/* 
 * Copyright (c) 2000 The University of Utah and the Flux Group.
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
 *
 * ---------------------------
 *
 * Filename: cli.c
 *   -- Author: Kristin Wright <kwright@cs.utah.edu> 
 *
 * ---------------------------
 *
 * $Id: cli.c,v 1.9 2004-06-17 18:17:01 mike Exp $
 */

#include "discvr.h"
#include "packet.h"
#include "util.h"

extern u_char *mac_list[MAX_NODES];
extern int num_nodes;


u_char *
find_nodeID(void)
{
        int                     i;
	struct sockaddr         *sa;
	char                    *ptr;
	u_char                  *myNodeIDtmp = 0; 
  	struct ifi_info         *ifi, *ifihead;

	/* 
	 * Get interface info for all inet4 interfaces 
	 * and don't return aliases. 
	 */
	for (ifihead = ifi = get_ifi_info(AF_INET, 0); 
		 ifi != NULL; ifi = ifi->ifi_next) {

		printf("%s: <", ifi->ifi_name);
		if (ifi->ifi_flags & IFF_UP)		printf("UP ");
		if (ifi->ifi_flags & IFF_BROADCAST)	printf("BCAST ");
		if (ifi->ifi_flags & IFF_MULTICAST)	printf("MCAST ");
		if (ifi->ifi_flags & IFF_LOOPBACK)	printf("LOOP ");
		if (ifi->ifi_flags & IFF_POINTOPOINT)	printf("P2P ");
		printf(">\n");

		if ( (i = ifi->ifi_hlen) > 0) {
			ptr = ifi->ifi_haddr;
			do {
				printf("%s%x", (i == ifi->ifi_hlen) ? "  " : ":", *ptr++);
			} while (--i > 0);
			
		}

		/* 
		 * We update myNodeIDtmp in block separate from above 
		 * since the above is just a debug clause and may be
		 * compiled out eventually. -lkw
		 */
		 
		if ( ifi->ifi_hlen > 0) {
		        myNodeIDtmp = max_haddr(myNodeIDtmp, ifi->ifi_haddr);
		}

		if ( (sa = ifi->ifi_addr) != NULL)
			printf("  IP addr: %s\n", sock_ntop(sa, sa->sa_len));
		if ( (sa = ifi->ifi_brdaddr) != NULL)
			printf("  broadcast addr: %s\n", sock_ntop(sa, sa->sa_len));
		if ( (sa = ifi->ifi_dstaddr) != NULL)
			printf("  destination addr: %s\n", sock_ntop(sa, sa->sa_len));
	}

        fprintf(stderr, "My node id:");
	print_nodeID(myNodeIDtmp);

	return myNodeIDtmp;
}                            

void
make_inquiry(topd_inqid_t *tip, u_int16_t ttl, u_int16_t factor, int lans_exist) 
{
    struct timeval tv;
	u_char         *nid;

	/* First goes the the time of day... */
	if (gettimeofday(&tv, NULL) == -1) {
	        perror("Unable to get time-of-day.");
		exit(1);
	}

	tip->tdi_tv.tv_sec  = htonl(tv.tv_sec);
	tip->tdi_tv.tv_usec = htonl(tv.tv_usec);

	/* ...then the ttl and factor... */
	tip->tdi_ttl     = htons(ttl);
	tip->tdi_factor  = htons(factor);

	/* ...and now our nodeID */
	nid = find_nodeID();
	memcpy((void *)tip->tdi_nodeID, nid, ETHADDRSIZ);
	bzero(tip->tdi_p_nodeIF,ETHADDRSIZ);
	tip->lans_exist = htons(lans_exist);
}

void
cli(int sockfd, const struct sockaddr *pservaddr, socklen_t servlen, 
    u_int16_t ttl, u_int16_t factor, int lans_exist)
{
        u_int32_t         n;
	char              recvline[MAXLINE + 1];
	topd_inqid_t      ti;
	
	make_inquiry(&ti, ttl, factor, lans_exist);

	printf("sending query to server:\n");
	sendto(sockfd, &ti, TOPD_INQ_SIZ, 0, pservaddr, servlen);
	print_tdinq((char *)&ti);
	n = recvfrom(sockfd, recvline, MAXLINE, 0, NULL, NULL);
	fflush(stdin);
	printf("Receiving in client:==>\n");
	print_tdreply(recvline, n);
	gen_nam_file(recvline, n,"td1.nam");
	printf("Done!\n");
}

/*
 * Note that the TTL is a function of the network diameter that
 * we're interested in. The factor parameter is a function of the
 * network topology and performance.
 */ 
int
main(int argc, char **argv)
{
	int sockfd;
	struct sockaddr_in servaddr;

	if (argc != 5) {
		fprintf(stderr, "usage: cli <Server IPaddress> <TTL> <factor> <lan
				present?1/0>\n");
		exit(1);
	}

	bzero(&servaddr, sizeof(servaddr));
	servaddr.sin_family = AF_INET;
	servaddr.sin_port = htons(SERV_PORT);
	inet_pton(AF_INET, argv[1], &servaddr.sin_addr);

	sockfd = socket(AF_INET, SOCK_DGRAM, 0);

	//printf("calling client\n");
	cli(sockfd, (struct sockaddr *) &servaddr, sizeof(servaddr), atoi(argv[2]),
		atoi(argv[3]), atoi(argv[4]));

	exit(0);
}
