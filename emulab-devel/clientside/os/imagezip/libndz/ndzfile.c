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

//#define CHUNKMAP_DEBUG

struct ndz_file *
ndz_open(const char *name, int forwrite)
{
    struct ndz_file *ndz = calloc(1, sizeof(struct ndz_file));
    int fd;
    ssize_t cc;
    char buf[DEFAULTREGIONSIZE];
    blockhdr_t *hdr;
    unsigned int magic;

    if (strcmp(name, "-") == 0) {
	fd = forwrite ? fileno(stdout) : fileno(stdin);
	name = forwrite ? "<STDOUT>" : "<STDIN>";
    } else {
	int flags = forwrite ? (O_WRONLY|O_CREAT|O_TRUNC) : (O_RDONLY);
	fd = open(name, flags, 0666);
	if (fd < 0) {
	    perror(name);
	    goto fail;
	}
	ndz->flags |= NDZ_FILE_SEEKABLE;
    }
    ndz->fd = fd;
    ndz->curoff = 0;
    if (forwrite)
	ndz->flags |= NDZ_FILE_WRITE;

    /*
     * It should have at least one chunk header. Read that and verify
     * what we can.
     */
    if (!forwrite) {
#if 0
	/* XXX use this instead */
	cc = ndz_readchunkheader(ndz, 0, buf);
#else
	cc = ndz_read(ndz, buf, sizeof buf, 0);
#endif
	if (cc < 0) {
	    perror(name);
	    goto fail;
	}
	if (cc != sizeof buf) {
	    fprintf(stderr, "%s: short read, got %d, expected %d\n",
		    name, (int)cc, (int)sizeof buf);
	    goto fail;
	}

	hdr = (blockhdr_t *)buf;

	magic = hdr->magic;
	if (magic < COMPRESSED_MAGIC_BASE ||
	    magic > COMPRESSED_MAGIC_CURRENT) {
	    fprintf(stderr, "%s: bad version 0x%x, not an ndz file?\n",
		    name, magic);
	    goto fail;
	}
    }

    /* XXX hardwired right now */
    ndz->sectsize = SECSIZE;
    ndz->chunksize = CHUNKSIZE;

    ndz_reloc_init(ndz);

    /*
     * XXX someday check checksum if present and stash info to check
     * in every chunk header.
     */
    ndz->fname = strdup(name);
    return ndz;

 fail:
    free(ndz);
    return NULL;
}

int
ndz_close(struct ndz_file *ndz)
{
    int rv;

    if (ndz == NULL)
	return -1;

    rv = close(ndz->fd);
    if (rv == 0) {
	ndz_reloc_free(ndz);
	if (ndz->hashmap)
	    ndz_rangemap_deinit(ndz->hashmap);
	if (ndz->rangemap)
	    ndz_rangemap_deinit(ndz->rangemap);
#ifdef USE_CHUNKMAP
	if (ndz->chunkmap)
	    free(ndz->chunkmap);
#endif
	if (ndz->fname)
	    free(ndz->fname);
	free(ndz);
    }
    return rv;
}

char *
ndz_filename(struct ndz_file *ndz)
{
    return ndz ? ndz->fname : NULL;
}

ssize_t
ndz_read(struct ndz_file *ndz, void *buf, size_t bytes, off_t offset)
{
    size_t count = bytes;
    char *bp = buf;

    if (ndz == NULL) {
	errno = EINVAL;
	return -1;
    }
    if ((ndz->flags & NDZ_FILE_WRITE) != 0) {
	errno = EACCES;
	return -1;
    }

    if ((ndz->flags & NDZ_FILE_SEEKABLE) != 0) {
	if (lseek(ndz->fd, offset, SEEK_SET) < 0)
	    return -1;
    } else {
	if (offset != ndz->curoff) {
	    fprintf(stderr, "%s: non-contiguous read on unseekable input.\n",
		    ndz->fname);
	    errno = ESPIPE;
	    return -1;
	}
    }

    /*
     * We might be reading from stdin or a pipe, so we may not get the
     * entire amount in one operation. Keep reading til EOF or we get
     * it all.
     */
    while (count) {
	int cc;

	if ((cc = read(ndz->fd, bp, count)) <= 0) {
	    if (cc == 0)
		break;

	    return -1;
	}
	count -= cc;
	bp += cc;
    }

    ndz->curoff += (bytes - count);
    return bytes - count;
}

int
ndz_readahead(struct ndz_file *ndz, void *buf, size_t bytes, off_t offset)
{
    return ENOTSUP;
}

/*
 * Explicitly initialize the rangemap for a file.
 * Returns a pointer to the rangemap or NULL on error.
 */
struct ndz_rangemap *
ndz_readranges(struct ndz_file *ndz)
{
    struct ndz_rangemap *map;
    struct ndz_chunkhdr head;
    blockhdr_t *hdr;
    struct region *reg;
    int rv, i;
    ndz_chunkno_t chunkno;
    ndz_addr_t first = 0, last = 0;
#ifdef USE_CHUNKMAP
    struct stat sb;
#endif

    if (ndz == NULL || (ndz->flags & NDZ_FILE_WRITE) != 0)
	return NULL;
    if (ndz->rangemap)
	return ndz->rangemap;

    map = ndz_rangemap_init(NDZ_LOADDR, NDZ_HIADDR-NDZ_LOADDR);
    if (map == NULL) {
	fprintf(stderr, "%s: could not allocate rangemap\n",
		ndz->fname);
	return NULL;
    }

#ifdef USE_CHUNKMAP
    /*
     * See if we can fstat the input so that we only have to do
     * one allocation for the chunkmap.
     */
    if (fstat(ndz->fd, &sb) == 0 && sb.st_size > 0) {
	ndz->chunkmapentries = (sb.st_size + CHUNKSIZE - 1) / CHUNKSIZE;
	ndz->chunkmap = malloc(ndz->chunkmapentries *
			       sizeof(ndz->chunkmap[0]));
	if (ndz->chunkmap == NULL) {
	    fprintf(stderr, "%s: could not allocate chunkmap\n",
		    ndz->fname);
	    ndz->chunkmapentries = 0;
	    ndz_rangemap_deinit(map);
	    return NULL;
	}
#ifdef CHUNKMAP_DEBUG
	fprintf(stderr, "allocated chunkmap of %lu bytes for %u chunks\n",
		ndz->chunkmapentries * sizeof(ndz->chunkmap[0]),
		ndz->chunkmapentries);
#endif
    }
#endif

    /*
     * Read the header of each chunk adding regions to the map.
     */
    for (chunkno = 0; ; chunkno++) {
#ifdef USE_CHUNKMAP
	ndz_addr_t clo = 0, chi = 0;
#endif

	rv = ndz_readchunkheader(ndz, chunkno, &head);
	if (rv)
	    return NULL;

	/* null header pointer indicates EOF */
	if ((hdr = head.header) == NULL)
	    break;

	if (hdr->magic != COMPRESSED_V1) {
	    if (chunkno == 0)
		first = hdr->firstsect;
	    last = hdr->lastsect - 1;
#ifdef USE_CHUNKMAP
	    clo = hdr->firstsect;
	    chi = hdr->lastsect - 1;
#endif
	}

	/* get the regions */
	reg = head.region;
	assert(reg != NULL || hdr->regioncount == 0);
	for (i = 0; i < hdr->regioncount; i++) {
	    if (hdr->magic == COMPRESSED_V1) {
		if (chunkno == 0)
		    first = (ndz_addr_t)reg->start;
		last = (ndz_addr_t)reg->start + (ndz_size_t)reg->size - 1;
#ifdef USE_CHUNKMAP
		if (i == 0)
		    clo = (ndz_addr_t)reg->start;
		chi = last;
#endif
	    }
	    rv = ndz_rangemap_alloc(map,
				    (ndz_addr_t)reg->start,
				    (ndz_size_t)reg->size,
				    (void *)(uintptr_t)(chunkno+1));
	    if (rv) {
		fprintf(stderr, "%s: bad region [%u-%u]\n",
			ndz->fname,
			(unsigned)reg->start,
			(unsigned)reg->start+reg->size-1);
		ndz_rangemap_deinit(map);
		return NULL;
	    }
	    reg++;
	}

#ifdef USE_CHUNKMAP
	if (chunkno >= ndz->chunkmapentries) {
	    assert(chunkno == ndz->chunkmapentries);
	    ndz->chunkmap = realloc(ndz->chunkmap,
				    (chunkno+1)*sizeof(ndz->chunkmap[0]));
	    if (ndz->chunkmap == NULL) {
		fprintf(stderr, "%s: could not allocate chunkmap entry\n",
			ndz->fname);
		ndz->chunkmapentries = 0;
		ndz_rangemap_deinit(map);
		return NULL;
	    }
	    ndz->chunkmapentries = chunkno + 1;
	}
#ifdef CHUNKMAP_DEBUG
	fprintf(stderr, "chunkmap[%u]: [%lu-%lu]\n", chunkno, clo, chi);
#endif
	ndz->chunkmap[chunkno].losect = clo;
	ndz->chunkmap[chunkno].hisect = chi;
#endif

	/* get the relocations */
	if (head.reloc) {
	    if (ndz_reloc_get(ndz, head.header, head.reloc) != 0) {
		fprintf(stderr, "%s: could not add relocations\n",
			ndz->fname);
#ifdef USE_CHUNKMAP
		if (ndz->chunkmap) {
		    free(ndz->chunkmap);
		    ndz->chunkmap = NULL;
		    ndz->chunkmapentries = 0;
		}
#endif
		ndz_rangemap_deinit(map);
		return NULL;
	    }
	}
    }

    ndz->maplo = first;
    ndz->maphi = last;
    ndz->rangemap = map;
    return map;
}

int
ndz_readchunkheader(struct ndz_file *ndz, ndz_chunkno_t chunkno,
		    struct ndz_chunkhdr *chunkhdr)
{
    ssize_t cc;
    blockhdr_t *hdr;
    struct region *reg;
    struct blockreloc *rel;

    if (ndz == NULL || (ndz->flags & NDZ_FILE_WRITE) != 0)
	return -1;

    cc = ndz_read(ndz, chunkhdr->data, sizeof chunkhdr->data,
		  (off_t)chunkno * ndz->chunksize);
    if (cc != sizeof chunkhdr->data) {
	/* EOF: return null header pointer */
	if (cc == 0) {
	    chunkhdr->header = NULL;
	    return 0;
	}
	if (cc < 0)
	    return errno;
	fprintf(stderr, "%s: short read, got %d, expected %d\n",
		ndz->fname, (int)cc, (int)sizeof chunkhdr->data);
	return -1;
    }
    hdr = (blockhdr_t *)chunkhdr->data;
    switch (hdr->magic) {
    case COMPRESSED_V1:
	reg = (struct region *)((struct blockhdr_V1 *)hdr + 1);
	rel = NULL;
	break;
    case COMPRESSED_V2:
    case COMPRESSED_V3:
	reg = (struct region *)((struct blockhdr_V2 *)hdr + 1);
	rel = (struct blockreloc *)(reg + hdr->regioncount);
	break;
    case COMPRESSED_V4:
	reg = (struct region *)((struct blockhdr_V4 *)hdr + 1);
	rel = (struct blockreloc *)(reg + hdr->regioncount);
	break;
    default:
	fprintf(stderr, "%s: bad version 0x%x, not an ndz file?\n",
		ndz->fname, hdr->magic);
	return -1;
    }
    chunkhdr->header = hdr;
    chunkhdr->region = hdr->regioncount ? reg : NULL;
    chunkhdr->reloc = (rel != NULL && hdr->reloccount) ? rel : NULL;

    return 0;
}

ssize_t
ndz_write(struct ndz_file *ndz, void *buf, size_t bytes, off_t offset)
{
    size_t count = bytes;
    char *bp = buf;

    if (ndz == NULL) {
	errno = EINVAL;
	return -1;
    }
    if ((ndz->flags & NDZ_FILE_WRITE) == 0) {
	errno = EACCES;
	return -1;
    }

    if ((ndz->flags & NDZ_FILE_SEEKABLE) != 0) {
	if (lseek(ndz->fd, offset, SEEK_SET) < 0)
	    return -1;
    } else {
	if (offset != ndz->curoff) {
	    fprintf(stderr, "%s: non-contiguous write on unseekable output.\n",
		    ndz->fname);
	    errno = ESPIPE;
	    return -1;
	}
    }

    /*
     * We might be writing to stdout or a pipe, so we may not put the
     * entire amount in one operation. Keep writing til we get EOF,
     * an error, or we put it all.
     */
    while (count) {
	int cc;

	if ((cc = write(ndz->fd, bp, count)) <= 0) {
	    if (cc == 0)
		break;

	    return -1;
	}
	count -= cc;
	bp += cc;
    }

    ndz->curoff += (bytes - count);
    return bytes - count;
}

static int
printrange(struct ndz_rangemap *map, struct ndz_range *range, void *arg)
{
    printf("  [%lu - %lu], chunk=%lu\n",
	   range->start, range->end, (uintptr_t)range->data - 1);
    return 0;
}

void
ndz_dumpranges(struct ndz_rangemap *map)
{
    ndz_rangemap_iterate(map, printrange, NULL);
}

#ifdef NDZFILE_TEST

int
main(int argc, char **argv)
{
    struct ndz_file *ndz;
    struct ndz_rangemap *map;
    int rv;

    if (argc != 2) {
	fprintf(stderr, "%s <ndzfile>\n", argv[0]);
	exit(1);
    }
    
    ndz = ndz_open(argv[1], 0);
    map = ndz_readranges(ndz);
    if (map == NULL) {
	fprintf(stderr, "Could not read ranges from %s\n", argv[1]);
	ndz_close(ndz);
	exit(1);
    }
    
    ndz_dumpranges(map);
    ndz_rangemap_deinit(map);
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
