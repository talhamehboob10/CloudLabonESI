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

#ifndef _LIBNDZ_H_
#define	_LIBNDZ_H_

#define USE_CHUNKMAP

#include "imagehdr.h"
#include "imagehash.h"
#include "rangemap.h"

typedef uint32_t ndz_chunkno_t;
/* XXX keep this opaque so we don't create dependencies on zlib */
typedef void * ndz_chunk_t;

struct ndz_hashdata {
    ndz_chunkno_t chunkno;
    uint32_t hashlen;
    uint8_t hash[HASH_MAXSIZE];
};

struct ndz_bounds {
    ndz_addr_t losect;
    ndz_addr_t hisect;
};

struct ndz_file {
    int fd;
    int flags;
    off_t curoff;
    char *fname;
    int sectsize;
    int chunksize;
    ndz_chunkno_t nchunks;
    ndz_addr_t maplo, maphi;
    struct ndz_rangemap *rangemap;
#ifdef USE_CHUNKMAP
    /* map of chunks to covered ranges */
    ndz_chunkno_t chunkmapentries;
    struct ndz_bounds *chunkmap;
#endif
    /* chunk object info */
    ndz_chunk_t chunkobj;
    ndz_addr_t chunksect;
    unsigned chunkuses;
    unsigned chunkhits;
    unsigned chunkreopens;
    /* relocation information */
    unsigned relocentries;
    void *relocdata;
    ndz_addr_t reloclo, relochi;
    /* hash (signature) info */
    unsigned hashtype;
    unsigned hashblksize;
    unsigned hashentries;
    unsigned hashcurentry;
    struct ndz_hashdata *hashdata;
    struct ndz_rangemap *hashmap;
    /* per-chunk info to verify */
    /* readahead cache stuff */
};

/* flags */
#define NDZ_FILE_WRITE		1
#define NDZ_FILE_SEEKABLE	2

struct ndz_chunkhdr {
    blockhdr_t *header;
    struct region *region;
    struct blockreloc *reloc;
    char data[DEFAULTREGIONSIZE];
};

struct ndz_file *ndz_open(const char *name, int flags);
int ndz_close(struct ndz_file *ndz);
char *ndz_filename(struct ndz_file *ndz);
ssize_t ndz_read(struct ndz_file *ndz, void *buf, size_t bytes, off_t offset);
ssize_t ndz_write(struct ndz_file *ndz, void *buf, size_t bytes, off_t offset);
int ndz_readahead(struct ndz_file *ndz, void *buf, size_t bytes, off_t offset);

int ndz_readchunkheader(struct ndz_file *ndz, ndz_chunkno_t chunkno,
			struct ndz_chunkhdr *chunkhdr);
ndz_size_t ndz_readdata(struct ndz_file *ndz, void *buf, ndz_size_t nsect,
			ndz_addr_t sect);
struct ndz_rangemap *ndz_readranges(struct ndz_file *ndz);
void ndz_dumpranges(struct ndz_rangemap *map);

ndz_chunk_t ndz_chunk_open(struct ndz_file *ndz, ndz_chunkno_t chunkno);
int ndz_chunk_rewind(ndz_chunk_t chobj);
void ndz_chunk_close(ndz_chunk_t chobj);
ssize_t ndz_chunk_read(ndz_chunk_t chobj, void *buf, size_t bytes);
ndz_chunkno_t ndz_chunk_chunkno(ndz_chunk_t chobj);
blockhdr_t *ndz_chunk_header(ndz_chunk_t chobj);
ssize_t ndz_chunk_datasize(ndz_chunk_t chobj);
ndz_chunk_t ndz_chunk_create(struct ndz_file *ndz, ndz_chunkno_t chunkno,
			     int clevel);
int ndz_chunk_flush(ndz_chunk_t chobj, int withheader);
ssize_t ndz_chunk_left(ndz_chunk_t chobj);
ssize_t ndz_chunk_append(ndz_chunk_t chobj, void *buf, size_t bytes);

void ndz_reloc_init(struct ndz_file *ndz);
int ndz_reloc_get(struct ndz_file *ndz, blockhdr_t *hdr, void *buf);
int ndz_reloc_put(struct ndz_file *ndz, blockhdr_t *hdr, void *buf);
int ndz_reloc_inrange(struct ndz_file *ndz, ndz_addr_t addr, ndz_size_t size);
int ndz_reloc_copy(struct ndz_file *ndzfrom, struct ndz_file *ndzto);
void ndz_reloc_free(struct ndz_file *ndz);

struct ndz_rangemap *ndz_readhashinfo(struct ndz_file *ndz, char *sigfile);
int ndz_writehashinfo(struct ndz_file *ndz, char *sigfile, char *ifile);
void ndz_hash_data(struct ndz_file *ndz, unsigned char *data,
		   unsigned long count, unsigned char *hash);
char *ndz_hash_dump(unsigned char *h, int hlen);
void ndz_hashmap_dump(struct ndz_rangemap *map, int summaryonly);
struct ndz_rangemap *ndz_compute_delta(struct ndz_file *ondz,
				       struct ndz_file *nndz);
struct ndz_rangemap *ndz_compute_delta_sigmap(struct ndz_file *ondz,
					      struct ndz_file *nndz);

#endif /* _LIBNDZ_H_ */

/*
 * Local variables:
 * mode: C
 * c-set-style: "BSD"
 * c-basic-offset: 4
 * End:
 */
