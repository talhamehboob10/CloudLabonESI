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
 * Global defns that should go away someday
 */
extern int debug;
extern int secsize;
extern int slicemode;
extern int dorelocs;
extern int metaoptimize;
extern int excludenonfs;
extern int forcerelocs;

extern off_t devlseek(int fd, off_t off, int whence);
extern ssize_t devread(int fd, void *buf, size_t nbytes);
extern void addskip(uint32_t start, uint32_t size);
extern void addvalid(uint32_t start, uint32_t size);
extern void addfixup(off_t offset, off_t poffset, off_t size, void *data,
		     int reloctype);
extern void addfixupfunc(void (*func)(void *, off_t, void *), off_t offset,
			 off_t poffset, off_t size, void *data, int dsize,
			 int reloctype);
extern void applyfixups(off_t offset, off_t size, void *data);
extern int hasfixup(uint32_t soffset, uint32_t ssize);
extern void savefixups(void);
extern void restorefixups(int isempty);
extern void dumpfixups(int verbose, int count);
extern uint64_t getdisksize(int fd);

extern SLICEMAP_PROCESS_PROTO(read_rawslice);
extern SLICEMAP_PROCESS_PROTO(read_bsdslice);
extern SLICEMAP_PROCESS_PROTO(read_bsdslicenl);
extern SLICEMAP_PROCESS_PROTO(read_bsdswapslice);
extern SLICEMAP_PROCESS_PROTO(read_linuxslice);
extern SLICEMAP_PROCESS_PROTO(read_linuxswap);
extern SLICEMAP_PROCESS_PROTO(read_ntfsslice);
extern SLICEMAP_PROCESS_PROTO(read_fatslice);

#define sectobytes(s)	((off_t)(s) * secsize)
#define bytestosec(b)	(uint32_t)((b) / secsize)
