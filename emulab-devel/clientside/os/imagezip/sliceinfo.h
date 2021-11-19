/*
 * Copyright (c) 2000-2016 University of Utah and the Flux Group.
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
#ifndef _SLICEINFO_H_
#define _SLICEINFO_H_

#include <inttypes.h>

/*
 * Partition (slice) description.
 * We use a simplified EFI partition description for our partition type.
 */

/* GPT max, seems reasonable */
#define MAXSLICES	128

/* We just use our own internal int types for the types we recognize */
typedef uint16_t	iz_type;
typedef uint16_t	iz_flags;

/* These are the same as MBR types */
#define IZTYPE_UNUSED		0	/* Unused */
#define	IZTYPE_FAT12		1	/* FAT12 */
#define	IZTYPE_FAT16		4	/* FAT16 */
#define	IZTYPE_EXT		5	/* DOS extended partition */
#define	IZTYPE_FAT16L		6	/* FAT16, part >= 32MB */
#define IZTYPE_NTFS    		7       /* Windows NTFS partition */
#define	IZTYPE_FAT32		11	/* FAT32 */
#define	IZTYPE_FAT32_LBA	12	/* FAT32, LBA */
#define	IZTYPE_FAT16L_LBA	14	/* FAT16, part >= 32MB, LBA */
#define	IZTYPE_EXT_LBA		15	/* DOS extended partition, LBA */
#define	IZTYPE_LINSWP		0x82	/* Linux swap partition */
#define	IZTYPE_LINUX		0x83	/* Linux partition */
#define IZTYPE_386BSD		0xa5	/* Free/NetBSD */
#define IZTYPE_OPENBSD		0xa6	/* OpenBSD */
#define IZTYPE_PROTECTIVE	0xee	/* GPT protective MBR */
#define IZTYPE_EFISYSTEM	0xef	/* EFI system partition */

/* These have no corresponding MBR type (should be 0x100 or above) */
#define IZTYPE_FBSDBOOT		0xA501	/* FreeBSD Boot partition */
#define IZTYPE_FBSDSWAP		0xA502	/* FreeBSD Swap partition */
#define IZTYPE_BIOSBOOT		0xEF02	/* GPT BIOS Boot partition */

/* These are internal */
#define IZTYPE_FBSDNOLABEL	0xFFA5	/* 386BSD but maybe no disklabel */
#define IZTYPE_UNKNOWN		0xFFFE	/* valid type, we just don't know it */
#define IZTYPE_INVALID		0xFFFF	/* invalid entry */

/* Flags */
#define IZFLAG_IGNORE		0x01	/* Explicitly ignored by imagezip */
#define IZFLAG_RAW		0x02	/* Explicitly forced to raw */
#define IZFLAG_NOTSUP		0x04	/* Not supported by imagezip */

#define ISBSD(t)	\
	((t) == IZTYPE_386BSD || (t) == IZTYPE_FBSDNOLABEL || \
	 (t) == IZTYPE_OPENBSD)
#define ISFAT(t)	\
	((t) == IZTYPE_FAT12 || (t) == IZTYPE_FAT16 || \
	 (t) == IZTYPE_FAT16L || (t) == IZTYPE_FAT32 || \
	 (t) == IZTYPE_FAT32_LBA || (t) == IZTYPE_FAT16L_LBA)

/*
 * XXX as of V4 we are all still 32 bit sector numbers.
 * 64-bit will come in V5...
 */
typedef uint32_t	iz_lba;
typedef uint32_t	iz_size;

struct iz_slice {
	iz_type		type;
	iz_flags	flags;
	iz_lba		offset;
	iz_size		size;
};

struct iz_disk {
	iz_size		dsize;		/* size of disk (in sectors) */
	iz_lba		lodata;		/* metadata below this */
	iz_lba		hidata;		/* metadata above this */
	iz_lba		losect;		/* lowest sector covered by a slice */
	iz_lba		hisect;		/* highest sector covered by a slice */
	struct iz_slice	slices[MAXSLICES];	/* slice info */
};

struct sliceinfo {
	iz_type	type;
	char	*desc;
	int	(*process)(int snum, iz_type stype, iz_lba start, iz_size size,
			   char *sname, int sfd);
	int	(*test)(int snum, iz_type stype, iz_lba start, iz_size size,
			   char *sname, int sfd);
};

/* 0 == false for all, ~0 == true for all, else true for those set */
typedef uint32_t partmap_t[MAXSLICES];
extern partmap_t ignore, forceraw;

#define SLICEMAP_PROCESS_PROTO(__process_fname__)	 \
	int __process_fname__(int snum, iz_type stype,   \
			      iz_lba start, iz_lba size, char *sname, int sfd)
#define SLICEMAP_TEST_PROTO(__test_fname__)	 \
	int __test_fname__(int snum, iz_type stype,   \
			      iz_lba start, iz_lba size, char *sname, int sfd)

extern struct sliceinfo *getslicemap(iz_type stype);
extern void printslicemap(void);

#ifdef WITH_MBR
extern int parse_mbr(int fd, struct iz_disk *disk, int dowarn);
extern int set_mbr_type(int fd, int slice, iz_type type);
#endif
#ifdef WITH_GPT
extern int parse_gpt(int fd, struct iz_disk *disk, int dowarn);
extern int set_gpt_type(int fd, int slice, iz_type type);
#endif

#endif /* _SLICEINFO_H_ */
