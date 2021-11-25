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
#ifndef _IMAGEHASH_H_
#define _IMAGEHASH_H_

#define HASH_VERSION_1	0x20031107
#define HASH_VERSION_2	0x20140618
#define HASH_VERSION	HASH_VERSION_2

#define HASH_MAGIC	".ndzsig"
#define HASHBLK_SIZE	(64*1024)
#define HASH_MAXSIZE	20

#define HASH_CHUNKNO(c)		((c) & ~(1 << 31))
#define HASH_CHUNKDOESSPAN(c)	(((c) & (1 << 31)) ? 1 : 0)
#define HASH_CHUNKSETSPAN(c)	((c) | (1 << 31))

struct hashregion {
	struct region region;
	uint32_t chunkno;
	unsigned char hash[HASH_MAXSIZE];
};

struct hashinfo {
	uint8_t	 magic[8];
	uint32_t version;
	uint32_t hashtype;
	uint32_t nregions;
	uint32_t blksize;	/* V2: make hash blocksize explicit */
	uint8_t	 pad[8];
	struct hashregion regions[0];
};

#define HASH_TYPE_MD5	1
#define HASH_TYPE_SHA1	2
#define HASH_TYPE_RAW	3

#endif /* _IMAGEHASH_H_ */
