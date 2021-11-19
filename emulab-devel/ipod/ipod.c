/*
 * Copyright (c) 2000-2013 University of Utah and the Flux Group.
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
 *  Send the magical ping of death ICMP type
 */


#include <time.h>
#include <sys/time.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <sys/types.h>
#include <sys/param.h>
#include <sys/socket.h>
#include <fcntl.h>
#include <netdb.h>
#include <netinet/in.h>
#include <netinet/in_systm.h>
#include <netinet/ip.h>
#include <netinet/ip_icmp.h>
#include <errno.h>
#include <string.h>
#include <signal.h>
#include <arpa/inet.h>

#define IPOD_ICMPTYPE	6
#define IPOD_ICMPCODE	6
#define IPOD_IPLEN	666
#define IPOD_IDLEN	32

int icmpid = 0;
static char myid[IPOD_IDLEN];
static int myidlen = 0;

u_short in_cksum(u_short *addr, int len);
void icmpmap_init();  /* For getting information */
void icmp_info(struct icmp *icmp, char *outbuf, int maxlen);

/*
 * We perform lookups on the hosts, and then store them in a chain
 * here.
 */

struct hostdesc {
	char *hostname;
	struct in_addr hostaddr;
	struct in_addr srcaddr;
	struct hostdesc *next;
	int s;
};
int use_hdrincl = 0;
int get_icmp_socket();

struct hostdesc *hostnames;
struct hostdesc *hosttail;

/*
 * Set up the list of hosts.  Return the count.
 */

int makehosts(char **hostlist, struct in_addr srcaddr)
{
	int i;
	struct hostent *hp;
	struct in_addr tmpaddr;
	int hostcount = 0;
	
	for (i = 0; hostlist[i]; i++) {
#ifdef DEBUG
		printf("Resolving %s\n", hostlist[i]);
#endif
		if (!hostlist[i] ||
		    !hostlist[i][0] ||
		    strlen(hostlist[i]) > MAXHOSTNAMELEN) {
		    fprintf(stderr, "bad host entry, exiting\n");
		    exit(-1);
		}
		if (!inet_aton(hostlist[i], &tmpaddr)) {
			if ((hp = gethostbyname(hostlist[i])) == NULL) {
				/* Could not resolve it.  Skip it. */
				fprintf(stderr, "%s: unknown host\n",
					hostlist[i]);
				continue;
			}
			else {
				memcpy(&tmpaddr.s_addr,
				       hp->h_addr_list[0],
				       hp->h_length);
			}
		}

		/* The host has been resolved.  Put it in the chain */
		/* We want to stick it on the end. */
		if (hostnames == NULL) {
			hostnames = (struct hostdesc *)
				malloc(sizeof(*hostnames));
			if (hostnames == NULL) {
				perror("hostnames malloc failed");
				exit(-1);
			}
			hosttail = hostnames;
		} else {
			hosttail->next = (struct hostdesc *)
				malloc(sizeof(*hostnames));
			if (hosttail->next == NULL) {
				perror("hosttail->next malloc failed");
				exit(-1);
			}
			hosttail = hosttail->next;
		}
		hosttail->hostname = strdup(hostlist[i]);
		if (hosttail->hostname == NULL) {
			perror("strdup failed");
			exit(-1);
		}
		hosttail->hostaddr = tmpaddr;
		hosttail->next = NULL;
		hosttail->srcaddr = srcaddr;
		hosttail->s = get_icmp_socket();
		hostcount++;
	}
	return hostcount;
}

void usage(char *prog)
{
   fprintf(stderr,
	   "%s [ -s src ] [ -i hashfile ] [-h hash ] target [ target ... ]\n",
	   prog);
}

/*
 * Set up a packet.  Returns the length of the ICMP portion.
 */

void initpacket(char *buf, int querytype, struct in_addr fromaddr)
{
   struct ip *ip = (struct ip *)buf;
   struct icmp *icmp = (struct icmp *)(ip + 1);

   /* things we customize */
   int icmplen = 0;

   ip->ip_src = fromaddr;	/* if 0,  have kernel fill in */
   ip->ip_v   = 4;		/* Always use ipv4 for now */
   ip->ip_hl  = sizeof *ip >> 2;
   ip->ip_tos = 0;
   ip->ip_id  = htons(4321);
   ip->ip_ttl = 255;
   ip->ip_p   = 1;
   ip->ip_sum = 0;                 /* kernel fills in */

   icmp->icmp_seq   = 1;
   icmp->icmp_cksum = 0;           /* We'll compute it later. */
   icmp->icmp_type  = querytype; 
   icmp->icmp_code  = IPOD_ICMPCODE;
   if (myidlen)
      memcpy(icmp->icmp_data, myid, myidlen);

   ip->ip_len = IPOD_IPLEN;
   icmplen = IPOD_IPLEN - sizeof(struct ip);
   icmp->icmp_cksum = in_cksum((u_short *)icmp, icmplen);
}

/*
 * Send all of the ICMP queries.
 */

void sendpings(int querytype, struct hostdesc *head, int delay,
	       struct in_addr fromaddr)
     
{
	char buf[1500];
	struct ip *ip = (struct ip *)buf;
	size_t len = IPOD_IPLEN;
	char *bufp = buf;

	bzero(buf, 1500);
	initpacket(buf, querytype, fromaddr);
	if (use_hdrincl == 0) {
	    bufp += sizeof(*ip);
	    len -= sizeof(*ip);
	}

	while (head != NULL) {
		int rc;
#ifdef DEBUG
		printf("pinging %s\n", head->hostname);
#endif
		ip->ip_dst.s_addr = head->hostaddr.s_addr;
		rc = send(head->s, bufp, len, 0);
                if (rc != len) {
			perror("send");
		}
		/* Don't flood small pipes. */
		if (delay)
			usleep(delay);
		head = head->next;
	}
}

/*
 * Handles our timeout for us.  Called by the signal handler
 * when we get a SIGARLM.
 */

void myexit(int whatsig)
{
	exit(0);
}

void sockaddr_from_ip(struct sockaddr_in *sin, struct in_addr ipaddr) {
    bzero(sin, sizeof(*sin));
    sin->sin_len = sizeof(*sin);
    sin->sin_family = AF_INET;
    sin->sin_addr = ipaddr;
}

/*
 * Open a raw socket for receiving ICMP.  Tell the kernel we want
 * to supply the IP headers.
 */

int get_icmp_socket()
{
	int s;
	int on = 1;
	struct sockaddr_in src, dst;
	if ((s = socket(AF_INET, SOCK_RAW, IPPROTO_ICMP)) < 0) {
		perror("socket");
		exit(1);
	}
	if (use_hdrincl && setsockopt(s, IPPROTO_IP, IP_HDRINCL,
		       (const char *)&on, sizeof(on)) < 0) {
		perror("IP_HDRINCL");
		exit(1);
	}
	if (*(u_int32_t *)(&hosttail->srcaddr)) {
	    sockaddr_from_ip(&src, hosttail->srcaddr);
	    if (bind(s, (const struct sockaddr *)&src, sizeof(src)) < 0) {
		perror("bind");
		exit(1);
	    }
	}
	sockaddr_from_ip(&dst, hosttail->hostaddr);
	if (connect(s, (const struct sockaddr *)&dst, sizeof(dst)) < 0) {
	    perror("connect");
	    exit(1);
	}
	return s;
}

int
main(int argc, char **argv)
{
   int s;

   char *progname;
   extern char *optarg;         /* getopt variable declarations */
   extern int optind;
   char ch;                     /* Holds the getopt result */
   int hostcount;
   int delay = 0;
   int querytype = ICMP_TSTAMP;
   struct in_addr fromaddr;
   int timeout = 5;  /* Default to 5 seconds */
   int identityfile;
   char *fromname = NULL;

   progname = argv[0];

   querytype = IPOD_ICMPTYPE;  /* the magical death packet number */

   while ((ch = getopt(argc, argv, "s:i:h:")) != -1)
      switch(ch)
      {
      case 's':
	  fromname = optarg;
	  break;
      case 'i':
	 if (optarg[0] == '-')
	    identityfile = 0;
	 else if ((identityfile = open(optarg, 0)) < 0)
	 {
	    perror(optarg);
	    exit(1);
	 }
	 myidlen = read(identityfile, myid, IPOD_IDLEN);
	 if (optarg[0] != '-')
	    close(identityfile);
         if (myidlen != IPOD_IDLEN)
	 {
	    fprintf(stderr, "%s: cannot read %d-byte identity\n",
		    optarg[0] != '-' ? optarg : "<stdin>", IPOD_IDLEN);
	    exit(2);
	 }
         break;
      case 'h':
	 myidlen = strlen(optarg);
         if (myidlen != IPOD_IDLEN) {
	    fprintf(stderr, "-h: identity hash must be %d bytes\n",
		    IPOD_IDLEN);
	    exit(2);
	 }
	 memcpy(myid, optarg, IPOD_IDLEN);
	 break;
      default:
         usage(progname);
	 exit(-1);
      }

   argc -= optind;
   argv += optind;
   if (!argv[0] || !strlen(argv[0])) 
   {
      usage(progname);
      exit(-1);
   }

   bzero(&fromaddr, sizeof(fromaddr));
   if (fromname) {
       if (!inet_aton(fromname, &fromaddr)) {
	   struct hostent *hp;
	   if ((hp = gethostbyname(fromname)) == NULL) {
	       /* Could not resolve it.  Skip it. */
	       fprintf(stderr, "%s: unknown host\n",
		       fromname);
	       exit(-1);
	   }
	   else {
	       memcpy(&fromaddr.s_addr,
		      hp->h_addr_list[0],
		      hp->h_length);
	   }
       }
   }
   hostcount = makehosts(argv, fromaddr);

   signal(SIGALRM, myexit);
   alarm(timeout);
   sendpings(querytype, hostnames, delay, fromaddr);
   exit(0);
}
   
/*
 * in_cksum --
 *	Checksum routine for Internet Protocol family headers (C Version)
 *      From FreeBSD's ping.c
 */

u_short
in_cksum(addr, len)
	u_short *addr;
	int len;
{
	register int nleft = len;
	register u_short *w = addr;
	register int sum = 0;
	u_short answer = 0;

	/*
	 * Our algorithm is simple, using a 32 bit accumulator (sum), we add
	 * sequential 16 bit words to it, and at the end, fold back all the
	 * carry bits from the top 16 bits into the lower 16 bits.
	 */
	while (nleft > 1)  {
		sum += *w++;
		nleft -= 2;
	}

	/* mop up an odd byte, if necessary */
	if (nleft == 1) {
		*(u_char *)(&answer) = *(u_char *)w ;
		sum += answer;
	}

	/* add back carry outs from top 16 bits to low 16 bits */
	sum = (sum >> 16) + (sum & 0xffff);	/* add hi 16 to low 16 */
	sum += (sum >> 16);			/* add carry */
	answer = ~sum;				/* truncate to 16 bits */
	return(answer);
}

