/*
 * Copyright (c) 2000-2021 University of Utah and the Flux Group.
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
 * Frisbee server
 */
#include <sys/types.h>
#include <sys/param.h>
#include <sys/time.h>
#include <sys/fcntl.h>
#include <sys/socket.h>
#include <sys/resource.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <errno.h>
#include <signal.h>
#include <pthread.h>
#include <assert.h>
#include "decls.h"
#include "queue.h"
#include "utils.h"

#include "trace.h"
#include "event.h"

/* Globals */
int		debug = 0;
int		tracing = 0;
int		dynburst = 0;
int		timeout = SERVER_INACTIVE_SECONDS;
int		keepalive = 0;
int		readsize = SERVER_READ_SIZE;
volatile int	burstsize = SERVER_BURST_SIZE;
int		maxburstsize = SERVER_DYNBURST_SIZE;
int		burstinterval = SERVER_BURST_GAP;
unsigned long	bandwidth;
int		portnum;
int		portlo = -1;
int		porthi;
int		sockbufsize = SOCKBUFSIZE;
int		killme;
int		blockslost;
int		clientretries;
char		*lostmap;
int		sendretries;
struct in_addr	mcastaddr;
struct in_addr	mcastif;
char	       *addrfilename;
char	       *filename;
char	       *hserver;
unsigned int	hinterval;
struct timeval  IdleTimeStamp, FirstReq, LastReq;
volatile int	activeclients, totalclients;

/* Forward decls */
void		quit(int);
void		reinit(int);
static ssize_t	mypread(int fd, void *buf, size_t nbytes, off_t offset);
static void	calcburst(void);
static void	compute_sendrate(void);
static void	dumpstats(void);
static int	findclient(uint32_t id);

/*
 * Progress tracking.
 *
 * Since JOIN/LEAVE messages are UDP like everything else and can be lost,
 * this is not definitive.
 */
#define MAXCLIENTS 1024	/* not a real limit, just for stats */
static struct {
	unsigned int id;
	unsigned int ip;
	unsigned int lastseq;
} clients[MAXCLIENTS];
static int nextclientix = 0, maxclientnum = 0;

#ifdef STATS
/*
 * Track duplicate chunks/joins for stats gathering
 */
char		*chunkmap;

/*
 * Stats gathering.
 */
struct {
	unsigned long	msgin;
	unsigned long	joins;
	unsigned long	leaves;
	unsigned long	requests;
	unsigned long	reports, reportslogged;
	unsigned long	joinrep;
	unsigned long	blockssent;
	unsigned long   dupsent;
	unsigned long long netusecs;
	unsigned long	netmaxusec;
	unsigned long	netmsplus;
	unsigned long	filereads;
	unsigned long long filebytes;
	unsigned long long fileusecs;
	unsigned long	filemaxusec;
	unsigned long	partialreq;
	unsigned long	qmerges;
	unsigned long	badpackets;
	unsigned long   blockslost;
	unsigned long	clientlost;
	unsigned long	goesidle;
	unsigned long	wakeups;
	unsigned long	intervals;
	unsigned long	missed;
	unsigned long	dynminburst;
	unsigned long	dynmaxburst;
	unsigned long	dynincs, dyndecs;
} Stats;
#define DOSTAT(x)	(Stats.x)
#else
#define DOSTAT(x)
#endif

/*
 * This structure defines the file we are spitting back.
 */
struct FileInfo {
	int	fd;		/* Open file descriptor */
	int	blocks;		/* Number of BLOCKSIZE blocks */
	int	chunks;		/* Number of CHUNKSIZE chunks */
	int	isimage;	/* non-zero if this is a 1MB-rounded file */
	off_t	filesize;	/* Real size of file */
};
static struct FileInfo FileInfo;

/*
 * The work queue of regions a client has requested.
 */
typedef struct {
	queue_chain_t	chain;
	int		chunk;		/* Which chunk */
	int		nblocks;	/* Number of blocks in map */
	BlockMap_t	blockmap;	/* Which blocks of the chunk */
} WQelem_t;
static queue_head_t     WorkQ;
static pthread_mutex_t	WorkQLock;
#ifdef CONDVARS_WORK
static pthread_cond_t	WorkQCond;
#endif
static int		WorkQDelay = -1;
static int		WorkQSize = 0;
static int		WorkChunk, WorkBlock, WorkCount;
#ifdef STATS
static int		WorkQMax = 0;
static unsigned long	WorkQMaxBlocks = 0;
#endif

/*
 * Work queue routines. The work queue is a time ordered list of chunk/blocks
 * pieces that a client is missing. When a request comes in, lock the list
 * and scan it for an existing work item that covers the new request. The new
 * request can be dropped if there already exists a Q item, since the client
 * is going to see that piece eventually.
 *
 * We use a mutex to guard the work queue.
 *
 * XXX - Clients make requests for chunk/block pieces they are
 * missing. For now, map that into an entire chunk and add it to the
 * work queue. This is going to result in a lot more data being sent
 * than is needed by the client, but lets wait and see if that
 * matters.
 */
static void
WorkQueueInit(void)
{
	pthread_mutex_init(&WorkQLock, NULL);
	queue_init(&WorkQ);

	if (WorkQDelay < 0)
		WorkQDelay = sleeptime(1000, NULL, 1);

#ifdef CONDVARS_WORK
	pthread_cond_init(&WorkQCond, NULL);
#endif

#ifdef STATS
	chunkmap = calloc(FileInfo.chunks, 1);
#endif
}

/*
 * Enqueue a join reply.
 * We always stick this at the head of the queue.
 */
static void
WorkQueueEnqueueJoin(int vers, unsigned int clientid)
{
	WQelem_t	*wqel;

	pthread_mutex_lock(&WorkQLock);

	wqel = calloc(1, sizeof(WQelem_t));
	if (wqel == NULL)
		FrisFatal("WorkQueueEnqueueChunk: No more memory");

	/* XXX */
	wqel->chunk = -vers;
	wqel->nblocks = (int)clientid;

	queue_enter_first(&WorkQ, wqel, WQelem_t *, chain);
	WorkQSize++;
#ifdef STATS
	if (WorkQSize > WorkQMax)
		WorkQMax = WorkQSize;
#endif

#ifdef CONDVARS_WORK
	pthread_cond_signal(&WorkQCond);
#endif
	pthread_mutex_unlock(&WorkQLock);
}

/*
 * Enqueue a chunk request.
 * If map==NULL, then we want the entire chunk.
 */
static int
WorkQueueEnqueueChunk(int chunk, BlockMap_t *map, int count)
{
	WQelem_t	*wqel;
	int		elt, blocks;
#ifdef STATS
	unsigned long	qblocks = 0;
#endif

	if (count == 0)
		return 0;

	pthread_mutex_lock(&WorkQLock);

	/*
	 * Common case: a full chunk request for the full block we are
	 * currently sending.  Don't queue.
	 */
	if (count == MAXCHUNKSIZE && chunk == WorkChunk && count == WorkCount) {
		EVENT(1, EV_WORKMERGE, mcastaddr, chunk, count, count, ~0);
		pthread_mutex_unlock(&WorkQLock);
		return 0;
	}

	elt = WorkQSize - 1;
	queue_riterate(&WorkQ, wqel, WQelem_t *, chain) {
		if (wqel->chunk == chunk) {
			/*
			 * If this is the head element of the queue
			 * we can only merge if the request is beyond
			 * the range being currently processed.
			 */
			if ((WQelem_t *)queue_first(&WorkQ) == wqel &&
			    chunk == WorkChunk &&
			    BlockMapFirst(map) < WorkBlock + WorkCount) {
				elt--;
				continue;
			}

			/*
			 * We have a queued request for the entire chunk
			 * already, nothing to do.
			 */
			if (wqel->nblocks == MAXCHUNKSIZE)
				blocks = 0;
			/*
			 * Or if incoming request is an entire chunk
			 * just copy that map.
			 */
			else if (count == MAXCHUNKSIZE) {
				wqel->blockmap = *map;
				blocks = MAXCHUNKSIZE - wqel->nblocks;
			}
			/*
			 * Otherwise do the full merge
			 */
			else
				blocks = BlockMapMerge(map, &wqel->blockmap);
			EVENT(1, EV_WORKMERGE, mcastaddr,
			      chunk, wqel->nblocks, blocks, elt);
			wqel->nblocks += blocks;
			assert(wqel->nblocks <= MAXCHUNKSIZE);
			pthread_mutex_unlock(&WorkQLock);
			return 0;
		}
#ifdef STATS
		qblocks += wqel->nblocks;
#endif
		elt--;
	}

	wqel = calloc(1, sizeof(WQelem_t));
	if (wqel == NULL)
		FrisFatal("WorkQueueEnqueueChunk: No more memory");

	wqel->chunk = chunk;
	wqel->nblocks = count;
	wqel->blockmap = *map;
	queue_enter(&WorkQ, wqel, WQelem_t *, chain);
	WorkQSize++;
#ifdef STATS
	if (WorkQSize > WorkQMax)
		WorkQMax = WorkQSize;
	if (qblocks > WorkQMaxBlocks)
		WorkQMaxBlocks = qblocks;
#endif

#ifdef CONDVARS_WORK
	pthread_cond_signal(&WorkQCond);
#endif
	pthread_mutex_unlock(&WorkQLock);

	EVENT(1, EV_WORKENQ, mcastaddr, chunk, count, WorkQSize, 0);
	return 1;
}

static int
WorkQueueDequeue(int *chunkp, int *blockp, int *countp)
{
	WQelem_t	*wqel;
	int		chunk, block, count;

	pthread_mutex_lock(&WorkQLock);

	/*
	 * We use a timed wait here because our caller gathers stats
	 * about idle time.
	 */
	if (queue_empty(&WorkQ)) {
#ifdef CONDVARS_WORK
		struct timespec timo;
		struct timeval stamp;
		int rv;

		gettimeofday(&stamp, 0);
		timo.tv_sec = stamp.tv_sec;
		timo.tv_nsec = (stamp.tv_usec + WorkQDelay) * 1000;
		while (timo.tv_nsec >= 1000000000) {
			timo.tv_nsec -= 1000000000;
			timo.tv_sec++;
		}

		WorkChunk = -1;
		rv = pthread_cond_timedwait(&WorkQCond, &WorkQLock, &timo);
		if (rv != 0) {
			assert(rv == ETIMEDOUT);
			pthread_mutex_unlock(&WorkQLock);
			return 0;
		}
		assert(!queue_empty(&WorkQ));
#else
		WorkChunk = -1;
		pthread_mutex_unlock(&WorkQLock);
		fsleep(WorkQDelay);
		return 0;
#endif
	}
	
	wqel = (WQelem_t *) queue_first(&WorkQ);
	chunk = wqel->chunk;

	/*
	 * XXX special case JOIN reply
	 */
	if (chunk < 0) {
		*chunkp = chunk;
		*countp = wqel->nblocks;
		queue_remove(&WorkQ, wqel, WQelem_t *, chain);
		free(wqel);
		WorkQSize--;
		pthread_mutex_unlock(&WorkQLock);
		return 1;
	}

	if (wqel->nblocks == MAXCHUNKSIZE) {
		block = 0;
		count = MAXCHUNKSIZE;
	} else
		count = BlockMapExtract(&wqel->blockmap, &block);
	assert(count <= wqel->nblocks);
	wqel->nblocks -= count;
	if (wqel->nblocks == 0) {
		queue_remove(&WorkQ, wqel, WQelem_t *, chain);
		free(wqel);
		WorkQSize--;
	}
	WorkChunk = chunk;
	WorkBlock = block;
	WorkCount = count;

	pthread_mutex_unlock(&WorkQLock);

	*chunkp = chunk;
	*blockp = block;
	*countp = count;

	EVENT(1, EV_WORKDEQ, mcastaddr, chunk, block, count, WorkQSize);
	return 1;
}

static void
ClientEnqueueMap(int chunk, BlockMap_t *map, int count, int isretry)
{
	int		enqueued;

	if (count != MAXCHUNKSIZE) {
		DOSTAT(blockslost+=count);
		blockslost += count;
		DOSTAT(partialreq++);
	}

	enqueued = WorkQueueEnqueueChunk(chunk, map, count);
	if (!enqueued)
		DOSTAT(qmerges++);
#ifdef STATS
	else if (chunkmap != 0 && count == MAXCHUNKSIZE) {
		if (chunkmap[chunk]) {
			if (debug > 1)
				FrisLog("Duplicate chunk request: %d", chunk);
			EVENT(1, EV_DUPCHUNK, mcastaddr, chunk, 0, 0, 0);
			DOSTAT(dupsent++);
		} else
			chunkmap[chunk] = 1;
	}
#endif

	if (isretry) {
		clientretries++;
		/*
		 * We only consider the block lost if we didn't have it
		 * on the server queue.  This is a feeble attempt to
		 * filter out rerequests prompted by a long server queue.
		 * Note we only do it at chunk granularity.
		 */
		if (enqueued) {
			if (lostmap)
				lostmap[chunk]++;
			DOSTAT(clientlost++);
		}
	}
}

/*
 * A client joins. We print out the time at which the client joins, and
 * return a reply packet with the number of chunks in the file so that
 * the client knows how much to ask for. We do not do anything else with
 * this info; clients can crash and go away and it does not matter. If they
 * crash they will start up again later. Inactivity is defined as a period
 * with no data block requests. The client will resend its join message
 * until it gets a reply back; duplicates of either the request or the
 * reply are harmless.
 */
static void
ClientJoin(Packet_t *p, int version)
{
	struct in_addr	ipaddr   = { p->hdr.srcip };
	unsigned int    clientid = p->msg.join.clientid;
	int		i, j;

	EVENT(1, EV_JOINREQ, ipaddr, clientid, version, 0, 0);
	WorkQueueEnqueueJoin(version, clientid);

	/*
	 * Sanity check the new client.
	 */
	j = -1;
	for (i = 0; i < nextclientix; i++) {
		if (clients[i].id == clientid) {
			if (clients[i].ip != ipaddr.s_addr) {
				FrisLog("%s reuses active client id",
					inet_ntoa(ipaddr));
				clients[i].ip = ipaddr.s_addr;
			}
			break;
		}
		if (clients[i].ip == ipaddr.s_addr) {
			int k;

			FrisLog("%s rejoins with different cid, ocid=%u",
				inet_ntoa(ipaddr), clients[i].id);

			/*
			 * Index is assumed to be unique, so look for other
			 * users. We just report it now.
			 */
			for (k = i + 1; k < nextclientix; k++)
				if (clients[k].id == clients[i].id) {
					FrisLog("%s also using cid; "
						"pooch screwed",
						clients[k].ip);
				}

			clients[i].id = clientid;
			break;
		}
		if (j == -1 && clients[i].id == 0)
			j = i;
	}
	if (i == nextclientix) {
		if (j == -1 && nextclientix < MAXCLIENTS) {
			j = nextclientix++;
			if (nextclientix > maxclientnum)
				maxclientnum = nextclientix;
		}
		if (j != -1) {
			activeclients++;
			totalclients++;
			clients[j].id = clientid;
			clients[j].ip = ipaddr.s_addr;
			clients[j].lastseq = 0;
		} else {
			FrisLog("more than %d clients, not tracking %s",
				MAXCLIENTS, inet_ntoa(ipaddr));
		}
		i = j;
	}
	DOSTAT(joinrep++);

	EVENT(1, EV_JOINREP, ipaddr, CHUNKSIZE, BLOCKSIZE,
	      (FileInfo.filesize >> 32), FileInfo.filesize);

	/*
	 * Log after we send reply so that we get the packet off as
	 * quickly as possible!
	 */
	FrisLog("%s (id %u, image %s) joins (v%d) at %s!  %d active clients.",
		inet_ntoa(ipaddr), clientid, filename, version,
		CurrentTimeString(), activeclients);
}

/*
 * A client leaves. Not much to it. All we do is print out a log statement
 * about it so that we can see the time. If the packet is lost, no big deal.
 */
static void
ClientLeave(Packet_t *p)
{
	struct in_addr	ipaddr = { p->hdr.srcip };
	unsigned int clientid = p->msg.leave.clientid;
	int i;

	EVENT(1, EV_LEAVEMSG, ipaddr, clientid, p->msg.leave.elapsed, 0, 0);

	i = findclient(clientid);
	if (i >= 0) {
		clients[i].id = clients[i].ip = 0;
		clients[i].lastseq = 0;
		if (nextclientix == i + 1)
			nextclientix = i;
		activeclients--;
		FrisLog("%s (id %u, image %s): leaves at %s, "
			"ran for %d seconds.  %d active clients",
			inet_ntoa(ipaddr), clientid, filename,
			CurrentTimeString(), p->msg.leave.elapsed,
			activeclients);
	} else
		FrisLog("%s (id %u): spurious leave ignored",
			inet_ntoa(ipaddr), clientid);
}

/*
 * A client leaves. Not much to it. All we do is print out a log statement
 * about it so that we can see the time. If the packet is lost, no big deal.
 */
static void
ClientLeave2(Packet_t *p)
{
	struct in_addr	ipaddr = { p->hdr.srcip };
	unsigned int clientid = p->msg.leave2.clientid;
	int i;

	EVENT(1, EV_LEAVEMSG, ipaddr, clientid, p->msg.leave2.elapsed, 0, 0);

	i = findclient(clientid);
	if (i >= 0) {
		clients[i].id = clients[i].ip = 0;
		clients[i].lastseq = 0;
		if (nextclientix == i + 1)
			nextclientix = i;
		activeclients--;
		FrisLog("%s (id %u, image %s): leaves at %s, "
			"ran for %d seconds.  %d active clients",
			inet_ntoa(ipaddr), clientid, filename,
			CurrentTimeString(), p->msg.leave2.elapsed,
			activeclients);
#ifdef STATS
		ClientStatsDump(clientid, &p->msg.leave2.stats);
#endif
	} else
		FrisLog("%s (id %u): spurious leave ignored",
			inet_ntoa(ipaddr), clientid);
}

/*
 * A client requests a chunk/block. Add to the workqueue, but do not
 * send a reply. The client will make a new request later if the packet
 * got lost.
 */
static void
ClientRequest(Packet_t *p)
{
	struct in_addr	ipaddr = { p->hdr.srcip };
	int		chunk = p->msg.request.chunk;
	int		block = p->msg.request.block;
	int		count = p->msg.request.count;
	BlockMap_t	tmp;

	if (block < 0 || block >= MAXCHUNKSIZE ||
	    count <= 0 || count > MAXCHUNKSIZE ||
	    block + count > MAXCHUNKSIZE) {
		FrisLog("WARNING: Bad request from %s - "
			"chunk:%d block:%d size:%d; ignored",
			inet_ntoa(ipaddr), chunk, block, count);
		return;
	}

	EVENT(1, EV_REQMSG, ipaddr, chunk, block, count, 0);

	BlockMapInit(&tmp, block, count);
	ClientEnqueueMap(chunk, &tmp, count, 0);

	if (debug > 1) {
		FrisLog("Client %s requests chunk:%d block:%d size:%d",
			inet_ntoa(ipaddr), chunk, block, count);
	}
}

/*
 * A client requests a chunk/block. Add to the workqueue, but do not
 * send a reply. The client will make a new request later if the packet
 * got lost.
 */
static void
ClientPartialRequest(Packet_t *p)
{
	struct in_addr	ipaddr = { p->hdr.srcip };
	int		chunk = p->msg.prequest.chunk;
	int		count;

	count = BlockMapIsAlloc(&p->msg.prequest.blockmap, 0, MAXCHUNKSIZE);

	if (count == 0) {
		FrisLog("WARNING: ClientPartialRequest with zero count; ignored");
		return;
	}

	EVENT(1, EV_PREQMSG, ipaddr, chunk, count, p->msg.prequest.retries, 0);
	ClientEnqueueMap(chunk, &p->msg.prequest.blockmap, count,
			 p->msg.prequest.retries);

	if (debug > 1) {
		FrisLog("Client %s requests %d blocks of chunk:%d",
			inet_ntoa(ipaddr), count, chunk);
	}
}

static void
ClientReport(Packet_t *p)
{
	struct in_addr ipaddr = { p->hdr.srcip };
	uint32_t seq = 0, tstamp = 0;
	ClientSummary_t *sump = NULL;
	ClientStats_t *statp = NULL;
	uint32_t lastseq;
	int i;

	if (p->hdr.type != PKTTYPE_REPLY ||
	    p->msg.progress.hdr.clientid == 0 ||
	    p->msg.progress.hdr.when == 0 ||
	    (p->msg.progress.hdr.what != 0 &&
	     p->hdr.datalen < sizeof(p->msg.progress)))
		return;

	if ((i = findclient(p->msg.progress.hdr.clientid)) < 0)
		return;

	lastseq = clients[i].lastseq;
	DOSTAT(reportslogged++);

	/* XXX keep the server alive */
	gettimeofday(&IdleTimeStamp, 0);

	tstamp = p->msg.progress.hdr.when;
	seq = p->msg.progress.hdr.seq;

	/*
	 * For a proxied request, we report the node we are proxying
	 * on behalf of rather than the source of the packet.
	 */
	if (p->msg.progress.hdr.who != 0 &&
	    p->msg.progress.hdr.who != p->hdr.srcip)
		ipaddr.s_addr = p->msg.progress.hdr.who;

	if (p->msg.progress.hdr.what == 0) {
		FrisLog("%s (id %u): reports at %u",
			inet_ntoa(ipaddr),
			p->msg.progress.hdr.clientid, tstamp);
	} else {
		if (p->msg.progress.hdr.what & PKTPROGRESS_SUMMARY) {
			sump = &p->msg.progress.summary;
			FrisLog("%s (id %u): reports summary at %u: "
				"recv=%u, decomp=%u, written=%llu",
				inet_ntoa(ipaddr),
				p->msg.progress.hdr.clientid,
				tstamp,
				p->msg.progress.summary.chunks_in,
				p->msg.progress.summary.chunks_out,
				p->msg.progress.summary.bytes_out);
		}
#ifdef STATS
		if (p->msg.progress.hdr.what & PKTPROGRESS_STATS) {
			statp = &p->msg.progress.stats;
			FrisLog("%s (id %u): reports stats at %u: ",
				inet_ntoa(ipaddr),
				p->msg.progress.hdr.clientid, tstamp);
			ClientStatsDump(p->msg.progress.hdr.clientid, statp);
		}
#endif
	}

	if (seq != lastseq + 1)
		FrisLog("%s (id %u): lost reports: last=%u, this=%u",
			inet_ntoa(ipaddr),
			p->msg.progress.hdr.clientid, lastseq, seq);
	clients[i].lastseq = seq;

#ifdef EMULAB_EVENTS
	/*
	 * Send an event to whoever might be tracking progress of the
	 * image load. XXX-y stuff:
	 *
	 * - We don't know the Emulab node_id so we pass the IP address
	 *
	 * - We don't know the official Emulab "pid/image:version" tag
	 *   either, but we try to intuit it from the image pathname.
	 *   That code (in utils.c) is awful, awful, awful!
	 */
	if (hserver) {
		static char *image = NULL;
		static int failed = 0;
		char *node;

		node = inet_ntoa(ipaddr);
		if (image == NULL)
			image = extract_imageid(filename);

		if (image == NULL ||
		    EventSendClientReport(node, image, tstamp, seq,
					  sump, statp) != 0) {
			if (failed++ == 0)
				FrisWarning("unable to send event!");
		} else
			failed = 0;
	}
#endif
}

/*
 * The server receive thread. This thread does nothing more than receive
 * request packets from the clients, and add to the work queue.
 */
void *
ServerRecvThread(void *arg)
{
	Packet_t	packet, *p = &packet;
	int		idles = 0, kafails = 0;
	static int	gotone;

	if (debug > 1)
		FrisLog("Server pthread starting up ...");
	
	/*
	 * Recalculate keepalive interval in terms of packet receive
	 * timeouts for simplicity.
	 */
	if (keepalive)
		keepalive = (int)(((unsigned long long)keepalive * 1000000) /
				  PKTRCV_TIMEOUT);
	while (1) {
		pthread_testcancel();
		if (PacketReceive(p) != 0) {
			if (keepalive && ++idles > keepalive) {
				if (NetMCKeepAlive()) {
					FrisWarning("Multicast keepalive failed");
					if (++kafails > 5) {
						FrisWarning("too many failures, disabled");
						keepalive = 0;
					}
				} else {
					kafails = 0;
					idles = 0;
					if (debug > 1)
						FrisLog("Ping...");
				}
			}
			continue;
		}
		idles = 0;
		DOSTAT(msgin++);

		if (! PacketValid(p, FileInfo.chunks)) {
			struct in_addr ipaddr = { p->hdr.srcip };
			DOSTAT(badpackets++);
			FrisLog("bad packet %d/%d from %s, ignored",
				p->hdr.type, p->hdr.subtype,
				inet_ntoa(ipaddr));
			if (p->hdr.type == PKTTYPE_REQUEST &&
			    (p->hdr.subtype == PKTSUBTYPE_REQUEST ||
			     p->hdr.subtype == PKTSUBTYPE_PREQUEST))
				FrisLog("  len=%d, chunk=%d(%d), word2=%d",
					p->hdr.datalen, p->msg.request.chunk,
					FileInfo.chunks, p->msg.request.block);
			continue;
		}
		gettimeofday(&LastReq, 0);
		if (!gotone) {
			FirstReq = LastReq;
			gotone = 1;
		}

		switch (p->hdr.subtype) {
		case PKTSUBTYPE_JOIN:
			DOSTAT(joins++);
			ClientJoin(p, 1);
			break;
		case PKTSUBTYPE_JOIN2:
			DOSTAT(joins++);
			ClientJoin(p, 2);
			break;
		case PKTSUBTYPE_LEAVE:
			DOSTAT(leaves++);
			ClientLeave(p);
			break;
		case PKTSUBTYPE_LEAVE2:
			DOSTAT(leaves++);
			ClientLeave2(p);
			break;
		case PKTSUBTYPE_REQUEST:
			DOSTAT(requests++);
			ClientRequest(p);
			break;
		case PKTSUBTYPE_PREQUEST:
			DOSTAT(requests++);
			ClientPartialRequest(p);
			break;
		case PKTSUBTYPE_PROGRESS:
			DOSTAT(reports++);
			ClientReport(p);
			break;
		}
	}
}

/*
 * The main thread spits out blocks. 
 *
 * NOTES: Perhaps use readv into a vector of packet buffers?
 */
static void
PlayFrisbee(void)
{
	int		chunk = 0, block = 0;
	int		blockcount, cc, j, idlelastloop = 1;
	int		startblock, lastblock, throttle = 0, thisburst = 0;
	Packet_t	packet, *p = &packet;
	char		*databuf;
	off_t		offset;
	struct timeval	startnext;

	if ((databuf = malloc(readsize * MAXBLOCKSIZE)) == NULL)
		FrisFatal("could not allocate read buffer");

	while (1) {
		if (killme) {
			FrisLog("Interrupted!");
			break;
		}
		
		/*
		 * Look for a WorkQ item to process. When there is nothing
		 * to process, check for being idle too long, and exit if
		 * no one asks for anything for a long time. Note that
		 * WorkQueueDequeue will delay for a while, so this will not
		 * spin.
		 */
		if (! WorkQueueDequeue(&chunk, &startblock, &blockcount)) {
			struct timeval stamp;

			gettimeofday(&stamp, 0);

			/* Record interval termination */
			if (burstinterval > 0 && thisburst > burstsize) {
				EVENT(1, EV_LONGBURST2,
				      mcastaddr,
				      thisburst,
				      burstsize,
				      chunk, block);
				thisburst = 0;
			}

			/* If zero, never exit */
			if (timeout == 0) {
				if (!idlelastloop) {
					DOSTAT(goesidle++);
					idlelastloop = 1;
				}
				continue;
			}
			
			/* If less than zero, exit when last client leaves */
			if (timeout < 0 &&
			    totalclients > 0 && activeclients == 0) {
				fsleep(2000000);
				FrisLog("Last client left!");
				break;
			}

			if (idlelastloop) {
				if (timeout > 0 &&
				    stamp.tv_sec - IdleTimeStamp.tv_sec >
				    timeout) {
					FrisLog("No requests or reports "
						"for %d seconds "
						"(%d remaining clients)",
						timeout, activeclients);
					break;
				}
			} else {
				DOSTAT(goesidle++);
				IdleTimeStamp.tv_sec = stamp.tv_sec;
				idlelastloop = 1;
			}
			continue;
		}
		/*
		 * If coming out of idle, restart the interval
		 */
		if (idlelastloop) {
			if (burstinterval > 0) {
				struct timeval stamp;

				gettimeofday(&stamp, 0);
				addusec(&startnext, &stamp, burstinterval);
				throttle = thisburst = 0;
			}
			idlelastloop = 0;
		}
		
#ifdef PRINT_GRAPH_INFO
		{
		static int firsttime = 1;
		if (firsttime) {
			struct timeval stamp;
			firsttime = 0;

			gettimeofday(&stamp, 0);
			fprintf(stderr, "%u.%06u %d\n",
				(unsigned)stamp.tv_sec,
				(unsigned)stamp.tv_usec, burstsize);
		}
		}
#endif

		/*
		 * Handle JOIN reply.
		 *
		 * XXX this is outside the normal packet pacing mechanism,
		 * I see no reason to overly complicate this path for the
		 * rare JOIN messages.
		 */
		if (chunk < 0) {
			/* XXX */
			int jvers = -chunk;
			uint32_t clientid = (uint32_t)blockcount;

			assert(jvers == 1 || jvers == 2);

			if (debug)
				FrisLog("sending JOIN%d reply to %u",
					jvers, clientid);
			p->hdr.type = PKTTYPE_REPLY;
			if (jvers == 1) {
				p->hdr.subtype = PKTSUBTYPE_JOIN;
				p->hdr.datalen = sizeof(p->msg.join);
				p->msg.join.clientid = clientid;
				p->msg.join.blockcount = FileInfo.blocks;
			} else {
				p->hdr.subtype = PKTSUBTYPE_JOIN2;
				p->hdr.datalen = sizeof(p->msg.join2);
				p->msg.join2.clientid = clientid;
				p->msg.join2.blockcount = 0;
				p->msg.join2.chunksize = CHUNKSIZE;
				p->msg.join2.blocksize = BLOCKSIZE;
				p->msg.join2.bytecount = FileInfo.filesize;
			}
			PacketSend(p, 0);

			/*
			 * Arrange for clients to report at the indicated interval.
			 * Note that this request is broadcast, but only the
			 * indicated client should effect the changes indicated.
			 *
			 * XXX for now we just hardwire the type.
			 */
			if (hinterval > 0) {
				if (debug)
					FrisLog("sending PROGRESS request to %u",
						clientid);
				p->hdr.type = PKTTYPE_REQUEST;
				p->hdr.subtype = PKTSUBTYPE_PROGRESS;
				p->hdr.datalen = sizeof(p->msg.progress.hdr);
				p->msg.progress.hdr.clientid = clientid;
				p->msg.progress.hdr.who = 0;
				p->msg.progress.hdr.when = hinterval;
				p->msg.progress.hdr.what = PKTPROGRESS_SUMMARY;
				p->msg.progress.hdr.seq = 1;
				PacketSend(p, 0);
			}
			continue;
		}

		lastblock = startblock + blockcount;

		/* Offset within the file */
		offset = (((off_t) MAXBLOCKSIZE * chunk * MAXCHUNKSIZE) +
			  ((off_t) MAXBLOCKSIZE * startblock));

		for (block = startblock; block < lastblock; ) {
			int	readcount;
			int	readbytes;
			int	resends;
			int	resid = 0;
#if defined(TRACE_EVENTS) || defined(STATS)
			struct timeval rstamp;
			gettimeofday(&rstamp, 0);
#endif

			/*
			 * Read blocks of data from disk.
			 */
			if (lastblock - block > readsize)
				readcount = readsize;
			else
				readcount = lastblock - block;
			readbytes = readcount * MAXBLOCKSIZE;

			/*
			 * Check for final partial block and truncate
			 * read if necessary.  This should only happen
			 * for the last block of a file, a request beyond
			 * that is an error (and do what?)
			 */
			if (offset+readbytes > FileInfo.filesize) {
				off_t diff =
					(offset+readbytes) - FileInfo.filesize;
				if (!FileInfo.isimage &&
				    diff < (off_t)MAXBLOCKSIZE) {
					readbytes -= diff;
					resid = (int)diff;
				} else {
					FrisWarning("Attempt to read beyond EOF "
						    "(offset %llu > %llu)\n",
						    offset+readbytes,
						    FileInfo.filesize);
					/* XXX just do not respond */
					break;
				}
			}

			if ((cc = mypread(FileInfo.fd, databuf,
					  readbytes, offset)) <= 0) {
				if (cc < 0)
					FrisPfatal("Reading File");
				FrisFatal("EOF on file");
			}
#ifdef STATS
			{
				struct timeval now;
				int us;
				gettimeofday(&now, 0);
				timersub(&now, &rstamp, &now);
				us = now.tv_sec * 1000000 + now.tv_usec;
				assert(us >= 0);
				Stats.fileusecs += us;
				if (us > Stats.filemaxusec)
					Stats.filemaxusec = us;
			}
#endif
			DOSTAT(filereads++);
			DOSTAT(filebytes += cc);
			EVENT(2, EV_READFILE, mcastaddr,
			      offset, readbytes, rstamp.tv_sec, rstamp.tv_usec);
			if (cc != readbytes)
				FrisFatal("Short read: %d!=%d", cc, readbytes);

			for (j = 0; j < readcount; j++) {
				p->hdr.type    = PKTTYPE_REQUEST;
				p->hdr.subtype = PKTSUBTYPE_BLOCK;
				p->hdr.datalen = sizeof(p->msg.block);
				p->msg.block.chunk = chunk;
				p->msg.block.block = block + j;

				/*
				 * If final block is short, pad it out.
				 * The receiver knows the exact size and
				 * can compensate.
				 */
				if (resid && j == readcount-1) {
					int count = MAXBLOCKSIZE - resid;
					memcpy(p->msg.block.buf,
					       &databuf[j * MAXBLOCKSIZE],
					       count);
					memset(&p->msg.block.buf[count],
					       0, resid);
					if (debug)
						FrisLog("Handle partial final block, padded with %d bytes",
							resid);
				} else {
					memcpy(p->msg.block.buf,
					       &databuf[j * MAXBLOCKSIZE],
					       MAXBLOCKSIZE);
				}
#ifdef STATS
				struct timeval wstamp;
				gettimeofday(&wstamp, 0);
#endif
				PacketSend(p, &resends);
#ifdef STATS
				{
					struct timeval now;
					int us;
					gettimeofday(&now, 0);
					timersub(&now, &wstamp, &now);
					us = now.tv_sec * 1000000 +
						now.tv_usec;
					assert(us >= 0);
					Stats.netusecs += us;
					if (us > Stats.netmaxusec)
						Stats.netmaxusec = us;
					if (us >= 1000)
						Stats.netmsplus++;
				}
#endif
				sendretries += resends;
				DOSTAT(blockssent++);
				EVENT(resends ? 1 : 3, EV_BLOCKMSG, mcastaddr,
				      chunk, block+j, resends, 0);

				/*
				 * Completed a burst.  Adjust the busrtsize
				 * if necessary and delay as required.
				 */
				if (burstinterval > 0 &&
				    ++throttle >= burstsize) {
					thisburst += throttle;

					/*
					 * XXX if we overran our interval, we
					 * reset the base time so we don't
					 * accumulate error.
					 */
					if (!sleeptil(&startnext)) {
						EVENT(1, EV_OVERRUN, mcastaddr,
						      startnext.tv_sec,
						      startnext.tv_usec,
						      chunk, block+j);
						gettimeofday(&startnext, 0);
						DOSTAT(missed++);
					} else {
						if (thisburst > burstsize)
							EVENT(1, EV_LONGBURST,
							      mcastaddr,
							      thisburst,
							      burstsize,
							      chunk, block+j);
						thisburst = 0;
					}
					if (dynburst)
						calcburst();
					addusec(&startnext, &startnext,
						burstinterval);
					throttle = 0;
					DOSTAT(intervals++);
				}
			}
			offset   += readbytes;
			block    += readcount;
		}
	}
	free(databuf);
}

char *usagestr = 
 "usage: frisbeed [-d] <-p #> <-m mcastaddr> <filename>\n"
 " -d              Turn on debugging. Multiple -d options increase output.\n"
 " -p portnum      Specify a port number to listen on (0 to pick avail port).\n"
 " -m mcastaddr    Specify a multicast address in dotted notation.\n"
 " -i mcastif      Specify a multicast interface in dotted notation.\n"
 " -b              Use broadcast instead of multicast\n"
 " -A file         Write address info to file in format <addr>:<port>.\n"
 "\n";

void
usage()
{
	fprintf(stderr, "%s", usagestr);
	exit(1);
}

int
main(int argc, char **argv)
{
	int		ch, fd;
	pthread_t	child_pid;
	off_t		fsize;
	void		*ignored;

	while ((ch = getopt(argc, argv, "dhp:k:m:i:tbDT:R:B:G:L:W:K:A:E:H:")) != -1)
		switch(ch) {
		case 'b':
			broadcast++;
			break;
			
		case 'd':
			debug++;
			break;
			
		case 'p':
			if (strchr(optarg, '-')) {
				char *h = strchr(optarg, '-');
				*h = '\0';
				portlo = atoi(optarg);
				porthi = atoi(h+1);
				*h = '-';
				if (portlo < 0 || portlo > 65535 ||
				    porthi < 0 || porthi > 65535 ||
				    portlo > porthi)
					usage();
			} else {
				portlo = atoi(optarg);
				porthi = portlo;
				if (portlo < 0 || portlo > 65535)
					usage();
			}
			break;
			
		case 'k':
			sockbufsize = atoi(optarg);
			if (sockbufsize <= 0 ||
			    (sockbufsize * 1024) > MAXSOCKBUFSIZE)
				sockbufsize = MAXSOCKBUFSIZE;
			else
				sockbufsize *= 1024;
			break;

		case 'm':
			inet_aton(optarg, &mcastaddr);
			break;

		case 'i':
			inet_aton(optarg, &mcastif);
			break;
		case 't':
			tracing++;
			break;
		case 'D':
			dynburst = 1;
			break;
		case 'T':
			timeout = atoi(optarg);
			break;
		case 'R':
			readsize = atoi(optarg);
			if (readsize == 0 || readsize > MAXCHUNKSIZE) {
				FrisWarning("readsize set to %d",
					    MAXCHUNKSIZE);
				readsize = MAXCHUNKSIZE;
			}
			break;
		case 'B':
			burstsize = atoi(optarg);
			break;
		case 'G':
			burstinterval = atoi(optarg);
			break;
		case 'W':
			bandwidth = atol(optarg);
			break;
		case 'K':
			keepalive = atoi(optarg);
			if (keepalive < 0)
				keepalive = 0;
			break;
		case 'A':
			addrfilename = optarg;
			break;
		case 'E':
#ifdef EMULAB_EVENTS
			hserver = optarg;
			break;
#else
			fprintf(stderr, "Not compiled for Emulab events\n");
			exit(1);
#endif
		case 'H':
			/*
			 * For now this is just the reporting interval.
			 */
			hinterval = atoi(optarg);
			if (hinterval > 3600)
				hinterval = 3600;
			break;

		case 'h':
		case '?':
		default:
			usage();
		}
	argc -= optind;
	argv += optind;
	if (argc != 1)
		usage();

	if (portlo < 0 || !mcastaddr.s_addr)
		usage();

	if (timeout > 0 && keepalive > timeout) {
		FrisWarning("keepalive > timeout, disabling keepalive");
		keepalive = 0;
	}

	signal(SIGINT, quit);
	signal(SIGTERM, quit);
	signal(SIGHUP, reinit);

	ServerLogInit();
	
	filename = argv[0];
	if (access(filename, R_OK) < 0)
		FrisPfatal("Cannot read %s", filename);

	/*
	 * Open the file and get its size so that we can tell clients how
	 * much to expect/require.
	 */
	if ((fd = open(filename, O_RDONLY)) < 0)
		FrisPfatal("Cannot open %s", filename);

	if ((fsize = lseek(fd, (off_t)0, SEEK_END)) < 0)
		FrisPfatal("Cannot lseek to end of file");

	InitSizes(MAXCHUNKSIZE, MAXBLOCKSIZE, fsize);
	FileInfo.fd = fd;
	FileInfo.filesize = fsize;
	FileInfo.blocks = TotalBlocks();
	FileInfo.chunks = TotalChunks();
	if ((FileInfo.filesize % (BLOCKSIZE * CHUNKSIZE)) == 0)
		FileInfo.isimage = 1;
	else
		FrisWarning("NOTE: serving non-image file, will ignore V1 JOINs");

	FrisLog("Opened %s: %d blocks (%lld bytes)",
		filename, FileInfo.blocks, FileInfo.filesize);

	compute_sendrate();

	WorkQueueInit();
	lostmap = calloc(FileInfo.chunks, 1);

	/*
	 * Everything else done, now init the network.
	 */
	ServerNetInit(portlo, porthi);
	if (addrfilename) {
		/* long enough for XXX.XXX.XXX.XXX:DDDDD\n\0 */
		char ainfo[24];
		int afd, len;

		snprintf(ainfo, sizeof(ainfo), "%s:%u\n",
			 inet_ntoa(mcastaddr), (unsigned)portnum);
		afd = open(addrfilename, O_WRONLY|O_CREAT|O_TRUNC, 0644);
		if (afd < 0)
			FrisPfatal(addrfilename);
		len = strlen(ainfo) + 1;
		if (write(afd, ainfo, len) != len) {
			close(afd);
			unlink(addrfilename);
			FrisFatal("%s: could not write address info\n",
				  addrfilename);
		}
		close(afd);
	}

#ifdef EMULAB_EVENTS
	if (hserver && EventInit(hserver))
		FrisWarning("not forwarding heartbeat events");
#endif
	if (tracing) {
		ServerTraceInit("frisbeed");
		TraceStart(tracing);
	}

	/*
	 * Create the subthread to listen for packets.
	 */
	if (pthread_create(&child_pid, NULL, ServerRecvThread, (void *)0)) {
		FrisFatal("Failed to create pthread!");
	}
	gettimeofday(&IdleTimeStamp, 0);
	
	PlayFrisbee();
	pthread_cancel(child_pid);
	pthread_join(child_pid, &ignored);

	if (tracing) {
		TraceStop();
		TraceDump(1, tracing);
	}
	subtime(&LastReq, &LastReq, &FirstReq);

#ifdef EMULAB_EVENTS
	if (hserver)
		EventDeinit();
#endif

	dumpstats();

	/*
	 * Exit from main thread will kill all the children.
	 */
	FrisLog("Exiting!");
	exit(0);
}

/*
 * We catch the signals, but do not do anything. We exit with 0 status
 * for these, since it indicates a desired shutdown.
 */
void
quit(int sig)
{
	killme = 1;
}

/*
 * We cannot reinit, so exit with non-zero to indicate it was unexpected.
 */
void
reinit(int sig)
{
	FrisLog("Caught signal %d. Exiting ...", sig);
	exit(1);
}

#define NFS_READ_DELAY	100000

/*
 * Wrap up pread with a retry mechanism to help protect against
 * transient NFS errors.
 */
static ssize_t
mypread(int fd, void *buf, size_t nbytes, off_t offset)
{
	int		cc, i, count = 0;

	while (nbytes) {
		int	maxretries = 100;

		for (i = 0; i < maxretries; i++) {
			cc = pread(fd, buf, nbytes, offset);
			if (cc == 0)
				FrisFatal("EOF on file");

			if (cc > 0) {
				nbytes -= cc;
				buf    += cc;
				offset += cc;
				count  += cc;
				goto again;
			}

			if (i == 0)
				FrisPwarning("read error: will retry");

			fsleep(NFS_READ_DELAY);
		}
		FrisPfatal("read error: busted for too long");
		return -1;
	again:
		;
	}
	return count;
}

static int
findclient(uint32_t id)
{
	int i;

	for (i = 0; i < nextclientix; i++)
		if (clients[i].id == id)
			return i;
	return -1;
}

#define LINK_OVERHEAD	(14+4+8+12)	/* ethernet (hdr+CRC+preamble+gap) */
#define IP_OVERHEAD	(20+8)		/* IP + UDP hdrs */

#define LOSS_INTERVAL	500	/* interval in which we collect data (ms) */
#define MULT_DECREASE	0.90	/* mult factor to decrease burst rate */
#define ADD_INCREASE	1	/* add factor to increase burst rate */

#define CHUNK_LIMIT	0

/*
 * Should we consider PacketSend retries?   They indicated that we are over
 * driving the socket?  Even though they have a builtin delay between retries,
 * we might be better off detecting the case and avoiding the delays.
 *
 * From Dave:
 *
 * A smoother one that is still fair with TCP is:
 *    W_{next} = W_{cur} - sqrt( W_{cur} ) if loss
 *    W_{next} = W_{cur} + 1 / sqrt( W_{cur} )  if no loss
 */
static void
calcburst(void)
{
	static int		lastsendretries, bursts, lastclientretries;
	static struct timeval	nextstamp;
	struct timeval		stamp;
	int			clientlost, lostchunks, hadloss = 0;

	gettimeofday(&stamp, 0);
	if (nextstamp.tv_sec == 0) {
		addusec(&nextstamp, &stamp, LOSS_INTERVAL * 1000);
		return;
	}

	bursts++;

	/*
	 * Has a full interval passed?
	 */
	if (!pasttime(&stamp, &nextstamp))
		return;

	/*
	 * An interval has past, now what constitiues a significant loss?
	 * The number of explicit client retry requests during the interval
	 * is the basis right now.
	 */
	clientlost = clientretries - lastclientretries;

	/*
	 * If we are overrunning our UDP socket then we are certainly
	 * transmitting too fast.
	 */
	if (sendretries - lastsendretries > 0)
		hadloss = 1;

	lostchunks = 0;
	if (lostmap) {
		int i;
		for (i = 0; i < FileInfo.chunks; i++)
			if (lostmap[i]) {
				lostchunks++;
				lostmap[i] = 0;
			}
	}

	if (lostchunks > CHUNK_LIMIT)
		hadloss = 1;

	if (debug > 1 && hadloss)
		FrisLog("%d client retries for %d chunks from %d clients, "
			"%d overruns in %d bursts",
			clientlost, lostchunks, activeclients,
			sendretries-lastsendretries, bursts);

	if (hadloss) {
		/*
		 * Decrement the burstsize slowly.
		 */
		if (burstsize > 1) {
			int obsize = burstsize;

			burstsize = (int)(burstsize * MULT_DECREASE);
			if (burstsize == obsize)
				burstsize--;
			if (burstsize < 1)
				burstsize = 1;
#ifdef PRINT_GRAPH_INFO
			fprintf(stderr, "%u.%06u %d\n",
				(unsigned)stamp.tv_sec,
				(unsigned)stamp.tv_usec, burstsize);
#endif
			if (debug > 1)
				FrisLog("Decrement burstsize to %d",
					burstsize);
#ifdef STATS
			Stats.dyndecs++;
			if (burstsize < Stats.dynminburst)
				Stats.dynminburst = burstsize;
#endif
		}
	} else {
		/*
		 * Increment the burstsize even more slowly.
		 */
		if (burstsize < maxburstsize) {
			burstsize += ADD_INCREASE;
			if (burstsize > maxburstsize)
				burstsize = maxburstsize;
#ifdef PRINT_GRAPH_INFO
			fprintf(stderr, "%u.%06u %d\n",
				(unsigned)stamp.tv_sec,
				(unsigned)stamp.tv_usec, burstsize);
#endif
			if (debug > 1)
				FrisLog("Increment burstsize to %d",
					burstsize);
#ifdef STATS
			Stats.dynincs++;
			if (burstsize > Stats.dynmaxburst)
				Stats.dynmaxburst = burstsize;
#endif
		}
	}

	/*
	 * Update for next time
	 */
	addusec(&nextstamp, &nextstamp, LOSS_INTERVAL * 1000);
	lastclientretries = clientretries;
	lastsendretries = sendretries;
	bursts = 0;
}

/*
 * Compute the approximate send rate.  Due to typically coarse grained
 * timers, send rate is implemented as a burst rate and a burst interval;
 * i.e. we put out "burst size" blocks every "burst interval" microseconds.
 * The user can specify either an aggregate bandwidth (bandwidth) or the
 * individual components (burstsize, burstinterval).
 */
static void
compute_sendrate(void)
{
	double blockspersec, burstspersec;
	int clockres, wireblocksize, minburst;

	if (burstinterval == 0) {
		if (!dynburst) {
			burstsize = 1;
			FrisLog("Maximum send bandwidth unlimited");
			return;
		}
		/*
		 * XXX in order for dynamic rate adjustment to work, we
		 * have to have burstsize/rate params set. So we just pick
		 * a high bandwidth cap here (10Gb/sec).
		 */
		bandwidth = 10000000000;
	}

	/* clock resolution in usec */
	clockres = sleeptime(1, 0, 1);

	burstspersec = 1000000.0 / clockres;
	wireblocksize = (sizeof(Packet_t) + IP_OVERHEAD + LINK_OVERHEAD) * 8;

	if (bandwidth != 0) {
		/*
		 * Convert bits/sec to blocks/sec
		 */
		blockspersec = bandwidth / wireblocksize;

		/*
		 * If blocks/sec less than maximum bursts/sec,
		 * crank down the clock.
		 */
		if (blockspersec < burstspersec)
			burstspersec = blockspersec;

		burstsize = blockspersec / burstspersec;
		burstinterval = (int)(1000000 / burstspersec);
	}

	burstinterval = sleeptime(burstinterval, 0, 1);
	burstspersec = 1000000.0 / burstinterval;
	bandwidth = (unsigned long)(burstspersec*burstsize*wireblocksize);

	/*
	 * For the dynamic rate throttle, we use the standard parameters
	 * as a cap.  We adjust the burstsize to ensure it is large
	 * enough to ensure that an initial multiplicitive decrement
	 * will produce a reasonable result (>= 4). If we cannot do
	 * that while still maintaining a reasonable burstinterval
	 * (< 0.5 seconds), just cancel the dynamic behavior.
	 */
	minburst = (int)((4.0 / MULT_DECREASE) + 0.5);
	if (dynburst && burstsize < minburst) {
		double burstfactor = (double)minburst / burstsize;

		if (burstinterval * burstfactor < 500000) {
			burstsize = minburst;
			burstinterval =
				sleeptime((int)burstinterval*burstfactor,
					  0, 1);
			burstspersec = (double)1000000.0 / burstinterval;
			bandwidth = (unsigned long)
				(burstspersec*burstsize*wireblocksize);
		} else
			dynburst = 0;
	}
	if (dynburst) {
		maxburstsize = burstsize;
#ifdef STATS
		Stats.dynminburst = Stats.dynmaxburst = burstsize;
#endif
	}

	if (!dynburst && burstsize * sizeof(Packet_t) > GetSockbufSize()) {
		FrisWarning("NOTE: burst size exceeds socket buffer size, "
			    "may drop packets");
	}

	FrisLog("Maximum send bandwidth %.3f Mbits/sec (%d blocks/sec)",
		bandwidth / 1000000.0, bandwidth / wireblocksize);
	if (debug)
		FrisLog("  burstsize=%d, burstinterval=%dus",
			burstsize, burstinterval);
}

#ifdef STATS
static unsigned long
compute_bandwidth(int bsize, int binterval)
{
	int wireblocksize = (sizeof(Packet_t)+IP_OVERHEAD+LINK_OVERHEAD) * 8;
	double burstspersec = 1000000.0 / binterval;

	return (unsigned long)(burstspersec*bsize*wireblocksize);
}
#endif

static void
dumpstats(void)
{
#ifdef  STATS
	struct rusage ru;
	extern unsigned long nonetbufs;

	getrusage(RUSAGE_SELF, &ru);
	FrisLog("Params:");
	FrisLog("  chunk/block size    %d/%d", MAXCHUNKSIZE, MAXBLOCKSIZE);
	FrisLog("  sockbuf size        %d KB", sockbufsize/1024);
	if (burstinterval == 0) {
		FrisLog("  burst size/interval unlimited");
		FrisLog("  bandwidth           unlimited");
	} else {
		unsigned long bw = compute_bandwidth(burstsize, burstinterval);
		FrisLog("  burst size/interval %d/%d",
			burstsize, burstinterval);
		FrisLog("  bandwidth           %d.%03d Mbit/sec",
			(int)(bw / 1000000), (int)((bw % 1000000) / 1000));
	}
	FrisLog("  file read size      %d blocks", readsize);
	FrisLog("  file:size           %s:%qd",
		filename, (long long)FileInfo.filesize);
	FrisLog("Stats:");
	FrisLog("  service time:      %d.%03d sec",
		LastReq.tv_sec, LastReq.tv_usec/1000);
	FrisLog("  user/sys CPU time: %d.%03d/%d.%03d",
		ru.ru_utime.tv_sec, ru.ru_utime.tv_usec/1000,
		ru.ru_stime.tv_sec, ru.ru_stime.tv_usec/1000);
	FrisLog("  max/total clients: %d/%d",
		maxclientnum, totalclients);
	FrisLog("  msgs in/out:       %d/%d",
		Stats.msgin, Stats.joinrep + Stats.blockssent);
	FrisLog("  joins/leaves:      %d/%d", Stats.joins, Stats.leaves);
	FrisLog("  reports recv/log:  %d/%d", Stats.reports, Stats.reportslogged);
	FrisLog("  requests:          %d (%d merged in queue)",
		Stats.requests, Stats.qmerges);
	FrisLog("  partial req/blks:  %d/%d",
		Stats.partialreq, Stats.blockslost);
	FrisLog("  duplicate req:     %d",
		Stats.dupsent);
	FrisLog("  client re-req:     %d",
		Stats.clientlost);
	FrisLog("  %dk blocks sent:    %d (%d repeated)",
		(MAXBLOCKSIZE/1024),
		Stats.blockssent, Stats.blockssent ?
		(Stats.blockssent-FileInfo.blocks) : 0);
	FrisLog("  block write time:  %d.%03d sec (%llu us/op, %d us max, %d 1ms+)",
		(int)(Stats.netusecs / 1000000),
		(int)((Stats.netusecs % 1000000) / 1000),
		Stats.netusecs / (Stats.blockssent ? Stats.blockssent : 1),
		Stats.netmaxusec, Stats.netmsplus);
	FrisLog("  file reads:        %d (%qu bytes, %qu repeated)",
		Stats.filereads, Stats.filebytes, Stats.filebytes ?
		(Stats.filebytes - FileInfo.filesize) : 0);
	FrisLog("  file read time:    %d.%03d sec (%llu us/op, %d us max)",
		(int)(Stats.fileusecs / 1000000),
		(int)((Stats.fileusecs % 1000000) / 1000),
		Stats.fileusecs / (Stats.filereads ? Stats.filereads : 1),
		Stats.filemaxusec);
	FrisLog("  net idle/blocked:  %d/%d", Stats.goesidle, nonetbufs);
	FrisLog("  send intvl/missed: %d/%d",
		Stats.intervals, Stats.missed);
	FrisLog("  sendbuf overruns:  %d", sendretries);
	FrisLog("  spurious wakeups:  %d", Stats.wakeups);
	FrisLog("  max workq size:    %d elts, %lu blocks",
		WorkQMax, WorkQMaxBlocks);
	if (dynburst) {
		unsigned long lbw, hbw;
		FrisLog("  dynburst incr/decr %d/%d",
			Stats.dynincs, Stats.dyndecs);
		FrisLog("    min/max burst    %d/%d",
			Stats.dynminburst, Stats.dynmaxburst);
		lbw = compute_bandwidth(Stats.dynminburst, burstinterval);
		hbw = compute_bandwidth(Stats.dynmaxburst, burstinterval);
		FrisLog("    min/max bw       %d.%03d/%d.%03d Mbit/sec",
			(int)(lbw / 1000000), (int)((lbw % 1000000) / 1000),
			(int)(hbw / 1000000), (int)((hbw % 1000000) / 1000));
	}
#endif
}
