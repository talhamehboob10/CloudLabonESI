/*
 * Copyright (c) 2000-2002, 2007 University of Utah and the Flux Group.
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
 * util.c --
 *
 *      Utility routines for event system.
 *
 */

#include <stdio.h>
#include <stdlib.h>
#include <time.h>
#include "event.h"

/* Attempt to allocate SIZE bytes of memory and exit if memory
   allocation fails.  Returns pointer to allocated memory. */
void *
xmalloc(int size)
{
    void *p;
    p = malloc(size);
    if (!p) {
	fprintf(stderr,"virtual memory exhausted!");
	exit(1);
    }        
    return p;
}

/* Attempt to change the size of allocated memory block P to SIZE
   bytes and exit if memory allocation fails.  Returns pointer to
   (re)allocated memory. */
void *
xrealloc(void *p, int size)
{
    void *q;
    q = realloc(p, size);
    if (!q) {
	fprintf(stderr,"virtual memory exhausted!");
	exit(1);
    }        
    return q;
}

/* Format a timeval into a nice timestamp
 * Buffer must be 24 bytes wide (including null character)
 */
void
make_timestamp(char * buf, const struct timeval * t_timeval)
{
	struct tm t_tm;
	time_t secs = t_timeval->tv_sec;
	localtime_r(&secs, &t_tm);
	strftime(buf, 17, "%Y%m%d_%T", &t_tm);
	snprintf(buf+17, 5, ".%03ld", t_timeval->tv_usec/1000);
}




