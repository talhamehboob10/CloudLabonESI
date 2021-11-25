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
 * Relocation handling routines.
 *
 * We just associate an array of blockreloc structs with the NDZ file
 * to keep track of these. This is good enough since there are not ever
 * very many relocs and they are almost always in the first chunk.
 *
 * Note that I originally used a rangemap, but there can be more than
 * one reloc per sector so that doesn't work.
 */

#include <unistd.h>
#include <stdlib.h>
#include <stdio.h>
#include <fcntl.h>
#include <string.h>
#include <errno.h>
#include <assert.h>

#include "libndz.h"

#define RELOC_DEBUG

void
ndz_reloc_init(struct ndz_file *ndz)
{
    assert(ndz != NULL);

    ndz->relocdata = NULL;
    ndz->relocentries = 0;
    ndz->reloclo = NDZ_HIADDR;
    ndz->relochi = NDZ_LOADDR;
}

/*
 * Read relocs out of a chunk header and add them to the array of relocs
 * for the file, reallocing the buffer as necessary. Not terrible efficient,
 * but does not have to be.
 */ 
int
ndz_reloc_get(struct ndz_file *ndz, blockhdr_t *hdr, void *buf)
{
    struct blockreloc *relocdata, *chunkreloc = buf;
    int i;

    if (ndz == NULL || hdr == NULL || chunkreloc == NULL)
	return -1;

    if (hdr->magic < COMPRESSED_V2 || hdr->reloccount == 0)
	return 0;

    /* resize the relocation buffer */
    i = ndz->relocentries + hdr->reloccount;
    if (ndz->relocdata == NULL)
	relocdata = malloc(i * sizeof(struct blockreloc));
    else
	relocdata = realloc(ndz->relocdata, i * sizeof(struct blockreloc));
    if (relocdata == NULL) {
	ndz_reloc_free(ndz);
	return -1;
    }
    ndz->relocdata = relocdata;

    relocdata = (struct blockreloc *)ndz->relocdata + ndz->relocentries;
    for (i = 0; i < hdr->reloccount; i++) {
	if (ndz->reloclo == NDZ_HIADDR)
	    ndz->reloclo = chunkreloc->sector;
	/* XXX we should be adding these in order; we assume this elsewhere */
	assert(ndz->reloclo <= chunkreloc->sector);
	if (chunkreloc->sector > ndz->relochi)
	    ndz->relochi = chunkreloc->sector;

	*relocdata++ = *chunkreloc++;
    }
    ndz->relocentries += hdr->reloccount;

#ifdef RELOC_DEBUG
    if (hdr->reloccount > 0) {
	fprintf(stderr, "got %d relocs, %d total, range [%lu-%lu]\n",
		hdr->reloccount, ndz->relocentries,
		ndz->reloclo, ndz->relochi);
    }
#endif

    return 0;
}

/*
 * Find any relocation entries that apply to the indicated chunk and add them.
 */
int
ndz_reloc_put(struct ndz_file *ndz, blockhdr_t *hdr, void *buf)
{
    struct blockreloc *chunkreloc, *relocdata;
    int i;

    if (ndz == NULL || hdr == NULL || buf == NULL)
	return -1;

    if (ndz->relocentries == 0 ||
	hdr->firstsect > ndz->relochi || hdr->lastsect <= ndz->reloclo)
	return 0;

    chunkreloc = buf;
    relocdata = ndz->relocdata;
    for (i = 0; i < ndz->relocentries; i++) {
	assert(relocdata->sectoff + relocdata->size <= ndz->sectsize);
	if (relocdata->sector >= hdr->firstsect &&
	    relocdata->sector < hdr->lastsect) {
#ifdef RELOC_DEBUG
	    fprintf(stderr, "found reloc for %u in chunk range [%u-%u]\n",
		    relocdata->sector, hdr->firstsect, hdr->lastsect - 1);
#endif
	    *chunkreloc++ = *relocdata;
	}
	relocdata++;
    }

    return 0;
}

/*
 * Returns the number of relocations in the indicated range, 0 otherwise
 * If size is zero, count til the end.
 */
int
ndz_reloc_inrange(struct ndz_file *ndz, ndz_addr_t addr, ndz_size_t size)
{
    struct blockreloc *relocdata;
    ndz_addr_t eaddr;
    int i, nreloc = 0;

    assert(ndz != NULL);

    if (size == 0)
	eaddr = (ndz->relochi > addr) ? ndz->relochi : addr;
    else
	eaddr = addr + size - 1;
    if (ndz->relocentries == 0 || addr > ndz->relochi || eaddr < ndz->reloclo)
	return 0;

    relocdata = ndz->relocdata;
    for (i = 0; i < ndz->relocentries; i++) {
	assert(relocdata->sectoff + relocdata->size <= ndz->sectsize);
	if (relocdata->sector > eaddr)
	    break;
	if (relocdata->sector >= addr && relocdata->sector <= eaddr) {
	    nreloc++;
	}
	relocdata++;
    }
#ifdef RELOC_DEBUG
    if (nreloc)
	fprintf(stderr, "found %d relocs in range [%lu-%lu]\n",
		nreloc, addr, eaddr);
#endif
    return nreloc;
}

/*
 * Reloc info is small so this is relatively painless
 */
int
ndz_reloc_copy(struct ndz_file *ndzfrom, struct ndz_file *ndzto)
{
    size_t size;

    if (ndzfrom == NULL || ndzto == NULL || ndzto->relocentries > 0)
	return -1;

    if (ndzfrom->relocentries == 0)
	return 0;

    size = ndzfrom->relocentries * sizeof(struct blockreloc);
    if ((ndzto->relocdata = malloc(size)) == NULL)
	return -1;

    memcpy(ndzto->relocdata, ndzfrom->relocdata, size);
    ndzto->relocentries = ndzfrom->relocentries;
    ndzto->reloclo = ndzfrom->reloclo;
    ndzto->relochi = ndzfrom->relochi;
    return 0;
}

void
ndz_reloc_free(struct ndz_file *ndz)
{
    if (ndz) {
	if (ndz->relocdata) {
	    free(ndz->relocdata);
	    ndz->relocdata = NULL;
	}
	ndz->relocentries = 0;
    }
}

/*
 * Local variables:
 * mode: C
 * c-set-style: "BSD"
 * c-basic-offset: 4
 * End:
 */
