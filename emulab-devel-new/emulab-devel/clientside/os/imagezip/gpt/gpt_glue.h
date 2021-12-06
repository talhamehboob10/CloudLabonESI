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
/*
 * Glue to connect imagezip with FreeBSD's sys/boot/common/gpt.c code.
 */
#ifndef _GPT_GLUE_H
#define _GPT_GLUE_H
#include <sys/types.h>
#include <stdio.h>
#include <strings.h>
#include "imagehdr.h"
#include "gpt.h"

#define drvread  gpt_drvread
#define drvwrite gpt_drvwrite
#define drvsize  gpt_drvsize

#ifdef __linux__
#include <string.h>
#define bcopy(s,d,n)	memcpy((d),(s),(n))
#define bzero(m,n)	memset((m),0,(n))
#define bcmp(a,b,n)	memcmp((a),(b),(n))
#ifndef htole16
#if __BYTE_ORDER == __LITTLE_ENDIAN
#define htole16(x)	(x)
#else
#define htole16(x)	__bswap_16(x)
#endif
#endif
#endif

/* we want to intercept these */
#define printf	 gpt_printf
int gpt_printf(const char * __restrict fmt, ...);

#ifndef DEV_BSIZE
#define DEV_BSIZE SECSIZE
#endif
#define BOOTPROG "YOWZA!"
typedef struct uuid uuid_t;

/* all se need for a "disk" is an fd */
struct dsk {
	uint64_t start;	/* we don't use this but code sets it */
	int fd;
};
int drvread(struct dsk *dskp, void *buf, daddr_t lba, unsigned nblk);
int drvwrite(struct dsk *dskp, void *buf, daddr_t lba, unsigned nblk);
uint64_t drvsize(struct dsk *dskp);

int gptread(const uuid_t *uuid, struct dsk *dskp, char *buf);
void gptgettables(struct gpt_hdr **hdr, struct gpt_ent **ent,
		  struct gpt_hdr **ohdr, struct gpt_ent **oent);
void gptupdate(const char *which, struct dsk *dskp, struct gpt_hdr *hdr,
	       struct gpt_ent *table);
void gptsetcurent(int idx);

#endif /* _GPT_GLUE_H */
