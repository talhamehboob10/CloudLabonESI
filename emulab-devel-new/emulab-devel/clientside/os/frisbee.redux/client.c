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

#undef OLD_SCHOOL
#undef PASSIVE

/*
 * Frisbee client.
 *
 * TODO: Deal with a dead server. Its possible that too many clients
 * could swamp the boss with unanswerable requests. Might need some 
 * backoff code.
 */
#include <sys/types.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <syslog.h>
#include <signal.h>
#include <stdarg.h>
#include <pthread.h>
#include <errno.h>
#include <assert.h>
#include "decls.h"
#include "utils.h"
#include "trace.h"

/* Tunable constants */
int		maxchunkbufs = DEFCHUNKBUFS;
int		maxwritebufmem = DEFWRITEBUFMEM;
int		maxmem = 0;
int		pkttimeout = PKTRCV_TIMEOUT;
int		idletimer = CLIENT_IDLETIMER_COUNT;
int		maxreadahead = MAXREADAHEAD;
int		maxinprogress = MAXINPROGRESS;
int		redodelay = CLIENT_REQUEST_REDO_DELAY;
int		idledelay = CLIENT_WRITER_IDLE_DELAY;
int		startdelay = 0, startat = 0;

int		nothreads = 0;
int		nodecompress = 0;
int		debug = 0;
int		quiet = 0;
int		tracing = 0;
char		traceprefix[64];
int		randomize = 1;
int		zero = 0;
int		keepalive;
int		portnum;
int		sockbufsize = SOCKBUFSIZE;
struct in_addr	mcastaddr;
struct in_addr	mcastif;
char		*imageid;
int		askonly;
int		busywait = 0;
char		*proxyfor = NULL;
struct in_addr	proxyip;
static struct timeval stamp;
static uint32_t	clientid;
static struct in_addr serverip;
int		servertimo = 0;
#ifdef MASTER_SERVER
static int	xfermethods = MS_METHOD_MULTICAST;
#endif
int		forcedirectio = 0;
int		heartbeat = 0;

static uint32_t hb_interval;
static uint32_t	hb_dst, hb_who;
static uint16_t	hb_what;
static uint16_t	hb_seq;

/* Forward Decls */
static void	PlayFrisbee(void);
static void	HandleProgress(Packet_t *p);
static int	GotBlock(Packet_t *p);
static void	RequestChunk(int timedout);
static int	RequestStamp(int chunk, int block, int count, void *arg);
static int	RequestRedoTime(int chunk, unsigned long long curtime);
extern int	ImageUnzipInitKeys(char *uuidstr, char *sig_keyfile,
				   char *enc_keyfile);
extern int	ImageUnzipInit(char *filename, int slice, int debug, int zero,
			       int nothreads, int dostype, int dodots,
			       unsigned long long writebufmem, int directio);
extern void	ImageUnzipSetChunkCount(unsigned long chunkcount);
extern void	ImageUnzipSetMemory(unsigned long long writebufmem);
extern int	ImageWriteChunk(int chunkno, char *chunkdata, int chunksize);
extern int	ImageUnzipChunk(char *chunkdata, int chunksize);
extern int	ImageUnzipFlush(void);
extern int	ImageUnzipQuit(void);

/*
 * Chunk descriptor, one per MAXCHUNKSIZE*MAXBLOCKSIZE bytes of an image file.
 * For each chunk, record its state and the time at which it was last
 * requested by someone.  The time stamp is "only" 60 bits.  This could be a
 * problem if packets arrive more than 36,500 years apart.  But we'll take
 * our chances...
 */
typedef struct {
#ifdef PASSIVE
	uint64_t lastreq:60;
	uint64_t enroute:1;	/* we have seen a request but no data yet */
#else
	uint64_t lastreq:61;
#endif
	uint64_t ours:1;	/* last request was from us */
	uint64_t seen:1;	/* chunk is either filling or been processed */
	uint64_t done:1;	/* chunk has been fully processed */
} Chunk_t;

/*
 * The chunker data structure. For each chunk in progress, we maintain this
 * array of blocks (plus meta info). This serves as a cache to receive
 * blocks from the server while we write completed chunks to disk. The child
 * thread reads packets and updates this cache, while the parent thread
 * simply looks for completed blocks and writes them. The "inprogress" slot
 * serves a free/allocated flag, while the ready bit indicates that a chunk
 * is complete and ready to write to disk.
 */
typedef struct {
	int	   thischunk;		/* Which chunk in progress */
	int	   state;		/* State of chunk */
	int	   blockcount;		/* Number of blocks not received yet */
	BlockMap_t blockmap;		/* Which blocks have been received */
	struct {
		char	data[MAXBLOCKSIZE];
	} blocks[MAXCHUNKSIZE];		/* Actual block data */
} ChunkBuffer_t;
#define CHUNK_EMPTY	0
#define CHUNK_FILLING	1
#define CHUNK_FULL	2
#define CHUNK_DUBIOUS	3

Chunk_t		*Chunks;		/* Chunk descriptors */
ChunkBuffer_t   *ChunkBuffer;		/* The cache */
int		*ChunkRequestList;	/* Randomized chunk request order */
int		TotalChunkCount;	/* Total number of chunks in file */
int		ChunksReceived;		/* Chunks received (for reporting) */
int		ChunksDecompressed;	/* Chunks decomp'ed (for reporting) */
#ifdef PASSIVE
int		ChunksEnroute;		/* Total useful chunks enroute */
#endif
#ifdef CONDVARS_WORK
static pthread_mutex_t	chunkbuf_mutex;
static pthread_cond_t	chunkbuf_cond;
static pthread_cond_t	heartbeat_cond;
#endif
static pthread_mutex_t	heartbeat_mutex;
static pthread_t child_pid, heartbeat_pid;
static long child_error;

#ifdef TRACE_EVENTS
int blocksrecv, goodblocksrecv;
#endif

/* XXX imageunzip.c */
extern long long totaledata, totalrdata, totalddata;
extern unsigned long decompblocks, writeridles;

#ifdef STATS
ClientStats_t	Stats;
#define DOSTAT(x)	(Stats.u.v1.x)
#else
#define DOSTAT(x)
#endif

char *usagestr = 
 "usage: frisbee [-drzbnqN] [-s #] <-m ipaddr> <-p #> <output filename>\n"
 "  or\n"
 "usage: frisbee [-drzbnqN] [-s #] <-S server> <-F fileid> <output filename>\n"
 "\n"
 " -d              Turn on debugging. Multiple -d options increase output.\n"
 " -r              Randomly delay first request by up to one second.\n"
 " -z              Zero fill unused block ranges (default is to seek past).\n"
 " -b              Use broadcast instead of multicast\n"
 " -n              Do not use extra threads in diskwriter\n"
 " -q              Quiet mode (no dots)\n"
 " -N              Do not decompress the received data, just write to output.\n"
 " -D DOS-ptype    Set the DOS partition type in slice mode.\n"
 " -S server-IP    Specify the IP address of the server to use.\n"
 " -p portnum      Specify a port number.\n"
 " -m mcastaddr    Specify a multicast address in dotted notation.\n"
 " -i mcastif      Specify a multicast interface in dotted notation.\n"
 " -s slice        Output to DOS slice (DOS numbering 1-4)\n"
 "                 NOTE: Must specify a raw disk device for output filename.\n"
 " -T seconds      Server inactivity timeout (seconds, default is zero for none).\n"
 " -F file-ID      Specify the ID of the file (image) to download.\n"
 "                 Here -S specifies the 'master' server which will\n"
 "                 return unicast/multicast info to use for image download.\n"
 " -Q file-ID      Ask the server (-S) about the indicated file (image).\n"
 "                 Tells whether the image is accessible by this node/user.\n"
 " -B seconds      Time to wait between queries if an image is busy (-F).\n"
 " -X method       Transfer method for -F, one of: ucast, mcast or bcast.\n"
 " -K seconds      Send a multicast keep alive after a period of inactivity.\n"
 "\n"
 "security options:\n"
 " -u UUID         Expect all chunks to have this unique ID\n"
 " -c sigkeyfile   File containing pubkey used for signing image\n"
 " -e enckeyfile   File containing secret used for encrypting image\n"
 "\n"
 "tuning options (if you don't know what they are, don't use em!):\n"
 " -k KB           Max KB of memory for a socket buffer (default is 1024).\n"
 " -C MB           Max MB of memory to use for network chunk buffering.\n"
 " -W MB           Max MB of memory to use for disk write buffering.\n"
 " -M MB           Max MB of memory to use for buffering\n"
 "                 (Half used for network, half for disk).\n"
 " -I ms           The time interval (millisec) between re-requests of a chunk.\n"
 " -R #            The max number of chunks we will request ahead.\n"
 " -O              Make chunk requests in increasing order (default is random order).\n"
 " -f              Force use of direct IO (O_DIRECT) to reduce system cache effects.\n"
 "\n";

void
usage()
{
	fprintf(stderr, "%s", usagestr);
	exit(1);
}

void (*DiskStatusCallback)();
static void
WriterStatusCallback(int isbusy)
{
#ifdef TRACE_EVENTS
	uint32_t hi, lo;

	if (zero) {
		hi = (totaledata >> 32);
		lo = totaledata;
	} else {
		hi = (totalrdata >> 32);
		lo = totalrdata;
	}
	CLEVENT((isbusy != 2) ? 1 : 3, EV_CLIWRSTATUS, isbusy, hi, lo, 0);
#endif
}

int
main(int argc, char **argv)
{
	int	ch, mem;
	char   *filename = NULL;
	int	dostype = -1;
	int	slice = 0;
	char	*sig_keyfile = 0, *enc_keyfile = 0, *uuidstr = 0;
	int	islocalproxy = 0;

	while ((ch = getopt(argc, argv, "dqhp:m:s:i:tbznU:r:E:D:C:W:S:T:M:R:I:ONc:e:u:K:B:F:Q:P:X:fk:H:")) != -1)
		switch(ch) {
		case 'd':
			debug++;
			break;
			
		case 'q':
			quiet++;
			break;

		case 'b':
			broadcast++;
			break;
			
		case 'p':
			portnum = atoi(optarg);
			break;
			
		case 'm':
			inet_aton(optarg, &mcastaddr);
			break;

		case 'n':
			nothreads++;
			break;

		case 'i':
			inet_aton(optarg, &mcastif);
			break;

		case 'r':
			startdelay = atoi(optarg);
			break;

		case 's':
			slice = atoi(optarg);
			break;

		case 'S':
			if (!GetIP(optarg, &serverip)) {
				fprintf(stderr, "Invalid server name '%s'\n",
					optarg);
				exit(1);
			}
			break;
		case 'T':
			servertimo = atoi(optarg);
			break;
#ifdef MASTER_SERVER
		case 'B':
			busywait = atoi(optarg);
			break;
		case 'F':
			imageid = optarg;
			break;
		case 'Q':
			imageid = optarg;
			askonly = 1;
			break;
		case 'P':
			proxyfor = optarg;
			break;
		case 'X':
		{
			char *ostr, *str, *cp;
			int nm = 0;

			str = ostr = strdup(optarg);
			while ((cp = strsep(&str, ",")) != NULL) {
				if (strcmp(cp, "ucast") == 0)
					nm |= MS_METHOD_UNICAST;
				else if (strcmp(cp, "mcast") == 0)
					nm |= MS_METHOD_MULTICAST;
				else if (strcmp(cp, "bcast") == 0)
					nm |= MS_METHOD_BROADCAST;
				else if (strcmp(cp, "any") == 0)
					nm = MS_METHOD_ANY;
			}
			free(ostr);
			if (nm == 0) {
				fprintf(stderr,
					"-X should specify one or more of: "
					"'ucast', 'mcast', 'bcast', 'any'\n");
				exit(1);
			}
			xfermethods = nm;
			break;
		}
#endif

		case 't':
			tracing++;
			break;

		case 'U':
			strncpy(traceprefix, optarg, sizeof(traceprefix)-1);
			break;

		case 'z':
			zero++;
			break;

		case 'D':
			dostype = (int)strtoul(optarg, NULL, 0);
			break;

		case 'k':
			mem = atoi(optarg);
			if (mem <= 0 || (mem * 1024) > MAXSOCKBUFSIZE)
				sockbufsize = MAXSOCKBUFSIZE;
			else
				sockbufsize = mem * 1024;
			break;

		case 'C':
			mem = atoi(optarg);
			if (mem < 0)
				mem = 1;
			else if (mem > MAXCHUNKBUFS)
				mem = MAXCHUNKBUFS;
			maxchunkbufs = mem;
			break;

		case 'W':
			mem = atoi(optarg);
			if (mem < 0)
				mem = 1;
			else if (mem > MAXWRITEBUFMEM)
				mem = MAXWRITEBUFMEM;
			maxwritebufmem = mem;
			break;

		case 'M':
			mem = atoi(optarg);
			if (mem < 2)
				mem = 2;
			else if (mem > MAXMEMUSE)
				mem = MAXMEMUSE;
			maxmem = mem;
			break;

		case 'R':
			maxreadahead = atoi(optarg);
			if (maxinprogress < maxreadahead * 4) {
				maxinprogress = maxreadahead * 4;
				if (maxchunkbufs > 0 &&
				    maxinprogress > maxchunkbufs)
					maxinprogress = maxchunkbufs;
			}
			break;

		case 'I':
			redodelay = atoi(optarg) * 1000;
			if (redodelay < 0)
				redodelay = 0;
			break;

		case 'O':
			randomize = 0;
			break;

		case 'N':
			nodecompress = 1;
			break;

		case 'c':
			sig_keyfile = optarg;
			break;

		case 'e':
			enc_keyfile = optarg;
			break;

		case 'u':
			uuidstr = optarg;
			break;

		case 'K':
			keepalive = atoi(optarg);
			if (keepalive < 0)
				keepalive = 0;
			break;

		case 'f':
			forcedirectio++;
			break;

		case 'H':
			/*
			 * Zero means enable heartbeats but let the server
			 * tell us the parameters.
			 * Non-zero is for compatability and we default to
			 * summaries at the specified interval.
			 */
			heartbeat = 1;
			hb_interval = atoi(optarg);
			/* XXX cannot sleep more that 4295 sec due to fsleep */
			if (hb_interval > 4295)
				hb_interval = 4295;
			if (hb_interval > 0)
				hb_what = PKTPROGRESS_SUMMARY;
			break;

		case 'h':
		case '?':
		default:
			usage();
		}
	argc -= optind;
	argv += optind;

	if (!askonly) {
		if (argc != 1)
			usage();
		filename = argv[0];
	}

	if (!((imageid != NULL && serverip.s_addr != 0) ||
	      (mcastaddr.s_addr != 0 && portnum != 0)))
		usage();

	ClientLogInit();
#ifdef MASTER_SERVER
	if (imageid) {
		struct in_addr pif;
		GetReply reply;
		int method = askonly ? MS_METHOD_ANY : xfermethods;
		int host = 0;
		int timo;

		/*
		 * XXX we could have a distinct timeout for the master
		 * server, but we just use the server response timeout
		 * instead since the master server and the image server
		 * are probably the same. This does mean that by default
		 * we will wait forever for a response here, but hey,
		 * what else do we have to do?
		 */
		timo = servertimo;

		if (proxyfor) {
			if (!GetIP(proxyfor, &proxyip))
				FrisFatal("Could not resolve host '%s'\n",
					  proxyfor);
			host = ntohl(proxyip.s_addr);

			/*
			 * XXX make a note if localhost is the server.
			 * This is a special case of proxying, see
			 * proxyfor comment below.
			 */
			if (ntohl(serverip.s_addr) == INADDR_LOOPBACK)
				islocalproxy = 1;
		}
		while (1) {
			if (!ClientNetFindServer(ntohl(serverip.s_addr),
						 portnum, host, imageid,
						 method, askonly, timo,
						 &reply, &pif))
				FrisFatal("Could not get download info for '%s'",
					  imageid);

			if (askonly) {
				PrintGetInfo(imageid, &reply, 1);
				exit(0);
			}
			if (reply.error) {
				if (busywait == 0 ||
				    reply.error != MS_ERROR_TRYAGAIN)
					FrisFatal("%s: server returned error: %s",
						  imageid,
						  GetMSError(reply.error));
				FrisLog("%s: image busy, waiting %d seconds...",
				    imageid, busywait);
				sleep(busywait);
				continue;
			}

			serverip.s_addr = htonl(reply.servaddr);
			mcastaddr.s_addr = htonl(reply.addr);
			portnum = reply.port;
			broadcast = (reply.method == MS_METHOD_BROADCAST);

			/*
			 * Unless the user explicitly specified the interface
			 * to use, default to the one on which we got a
			 * response from the server.
			 */
			if (mcastif.s_addr == 0)
				mcastif = pif;

			if (serverip.s_addr == mcastaddr.s_addr)
				FrisLog("%s: address: %s:%d%s",
					imageid, inet_ntoa(mcastaddr), portnum,
					broadcast ? " (broadcast)" : "");
			else {
				char serverstr[sizeof("XXX.XXX.XXX.XXX")+1];

				strncpy(serverstr, inet_ntoa(serverip),
					sizeof serverstr);
				FrisLog("%s: address: %s:%d%s, server: %s",
					imageid, inet_ntoa(mcastaddr), portnum,
					broadcast ? " (broadcast)" : "",
					serverstr);
			}
			break;
		}
	}

	/*
	 * XXX if proxying for another node from localhost, assume that
	 * we are only interested in starting up the frisbeed and don't
	 * care about the image ourselves. So, our work is done!
	 *
	 * This is a special case for implementing backward compatibility
	 * on Emulab. We should instead have a client timeout option that
	 * we can set to really small value to handle immediate termination.
	 */
	if (proxyfor && islocalproxy) {
		FrisLog("frisbeed server started on behalf of %s", proxyfor);
		exit(0);
	}
#endif
	ClientNetInit(portnum);

	redodelay = sleeptime(redodelay, "request retry delay", 0);
	idledelay = sleeptime(idledelay, "writer idle delay", 0);

	/*
	 * Set initial memory limits.  These may be adjusted when we
	 * find out how big the image is.
	 */
	if (maxmem != 0) {
		/* XXX divide it up 50/50 */
		maxchunkbufs = (int)((unsigned long long)maxmem/2 * 1024*1024
				     / sizeof(ChunkBuffer_t));
		maxwritebufmem = maxmem/2;
	}

	/*
	 * Initialize keys for authentication/encryption.
	 */
	ImageUnzipInitKeys(uuidstr, sig_keyfile, enc_keyfile);

	/*
	 * Pass in assorted parameters and fire off the disk writer thread.
	 * The writer thread synchronizes only with us (the decompresser).
	 */
	ImageUnzipInit(filename, slice, debug, zero, nothreads, dostype,
		       quiet ? 0 : 3,
		       (unsigned long long)maxwritebufmem*1024*1024,
		       forcedirectio);

	if (tracing) {
		ClientTraceInit(traceprefix);
		TraceStart(tracing);
		if (!nothreads)
			DiskStatusCallback = WriterStatusCallback;
	}

	if (servertimo)
		FrisLog("Quit if no messages from server after %d seconds",
			servertimo);

	/*
	 * Set the MC keepalive counter (but only if we are multicasting!)
	 */
	if (broadcast || (ntohl(mcastaddr.s_addr) >> 28) != 14)
		keepalive = 0;
	if (keepalive)
		FrisLog("Enabling MC keepalive at %d seconds", keepalive);

	PlayFrisbee();

	if (tracing) {
		TraceStop();
		TraceDump(0, tracing);
	}

	ImageUnzipQuit();

	exit(0);
}

/*
 * The network receive (and send) thread. This thread takes in packets from the
 * server.  It is responsible for driving the protocol, making block requests
 * as needed.
 *
 * XXX record time for entire download so that we can figure average download.
 */
void *
ClientRecvThread(void *arg)
{
	Packet_t	packet, *p = &packet;
	int		IdleCounter, BackOff, KACounter, STCounter;
	static int	gotone;

	if (debug)
		FrisLog("Receive pthread starting up ...");

	/*
	 * Use this to control the rate at which we request blocks.
	 * The IdleCounter is how many ticks we let pass without a
	 * useful block, before we make another request. We want that to
	 * be short, but not too short; we do not want to pummel the
	 * server.  We initialize this to one so that we will issue an
	 * immediate first request to get the ball rolling.
	 */
	IdleCounter = 1;

	/*
	 * KACounter is how often we send a multicast "keep alive",
	 * aka a V2 IGMP report message. The keep alive mechanism is a
	 * hack and indicates a compatibility issue between the frisbee
	 * server, frisbee client, and switch IGMP implementations.
	 * As with the idle counter, we initialize it to one so that an
	 * immediate message will be sent in order to get things moving
	 * quickly.
	 */
	KACounter = keepalive ? 1 : 0;

	/*
	 * This is another throttling mechanism; avoid making repeated
	 * requests to a server that is not running. That is, if the server
	 * is not responding, slowly back off our request rate (to about
	 * one a second) until the server starts responding.  This will
	 * prevent a large group of clients from pummeling the server
	 * machine, when there is no server running to respond (say, if the
	 * server process died).
	 */
	BackOff = 0;

	/*
	 * Server timeout counter. If we do not see any message from the
	 * server for this many ticks, we assume the server has died and quit.
	 */
	STCounter = servertimo * TIMEOUT_HZ;

	while (1) {
#ifdef TRACE_EVENTS
		static int needstamp = 1;
		struct timeval pstamp;
		if (needstamp) {
			gettimeofday(&pstamp, 0);
			needstamp = 0;
		}
#endif

		/*
		 * If we go too long without getting a block, we want
		 * to make another chunk request.
		 *
		 * XXX fixme: should probably be if it hasn't received
		 * a block that it is able to make use of.  But that has
		 * problems in that any new request we make will wind up
		 * at the end of the server work list, and we might not
		 * see that block for longer than our timeout period,
		 * leading us to issue another request, etc.
		 */
		if (PacketReceive(p) != 0) {
			pthread_testcancel();

			/*
			 * First see if we should exit
			 */
			if (servertimo && --STCounter <= 0) {
				FrisLog("\n*** No messages from server "
					"after %d seconds, exiting",
					servertimo);
				child_error = ETIMEDOUT;
#ifdef CONDVARS_WORK
				pthread_cond_signal(&chunkbuf_cond);
#endif
				pthread_exit((void *)child_error);
			}

			/*
			 * See if we should send a keep alive
			 */
			if (KACounter == 1) {
				/* If for some reason it fails, stop trying */
				if (debug)
					FrisLog("sending keepalive...");
				if (NetMCKeepAlive()) {
					FrisLog("Multicast keepalive failed, "
						"disabling keepalive");
					keepalive = 0;
				}
				KACounter = keepalive * TIMEOUT_HZ;
			} else if (KACounter > 1)
				KACounter--;

			if (--IdleCounter <= 0) {
				if (gotone)
					DOSTAT(recvidles++);
				CLEVENT(2, EV_CLIRTIMO,
					pstamp.tv_sec, pstamp.tv_usec, 0, 0);
#ifdef TRACE_EVENTS
				needstamp = 1;
#endif
#ifdef PASSIVE
				/*
				 * If we timed-out with a en route counter
				 * that has been keeping us from making our
				 * own requests, then we are out of synch.
				 * Just clear the enroute counters.
				 */
				if (ChunksEnroute >= maxreadahead) {
					int i;
					for (i = 0; i < TotalChunkCount; i++)
						Chunks[i].enroute = 0;
					ChunksEnroute = 0;
					CLEVENT(1, EV_CLIENCLEAR, ChunksEnroute, 0, 0, 0);
				}
#endif
				RequestChunk(1);
				IdleCounter = idletimer;

				if (BackOff++) {
					IdleCounter += BackOff;
					if (BackOff > TIMEOUT_HZ)
						BackOff = TIMEOUT_HZ;
				}
			}
			continue;
		}
		pthread_testcancel();
		if (servertimo)
			STCounter = servertimo * TIMEOUT_HZ;
		if (keepalive)
			KACounter = keepalive * TIMEOUT_HZ;
		gotone = 1;

		if (! PacketValid(p, TotalChunkCount)) {
			FrisLog("received bad packet %d/%d, ignored",
				p->hdr.type, p->hdr.subtype);
			continue;
		}

		switch (p->hdr.subtype) {
		case PKTSUBTYPE_BLOCK:
			/*
			 * Ensure blocks comes from where we expect.
			 * The validity of hdr.srcip has already been checked.
			 */
			if (serverip.s_addr != 0 &&
			    serverip.s_addr != p->hdr.srcip) {
				struct in_addr tmp = { p->hdr.srcip };
				if (debug)
					FrisLog("BLOCK msg from non-server %s",
						inet_ntoa(tmp));
				break;
			}

			CLEVENT(BackOff ? 1 : (p->msg.block.block==0 ? 3 : 4),
				EV_CLIGOTPKT, pstamp.tv_sec, pstamp.tv_usec,
				goodblocksrecv, blocksrecv);
#ifdef TRACE_EVENTS
			needstamp = 1;
#endif
			BackOff = 0;
			if (GotBlock(p)) {
				/*
				 * Anytime we receive a packet thats needed,
				 * reset the idle counter.  This will prevent
				 * us from sending too many requests.
				 */
				IdleCounter = idletimer;
			}
			/*
			 * We may have missed the request for this chunk/block
			 * so treat the arrival of a block as an indication
			 * that someone requested it.
			 *
			 * XXX note the hacky final argument which tells
			 * RequestStamp that we actually received the block
			 * and didn't just see a request.
			 */
			(void) RequestStamp(p->msg.block.chunk,
					    p->msg.block.block, 1, (void *)1);
#ifdef PASSIVE
			if (Chunks[p->msg.block.chunk].enroute) {
				Chunks[p->msg.block.chunk].enroute = 0;
				ChunksEnroute--;
				CLEVENT(1, EV_CLIENROUTE, 0, ChunksEnroute, 0, 0);
			}
#endif
			break;

		case PKTSUBTYPE_REQUEST:
			CLEVENT(3, EV_CLIREQMSG,
				p->hdr.srcip, p->msg.request.chunk,
				p->msg.request.block, p->msg.request.count);


			if (RequestStamp(p->msg.request.chunk,
					 p->msg.request.block,
					 p->msg.request.count, 0)) {
#ifndef OLD_SCHOOL
				/*
				 * XXX experimental: Also reset timer if
				 * someone else requests a block we need.
				 * This is indicated by the Chunk stamp
				 * getting updated.
				 */
				IdleCounter = idletimer;
#else
				;
#endif
#ifdef PASSIVE
				/*
				 * XXX experimental: If there is something
				 * in the request we need, mark the chunk
				 * as en route. If there are enough en route
				 * packets when it comes time for us to make
				 * a non-timeout driven request, then we
				 * hold off making the request.
				 */
				if (!Chunks[p->msg.request.chunk].enroute) {
					Chunks[p->msg.request.chunk].enroute = 1;
					ChunksEnroute++;
					CLEVENT(1, EV_CLIENROUTE, 1, ChunksEnroute, 0, 0);
				}
#endif
			}
			break;

		case PKTSUBTYPE_PREQUEST:
			CLEVENT(3, EV_CLIPREQMSG,
				p->hdr.srcip, p->msg.request.chunk, 0, 0);

			/*
			 * XXX could/should update the idlecounter but
			 * BlockMapApply doesn't return what we need
			 * to easily determine this.
			 */
			(void) BlockMapApply(&p->msg.prequest.blockmap,
					     p->msg.prequest.chunk,
					     RequestStamp, 0);
			break;


		case PKTSUBTYPE_PROGRESS:
			/*
			 * Only process REQUESTs that come from our server
			 * and targeted to our clientid or to all clients.
			 */
			if (p->hdr.type == PKTTYPE_REQUEST) {
				if (serverip.s_addr != 0 &&
				    serverip.s_addr != p->hdr.srcip) {
					struct in_addr tmp = { p->hdr.srcip };
					if (debug)
						FrisLog("PROGRESS request from non-server %s",
							inet_ntoa(tmp));
				}
				else if (p->msg.progress.hdr.clientid == 0 ||
					 p->msg.progress.hdr.clientid == clientid)
					HandleProgress(p);
			}
			break;

		case PKTSUBTYPE_JOIN:
		case PKTSUBTYPE_JOIN2:
		case PKTSUBTYPE_LEAVE:
			/* Ignore these. They are from other clients. */
			CLEVENT(3, EV_OCLIMSG,
				p->hdr.srcip, p->hdr.subtype, 0, 0);
			break;
		}
	}
}

#ifndef linux
/*
 * XXX mighty hack!
 *
 * Don't know if this is a BSD linuxthread thing or just a pthread semantic,
 * but if the child thread calls exit(-1) from fatal, the frisbee process
 * exits, but with a code of zero; i.e., the child exit code is lost.
 * Granted, a multi-threaded program should not be calling exit willy-nilly,
 * but it does, so we deal with it as follows.
 *
 * Since the child should never exit during normal operation (we always
 * kill it), if it does exit we know there is a problem.  So, we catch
 * all exits and if it is the child, we set a flag.  The parent thread
 * will see this and exit with an error.
 *
 * Since I don't understand this fully, I am making it a FreeBSD-only
 * thing for now.
 */
void
myexit(void)
{
	if (pthread_self() == child_pid) {
		child_error = -2;
		pthread_exit((void *)child_error);
	}
}
#endif

/*
 * The heart of the game.
 * Fire off the network thread and wait for chunks to start appears.
 * Synchronizes with the network thread via the chunk cache.
 */
static void
ChunkerStartup(void)
{
	void		*ignored;
	int		chunkcount = TotalChunkCount;
	int		i, wasidle = 0;
	static int	gotone;
#ifdef TRACE_EVENTS
	uint32_t	idleus = 0;
#endif

	/*
	 * Allocate the chunk descriptors, request list and cache buffers.
	 */
	Chunks = calloc(chunkcount, sizeof(*Chunks));
	if (Chunks == NULL)
		FrisFatal("Chunks: No more memory");

	ChunkRequestList = calloc(chunkcount, sizeof(*ChunkRequestList));
	if (ChunkRequestList == NULL)
		FrisFatal("ChunkRequestList: No more memory");

	ChunkBuffer = malloc(maxchunkbufs * sizeof(ChunkBuffer_t));
	if (ChunkBuffer == NULL)
		FrisFatal("ChunkBuffer: No more memory");
#ifdef CONDVARS_WORK
	pthread_mutex_init(&chunkbuf_mutex, 0);
	pthread_cond_init(&chunkbuf_cond, 0);
#endif

	/*
	 * Set all the buffers to "free"
	 */
	for (i = 0; i < maxchunkbufs; i++)
		ChunkBuffer[i].state = CHUNK_EMPTY;

	for (i = 0; i < TotalChunkCount; i++)
		ChunkRequestList[i] = i;
	
	/*
	 * We randomize the block selection so that multiple clients
	 * do not end up getting stalled by each other. That is, if
	 * all the clients were requesting blocks in order, then all
	 * the clients would end up waiting until the last client was
	 * done (since the server processes client requests in FIFO
	 * order).
	 */
	if (randomize) {
		for (i = 0; i < 50 * TotalChunkCount; i++) {
			int c1 = random() % TotalChunkCount;
			int c2 = random() % TotalChunkCount;
			int t1 = ChunkRequestList[c1];
			int t2 = ChunkRequestList[c2];

			ChunkRequestList[c2] = t1;
			ChunkRequestList[c1] = t2;
		}
	}

#ifndef linux
	atexit(myexit);
#endif

	/*
	 * Start up a heartbeat thread to make periodic progress reports
	 * to our server.
	 */
	if (heartbeat) {
		void *ClientReportThread(void *);

		pthread_mutex_init(&heartbeat_mutex, 0);
#ifdef CONDVARS_WORK
		pthread_cond_init(&heartbeat_cond, 0);
#endif
		if (pthread_create(&heartbeat_pid, NULL,
				   ClientReportThread, (void *)0)) {
			FrisFatal("Failed to create heartbeat thread!");
		}
	}

	if (pthread_create(&child_pid, NULL,
			   ClientRecvThread, (void *)0)) {
		FrisFatal("Failed to create network receive thread!");
	}

	/*
	 * Loop until all chunks have been received and written to disk.
	 */
	while (chunkcount) {
		int chunkbytes;

#ifdef CONDVARS_WORK
		pthread_mutex_lock(&chunkbuf_mutex);
#endif
		/*
		 * Search the chunk cache for a chunk that is ready to write.
		 */
		for (i = 0; i < maxchunkbufs; i++)
			if (ChunkBuffer[i].state == CHUNK_FULL)
				break;

		/*
		 * If nothing to do, then get out of the way for a while.
		 */
		if (i == maxchunkbufs) {
			/*
			 * Might be nothing to do because network receiver
			 * thread died.  That indicates a problem.
			 *
			 * XXX why _exit and not exit?  Because exit loses
			 * the error code again.  This is clearly bogus and
			 * needs to be rewritten!
			 */
			if (child_error) {
#ifdef CONDVARS_WORK
				pthread_mutex_unlock(&chunkbuf_mutex);
#endif
				pthread_join(child_pid, &ignored);
				if (heartbeat) {
					pthread_cancel(heartbeat_pid);
					pthread_join(heartbeat_pid, &ignored);
				}
				_exit(child_error);
			}
			if (!wasidle) {
				CLEVENT(1, EV_CLIDCIDLE, 0, 0, 0, 0);
				if (debug > 1)
					FrisLog("No chunks ready to write!");
			}
			if (gotone)
				DOSTAT(nochunksready++);
#ifdef CONDVARS_WORK
			{
#ifdef TRACE_EVENTS
				struct timeval _istamp, _eistamp;
				gettimeofday(&_istamp, 0);
#endif
				pthread_cond_wait(&chunkbuf_cond,
						  &chunkbuf_mutex);
				pthread_mutex_unlock(&chunkbuf_mutex);
#ifdef TRACE_EVENTS
				gettimeofday(&_eistamp, 0);
				timersub(&_eistamp, &_istamp, &_eistamp);
				/* XXX yes, this can wrap */
				idleus += (uint32_t)
					((_eistamp.tv_sec * 1000000) +
					 _eistamp.tv_usec);
#endif
			}
#else
			fsleep(idledelay);
#ifdef TRACE_EVENTS
			/* XXX yes, this can wrap */
			idleus += idledelay;
#endif
#endif
			wasidle++;
			continue;
		}
#ifdef CONDVARS_WORK
		pthread_mutex_unlock(&chunkbuf_mutex);
#endif
		gotone = 1;

		/*
		 * We have a completed chunk. Write it to disk.
		 */
		chunkbytes = ChunkBytes(ChunkBuffer[i].thischunk);
		if (debug > 1)
			FrisLog("Writing chunk %d (buffer %d), size %d, after %d idle intervals",
				ChunkBuffer[i].thischunk, i, chunkbytes,
				wasidle);

		CLEVENT(1, EV_CLIDCSTART,
			ChunkBuffer[i].thischunk, idleus,
			decompblocks, writeridles);
		wasidle = 0;
#ifdef TRACE_EVENTS
		idleus = 0;
#endif

		if (nodecompress) {
			if (ImageWriteChunk(ChunkBuffer[i].thischunk,
					    ChunkBuffer[i].blocks[0].data,
					    chunkbytes))
				FrisPfatal("ImageWriteChunk failed");
		} else {
			if (ImageUnzipChunk(ChunkBuffer[i].blocks[0].data,
					    chunkbytes))
				FrisPfatal("ImageUnzipChunk failed");
		}

		CLEVENT(1, EV_CLIDCDONE, ChunkBuffer[i].thischunk,
			chunkbytes, chunkcount, 0);
		CLEVENT(2, EV_CLIDCSTAT, (totalddata >> 32), totalddata,
			decompblocks, writeridles);

		/*
		 * Okay, free the slot up for another chunk.
		 */
		ChunkBuffer[i].state = CHUNK_EMPTY;
		ChunksDecompressed++;
		chunkcount--;
	}
	/*
	 * Kill the child and wait for it before returning. We do not
	 * want the child absorbing any more packets, cause that would
	 * mess up the termination handshake with the server. 
	 */
	pthread_cancel(child_pid);
	pthread_join(child_pid, &ignored);

	/*
	 * Make sure any asynchronous writes are done
	 * and collect stats from the unzipper.
	 */
	if (ImageUnzipFlush())
		FrisPfatal("ImageUnzipFlush failed");

	/*
	 * Kill the heartbeat thread now that everything is done
	 */
	if (heartbeat) {
		pthread_cancel(heartbeat_pid);
		pthread_join(heartbeat_pid, &ignored);
	}

	free(ChunkBuffer);
	free(ChunkRequestList);
	free(Chunks);
}

/*
 * Note that someone has made a request from the server right now.
 * This is either a request by us or one we snooped.
 *
 * We use the time stamp to determine when we should repeat a request to
 * the server.  If we update the stamp here, we are further delaying
 * a re-request.  The general strategy is: if a chunk request contains
 * any blocks that we will be able to use, we update the stamp to delay
 * what would otherwise be a redundant request.
 *
 * Returns one if the chunk was stamped.
 */
static int
RequestStamp(int chunk, int block, int count, void *arg)
{
	int stampme = 0;
	int gotblock = (arg != 0) ? 1 : 0;

	/*
	 * If not doing delays, don't bother with the stamp
	 */
	if (redodelay == 0)
		return 0;

	/*
	 * Chunk has been fully processed, no need to stamp.
	 */
	if (Chunks[chunk].done)
		return 0;

	/*
	 * Either we have not seen this chunk or we are currently processing it.
	 *
	 * Common case of a complete chunk request, always stamp as there will
	 * be some data in it we need.
	 */
	if (block == 0 && count == ChunkSize(chunk))
		stampme = 1;
	/*
	 * Else, request is for a partial chunk. If we are not currently
	 * processing this chunk, then the chunk data will be of use to
	 * us so we update the stamp.
	 */
	else if (!Chunks[chunk].seen)
		stampme = 1;
	/*
	 * Otherwise, this is a partial chunk request for which we have
	 * already received some blocks.  We need to determine if the
	 * request contains any blocks that we need to complete our copy
	 * of the chunk.  If so, we conservatively update the stamp as it
	 * implies there is at least some chunk data coming that we will
	 * be able to use.  If the request contains only blocks that we
	 * already have, then the returned data will be of no use to us
	 * for completing our copy and we will still have to make a
	 * further request (i.e., we don't stamp).
	 */
	else {
		int i;

		for (i = 0; i < maxchunkbufs; i++)
			if (ChunkBuffer[i].thischunk == chunk &&
			    (ChunkBuffer[i].state == CHUNK_FILLING ||
			     ChunkBuffer[i].state == CHUNK_DUBIOUS))
				break;
		if (i < maxchunkbufs &&
		    BlockMapIsAlloc(&ChunkBuffer[i].blockmap, block, count)
		    != count) {
			stampme = 1;
			/*
			 * Any block that was formerly of dubious value now
			 * has real value since someone has requested more.
			 *
			 * XXX unless we were called because we received the
			 * block rather than just seeing a request. In that
			 * case, we might have just marked the chunk as
			 * dubious in GotBlock so we should not undo it!
			 */
			if (!gotblock &&
			    ChunkBuffer[i].state == CHUNK_DUBIOUS) {
				CLEVENT(1, EV_CLIDUBPROMO, chunk, block, 0, 0);
				ChunkBuffer[i].state = CHUNK_FILLING;
			}
		}
	}

	if (stampme) {
		struct timeval tv;

		gettimeofday(&tv, 0);
		Chunks[chunk].lastreq =
			(unsigned long long)tv.tv_sec * 1000000 + tv.tv_usec;
		CLEVENT(5, EV_CLISTAMP, chunk, tv.tv_sec, tv.tv_usec, 0);
	}

	return stampme;
}

/*
 * Returns 1 if we have not made (or seen) a request for the given chunk
 * "for awhile", 0 otherwise.
 */
static int
RequestRedoTime(int chunk, unsigned long long curtime)
{
	if (Chunks[chunk].lastreq == 0 || redodelay == 0 ||
	    (int)(curtime - Chunks[chunk].lastreq) >= redodelay) {
		CLEVENT(5, EV_CLIREDO, chunk,
			Chunks[chunk].lastreq/1000000,
			Chunks[chunk].lastreq%1000000, 0);
		return 1;
	}
	return 0;
}

/*
 * Receive a single data block. If the block is for a chunk in progress, then
 * insert the data and check for a completed chunk. It will be up to the main
 * thread to process that chunk.
 *
 * If the block is the first of some chunk, then try to allocate a new chunk.
 * If the chunk buffer is full, then drop the block. If this happens, it
 * indicates the chunk buffer is not big enough, and should be increased.
 */
static int
GotBlock(Packet_t *p)
{
	int	chunk = p->msg.block.chunk;
	int	block = p->msg.block.block;
	int	i, state, free = -1, dubious = -1;
	static int lastnoroomchunk = -1, lastnoroomblocks, inprogress;
	int	nfull = 0, nfill = 0; 

#ifdef TRACE_EVENTS
	blocksrecv++;
#endif
#ifndef OLD_SCHOOL
	/*
	 * If we have already processed this chunk, bail now.
	 */
	if (Chunks[chunk].done) {
		assert(Chunks[chunk].seen);
		CLEVENT((block==0)? 3 : 4, EV_CLIDUPCHUNK, chunk, block, 0, 0);
		DOSTAT(dupchunk++);
		if (debug > 2)
			FrisLog("Duplicate chunk %d data ignored!", chunk);
		return 0;
	}
#endif

	/*
	 * Otherwise, search the chunk buffer for a match (or a free one).
	 */
	for (i = 0; i < maxchunkbufs; i++) {
		switch (ChunkBuffer[i].state) {
		case CHUNK_FULL:
			nfull++;
			continue;
		case CHUNK_EMPTY:
			if (free == -1)
				free = i;
			continue;
		case CHUNK_FILLING:
			nfill++;
			if (ChunkBuffer[i].thischunk == chunk)
				break;
			continue;
		case CHUNK_DUBIOUS:
			nfill++;
			if (ChunkBuffer[i].thischunk == chunk)
				break;
			if (dubious == -1)
				dubious = i;
			continue;
		default:
			FrisFatal("Unknown state %d for chunk %d",
				  ChunkBuffer[i].state, chunk);
		}
		break;
	}
	if (i == maxchunkbufs) {
#ifndef OLD_SCHOOL
		assert(Chunks[chunk].seen == 0);
#endif

		/*
		 * Did not find it. Allocate the free one, or drop the
		 * packet if there is no free chunk.
		 */
		if (free == -1) {
			/*
			 * No free blocks, but we do have a "dubious" block.
			 * If it looks like the start of a new chunk, toss
			 * the dubious block and reuse its buffer.
			 */
			if (dubious != -1 && block == 0) {
				int dchunk = ChunkBuffer[dubious].thischunk;
				assert(Chunks[dchunk].done == 0);
				assert(Chunks[dchunk].seen == 1);

#ifdef TRACE_EVENTS
				{
				int dblocks = BlockMapIsAlloc(&ChunkBuffer[dubious].blockmap, 0, CHUNKSIZE);
				goodblocksrecv -= dblocks;
				CLEVENT(1, EV_CLIREUSE, chunk, block,
					dblocks, dchunk);
				}
#endif
				Chunks[dchunk].seen = 0;
				Chunks[dchunk].lastreq = 0;
				lastnoroomchunk = -1;
				ChunkBuffer[dubious].state = CHUNK_EMPTY;
				free = dubious;
				inprogress--;
				DOSTAT(partialdrops++);
			} else {
				if (chunk != lastnoroomchunk) {
					CLEVENT(1, EV_CLINOROOM, chunk, block,
						nfull, nfill);
					lastnoroomchunk = chunk;
					lastnoroomblocks = 0;
					if (debug > 1)
						FrisLog("No free buffer for chunk %d!",
							chunk);
				}
				lastnoroomblocks++;
				DOSTAT(nofreechunks++);
				return 0;
			}
		}
		state = CHUNK_FILLING;
		if (chunk == lastnoroomchunk
#ifdef OLD_SCHOOL
		    && !Chunks[chunk].seen
#endif
		) {
#ifndef OLD_SCHOOL
			/*
			 * Here we have missed part of a chunk because of
			 * a lack of buffers.  The part we missed is not
			 * likely to be resent for awhile.  We go ahead and
			 * start collecting the chunk, but mark it as dubious
			 * in case a better offer comes along (i.e., the start
			 * of a new chunk we have not seen).
			 */
			state = CHUNK_DUBIOUS;
#endif
			CLEVENT(1, EV_CLIFOUNDROOM, chunk, block,
				lastnoroomblocks, 0);
		}
		lastnoroomchunk = -1;
		lastnoroomblocks = 0;

#ifdef OLD_SCHOOL
		/*
		 * If we have already processed this chunk, bail now.
		 */
		if (Chunks[chunk].done) {
			assert(Chunks[chunk].seen);
			CLEVENT(3, EV_CLIDUPCHUNK, chunk, block, 0, 0);
			DOSTAT(dupchunk++);
			if (debug > 2)
				FrisLog("Duplicate chunk %d data ignored!",
					chunk);
			return 0;
		}
#endif
		Chunks[chunk].seen = 1;

		if (debug > 1)
			FrisLog("Starting chunk %d (buffer %d)", chunk, free);

		i = free;
		ChunkBuffer[i].state      = state;
		ChunkBuffer[i].thischunk  = chunk;
		ChunkBuffer[i].blockcount = ChunkSize(chunk);
		memset(&ChunkBuffer[i].blockmap, 0,
		       sizeof(ChunkBuffer[i].blockmap));
		inprogress++;
		CLEVENT(1, EV_CLISCHUNK, chunk, block, inprogress,
			goodblocksrecv+1);
	}
	assert(Chunks[chunk].seen);

	/*
	 * Insert the block and update the metainfo. We have to watch for
	 * duplicate blocks in the same chunk since another client may
	 * issue a request for a lost block, and we will see that even if
	 * we do not need it (in the case of broadcast/multicast).
	 */
	if (BlockMapAlloc(&ChunkBuffer[i].blockmap, block)) {
		CLEVENT(3, EV_CLIDUPBLOCK, chunk, block, 0, 0);
		DOSTAT(dupblock++);
		if (debug > 2)
			FrisLog("Duplicate block %d in chunk %d",
				block, chunk);
		return 0;
	}
	ChunkBuffer[i].blockcount--;
	memcpy(ChunkBuffer[i].blocks[block].data,
	       p->msg.block.buf, BlockSize(chunk, block));
#ifdef TRACE_EVENTS
	goodblocksrecv++;

	/*
	 * If we switched chunks before completing the previous, make a note.
	 */
	{
		static int lastchunk = -1, lastblock, lastchunkbuf;

		if (lastchunk != -1 && chunk != lastchunk &&
		    lastchunk == ChunkBuffer[lastchunkbuf].thischunk &&
		    (ChunkBuffer[lastchunkbuf].state == CHUNK_FILLING ||
		     ChunkBuffer[lastchunkbuf].state == CHUNK_DUBIOUS))
			CLEVENT(1, EV_CLILCHUNK, lastchunk, lastblock,
				ChunkBuffer[lastchunkbuf].blockcount, 0);
		lastchunkbuf = i;
		lastchunk = chunk;
		lastblock = block;
		CLEVENT(4, EV_CLIBLOCK, chunk, block,
			ChunkBuffer[i].blockcount, 0);
	}
#endif

	/*
	 * Is the chunk complete? If so, then release it to the main thread.
	 */
	if (ChunkBuffer[i].blockcount == 0) {
		assert(ChunkBuffer[i].thischunk == chunk);

		inprogress--;
		CLEVENT(1, EV_CLIECHUNK, chunk, block, inprogress,
			goodblocksrecv);
		if (debug > 1)
			FrisLog("Releasing chunk %d to main thread", chunk);
#ifdef CONDVARS_WORK
		pthread_mutex_lock(&chunkbuf_mutex);
#endif
		ChunkBuffer[i].state = CHUNK_FULL;
#ifdef CONDVARS_WORK
		pthread_cond_signal(&chunkbuf_cond);
		pthread_mutex_unlock(&chunkbuf_mutex);
#endif

		/*
		 * Mark the chunk as "done."  Technically, it isn't since
		 * we have not yet decompressed or written it.  But I want
		 * to keep all updating of the Chunks array in this thread
		 * so we don't have to lock it.  Note that we cannot recover
		 * from a failed decompress or write right now anyway, so
		 * we are done for better or worse at this point.
		 */
		Chunks[chunk].done = 1;
		ChunksReceived++;

#ifdef PASSIVE
		/*
		 * If we know of enough chunks en route to keep us busy,
		 * don't make a request here. Otherwise, if we were late
		 * to the party, we might make a bunch of requests that
		 * everyone else has already seen. For the greater good,
		 * lets just ride the wave until we don't see any more
		 * good stuff coming in.
		 */
		if (ChunksEnroute >= maxreadahead) {
			CLEVENT(1, EV_CLIPASSIVE, ChunksEnroute, 0, 0, 0);
			return 1;
		}
#endif
		/*
		 * Send off a request for a chunk we do not have yet. This
		 * should be enough to ensure that there is more work to do
		 * by the time the main thread finishes the chunk we just
		 * released.
		 */
		RequestChunk(0);
	}

	return 1;
}

/*
 * Request a chunk/block/range we do not have.
 */
static void
RequestMissing(int chunk, BlockMap_t *map, int count)
{
	Packet_t	packet, *p = &packet;
	int		csize = ChunkSize(chunk);

	if (debug > 1)
		FrisLog("Requesting %d missing blocks of chunk:%d",
			count, chunk);
	
	p->hdr.type       = PKTTYPE_REQUEST;
	p->hdr.subtype    = PKTSUBTYPE_PREQUEST;
	p->hdr.datalen    = sizeof(p->msg.prequest);
	p->msg.prequest.chunk = chunk;
	p->msg.prequest.retries = Chunks[chunk].ours;
	/*
	 * Invert the map of what we have so we request everything we
	 * don't have, but be careful not to request anything beyond the
	 * end of a partial chunk.  Note that we use MAXCHUNKSIZE as the
	 * upper bound size size CHUNKSIZE may be less than that even for
	 * "full-sized" image chunks.
	 */
	BlockMapInvert(map, &p->msg.prequest.blockmap);
	if (csize < MAXCHUNKSIZE)
		BlockMapClear(&p->msg.prequest.blockmap,
			      csize, MAXCHUNKSIZE - csize);
	if (heartbeat) {
		pthread_mutex_lock(&heartbeat_mutex);
		PacketSend(p, 0);
		pthread_mutex_unlock(&heartbeat_mutex);
	} else
		PacketSend(p, 0);
#ifdef STATS
	assert(count == BlockMapIsAlloc(&p->msg.prequest.blockmap, 0, CHUNKSIZE));
	if (count == 0)
		FrisLog("Request 0 blocks from chunk %d", chunk);
	Stats.u.v1.lostblocks += count;
	Stats.u.v1.requests++;
	Stats.u.v1.prequests++;
	if (Chunks[chunk].ours) {
		Stats.u.v1.rerequests++;
		if (count == csize)
			Stats.u.v1.fullrerequests++;
	}
#endif
	CLEVENT(1, EV_CLIPREQ, chunk, count, 0, 0);

	/*
	 * Since stamps are per-chunk and we wouldn't be here
	 * unless we were requesting something we are missing
	 * we can just unconditionally stamp the chunk.
	 */
	RequestStamp(chunk, 0, csize, 0);
	Chunks[chunk].ours = 1;
}

/*
 * Request a chunk/block/range we do not have.
 */
static void
RequestRange(int chunk, int block, int count)
{
	Packet_t	packet, *p = &packet;

	/*
	 * If this is a re-request, use RequestMissing instead so that
	 * the server will know that this is a retry.
	 */
	if (Chunks[chunk].ours) {
		BlockMap_t tmap;

		if (block == 0 && count == ChunkSize(chunk))
			memset(&tmap, 0, sizeof(tmap));
		else {
			memset(&tmap, ~0, sizeof(tmap));
			BlockMapClear(&tmap, block, count);
		}
		RequestMissing(chunk, &tmap, count);
		return;
	}

	if (debug > 1)
		FrisLog("Requesting chunk:%d block:%d count:%d",
			chunk, block, count);
	
	p->hdr.type       = PKTTYPE_REQUEST;
	p->hdr.subtype    = PKTSUBTYPE_REQUEST;
	p->hdr.datalen    = sizeof(p->msg.request);
	p->msg.request.chunk = chunk;
	p->msg.request.block = block;
	p->msg.request.count = count;
	if (heartbeat) {
		pthread_mutex_lock(&heartbeat_mutex);
		PacketSend(p, 0);
		pthread_mutex_unlock(&heartbeat_mutex);
	} else
		PacketSend(p, 0);
	CLEVENT(1, EV_CLIREQ, chunk, block, count, 0);
	DOSTAT(requests++);

	RequestStamp(chunk, block, count, 0);
	Chunks[chunk].ours = 1;
}

static void
RequestChunk(int timedout)
{
	int		   i, j, k;
	int		   emptybufs, fillingbufs;
	unsigned long long stamp = 0;

	CLEVENT(1, EV_CLIREQCHUNK, timedout, 0, 0, 0);

	if (! timedout) {
		struct timeval tv;

		gettimeofday(&tv, 0);
		stamp = (unsigned long long)tv.tv_sec * 1000000 + tv.tv_usec;
	}

	/*
	 * Look for unfinished chunks.
	 */
	emptybufs = fillingbufs = 0;
	for (i = 0; i < maxchunkbufs; i++) {
		/*
		 * Skip empty and full buffers
		 */
		if (ChunkBuffer[i].state == CHUNK_EMPTY) {
			/*
			 * Keep track of empty chunk buffers while we are here
			 */
			emptybufs++;
			continue;
		}
		if (ChunkBuffer[i].state == CHUNK_FULL)
			continue;

		fillingbufs++;

		/*
		 * Make sure this chunk is eligible for re-request.
		 */
		if (! timedout &&
		    ! RequestRedoTime(ChunkBuffer[i].thischunk, stamp))
			continue;

		/*
		 * Request all the missing blocks.
		 * If the block was of dubious value, it is no longer.
		 */
		RequestMissing(ChunkBuffer[i].thischunk,
			       &ChunkBuffer[i].blockmap,
			       ChunkBuffer[i].blockcount);
		if (ChunkBuffer[i].state == CHUNK_DUBIOUS) {
			CLEVENT(1, EV_CLIDUBPROMO, ChunkBuffer[i].thischunk,
				0, 0, 0);
			ChunkBuffer[i].state = CHUNK_FILLING;
		}
	}

	CLEVENT(2, EV_CLIREQRA, emptybufs, fillingbufs, 0, 0);

	/*
	 * Issue read-ahead requests.
	 *
	 * If we already have enough unfinished chunks on our plate
	 * or we have no room for read-ahead, don't do it.
	 */
	if (emptybufs == 0 || fillingbufs >= maxinprogress)
		return;

	/*
	 * Scan our request list looking for candidates.
	 */
	k = maxreadahead;
#ifdef PASSIVE
	assert(maxreadahead > ChunksEnroute);
	k -= ChunksEnroute;
#endif
	if (k > emptybufs)
		k = emptybufs;
	for (i = 0, j = 0; i < TotalChunkCount && j < k; i++) {
		int chunk = ChunkRequestList[i];
		
		/*
		 * If already working on this chunk (or it is done), skip it.
		 */
		if (Chunks[chunk].seen)
			continue;

		/*
		 * Issue a request for the chunk if it isn't already
		 * on the way.  This chunk, whether requested or not
		 * is considered a read-ahead to us.
		 */
		if (timedout || RequestRedoTime(chunk, stamp))
			RequestRange(chunk, 0, ChunkSize(chunk));

		/*
		 * Even if we did not just request the block, we still
		 * count it as part of our readahead, since somebody has
		 * requested it and therefore it is on the way.
		 */
		j++;
	}
}

#ifdef STATS
static void
FillStats(ClientStats_t *st, struct timeval *rstamp)
{
	/* From global stats struct */
	memcpy(st, &Stats, sizeof(Stats));

	/* From imageunzip */
	st->u.v1.decompblocks = decompblocks;
	st->u.v1.writeridles = writeridles;
	st->u.v1.ebyteswritten = totaledata;
	st->u.v1.rbyteswritten = totalrdata;

	st->version            = CLIENT_STATS_VERSION;
	st->u.v1.runsec        = rstamp->tv_sec;
	st->u.v1.runmsec       = rstamp->tv_usec / 1000;
	st->u.v1.chunkbufs     = maxchunkbufs;
	st->u.v1.writebufmem   = maxwritebufmem;
	st->u.v1.maxreadahead  = maxreadahead;
	st->u.v1.maxinprogress = maxinprogress;
	st->u.v1.pkttimeout    = pkttimeout;
	st->u.v1.startdelay    = startdelay;
	st->u.v1.idletimer     = idletimer;
	st->u.v1.idledelay     = idledelay;
	st->u.v1.redodelay     = redodelay;
	st->u.v1.randomize     = randomize;
}
#endif

/*
 * Send a progress report to our server.
 * Caller should hold the heartbeat_mutex to avoid race with other packet
 * sends and with changes to the reporting params.
 */
void
SendProgressReport(void)
{
	Packet_t pkt;
	struct timeval rstamp;

	/* One-time initialization */
	if (hb_dst == 0) {
		assert(serverip.s_addr != 0);

		hb_dst = serverip.s_addr;
		if (proxyfor)
			hb_who = proxyip.s_addr;
		else
			hb_who = htonl(ClientNetID());
		hb_seq = 1;
	}

	gettimeofday(&rstamp, 0);
	memset(&pkt, 0, sizeof pkt);

	pkt.hdr.type = PKTTYPE_REPLY;
	pkt.hdr.subtype = PKTSUBTYPE_PROGRESS;
	pkt.hdr.datalen = hb_what ?
		sizeof(pkt.msg.progress) : sizeof(pkt.msg.progress.hdr);
	/* XXX set to server, PacketReply uses this as the to address */
	pkt.hdr.srcip = hb_dst;

	pkt.msg.progress.hdr.clientid = clientid;
	pkt.msg.progress.hdr.who = hb_who;
	pkt.msg.progress.hdr.when = rstamp.tv_sec;
	pkt.msg.progress.hdr.what = hb_what;
	pkt.msg.progress.hdr.seq  = hb_seq++;
	if ((hb_what & PKTPROGRESS_SUMMARY) != 0) {
		pkt.msg.progress.summary.chunks_in = ChunksReceived;
		pkt.msg.progress.summary.chunks_out = ChunksDecompressed;
		pkt.msg.progress.summary.bytes_out = totalrdata;
	}
#ifdef STATS
	if ((hb_what & PKTPROGRESS_STATS) != 0) {
		timersub(&rstamp, &stamp, &rstamp);
		FillStats(&pkt.msg.progress.stats, &rstamp);
	}
#endif

	PacketReply(&pkt, 1);
}

/*
 * Process a progress report request.
 *
 * We will either set (or update) our report interval or send an immediate
 * progress report with the requested info.
 */
static void
HandleProgress(Packet_t *p)
{
	uint32_t when = p->msg.progress.hdr.when;
	uint16_t what = p->msg.progress.hdr.what;
	uint16_t seq = p->msg.progress.hdr.seq;

	/* Heatbeat thread has to be running */
	if (!heartbeat)
		return;

	/* XXX gotta have a unicast server IP */
	if (serverip.s_addr == 0)
		return;

	/* XXX cannot sleep more that 4295 sec due to fsleep */
	if (when > 4295)
		when = 4295;

	/* keep only the relevant bits */
	what &= (PKTPROGRESS_SUMMARY|PKTPROGRESS_STATS);
	
	pthread_mutex_lock(&heartbeat_mutex);

#ifdef CONDVARS_WORK
	/* thread was disabled; wake it up */
	if (hb_interval == 0 && when > 0)
		pthread_cond_signal(&chunkbuf_cond);
#endif

	hb_interval = when;
	hb_what = what;

	/* only reset sequence number if not already set */
	if (hb_seq == 0)
		hb_seq = seq;

	/* fire off a one-time report (this also disables periodic reports) */
	if (when == 0)
		SendProgressReport();

	pthread_mutex_unlock(&heartbeat_mutex);
}

/*
 * For now the reporting mechanism is one way. The protocol is designed
 * such that the server can make requests to make an immediate report or
 * to change the reporting interval, but we don't do that yet. If the client
 * '-H <interval>' option is specified, we just make make unsolicited
 * reports at the specified interval. Simple.
 */
void *
ClientReportThread(void *arg)
{
	/*
	 * XXX we don't want to multicast these packets so make sure we
	 * know who the server is.
	 */
	if (serverip.s_addr == 0) {
		FrisLog("WARNING: no server to send heartbeats to; "
			"heartbeat reporting disabled");
	}

	/* Delay a random amount so clients don't report in sync */
	fsleep(random() % 5000000);

	if (debug)
		FrisLog("Heartbeat pthread starting up ...");

	pthread_mutex_lock(&heartbeat_mutex);
	while (1) {
		uint32_t iv = hb_interval;

		if (iv == 0) {
#ifdef CONDVARS_WORK
			pthread_cond_wait(&heartbeat_cond, &heartbeat_mutex);
#else
			pthread_mutex_unlock(&heartbeat_mutex);
			fsleep(1000000);
			pthread_mutex_lock(&heartbeat_mutex);
#endif
			continue;
		}
		pthread_mutex_unlock(&heartbeat_mutex);
		fsleep(iv * 1000000);
		pthread_mutex_lock(&heartbeat_mutex);

		SendProgressReport();
	}
}

/*
 * Join the Frisbee team, and then go into the main loop above.
 */
static void
PlayFrisbee(void)
{
	Packet_t	packet, *p = &packet;
	struct timeval  estamp, timeo;
	int		delay, rv, checkid = 0;
	int32_t		jtype = 0;

	gettimeofday(&stamp, 0);
	CLEVENT(1, EV_CLISTART, 0, 0, 0, 0);

	/*
	 * Init the random number generator. We randomize the block request
	 * sequence above, and its important that each client have a different
	 * sequence!
	 */
#ifdef __FreeBSD__
	srandomdev();
#else
	srandom(ClientNetID() ^ stamp.tv_sec ^ stamp.tv_usec ^ getpid());
#endif

	/*
	 * A random number ID. I do not think this is really necessary,
	 * but perhaps might be useful for determining when a client has
	 * crashed and returned.
	 */
	clientid = random();
	
	/*
	 * To avoid a blast of messages from a large number of clients,
	 * we can delay a small amount before startup.  If startat is
	 * non-zero we delay for that number of seconds.  Otherwise, if
	 * startdelay is non-zero, the delay value is uniformly distributed
	 * between 0 and startdelay seconds, with ms granularity.
	 */
	if (startat > 0)
		delay = startat * 1000;
	else if (startdelay > 0)
		delay = random() % (startdelay * 1000);
	else
		delay = 0;
	if (delay) {
		if (debug)
			FrisLog("Startup delay: %d.%03d seconds",
				delay/1000, delay%1000);
		DOSTAT(delayms = delay);
		fsleep(delay * 1000);
	}

	/*
	 * Send a join the team message. We block waiting for a reply
	 * since we need to know the total block size. We resend the
	 * message (dups are harmless) if we do not get a reply back.
	 */
	rv = -1;
	gettimeofday(&timeo, 0);
	while (1) {
		struct timeval now;

		gettimeofday(&now, 0);
		if (rv != 0 && timercmp(&timeo, &now, <=)) {
			CLEVENT(1, EV_CLIJOINREQ, clientid, 0, 0, 0);
			DOSTAT(joinattempts++);
			p->hdr.type = PKTTYPE_REQUEST;
			/*
			 * Unless they have specified the -N option, continue
			 * to use the V1 JOIN which tells the server only to
			 * let us join if the image being requested is a
			 * traditional, 1MB padded image.
			 *
			 * Two reasons for this: 1) right now the client
			 * code for decompressing images has not been modified
			 * to handle non-padded images, and 2) this gives us
			 * some degree of backward compatibility for a new
			 * client talking to an old (pre-JOINv2) server.
			 */
			if (!nodecompress) {
				jtype = p->hdr.subtype = PKTSUBTYPE_JOIN;
				p->hdr.datalen = sizeof(p->msg.join);
				p->msg.join.clientid = clientid;
				checkid = 0;
			} else {
				jtype = p->hdr.subtype = PKTSUBTYPE_JOIN2;
				p->hdr.datalen = sizeof(p->msg.join2);
				p->msg.join2.clientid = clientid;
				p->msg.join2.chunksize = MAXCHUNKSIZE;
				p->msg.join2.blocksize = MAXBLOCKSIZE;
				checkid = 1;
			}
			if (heartbeat) {
				pthread_mutex_lock(&heartbeat_mutex);
				PacketSend(p, 0);
				pthread_mutex_unlock(&heartbeat_mutex);
			} else
				PacketSend(p, 0);
			timeo.tv_sec = 0;
			timeo.tv_usec = 500000;
			timeradd(&timeo, &now, &timeo);
			if (debug)
				FrisLog("sent JOIN (%d)", p->hdr.subtype);
#ifdef USE_REUSEADDR_COMPAT
			/*
			 * For backward compat, we need to check the unicast
			 * socket to see if the server sent a reply there.
			 *
			 * We do not do this every time through the loop since
			 * in the non-backward compat case it will timeout
			 * every time. When other clients are busy, this will
			 * cause a backlog of MC packets possibly causing our
			 * reply to get dropped. So we only check immediately
			 * after a send.
			 */
			rv = PacketRequest(p);
#else
			assert(rv != 0);
#endif
		} else
			rv = -1;

		if (rv)
			rv = PacketReceive(p);

		/*
		 * Throw away any data packets. We cannot start until
		 * we get a reply back.
		 */
		if (rv == 0 &&
		    p->hdr.subtype == jtype &&
		    p->hdr.type == PKTTYPE_REPLY &&
		    (!checkid || p->msg.join.clientid == clientid)) {
			if (jtype == PKTSUBTYPE_JOIN) {
				p->msg.join2.chunksize = MAXCHUNKSIZE;
				p->msg.join2.blocksize = MAXBLOCKSIZE;
				p->msg.join2.bytecount =
					(uint64_t)p->msg.join.blockcount *
					MAXBLOCKSIZE;
			}
			if (debug)
				FrisLog("got JOIN (%d) reply", jtype);
			CLEVENT(1, EV_CLIJOINREP,
				p->msg.join2.chunksize,
				p->msg.join2.blocksize,
				(p->msg.join2.bytecount >> 32),
				p->msg.join2.bytecount);
			break;
		}
	}
	gettimeofday(&timeo, 0);
	InitSizes(p->msg.join2.chunksize, p->msg.join2.blocksize,
		  p->msg.join2.bytecount);
	TotalChunkCount = TotalChunks();
	ImageUnzipSetChunkCount(TotalChunkCount);
	
	if (maxchunkbufs == 0)
		maxchunkbufs = TotalChunkCount;

	/*
	 * There is no point in having more chunkbufs than there are
	 * chunks in the file. If we have partitioned up the memory,
	 * reallocate the excess to disk buffering. Otherwise, we just
	 * adjust the chunkbuf count.
	 */
	if (maxchunkbufs > TotalChunkCount) {
		if (maxmem != 0) {
			int excessmb = (int)
				((((unsigned long long)
				   (maxchunkbufs - TotalChunkCount) *
				   sizeof(ChunkBuffer_t)) / (1024 * 1024)));
			if (excessmb > 0) {
				maxwritebufmem += excessmb;
				ImageUnzipSetMemory((unsigned long long)
						    maxwritebufmem*1024*1024);
			}
		}
		maxchunkbufs = TotalChunkCount;
		if (maxinprogress > maxchunkbufs)
			maxinprogress = maxchunkbufs;
		if (maxreadahead > maxchunkbufs)
			maxreadahead = maxchunkbufs;
	}
 
	FrisLog("Joined the team after %d sec. ID is %u. "
		"File is %d chunks (%lld bytes)",
		timeo.tv_sec - stamp.tv_sec,
		clientid, TotalChunkCount, p->msg.join2.bytecount);

	ChunkerStartup();

	gettimeofday(&estamp, 0);
	timersub(&estamp, &stamp, &estamp);
	
	/*
	 * Done! Send off a leave message, but do not worry about whether
	 * the server gets it. All the server does with it is print a
	 * timestamp, and that is not critical to operation.
	 */
	CLEVENT(1, EV_CLILEAVE, clientid, estamp.tv_sec,
		(Stats.u.v1.rbyteswritten >> 32), Stats.u.v1.rbyteswritten);
#ifdef STATS
	p->hdr.type       = PKTTYPE_REQUEST;
	p->hdr.subtype    = PKTSUBTYPE_LEAVE2;
	p->hdr.datalen    = sizeof(p->msg.leave2);
	p->msg.leave2.clientid = clientid;
	p->msg.leave2.elapsed  = estamp.tv_sec;
	FillStats(&p->msg.leave2.stats, &estamp);
	/* N.B. heartbeat thread is gone, not need for mutex */
	PacketSend(p, 0);

	if (!quiet) {
		FrisLog("");
		ClientStatsDump(clientid, &p->msg.leave2.stats);
		FrisLog("");
	}
#else
	p->hdr.type       = PKTTYPE_REQUEST;
	p->hdr.subtype    = PKTSUBTYPE_LEAVE;
	p->hdr.datalen    = sizeof(p->msg.leave);
	p->msg.leave.clientid = clientid;
	p->msg.leave.elapsed  = estamp.tv_sec;
	/* N.B. heartbeat thread is gone, not need for mutex */
	PacketSend(p, 0);
#endif
	FrisLog("Left the team after %ld seconds on the field!",
		estamp.tv_sec);
}
