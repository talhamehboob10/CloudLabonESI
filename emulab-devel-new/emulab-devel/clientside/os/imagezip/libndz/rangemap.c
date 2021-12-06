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
#include <stdlib.h>
#include <stdio.h>
#include <assert.h>
#include <errno.h>

#include "rangemap.h"

struct ndz_range *
ndz_range_alloc(void)
{
    return calloc(1, sizeof(struct ndz_range));
}

void
ndz_range_free(struct ndz_range *range)
{
    assert(range);
    free(range);
}

struct ndz_rangemap *
ndz_rangemap_init(ndz_addr_t lo, ndz_addr_t hi)
{
    struct ndz_rangemap *map = calloc(1, sizeof(*map));
    if (map != NULL) {
	map->loaddr = lo;
	map->hiaddr = hi;
	map->hint = &map->head.next;
	map->gen = 1;
	map->entries = 0;
	map->sectors = 0;
    }
    return map;
}

void
ndz_rangemap_deinit(struct ndz_rangemap *map)
{
    struct ndz_range *range, *next;

    if (map) {
	for (range = map->head.next; range; range = next) {
	    next = range->next;
	    ndz_range_free(range);
	}
	free(map);
    }
}

/*
 * Mark [addr - addr+size-1] as allocated in the indicated map.
 * Associate the given data with that address range, NULL if none.
 * Return zero on success, an error otherwise.
 * Errors:
 *  - map is invalid
 *  - range is malformed
 *  - part of range is outside of the bounds of the map
 *  - part of range is already allocated
 *  - out of memory
 *
 * Note: we optimize the map hint for repeated allocs of increasing
 * addresses.
 */
int
ndz_rangemap_alloc(struct ndz_rangemap *map, ndz_addr_t addr, ndz_size_t size,
		   void *data)
{
    struct ndz_range *prev, *range, *next;
    ndz_addr_t eaddr = addr + size - 1;
    int ishead = 0;

    if (map == NULL || eaddr < addr ||
	addr < map->loaddr || eaddr > map->hiaddr)
	return EINVAL;

    range = ndz_rangemap_lookup(map, addr, &prev);

    /* found the address: error */
    if (range)
	return EINVAL;

    /* if prev is null we are at the beginning, take note */
    if (prev == NULL) {
	prev = &map->head;
	next = prev->next;
	ishead = 1;

	/* list is empty, no further checks are necessary */
	if (next == NULL)
	    goto newone;
    } else
	next = prev->next;

    /* our range overlaps with the following range: error */
    if (next && eaddr >= next->start)
	return EINVAL;

    /*
     * If the range abuts the previous or next range, merge with one or
     * both to reduce the map size. Note that we only merge entries that
     * have NULL data pointers.
     */
    if (data == NULL &&
	((!ishead && prev->end + 1 == addr && prev->data == NULL) ||
	 (next && eaddr + 1 == next->start && next->data == NULL))) {
	if (!ishead && prev->end + 1 == addr) {
	    prev->end = eaddr;
	    if (next && prev->end + 1 == next->start) {
		prev->end = next->end;
		prev->next = next->next;
		ndz_range_free(next);
		map->entries--;
	    }
	    /* if hint currently points to prev, leave it */
	    if (*map->hint != prev)
		map->hint = &prev->next;
	} else if (next && eaddr + 1 == next->start) {
	    next->start = addr;
	    map->hint = &prev->next;
	}
	map->gen++;
	map->sectors += size;
	return 0;
    }

 newone:
    /* need a new range to put after current range */
    range = ndz_range_alloc();
    if (range == NULL)
	return ENOMEM;

    range->next = next;
    range->start = addr;
    range->end = eaddr;
    range->data = data;
    prev->next = range;
    map->hint = &prev->next;
    map->gen++;
    map->entries++;
    map->sectors += size;

    return 0;
}

/*
 * Mark [addr - addr+size-1] as unallocated in the indicated map.
 * Return zero on success, non-zero otherwise.
 * It is up to the caller to ensure that any associated data has been freed.
 * Errors:
 *  - map is invalid
 *  - range is malformed
 *  - part of range is outside of the bounds of the map
 *  - part of range is not allocated
 *  - out of memory
 *
 * Note: we optimize the map hint for deleting at increasing addresses.
 * I.e., it is left pointing to the entry following what was deleted.
 */
int
ndz_rangemap_dealloc(struct ndz_rangemap *map, ndz_addr_t addr, ndz_size_t size)
{
    struct ndz_range *prev, *range, *next;
    ndz_addr_t eaddr = addr + size - 1;

    if (map == NULL || eaddr < addr ||
	addr < map->loaddr || eaddr > map->hiaddr)
	return EINVAL;

    range = ndz_rangemap_lookup(map, addr, &prev);

    /*
     * If our range is not completely covered by the returned entry,
     * it is an error.
     */
    if (range == NULL || eaddr > range->end)
	return EINVAL;

    /*
     * XXX there must be no associated data right now
     */
    if (range->data)
	return EBUSY;

    /* if prev is null we are at the beginning, take note */
    if (prev == NULL)
	prev = &map->head;

    /*
     * If the dealloced range abuts the containing range at either the
     * beginning or end (or both), then we just need to adjust the
     * containing range (or delete it entirely).
     */
    if (range->start == addr) {
	/* both: delete range entirely */
	if (range->end == eaddr) {
	    prev->next = range->next;
	    ndz_range_free(range);
	    map->entries--;
	}
	/* otherwise increment start of containing range */
	else
	    range->start = eaddr + 1;
	map->hint = &prev->next;
	map->gen++;
	map->sectors -= size;

	return 0;
    }
    /* decrement end of containing range */
    if (range->end == eaddr) {
	range->end = addr - 1;
	map->hint = &prev->next;
	map->gen++;
	map->sectors -= size;

	return 0;
    }

    /*
     * If the dealloced range does not abut the containing range, we need to
     * split the containing range because we will wind up with two ranges
     * after the dealloc.
     */
    next = ndz_range_alloc();
    if (next == NULL)
	return ENOMEM;
    next->next = range->next;
    range->next = next;
    next->start = eaddr + 1;
    next->end = range->end;
    range->end = addr - 1;
    map->hint = &range->next;
    map->gen++;
    map->entries++;
    map->sectors -= size;

    return 0;
}

/*
 * Call an iteration function for each range in the map.
 * Iteration function should return non-zero to terminate the iteration.
 * Return zero if the entire map was traversed, or non-zero value returned
 * by iteration function otherwise.
 *
 * Note: we attempt to optimize any range operation in the iteration
 * function by pointing the map hint at the current range.
 */
int
ndz_rangemap_iterate(struct ndz_rangemap *map,
		     int (*ifunc)(struct ndz_rangemap *,
				  struct ndz_range *,
				  void *),
		     void *arg)
{
    int rv = 0;
    struct ndz_range *range, *prev;
    ndz_addr_t addr;
    uint64_t gen;

    map->hint = &map->head.next;
    for (range = map->head.next; range; range = range->next) {
	addr = range->end;
	gen = map->gen;
	rv = (*ifunc)(map, range, arg);
	if (rv)
	    break;
	/*
	 * Iteration function may have caused the current
	 * range to be deleted, split or joined with another.
	 * So we re-lookup the current range to get the correct
	 * next pointer.
	 */
	if (map->gen != gen) {
	    range = ndz_rangemap_lookup(map, addr, &prev);
	    if (range == NULL) {
		assert(prev == NULL || *map->hint == prev);
		range = prev ? prev : &map->head;
		if (range == NULL)
		    return -1;
	    }
	}
	map->hint = &range->next;
    }

    return rv;
}

/*
 * Return a pointer to the first entry in the map.
 * Returns NULL if map is empty.
 *
 * Does not affect the map hint.
 */
struct ndz_range *
ndz_rangemap_first(struct ndz_rangemap *map)
{
    return map->head.next;
}

/*
 * Return a pointer to the last entry in the map.
 * Returns NULL if map is empty.
 *
 * Does not affect the map hint.
 */
struct ndz_range *
ndz_rangemap_last(struct ndz_rangemap *map)
{
    struct ndz_range *range;

    /* start at the hint which is probably closer to the end */
    assert(map->hint != NULL);
    range = *map->hint;
    if (range == NULL)
	range = map->head.next;

    /* empty list */
    if (range == NULL)
	return NULL;

    while (range->next)
	range = range->next;

    return range;
}

/*
 * Return the number of entries in the map.
 *
 * Does not affect the map hint.
 */
ndz_size_t
ndz_rangemap_entries(struct ndz_rangemap *map)
{
    return map->entries;
}

/*
 * Return the number of sectors covered by the map.
 *
 * Does not affect the map hint.
 */
ndz_size_t
ndz_rangemap_sectors(struct ndz_rangemap *map)
{
    return map->sectors;
}

/*
 * Locate the indicated address in the map.
 * Returns the range containing the address if it is allocated, NULL ow.
 * If prev is non-NULL, it also returns a pointer to the entry preceeding
 * the indicated address, whether the address is found or not.
 * If NULL is returned for prev, then we are at the head of the list.
 *
 * Resulting map hint values:
 *   if range is found, hint points to it.
 *   if range is not found, hint points to previous range.
 *   if there is no previous range (i.e., at beginning of list), hint is null.
 * This optimizes the common cases where we insert after a failed lookup
 * or delete after a successful lookup.
 */
struct ndz_range *
ndz_rangemap_lookup(struct ndz_rangemap *map, ndz_addr_t addr,
		    struct ndz_range **prevp)
{
    struct ndz_range *prev, *range, **prange, **oprange;
#ifdef STATS
    int passes = 0;

    map->stats.lookups++;
#endif

    assert(map);

    prange = map->hint;
    assert(prange);

    /* Hint is at the end or address before hint, start at beginning. */
    if (*prange == NULL || addr < (*prange)->start) {
	prange = &map->head.next;
	/* We have an empty list */
	if (*prange == NULL) {
	    if (prevp)
		*prevp = NULL;
#ifdef STATS
	    map->stats.entriesscanned++;
	    map->stats.hits++;
#endif
	    map->hint = prange;

	    return NULL;
	}
#ifdef STATS
	map->stats.fullscans++;
#endif
    }

    oprange = NULL;
    while (1) {
#ifdef STATS
	map->stats.entriesscanned++;
#endif
	range = *prange;
	/*
	 * If address is allocated, it must be this entry.
	 */
	if (addr <= range->end) {
	    prev = (prange == &map->head.next) ?
		NULL : (struct ndz_range *)prange;

	    /* Not allocated, return NULL */
	    if (addr < range->start) {
		range = NULL;
		/* hint should point to prev entry if possible */
		if (oprange)
		    prange = oprange;
	    }

	    break;
	}

	/* Ran out of list, set prev to this entry and return NULL */
	if (range->next == NULL) {
	    prev = range;
	    range = NULL;
	    break;
	}

#ifdef STATS
	passes++;
#endif
	oprange = prange;
	prange = &range->next;
    }

#ifdef STATS
    if (passes == 0)
	map->stats.hits++;
    else if (passes == 1)
	map->stats.onehops++;
#endif
    map->hint = prange;

#if 1
    /*
     * Make sure the hint is pointing where it should:
     */
    if (range) {
	assert(*map->hint == range);
    } else if (prev) {
	assert(*map->hint == prev);
    }
#endif

    if (prevp)
	*prevp = prev;
    return range;
}

/*
 * Determine if the indicated range [addr - addr+size-1] overlaps with
 * any entry in the given map. Returns a pointer to the first map entry
 * that overlaps, or NULL if there is no overlap.
 *
 * Resulting map hint values:
 *   if range is found, hint points to it.
 *   if range is not found, hint is unaffected.
 */
struct ndz_range *
ndz_rangemap_overlap(struct ndz_rangemap *map, ndz_addr_t addr,
		     ndz_size_t size)
{
    struct ndz_range *range, *prev;
    ndz_addr_t eaddr = addr + size - 1;

    /*
     * Lookup the first address in the range.
     * If it falls within a range in the map, we are done.
     * Otherwise look for overlap with the following map entry.
     */
    range = ndz_rangemap_lookup(map, addr, &prev);
    if (range == NULL) {
	/* if prev is null we are at the beginning */
	if (prev == NULL)
	    range = map->head.next;
	else
	    range = prev->next;

	/*
	 * At the end of the map, there can be no overlap.
	 */
	if (range == NULL)
	    return NULL;

	/*
	 * If our range ends before the next element in the list,
	 * there is no overlap.
	 */
	if (eaddr < range->start)
	    return NULL;
    }

    return range;
}

void
ndz_rangemap_dumpstats(struct ndz_rangemap *map)
{
#ifdef STATS
	printf("\t%d lookups, %d hits, %d one-scans, %d full-scans, %d entries scanned\n",
	       map->stats.lookups, map->stats.hits, map->stats.onehops,
	       map->stats.fullscans, map->stats.entriesscanned);
#endif
}

void
ndz_rangemap_dump(struct ndz_rangemap *map, int summaryonly,
		  void (*dfunc)(struct ndz_rangemap *, void *))
{
    struct ndz_range *range;
    unsigned long elements = 0;
    int nrange = 0;

    printf("MAP: %p (hint=%p, gen=%lu, entries=%lu, sectors=%lu)\n",
	   map, map->hint, map->gen, map->entries, map->sectors);
    ndz_rangemap_dumpstats(map);
    for (range = map->head.next; range; range = range->next) {
	if (!summaryonly) {
	    printf("\t%c[%lu - %lu]",
		   *map->hint == range ? '*' : ' ',
		   (unsigned long)range->start, (unsigned long)range->end);
	    if (range->data) {
		printf(", ");
		if (dfunc)
		    (*dfunc)(map, range->data);
		else
		    printf("data=%p", range->data);
	    }
	    putchar('\n');
	}
	elements += (range->end - range->start + 1);
	nrange++;
    }
    assert(nrange == map->entries);
    assert(elements == map->sectors);
}

#ifdef RANGEMAP_TEST
int verbose = 1;

int
printme(struct ndz_rangemap *map, struct ndz_range *range, void *arg)
{
    printf("%p: [%lu - %lu]\n", range, range->start, range->end);
    return 0;
}

int
whackme(struct ndz_rangemap *map, struct ndz_range *range, void *arg)
{
    int rv;
    rv = ndz_rangemap_dealloc(map,
			      range->start,
			      range->end - range->start + 1);
    if (verbose)
	ndz_rangemap_dump(map, 0, NULL);

    return rv;
}

int
joinme(struct ndz_rangemap *map, struct ndz_range *range, void *arg)
{
    int rv = 0;
    ndz_addr_t leaddr = *(ndz_addr_t *)arg;
    *(ndz_addr_t *)arg = range->end;

#if 1
 again:
    if (range->next) {
	ndz_addr_t addr = range->end + 1;
	ndz_addr_t eaddr = range->next->start - 1;
	ndz_size_t size = eaddr - addr + 1;

	if (size < 64) {
	    rv = ndz_rangemap_alloc(map, addr, size, NULL);
	    if (rv == 0)
		goto again;
	}
    }
#else
    if (leaddr != NDZ_HIADDR) {
	ndz_addr_t addr = leaddr + 1;
	ndz_addr_t eaddr = range->start - 1;
	ndz_size_t size = eaddr - addr + 1;

	if (size < 64)
	    rv = ndz_rangemap_alloc(map, addr, size, NULL);
    }
#endif
    if (verbose)
	ndz_rangemap_dump(map, 0, NULL);

    return rv;
}

int
zapdata(struct ndz_rangemap *map, struct ndz_range *range, void *arg)
{
    range->data = NULL;
    if (verbose)
	ndz_rangemap_dump(map, 0, NULL);

    return 0;
}

int
coalesce(struct ndz_rangemap *map, struct ndz_range *range, void *arg)
{
    int rv = 0;
    struct ndz_range *next;

 again:
    next = range->next;
    if (next && range->end + 1 == next->start &&
	range->data == NULL && next->data == NULL) {
	range->end = next->end;
	range->next = next->next;
	ndz_range_free(next);
	goto again;
    }
    if (verbose)
	ndz_rangemap_dump(map, 0, NULL);

    return rv;
}

int
main(int argc, char **argv)
{
    struct ndz_rangemap *map;
    struct ndz_range *range;
    ndz_addr_t lo, hi;
    void *data;
    unsigned long ilo, ihi, idata;
    int rv;
    char buf[100], cmd;

    do {
	printf("Map range (low high)? ");
	fgets(buf, sizeof(buf), stdin);
	rv = sscanf(buf, "%lu %lu", &ilo, &ihi);
	if (rv != 2)
	    printf("*** wrong # of args %d\n", rv);
    } while (rv != 2);
    assert(ilo < ihi);
    lo = ilo; hi = ihi;
    map = ndz_rangemap_init(lo, hi);
    assert(map);

    while (1) {
	if (verbose)
	    printf("Command and range (cmd low high)? ");
	if (fgets(buf, sizeof(buf), stdin) == NULL)
	    break;
	ilo = ihi = 0;
	rv = sscanf(buf, "%c %lu %lu %lu", &cmd, &ilo, &ihi, &idata);
	if (rv == 0) {
	    printf("*** wrong number of args\n");
	    continue;
	}
	if (rv > 2 && ilo > ihi)
	    continue;
	lo = ilo;
	hi = rv > 2 ? ihi : ilo;
	data = rv > 3 ? (void *)idata : NULL;

	switch (cmd) {
	case 'a': case 'A':
	    rv = ndz_rangemap_alloc(map, lo, hi-lo+1, data);
	    if (rv)
		printf("*** map_alloc failed: %d\n", rv);
	    else if (verbose)
		ndz_rangemap_dump(map, 0, NULL);
	    break;
	case 'd': case 'D':
	    rv = ndz_rangemap_dealloc(map, lo, hi-lo+1);
	    if (rv)
		printf("*** map_dealloc failed: %d\n", rv);
	    else if (verbose)
		ndz_rangemap_dump(map, 0, NULL);
	    break;
	case 'l': case 'L':
	    range = ndz_rangemap_lookup(map, lo, NULL);
	    if (range) {
		printf("%lu found in [%lu - %lu]\n",
		       lo, range->start, range->end);
		if (verbose)
		    ndz_rangemap_dump(map, 0, NULL);
	    } else
		printf("*** %lu not found\n", lo);
	    break;
	case 'i': case 'I':
	{
	    int (*func)(struct ndz_rangemap *, struct ndz_range *, void *);
	    ndz_addr_t taddr = NDZ_HIADDR;

	    if (lo == 1)
		func = printme;
	    else if (lo == 2)
		func = whackme;
	    else if (lo == 3)
		func = joinme;
	    else if (lo == 4)
		func = zapdata;
	    else if (lo == 5)
		func = coalesce;
	    else {
		printf("*** unknown iterator function\n");
		break;
	    }
	    rv = ndz_rangemap_iterate(map, func, &taddr);
	    break;
	}
	case 'p': case 'P':
	    ndz_rangemap_dump(map, 0, NULL);
	    break;
	case 'q': case 'Q':
	    goto done;
	case 'v': case 'V':
	    verbose = !verbose;
	    printf("Verbose is %s\n", verbose ? "on" : "off");
	    break;
	default:
	    printf("Unrecognized command '%c'\n", cmd);
	    break;
	}
    }

 done:
    ndz_rangemap_deinit(map);
    return 0;
}
#endif

/*
 * Local variables:
 * mode: C
 * c-set-style: "BSD"
 * c-basic-offset: 4
 * End:
 */
