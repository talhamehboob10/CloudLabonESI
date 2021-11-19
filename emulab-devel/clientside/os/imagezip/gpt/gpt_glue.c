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

/*
 * Glue to connect imagezip with FreeBSD's sys/boot/common/gpt.c code.
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

#include "gpt_glue.h"
#undef printf

/*
 * XXX hack. gpt.c is very chatty, and we don't want to be putting out
 * error messages if we are just probing for a GPT. Fortunately, it always
 * puts BOOTPROG at the beginning of all its messages, so we only filter
 * those. We keep around the last string in case we really do want to
 * print it.
 */
#include <stdarg.h>

static char lastmsg[512];
static int silent = 0;
static void gpt_utf8_to_utf16(const uint8_t *s8, uint16_t *s16, size_t s16len);

int
gpt_printf(const char * __restrict fmt, ...)
{
	va_list ap;
	int len;

	va_start(ap, fmt);
	vsnprintf(lastmsg, sizeof(lastmsg), fmt, ap);

	/* XXX get rid of newline since warn outputs one */
	len = strlen(lastmsg);
	if (lastmsg[len-1] == '\n')
		lastmsg[len-1] = '\0';

	if (strncmp(lastmsg, BOOTPROG, strlen(BOOTPROG)) != 0) {
		warnx("GPT: %s", lastmsg);
		lastmsg[0] = '\0';
	} else if (!silent)
		warnx("GPT%s", lastmsg + strlen(BOOTPROG));

	return 1;
}

/*
 * Read the indicated number of sectors.
 * Return 0 on success, error otherwise.
 */
int
drvread(struct dsk *dskp, void *buf, daddr_t lba, unsigned nblk)
{
	int fd = dskp->fd;
	off_t loc = sectobytes(lba);
	size_t size = sectobytes(nblk);

	if (lseek(fd, loc, SEEK_SET) < 0)
		return 1;

	if (read(fd, buf, size) != size)
		return 1;

	return 0;
}

int
drvwrite(struct dsk *dskp, void *buf, daddr_t lba, unsigned nblk)
{
	int fd = dskp->fd;
	off_t loc = sectobytes(lba);
	size_t size = sectobytes(nblk);

	if (lseek(fd, loc, SEEK_SET) < 0)
		return 1;

	if (write(fd, buf, size) != size)
		return 1;

	return 0;
}

/*
 * Return disk size in sectors.
 */
uint64_t
drvsize(struct dsk *dskp)
{
	return (uint64_t)getdisksize(dskp->fd);
}

/* keep things aligned for O_DIRECT IO */
#define SECALIGN(p)	(void *)(((uintptr_t)(p) + (SECSIZE-1)) & ~(SECSIZE-1))

/*
 * Map of GPT type UUIDs to imagezip types
 */
struct gptmap {
	struct uuid gpttype;
	char *desc;
	iz_type iztype;
	uint16_t shortid;
};
struct gptmap gptmap[] = {
	{GPT_ENT_TYPE_UNUSED, "Unused entry", IZTYPE_UNUSED, 0x0000},
	{GPT_ENT_TYPE_FREEBSD, "FreeBSD disklabel", IZTYPE_386BSD, 0xA500},
	{GPT_ENT_TYPE_FREEBSD_UFS, "FreeBSD UFS", IZTYPE_FBSDNOLABEL, 0xA503},
	{GPT_ENT_TYPE_LINUX_DATA, "Linux filesystem", IZTYPE_LINUX, 0x8300},
	{GPT_ENT_TYPE_LINUX_SWAP, "Linux swap", IZTYPE_LINSWP, 0x8200},
	{GPT_ENT_TYPE_BIOS_BOOT, "Grub BIOS boot partition", IZTYPE_BIOSBOOT, 0xEF02},
	{GPT_ENT_TYPE_FREEBSD_BOOT, "FreeBSD boot", IZTYPE_FBSDBOOT, 0xA501},
	{GPT_ENT_TYPE_FREEBSD_SWAP, "FreeBSD swap", IZTYPE_FBSDSWAP, 0xA502},
	{GPT_ENT_TYPE_EFI, "EFI System", IZTYPE_EFISYSTEM, 0xEF00},
	{GPT_ENT_TYPE_MBR, "MBR partition scheme", IZTYPE_UNKNOWN, 0xEF01},
	{GPT_ENT_TYPE_FREEBSD_NANDFS, "FREEBSD_NANDFS", IZTYPE_UNKNOWN, 0xFFFF},
	{GPT_ENT_TYPE_FREEBSD_VINUM, "FreeBSD Vinum/RAID", IZTYPE_UNKNOWN, 0xA505},
	{GPT_ENT_TYPE_FREEBSD_ZFS, "FreeBSD ZFS", IZTYPE_UNKNOWN, 0xA504},
	{GPT_ENT_TYPE_PREP_BOOT, "PowerPC PReP boot", IZTYPE_UNKNOWN, 0x4100},
	{GPT_ENT_TYPE_MS_RESERVED, "Microsoft reserved", IZTYPE_UNKNOWN, 0x0C01},
	{GPT_ENT_TYPE_MS_BASIC_DATA, "Microsoft basic data", IZTYPE_NTFS, 0x0700},
	{GPT_ENT_TYPE_MS_LDM_METADATA, "Windows LDM metadata", IZTYPE_UNKNOWN, 0x4201},
	{GPT_ENT_TYPE_MS_LDM_DATA, "Windows LDM data", IZTYPE_UNKNOWN, 0x4200},
	{GPT_ENT_TYPE_LINUX_RAID, "Linux RAID", IZTYPE_UNKNOWN, 0xFD00},
	{GPT_ENT_TYPE_LINUX_LVM, "Linux LVM", IZTYPE_UNKNOWN, 0x8E00},
	{GPT_ENT_TYPE_VMFS, "VMWare VMFS", IZTYPE_UNKNOWN, 0xFB00},
	{GPT_ENT_TYPE_VMKDIAG, "VMWare kcore crash protection", IZTYPE_UNKNOWN, 0xFC00},
	{GPT_ENT_TYPE_VMRESERVED, "VMWare reserved", IZTYPE_UNKNOWN, 0xFB01},
	{GPT_ENT_TYPE_VMVSANHDR, "VMVSANHDR", IZTYPE_UNKNOWN, 0xFB02},
	{GPT_ENT_TYPE_APPLE_BOOT, "Apple boot", IZTYPE_UNKNOWN, 0xAB00},
	{GPT_ENT_TYPE_APPLE_HFS, "Apple HFS/HFS+", IZTYPE_UNKNOWN, 0xAF00},
	{GPT_ENT_TYPE_APPLE_UFS, "Apple UFS", IZTYPE_UNKNOWN, 0xA800},
	{GPT_ENT_TYPE_APPLE_ZFS, "Solaris/Apple ZFS", IZTYPE_UNKNOWN, 0xBF01},
	{GPT_ENT_TYPE_APPLE_RAID, "Apple RAID", IZTYPE_UNKNOWN, 0xAF01},
	{GPT_ENT_TYPE_APPLE_RAID_OFFLINE, "Apple RAID offline", IZTYPE_UNKNOWN, 0xAF02},
	{GPT_ENT_TYPE_APPLE_LABEL, "Apple label", IZTYPE_UNKNOWN, 0xAF03},
	{GPT_ENT_TYPE_APPLE_TV_RECOVERY, "AppleTV recovery", IZTYPE_UNKNOWN, 0xAF04},
	{GPT_ENT_TYPE_NETBSD_FFS, "NetBSD FFS", IZTYPE_UNKNOWN, 0xA902},
	{GPT_ENT_TYPE_NETBSD_LFS, "NetBSD LFS", IZTYPE_UNKNOWN, 0xA903},
	{GPT_ENT_TYPE_NETBSD_SWAP, "NetBSD swap", IZTYPE_UNKNOWN, 0xA901},
	{GPT_ENT_TYPE_NETBSD_RAID, "NetBSD RAID", IZTYPE_UNKNOWN, 0xA906},
	{GPT_ENT_TYPE_NETBSD_CCD, "NetBSD concatenated", IZTYPE_UNKNOWN, 0xA904},
	{GPT_ENT_TYPE_NETBSD_CGD, "NetBSD encrypted", IZTYPE_UNKNOWN, 0xA905},
	{GPT_ENT_TYPE_DRAGONFLY_LABEL32, "Dragonfly label32", IZTYPE_UNKNOWN, 0xFFFF},
	{GPT_ENT_TYPE_DRAGONFLY_SWAP, "Dragonfly swap", IZTYPE_UNKNOWN, 0xFFFF},
	{GPT_ENT_TYPE_DRAGONFLY_UFS1, "Dragonfly UFS1", IZTYPE_UNKNOWN, 0xFFFF},
	{GPT_ENT_TYPE_DRAGONFLY_VINUM, "Dragonfly Vinum", IZTYPE_UNKNOWN, 0xFFFF},
	{GPT_ENT_TYPE_DRAGONFLY_CCD, "Dragonfly concatenated", IZTYPE_UNKNOWN, 0xFFFF},
	{GPT_ENT_TYPE_DRAGONFLY_LABEL64, "Dragonfly label64", IZTYPE_UNKNOWN, 0xFFFF},
	{GPT_ENT_TYPE_DRAGONFLY_LEGACY, "Dragonfly legacy", IZTYPE_UNKNOWN, 0xFFFF},
	{GPT_ENT_TYPE_DRAGONFLY_HAMMER, "Dragonfly Hammer", IZTYPE_UNKNOWN, 0xFFFF},
	{GPT_ENT_TYPE_DRAGONFLY_HAMMER2, "Dragonfly Hammer2", IZTYPE_UNKNOWN, 0xFFFF}
};
int ngptmap = sizeof(gptmap) / sizeof(gptmap[0]);

static struct gptmap *
getgpttypebyiztype(iz_type iztype)
{
	int i;

	/* check both DOS ids and GPT ids */
	if (iztype <= 0xFF) {
		for (i = 0; i < ngptmap; i++)
			if (gptmap[i].iztype == iztype)
				return &gptmap[i];
		return NULL;
	}

	for (i = 0; i < ngptmap; i++)
		if (gptmap[i].shortid == iztype)
			return &gptmap[i];
	return NULL;
}

static struct gptmap *
getgpttypebyuuid(struct uuid *gtype)
{
	int i;
	for (i = 0; i < ngptmap; i++)
		if (memcmp(&gptmap[i].gpttype, gtype, sizeof(*gtype)) == 0)
			return &gptmap[i];
	return NULL;
}

/*
 * Our interface to GPT code.
 * Read a GPT partition table. Returns 0 on success, an error otherwise.
 */
int
parse_gpt(int fd, struct iz_disk *disk, int dowarn)
{
	struct iz_slice *parttab = disk->slices;
	struct dsk dsk;
	uuid_t uuid;
	struct gpt_hdr *hdr;
	struct gpt_ent *ent;
	char secbuf[SECSIZE+SECSIZE-1], *buf = SECALIGN(secbuf);
	uint64_t dsize, losect, hisect;
	int i;

	dsk.fd = fd;

	/* mark everything invalid to start */
	for (i = 0; i < MAXSLICES; i++)
		parttab[i].type = IZTYPE_INVALID;

	silent = (dowarn == 0);

	/* attempt to read a GPT */
	if (gptread(&uuid, &dsk, buf))
		return 1;

	/* XXX get pointers to the static structs in gpt.c */
	gptgettables(&hdr, &ent, NULL, NULL);
	if (!hdr || !ent) {
		warnx("GPT: no header or table!?");
		return 1;
	}

	if (hdr->hdr_entries > MAXSLICES) {
		warnx("GPT: too many entries in table!");
		return 1;
	}

	losect = ~0;
	hisect = 0;
	for (i = 0; i < hdr->hdr_entries; i++) {
		struct gptmap *gmap = getgpttypebyuuid(&ent[i].ent_type);
		uint64_t start = ent[i].ent_lba_start;
		uint64_t size = ent[i].ent_lba_end - ent[i].ent_lba_start + 1;
		iz_type type = IZTYPE_UNKNOWN;

		if (gmap)
			type = gmap->iztype;

		parttab[i].type = type;
		if (type == IZTYPE_UNKNOWN) {
			warnx("P%d: Unsupported GPT partition type %s",
			      i+1, gmap ? gmap->desc : "???");
			parttab[i].flags |= IZFLAG_NOTSUP;
		} else
			parttab[i].flags = 0;

		/* consider a zero-length unused partition as invalid */
		if (type == IZTYPE_UNUSED && start == 0 && size == 1) {
			parttab[i].type = type = IZTYPE_INVALID;
			size = 0;
		}

		parttab[i].offset = start;
		parttab[i].size = size;

		/* XXX right now imagezip only handles 32-bit off/size */
		if ((uint64_t)(parttab[i].offset) != start ||
		    (uint64_t)(parttab[i].size) != size) {
			warnx("P%d: Offset/size too large, ignoring", i+1);
			parttab[i].flags |= IZFLAG_IGNORE;
		}

		if (type != IZTYPE_INVALID) {
			if (start < losect)
				losect = start;
			if (start + size > hisect)
				hisect = start + size;
		}
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
	 *
	 * For GPT right now, we just do the easy stuff. The GPT header
	 * tells us the first and last sectors allocated to partitions.
	 * Everything before and after, except the primary and secondary
	 * GPTs, can be skipped.
	 */
	dsize = gpt_drvsize(&dsk);
	{
		uint64_t prilba, seclba;

		if (hdr->hdr_lba_self > hdr->hdr_lba_alt) {
			if (dowarn)
				warnx("GPT: using secondary GPT");
			prilba = hdr->hdr_lba_alt;
			seclba = hdr->hdr_lba_self;
		} else {
			prilba = hdr->hdr_lba_self;
			seclba = hdr->hdr_lba_alt;
		}
//fprintf(stderr, "dsize=%lu, pri=%lu, alt=%lu, lba_low=%lu, lba_high=%lu\n", dsize, prilba, seclba, hdr->hdr_lba_start, hdr->hdr_lba_end);
		if (dowarn && (prilba == 0 || seclba == 0))
			warnx("GPT: primary (%lu) or secondary (%lu) is zero",
			      prilba, seclba);
		if (dowarn && losect < hdr->hdr_lba_start)
			warnx("GPT: partition starts (%lu) below lba_start (%lu)",
			      losect, hdr->hdr_lba_start);
		if (dowarn && hisect - 1 > hdr->hdr_lba_end)
			warnx("GPT: partition ends (%lu) after lba_end (%lu)",
			      hisect-1, hdr->hdr_lba_end);
		if (dowarn && prilba != 1)
			warnx("GPT: primary (%lu) not at sector 1", prilba);
		if (dsize && seclba + 1 != dsize) {
			if (dowarn)
				warnx("GPT: secondary (%lu) not at end of disk (%lu)",
				      seclba, dsize);
			seclba = dsize - 1;
		}

		disk->dsize = (iz_size)dsize;
		disk->lodata = (iz_lba)hdr->hdr_lba_start;
		disk->hidata = (iz_lba)hdr->hdr_lba_end;
		disk->losect = (iz_lba)losect;
		disk->hisect = (iz_lba)hisect - 1;
	}

	return 0;
}

int
set_gpt_type(int fd, int slice, iz_type iztype)
{
	struct gptmap *gmap;
	struct gpt_hdr *hdr, *ohdr;
	struct gpt_ent *ent, *oent;
	char secbuf[SECSIZE+SECSIZE-1], *buf = SECALIGN(secbuf);
	struct dsk dsk;
	uuid_t uuid;

	gmap = getgpttypebyiztype(iztype);
	if (gmap == NULL) {
		fprintf(stderr, "Cannot map type 0x%x to a GPT type\n",
			iztype);
		return 1;
	}

	/* read existing GPT */
	dsk.fd = fd;
	if (gptread(&uuid, &dsk, buf))
		return 1;
	gptgettables(&hdr, &ent, &ohdr, &oent);
	if (!hdr || !ent || !oent) {
		fprintf(stderr, "GPT: no header or table!?\n");
		return 1;
	}
	if (slice > hdr->hdr_entries) {
		fprintf(stderr, "Invalid slice number %d\n", slice);
		return 1;
	}

	/* change partition type in both copies */
	memcpy(&ent[slice-1].ent_type, &gmap->gpttype, sizeof(struct uuid));
	memcpy(&oent[slice-1].ent_type, &gmap->gpttype, sizeof(struct uuid));

	/* set the name from the description (this is what sgpart does) */
	int len = sizeof(ent[slice-1].ent_name) / 2;
	gpt_utf8_to_utf16((uint8_t *)gmap->desc, ent[slice-1].ent_name, len);
	gpt_utf8_to_utf16((uint8_t *)gmap->desc, oent[slice-1].ent_name, len);

	/* write out new GPT */
	gptsetcurent(slice - 1);
	gptupdate("primary", &dsk, hdr, ent);
	gptupdate("backup", &dsk, ohdr, oent);

	return 0;
}

#ifdef __FreeBSD__
#include <sys/endian.h>
#endif

/* Ripped from /usr/src/sys/geom/part/g_part_gpt.c */
static void
gpt_utf8_to_utf16(const uint8_t *s8, uint16_t *s16, size_t s16len)
{
	size_t s16idx, s8idx;
	uint32_t utfchar;
	unsigned int c, utfbytes;

	s8idx = s16idx = 0;
	utfchar = 0;
	utfbytes = 0;
	bzero(s16, s16len << 1);
	while (s8[s8idx] != 0 && s16idx < s16len) {
		c = s8[s8idx++];
		if ((c & 0xc0) != 0x80) {
			/* Initial characters. */
			if (utfbytes != 0) {
				/* Incomplete encoding of previous char. */
				s16[s16idx++] = htole16(0xfffd);
			}
			if ((c & 0xf8) == 0xf0) {
				utfchar = c & 0x07;
				utfbytes = 3;
			} else if ((c & 0xf0) == 0xe0) {
				utfchar = c & 0x0f;
				utfbytes = 2;
			} else if ((c & 0xe0) == 0xc0) {
				utfchar = c & 0x1f;
				utfbytes = 1;
			} else {
				utfchar = c & 0x7f;
				utfbytes = 0;
			}
		} else {
			/* Followup characters. */
			if (utfbytes > 0) {
				utfchar = (utfchar << 6) + (c & 0x3f);
				utfbytes--;
			} else if (utfbytes == 0)
				utfbytes = ~0;
		}
		/*
		 * Write the complete Unicode character as UTF-16 when we
		 * have all the UTF-8 charactars collected.
		 */
		if (utfbytes == 0) {
			/*
			 * If we need to write 2 UTF-16 characters, but
			 * we only have room for 1, then we truncate the
			 * string by writing a 0 instead.
			 */
			if (utfchar >= 0x10000 && s16idx < s16len - 1) {
				s16[s16idx++] =
				    htole16(0xd800 | ((utfchar >> 10) - 0x40));
				s16[s16idx++] =
				    htole16(0xdc00 | (utfchar & 0x3ff));
			} else
				s16[s16idx++] = (utfchar >= 0x10000) ? 0 :
				    htole16(utfchar);
		}
	}
	/*
	 * If our input string was truncated, append an invalid encoding
	 * character to the output string.
	 */
	if (utfbytes != 0 && s16idx < s16len)
		s16[s16idx++] = htole16(0xfffd);
}
