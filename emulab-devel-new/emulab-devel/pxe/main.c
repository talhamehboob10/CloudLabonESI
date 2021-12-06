/*
 * Copyright (c) 2000-2016, 2018 University of Utah and the Flux Group.
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

#include <sys/types.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <stdio.h>
#include <sys/param.h>
#include <paths.h>
#include <unistd.h>
#include <stdlib.h>
#include <string.h>
#include <signal.h>
#include <db.h>
#include <fcntl.h>
#include <time.h>
#include "config.h"
#include "log.h"
#include "tbdefs.h"
#include "bootwhat.h"
#include "bootinfo.h"

#ifdef LIBWRAP
#include <syslog.h>
#include <tcpd.h>
int allow_severity = LOG_TESTBED|LOG_INFO;
int deny_severity  = LOG_TESTBED|LOG_WARNING;
#endif

/*
 * Minimum number of seconds that must pass before we send another
 * event for a node. This is to decrease the number of spurious events
 * we get from nodes when bootinfo packets are lost. 
 */
#define MINEVENTTIME	10

static void	log_bootwhat(struct in_addr, boot_what_t *, int);
static void	onhup(int sig);
static char	*progname;
static char     pidfile[MAXPATHLEN];
int		noevents = 0;
int		debug = 0;

void
usage()
{
	fprintf(stderr,
		"Usage: %s <options> [-d]\n"
		"options:\n"
		"-E         - Do not send BOOTING events\n"
		"-d         - Turn on debugging\n"
		"-p port    - Specify port number to listen on\n"
		"-i address - Specify IP address to bind to\n",
		progname);
	exit(-1);
}

static void
cleanup()
{
	unlink(pidfile);
	exit(0);
}

int
main(int argc, char **argv)
{
	int			sock, mlen, err, c;
	struct sockaddr_in	name, client;
	struct in_addr          bindaddr;
	socklen_t		length;
	boot_info_t		boot_info;
	int		        port = BOOTWHAT_DSTPORT;
	FILE			*fp;
	extern char		build_info[];
	bindaddr.s_addr	= INADDR_ANY;
#ifdef ELABINELAB
	if (!inet_aton(BOSSNODE_IP, &bindaddr)) {
		fprintf(stderr, "Invalid bind IP '%s'\n", BOSSNODE_IP);
		exit(1);
	}
#endif
	progname = argv[0];

	while ((c = getopt(argc, argv, "Ep:dhvi:")) != -1) {
		switch (c) {
		case 'E':
			noevents = 1;
			break;
		case 'd':
			debug++;
			break;
		case 'p':
			port = atoi(optarg);
			break;
		case 'v':
		    	fprintf(stderr, "%s\n", build_info);
			exit(0);
			break;
		case 'i':
			if (!inet_aton(optarg, &bindaddr)) {
				fprintf(stderr, "Invalid bind IP '%s'\n",
					optarg);
				exit(1);
			}
			break;
		case 'h':
		case '?':
		default:
			usage();
		}
	}
	argc -= optind;
	argv += optind;

	if (argc)
		usage();

	if (debug) 
		loginit(0, 0);
	else {
		/* Become a daemon */
		daemon(0, 0);
		loginit(1, "bootinfo");
	}
	info("%s\n", build_info);

	signal(SIGTERM, cleanup);
	/*
	 * Write out a pidfile.
	 */
	sprintf(pidfile, "%s/bootinfo.pid", _PATH_VARRUN);
	fp = fopen(pidfile, "w");
	if (fp != NULL) {
		fprintf(fp, "%d\n", getpid());
		(void) fclose(fp);
	}

	err = bootinfo_init();
	if (err) {
		error("could not initialize bootinfo\n");
		exit(1);
	}
	/* Create socket from which to read. */
	sock = socket(AF_INET, SOCK_DGRAM, 0);
	if (sock < 0) {
		errorc("opening datagram socket");
		exit(1);
	}
	
	/* Create name. */
	name.sin_family = AF_INET;
	name.sin_addr.s_addr = bindaddr.s_addr;
	name.sin_port = htons((u_short) port);
	if (bind(sock, (struct sockaddr *) &name, sizeof(name))) {
		errorc("binding datagram socket");
		exit(1);
	}
	/* Find assigned port value and print it out. */
	length = sizeof(name);
	if (getsockname(sock, (struct sockaddr *) &name, &length)) {
		errorc("getting socket name");
		exit(1);
	}
	info("listening on port %d\n", ntohs(name.sin_port));

	signal(SIGHUP, onhup);
	while (1) {
		int esent = 0;
#ifdef LIBWRAP
		struct request_info req;
#endif
		if ((mlen = recvfrom(sock, &boot_info, sizeof(boot_info),
				     0, (struct sockaddr *)&client, &length))
		    < 0) {
			errorc("receiving datagram packet");
			exit(1);
		}
#ifdef LIBWRAP
		request_init(&req, RQ_DAEMON, "bootinfo",
			     RQ_CLIENT_SIN, (struct sockaddr *)&client, 0);
		sock_methods(&req);
		if (!hosts_access(&req)) {
			info("%s: request denied by tcp wrappers\n",
			     inet_ntoa(client.sin_addr));
			continue;
		}
#endif
		err = bootinfo(client.sin_addr, (char *) NULL,
			       &boot_info, (void *) NULL, noevents, &esent);
		if (err < 0)
			continue;
		if (boot_info.status == BISTAT_SUCCESS)
			log_bootwhat(client.sin_addr,
				     (boot_what_t *) &boot_info.data, esent);

		boot_info.opcode = BIOPCODE_BOOTWHAT_REPLY;
		
		client.sin_family = AF_INET;
		client.sin_port = htons(BOOTWHAT_SRCPORT);
		if (sendto(sock, (char *)&boot_info, sizeof(boot_info), 0,
			(struct sockaddr *)&client, sizeof(client)) < 0)
			errorc("sendto");
	}
	close(sock);
	close_bootinfo_db();
	info("daemon terminating\n");
	exit(0);
}

static void
onhup(int sig)
{
	int err;

	info("re-initializing configuration database\n");
	close_bootinfo_db();
	err = open_bootinfo_db();
	if (err) {
		error("Could not reopen database\n");
		exit(1);
	}
}

static void
log_bootwhat(struct in_addr ipaddr, boot_what_t *bootinfo, int esent)
{
	char infostr[48];

	snprintf(infostr, sizeof(infostr), "%s: REPLY(%d): ",
		 inet_ntoa(ipaddr), esent);
	switch (bootinfo->type) {
	case BIBOOTWHAT_TYPE_PART:
		info("%sboot from partition %d\n",
		     infostr,
		     bootinfo->what.partition);
		break;
	case BIBOOTWHAT_TYPE_DISKPART:
		info("%sboot from disk/partition 0x%x/%d\n",
		     infostr,
		     bootinfo->what.dp.disk,
		     bootinfo->what.dp.partition);
		break;
	case BIBOOTWHAT_TYPE_SYSID:
		info("%sboot from partition with sysid %d\n",
		     infostr,
		     bootinfo->what.sysid);
		break;
	case BIBOOTWHAT_TYPE_MB:
		info("%sboot multiboot image %s:%s\n",
		     infostr,
		     inet_ntoa(bootinfo->what.mb.tftp_ip),
		     bootinfo->what.mb.filename);
		break;
	case BIBOOTWHAT_TYPE_WAIT:
		info("%swait mode\n", infostr);
		break;
	case BIBOOTWHAT_TYPE_MFS:
		info("%sboot from mfs %s\n", infostr, bootinfo->what.mfs);
		break;
	case BIBOOTWHAT_TYPE_REBOOT:
		info("%sreboot (alternate PXE boot)\n", infostr);
		break;
	default:
		info("%sUNKNOWN (type=%d)\n", infostr, bootinfo->type);
		break;
	}
	if (bootinfo->cmdline[0]) {
		info("%scommand line: %s\n", infostr, bootinfo->cmdline);
	}
}

