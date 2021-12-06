/*
 * Copyright (c) 2000-2017 University of Utah and the Flux Group.
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

#include <time.h>

static inline int
pasttime(struct timeval *cur, struct timeval *next)
{
	return (cur->tv_sec > next->tv_sec ||
		(cur->tv_sec == next->tv_sec &&
		 cur->tv_usec >= next->tv_usec));
}

static inline void
addtime(struct timeval *next, struct timeval *cur, struct timeval *inc)
{
	next->tv_sec = cur->tv_sec + inc->tv_sec;
	next->tv_usec = cur->tv_usec + inc->tv_usec;
	if (next->tv_usec >= 1000000) {
		next->tv_usec -= 1000000;
		next->tv_sec++;
	}
}

static inline void
subtime(struct timeval *next, struct timeval *cur, struct timeval *dec)
{
	if (cur->tv_usec < dec->tv_usec) {
		next->tv_usec = (cur->tv_usec + 1000000) - dec->tv_usec;
		next->tv_sec = (cur->tv_sec - 1) - dec->tv_sec;
	} else {
		next->tv_usec = cur->tv_usec - dec->tv_usec;
		next->tv_sec = cur->tv_sec - dec->tv_sec;
	}
}

static inline void
addusec(struct timeval *next, struct timeval *cur, unsigned long usec)
{
	next->tv_sec = cur->tv_sec;
	next->tv_usec = cur->tv_usec + usec;
	while (next->tv_usec >= 1000000) {
		next->tv_usec -= 1000000;
		next->tv_sec++;
	}
}

/* Prototypes */
char   *CurrentTimeString(void);
int	sleeptime(unsigned int usecs, char *str, int doround);
int	fsleep(unsigned int usecs);
int	sleeptil(struct timeval *nexttime);
void	InitSizes(int32_t chunksize, int32_t blocksize, int64_t bytes);
int	TotalChunks(void);
int	ChunkSize(int chunkno);
int	ChunkBytes(int chunkno);
int	TotalBlocks(void);
int	BlockSize(int chunkno, int blockno);
void	BlockMapInit(BlockMap_t *blockmap, int block, int count);
void	BlockMapAdd(BlockMap_t *blockmap, int block, int count);
void	BlockMapClear(BlockMap_t *blockmap, int block, int count);
int	BlockMapAlloc(BlockMap_t *blockmap, int block);
int	BlockMapIsAlloc(BlockMap_t *blockmap, int block, int count);
int	BlockMapExtract(BlockMap_t *blockmap, int *blockp);
void	BlockMapInvert(BlockMap_t *oldmap, BlockMap_t *newmap);
int	BlockMapMerge(BlockMap_t *frommap, BlockMap_t *tomap);
int	BlockMapFirst(BlockMap_t *blockmap);
int	BlockMapApply(BlockMap_t *blockmap, int chunk,
		      int (*func)(int, int, int, void *), void *farg);
void	ClientStatsDump(unsigned int id, ClientStats_t *stats);
#ifdef EMULAB_EVENTS
char	*extract_imageid(char *opath);
#endif
#ifdef MASTER_SERVER
char	*GetMSError(int error);
char	*GetMSMethods(int methods);
void	PrintGetInfo(char *imageid, GetReply *reply, int raw);
void	PrintPutInfo(char *imageid, PutReply *reply, int raw);
#endif

/* Compat */
#define CHUNKSIZE	ChunkSize(-1)
#define BLOCKSIZE	BlockSize(-1, -1)
