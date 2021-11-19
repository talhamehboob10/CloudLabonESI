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
#ifndef _NDZ_RANGEMAP_H_
#define	_NDZ_RANGEMAP_H_

#include <inttypes.h>

#define NDZ_RANGEMAP_STATS

typedef uint64_t ndz_addr_t;
typedef uint64_t ndz_size_t;

#define NDZ_LOADDR ((uint64_t)0)
#define NDZ_HIADDR (~((uint64_t)0))

#ifdef NDZ_RANGEMAP_STATS
struct ndz_rangemap_stats {
    unsigned lookups;
    unsigned hits;
    unsigned onehops;
    unsigned fullscans;
    unsigned entriesscanned;
};
#endif

struct ndz_range {
    struct ndz_range *next;		/* must be first */
    ndz_addr_t start;
    ndz_addr_t end;
    void *data;
};

struct ndz_rangemap {
    struct ndz_range head;
    struct ndz_range **hint;
    ndz_addr_t loaddr;
    ndz_addr_t hiaddr;
    uint64_t gen;
    ndz_size_t entries;
    ndz_size_t sectors;
#ifdef NDZ_RANGEMAP_STATS
    struct ndz_rangemap_stats stats;
#endif
};

struct ndz_rangemap *ndz_rangemap_init(ndz_addr_t loaddr, ndz_addr_t hiaddr);
void ndz_rangemap_deinit(struct ndz_rangemap *map);
int ndz_rangemap_alloc(struct ndz_rangemap *map,
		       ndz_addr_t addr, ndz_size_t size, void *data);
int ndz_rangemap_dealloc(struct ndz_rangemap *map,
			 ndz_addr_t addr, ndz_size_t size);
int ndz_rangemap_iterate(struct ndz_rangemap *map,
			 int (*ifunc)(struct ndz_rangemap *,
				      struct ndz_range *,
				      void *),
			 void *arg);
struct ndz_range *ndz_rangemap_first(struct ndz_rangemap *map);
struct ndz_range *ndz_rangemap_last(struct ndz_rangemap *map);
ndz_size_t ndz_rangemap_entries(struct ndz_rangemap *map);
ndz_size_t ndz_rangemap_sectors(struct ndz_rangemap *map);
struct ndz_range *ndz_rangemap_lookup(struct ndz_rangemap *map,
				      ndz_addr_t addr,
				      struct ndz_range **prev);
struct ndz_range *ndz_rangemap_overlap(struct ndz_rangemap *map,
				       ndz_addr_t addr, ndz_size_t);
void ndz_rangemap_dump(struct ndz_rangemap *map, int summaryonly,
		       void (*dfunc)(struct ndz_rangemap *, void *));
void ndz_rangemap_dumpstats(struct ndz_rangemap *map);

struct ndz_range *ndz_range_alloc(void);
void ndz_range_free(struct ndz_range *entry);

#define ndz_range_start(r)	(r)->start
#define ndz_range_end(r)	((r)->start + (r)->size)
#define ndz_range_size(r)	(r)->size

#endif /* _NDZ_RANGEMAP_H_ */

/*
 * Local variables:
 * mode: C
 * c-set-style: "BSD"
 * c-basic-offset: 4
 * End:
 */
