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
 * Chunk-oriented IO routines.
 *
 * Since chunks are independently compressed, we can manipulate them
 * independently.
 */

#include <unistd.h>
#include <stdlib.h>
#include <stdio.h>
#include <fcntl.h>
#include <string.h>
#include <errno.h>
#include <assert.h>
#include <zlib.h>
#include <sys/stat.h>

#include "libndz.h"

//#define CHUNK_DEBUG

/*
 * Currently we use the "classic" imagezip algorithm for filling chunks.
 *
 * 1. Before we even try compressing data, we make sure there is at least
 *    (request_size + 1000) bytes available, where request_size is the
 *    UNCOMPRESSED size.
 * 2. After a compression is done, there needs to be at least 8K left, or
 *    we call it a day.
 */
#define CHUNKSLOP	1000
#define CHUNKTHRESH	8192

struct ndz_chunk {
    struct ndz_file *ndz;
    ndz_chunkno_t chunkno;
    off_t foff;
    z_stream z;
    int clevel;
    /* buffer stuff */
    char *cbufbase;	/* allocated memory */
    blockhdr_t *cbufhdr;/* (aligned) chunk header location */
    char *cbufdata;	/* (aligned) chunk data location */
    int cbufsize;	/* size of data portion */
    int cbufoff;	/* high-water mark of valid data */
    int cbufleft;	/* write: space left to fill */
};

int
getchunkbuffer(struct ndz_chunk *chunk)
{
    int psize = getpagesize();
    uintptr_t ptr;

    chunk->cbufbase = malloc(CHUNKSIZE + psize);
    if (chunk->cbufbase == NULL)
	return -1;

    ptr = (((uintptr_t)chunk->cbufbase + psize - 1) & ~(psize - 1));
    chunk->cbufhdr = (blockhdr_t *)ptr;
    chunk->cbufdata = (char *)(ptr + DEFAULTREGIONSIZE);
    chunk->cbufsize = CHUNKSIZE - DEFAULTREGIONSIZE;
    chunk->cbufoff = 0;
    chunk->cbufleft = chunk->cbufsize;

    return 0;
}

ndz_chunk_t
ndz_chunk_open(struct ndz_file *ndz, ndz_chunkno_t chunkno)
{
    struct ndz_chunk *chunk = malloc(sizeof *chunk);
    if (chunk == NULL)
	return NULL;

#ifdef CHUNK_DEBUG
    fprintf(stderr, "%s: chunk_open called\n", ndz->fname);
#endif
    if (getchunkbuffer(chunk)) {
	free(chunk);
	return NULL;
    }

    chunk->ndz = ndz;
    chunk->chunkno = chunkno;
    chunk->z.zalloc = Z_NULL;
    chunk->z.zfree = Z_NULL;
    chunk->z.opaque = Z_NULL;
    chunk->z.next_in = Z_NULL;
    chunk->z.avail_in = 0;
    chunk->z.next_out = Z_NULL;
    if (inflateInit(&chunk->z) != Z_OK) {
	free(chunk);
	return NULL;
    }
    chunk->foff = (off_t)chunkno * ndz->chunksize + DEFAULTREGIONSIZE;

    /*
     * XXX currently we use ndzfile::ndz_readchunkheader for read access to the
     * chunk header. It is better for applications that don't need access to the
     * decompressed data, since it won't drag in libz as use of functions in this
     * file would.
     */
    chunk->cbufhdr = NULL;

    return (ndz_chunk_t)chunk;
}

int
ndz_chunk_rewind(ndz_chunk_t chobj)
{
    struct ndz_chunk *chunk = (struct ndz_chunk *)chobj;
    if (chunk == NULL || chunk->cbufbase == NULL)
	return -1;

    if (inflateReset(&chunk->z) != Z_OK) {
	fprintf(stderr, "chunk_rewind: could not reset zlib state\n");
	return -1;
    }

    chunk->z.next_in = (Bytef *)chunk->cbufdata;
    chunk->z.avail_in = chunk->cbufoff;

    return 0;
}

void
ndz_chunk_close(ndz_chunk_t chobj)
{
    struct ndz_chunk *chunk = (struct ndz_chunk *)chobj;
    if (chunk == NULL)
	return;

#ifdef CHUNK_DEBUG
    fprintf(stderr, "%s: chunk_close called\n", chunk->ndz->fname);
#endif
    inflateEnd(&chunk->z);

    if (chunk->cbufbase)
	free(chunk->cbufbase);
    free(chunk);
}

ndz_chunkno_t
ndz_chunk_chunkno(ndz_chunk_t chobj)
{
    struct ndz_chunk *chunk = (struct ndz_chunk *)chobj;
    if (chunk == NULL)
	return ~0;

    return chunk->chunkno;
}

blockhdr_t *
ndz_chunk_header(ndz_chunk_t chobj)
{
    struct ndz_chunk *chunk = (struct ndz_chunk *)chobj;
    if (chunk == NULL)
	return NULL;

    return chunk->cbufhdr;
}

ssize_t
ndz_chunk_datasize(ndz_chunk_t chobj)
{
    struct ndz_chunk *chunk = (struct ndz_chunk *)chobj;
    if (chunk == NULL)
	return -1;

    return chunk->cbufoff;
}

/*
 * Sequentially read data from a chunk til there is no more to be read
 */
ssize_t
ndz_chunk_read(ndz_chunk_t chobj, void *buf, size_t bytes)
{
    int rv;
    ssize_t cc;

    struct ndz_chunk *chunk = (struct ndz_chunk *)chobj;
    if (chunk == NULL)
	return -1;

#ifdef CHUNK_DEBUG
    fprintf(stderr, "%s: chunk_read called\n", chunk->ndz->fname);
#endif

    chunk->z.next_out = (Bytef *)buf;
    chunk->z.avail_out = bytes;
    while (chunk->z.avail_out > 0) {
	/* read more compressed data from file if necessary */
	if (chunk->z.avail_in == 0) {
	    cc = ndz_read(chunk->ndz, chunk->cbufdata + chunk->cbufoff,
			  chunk->cbufsize - chunk->cbufoff, chunk->foff);
#ifdef CHUNK_DEBUG
	    fprintf(stderr, "chunk_read: reading %d bytes at %lu returns %ld\n",
		    chunk->cbufsize - chunk->cbufoff,
		    (unsigned long)chunk->foff, cc);
#endif
	    if (cc <= 0)
		return cc;
	    chunk->z.next_in = (Bytef *)(chunk->cbufdata + chunk->cbufoff);
	    chunk->z.avail_in = cc;
	    chunk->cbufoff += cc;
	    chunk->foff += cc;
	}
	assert(chunk->z.next_in != Z_NULL);
	assert(chunk->z.avail_in > 0);

	rv = inflate(&chunk->z, Z_SYNC_FLUSH);

	if (rv == Z_STREAM_END) {
#ifdef CHUNK_DEBUG
	    fprintf(stderr, "chunk_read hit STREAM_END at foff=%ld, avail_out=%d\n",
		    (unsigned long)chunk->foff, chunk->z.avail_out);
#endif
	    break;
	}

	if (rv != Z_OK) {
	    fprintf(stderr, "%s: inflate failed, rv=%d\n",
		    chunk->ndz->fname, rv);
	    return -1;
	}
    }

    return (bytes - chunk->z.avail_out);
}

/*
 * XXX for now the write functions are distinct from the read functions
 * til I decide if it is worthwhile to combine.
 */
ndz_chunk_t
ndz_chunk_create(struct ndz_file *ndz, ndz_chunkno_t chunkno, int clevel)
{
    struct ndz_chunk *chunk = malloc(sizeof *chunk);
    if (chunk == NULL)
	return NULL;

#ifdef CHUNK_DEBUG
    fprintf(stderr, "%s: chunk_create called\n", chunk->ndz->fname);
#endif
    if (getchunkbuffer(chunk)) {
	free(chunk);
	return NULL;
    }
    memset(chunk->cbufhdr, 0, DEFAULTREGIONSIZE);

    chunk->clevel = clevel;
    chunk->ndz = ndz;
    chunk->chunkno = chunkno;
    chunk->z.zalloc = Z_NULL;
    chunk->z.zfree = Z_NULL;
    chunk->z.opaque = Z_NULL;
    if (deflateInit(&chunk->z, chunk->clevel) != Z_OK) {
	free(chunk);
	return NULL;
    }
    chunk->foff = (off_t)chunkno * ndz->chunksize + DEFAULTREGIONSIZE;

    return (ndz_chunk_t)chunk;
}

int
ndz_chunk_flush(ndz_chunk_t chobj, int withheader)
{
    struct ndz_chunk *chunk = (struct ndz_chunk *)chobj;
    char *buf = chunk->cbufdata;
    size_t count = chunk->cbufsize;
    off_t off = chunk->foff;
    ssize_t cc;

    if (chunk == NULL)
	return -1;

#ifdef CHUNK_DEBUG
    fprintf(stderr, "%s: chunk_flush called\n", chunk->ndz->fname);
#endif

    /*
     * XXX there can be some compressed data left even though we use Z_SYNC_FLUSH.
     * So use Z_FINISH to clear the pipes.
     */

    /* XXX fix up cbufleft since we might have zeroed it in chunk_append */
    chunk->cbufleft = CHUNKSIZE - DEFAULTREGIONSIZE - chunk->cbufoff;
    assert(chunk->cbufleft > 0);

    chunk->z.next_in   = 0;
    chunk->z.avail_in  = 0;
    chunk->z.next_out = (Bytef *)(chunk->cbufdata + chunk->cbufoff);
    chunk->z.avail_out = chunk->cbufleft;

    cc = deflate(&chunk->z, Z_FINISH);
    if (cc != Z_STREAM_END) {
	fprintf(stderr, "chunk_flush: deflate(FINISH) failed, rv=%ld\n", cc);
	return -1;
    }
    if (chunk->z.avail_out == 0) {
	fprintf(stderr,
		"chunk_flush: too much data for chunk; "
		"recompile with larger CHUNKSLOP and try again!\n");
	return -1;
    }
    chunk->cbufoff += (chunk->cbufleft - chunk->z.avail_out);
    chunk->cbufleft = chunk->z.avail_out;
#ifdef CHUNK_DEBUG
    fprintf(stderr, "%s: chunk_flush: %d bytes left in chunk\n",
	    chunk->ndz->fname, chunk->cbufleft);
#endif

    /*
     * XXX XXX horrible horrible hack alert!!!
     * Touch up the header if we are writing it out.
     */
    if (withheader && chunk->cbufhdr->magic > COMPRESSED_V1)
	chunk->cbufhdr->size = chunk->cbufoff;

    /* XXX if nothing has been appended, don't write anything */
    if (chunk->cbufoff > 0 || withheader) {
	/* params are setup by default for no header write, adjust */
	if (withheader) {
	    buf = (char *)chunk->cbufhdr;
	    count += DEFAULTREGIONSIZE;
	    off -= DEFAULTREGIONSIZE;
	}

	/* zero the remaining portion of the chunk data buffer */
	memset(chunk->cbufdata + chunk->cbufoff, 0, chunk->cbufleft);

	cc = ndz_write(chunk->ndz, buf, count, off);
	if (cc != count) {
	    fprintf(stderr,
		    "chunk_flush: failed to write entire chunk (%ld of %lu)\n",
		    cc, count);
	    return -1;
	}
    }

    if (deflateEnd(&chunk->z) != Z_OK) {
	fprintf(stderr, "chunk_flush: deflateEnd failed\n");
	return -1;
    }

    if (chunk->cbufbase)
	free(chunk->cbufbase);
    free(chunk);

    return 0;
}

/*
 * Returns the amount of uncompressed data that the chunk object will
 * accept in an ndz_chunk_append operation. Zero indicates that it is
 * time to flush.
 */
ssize_t
ndz_chunk_left(ndz_chunk_t chobj)
{
    ssize_t remain;

    struct ndz_chunk *chunk = (struct ndz_chunk *)chobj;
    if (chunk == NULL)
	return -1;

    remain = chunk->cbufleft - CHUNKSLOP;
    return (remain > 0 ? remain : 0);
}

/*
 * Compress and append data to a chunk.
 *
 * Writes are all-or-nothing, returns zero if the full write cannot be done.
 * It is up to the caller to use ndz_chunk_left and resize accordingly.
 */
ssize_t
ndz_chunk_append(ndz_chunk_t chobj, void *buf, size_t bytes)
{
    int rv;

    struct ndz_chunk *chunk = (struct ndz_chunk *)chobj;
    if (chunk == NULL || chunk->ndz == NULL)
	return -1;

    if ((bytes % chunk->ndz->sectsize) != 0) {
	fprintf(stderr, "chunk_append: write not multiple of sector size\n");
	return -1;
    }

    if (bytes == 0 || bytes > chunk->cbufleft - CHUNKSLOP)
	return 0;

    chunk->z.next_in = (Bytef *)buf;
    chunk->z.avail_in = bytes;
    chunk->z.next_out = (Bytef *)(chunk->cbufdata + chunk->cbufoff);
    chunk->z.avail_out = chunk->cbufleft;
    rv = deflate(&chunk->z, Z_SYNC_FLUSH);
    if (rv != Z_OK) {
	fprintf(stderr, "chunk_append: deflate failed, rv=%d\n", rv);
	return -1;
    }
    if (chunk->z.avail_out == 0) {
	fprintf(stderr,
		"chunk_append: too much data for chunk; "
		"recompile with larger CHUNKSLOP and try again!\n");
	return -1;
    }
    assert(chunk->z.avail_in == 0);

    chunk->cbufoff += (chunk->cbufleft - chunk->z.avail_out);
    chunk->cbufleft = chunk->z.avail_out;
    if (chunk->cbufleft < CHUNKTHRESH)
	chunk->cbufleft = 0;

    return (bytes - chunk->z.avail_in);
}

/*
 * Local variables:
 * mode: C
 * c-set-style: "BSD"
 * c-basic-offset: 4
 * End:
 */
