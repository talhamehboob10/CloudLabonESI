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
 * Routines for dealing with MBRs.
 */
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <string.h>
#include <assert.h>
#include <err.h>

#include "imagehdr.h"
#include "sliceinfo.h"
#include "global.h"
#include "mbr.h"

/*
 * Throughout Emulab history, the fake "track size" for MBR has always
 * been 63 sectors and the first partition has always started at 63.
 * We have always saved those low 63 sectors since they are used for
 * the boot block and other purposes. We continue to do this, but
 * will skip anything between 63 and the first partition.
 */
#define MAGIC_LOSECT	63

static int silent = 0;
static uint32_t losect = ~0, hisect = 0;

static int read_mbr(int fd, uint32_t bbstart, uint32_t pstart,
		    uint32_t extstart, struct iz_slice *parttab);

/*
 * Read an MBR partition table at the indicated offset.
 * If successful return 0 with *parttab filled in.
 * Otherwise return an error.
 */
int
parse_mbr(int fd, struct iz_disk *disk, int dowarn)
{
	struct iz_slice *parttab = disk->slices;
	int i;

	/* mark everything invalid to start */
	for (i = 0; i < MAXSLICES; i++)
		parttab[i].type = IZTYPE_INVALID;

	silent = (dowarn == 0);
	i = read_mbr(fd, DOSBBSECTOR, 0, 0, parttab);
	if (i)
		return i;

	disk->dsize = (iz_size)getdisksize(fd);
	disk->lodata = MAGIC_LOSECT;
	disk->hidata = disk->dsize - 1;
	disk->losect = (iz_lba)losect;
	disk->hisect = (iz_lba)hisect - 1;

	return 0;
}

/*
 * XXX Argh! We have a problem.
 *
 * The definition of the DOS boot block (doslabel struct) has an embedded
 * struct (parts) that is at a non-word boundary according to the on-disk
 * layout of the boot block. Left to its own devices, the compiler will
 * offset the parts struct inserting an implicit 2 bytes of padding before
 * it, so that word accesses within the struct (in particular, dp_start
 * and dp_size) are aligned. (Once upon a time, such unaligned accesses
 * were fatal. Now they are not on most x86-en, but we try to avoid it
 * anyway.) The problem is that the implicit padding means the struct
 * doesn't line up with the on-disk structure. So, struct doslabel inserts
 * 2 bytes of padding at the beginning of the struct ("align") so that the
 * "parts" struct does fall on a word boundary without padding. The price
 * we pay is that now whenever we read or write such a struct, we do so at
 * an offset 2 bytes in (the "pad2" field).
 *
 * That was all fine until we started using the O_DIRECT flag on open of
 * a device. O_DIRECT requires that the data buffer we pass be 512-byte
 * aligned, at least on Linux. But there is no way we can have both the
 * read-buffer aligned and the "parts" struct within the doslabel aligned.
 * One solution is to align the read buffer and just use the "packed"
 * attribute for the struct so that the compiler won't try to align it
 * and we would wind up doing unaligned word accesses. However, this would
 * be way too simple. Instead, we retain the obscure structure definition
 * and COPY the data from the read/write buffer into a properly (mis)aligned
 * doslabel struct for access!
 */
#define SECALIGN(p)	(void *)(((uintptr_t)(p) + (SECSIZE-1)) & ~(SECSIZE-1))

static int
read_mbr(int fd, uint32_t bbstart, uint32_t pstart, uint32_t extstart,
	 struct iz_slice *parttab)
{
	char mbrbuf[DOSPARTSIZE+SECSIZE], *mbr = SECALIGN(mbrbuf);
	struct doslabel label;
	int cc, i;

	if (lseek(fd, sectobytes(bbstart), SEEK_SET) < 0) {
		if (!silent)
			warn("Could not seek to DOS label at sector %u",
			     bbstart);
		return 1;
	}
	if ((cc = read(fd, mbr, DOSPARTSIZE)) < 0) {
		if (!silent)
			warn("Could not read DOS label at sector %u", bbstart);
		return 1;
	}
	if (cc != DOSPARTSIZE) {
		if (!silent)
			warnx("Incomplete read of DOS label at sector %u",
			      bbstart);
		return 1;
	}
	memcpy(&label.pad2, mbr, DOSPARTSIZE);
	if (label.magic != BOOT_MAGIC) {
		if (!silent)
			warnx("Wrong magic number in DOS partition table "
			      "at sector %u", bbstart);
		return 1;
	}

	/*
	 * If partition 1 is a protective MBR, punt
	 */
	if (label.parts[0].dp_typ == DOSPTYP_PROTECTIVE) {
		if (!silent)
			warnx("Found protective MBR, this is a GPT disk!");
		return 1;
	}

	/*
	 * Parse out the DOS partitions filling in our partition table.
	 * We handle extended DOS partitions here as well.
	 */
	for (i = 0; i < NDOSPART; i++) {
		unsigned char	type  = label.parts[i].dp_typ;
		uint64_t	start = bbstart + label.parts[i].dp_start;
		uint64_t	size  = label.parts[i].dp_size;
		int		pix = pstart + i;
		int		rval;

		parttab[pix].type = type;
		parttab[pix].flags = 0;
		parttab[pix].offset = start;
		parttab[pix].size = size;

		switch (type) {
		/* handle the partition types we know */
		/* N.B: for all of these, DOSPTY_* == IZTYPE_* */
		case DOSPTYP_UNUSED:
			parttab[pix].flags |= IZFLAG_IGNORE;
			break;
		case DOSPTYP_FAT12:
		case DOSPTYP_FAT16:
		case DOSPTYP_FAT16L:
		case DOSPTYP_NTFS:
		case DOSPTYP_FAT32:
		case DOSPTYP_FAT32_LBA:
		case DOSPTYP_FAT16L_LBA:
		case DOSPTYP_LINSWP:
		case DOSPTYP_LINUX:
		case DOSPTYP_386BSD:
		case DOSPTYP_OPENBSD:
			break;

		case DOSPTYP_EXT:
		case DOSPTYP_EXT_LBA:
			parttab[pix].flags |= IZFLAG_IGNORE;

			/*
			 * Look for an MBR at the beginning of the extended
			 * partition and identify those partitions.
			 *
			 * XXX extended partition start sectors are relative
			 * to the first extended partition found (extstart).
			 */
			rval = read_mbr(fd, extstart + label.parts[i].dp_start,
					pstart + NDOSPART,
					extstart ? extstart : start,
					parttab);
			if (rval) {
				warnx("P%d: Could not read MBR for extended "
				      "partition, treating as unsupported",
				      pix+1);
				parttab[pix].flags |= IZFLAG_NOTSUP;
			}
			break;

		default:
			warnx("P%d: Unsupported DOS partition type 0x%x",
			      pix+1, type);
			parttab[pix].flags |= IZFLAG_NOTSUP;
			break;
		}

		if (start < losect)
			losect = start;
		if (start + size > hisect)
			hisect = start + size;
	}

	/*
	 * At this point we should sanity check the partitions, looking
	 * for overlaps and gaps. The gaps should be added to the skip
	 * list (except for the init pre-partition 1 space which is
	 * typically a boot block and other magic).
	 *
	 * We could do this is a partitioner-indepenedent way, except
	 * that only the partitioner knows which gaps are special and
	 * need to be saved.
	 */

	return 0;
}

/* XXX for imageunzip */
int
set_mbr_type(int fd, int slice, iz_type dostype)
{
	char mbrbuf[DOSPARTSIZE+SECSIZE], *mbr = SECALIGN(mbrbuf);
	struct doslabel label;
	int cc;

	if (dostype > 0xFF) {
		fprintf(stderr, "Unrecognized MBR partition type 0x%x\n",
			dostype);
		return 1;
	}

	if (lseek(fd, sectobytes(DOSBBSECTOR), SEEK_SET) < 0) {
		perror("Could not seek to DOS label");
		return 1;
	}
	if ((cc = read(fd, mbr, DOSPARTSIZE)) < 0) {
		perror("Could not read DOS label");
		return 1;
	}
	if (cc != DOSPARTSIZE) {
		fprintf(stderr, "Could not get the entire DOS label\n");
		return 1;
	}
	memcpy(&label.pad2, mbr, DOSPARTSIZE);
	if (label.magic != BOOT_MAGIC) {
		fprintf(stderr, "Wrong magic number in DOS partition table\n");
		return 1;
	}

	if (label.parts[slice-1].dp_typ != dostype) {
		label.parts[slice-1].dp_typ = dostype;
		if (lseek(fd, sectobytes(DOSBBSECTOR), SEEK_SET) < 0) {
			perror("Could not seek to DOS label");
			return 1;
		}
		memcpy(mbr, &label.pad2, DOSPARTSIZE);
		cc = write(fd, mbr, DOSPARTSIZE);
		if (cc != DOSPARTSIZE) {
			perror("Could not write DOS label");
			return 1;
		}
	}
	return 0;
}
