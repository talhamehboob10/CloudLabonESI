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
#ifndef _IMAGEHDR_H_
#define _IMAGEHDR_H_

#include <inttypes.h>

/*
 * Magic number when image is compressed
 *
 * This magic number has been commandeered for use as a version number.
 * None of this wimpy start at version 1 stuff either, our first version
 * is 1,768,515,945!
 *
 *	V2 introduced the first and last sector fields as well
 *	as basic relocations. Also dropped maintenance of blocktotal.
 *
 *	V3 introduced LILO relocations for Linux partition images.
 *	Since an older imageunzip would still work, but potentially
 *	lay down an incorrect images, I bumped the version number.
 *	Note that there is no change to the header structure however.
 *
 *	V4 of the block descriptor adds support for integrety protection
 *	and encryption.
 */
#define COMPRESSED_MAGIC_BASE		0x69696969
#define COMPRESSED_V1			(COMPRESSED_MAGIC_BASE+0)
#define COMPRESSED_V2			(COMPRESSED_MAGIC_BASE+1)
#define COMPRESSED_V3			(COMPRESSED_MAGIC_BASE+2)
#define COMPRESSED_V4			(COMPRESSED_MAGIC_BASE+3)

#define COMPRESSED_MAGIC_CURRENT	COMPRESSED_V4

/*
 * Each compressed block of the file has this little header on it.
 * Since each block is independently compressed, we need to know
 * its internal size (it will probably be shorter than 1MB) since we
 * have to know exactly how much to give the inflator.
 */
struct blockhdr_V1 {
	uint32_t	magic;		/* magic/version */
	uint32_t	size;		/* Size of compressed part */
	int32_t		blockindex;	/* which block we are */
	int32_t		blocktotal;	/* V1: total number of blocks */
	int32_t		regionsize;	/* sizeof header + regions */
	int32_t		regioncount;	/* number of regions */
};

/*
 * Version 2 of the block descriptor adds a first and last sector value.
 * These are used to describe free space which is adjacent to the allocated
 * sector data.  This is needed in order to properly zero all free space.
 * Previously free space between regions that wound up in different
 * blocks could only be handled if the blocks were presented consecutively,
 * this was not the case in frisbee.
 */
struct blockhdr_V2 {
	uint32_t	magic;		/* magic/version */
	uint32_t	size;		/* Size of compressed part */
	int32_t		blockindex;	/* which block we are */
	int32_t		blocktotal;	/* V1: total number of blocks */
	int32_t		regionsize;	/* sizeof header + regions */
	int32_t		regioncount;	/* number of regions */
	/* V2 follows */
	uint32_t	firstsect;	/* first sector described by block */
	uint32_t	lastsect;	/* first sector past block */
	int32_t		reloccount;	/* number of reloc entries */
};

#define UUID_LENGTH		16

/*
 * Authentication/integrity/encryption constants for V4.
 */
#define ENC_MAX_KEYLEN		32	/* XXX same as EVP_MAX_KEY_LENGTH */
#define CSUM_MAX_LEN		64
#define SIG_MAX_KEYLEN		256	/* must be > CSUM_MAX_LEN+41 */

/*
 * Version 4 of the block descriptor adds support for authentication,
 * integrety protection and encryption.
 *
 * An optionally-signed checksum (hash) of each header+chunk is stored in
 * the header (checksum) along with the hash algorithm used (csum_type).
 * The pubkey used to sign the hash is transfered out-of-band.
 *
 * To ensure that all valid signed chunks are part of the same image,
 * a unique identifier is stored in the header (imageid) of each chunk
 * associated with the same image.
 *
 * Optionally, the contents of each chunk (but not the header) is encrypted
 * using the indicated cipher (enc_cipher) and initialization vector (enc_iv).
 */
struct blockhdr_V4 {
	uint32_t	magic;		/* magic/version */
	uint32_t	size;		/* Size of compressed part */
	int32_t		blockindex;	/* which block we are */
	int32_t		blocktotal;	/* V1: total number of blocks */
	int32_t		regionsize;	/* sizeof header + regions */
	int32_t		regioncount;	/* number of regions */
	/* V2 follows */
	uint32_t	firstsect;	/* first sector described by block */
	uint32_t	lastsect;	/* first sector past block */
	int32_t		reloccount;	/* number of reloc entries */
	/* V4 follows */
	uint16_t	enc_cipher;	/* cipher was used to encrypt */
	uint16_t	csum_type;	/* checksum algortihm used */
	uint8_t		enc_iv[ENC_MAX_KEYLEN];
					/* Initialization vector */
	unsigned char	checksum[SIG_MAX_KEYLEN];
					/* (Signed) checksum */
	unsigned char	imageid[UUID_LENGTH];
					/* Unique ID for the whole image */
};

/*
 * Coming soon in V5:
 *
 * 64-bit support.
 *   Grow blockindex, firstsect, lastsect, region descriptors, may need to
 *   grow DEFAULTREGIONSIZE to accomodate the doubling in size of regions.
 *
 * Flag field?
 *   For example, to indicate a delta image. Would probably take over the
 *   otherwise unused blocktotal field.
 *
 * Sectorsize field?
 *   To make explicit the units of sector fields; e.g., 512 vs 4096.
 *
 * Chunksize field?
 *   To support different chunksizes.
 *
 * Mandate little-endian on-disk data.
 *   Code changes only to use appropriate endian macros when reading/writing
 *   data. No data struct changes needed.
 *
 * Support for SHA256 and SHA512 checksums.
 *   Just some constants here, as checksum is already 64 bytes.
 *   Will need to grow the imagehash header to accomodate these checksums
 *   for signatures, but that is separately versioned.
 */

/*
 * Checksum types supported
 */
#define CSUM_NONE		0  /* must be zero */
#define CSUM_SHA1		1  /* SHA1: default */
#define CSUM_SHA1_LEN		20

/* type field */
#define CSUM_TYPE		0xFF

/* flags */
#define CSUM_SIGNED		0x8000	/* checksum is signed */

/*
 * Ciphers supported
 */
#define ENC_NONE		0  /* must be zero */
#define ENC_BLOWFISH_CBC	1

/*
 * Authentication ciphers supported
 */
#define AUTH_RSA		0

/*
 * Relocation descriptor.
 * Certain data structures like BSD disklabels and LILO boot blocks require
 * absolute block numbers.  This descriptor tells the unzipper what the
 * data structure is and where it is located in the block.
 *
 * Relocation descriptors follow the region descriptors in the header area.
 */
struct blockreloc {
	uint32_t	type;		/* relocation type (below) */
	uint32_t	sector;		/* sector it applies to */
	uint32_t	sectoff;	/* offset within the sector */
	uint32_t	size;		/* size of data affected */
};
#define RELOC_NONE		0
#define RELOC_FBSDDISKLABEL	1	/* FreeBSD disklabel */
#define RELOC_OBSDDISKLABEL	2	/* OpenBSD disklabel */
#define RELOC_LILOSADDR		3	/* LILO sector address */
#define RELOC_LILOMAPSECT	4	/* LILO map sector */
#define RELOC_LILOCKSUM		5	/* LILO descriptor block cksum */
#define RELOC_SHORTSECTOR	6	/* indicated sector < sectsize */

/* XXX potential future alternatives to hard-wiring BSD disklabel knowledge */
#define RELOC_ADDPARTOFFSET	100	/* add partition offset to location */
#define RELOC_XOR16CKSUM	101	/* 16-bit XOR checksum */
#define RELOC_CKSUMRANGE	102	/* range of previous checksum */

typedef struct blockhdr_V4 blockhdr_t;

/*
 * This little struct defines the pair. Each number is in sectors. An array
 * of these come after the header above, and is padded to a 1K boundry.
 * The region says where to write the next part of the input file, which is
 * how we skip over parts of the disk that do not need to be written
 * (swap, free FS blocks).
 */
struct region {
	uint32_t	start;
	uint32_t	size;
};

/*
 * Each block has its own region header info.
 *
 * Since there is no easy way to tell how many regions will fit before
 * we have compressed the region data, we just have to pick a size here.
 * If this area is too small, it is possible that a highly fragmented image
 * will fill this header before filling the data area of a block.  If the
 * region header area is too large, we will almost always fill up the data
 * area before filling the region header.  Since the latter is more likely
 * to be common, we tend to the small-ish side.
 *
 * At 4K with 8 byte region descriptors, we can fix 512 regions into a
 * single chunk.
 */
#define DEFAULTREGIONSIZE	4096

/*
 * Ah, the frisbee protocol. The new world order is to break up the
 * file into fixed chunks, with the region info prepended to each
 * chunk so that it can be layed down on disk independently of all the
 * chunks in the file. 
 */
#define F_BLOCKSIZE		1024
#define F_BLOCKSPERCHUNK	1024

#define CHUNKSIZE		(F_BLOCKSIZE * F_BLOCKSPERCHUNK)
#define CHUNKMAX		(CHUNKSIZE - DEFAULTREGIONSIZE)


/*
 * Assumed sector (block) size
 */
#define SECSIZE			512

#endif /* _IMAGEHDR_H_ */
