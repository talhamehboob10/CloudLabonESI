/*
 * Copyright (c) 2000-2020 University of Utah and the Flux Group.
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
 * Network routines.
 */
#include <sys/types.h>
#include <sys/socket.h>
#include <sys/time.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <net/if.h>
#include <ifaddrs.h>
#include <netdb.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <signal.h>
#include <errno.h>
#include "decls.h"
#include "utils.h"
#ifdef NO_SOCKET_TIMO
#include <sys/select.h>
#endif

#ifdef STATS
unsigned long nonetbufs;
#define DOSTAT(x)	(x)
#else
#define DOSTAT(x)
#endif

/* Max number of times to attempt bind to port before failing. */
#define MAXBINDATTEMPTS		1

#define IS_MCAST_ADDR(sa)	((ntohl((sa).s_addr) >> 28) == 14)

/* Max number of hops multicast hops. */
#define MCAST_TTL		5

static int		sock = -1;
#ifdef USE_REUSEADDR_COMPAT
static int		selfsock = -1;
#endif
struct in_addr		myipaddr;
static int		nobufdelay = -1;
int			broadcast = 0;
static int		isclient = 0;
static int		sndportnum;	/* kept in network order */

/*
 * Convert a string to an IPv4 address.  We first try to interpret it as
 * an IPv4 address.  If that fails, we attempt to resolve it as a host name.
 * Return non-zero on success.
 */
int
GetIP(char *str, struct in_addr *in)
{
	struct hostent *he;

	if (inet_aton(str, in) == 0) {
		if ((he = gethostbyname(str)) == NULL)
			return 0;
		memcpy(in, he->h_addr, sizeof(*in));
	}

	return 1;
}

/*
 * Return the maximum size of a socket buffer.
 * Computes it dynamically on the first call.
 *
 * XXX assumes send/recv max sizes are the same.
 */
int
GetSockbufSize(void)
{

	static int sbsize = 0;

	if (sbsize == 0) {
		int sock;

		if ((sock = socket(PF_INET, SOCK_DGRAM, IPPROTO_UDP)) < 0)
			FrisPfatal("Could not allocate a socket");

		for (sbsize = sockbufsize; sbsize > 0; sbsize -= (16*1024)) {
			int i = sbsize;
			if (setsockopt(sock, SOL_SOCKET, SO_SNDBUF,
				       &i, sizeof(i)) >= 0)
				break;
		}
		if (sbsize < 0) {
			int i = 0;
			unsigned int ilen = sizeof(i);
			if (getsockopt(sock, SOL_SOCKET, SO_SNDBUF,
				       &i, &ilen) < 0)
				i = sockbufsize;
			sbsize = i;
		}
		else {
			int i = 0;
			unsigned int ilen = sizeof(i);
			if (getsockopt(sock, SOL_SOCKET, SO_SNDBUF,
				       &i, &ilen) < 0)
				FrisPfatal("Could not read sockbuf size");
#ifdef linux
			/* In Linux, getsockopt returns 2 * actual value */
			if (i == 2 * sbsize)
				i = sbsize;
#endif
			if (i != sbsize) {
				FrisWarning("Actual socket buffer size is %d"
					    " (instead of %d)", i, sbsize);
				sbsize = i;
			}
		}
		close(sock);
		FrisLog("Maximum socket buffer size of %d bytes", sbsize);
	}
	return sbsize;
}

/*
 * Find the subnet broadcast address associated with the given interface
 * address. We use this to limit broadcasts to a single interface.
 * Returns zero if we successfully produced an address (in *bcaddr),
 * non-zero otherwise.
 */
static int
GetBcastAddr(struct in_addr *ifaddr, struct in_addr *bcaddr)
{
	struct ifaddrs *ifa, *nifa;
	struct sockaddr_in *sin;

	if (getifaddrs(&ifa) != 0) {
		FrisPwarning("Could not get interface list");
		return 1;
	}

	for (nifa = ifa; nifa != NULL; nifa = nifa->ifa_next) {
		if (nifa->ifa_addr->sa_family != AF_INET)
			continue;
		if ((nifa->ifa_flags & (IFF_UP|IFF_BROADCAST)) !=
		    (IFF_UP|IFF_BROADCAST))
			continue;
		sin = (struct sockaddr_in *)nifa->ifa_addr;
		if (ifaddr->s_addr == sin->sin_addr.s_addr) {
			*bcaddr = ((struct sockaddr_in *)nifa->ifa_broadaddr)->sin_addr;
			freeifaddrs(ifa);
			return 0;
		}
	}
	freeifaddrs(ifa);

	FrisWarning("Could not find interface %s", inet_ntoa(*ifaddr));
	return 1;
}

/*
 * Bind one port from the given range.
 * If lo == hi == 0, then we let the kernel choose.
 * If lo == hi != 0, then we must get that port.
 * Otherwise we loop over the range til we get one.
 * Returns the port bound or 0 if unsuccessful.
 */
static in_port_t
BindPort(in_addr_t addr, in_port_t portlo, in_port_t porthi)
{
	struct sockaddr_in name;
	socklen_t sl = sizeof(name);

	name.sin_family      = AF_INET;
	name.sin_addr.s_addr = htonl(addr);
	name.sin_port        = htons(portlo);

	/*
	 * Let the kernel choose.
	 */
	if (portlo == 0) {
		if (bind(sock, (struct sockaddr *)&name, sl) != 0) {
			FrisPwarning("Bind to %s:%d failed",
				     inet_ntoa(name.sin_addr), portlo);
			return 0;
		}

		if (getsockname(sock, (struct sockaddr *)&name, &sl) < 0)
			FrisPfatal("could not determine bound port");
		return(ntohs(name.sin_port));
	}
	
	/*
	 * Specific port. Try a few times to get it.
	 */
	if (portlo == porthi) {
		int i = MAXBINDATTEMPTS;

		while (i) {
			if (bind(sock, (struct sockaddr *)&name, sl) == 0)
				return portlo;

			if (--i) {
				FrisPwarning("Bind to %s:%d failed. "
					     "Will try %d more times!",
					     inet_ntoa(name.sin_addr), portlo, i);
				sleep(5);
			}
		}
		FrisPwarning("Bind to %s:%d failed",
			     inet_ntoa(name.sin_addr), portlo);
		return 0;
	}

	/*
	 * Port range, gotta loop through trying to grab one.
	 */
	while (portlo <= porthi) {
		name.sin_port = htons(portlo);
		if (bind(sock, (struct sockaddr *)&name, sl) == 0)
			return portlo;
		portlo++;
	}

	return 0;
}

static void
CommonInit(int portlo, int porthi, int dobind)
{
	int			i;
	char			buf[BUFSIZ];
	struct hostent		*he;

	sockbufsize = GetSockbufSize();
	if ((sock = socket(PF_INET, SOCK_DGRAM, IPPROTO_UDP)) < 0)
		FrisPfatal("Could not allocate a socket");

	i = sockbufsize;
	if (setsockopt(sock, SOL_SOCKET, SO_SNDBUF, &i, sizeof(i)) < 0)
		FrisPwarning("Could not set send socket buffer size to %d", i);
    
	i = sockbufsize;
	if (setsockopt(sock, SOL_SOCKET, SO_RCVBUF, &i, sizeof(i)) < 0)
		FrisPwarning("Could not set receive socket buffer size to %d",
			     i);

	/*
	 * At present, we use a multicast address in both directions.
	 */
	if (IS_MCAST_ADDR(mcastaddr)) {
		unsigned int loop = 0, ttl = MCAST_TTL;
		struct ip_mreq mreq;

		FrisLog("Using Multicast %s", inet_ntoa(mcastaddr));

		mreq.imr_multiaddr.s_addr = mcastaddr.s_addr;

		if (mcastif.s_addr)
			mreq.imr_interface.s_addr = mcastif.s_addr;
		else
			mreq.imr_interface.s_addr = htonl(INADDR_ANY);

		if (setsockopt(sock, IPPROTO_IP, IP_ADD_MEMBERSHIP,
			       &mreq, sizeof(mreq)) < 0)
			FrisPfatal("setsockopt(IPPROTO_IP, IP_ADD_MEMBERSHIP)");

		if (setsockopt(sock, IPPROTO_IP, IP_MULTICAST_TTL,
			       &ttl, sizeof(ttl)) < 0) 
			FrisPfatal("setsockopt(IPPROTO_IP, IP_MULTICAST_TTL)");

		/* Disable local echo */
		if (setsockopt(sock, IPPROTO_IP, IP_MULTICAST_LOOP,
			       &loop, sizeof(loop)) < 0)
			FrisPfatal("setsockopt(IPPROTO_IP, IP_MULTICAST_LOOP)");

		if (mcastif.s_addr &&
		    setsockopt(sock, IPPROTO_IP, IP_MULTICAST_IF,
			       &mcastif, sizeof(mcastif)) < 0) {
			FrisPfatal("setsockopt(IPPROTO_IP, IP_MULTICAST_IF)");
		}

#ifdef USE_REUSEADDR
		/*
		 * Allow use of the desired port in the presense of other
		 * non-MC use. Also allows for multiple clients of the same
		 * stream.
		 */
		if (isclient) {
			i = 1;
			if (setsockopt(sock, SOL_SOCKET, SO_REUSEADDR,
				       &i, sizeof(i)))
				FrisWarning("Could not set SO_REUSEADDR");
		}
#endif

#ifdef WITH_IGMP
		IGMPInit(&mcastif, &mcastaddr);
#endif
	}
	else if (broadcast) {
		FrisLog("Setting broadcast mode");

		/*
		 * If they are using the local broadcast address and they
		 * have specified an interface, attempt to limit broadcasts
		 * to that interface by using the subnet broadcast address.
		 * Otherwise we issue a dire warning about the consequences
		 * of broadcasting to all interfaces.
		 */
		if (ntohl(mcastaddr.s_addr) == INADDR_BROADCAST) {
			struct in_addr bcaddr;
			if (mcastif.s_addr &&
			    GetBcastAddr(&mcastif, &bcaddr) == 0) {
				FrisLog("Limiting broadcasts using %s",
					inet_ntoa(bcaddr));
				mcastaddr = bcaddr;
			} else
				FrisWarning("WARNING: will broadcast "
					    "to ALL configured interfaces!");
		}

		i = 1;
		if (setsockopt(sock, SOL_SOCKET, SO_BROADCAST,
			       &i, sizeof(i)) < 0)
			FrisPfatal("setsockopt(SOL_SOCKET, SO_BROADCAST)");
	}

	if (dobind) {
		in_addr_t addr = INADDR_ANY;

#ifdef USE_REUSEADDR
		/*
		 * For REUSEADDR to work in the face of unrelated apps that
		 * bind INADDR_ANY:port, we must NOT also bind INADDR_ANY.
		 */
		if (isclient && IS_MCAST_ADDR(mcastaddr))
			addr = ntohl(mcastaddr.s_addr);
#endif
		portnum = BindPort(addr, portlo, porthi);

		/*
		 * Could not get a port.
		 * Note that we exit with a magic value. This is for server
		 * wrapper-scripts so that they can differentiate this case
		 * and try again with a different port.
		 *
		 * Note also that if portlo == 0, it cannot be a port
		 * conflict so we do not retry.
		 */
		if (portnum == 0) {
			FrisError("Could not bind %s:%d!\n",
				  inet_ntoa(mcastaddr), portnum);
			exit(portlo ? EADDRINUSE : -1);
		}
		FrisLog("Bound to %s:%d", inet_ntoa(mcastaddr), portnum);
	} else {
		portnum = portlo;
		FrisLog("NOT binding to %s:%d", inet_ntoa(mcastaddr), portnum);
	}
	sndportnum = htons(portnum);

#ifndef NO_SOCKET_TIMO
	/*
	 * We use a socket level timeout instead of polling for data.
	 */
	{
		struct timeval timeout;

		timeout.tv_sec  = 0;
		timeout.tv_usec = PKTRCV_TIMEOUT;
		if (setsockopt(sock, SOL_SOCKET, SO_RCVTIMEO,
			       &timeout, sizeof(timeout)) < 0)
			FrisPfatal("setsockopt(SOL_SOCKET, SO_RCVTIMEO)");
	}
#endif

	/*
	 * If a specific interface IP is specified, use that to
	 * tag our outgoing packets.  Otherwise we use the IP address
	 * associated with our hostname.
	 */
	if (mcastif.s_addr)
		myipaddr.s_addr = mcastif.s_addr;
	else {
		if (gethostname(buf, sizeof(buf)) < 0)
			FrisPfatal("gethostname failed");

		if ((he = gethostbyname(buf)) == 0)
			FrisFatal("gethostbyname: %s", hstrerror(h_errno));

		memcpy((char *)&myipaddr, he->h_addr, sizeof(myipaddr));
	}

	/*
	 * Compute the out of buffer space delay.
	 */
	if (nobufdelay < 0)
		nobufdelay = sleeptime(100, NULL, 1);
}

int
ClientNetInit(int port)
{
	isclient = 1;
#ifdef SAME_HOST_HACK
	CommonInit(port, port, 0);
#else
	CommonInit(port, port, 1);
#endif

#ifdef USE_REUSEADDR_COMPAT
	/*
	 * Bind a unicast socket for our interface address and the port.
	 *
	 * XXX this is for backward compatibility with an older server and
	 * is used for two purposes.
	 *
	 * One, is so that we can receive a unicast JOIN reply from an old
	 * server (the new server always multicasts JOIN replies). The old
	 * client would see this reply because it would just bind the port
	 * using INADDR_ANY in CommonInit, insuring that it would get the
	 * JOIN reply. But with SO_REUSEADDR, we do not bind to INADDR_ANY,
	 * we bind explicitly to the MC address and port and thus would not
	 * see the reply without also binding the unicast (interface) address
	 * and port.
	 *
	 * Two, we send all our multicast packets (joins and block requests)
	 * out this interface so that the packets are stamped with the IP of
	 * the interface and not the MC IP. The old server required that the
	 * packet source IP match the source IP in the frisbee packet header
	 * (the new server allows packets that come from the MC address).
	 * We could just set the frisbee packet header srcip to be the MC
	 * address instead, but we use that address for logging and stats
	 * and want to keep it correct.
	 */
	if (myipaddr.s_addr && IS_MCAST_ADDR(mcastaddr)) {
		struct sockaddr_in name;
		int i;

		if ((selfsock = socket(PF_INET, SOCK_DGRAM, IPPROTO_UDP)) < 0)
			FrisPfatal("Could not allocate a socket");

		i = MCAST_TTL;
		if (setsockopt(selfsock, IPPROTO_IP, IP_MULTICAST_TTL,
			       &i, sizeof(i)) < 0) 
			FrisWarning("Could not set MC TTL");

		/* Disable local echo */
		i = 0;
		if (setsockopt(selfsock, IPPROTO_IP, IP_MULTICAST_LOOP,
			       &i, sizeof(i)) < 0)
			FrisWarning("Could not clear local echo");

		/* Make sure we use the correct interface */
		if (mcastif.s_addr &&
		    setsockopt(selfsock, IPPROTO_IP, IP_MULTICAST_IF,
			       &mcastif, sizeof(mcastif)) < 0) {
			FrisWarning("Could not set MCAST_IF");
		}

		/* Set REUSEADDR */
		i = 1;
		if (setsockopt(selfsock, SOL_SOCKET, SO_REUSEADDR,
			       &i, sizeof(i)))
			FrisWarning("Could not set SO_REUSEADDR");

		name.sin_family = AF_INET;
		name.sin_port = htons(portnum);
		name.sin_addr.s_addr = myipaddr.s_addr;
		if (bind(selfsock, (struct sockaddr *)&name, sizeof(name)) < 0)
			FrisPfatal("Could not bind to %s:%d",
				   inet_ntoa(name.sin_addr), portnum);

#ifndef NO_SOCKET_TIMO
		/*
		 * We use a socket level timeout instead of polling for data.
		 */
		{
			struct timeval timeout;

			timeout.tv_sec  = 0;
			timeout.tv_usec = PKTRCV_TIMEOUT;
			if (setsockopt(selfsock, SOL_SOCKET, SO_RCVTIMEO,
				       &timeout, sizeof(timeout)) < 0)
				FrisPfatal("setsockopt(SOL_SOCKET, SO_RCVTIMEO)");
		}
#endif
	}
#endif

	return 1;
}

unsigned long
ClientNetID(void)
{
	return ntohl(myipaddr.s_addr);
}

int
ServerNetInit(int portlo, int porthi)
{
	isclient = 0;
	CommonInit(portlo, porthi, 1);

#ifdef linux
	/*
	 * Enabled extended error reporting so that we get back ENOBUFS
	 * when we overrun the sent socket or NIC send buffers.
	 * For now we just do this on the client.
	 */
	{
		int i = 1;
		if (setsockopt(sock, SOL_IP, IP_RECVERR, &i, sizeof(i)) < 0)
			FrisPwarning("Could not enable extended errors");
	}
#endif

	return 1;
}

/*
 * XXX hack.
 *
 * Cisco switches without a multicast router defined have an unfortunate
 * habit of losing our IGMP membership.  This function allows us to send
 * a report message to remind the switch we are still around.
 *
 * We need a better way to do this!
 */
int
NetMCKeepAlive(void)
{
	struct ip_mreq mreq;

	if (broadcast || (ntohl(mcastaddr.s_addr) >> 28) != 14)
		return 0;

	if (sock == -1)
		return 1;

#ifdef WITH_IGMP
	/* Send a direct V2 report packet if possible */
	if (IGMPSendReport() == 0)
		return 0;
#endif

	mreq.imr_multiaddr.s_addr = mcastaddr.s_addr;
	if (mcastif.s_addr)
		mreq.imr_interface.s_addr = mcastif.s_addr;
	else
		mreq.imr_interface.s_addr = htonl(INADDR_ANY);

	if (setsockopt(sock, IPPROTO_IP, IP_DROP_MEMBERSHIP,
		       &mreq, sizeof(mreq)) < 0 ||
	    setsockopt(sock, IPPROTO_IP, IP_ADD_MEMBERSHIP,
		       &mreq, sizeof(mreq)) < 0)
		return 1;

	return 0;
}

/*
 * Look for a packet on the socket. Propogate the errors back to the caller
 * exactly as the system call does. Remember that we set up a socket timeout
 * above, so we will get EWOULDBLOCK errors when no data is available. 
 *
 * The amount of data received is determined from the datalen of the hdr.
 * All packets are actually the same size/structure. 
 *
 * Returns 0 for a good packet, 1 for a bad packet, -1 on timeout.
 */
int
PacketReceive(Packet_t *p)
{
	struct sockaddr_in from;
	int		   mlen;
	unsigned int	   alen;

#ifdef NO_SOCKET_TIMO
	fd_set		ready;
	struct timeval	tv;
	int		rv;

	tv.tv_sec = 0;
	tv.tv_usec = PKTRCV_TIMEOUT;
	FD_ZERO(&ready);
	FD_SET(sock, &ready);
	rv = select(sock+1, &ready, NULL, NULL, &tv);
	if (rv < 0) {
		if (errno == EINTR)
			return -1;
		FrisPfatal("PacketReceive(select)");
	}
	if (rv == 0)
		return -1;
#endif
	alen = sizeof(from);
	bzero(&from, alen);
	if ((mlen = recvfrom(sock, p, sizeof(*p), 0,
			     (struct sockaddr *)&from, &alen)) < 0) {
		if (errno == EWOULDBLOCK || errno == EINTR)
			return -1;
		FrisPfatal("PacketReceive(recvfrom)");
	}

	/*
	 * Basic integrity checks
	 */
	if ((uint32_t)mlen < sizeof(p->hdr) + p->hdr.datalen) {
		FrisLog("Bad message length (%d != %d)",
			mlen, p->hdr.datalen);
		return 1;
	}
#ifdef SAME_HOST_HACK
	/*
	 * If using a host alias for the client, a message may get
	 * the wrong IP, so rig the IP check to make it always work.
	 */
	if (p->hdr.srcip != from.sin_addr.s_addr)
		from.sin_addr.s_addr = p->hdr.srcip;

	/*
	 * Also, we aren't binding to a port on the client side, so the
	 * first message to the server will contain the actual port we
	 * will use from now on.
	 */
	if (!isclient && sndportnum == htons(portnum) &&
	    sndportnum != from.sin_port)
		sndportnum = from.sin_port;
#endif
	/*
	 * XXX accept packets from the MC address. This will be the case with
	 * newer clients that bind to the MC address instead of INADDR_ANY.
	 *
	 * Note that on a client, certain packets should only come from the
	 * server. These include: BLOCK replies and PROGRESS requests.
	 * Don't rewrite the address in these cases so that the following
	 * check will catch them (or a later caller check on hdr.srcip).
	 */
	if (from.sin_addr.s_addr == mcastaddr.s_addr) {
		if (isclient &&
		    (p->hdr.subtype == PKTSUBTYPE_BLOCK ||
		     (p->hdr.subtype == PKTSUBTYPE_PROGRESS &&
		      p->hdr.type == PKTTYPE_REQUEST)))
			;
		else
			from.sin_addr.s_addr = p->hdr.srcip;
	}

	if (p->hdr.srcip != from.sin_addr.s_addr) {
		FrisLog("Bad message source (%x != %x)",
			ntohl(from.sin_addr.s_addr), ntohl(p->hdr.srcip));
		return 1;
	}
	if (sndportnum != from.sin_port) {
		FrisLog("Bad message port (%d != %d)",
			ntohs(from.sin_port), ntohs(sndportnum));
		return 1;
	}
	return 0;
}

#ifdef USE_REUSEADDR_COMPAT
/*
 * Same as PacketReceive but read from unicast (self) socket.
 *
 * Returns 0 for a good packet, 1 for a bad packet, -1 on timeout.
 */
int
PacketRequest(Packet_t *p)
{
	struct sockaddr_in from;
	int		   mlen;
	unsigned int	   alen;

	if (selfsock < 0)
		return -1;

#ifdef NO_SOCKET_TIMO
	{
		fd_set		ready;
		struct timeval	tv;
		int		rv, maxfd;

		tv.tv_sec = 0;
		tv.tv_usec = PKTRCV_TIMEOUT;
		FD_ZERO(&ready);
		FD_SET(selfsock, &ready);
		rv = select(selfsock+1, &ready, NULL, NULL, &tv);
		if (rv < 0) {
			if (errno == EINTR)
				return -1;
			FrisPfatal("PacketRequest(select)");
		}
		if (rv == 0)
			return -1;
	}
#endif
	alen = sizeof(from);
	bzero(&from, alen);
	if ((mlen = recvfrom(selfsock, p, sizeof(*p), 0,
			     (struct sockaddr *)&from, &alen)) < 0) {
		if (errno == EWOULDBLOCK || errno == EINTR)
			return -1;
		FrisPfatal("PacketRequest(recvfrom)");
	}

	/*
	 * Basic integrity checks
	 */
	if (mlen < sizeof(p->hdr) + p->hdr.datalen) {
		FrisLog("Bad message length (%d != %d)",
			mlen, p->hdr.datalen);
		return 1;
	}
#ifdef SAME_HOST_HACK
	/*
	 * If using a host alias for the client, a message may get
	 * the wrong IP, so rig the IP check to make it always work.
	 */
	if (p->hdr.srcip != from.sin_addr.s_addr)
		from.sin_addr.s_addr = p->hdr.srcip;

	/*
	 * Also, we aren't binding to a port on the client side, so the
	 * first message to the server will contain the actual port we
	 * will use from now on.
	 */
	if (!isclient && sndportnum == htons(portnum) &&
	    sndportnum != from.sin_port)
		sndportnum = from.sin_port;
#endif
	if (p->hdr.srcip != from.sin_addr.s_addr) {
		FrisLog("Bad message source (%x != %x)",
			ntohl(from.sin_addr.s_addr), ntohl(p->hdr.srcip));
		return 1;
	}
	if (sndportnum != from.sin_port) {
		FrisLog("Bad message port (%d != %d)",
			ntohs(from.sin_port), ntohs(sndportnum));
		return 1;
	}
	return 0;
}
#endif

#ifndef MSG_DONTWAIT
#define MSG_DONTWAIT 0
#endif

/*
 * We use blocking sends since there is no point in giving up. All packets
 * go to the same place, whether client or server.
 *
 * The amount of data sent is determined from the datalen of the packet hdr.
 * All packets are actually the same size/structure. 
 */
void
PacketSend(Packet_t *p, int *resends)
{
	struct sockaddr_in to;
	int		   len, delays, rc;
	int		   fd = sock;

	len = sizeof(p->hdr) + p->hdr.datalen;
	p->hdr.srcip = myipaddr.s_addr;

	to.sin_family      = AF_INET;
	to.sin_port        = sndportnum;
	to.sin_addr.s_addr = mcastaddr.s_addr;

	delays = 0;
#ifdef USE_REUSEADDR_COMPAT
	/* send out selfsock so the source IP is ours and not the MC addr */
	if (selfsock >= 0)
		fd = selfsock;
#endif
	while ((rc = sendto(fd, (void *)p, len, MSG_DONTWAIT,
			    (struct sockaddr *)&to, sizeof(to))) <= 0) {
		if (rc < 0 && !(errno == ENOBUFS || errno == EAGAIN))
			FrisPfatal("PacketSend(sendto)");

		/*
		 * ENOBUFS (BSD) or EAGAIN (Linux, because we set DONTWAIT)
		 * means there was not enough socket space for the packet.
		 * Okay to sleep a bit to let things drain.
		 *
		 * Note that on BSD, ENOBUFS is also returned when the NIC
		 * send buffers are full, so we should never lose a packet
		 * on the send path.
		 *
		 * On Linux, we get this behavior as well by turning on
		 * the extended error message passing (IP_RECVERR).
		 */
		delays++;
		fsleep(nobufdelay);
	}

	DOSTAT(nonetbufs += delays);
	if (resends != 0)
		*resends = delays;
}

/*
 * Basically the same as above, but instead of sending to the multicast
 * group, send to the (unicast) IP in the packet header. This simplifies
 * the logic in a number of places, by avoiding having to deal with
 * multicast packets that are not destined for us, but for someone else.
 */
void
PacketReply(Packet_t *p, int firenforget)
{
	struct sockaddr_in to;
	int		len;
	int		fd = sock;

	len = sizeof(p->hdr) + p->hdr.datalen;

	to.sin_family      = AF_INET;
	to.sin_port        = sndportnum;
	to.sin_addr.s_addr = p->hdr.srcip;
	p->hdr.srcip       = myipaddr.s_addr;

#ifdef USE_REUSEADDR_COMPAT
	/* send out selfsock so the source IP is ours and not the MC addr */
	if (selfsock >= 0)
		fd = selfsock;
#endif

	while (sendto(fd, (void *)p, len, 0, 
		      (struct sockaddr *)&to, sizeof(to)) < 0) {
		if (errno != ENOBUFS && errno != EAGAIN)
			FrisPfatal("PacketReply(sendto)");

		if (firenforget)
			break;

		/*
		 * ENOBUFS means we ran out of mbufs. Okay to sleep a bit
		 * to let things drain.
		 */
		DOSTAT(nonetbufs++);
		fsleep(nobufdelay);
	}
}

int
PacketValid(Packet_t *p, int nchunks)
{
	switch (p->hdr.type) {
	case PKTTYPE_REQUEST:
	case PKTTYPE_REPLY:
		break;
	default:
		return 0;
	}

	switch (p->hdr.subtype) {
	case PKTSUBTYPE_BLOCK:
		if (p->hdr.datalen < sizeof(p->msg.block))
			return 0;
		if (p->msg.block.chunk < 0 ||
		    p->msg.block.chunk >= nchunks ||
		    p->msg.block.block < 0 ||
		    p->msg.block.block >= MAXCHUNKSIZE)
			return 0;
		break;
	case PKTSUBTYPE_REQUEST:
		if (p->hdr.datalen < sizeof(p->msg.request))
			return 0;
		if (p->msg.request.chunk < 0 ||
		    p->msg.request.chunk >= nchunks ||
		    p->msg.request.block < 0 ||
		    p->msg.request.block >= MAXCHUNKSIZE ||
		    p->msg.request.count < 0 ||
		    p->msg.request.block+p->msg.request.count > MAXCHUNKSIZE)
			return 0;
		break;
	case PKTSUBTYPE_PREQUEST:
		if (p->hdr.datalen < sizeof(p->msg.prequest))
			return 0;
		if (p->msg.prequest.chunk < 0 ||
		    p->msg.prequest.chunk >= nchunks)
			return 0;
		break;
	case PKTSUBTYPE_JOIN:
		if (p->hdr.datalen < sizeof(p->msg.join))
			return 0;
		break;
	case PKTSUBTYPE_JOIN2:
		if (p->hdr.datalen < sizeof(p->msg.join2))
			return 0;
		break;
	case PKTSUBTYPE_LEAVE:
		if (p->hdr.datalen < sizeof(p->msg.leave))
			return 0;
		break;
	case PKTSUBTYPE_LEAVE2:
		if (p->hdr.datalen < sizeof(p->msg.leave2))
			return 0;
		break;
	case PKTSUBTYPE_PROGRESS:
		if (p->hdr.datalen < sizeof(p->msg.progress.hdr))
			return 0;
		break;
	default:
		return 0;
	}

	return 1;
}

/*
 * Functions for communicating with the master server.
 *
 * TODO: protocol for negotiating the protocol version:
 * On the client, send a request with our current version and:
 *   - get a version error back: server must be V01, so redo with V01
 *   - otherwise header reply contains version
 *     if not our version, must be a lower version, so redo with that version
 * On the server:
 *   - version less than our current version, use that version
 *   - version greater than ours, reply with our version 
 */
#ifdef MASTER_SERVER
int
MsgSend(int msock, MasterMsg_t *msg, size_t size, int timo)
{
	void *buf = msg;
	int cc;
	struct timeval tv, now, then;
	fd_set wfds;

	if (timo) {
		tv.tv_sec = timo;
		tv.tv_usec = 0;
		gettimeofday(&then, NULL);
		timeradd(&then, &tv, &then);
	}
	while (size > 0) {
		if (timo) {
			gettimeofday(&now, NULL);
			if (timercmp(&now, &then, >=)) {
				cc = 0;
			} else {
				timersub(&then, &now, &tv);
				FD_ZERO(&wfds);
				FD_SET(msock, &wfds);
				cc = select(msock+1, NULL, &wfds, NULL, &tv);
			}
			if (cc <= 0) {
				if (cc == 0) {
					errno = ETIMEDOUT;
					cc = -1;
				}
				break;
			}
		}

		cc = write(msock, buf, size);
		if (cc <= 0)
			break;

		size -= cc;
		buf += cc;
	}

	if (size != 0) {
		char *estr = "master server message send";
		if (cc == 0)
			fprintf(stderr, "%s: Unexpected EOF\n", estr);
		else
			perror(estr);
		return 0;
	}
	return 1;
}

int
MsgReceive(int msock, MasterMsg_t *msg, size_t size, int timo)
{
	void *buf = msg;
	int cc;
	struct timeval tv, now, then;
	fd_set rfds;

	if (timo) {
		tv.tv_sec = timo;
		tv.tv_usec = 0;
		gettimeofday(&then, NULL);
		timeradd(&then, &tv, &then);
	}
	while (size > 0) {
		if (timo) {
			gettimeofday(&now, NULL);
			if (timercmp(&now, &then, >=)) {
				cc = 0;
			} else {
				timersub(&then, &now, &tv);
				FD_ZERO(&rfds);
				FD_SET(msock, &rfds);
				cc = select(msock+1, &rfds, NULL, NULL, &tv);
			}
			if (cc <= 0) {
				if (cc == 0) {
					errno = ETIMEDOUT;
					cc = -1;
				}
				break;
			}
		}

		cc = read(msock, buf, size);
		if (cc <= 0)
			break;

		size -= cc;
		buf += cc;
	}

	if (size != 0) {
		char *estr = "master server message receive";
		if (cc == 0)
			fprintf(stderr, "%s: Unexpected EOF\n", estr);
		else
			perror(estr);
		return 0;
	}
	return 1;
}

/*
 * Contact the master server to discover download information for imageid.
 * 'sip' and 'sport' are the addr/port of the master server, 'method'
 * specifies the desired download method, 'askonly' is set to just ask
 * for information about the image (without starting a server), 'timeout'
 * is how long to wait for a response.
 *
 * If 'hostip' is not zero, then we are requesting information on behalf of
 * that node.  The calling node (us) must have "proxy" permission on the
 * server for this to work.
 *
 * On success, return non-zero with 'reply' filled in with the server's
 * response IN HOST ORDER.  On failure returns zero.
 */
int
ClientNetFindServer(in_addr_t sip, in_port_t sport,
		    in_addr_t hostip, char *imageid,
		    int method, int askonly, int timeout,
		    GetReply *reply, struct in_addr *myip)
{
	struct sockaddr_in name;
	MasterMsg_t msg;
	int msock, len;
	
	if ((msock = socket(PF_INET, SOCK_STREAM, IPPROTO_TCP)) < 0) {
		perror("Could not allocate socket for master server");
		return 0;
	}
	if (sport == 0)
		sport = MS_PORTNUM;

	/* XXX need connection timeout! */

	name.sin_family = AF_INET;
	name.sin_addr.s_addr = htonl(sip);
	name.sin_port = htons(sport);
	if (connect(msock, (struct sockaddr *)&name, sizeof(name)) < 0) {
		fprintf(stderr,
			"Connecting to master server %s:%d failed: %s",
			inet_ntoa(name.sin_addr), sport, strerror(errno));
		close(msock);
		return 0;
	}

	/*
	 * XXX recover the IP address of the interface used to talk to
	 * the server.
	 */
	if (myip) {
		struct sockaddr_in me;
		socklen_t len = sizeof me;

		if (getsockname(msock, (struct sockaddr *)&me, &len) < 0) {
			perror("getsockname");
			close(msock);
			return 0;
		}
		*myip = me.sin_addr;
	}

	memset(&msg, 0, sizeof msg);
	strncpy((char *)msg.hdr.version, MS_MSGVERS_1,
		sizeof(msg.hdr.version));
	msg.hdr.type = htonl(MS_MSGTYPE_GETREQUEST);
	msg.body.getrequest.hostip = htonl(hostip);
	if (askonly) {
		msg.body.getrequest.status = 1;
		msg.body.getrequest.methods = MS_METHOD_ANY;
	} else {
		msg.body.getrequest.methods = method;
	}
	len = strlen(imageid);
	if (len > MS_MAXIDLEN)
		len = MS_MAXIDLEN;
	msg.body.getrequest.idlen = htons(len);
	strncpy((char *)msg.body.getrequest.imageid, imageid, MS_MAXIDLEN);

	len = sizeof msg.hdr + sizeof msg.body.getrequest;
	if (!MsgSend(msock, &msg, len, timeout)) {
		close(msock);
		return 0;
	}

	memset(&msg, 0, sizeof msg);
	len = sizeof msg.hdr + sizeof msg.body.getreply;
	if (!MsgReceive(msock, &msg, len, timeout)) {
		close(msock);
		return 0;
	}
	close(msock);

	if (strncmp((char *)msg.hdr.version, MS_MSGVERS_1,
		    sizeof(msg.hdr.version))) {
		fprintf(stderr,
			"Got incorrect version from master server %s:%d\n",
			inet_ntoa(name.sin_addr), sport);
		return 0;
	}
	if (ntohl(msg.hdr.type) != MS_MSGTYPE_GETREPLY) {
		fprintf(stderr,
			"Got incorrect reply from master server %s:%d\n",
			inet_ntoa(name.sin_addr), sport);
		return 0;
	}

	/*
	 * Convert the reply info to host order
	 */
	*reply = msg.body.getreply;
	reply->error = ntohs(reply->error);
	reply->servaddr = ntohl(reply->servaddr);
	reply->addr = ntohl(reply->addr);
	reply->port = ntohs(reply->port);
	reply->sigtype = ntohs(reply->sigtype);
	if (reply->sigtype == MS_SIGTYPE_MTIME)
		*(uint32_t *)reply->signature =
			ntohl(*(uint32_t *)reply->signature);
	reply->hisize = ntohl(reply->hisize);
	reply->losize = ntohl(reply->losize);
	return 1;
}

/*
 * Contact the master server to negotiate an upload for a 'file' to store
 * under the given 'imageid'.
 *
 * 'sip' and 'sport' are the addr/port of the master server, 'askonly' is
 * set to just see if the upload is allowed and to get characteristics of
 * any existing copy of the image, 'timeout' is how long to wait for a
 * response.
 *
 * If 'hostip' is not zero, then we are requesting information on behalf of
 * that node.  The calling node (us) must have "proxy" permission on the
 * server for this to work.
 *
 * On success, return non-zero with 'reply' filled in with the server's
 * response IN HOST ORDER.  On failure returns zero.
 */
int
ClientNetPutRequest(in_addr_t sip, in_port_t sport,
		    in_addr_t hostip, char *imageid,
		    uint64_t isize, uint32_t mtime,
		    int timeout, int askonly, int reqtimo, PutReply *reply)
{
	struct sockaddr_in name;
	MasterMsg_t msg;
	int msock, len;
	
	if ((msock = socket(PF_INET, SOCK_STREAM, IPPROTO_TCP)) < 0) {
		perror("Could not allocate socket for master server");
		return 0;
	}
	if (sport == 0)
		sport = MS_PORTNUM;

	/* XXX need connection timeout! */

	name.sin_family = AF_INET;
	name.sin_addr.s_addr = htonl(sip);
	name.sin_port = htons(sport);
	if (connect(msock, (struct sockaddr *)&name, sizeof(name)) < 0) {
		fprintf(stderr,
			"Connecting to master server %s:%d failed: %s\n",
			inet_ntoa(name.sin_addr), sport, strerror(errno));
		close(msock);
		return 0;
	}

	memset(&msg, 0, sizeof msg);
	strncpy((char *)msg.hdr.version, MS_MSGVERS_1,
		sizeof(msg.hdr.version));
	msg.hdr.type = htonl(MS_MSGTYPE_PUTREQUEST);
	msg.body.putrequest.hostip = htonl(hostip);
	if (askonly)
		msg.body.putrequest.status = askonly;
	len = strlen(imageid);
	if (len > MS_MAXIDLEN)
		len = MS_MAXIDLEN;
	msg.body.putrequest.idlen = htons(len);
	strncpy((char *)msg.body.putrequest.imageid, imageid, MS_MAXIDLEN);
	if (isize > 0) {
		msg.body.putrequest.hisize = htonl(isize >> 32);
		msg.body.putrequest.losize = htonl(isize);
	}
	if (mtime)
		msg.body.putrequest.mtime = htonl(mtime);
	/* XXX have the server wait longer than us so we timeout first */
	if (timeout)
		msg.body.putrequest.timeout = htonl(timeout+2);

	len = sizeof msg.hdr + sizeof msg.body.putrequest;
	if (!MsgSend(msock, &msg, len, reqtimo)) {
		close(msock);
		return 0;
	}

	memset(&msg, 0, sizeof msg);
	len = sizeof msg.hdr + sizeof msg.body.putreply;
	if (!MsgReceive(msock, &msg, len, reqtimo)) {
		close(msock);
		return 0;
	}
	close(msock);

	if (strncmp((char *)msg.hdr.version, MS_MSGVERS_1,
		    sizeof(msg.hdr.version))) {
		fprintf(stderr,
			"Got incorrect version from master server %s:%d\n",
			inet_ntoa(name.sin_addr), sport);
		return 0;
	}
	if (ntohl(msg.hdr.type) != MS_MSGTYPE_PUTREPLY) {
		fprintf(stderr,
			"Got incorrect reply from master server %s:%d\n",
			inet_ntoa(name.sin_addr), sport);
		return 0;
	}

	/*
	 * Convert the reply info to host order
	 */
	*reply = msg.body.putreply;
	reply->error = ntohs(reply->error);
	reply->addr = ntohl(reply->addr);
	reply->port = ntohs(reply->port);
	reply->sigtype = ntohs(reply->sigtype);
	if (reply->sigtype == MS_SIGTYPE_MTIME)
		*(uint32_t *)reply->signature =
			ntohl(*(uint32_t *)reply->signature);
	reply->hisize = ntohl(reply->hisize);
	reply->losize = ntohl(reply->losize);
	reply->himaxsize = ntohl(reply->himaxsize);
	reply->lomaxsize = ntohl(reply->lomaxsize);
	return 1;
}

#endif

/*
 * Functions for dealing with IGMP
 */
#ifdef WITH_IGMP
#include <netinet/in_systm.h>	/* for older *BSD that needs n_long */
#include <netinet/ip.h>
#include <netinet/igmp.h>

#ifdef IGMP_MEMBERSHIP_QUERY
#define IGMP_QUERY IGMP_MEMBERSHIP_QUERY
#else
#define IGMP_QUERY IGMP_HOST_MEMBERSHIP_QUERY
#endif
#ifdef IGMP_V2_MEMBERSHIP_REPORT
#define IGMP_REPORT IGMP_V2_MEMBERSHIP_REPORT
#else
#define IGMP_REPORT IGMP_v2_HOST_MEMBERSHIP_REPORT
#endif

static struct igmp qpacket, rpacket;
static struct in_addr mciface;
static struct sockaddr_in allhosts, mcgroup;

static uint16_t
igmp_csum(struct igmp *pkt)
{
	char *addr = (char *)pkt;
	int cc = sizeof(*pkt);
	uint32_t csum = 0;

	while (cc >= sizeof(uint16_t)) {
		csum += *(uint16_t *)addr;
		addr += sizeof(uint16_t);
		cc -= sizeof(uint16_t);
	}
	if (cc > 0)
		csum = csum + *(uint8_t *)addr;

	while ((csum >> 16) != 0)
		csum = (csum >> 16) + (csum & 0xFFFF);

	return(~csum);
}

static int
igmp_opensocket(void)
{
	unsigned char ra[4];
	int ttl = 1;
	int sock;

	sock = socket(AF_INET, SOCK_RAW, IPPROTO_IGMP);
	if (sock < 0) {
		perror("IGMP socket");
		return -1;
	}
	
	/* set TTL */
	if (setsockopt(sock, IPPROTO_IP, IP_MULTICAST_TTL,
		       &ttl, sizeof(ttl)) < 0) {
		perror("setsockopt(MULTICAST_TTL)");
		close(sock);
		return -1;
	}

	/* fix interface */
	if (mciface.s_addr != 0 &&
	    setsockopt(sock, IPPROTO_IP, IP_MULTICAST_IF,
		       &mciface, sizeof(mciface)) < 0) {
		perror("setsockopt(MULTICAST_IF)");
		close(sock);
		return -1;
	}

	/* set router alert option */
	ra[0] = IPOPT_RA;
	ra[1] = 4;
	ra[2] = ra[3] = '\0';
	if (setsockopt(sock, IPPROTO_IP, IP_OPTIONS, &ra, sizeof(ra)) < 0) {
		perror("setsockopt(RA)");
		close(sock);
		return -1;
	}

	return sock;
}

void
IGMPInit(struct in_addr *iface, struct in_addr *mcaddr)
{
	/* build a prototype query packet */
	qpacket.igmp_type = IGMP_QUERY;
	qpacket.igmp_code = 0x64;
	memset(&qpacket.igmp_group, 0, sizeof(qpacket.igmp_group));
	qpacket.igmp_cksum = 0;
	qpacket.igmp_cksum = igmp_csum(&qpacket);

	/* sockaddr for queries */
	allhosts.sin_family = AF_INET;
	allhosts.sin_port = htons(0);
	allhosts.sin_addr.s_addr = htonl(INADDR_ALLHOSTS_GROUP);

	if (mcaddr != NULL) {
		/* build a prototype report packet */
		rpacket.igmp_type = IGMP_REPORT;
		rpacket.igmp_code = 0;
		rpacket.igmp_group = *mcaddr;
		rpacket.igmp_cksum = 0;
		rpacket.igmp_cksum = igmp_csum(&rpacket);

		/* sockaddr for reports */
		mcgroup.sin_family = AF_INET;
		mcgroup.sin_port = htons(0);
		mcgroup.sin_addr = *mcaddr;
	}

	/* remember the interface */
	if (iface != NULL)
		mciface = *iface;
	else
		mciface.s_addr = 0;
}

int
IGMPSendQuery(void)
{
	int rv, sock;

	if ((sock = igmp_opensocket()) < 0)
		return -1;

	rv = sendto(sock, &qpacket, sizeof(qpacket), 0,
		  (struct sockaddr *)&allhosts, sizeof(allhosts));
	if (rv < 0)
		perror("query sendto");
	close(sock);

	return (rv != sizeof(qpacket));
}

int
IGMPSendReport(void)
{
	int rv, sock;

	if (mcgroup.sin_addr.s_addr == 0)
		return 0;

	if ((sock = igmp_opensocket()) < 0)
		return -1;

	rv = sendto(sock, &rpacket, sizeof(rpacket), 0,
		    (struct sockaddr *)&mcgroup, sizeof(mcgroup));
	if (rv < 0)
		perror("report sendto");
	close(sock);

	return (rv != sizeof(rpacket));
}
#endif
