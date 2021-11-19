/*
 * Copyright (c) 2000-2016 University of Utah and the Flux Group.
 * 
 * {{{EMULAB-LICENSE
 * 
 * This file is part of the Emulab network testbed software.
 * 
 * This file is free software: you can redistribute it and/or modify it
 * under the terms of the GNU Affero General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or (at
 * your option) any later version.
 * 
 * This file is distributed in the hope that it will be useful, but WITHOUT
 * ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
 * FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Affero General Public
 * License for more details.
 * 
 * You should have received a copy of the GNU Affero General Public License
 * along with this file.  If not, see <http://www.gnu.org/licenses/>.
 * 
 * }}}
 */

//#define CHUNKIFY_DEBUG

/*
 * imagerezip [-S] Oimage.ndz Nimage.ndz
 *
 * Read the data of the old image (Oimage.ndz) and create a new image
 * (Nimage.ndz) from it. With -S, it will create a new signature file
 * as well.
 *
 * Currently this is just a testing tool for the new libraries. At some
 * point it might be used to rechunk or rehash existing images, or compress
 * them with a different level.
 */
#include <stdio.h>
#include <stdlib.h>
#include <fcntl.h>
#include <assert.h>
#include <unistd.h>
#include <string.h>
#include <zlib.h>
#include <sys/stat.h>
#include <sys/time.h>
#include <errno.h>
#include <openssl/sha.h>
#include <openssl/md5.h>
#ifndef NOTHREADS
#include <pthread.h>
#endif

#include "imagehdr.h"
#include "imagehash.h"
#include "libndz/libndz.h"

struct fileinfo {
    struct ndz_file *ndz;
    char *sigfile;
    struct ndz_rangemap *map, *sigmap;
} old, new;

static int gensigfile = 0;
static int forcesig = 0;
static int debug = 0;
static int verify = 0;
static int sanitycheck = 1;
static int clevel = 4;
static int hashtype = HASH_TYPE_SHA1;
static int hashlen = 20;
static long hashblksize = -1;

void
usage(void)
{
    fprintf(stderr,
	    "Usage: imagerezip [-SVfd] [-b blksize] [-D hashfunc] [-z level] Oimage1.ndz Nimage.ndz\n"
	    "\n"
	    "Produce a new image that is a copy of the old image.\n"
	    "\n"
	    "-S         Generate a new signature.\n"
	    "-V         Verify consistency of image and signature.\n"
	    "-f         Force imagedelta to use a questionable sigfile.\n"
	    "-d         Enable debugging.\n"
	    "-D hfunc   Hash function to use (md5 or sha1).\n"
	    "-b blksize Size of hash blocks (512 <= size <= 32M).\n"
	    "-z level   Compression level (0 to 9).\n");

    exit(1);
}

/*
 * Iterator for ranges in the image map.
 * Validate that entries match up with those in the signature map.
 */
static int
verifyfunc(struct ndz_rangemap *imap, struct ndz_range *range, void *arg)
{
    struct ndz_range **smnext = arg;
    struct ndz_range *srange = *smnext;
    ndz_addr_t addr, eaddr;

    addr = range->start;
    eaddr = range->end;

    /*
     * Every image range should correspond to an integral number of
     * signature map entries.
     */
    while (addr <= eaddr && srange) {
	if (srange->start != addr || srange->end > eaddr) {
	    /*
	     * XXX argh! One anomaly is when an image region gets
	     * split across chunks, in which case it appears as distinct
	     * ranges in our image map. Here we look ahead behind to
	     * identify those cases...
	     */
	    if (srange->data) {
		struct ndz_hashdata *hd = (struct ndz_hashdata *)srange->data;

		if (HASH_CHUNKDOESSPAN(hd->chunkno)) {
		    /*
		     * If starts line up then make sure following
		     * image map entry is contiguous with us. If so,
		     * assume this is the special case and return
		     * without incrementing the sigmap entry.
		     */
		    if (srange->start == addr && range->next &&
			range->next->start == range->end + 1) {
			*smnext = srange;
			return 0;
		    }
		    /*
		     * See if we are on the other side of the anomaly.
		     * Here the srange start will be before the image
		     * map range start and the previous image range
		     * should be contiguous with us. If so, advance to
		     * the next srange and continue.
		     */
		    if (addr == range->start &&
			srange->start < addr && srange->end <= eaddr &&
			ndz_rangemap_lookup(imap, addr-1, NULL) != NULL) {
			addr = srange->end + 1;
			srange = srange->next;
			continue;
		    }
		}
	    }
	    fprintf(stderr, "  *** [%lu-%lu]: bad sigentry [%lu-%lu]\n",
		    range->start, eaddr, srange->start, srange->end);
	    return 1;
	}
	addr = srange->end + 1;
	srange = srange->next;
    }
    if (addr <= eaddr) {
	fprintf(stderr, "  *** [%lu-%lu]: signature map too short!\n",
		range->start, range->end);
	return 1;
    }

    *smnext = srange;
    return 0;
}

/*
 * File must exist and be readable.
 * If verify is set, signature file must exist as well.
 * Reads in the range map and signature as well.
 */
void
openifile(char *file, struct fileinfo *info)
{
    int sigfd;

    info->ndz = ndz_open(file, 0);
    if (info->ndz == NULL) {
	fprintf(stderr, "%s: could not open as NDZ file\n",
		ndz_filename(info->ndz));
	exit(1);
    }

    if (verify) {
	struct stat sb1, sb2;

	info->sigfile = malloc(strlen(file) + 5);
	assert(info->sigfile != NULL);
	strcpy(info->sigfile, file);
	strcat(info->sigfile, ".sig");
	sigfd = open(info->sigfile, 0);
	if (sigfd < 0) {
	    fprintf(stderr, "%s: could not find signature file %s\n",
		    file, info->sigfile);
	    exit(1);
	}
	if (fstat(info->ndz->fd, &sb1) < 0 || fstat(sigfd, &sb2) < 0) {
	    fprintf(stderr, "%s: could stat image or signature file\n", file);
	    exit(1);
	}
	if (!forcesig && labs(sb1.st_mtime - sb2.st_mtime) > 2) {
	    fprintf(stderr, "%s: image and signature disagree (%ld != %ld), "
		    "use -f to override.\n", file, sb1.st_mtime, sb2.st_mtime);
	    exit(1);
	}
	close(sigfd);
    }
}

void
openofile(char *file, struct fileinfo *info)
{
    int sigfd;

    if (strcmp(file, "-") == 0) {
	fprintf(stderr, "Cannot output to stdout yet\n");
	exit(1);
    }

    info->ndz = ndz_open(file, 1);
    if (info->ndz == NULL) {
	perror(file);
	exit(1);
    }

    info->sigfile = malloc(strlen(file) + 5);
    assert(info->sigfile != NULL);
    strcpy(info->sigfile, file);
    strcat(info->sigfile, ".sig");

    /* check early that we can write to the sigfile! */
    sigfd = open(info->sigfile, O_WRONLY|O_CREAT|O_TRUNC, 0666);
    if (sigfd < 0) {
	perror(info->sigfile);
	exit(1);
    }
    close(sigfd);
}

void
readifile(struct fileinfo *info)
{
    /* read range info from image */
    info->map = ndz_readranges(info->ndz);
    if (info->map == NULL) {
	fprintf(stderr, "%s: could not read ranges\n",
		ndz_filename(info->ndz));
	exit(1);
    }

    /* read signature info */
    if (verify) {
	info->sigmap = ndz_readhashinfo(info->ndz, info->sigfile);
	if (info->sigmap == NULL) {
	    fprintf(stderr, "%s: could not read signature info\n",
		    ndz_filename(info->ndz));
	    exit(1);
	}
	if (sanitycheck) {
	    struct ndz_range *next = ndz_rangemap_first(info->sigmap);
	    int rv;

	    /*
	     * Perform a sanity check, ensuring that ranges in the image
	     * map exactly correspond to those in the signature.
	     */
	    rv = ndz_rangemap_iterate(info->map, verifyfunc, &next);
	    if (rv != 0 || next != NULL) {
		if (rv == 0)
		    fprintf(stderr,
			    "  *** image map too short at sig [%lu-%lu]\n",
			    next->start, next->end);
		fprintf(stderr, "%s: error while validating range/hash maps\n",
			ndz_filename(info->ndz));
#if 0
		printf("==== Image ");
		ndz_rangemap_dump(info->map, (debug==0), NULL);
		printf("==== Hash ");
		ndz_hashmap_dump(info->sigmap, (debug==0));
		fflush(stdout);
#endif
		exit(1);
	    }
	}
    } else
	info->sigmap = NULL;
}

struct chunkstate {
    ndz_chunk_t chunkobj;
    ndz_chunkno_t chunkno;
    unsigned char *chunkdatabuf;
    blockhdr_t *header;
    uint32_t headerleft;
    struct region *region;
    struct region *curregion;
};

static int
initnewchunk(struct chunkstate *cstate, struct ndz_file *ndz)
{
    struct blockhdr_V2 *hdr;

    cstate->chunkobj = ndz_chunk_create(ndz, cstate->chunkno, clevel);
    if (cstate->chunkobj == NULL) {
	fprintf(stderr, "Error creating chunk %u\n", cstate->chunkno);
	return 1;
    }
    cstate->header = ndz_chunk_header(cstate->chunkobj);

    /*
     * XXX we still do V3 (actually V2 format) headers.
     * We still don't really support V4 yet...
     */
    hdr = (struct blockhdr_V2 *)cstate->header;
    hdr->magic = COMPRESSED_V3;
    hdr->size = 0;
    hdr->blockindex = cstate->chunkno;
    hdr->regionsize = DEFAULTREGIONSIZE;
    hdr->regioncount = 0;
    hdr->firstsect = 0;
    hdr->lastsect = 0;
    hdr->reloccount = 0;

    cstate->region = (struct region *)(hdr + 1);
    cstate->curregion = cstate->region;
    cstate->headerleft = hdr->regionsize - sizeof(blockhdr_t);

    return 0;
}

/*
 * Iterator for ranges in the delta map.
 *
 * Read and chunkify the data from the full image to produce the delta.
 *
 * If we have a signature file for the "source" full image, then we don't
 * need to do any hashing as the delta signature will be identical
 * (signatures always cover the entire image).
 *
 * If we have no signature, or we are changing the hash block size or
 * hash algorithm, or we just want to validate the original signature,
 * then we hash the data as we go.
 */
static int
chunkify(struct ndz_rangemap *mmap, struct ndz_range *range, void *arg)
{
    struct chunkstate *cstate = arg;
    ndz_addr_t rstart = range->start;
    ndz_size_t rsize = range->end + 1 - rstart, sc;
    uint32_t roffset, hstart, hsize;
    size_t hbytes;
    ssize_t cc;
    struct ndz_hashdata *hdata = NULL;
    struct ndz_range *hrange;

#ifdef CHUNKIFY_DEBUG
    fprintf(stderr, "chunkify [%lu-%lu]:\n", range->start, range->end);
#endif

    /*
     * First call. Initialize the state we are going to carry through
     * with us via the iterator argument.
     */
    if (cstate->chunkobj == NULL) {
	cstate->chunkdatabuf = malloc(hashblksize * new.ndz->sectsize);
	if (cstate->chunkdatabuf == NULL) {
	    fprintf(stderr, "could not initialize chunkify data structs\n");
	    return 1;
	}
	cstate->chunkno = 0;
	if (initnewchunk(cstate, new.ndz) != 0)
	    return 1;
	cstate->header->firstsect = rstart;
	cstate->curregion->start = rstart;
	/*
	 * Account for relocations.
	 * XXX we don't know how many relocs will wind up in this chunk
	 * so we have to assume that all remaining ones will.
	 */
	if (new.ndz->relocentries > 0)
	    cstate->headerleft -=
		(ndz_reloc_inrange(new.ndz, rstart, 0) *
		 sizeof(struct blockreloc));
    }

    /*
     * Process the range, reading the old and producing the new.
     * When hashing, we also must respect hash block alignment.
     */
    if (verify || gensigfile)
	roffset = rstart % hashblksize;
    else
	roffset = 0;
    while (rsize > 0) {
	uint32_t pstart, psize;
	int spanschunk;
	size_t bufoff;

	hstart = rstart;
	if (roffset) {
	    hsize = hashblksize - roffset;
	    if (hsize > rsize)
		hsize = rsize;
	    roffset = 0;
	} else if (rsize > hashblksize)
	    hsize = hashblksize;
	else
	    hsize = rsize;
#ifdef CHUNKIFY_DEBUG
	fprintf(stderr, "  [%u-%u]: ", hstart, hstart + hsize - 1);
#endif

	/* XXX read/decompress data range */
	sc = ndz_readdata(old.ndz, cstate->chunkdatabuf, hsize, hstart);
	if (sc != hsize) {
	    fprintf(stderr, "%s: unexpected read return %ld (instead of %u)\n",
		    ndz_filename(old.ndz), (long)sc, hsize);
	    return 1;
	}

	/*
	 * Fetch and/or compute the hash value.
	 */
	hbytes = hsize * new.ndz->sectsize;
	if (verify || gensigfile) {
	    unsigned char hbuf[HASH_MAXSIZE];

	    /* compute the hash */
	    ndz_hash_data(new.ndz, cstate->chunkdatabuf, hbytes, hbuf);
#ifdef CHUNKIFY_DEBUG
	    fprintf(stderr, "computed hash=%s\n",
		    ndz_hash_dump(hbuf, hashlen));
#endif

	    if (gensigfile) {
		assert(new.ndz->hashcurentry < new.ndz->hashentries);
		hdata = &new.ndz->hashdata[new.ndz->hashcurentry++];
		hdata->hashlen = hashlen;
		memcpy(hdata->hash, hbuf, hashlen);
	    }

	    if (verify) {
		hrange = ndz_rangemap_lookup(old.sigmap, hstart, NULL);
		if (hrange && hrange->data &&
		    hrange->start == hstart &&
		    hrange->end == hstart + hsize - 1) {
		    struct ndz_hashdata *hd =
			(struct ndz_hashdata *)hrange->data;
		    if (memcmp(hd->hash, hbuf, hashlen)) {
			fprintf(stderr,
				"*** [%u-%u]: hash=%s does not compare!\n",
				hstart, hstart + hsize - 1,
				ndz_hash_dump(hd->hash, hashlen));
			return 1;
		    }
		} else {
		    fprintf(stderr, "*** [%u-%u]: ",
			    hstart, hstart + hsize - 1);
		    if (hrange == NULL)
			fprintf(stderr, "range start not found!\n");
		    else if (hrange->data == NULL)
			fprintf(stderr, "no hash data found!\n");
		    else
			fprintf(stderr, "range mismatch [%lu-%lu]!\n",
				hrange->start, hrange->end);
		    return 1;
		}
	    }
	}
#ifdef CHUNKIFY_DEBUG
	else
	    fprintf(stderr, "no hash computed\n");
#endif

	/*
	 * At this point we have a range of data ([hstart - hstart+hsize-1])
	 * of a specific size (hsize) which we have hashed (hdata->hash).
	 * Now we compress and write it out to the new image file. This is
	 * complicated significantly by the fact that it might not all fit
	 * in the current chunk. If there is not enough room for this range
	 * in the current chunk, we split it and write what we can.
	 *
	 * This is complicated even further by our conservative algorithm
	 * for filling chunks, which is basically: if the amount of
	 * uncompressed data exceeds the amount of space left for the
	 * compressed data (plus a little slop in case it expands instead),
	 * then we stop. This is an iterative process since, most likely,
	 * the compressed data will be significantly smaller than the
	 * uncompressed data.
	 */
	bufoff = 0;
	spanschunk = 0;
	pstart = hstart;
	psize = hsize;
	while (psize > 0) {
	    uint32_t wsize;
	    size_t wbytes, chunkremaining;

	    chunkremaining = ndz_chunk_left(cstate->chunkobj);
	    if (chunkremaining < new.ndz->sectsize ||
		cstate->headerleft < sizeof(struct region)) {
		/* switch to new chunk */
#ifdef CHUNKIFY_DEBUG
		fprintf(stderr,
			"    chunk %u full (%lu bytes, %u header), writing\n",
			cstate->chunkno,
			(unsigned long)ndz_chunk_datasize(cstate->chunkobj),
			cstate->header->regionsize - cstate->headerleft);
#endif

		/* finalize the header */
		cstate->header->size = ndz_chunk_datasize(cstate->chunkobj);
		cstate->header->regioncount =
		    (cstate->curregion - cstate->region + 1);
		/* XXX should always be zero */
		if (cstate->chunkno == 0)
		    cstate->header->firstsect = 0;
		cstate->header->lastsect = pstart;

		/* include any relocations */
		if (new.ndz->relocentries > 0) {
		    void *buf = (cstate->curregion + 1);
		    if (ndz_reloc_put(new.ndz, cstate->header, buf) != 0) {
			fprintf(stderr, "Error writing relocation info\n");
			return 1;
		    }
		}

		/* and write it */
		if (ndz_chunk_flush(cstate->chunkobj, 1) != 0) {
		    fprintf(stderr, "Error writing compressed data\n");
		    return 1;
		}

		cstate->chunkno++;
		if (initnewchunk(cstate, new.ndz) != 0)
		    return 1;
		cstate->header->firstsect = pstart;
		cstate->curregion->start = pstart;
		if (new.ndz->relocentries > 0)
		    cstate->headerleft -=
			(ndz_reloc_inrange(new.ndz, pstart, 0) *
			 sizeof(struct blockreloc));

		/* keep track if this hash range spans chunks */
		if (psize < hsize)
		    spanschunk++;

		chunkremaining = ndz_chunk_left(cstate->chunkobj);
		assert(psize <= chunkremaining / new.ndz->sectsize);
	    }

	    /* write up to chunkremaining (truncated to sectorsize) bytes */
	    wsize = psize;
	    wbytes = wsize * new.ndz->sectsize;
	    if (wbytes > chunkremaining) {
		wsize = (chunkremaining / new.ndz->sectsize);
		wbytes = wsize * new.ndz->sectsize;
	    }
	    assert(wsize > 0);

#ifdef CHUNKIFY_DEBUG
	    fprintf(stderr, "    appending %u sectors to chunk %u "
		    "(%ld bytes available)\n",
		    wsize, cstate->chunkno,
		    ndz_chunk_left(cstate->chunkobj));
#endif
	    cc = ndz_chunk_append(cstate->chunkobj,
				  cstate->chunkdatabuf + bufoff, wbytes);
	    if (cc < 0) {
		fprintf(stderr, "Error compressing data\n");
		return 1;
	    }
	    assert(cc == wbytes);

	    /* append to the current region or create a new one */
	    if (cstate->curregion->start + cstate->curregion->size == pstart) {
		cstate->curregion->size += wsize;
#ifdef CHUNKIFY_DEBUG
		fprintf(stderr, "    adjust range entry to [%u-%u]\n",
			cstate->curregion->start,
			cstate->curregion->start+cstate->curregion->size-1);
#endif
	    } else {
		cstate->curregion++;
		cstate->curregion->start = pstart;
		cstate->curregion->size = wsize;
		cstate->headerleft -= sizeof(struct region);
#ifdef CHUNKIFY_DEBUG
		fprintf(stderr,
			"    new range entry [%u-%u], %u header bytes left\n",
			cstate->curregion->start,
			cstate->curregion->start+cstate->curregion->size-1,
			cstate->headerleft);
#endif
	    }

	    bufoff += wbytes;
	    pstart += wsize;
	    psize -= wsize;
	    chunkremaining = ndz_chunk_left(cstate->chunkobj);
	}
 
	/*
	 * At this point we have written out the entire range. If creating
	 * a signature file, add it to the hash map, recording the chunk(s)
	 * that it belongs to.
	 */
	if (gensigfile) {
	    if (spanschunk)
		hdata->chunkno = HASH_CHUNKSETSPAN(cstate->chunkno-1);
	    else
		hdata->chunkno = cstate->chunkno;
#ifdef CHUNKIFY_DEBUG
	    fprintf(stderr, "    write hash entry [%u-%u], chunk %u",
		    hstart, hstart + hsize - 1, HASH_CHUNKNO(hdata->chunkno));
	    if (HASH_CHUNKDOESSPAN(hdata->chunkno))
		fprintf(stderr, "-%u", HASH_CHUNKNO(hdata->chunkno) + 1);
	    fprintf(stderr, "\n");
#endif
	    cc = ndz_rangemap_alloc(new.sigmap, hstart, hsize, (void *)hdata);
	    if (cc) {
		fprintf(stderr, "Could not add hashmap entry\n");
		return 1;
	    }
	}

	rstart += hsize;
	rsize -= hsize;
    }

    /*
     * If this is the last range, we have to flush the final chunk.
     */
    if (range->next == NULL) {
#ifdef CHUNKIFY_DEBUG
	fprintf(stderr, "    final chunk %u done (%lu bytes)\n",
		cstate->chunkno,
		(unsigned long)ndz_chunk_datasize(cstate->chunkobj));
#endif

	/* finalize the header */
	cstate->header->size = ndz_chunk_datasize(cstate->chunkobj);
	cstate->header->regioncount = (cstate->curregion - cstate->region + 1);
	/* XXX should always be zero */
	if (cstate->chunkno == 0)
	    cstate->header->firstsect = 0;
	cstate->header->lastsect = new.ndz->maphi + 1;

	/* include any relocations */
	if (new.ndz->relocentries > 0) {
	    void *buf = (cstate->curregion + 1);
	    if (ndz_reloc_put(new.ndz, cstate->header, buf) != 0) {
		fprintf(stderr, "Error writing relocation info\n");
		return 1;
	    }
	}

	/* and write it */
	if (ndz_chunk_flush(cstate->chunkobj, 1) != 0) {
	    fprintf(stderr, "Error writing compressed data\n");
	    return 1;
	}

	free(cstate->chunkdatabuf);

	/* XXX for debugging */
	memset(cstate, 0, sizeof(*cstate));
    }

    return 0;
}

static int
unchunkify(struct ndz_rangemap *omap, struct ndz_range *range, void *arg)
{
    struct ndz_rangemap *nmap = arg;
    ndz_addr_t size = range->end - range->start + 1;

    assert(nmap);
    if (ndz_rangemap_alloc(nmap, range->start, size, 0)) {
	fprintf(stderr, "could not create map entry for [%lu-%lu]\n",
		range->start, range->end);
	return 1;
    }

    return 0;
}

#if 0
static void
chunkfunc(struct ndz_rangemap *map, void *ptr)
{
    unsigned int chunkno = (uintptr_t)ptr;
    printf("chunkno=%u", chunkno);
}
#endif

int
main(int argc, char **argv)
{
    int ch;

    while ((ch = getopt(argc, argv, "SfdVb:D:")) != -1)
	switch(ch) {
	case 'S':
	    gensigfile = 1;
	    break;
	case 'b':
	    hashblksize = atol(optarg);
	    if (hashblksize < 512 || hashblksize > (32*1024*1024) ||
		(hashblksize & 511) != 0) {
		fprintf(stderr, "Invalid hash block size\n");
		usage();
	    }
	    hashblksize /= 512;
	    break;
	case 'D':
	    if (strcmp(optarg, "md5") == 0) {
		hashtype = HASH_TYPE_MD5;
		hashlen = 16;
	    } else if (strcmp(optarg, "sha1") == 0) {
		hashtype = HASH_TYPE_SHA1;
		hashlen = 20;
	    } else {
		fprintf(stderr, "Invalid digest type `%s'\n",
			optarg);
		usage();
	    }
	    break;
	case 'f':
	    forcesig = 1;
	    break;
	case 'V':
	    verify = 1;
	    break;
	case 'd':
	    debug++;
	    break;
	case 'z':
	    clevel = atoi(optarg);
	    if (clevel < 0 || clevel > 9) {
		fprintf(stderr, "Invalid compression level\n");
		usage();
	    }
	    break;
	case 'h':
	case '?':
	default:
	    usage();
	}
    argc -= optind;
    argv += optind;

    if (argc < 2)
	usage();

    /*
     * Set a reasonable default blocksize whether hashing or not.
     */
    if (hashblksize == -1) {
	if (verify || gensigfile)
	    hashblksize = HASHBLK_SIZE / 512;
	else
	    hashblksize = (128 * 1024) / 512;
    }

    /*
     * Make sure we can open all the files
     */
    openifile(argv[0], &old);
    openofile(argv[1], &new);

    /*
     * Read in the range and signature info.
     */
    readifile(&old);

#if 0
    printf("==== Old range ");
    ndz_rangemap_dump(old.map, (debug==0), chunkfunc);
    if (old.sigmap) {
	printf("==== Old hash ");
	ndz_hashmap_dump(old.sigmap, (debug==0));
    }
    fflush(stdout);
#endif

    /*
     * If we are checking and producing signatures, make sure the
     * hashtype and block size are the same.
     */
    if (verify && gensigfile) {
	if (old.ndz->hashtype != hashtype ||
	    old.ndz->hashblksize != hashblksize) {
	    fprintf(stderr, "%s: incompatible hash values\n", argv[0]);
	    exit(1); 
	}
    }

    /*
     * Copy the old map to the new map removing any artificial chunk
     * boundaries.
     */
    new.map = ndz_rangemap_init(NDZ_LOADDR, NDZ_HIADDR-NDZ_LOADDR);
    if (ndz_rangemap_iterate(old.map, unchunkify, new.map)) {
	fprintf(stderr, "%s: could not create new map\n", argv[0]);
	exit(1);
    }

    /*
     * New map has same range as old image.
     * XXX doesn't belong here.
     */
    new.ndz->maplo = old.ndz->maplo;
    new.ndz->maphi = old.ndz->maphi;

    /*
     * Iterate through the map hashing (if necessary) and chunking the data.
     */
    new.sigmap = ndz_rangemap_init(NDZ_LOADDR, NDZ_HIADDR-NDZ_LOADDR);
    if (new.sigmap == NULL) {
	fprintf(stderr, "%s: could not create signature map for new image\n",
		argv[1]);
	exit(1);
    }

    /*
     * Initialize signature file info for new map.
     * XXX doesn't belong here.
     */
    new.ndz->hashmap = new.sigmap;
    new.ndz->hashdata = calloc(old.ndz->hashentries,
			       sizeof(struct ndz_hashdata));
    if (new.ndz->hashdata == NULL) {
	fprintf(stderr, "%s: could not allocate hashdata for new image\n",
		argv[1]);
	exit(1);
    }
    new.ndz->hashtype = hashtype;
    new.ndz->hashblksize = hashblksize;
    new.ndz->hashentries = old.ndz->hashentries;
    new.ndz->hashcurentry = 0;

    if (ndz_reloc_copy(old.ndz, new.ndz)) {
	fprintf(stderr, "%s: could not copy reloc info for new image\n",
		argv[2]);
	exit(1);
    }

    /*
     * If there is anything in the old image, produce a new image!
     */
    if (ndz_rangemap_first(new.map) != NULL) {
	struct chunkstate *cstate = calloc(1, sizeof(*cstate));
	assert(cstate != NULL);

	if (ndz_rangemap_iterate(new.map, chunkify, cstate) != 0) {
	    fprintf(stderr, "%s: error while creating new image\n",
		    argv[1]);
	    exit(1);
	}
	free(cstate);

	/* write the new sigfile */
	if (gensigfile) {
	    if (ndz_writehashinfo(new.ndz, new.sigfile, argv[1]) != 0) {
		fprintf(stderr, "%s: could not write signature file %s\n",
			argv[1], new.sigfile);
	    }
	}
    }

    return 0;
}

/*
 * Local variables:
 * mode: C
 * c-set-style: "BSD"
 * c-basic-offset: 4
 * End:
 */
