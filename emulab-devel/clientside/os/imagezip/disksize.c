/*
 * Copyright (c) 2000-2015 University of Utah and the Flux Group.
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
 * Determine the size of the target disk in sectors.
 */

#include <inttypes.h>
#include <unistd.h>
#include <stdio.h>

#ifdef __FreeBSD__
#if __FreeBSD__ >= 5
#include <sys/disk.h>
#else
#include <sys/disklabel.h>
#endif
#else
#ifdef __linux__
#include <sys/ioctl.h>
#include <linux/fs.h>
#endif
#endif

uint64_t
getdisksize(int fd)
{
	unsigned long disksize = 0;
	unsigned int ssize = 512;
	off_t whuzat;

#ifdef linux
	if (disksize == 0) {
		int rv;
		rv = ioctl(fd, BLKGETSIZE, &disksize);
		if (rv < 0)
			disksize = 0;
#ifdef TEST
		fprintf(stderr, "Linux BLKGETSIZE returned %lu\n", disksize);
#endif
	}
#else
#ifdef DIOCGMEDIASIZE
	if (disksize == 0) {
		int rv;
		off_t dsize;

		if (ioctl(fd, DIOCGSECTORSIZE, &ssize) < 0)
			ssize = 512;
		rv = ioctl(fd, DIOCGMEDIASIZE, &dsize);
		if (rv >= 0)
			disksize = (unsigned long)(dsize / ssize);
#ifdef TEST
		fprintf(stderr, "BSD BIOCGMEDIASIZE returned %lu\n", disksize);
#endif
	}
#else
#ifdef DIOCGDINFO
	if (disksize == 0) {
		int rv;
		struct disklabel label;

		rv = ioctl(fd, DIOCGDINFO, &label);
		if (rv >= 0)
			disksize = label.d_secperunit;
#ifdef TEST
		fprintf(stderr, "BSD DIOCGDINFO returned %lu\n", disksize);
#endif
	}
#endif
#endif
#endif

	whuzat = lseek(fd, (off_t)0, SEEK_CUR);

	/*
	 * OS wouldn't tell us anything directly, try a seek to the
	 * end of the device.
	 */
	if (disksize == 0) {
		off_t lastoff;

		lastoff = lseek(fd, (off_t)0, SEEK_END);
		if (lastoff > 0)
			disksize = (unsigned long)(lastoff / ssize);
#ifdef TEST
		fprintf(stderr, "lseek SEEK_END returned %ld, disksize=%lu\n", (long)lastoff, disksize);
#endif

	}

	/*
	 * Make sure we can seek to that sector
	 */
	if (disksize > 0) {
		if (lseek(fd, (off_t)(disksize-1) * ssize, SEEK_SET) < 0)
			fprintf(stderr, "WARNING: could not seek to "
				"final sector (%lu) of disk\n",
				disksize - 1);

		if (whuzat >= 0) {
			if (lseek(fd, whuzat, SEEK_SET) < 0)
				fprintf(stderr, "WARNING: could not seek to "
					"previous offset on disk\n");
		}
	}

	return disksize;
}

#ifdef TEST
#include <fcntl.h>

int
main(int argc, char **argv)
{
	uint64_t dsize;
	int fd;

	if (argc != 2) {
		fprintf(stderr, "Usage: %s disk\n", argv[0]);
		return 1;
	}

	fd = open(argv[1], O_RDONLY);
	if (fd < 0) {
		fprintf(stderr, "Could not open '%s'\n", argv[1]);
		return 1;
	}

	dsize = getdisksize(fd);
	close(fd);

	fprintf(stderr, "%s: size is %llu sectors\n",
		argv[1], (unsigned long long)dsize);

	return 0;
}
#endif
