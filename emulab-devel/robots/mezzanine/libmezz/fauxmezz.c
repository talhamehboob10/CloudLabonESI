/*
 * Copyright (c) 2005 University of Utah and the Flux Group.
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

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <fcntl.h>
#include <unistd.h>

#include "mezz.h"

static void usage(void)
{
    fprintf(stderr,
	    "Usage: fauxmezz <ipcfile> <frame0> [frame1 frame2]\n"
	    "\n"
	    "Fake mezzanine that updates an IPC file with frame\n"
	    "data from a separate run of mezzanine.  It is intended\n"
	    "for use with mezzcal, simply start this program with\n"
	    "the list of frames you wish to examine and then direct\n"
	    "mezzcal to this program's IPC file.\n");
}

int read_mmap(mezz_mmap_t *mm, char *file)
{
    int fd, retval = 0;

    if ((fd = open(file, O_RDONLY)) == -1) {
	perror("open");
    }
    else if (read(fd, mm, sizeof(mezz_mmap_t)) != sizeof(mezz_mmap_t)) {
	perror("short read");
    }

    if (fd != -1) {
	close(fd);
    }

    memset(mm->pids, 0, sizeof(pid_t) * 32);
    mm->calibrate = -1;
    
    return retval;
}

int main(int argc, char *argv[])
{
    int retval = EXIT_SUCCESS;

    if (argc < 2) {
	usage();
	exit(0);
    }
    
    if (mezz_init(1, argv[1]) != 0) {
	fprintf(stderr, "unable to initialize mezzanine");
    }
    else {
	mezz_mmap_t *mm;
	int lpc = 0;
	
	argv += 2;
	argc -= 2;

	printf("Hit return to load the next frame\n");
	mm = mezz_mmap();
	read_mmap(mm, argv[lpc]);
	while (!feof(stdin)) {
	    int c = getchar();

	    printf("reading %s\n", argv[lpc % argc]);
	    read_mmap(mm, argv[lpc % argc]);
	    printf("Time: %f  Frame: %d\n", mm->time, mm->count);
	    mezz_raise_event();

	    lpc += 1;
	}
	mezz_term(1);
    }

    return retval;
}
