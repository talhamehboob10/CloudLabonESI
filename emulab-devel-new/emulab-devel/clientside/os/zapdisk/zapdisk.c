/*
 * Copyright (c) 2005-2017 University of Utah and the Flux Group.
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
 * Another little utility that groks DOS partitions and neuters boot blocks
 * and/or superblocks.
 *
 * XXX should be combined with dostype.c.
 */

#include <stdlib.h>
#include <limits.h>
#include <unistd.h>
#include <fcntl.h>
#include <stdio.h>
#include <errno.h>
#ifndef __CYGWIN__
#include <sys/types.h>
#include <inttypes.h>
#endif

#include "sliceinfo.h"

/*
 * For FS superblocks and other metadata we wipe the first 4M since that
 *   is sufficient to wipe the most commonly sized LVM metadata block.
 * For boot blocks we need up to 32k for GPT.
 * For certain HW/SW RAID standards, we may need to zap even more (up to
 * 32MB for DDF 2.0) at the end of the disk.
 */
#define MD_ZAPSIZE	(32*1024*1024)
#define MBR_ZAPSIZE	512
#define GPT_ZAPSIZE	(32*1024)
#define MAX_ZAPSIZE	(32*1024*1024)

static int verbose = 0;
static int pnum = 0;
static int bootblocks = 0;
static int superblocks = 0;
static int erase = 0;
static int doit = 0;

static char *diskname;
static char *zapdata;
static size_t zapsize;

static int zappart(int fd, struct iz_disk *diskinfo, int pnum, int rpnum);
static int zapptab(int fd, struct iz_disk *diskinfo, int ismbr);

/* XXX needed for mbr lib */
int secsize = 512;

static void
usage(void)
{
	fprintf(stderr, "usage: "
		"zapdisk [-BSE] [-Z] <diskdev>\n"
		" -p <pnum>   operate only on the given partition\n"
		" -B          zap MBR/GPT and partition boot programs\n"
		" -S          zap possible superblocks in all partitions\n"
		" -E          erase (TRIM) the partition or disk\n"
		" -Z          really do the zap and don't just talk about it\n"
		" <diskdev>   disk special file to operate on\n");
	exit(1);
}	

int
main(int argc, char **argv)
{
	int ch, i, fd;
	int errors = 0;
	struct iz_disk diskinfo;
	int ismbr;
	int gotbb = 0;

	while ((ch = getopt(argc, argv, "p:vBSEZ")) != -1)
		switch(ch) {
		case 'Z':
			doit++;
			break;
		case 'p':
			pnum = atoi(optarg);
			break;
		case 'v':
			verbose++;
			break;
		case 'B':
			bootblocks++;
			break;
		case 'S':
			superblocks++;
			break;
		case 'E':
			erase++;
			break;
		case '?':
		default:
			usage();
		}
	argc -= optind;
	argv += optind;
	if (argc < 1)
		usage();

	if (!bootblocks && !superblocks && !erase) {
		fprintf(stderr, "Must specify either -E or one or both of -B and -S\n");
		usage();
	}
	diskname = argv[0];
	if (pnum < 0 || pnum > MAXSLICES) {
		fprintf(stderr, "Invalid partition number %d\n", pnum);
		exit(1);
	} else if (pnum && bootblocks) {
		fprintf(stderr, "Cannot use -B and -p together\n");
		usage();
	}
#ifdef __CYGWIN__
	fprintf(stderr, "Does't work under Windows yet\n");
	exit(1);
#else
	fd = open(diskname, doit ? O_RDWR : O_RDONLY);
	if (fd < 0) {
		fprintf(stderr, "%s: ", diskname);
		perror("open");
		exit(1);
	}

	/*
	 * We are assuming that writing zeros provides proper zap-age
	 */
	zapdata = calloc(1, MAX_ZAPSIZE);
	if (zapdata == NULL) {
		fprintf(stderr, "%s: could not allocated zap buffer!\n",
			diskname);
		exit(1);
	}

#ifdef WITH_GPT
	if (!gotbb && parse_gpt(fd, &diskinfo, 0) == 0) {
		gotbb = 1;
		ismbr = 0;
		if (verbose)
			printf("%s: has GPT\n", diskname);
	}
#endif
#ifdef WITH_MBR
	if (!gotbb && parse_mbr(fd, &diskinfo, 0) == 0) {
		gotbb = 1;
		ismbr = 1;
		if (verbose)
			printf("%s: has MBR\n", diskname);
	}
#endif
	if (erase) {
#ifdef NO_ERASE
		fprintf(stderr, "Erase operation not implemented!\n");
		exit(1);
#else
		iz_lba start;
		iz_size size;
		extern uint64_t getdisksize(int);
		extern int erasedata(int, off_t, off_t, int);

		if (!gotbb && pnum > 0) {
			fprintf(stderr, "%s: No valid MBR/GPT,"
				" cannot erase partitions\n", diskname);
			exit(1);
		}
		if (pnum == 0) {
			start = 0;
			size = getdisksize(fd);
		} else {
			start = diskinfo.slices[pnum-1].offset;
			size = diskinfo.slices[pnum-1].size;
		}
		if (!doit) {
			printf("%s: would erase sectors [%lu-%lu]\n",
			       diskname, (unsigned long)start,
			       (unsigned long)start + size - 1);
			exit(0);
		}
		if (verbose)
			printf("%s: erasing sectors [%lu-%lu]\n",
			       diskname, (unsigned long)start,
			       (unsigned long)start + size - 1);
		if (erasedata(fd, (off_t)start * secsize,
			      (off_t)size * secsize, 0)) {
			fprintf(stderr,
				"%s: Could not erase sectors [%lu-%lu]\n",
				diskname, (unsigned long)start,
				(unsigned long)start + size - 1);
			exit(1);
		}
		exit(0);
#endif
	}

	if (!gotbb) {
		/* lack of a valid partition table is ok */
		if (superblocks)
			fprintf(stderr, "%s: WARNING: no valid MBR/GPT,"
				" cannot zero partitions\n", diskname);

		/* but we will force a bootblock zap if desired */
		ismbr = -1;
		goto whackaptab;
	}

	if (pnum > 0 && diskinfo.slices[pnum-1].type == IZTYPE_INVALID) {
		fprintf(stderr, "%s: no partition %d, skipped\n",
			diskname, pnum);
		exit(0);
	}

	if (superblocks) {
		for (i = 1; i <= MAXSLICES; i++)
			if (pnum == 0 || i == pnum)
				if (zappart(fd, &diskinfo, i, pnum))
					errors++;
	}
 whackaptab:
	if (bootblocks)
		if (zapptab(fd, &diskinfo, ismbr))
			errors++;

	exit(errors);
#endif
}

/*
 * Zap the bootblock/superblock/metadata in a partition.
 */
static int
zappart(int fd, struct iz_disk *diskinfo, int pnum, int rpnum)
{
	int cc;
	struct iz_slice *pinfo = &diskinfo->slices[pnum-1];

	zapsize = MD_ZAPSIZE;

	if (verbose && pinfo->type != IZTYPE_INVALID)
		printf("%s: P%d: start=%lu, size=%lu, type=0x%04x\n",
		       diskname, pnum, (unsigned long)pinfo->offset,
		       (unsigned long)pinfo->size, pinfo->type);

	/* Sanity checks */
	switch (pinfo->type) {
	case IZTYPE_PROTECTIVE:
		if (verbose || !doit)
			printf("%s: P%d: protective MBR, skipped\n",
			       diskname, pnum);
		return 0;
	case IZTYPE_INVALID:
		return 0;
	case IZTYPE_UNUSED:
		break;
	}

	/* If partition size is zero, silently skip it. */
	if (pinfo->size == 0)
		return 0;

	/* If it is smaller than our usual zapsize, zero the whole thing! */
	if ((size_t)pinfo->size*secsize < zapsize)
		zapsize = pinfo->size * secsize;

	if (lseek(fd, (off_t)pinfo->offset * secsize, SEEK_SET) < 0) {
		fprintf(stderr, "%s: ", diskname);
		perror("could not seek to partition start");
		return 1;
	}

	if (!doit) {
		printf("%s: P%d: would zero %d bytes at sector %d\n",
		       diskname, pnum, (int)zapsize, pinfo->offset);
		cc = zapsize;
	} else {
		if (verbose)
			printf("%s: P%d: zeroing %d bytes at sector %d\n",
			       diskname, pnum, (int)zapsize, pinfo->offset);
		cc = write(fd, zapdata, zapsize);
	}
	if (cc != zapsize) {
		if (cc < 0) {
			fprintf(stderr, "%s: P%d: ", diskname, pnum);
			perror("could not write to partition");
			return 1;
		}
		fprintf(stderr, "%s: P%d: WARNING: incomplete write "
			"of partition block (%d of %d)\n",
			diskname, pnum, cc, (int)zapsize);
	}
	return 0;
}

static int
zapptab(int fd, struct iz_disk *diskinfo, int ismbr)
{
	int cc;
	off_t looff, hioff;
	size_t losize = 0, hisize = 0;

	/*
	 * Unconditionally wipe the beginning and end of the disk.
	 */
	if (ismbr == -1) {
		extern uint64_t getdisksize(int fd);

		losize = MAX_ZAPSIZE;
		looff = 0;
		hioff = (off_t)getdisksize(fd) * secsize;
		if (hioff >= MAX_ZAPSIZE) {
			hioff -= MAX_ZAPSIZE;
			hisize = MAX_ZAPSIZE;
		}
	}
	/*
	 * We zap the metadata regions as recorded in the diskinfo.
	 */
	else {
		if (diskinfo->lodata > 0) {
			looff = 0;
			losize = (size_t)diskinfo->lodata * secsize;
		}
		if (diskinfo->hidata + 1 < diskinfo->dsize) {
			hioff = (off_t)(diskinfo->hidata + 1) * secsize;
			hisize = (size_t)
				(diskinfo->dsize - diskinfo->hidata - 1) *
				secsize;
		}
	}

	if (!doit) {
		if (losize)
			printf("%s: would zero %lu bytes at offset %lu\n",
			       diskname,
			       (unsigned long)losize, (unsigned long)looff);
		if (hisize)
			printf("%s: would zero %lu bytes at offset %lu\n",
			       diskname,
			       (unsigned long)hisize, (unsigned long)hioff);
		return 0;
	}

	if (losize) {
		if (verbose)
			printf("%s: zeroing %lu bytes at offset %lu\n",
			       diskname,
			       (unsigned long)losize, (unsigned long)looff);
		if (lseek(fd, looff, SEEK_SET) < 0) {
			fprintf(stderr, "%s: ", diskname);
			perror("could not seek to low ptab sector");
			return 1;
		}
		cc = write(fd, zapdata, losize);
		if (cc != losize) {
			fprintf(stderr, "%s: ", diskname);
			if (cc < 0)
				perror("could not write low ptab");
			else
				fprintf(stderr, "partial write of low ptab "
					"(%lu of %lu)\n",
					(unsigned long)cc,
					(unsigned long)losize);
			return 1;
		}
	}
	if (hisize) {
		if (verbose)
			printf("%s: zeroing %lu bytes at offset %lu\n",
			       diskname,
			       (unsigned long)hisize, (unsigned long)hioff);
		if (lseek(fd, hioff, SEEK_SET) < 0) {
			fprintf(stderr, "%s: ", diskname);
			perror("could not seek to high ptab sector");
			return 1;
		}
		cc = write(fd, zapdata, hisize);
		if (cc != hisize) {
			fprintf(stderr, "%s: ", diskname);
			if (cc < 0)
				perror("could not write high ptab");
			else
				fprintf(stderr, "partial write of high ptab "
					"(%lu of %lu)\n",
					(unsigned long)cc,
					(unsigned long)hisize);
			return 1;
		}
	}
	return 0;
}
