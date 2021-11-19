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
#include <unistd.h>
#include <stdlib.h>
#include <stdio.h>
#include <fcntl.h>
#include <string.h>
#include <errno.h>
#include <assert.h>
#include <sys/stat.h>

#include "libndz.h"

//#define CHUNK_DEBUG
//#define CHUNKMAP_DEBUG

#ifndef USE_CHUNKMAP
/*
 * Find the first range for a particular chunk.
 *
 * XXX awkward because we need to pass in the chunkno and return the
 * range entry. We could do this just using the arg pointer, but let's
 * be a little less obscure!
 */
struct fcarg {
    ndz_chunkno_t in_chunkno;
    struct ndz_range *out_range;
};

static int
findchunk(struct ndz_rangemap *map, struct ndz_range *range, void *arg)
{
    struct fcarg *fcarg = arg;

    if ((uintptr_t)range->data == fcarg->in_chunkno) {
	fcarg->out_range = range;
	return 1;
    }
    return 0;
}
#endif

/*
 * Read uncompessed data from an imagefile.
 *
 * Return as many contiguous sectors as it can get at the indicated location,
 * or an error if there are no data at the indicated location.
 */
ndz_size_t
ndz_readdata(struct ndz_file *ndz, void *buf, ndz_size_t nsect, ndz_addr_t sect)
{
    ndz_addr_t ssect, esect, csect, resect;
    struct ndz_range *range, *crange;
    ndz_chunkno_t chunkno, lchunkno;
    ndz_chunk_t chunk;
    ssize_t rbytes, cc;
#ifdef USE_CHUNKMAP
    struct ndz_range *prev;
#endif

    if (ndz->rangemap == NULL && ndz_readranges(ndz) == NULL) {
	fprintf(stderr, "%s could not read sector ranges\n", ndz->fname);
	return -1;
    }

    /*
     * Find the range entry corresponding to the desired offset.
     * If the offset isn't included in the image, return zero.
     */
    ssect = sect;
    esect = sect + nsect;
    range = ndz_rangemap_lookup(ndz->rangemap, ssect, NULL);
    if (range == NULL)
	return 0;

    chunkno = (uintptr_t)range->data;
    assert(chunkno > 0);
    chunkno--;

    /*
     * If we already have a decompression object for the chunk, see if it is
     * currently before the sector we want. If so, we can just continue
     * decompression in the context of that stream.
     */
#ifdef STATS
    ndz->chunkuses++;
#endif
    chunk = ndz->chunkobj;
    if (chunk && ndz_chunk_chunkno(chunk) == chunkno &&
	ndz->chunksect <= ssect) {
#ifdef CHUNK_DEBUG
	fprintf(stderr, "%s: reusing chunk %d object, sect=%ld\n",
		ndz->fname, chunkno, ndz->chunksect);
#endif
	csect = ndz->chunksect;
	if (csect == ssect)
	    crange = range;
	else {
	    crange = ndz_rangemap_lookup(ndz->rangemap, csect, NULL);
	    assert(crange != NULL);
	}
#ifdef STATS
	ndz->chunkhits++;
#endif
    }
    /*
     * Otherwise we have to open a new stream and work forward from the
     * first range entry in that chunk.
     */
    else {
	if (chunk && ndz_chunk_chunkno(chunk) == chunkno &&
	    ndz_chunk_rewind(chunk) == 0) {
#ifdef CHUNK_DEBUG
	    fprintf(stderr, "%s: reopened current chunk %d object, sect=%ld;"
		    " requesting sect=%ld\n",
		    ndz->fname, chunkno, ndz->chunksect, ssect);
#endif
#ifdef STATS
	    ndz->chunkreopens++;
#endif
	    ;
	}
	else {
	    if (chunk) {
#ifdef CHUNK_DEBUG
		fprintf(stderr, "%s: could not reuse chunk %d object, sect=%ld;"
			" requesting chunk %d, sect=%ld\n",
			ndz->fname, ndz_chunk_chunkno(chunk), ndz->chunksect,
			chunkno, ssect);
#endif
		ndz_chunk_close(chunk);
	    }
	    chunk = ndz->chunkobj = ndz_chunk_open(ndz, chunkno);
	    if (chunk == NULL) {
		fprintf(stderr, "%s: could not access chunk %d\n",
			ndz->fname, chunkno);
		return -1;
	    }
	}

#ifdef USE_CHUNKMAP
	assert(chunkno < ndz->chunkmapentries);
	csect = ndz->chunkmap[chunkno].losect;
	crange = ndz_rangemap_lookup(ndz->rangemap, csect, &prev);
	if (crange == NULL) {
	    if (prev == NULL)
		crange = ndz_rangemap_first(ndz->rangemap);
	    else
		crange = prev->next;
	    assert(crange != NULL);
	}
	csect = crange->start;
	assert(csect <= ndz->chunkmap[chunkno].hisect);
#ifdef CHUNKMAP_DEBUG
	fprintf(stderr, "lookup chunk %u range [%lu-%lu] returns %lu\n",
		chunkno, ndz->chunkmap[chunkno].losect,
		ndz->chunkmap[chunkno].hisect, csect);
#endif
#else
	{
	    struct fcarg fcarg;

	    /* note: chunk numbers are 1-based in range map */
	    fcarg.in_chunkno = chunkno + 1;
	    fcarg.out_range = NULL;
	    (void) ndz_rangemap_iterate(ndz->rangemap, findchunk, &fcarg);
	    crange = fcarg.out_range;
	    assert(crange != NULL);
	    csect = crange->start;
	}
#endif
	ndz->chunksect = csect;
#ifdef CHUNK_DEBUG
	fprintf(stderr, "%s: (re)opened chunk %d object, sect=%ld\n",
		ndz->fname, chunkno, ndz->chunksect);
#endif
    }
    assert(csect <= ssect);

    /*
     * Read/uncompress data til we get to the desired start sector.
     */
    if (csect < ssect) {
	size_t tossbufsize = 128 * 1024;
	char *tossbuf;

	tossbuf = malloc(tossbufsize);
	if (tossbuf == NULL) {
	    fprintf(stderr, "%s: could not allocate toss buffer\n",
		    ndz->fname);
	    ndz_chunk_close(chunk);
	    ndz->chunkobj = NULL;
	    return -1;
	}

	while (csect < ssect) {
	    /*
	     * If we are not in the target range yet, we may need to
	     * decompress our way through a number of other ranges in
	     * the same chunk til we get where we need to be.
	     */
	    if (range != crange) {
		assert(crange->end < ssect);
		resect = crange->end + 1;
	    } else
		resect = ssect;
	    rbytes = (resect - csect) * ndz->sectsize;
	    if (rbytes > tossbufsize)
		rbytes = tossbufsize;
	    cc = ndz_chunk_read(chunk, tossbuf, rbytes);
	    if (cc != rbytes) {
		fprintf(stderr,
			"%s: unexpected return from ndz_chunk_read (%ld != %lu)\n",
			ndz->fname, (long)cc, (long unsigned)rbytes);
		ndz_chunk_close(chunk);
		ndz->chunkobj = NULL;
		return -1;
	    }
	    csect += (cc / ndz->sectsize);
	    if (range != crange && csect == crange->end + 1) {
		assert(crange->next != NULL);
		crange = crange->next;
		csect = crange->start;
	    }
	    ndz->chunksect = csect;
	}
    }
    
    lchunkno = chunkno;
    while (ssect < esect) {
	resect = range->end + 1;
	if (esect < resect)
	    resect = esect;
	rbytes = (resect - ssect) * ndz->sectsize;
	cc = ndz_chunk_read(chunk, buf, rbytes);
	if (cc != rbytes) {
	    fprintf(stderr,
		    "%s: unexpected return from ndz_chunk_read (%ld != %lu)\n",
		    ndz->fname, (long)cc, (long unsigned)rbytes);
	    ndz_chunk_close(chunk);
	    ndz->chunkobj = NULL;
	    return -1;
	}
	ndz->chunksect = resect;
	ssect = resect;
	buf += rbytes;

	/*
	 * Our request might span ranges and even chunks.
	 */
	if (ssect < esect && ssect == range->end + 1) {
	    range = range->next;
	    /*
	     * If we hit the end of the file, chunk, or just the
	     * end of contiguous data, return what we read.
	     */
	    if (range == NULL || range->start != ssect) {
#ifdef CHUNK_DEBUG
		fprintf(stderr, "%s: hit end-of-%s\n",
			ndz->fname, range ? "contiguous-data" : "file");
#endif
		if (range)
		    ndz->chunksect = range->start;
		else {
		    ndz_chunk_close(chunk);
		    ndz->chunkobj = NULL;
		}
		return (ssect - sect);
	    }
	    chunkno = (uintptr_t)range->data;
	    assert(chunkno != 0);
	    chunkno--;
	    if (chunkno != lchunkno) {
		assert(chunkno == lchunkno + 1);
#ifdef CHUNK_DEBUG
		fprintf(stderr, "%s: finished chunk %d, opening chunk %d, sect=%ld\n",
			ndz->fname, lchunkno, chunkno, range->start);
#endif
		ndz_chunk_close(chunk);
		chunk = ndz->chunkobj = ndz_chunk_open(ndz, chunkno);
		if (chunk == NULL) {
		    fprintf(stderr, "%s: could not access chunk %d\n",
			    ndz->fname, chunkno);
		    return -1;
		}
		ndz->chunksect = range->start;
		lchunkno = chunkno;
	    }
	}
    }

    /*
     * We could have ended at the end of a range or even the end
     * of the chunk. Adjust chunksect accordingly.
     */
    assert(ssect == esect);
    if (ssect == range->end + 1) {
	if (range->next)
	    ndz->chunksect = range->next->start;
	else {
	    ndz_chunk_close(chunk);
	    ndz->chunkobj = NULL;
	}
    }

    return (ssect - sect);
}

#ifdef NDZDATA_TEST

static int
readrange(struct ndz_rangemap *map, struct ndz_range *range, void *arg)
{
    static char dbuf[1*1024*1024];
    struct ndz_file *ndz = arg;
    ndz_addr_t ssect, rsize;
    ndz_size_t sc, exsc;

    /* just read up to 1M of every range */
    ssect = range->start;
    rsize = range->end + 1 - range->start;
    if (rsize > sizeof(dbuf) / ndz->sectsize)
	rsize = sizeof(dbuf) / ndz->sectsize;
    exsc = rsize;
    sc = ndz_readdata(ndz, dbuf, rsize, ssect);
#if 1
    fprintf(stderr,
	    "  read [%lu-%lu] from [%d:%lu-%lu] returned %ld of %lu sectors\n",
	    ssect, ssect+rsize-1, (int)range->data, range->start, range->end,
	    (long)sc, exsc);
#endif
    if (sc != exsc) {
	fprintf(stderr, "*** short read!\n");
	return 1;
    }

    /* try spanning the end of the range and see what we get */
    if (range->next) {
	rsize = sizeof(dbuf) / ndz->sectsize;
	ssect = range->end - rsize / 2;
	if (ssect < range->start)
	    ssect = range->start;
	exsc = range->end + 1 - ssect;
	if (range->end + 1 == range->next->start) {
	    exsc += range->next->end + 1 - range->next->start;
	    if (exsc > rsize)
		exsc = rsize;
	}
	sc = ndz_readdata(ndz, dbuf, rsize, ssect);
#if 0
	fprintf(stderr,
		"  read [%lu-%lu] from [%d:%lu-%lu][%d:%lu-%lu] returned %lu of %lu sectors\n",
		ssect, ssect+rsize-1,
		(int)range->data, range->start, range->end,
		(int)range->next->data, range->next->start, range->next->end,
		sc, exsc);
#endif
	if (sc != exsc) {
	    fprintf(stderr, "*** short read!\n");
	    return 1;
	}
    }
    return 0;
}

int
main(int argc, char **argv)
{
    struct ndz_file *ndz;
    struct ndz_rangemap *map;
    char buf[SECSIZE];
    ssize_t cc;

    if (argc != 2) {
	fprintf(stderr, "%s <ndzfile>\n", argv[0]);
	exit(1);
    }
    
    fprintf(stderr, "%s: opening ...\n", argv[1]);
    ndz = ndz_open(argv[1], 0);
    assert(ndz != NULL);
    fprintf(stderr, "%s: reading ranges ...\n", argv[1]);
    map = ndz_readranges(ndz);
    assert(map != NULL);

    /* for now just make sure we can read all data */
    fprintf(stderr, "%s: testing data reads (could take minutes) ...\n", argv[1]);
    cc = ndz_rangemap_iterate(map, readrange, ndz);
    if (cc != 0)
	fprintf(stderr, "%s: FAILED\n", argv[1]);

#ifdef STATS
    fprintf(stderr, "Chunk object uses %u, hits %u (%.2f%%), reopens %u (%.2f%%)\n",
	    ndz->chunkuses, ndz->chunkhits,
	    (double)ndz->chunkhits / (ndz->chunkuses ?: 1) * 100,
	    ndz->chunkreopens,
	    (double)ndz->chunkreopens / (ndz->chunkuses ?: 1) * 100);
#endif
    if (ndz->chunkobj)
	ndz_chunk_close(ndz->chunkobj);
    ndz_close(ndz);
    exit(0);
}
#endif

/*
 * Local variables:
 * mode: C
 * c-set-style: "BSD"
 * c-basic-offset: 4
 * End:
 */
