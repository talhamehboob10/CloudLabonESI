/*
 * Implement a couple of simple IGMP V2 messages.
 *
 * We can either send a general membership query (suitable for implementing
 * a simple IGMP querier) or a membership report.
 */
#include <inttypes.h>
#include <string.h>
#include <stdio.h>
#include <sys/types.h>
#include <sys/socket.h>
#include <netinet/in.h>
#ifdef WITH_IGMP
#include <netinet/ip.h>
#include <netinet/igmp.h>
#endif

#ifdef WITH_IGMP
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
	char ra[4];
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
#endif

void
IGMPInit(struct in_addr *iface, struct in_addr *mcaddr)
{
#ifdef WITH_IGMP
	/* build a prototype query packet */
	qpacket.igmp_type = IGMP_MEMBERSHIP_QUERY;
	qpacket.igmp_code = 0x64;
	memset(&qpacket.igmp_group, 0, sizeof(qpacket.igmp_group));
	qpacket.igmp_cksum = 0;
	qpacket.igmp_cksum = igmp_csum(&qpacket);

	/* sockaddr for queries */
	allhosts.sin_len = sizeof(allhosts);
	allhosts.sin_family = AF_INET;
	allhosts.sin_port = htons(0);
	allhosts.sin_addr.s_addr = htonl(INADDR_ALLHOSTS_GROUP);

	if (mcaddr != NULL) {
		/* build a prototype report packet */
		rpacket.igmp_type = IGMP_V2_MEMBERSHIP_REPORT;
		rpacket.igmp_code = 0;
		rpacket.igmp_group = *mcaddr;
		rpacket.igmp_cksum = 0;
		rpacket.igmp_cksum = igmp_csum(&rpacket);

		/* sockaddr for reports */
		mcgroup.sin_len = sizeof(mcgroup);
		mcgroup.sin_family = AF_INET;
		mcgroup.sin_port = htons(0);
		mcgroup.sin_addr = *mcaddr;
	}

	/* remember the interface */
	if (iface != NULL)
		mciface = *iface;
	else
		mciface.s_addr = 0;
#endif
}

int
IGMPSendQuery(void)
{
#ifdef WITH_IGMP
	int rv, sock;

	if ((sock = igmp_opensocket()) < 0)
		return -1;

	rv = sendto(sock, &qpacket, sizeof(qpacket), 0,
		  (struct sockaddr *)&allhosts, sizeof(allhosts));
	if (rv < 0)
		perror("query sendto");
	close(sock);

	return (rv != sizeof(qpacket));
#else
	FrisFatal("IGMPSendQuery not implemented");
#endif
}

int
IGMPSendReport(void)
{
#ifdef WITH_IGMP
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
#else
	FrisFatal("IGMPSendReport not implemented");
#endif
}

#if 0
#include <stdio.h>
#include <stdlib.h>
main(int argc, char **argv)
{
	struct in_addr addr, mcaddr;
	int i;

	if (argc < 2) {
		fprintf(stderr, "usage: %s <cnet-interface-IP>\n", argv[0]);
		exit(1);
	}
	inet_aton(argv[1], &addr);
	inet_aton("234.5.6.7", &mcaddr);

	printf("Testing querier (using iface %s)...\n", inet_ntoa(addr));
	IGMPInit(&addr, &mcaddr);

	printf("Sending a report for %s...\n", inet_ntoa(mcaddr));
	if (IGMPSendReport()) {
		printf("report send failed!\n");
		exit(1);
	}

	printf("Sending queries to %s...\n", inet_ntoa(allhosts.sin_addr));
	i = 10;
	while (i-- > 0) {
		if (IGMPSendQuery()) {
			printf("query send failed!\n");
			exit(1);
		}
		sleep(30);
	}

	exit(0);
}
#endif
