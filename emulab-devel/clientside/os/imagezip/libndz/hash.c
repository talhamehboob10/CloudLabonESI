/*
 * Copyright (c) 2014-2015 University of Utah and the Flux Group.
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

/*
 * Hashing-related functions.
 */

#include <unistd.h>
#include <stdlib.h>
#include <stdio.h>
#include <fcntl.h>
#include <string.h>
#include <errno.h>
#include <assert.h>
#include <sys/stat.h>
#include <sys/time.h>
#include <openssl/md5.h>
#include <openssl/sha.h>

#include "libndz.h"

//#define COMPDELTA_DEBUG

char *
ndz_hash_dump(unsigned char *h, int hlen)
{
	static char hbuf[HASH_MAXSIZE*2+1];
	static const char hex[] = "0123456789abcdef";
	int i;

	for (i = 0; i < hlen; i++) {
		hbuf[i*2] = hex[h[i] >> 4];
		hbuf[i*2+1] = hex[h[i] & 0xf];
	}
	hbuf[i*2] = '\0';
	return hbuf;
}

static void
printhashdata(struct ndz_rangemap *map, void *ptr)
{
    struct ndz_hashdata *h = ptr;

    /* upper bit of chunkno indicates chunkrange */
    if (HASH_CHUNKDOESSPAN(h->chunkno)) {
	int chunkno = HASH_CHUNKNO(h->chunkno);
	printf("chunkno=%d-%d, ", chunkno, chunkno + 1);
    } else
	printf("chunkno=%d, ", (int)h->chunkno);
    printf("hash=%s", ndz_hash_dump(h->hash, h->hashlen));
}

void
ndz_hashmap_dump(struct ndz_rangemap *map, int summaryonly)
{
    if (map)
	ndz_rangemap_dump(map, summaryonly, printhashdata);
}

void
ndz_hash_data(struct ndz_file *ndz, unsigned char *data, unsigned long count,
	      unsigned char *hash)
{
    assert(ndz != NULL && ndz->hashtype != 0);
    assert(data != NULL && hash != NULL);

    if (ndz->hashtype == HASH_TYPE_SHA1)
	SHA1(data, count, hash);
    else if (ndz->hashtype == HASH_TYPE_MD5)
	MD5(data, count, hash);
}


/*
 * Read the hash info from a signature file into a region map associated
 * with the ndz file.
 */
struct ndz_rangemap *
ndz_readhashinfo(struct ndz_file *ndz, char *sigfile)
{
    struct hashinfo hi;
    struct hashregion hr;
    int fd, cc, rv, i;
    unsigned hashlen, blksize, hashtype;
    struct ndz_rangemap *map;
    struct ndz_hashdata *hashdata = NULL;
    unsigned lhblock;
#if 0
    unsigned lstart, lsize;
#endif

    if (ndz == NULL || sigfile == NULL)
	return NULL;
    if (ndz->hashmap)
	return ndz->hashmap;

    fd = open(sigfile, O_RDONLY);
    if (fd < 0) {
	perror(sigfile);
	return NULL;
    }
    cc = read(fd, &hi, sizeof(hi));
    if (cc != sizeof(hi)) {
	if (cc < 0)
	    perror(sigfile);
	else
	    fprintf(stderr, "%s: too short\n", sigfile);
	close(fd);
	return NULL;
    }
    if (strcmp((char *)hi.magic, HASH_MAGIC) != 0 ||
	!(hi.version == HASH_VERSION_1 || hi.version == HASH_VERSION_2)) {
	fprintf(stderr, "%s: not a valid signature file\n", sigfile);
	close(fd);
	return NULL;
    }

    map = ndz_rangemap_init(NDZ_LOADDR, NDZ_HIADDR-NDZ_LOADDR);
    if (map == NULL) {
	fprintf(stderr, "%s: could not allocate rangemap\n",
		ndz->fname);
	close(fd);
	return NULL;
    }

    /* allocate the hash data elements all in one piece for convienience */
    if (hi.nregions) {
	hashdata = malloc(hi.nregions * sizeof(struct ndz_hashdata));
	if (hashdata == NULL) {
	    fprintf(stderr, "%s: could not allocate hashmap data\n",
		    ndz->fname);
	    close(fd);
	    return NULL;
	}
    }

    hashtype = hi.hashtype;
    hashlen = (hashtype == HASH_TYPE_MD5) ? 16 : 20;
    blksize = (hi.version == HASH_VERSION_1) ?
	(HASHBLK_SIZE / ndz->sectsize) : hi.blksize;

    lhblock = -1;
    for (i = 0; i < hi.nregions; i++) {
	cc = read(fd, &hr, sizeof(hr));
	if (cc != sizeof(hr)) {
	    fprintf(stderr, "%s: incomplete sig entry\n", sigfile);
	    free(hashdata);
	    close(fd);
	    return NULL;
	}
	hashdata[i].chunkno = hr.chunkno;
	hashdata[i].hashlen = hashlen;
	memcpy(hashdata[i].hash, hr.hash, HASH_MAXSIZE);

#if 0
	/* Sanity check the ranges */
	if (1) {
	    unsigned sb = hr.region.start / blksize;
	    unsigned eb = (hr.region.start+hr.region.size-1) / blksize;
	    if (sb != eb)
		fprintf(stderr, "*** [%u-%u]: range spans hash blocks\n",
			hr.region.start, hr.region.start+hr.region.size-1);
	    if (sb == lhblock)
		fprintf(stderr, "*** [%u-%u]: range in same hash block ([%u-%u]) as [%u-%u]\n",
			hr.region.start, hr.region.start+hr.region.size-1,
			sb*blksize, sb*blksize+blksize-1,
			lstart, lstart+lsize-1);
	    lhblock = sb;
	    lstart = hr.region.start;
	    lsize = hr.region.size;
	}
#endif

	rv = ndz_rangemap_alloc(map, (ndz_addr_t)hr.region.start,
				(ndz_size_t)hr.region.size,
				(void *)&hashdata[i]);
	if (rv) {
	    fprintf(stderr, "%s: bad hash region [%u-%u]\n",
		    ndz->fname,
		    (unsigned)hr.region.start,
		    (unsigned)hr.region.start+hr.region.size-1);
	    ndz_rangemap_deinit(map);
	    free(hashdata);
	    close(fd);
	    return NULL;
	}
    }
    close(fd);

    ndz->hashmap = map;
    ndz->hashentries = hi.nregions;
    ndz->hashcurentry = ndz->hashentries;
    ndz->hashdata = hashdata;
    ndz->hashblksize = blksize;
    ndz->hashtype = hashtype;

    return map;
}

static int
writehinfo(struct ndz_rangemap *map, struct ndz_range *range, void *arg)
{
    struct hashregion hr;
    struct ndz_hashdata *hd = range->data;
    int ofd = (int)(uintptr_t)arg;

    if (hd == NULL) {
	fprintf(stderr, "no hash info for range [%lu-%lu]\n",
		range->start, range->end);
	return 1;
    }
    assert(hd->hashlen <= HASH_MAXSIZE);

    hr.region.start = range->start;
    hr.region.size = range->end - range->start + 1;
    hr.chunkno = hd->chunkno;
    memcpy(hr.hash, hd->hash, hd->hashlen);
    if (hd->hashlen < HASH_MAXSIZE)
	memset(&hr.hash[hd->hashlen], 0, HASH_MAXSIZE - hd->hashlen);
    if (write(ofd, &hr, sizeof(hr)) != sizeof(hr))
	return 1;

    return 0;
}

/*
 * Write out hash (signature) info associated with the named image.
 */
int
ndz_writehashinfo(struct ndz_file *ndz, char *sigfile, char *ifile)
{
    int ofd, cc;
    struct hashinfo hi;

    if (ndz == NULL || ndz->hashmap == NULL || sigfile == NULL)
	return -1;

    ofd = open(sigfile, O_RDWR|O_CREAT|O_TRUNC, 0666);
    if (ofd < 0) {
	perror(sigfile);
	return -1;
    }

    if (ifile == NULL)
	ifile = ndz->fname;

    memset(&hi, 0, sizeof(hi));
    strcpy((char *)hi.magic, HASH_MAGIC);
    hi.version = HASH_VERSION_2;
    hi.hashtype = ndz->hashtype;
    hi.nregions = ndz->hashentries;
    hi.blksize = ndz->hashblksize;

    cc = write(ofd, &hi, sizeof(hi));
    if (cc != sizeof(hi)) {
	if (cc < 0)
	    perror(sigfile);
	else
	    fprintf(stderr,
		    "%s: incomplete write (%d) to sigfile %s\n",
		    ifile, cc, sigfile);
	close(ofd);
	unlink(sigfile);
	return -1;
    }

    /*
     * Iterate over the sigmap writing out the entries
     */
    if (ndz_rangemap_iterate(ndz->hashmap, writehinfo,
			     (void *)(uintptr_t)ofd) != 0) {
	fprintf(stderr,
		"%s: could not write one or more hash entries to sigfile %s\n",
		ifile, sigfile);
	close(ofd);
	unlink(sigfile);
	return -1;
    }

    close(ofd);

    /*
     * Set the modtime of the hash file to match that of the image.
     * This is a crude (but fast!) method for matching images with
     * signatures.
     */
    if (strcmp(ifile, "-") != 0) {
	struct stat sb;
	struct timeval tm[2];

	cc = stat(ifile, &sb);
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
	    cc = utimes(sigfile, tm);
	}
	if (cc < 0)
	    fprintf(stderr,
		    "%s: WARNING: could not set mtime (%s)\n",
		    sigfile, strerror(errno));
    }

    fprintf(stderr, "%s: new signature written to %s\n", ifile, sigfile);
    return 0;
}

void
ndz_freehashmap(struct ndz_file *ndz)
{
    if (ndz->hashmap) {
	ndz_rangemap_deinit(ndz->hashmap);
	ndz->hashmap = NULL;
    }
    if (ndz->hashdata) {
	free(ndz->hashdata);
	ndz->hashdata = NULL;
	ndz->hashentries = 0;
    }
    ndz->hashblksize = 0;
}

struct deltainfo {
    struct ndz_file *ndz;
    struct ndz_rangemap *omap;
    struct ndz_rangemap *dmap;
    int omapdone;
};

/*
 * Compute a "reasonably accurate" delta given the hash maps of two
 * images. Where hash ranges of the two maps exactly overlap, we can
 * use the hashes to determine whether to include the range. Otherwise,
 * if they partially overlap, we just include the entirety of the new
 * range, rather than determining the exact sets of overlaps and computing
 * hashes on those.
 *
 * Why is this "reasonably accurate"? Since these are hash maps, no range
 * is larger than hashblksize sectors (typically 128 sectors), so any single
 * partial overlap will be contained in a small area. Worst case scenario
 * is that one sector has been added or removed from each hashblksize range.
 * This would cause us to create a full image. 
 */
static int
compfastdelta(struct ndz_rangemap *nmap, struct ndz_range *range, void *arg)
{
    struct deltainfo *dinfo = arg;
    struct ndz_rangemap *omap = dinfo->omap;
    struct ndz_rangemap *dmap = dinfo->dmap;
    ndz_addr_t addr, eaddr;
    struct ndz_range *orange, *oprev;
    struct ndz_hashdata *odata, *ndata;
    int rv;

    addr = range->start;
    eaddr = range->end;

#ifdef COMPDELTA_DEBUG
    fprintf(stderr, "compdelta [%lu-%lu]:\n", addr, eaddr);
#endif

    /*
     * We are past the end of the old map. Just allocate the range in
     * the merge map and continue.
     */
    if (dinfo->omapdone) {
#ifdef COMPDELTA_DEBUG
	fprintf(stderr, "  already finished old map, adding\n");
#endif
	rv = ndz_rangemap_alloc(dmap, addr, eaddr-addr+1, NULL);
	assert(rv == 0);
	return 0;
    }

    /*
     * Look up the corresponding start address in the old map.
     */
    orange = ndz_rangemap_lookup(omap, addr, &oprev);
    if (orange == NULL) {
	/*
	 * Start address was not found. If we are at the end of the
	 * old list, then there can be no overlap with any following
	 * entries so we just add this range. As an optimization,
	 * we also note that we have finished with the old map so
	 * that we will just add all following new map entries.
	 */
	if (oprev == NULL)
	    oprev = &omap->head;
	if ((orange = oprev->next) == NULL) {
#ifdef COMPDELTA_DEBUG
	    fprintf(stderr, "  past end of old map, adding\n");
#endif
	    rv = ndz_rangemap_alloc(dmap, addr, eaddr-addr+1, NULL);
	    assert(rv == 0);
	    dinfo->omapdone = 1;
	    return 0;
	}
	/*
	 * Likewise, if the start address of the next old range entry
	 * is beyond our end address, there is no overlap.
	 */
	if (orange->start > eaddr) {
#ifdef COMPDELTA_DEBUG
	    fprintf(stderr, "  no overlap with old map, adding\n");
#endif
	    rv = ndz_rangemap_alloc(dmap, addr, eaddr-addr+1, NULL);
	    assert(rv == 0);
	    return 0;
	}
    } else {
	/*
	 * Start address was found. Check for an exact overlap, in
	 * which case we can just compare the hashes to determine
	 * whether to add the range or not.
	 */
	if (addr == orange->start && eaddr == orange->end) {
#ifdef COMPDELTA_DEBUG
	    fprintf(stderr, "  exact overlap with old map, ");
#endif

	    /*
	     * XXX if the sector range includes a relocation,
	     * we always force it into the image.
	     */
	    if (dinfo->ndz->relocdata &&
		ndz_reloc_inrange(dinfo->ndz, addr, eaddr-addr+1)) {
#ifdef COMPDELTA_DEBUG
		fprintf(stderr, "has relocation, adding\n");
#endif
		rv = ndz_rangemap_alloc(dmap, addr, eaddr-addr+1, NULL);
		assert(rv == 0);
		return 0;
	    }

	    odata = orange->data;
	    ndata = range->data;
	    assert(odata->hashlen == ndata->hashlen);
	    if (memcmp(odata->hash, ndata->hash, ndata->hashlen) != 0) {
#ifdef COMPDELTA_DEBUG
		fprintf(stderr, "hash differs, adding\n");
#endif
		rv = ndz_rangemap_alloc(dmap, addr, eaddr-addr+1, NULL);
		assert(rv == 0);
		return 0;
	    }
#ifdef COMPDELTA_DEBUG
	    fprintf(stderr, "hash same, skipping\n");
#endif
	    return 0;
	}
    }

    /*
     * If we get here, some portion of the new range overlaps with
     * one or more old ranges. We just have to add the whole range
     * since we don't have comparible hashes.
     */
#ifdef COMPDELTA_DEBUG
    fprintf(stderr, "  partial overlap with oldrange [%lu-%lu], adding\n",
	    orange->start, orange->end);
#endif
    rv = ndz_rangemap_alloc(dmap, addr, eaddr-addr+1, NULL);
    assert(rv == 0);

    return 0;
}

struct ndz_rangemap *
ndz_compute_delta(struct ndz_file *ondz, struct ndz_file *nndz)
{
    struct ndz_rangemap *omap, *nmap, *dmap;
    struct deltainfo dinfo;

    if (ondz == NULL || (omap = ondz->rangemap) == NULL ||
	nndz == NULL || (nmap = nndz->rangemap) == NULL)
	return NULL;

    if (omap == NULL || nmap == NULL)
	return NULL;

    dmap = ndz_rangemap_init(nmap->loaddr, nmap->hiaddr);
    if (dmap == NULL) {
	fprintf(stderr, "Could not allocate delta map\n");
	return NULL;
    }

    dinfo.ndz = nndz;
    dinfo.omap = omap;
    dinfo.dmap = dmap;
    dinfo.omapdone = 0;
#if 0
    (void) ndz_rangemap_iterate(nmap, compdelta, &dinfo);
#endif

    return dmap;
}

/*
 * This is much easier as we don't need to hash anything or worry about
 * computing hash alignments.
 */
struct ndz_rangemap *
ndz_compute_delta_sigmap(struct ndz_file *ondz, struct ndz_file *nndz)
{
    struct ndz_rangemap *omap, *nmap, *dmap;
    struct deltainfo dinfo;

    if (ondz == NULL || (omap = ondz->hashmap) == NULL ||
	nndz == NULL || (nmap = nndz->hashmap) == NULL)
	return NULL;

    dmap = ndz_rangemap_init(nmap->loaddr, nmap->hiaddr);
    if (dmap == NULL) {
	fprintf(stderr, "Could not allocate delta map\n");
	return NULL;
    }

    dinfo.ndz = nndz;
    dinfo.omap = omap;
    dinfo.dmap = dmap;
    dinfo.omapdone = 0;
    (void) ndz_rangemap_iterate(nmap, compfastdelta, &dinfo);

    return dmap;
}

/*
 * Local variables:
 * mode: C
 * c-set-style: "BSD"
 * c-basic-offset: 4
 * End:
 */
