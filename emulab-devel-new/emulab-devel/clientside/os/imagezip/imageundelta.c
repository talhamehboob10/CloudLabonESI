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

#define MAP_DEBUG
//#define APPLYDELTA_DEBUG
//#define CHUNKIFY_DEBUG

/*
 * imageundelta [ -S -f ] base.ndz delta.ndz newimage.ndz
 *
 * Takes a base image and a delta image and produces a full image
 * that is the result of applying the delta on top of the base.
 *
 * Note that the resulting image may be larger than if newimage.ndz
 * had been created straight from a disk. This is because the delta
 * image only contains information about which blocks are different
 * from the base image, and nothing about which blocks in the base
 * image are no longer needed.
 *
 * The -S option says to use the signature file of the delta to glean
 * which blocks of the base image are no longer needed and thus produce
 * a more "accurate" image. This assumes that the signature associated
 * with the delta image is a full-image signature, and not a delta
 * image signature. Otherwise, you will just wind up with a new copy
 * of the delta image!
 *
 * In theory, we could take a sequence of deltas to apply to the base
 * image, but let's start simple.
 *
 * Note that order matters here! If you were to apply the base to the
 * delta, you would wind up with either a copy of the base images
 * (with -S) or a copy of the base image with excess junk sectors (no -S).
 *
 * Approach:
 *
 *  1.  Read the range map for the base image.
 *  2.  Read the range map and (optional) signature for the delta.
 *      Perhaps validate that the signature covers a range larger
 *      that that of the image, as a quick heuristic to determine
 *      if this is a "useable" delta image; i.e., it must have a
 *      full-image signature.
 *  3.  Create a "union" map with all the ranges that need to go into
 *      the new image, augmented with info about what image/chunk to
 *      pull the data from.
 *  3a. With a signature, use the delta image signature file. For
 *      each signature entry, if the range is in the delta image,
 *      make that the source. If not, use the base image as the source.
 *  3b. Without a signature, use the range maps. Start with a copy of
 *      the base image map using the base image as source. For each
 *      range in the delta map, replace/add entries with delta as source.
 *  4.  Iterate through the new map, reading data from the indicated
 *      source, and writing to the new image. Write a new signature if
 *	desired (can just copy the delta image signature as appropriate).
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
} base, delta, new;

static int usesigfile = 0;
static int forcesig = 0;
static int debug = 0;
static int verify = 0;
static int clevel = 4;
static int hashtype = HASH_TYPE_SHA1;
static int hashlen = 20;
static long hashblksize = HASHBLK_SIZE / 512;

static int sigchunkify(struct ndz_rangemap *sigmap, struct ndz_range *range,
		       void *arg);
static int chunkify(struct ndz_rangemap *mmap, struct ndz_range *range,
		    void *arg);
static int verifyfunc(struct ndz_rangemap *imap, struct ndz_range *range,
		      void *arg);

void
usage(void)
{
    fprintf(stderr,
	    "Usage: imageundelta [-SVfd] [-b blksize] [-D hashfunc] [-z level] base.ndz delta.ndz newimage.ndz\n"
	    "\n"
	    "Produce a new full image (newimage) by combining a base image\n"
	    "(base) and a delta image (delta).\n"
	    "\n"
	    "-S         Use sigfile for delta to optimize image creation.\n"
	    "-V         Verify consistency of delta and signature.\n"
	    "-f         Force imagedelta to use a questionable sigfile.\n"
	    "-d         Enable debugging.\n"
	    "-D hfunc   Hash function to use (md5 or sha1) for new sigfile.\n"
	    "-b blksize Size of hash blocks (512 <= size <= 32M) for new sigfile.\n"
	    "-z level   Compression level (0 to 9).\n");

    exit(1);
}

/*
 * Iterator for ranges in the image map.
 * Validate that entries are covered by those in the signature map.
 */
static int
verifyfunc(struct ndz_rangemap *imap, struct ndz_range *range, void *arg)
{
    struct ndz_rangemap *sigmap = arg;
    struct ndz_range *srange;
    ndz_addr_t addr, eaddr;

    addr = range->start;
    eaddr = range->end;

    /*
     * Every image range should be completely covered by sigmap ranges.
     */
    while (addr <= eaddr) {
	srange = ndz_rangemap_lookup(sigmap, addr, NULL);

	/* start address not in the map, error */
	if (srange == NULL)
	    return 1;

	/* everything through the end of the sigmap entry is covered */
	addr = srange->end + 1;
    }
    return 0;
}

/*
 * File must exist and be readable.
 * If usesigfile is set, signature file must exist as well.
 * Reads in the range map and signature as well.
 */
void
openifile(char *file, struct fileinfo *info, int usesig)
{
    int sigfd;

    info->ndz = ndz_open(file, 0);
    if (info->ndz == NULL) {
	fprintf(stderr, "%s: could not open as NDZ file\n",
		ndz_filename(info->ndz));
	exit(1);
    }

    if (usesig) {
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
readifile(struct fileinfo *info, int usesig)
{
    /* read range info from image */
    info->map = ndz_readranges(info->ndz);
    if (info->map == NULL) {
	fprintf(stderr, "%s: could not read ranges\n",
		ndz_filename(info->ndz));
	exit(1);
    }

    /* read signature info */
    if (usesig) {
	info->sigmap = ndz_readhashinfo(info->ndz, info->sigfile);
	if (info->sigmap == NULL) {
	    fprintf(stderr, "%s: could not read signature info\n",
		    ndz_filename(info->ndz));
	    exit(1);
	}
	if (verify) {
	    ndz_size_t isects, ssects;
	    int rv;

	    /*
	     * Perform a sanity check, ensuring that ranges in the image map
	     * are all covered by entries in the sigmap.
	     */
	    rv = ndz_rangemap_iterate(info->map, verifyfunc, info->sigmap);
	    if (rv != 0) {
		fprintf(stderr,
			"%s: signature does not completely cover image\n",
			ndz_filename(info->ndz));
		exit(1);
	    }
	    /*
	     * Sanity check part 2, ensure that the signature map more than
	     * covers the image map. In fact, if they are an exact match,
	     * then the image is either not a delta image or the signature
	     * is not a full-image signature. Either way, the produced image
	     * is likely not going to be what you expect.
	     *
	     * Since we know that the image map has to be a subset of the
	     * signature map, we can just use the sectors counts to perform
	     * our check.
	     */
	    isects = ndz_rangemap_sectors(info->map);
	    ssects = ndz_rangemap_sectors(info->sigmap);
	    if (isects > ssects) {
		fprintf(stderr,
			"%s: mapformed signature?\nImage ranges not completely"
			" covered by signature.\n", ndz_filename(info->ndz));
		exit(1);
	    }
	    if (ssects - isects == 0) {
		fprintf(stderr,
			"%s: WARNING: delta signature exactly matches image.\n"
			"Either delta is really a full image or "
			"signature is not for a full image.\n",
			ndz_filename(info->ndz)); 
		return;
	    }
	    if (debug)
		fprintf(stderr, "sig covers %lu more sectors than in image\n",
			ssects - isects);
	}
    } else
	info->sigmap = NULL;
}

struct mergestate {
    struct ndz_range *dmapnext;
    ndz_addr_t dmapaddr;
    struct ndz_rangemap *mmap;
};
struct mapdata {
    int frombase;
    ndz_chunkno_t chunkno;
};

static void
mergefunc(struct ndz_rangemap *map, void *ptr)
{
    struct mapdata *mdata = ptr;
    printf("%s map, chunkno=%u",
	   mdata->frombase ? "base" : "delta", mdata->chunkno);
}

static int
addmmrange(struct ndz_rangemap *mmap, ndz_addr_t addr, ndz_addr_t eaddr,
	   int frombase, ndz_chunkno_t chunkno)
{
    struct mapdata *mdata = malloc(sizeof *mdata);
    if (mdata == NULL)
	return 1;
    mdata->frombase = frombase;
    mdata->chunkno = chunkno;
#ifdef APPLYDELTA_DEBUG
    fprintf(stderr, "  adding %s range [%lu-%lu]\n",
	    frombase ? "base" : "delta", addr, eaddr);
#endif
    if (ndz_rangemap_alloc(mmap, addr, eaddr - addr + 1, mdata)) {
	free(mdata);
	return 1;
    }

    return 0;
}

/*
 * For a range in the delta image map, insert it into the base map.
 * Where there is overlap, replace the corresponding base map info.
 */
static int
applydelta(struct ndz_rangemap *bmap, struct ndz_range *brange, void *arg)
{
    struct mergestate *state = arg;
    struct ndz_rangemap *mmap = state->mmap;
    ndz_addr_t baddr, beaddr, daddr = 0, deaddr = 0;
    struct ndz_range *drange;

    baddr = brange->start;
    beaddr = brange->end;

#ifdef APPLYDELTA_DEBUG
    fprintf(stderr, "applydelta [%lu-%lu]:\n", baddr, beaddr);
#endif

    /*
     * Any delta entries before this base entry need to be added.
     */
    drange = state->dmapnext;
    if (drange) {
	daddr = state->dmapaddr;
	deaddr = drange->end;
    }
    while (drange && deaddr < baddr) {
	if (addmmrange(mmap, daddr, deaddr, 0, (uintptr_t)drange->data))
	    goto fail;
	if ((drange = drange->next) != NULL) {
	    daddr = drange->start;
	    deaddr = drange->end;
	}
    }

    /*
     * If there is no overlap with the next delta entry,
     * just add the current base entry and return.
     */
    if (drange == NULL || daddr > beaddr) {
	if (addmmrange(mmap, baddr, beaddr, 1, (uintptr_t)brange->data))
	    goto fail;
	goto done;
    }

    /*
     * If any portion of the current delta entry is before us,
     * add that portion.
     */
    if (daddr < baddr) {
	assert(drange != NULL);
	assert(deaddr >= baddr);
	if (addmmrange(mmap, daddr, baddr-1, 0, (uintptr_t)drange->data))
	    goto fail;
	daddr = baddr;
    }

    /*
     * Walk through the current base range recording which portions
     * come from the base and which are covered by the delta.
     */
    while (baddr <= beaddr) {
#ifdef APPLYDELTA_DEBUG
	fprintf(stderr, " remaining: base [%lu-%lu], delta [%lu-%lu]\n",
		baddr, beaddr, daddr, deaddr);
#endif
	/* base range */
	if (baddr < daddr) {
	    if (daddr <= beaddr) {
		if (addmmrange(mmap, baddr, daddr-1, 1,
			       (uintptr_t)brange->data))
		    goto fail;
		baddr = daddr;
	    } else {
		if (addmmrange(mmap, baddr, beaddr, 1,
			       (uintptr_t)brange->data))
		    goto fail;
		baddr = beaddr + 1;
	    }
	    continue;
	}

	/* delta range */
	if (deaddr <= beaddr) {
	    if (addmmrange(mmap, daddr, deaddr, 0,
			   (uintptr_t)drange->data))
		goto fail;
	    baddr = deaddr + 1;
	    if ((drange = drange->next) != NULL) {
		daddr = drange->start;
		deaddr = drange->end;
	    } else
		daddr = beaddr + 1;
	} else {
	    if (addmmrange(mmap, daddr, beaddr, 0,
			   (uintptr_t)drange->data))
		goto fail;
	    baddr = beaddr + 1;
	    daddr = baddr;
	}
    }

 done:
    /*
     * This is the final base map entry, must add everything else
     * from the delta map.
     */
    if (brange->next == NULL && drange != NULL) {
#ifdef APPLYDELTA_DEBUG
	fprintf(stderr, " base finished, adding remaining delta"
		" starting at [%lu-%lu]\n", daddr, deaddr);
#endif
	while (drange) {
	    if (addmmrange(mmap, daddr, deaddr, 0, (uintptr_t)drange->data))
		goto fail;
	    if (drange->next) {
		daddr = drange->next->start;
		deaddr = drange->next->end;
	    }
	    drange = drange->next;
	}
    }

    state->dmapnext = drange;
    state->dmapaddr = daddr;
    return 0;

 fail:
    fprintf(stderr, "applydelta failed\n");
    return 1;
}

struct chunkstate {
    ndz_chunk_t chunkobj;
    ndz_chunkno_t chunkno;
    unsigned char *chunkdatabuf;
    blockhdr_t *header;
    uint32_t headerleft;
    struct region *region;
    struct region *curregion;
    struct ndz_rangemap *verifysigmap;
    struct ndz_rangemap *newsigmap;
};

struct sigchunkstate {
    struct ndz_rangemap *mmap;
    struct chunkstate cstate;
};

/*
 * Use the sigmap to direct chunking/writing of data. This way we can
 * eliminate data from the base image which should no longer be in the
 * new image.
 */
static int
sigchunkify(struct ndz_rangemap *sigmap, struct ndz_range *srange, void *arg)
{
    struct sigchunkstate *state = arg;
    struct ndz_range *range, trange;

#ifdef CHUNKIFY_DEBUG
    fprintf(stderr, "sigchunkify [%lu-%lu]:\n", srange->start, srange->end);
#endif

    assert(srange->data != NULL);

    range = ndz_rangemap_lookup(state->mmap, srange->start, NULL);
    assert(range != NULL);
    
    /*
     * Create a fake range entry using the bounds of the sigmap range but
     * data form the image map range. We can do this since data for a single
     * sigmap entry will always come from the same source (either base or
     * delta image map). Note that a sigmap entry may cover multiple contiguous
     * range map entries. Chunkify will handle this just fine as long as the
     * data are all from the same image (base or delta).
     */
    assert(srange->start >= range->start);
    trange.start = srange->start;
    trange.end = srange->end;
    trange.data = range->data;
    /* massive assertion */
    while (srange->end > range->end) {
	struct ndz_range *next = range->next;
	struct mapdata *hdata, *nhdata;
	assert(next && next->start == range->end+1);
	assert(range->data && next->data);
	hdata = range->data;
	nhdata = next->data;
	assert(hdata->frombase == nhdata->frombase);
	range = next;
    }

    /*
     * Whacky, we need to set the next entry as chunkify uses that to
     * detect when it reaches the final range so it can flush the final
     * chunk. To make sure chunkify doesn't do that prematurely in the
     * event we have multiple hash ranges over the final image range,
     * we make sure that next is non-zero except for the final sig piece.
     */
    if (srange->next == NULL)
	trange.next = NULL;
    else
	/* XXX value does not matter, just non-zero */
	trange.next = &trange;

    return chunkify(state->mmap, &trange, &state->cstate);
}

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
 * Iterator for ranges in the merge map.
 *
 * Read and chunkify the data from either the full image or the delta to
 * produce the new image.
 *
 * If we have a full signature file for the delta image, then we don't
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
    struct mapdata *mdata;

    assert(range->data != NULL);
    mdata = range->data;

#ifdef CHUNKIFY_DEBUG
    fprintf(stderr, "chunkify [%lu-%lu]: %s image chunk %u\n",
	    range->start, range->end,
	    mdata->frombase ? "base" : "delta", mdata->chunkno);
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
	if (delta.ndz->relocentries > 0)
	    cstate->headerleft -=
		(ndz_reloc_inrange(new.ndz, rstart, 0) *
		 sizeof(struct blockreloc));
    }

    /*
     * Process the range, reading the old and producing the new.
     * When hashing, we also must respect hash block alignment.
     */
    if (cstate->verifysigmap || cstate->newsigmap)
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
	sc = ndz_readdata(mdata->frombase ? base.ndz : delta.ndz,
			  cstate->chunkdatabuf, hsize, hstart);
	if (sc != hsize) {
	    fprintf(stderr, "%s: unexpected read return %ld (instead of %u)\n",
		    ndz_filename(mdata->frombase ? base.ndz : delta.ndz),
		    (long)sc, hsize);
	    return 1;
	}

	/*
	 * Fetch and/or compute the hash value.
	 */
	hbytes = hsize * new.ndz->sectsize;
	if (cstate->verifysigmap || cstate->newsigmap) {
	    unsigned char hbuf[HASH_MAXSIZE];

	    /* compute the hash */
	    ndz_hash_data(new.ndz, cstate->chunkdatabuf, hbytes, hbuf);
#ifdef CHUNKIFY_DEBUG
	    fprintf(stderr, "computed hash=%s\n",
		    ndz_hash_dump(hbuf, hashlen));
#endif

	    if (cstate->newsigmap) {
		assert(new.ndz->hashcurentry < new.ndz->hashentries);
		hdata = &new.ndz->hashdata[new.ndz->hashcurentry++];
		hdata->hashlen = hashlen;
		memcpy(hdata->hash, hbuf, hashlen);
	    }

	    if (cstate->verifysigmap) {
		hrange = ndz_rangemap_lookup(cstate->verifysigmap,
					     hstart, NULL);
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
		if (delta.ndz->relocentries > 0)
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
	if (cstate->newsigmap) {
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
	    cc = ndz_rangemap_alloc(cstate->newsigmap, hstart, hsize, hdata);
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

static void
chunkfunc(struct ndz_rangemap *map, void *ptr)
{
    unsigned int chunkno = (uintptr_t)ptr;
    printf("chunkno=%u", chunkno);
}

/*
 * Set the modtime of dst to match that of src.
 */
static void
setfiletime(char *dst, char *src)
{
    struct timeval tm[2];
    struct stat sb;
    int cc;

    cc = stat(src, &sb);
    if (cc >= 0) {
#ifdef linux
	tm[0].tv_sec = sb.st_atime;
	tm[0].tv_usec = 0;
	tm[1].tv_sec = sb.st_mtime;
	tm[1].tv_usec = 0;
#else
	TIMESPEC_TO_TIMEVAL(&tm[0], &sb.st_atimespec);
	TIMESPEC_TO_TIMEVAL(&tm[1], &sb.st_mtimespec);
#endif
	cc = utimes(dst, tm);
    }
    if (cc < 0)
	fprintf(stderr, "%s: WARNING: could not set mtime (%s)\n",
		dst, strerror(errno));
}

int
main(int argc, char **argv)
{
    struct mergestate state;
    int ch;

    while ((ch = getopt(argc, argv, "SfdVb:D:F")) != -1)
	switch(ch) {
	case 'S':
	    usesigfile = 1;
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

    if (argc < 3)
	usage();

    /*
     * Make sure we can open all the files
     */
    openifile(argv[0], &base, 0);
    openifile(argv[1], &delta, usesigfile);
    openofile(argv[2], &new);

    /*
     * Read in the range and signature info.
     */
    readifile(&base, 0);
    readifile(&delta, usesigfile);

#ifdef MAP_DEBUG
    if (debug) {
	printf("==== Base range ");
	ndz_rangemap_dump(base.map, (debug==1), chunkfunc);
	printf("==== Delta range ");
	ndz_rangemap_dump(delta.map, (debug==1), chunkfunc);
	if (usesigfile) {
	    printf("==== Delta hash ");
	    ndz_hashmap_dump(delta.sigmap, (debug==1));
	}
	fflush(stdout);
    }
#endif

    /*
     * Compute a map for the new image.
     */
    new.map = ndz_rangemap_init(NDZ_LOADDR, NDZ_HIADDR-NDZ_LOADDR);
    if (new.map == NULL) {
	fprintf(stderr, "%s: could not create map for new image\n",
		argv[2]);
	exit(1);
    }

    state.dmapnext = ndz_rangemap_first(delta.map);
    state.dmapaddr = state.dmapnext ? state.dmapnext->start : 0;
    state.mmap = new.map;

    if (ndz_rangemap_iterate(base.map, applydelta, &state) != 0) {
	fprintf(stderr, "%s: error while creating new image\n",
		argv[2]);
	exit(1);
    }

#ifdef MAP_DEBUG
    if (debug) {
	printf("==== Merge ");
	ndz_rangemap_dump(new.map, (debug==1), mergefunc);
	fflush(stdout);
    }
#endif

#if 1
    /*
     * Range of the new map is the same as the delta.
     */
    new.ndz->maplo = delta.ndz->maplo;
    new.ndz->maphi = delta.ndz->maphi;
#else
    /*
     * Compute the range of the new map. We look at the first and last
     * ranges in the merged map and use the source entries of those to
     * determine the proper values.
     * XXX doesn't belong here.
     */
    if (ndz_rangemap_sectors(new.map)) {
	struct mapdata *mdata;

	/* XXX look up last first since hint is already at the end */
	mdata = ndz_rangemap_last(new.map)->data;
	assert(mdata != NULL);
	if (mdata->frombase)
	    new.ndz->maphi = base.ndz->maphi;
	else
	    new.ndz->maphi = delta.ndz->maphi;

	mdata = ndz_rangemap_first(new.map)->data;
	assert(mdata != NULL);
	if (mdata->frombase)
	    new.ndz->maplo = base.ndz->maplo;
	else
	    new.ndz->maplo = delta.ndz->maplo;
	if (debug) {
	    printf("new map range: low=%lu, high=%lu\n",
		   new.ndz->maplo, new.ndz->maphi);
	    fflush(stdout);
	}
    }
#endif

    /*
     * Iterate through the produced map hashing (if necessary) and
     * chunking the data.
     */
    if (usesigfile) {
	new.sigmap = ndz_rangemap_init(NDZ_LOADDR, NDZ_HIADDR-NDZ_LOADDR);
	if (new.sigmap == NULL) {
	    fprintf(stderr,
		    "%s: could not create signature map for new image\n",
		    argv[2]);
	    exit(1);
	}

	/*
	 * Initialize signature file info for new map.
	 * XXX doesn't belong here.
	 */
	new.ndz->hashmap = new.sigmap;
	new.ndz->hashdata = calloc(delta.ndz->hashentries,
				   sizeof(struct ndz_hashdata));
	if (new.ndz->hashdata == NULL) {
	    fprintf(stderr, "%s: could not allocate hashdata for new image\n",
		    argv[2]);
	    exit(1);
	}
	new.ndz->hashtype = hashtype;
	new.ndz->hashblksize = hashblksize;
	new.ndz->hashentries = delta.ndz->hashentries;
	new.ndz->hashcurentry = 0;

	if (ndz_reloc_copy(delta.ndz, new.ndz)) {
	    fprintf(stderr, "%s: could not copy reloc info for new image\n",
		    argv[2]);
	    exit(1);
	}
    }

    /*
     * If there is anything in the new map, produce an image!
     */
    if (ndz_rangemap_first(new.map) != NULL) {
	/*
	 * If we are using the sigmap, we use that to determine which
	 * ranges in new.map to actually write to the file. sigchunkify
	 * will call chunkify on any legit ranges.
	 */
	if (usesigfile) {
	    struct sigchunkstate scstate;

	    scstate.mmap = new.map;
	    memset(&scstate.cstate, 0, sizeof(scstate.cstate));
	    if (verify)
		scstate.cstate.verifysigmap = delta.sigmap;
	    if (usesigfile)
		scstate.cstate.newsigmap = new.sigmap;
	    if (ndz_rangemap_iterate(delta.sigmap, sigchunkify, &scstate)) {
		fprintf(stderr, "%s: error while creating new image\n",
			argv[2]);
		exit(1);
	    }

	    /* readjust to reflect the actual number of hash entries */
	    new.ndz->hashentries = new.ndz->hashcurentry;

	    /* write the new sigfile */
	    if (ndz_writehashinfo(new.ndz, new.sigfile, argv[2]) != 0) {
		fprintf(stderr, "%s: could not write signature file %s\n",
			argv[2], new.sigfile);
	    }
	}
	/*
	 * Otherwise we produce an image directly from the newly calculated
	 * map. Note that it will contain ranges from the full image that are
	 * no longer a part of the image described by the delta.
	 */
	else {
	    struct chunkstate cstate;

	    memset(&cstate, 0, sizeof(cstate));
	    if (verify)
		cstate.verifysigmap = delta.sigmap;
	    if (usesigfile)
		cstate.newsigmap = new.sigmap;
	    if (ndz_rangemap_iterate(new.map, chunkify, &cstate) != 0) {
		fprintf(stderr, "%s: error while creating new image\n",
			argv[2]);
		exit(1);
	    }
	}

	ndz_close(base.ndz);
	ndz_close(delta.ndz);
	ndz_close(new.ndz);

	setfiletime(argv[2], argv[1]);

	/*
	 * Set the modtime of the signature file to match that of the image.
	 * This is a crude (but fast!) method for matching images with
	 * signatures.
	 */
	setfiletime(new.sigfile, argv[2]);
    } else {
	fprintf(stderr, "Images %s and %s are identical, no image produced!\n",
		argv[0], argv[1]);
	ndz_close(base.ndz);
	ndz_close(delta.ndz);
	unlink(argv[2]);
	if (usesigfile)
	    unlink(new.sigfile);
	ndz_close(new.ndz);
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
