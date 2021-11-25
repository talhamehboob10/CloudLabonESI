/*
 * Copyright (c) 2000-2016, 2019 University of Utah and the Flux Group.
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
#include <fcntl.h>
#include <stdio.h>
#include <paths.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <syslog.h>
#include <assert.h>
#include <stdarg.h>
#include <errno.h>
#include <mysql/mysql.h>
#include <sys/time.h>
#include <signal.h>
#include <grp.h>
#include <netdb.h>
#include "capdecls.h"
#include "config.h"
#include "tbdb.h"

#define TESTMODE

static int	debug = 0;
static int	portnum = SERVERPORT;
static gid_t	admingid;
char		*Pidname;
void		sigterm(int);
void		cleanup(void);

static struct server {
	char *name;
	struct in_addr ip;
} *servers;
static int nservers; 

int regexinit(void);
int validwhoami(whoami_t *wai, int verbose);

char *usagestr = 
 "usage: capserver [-d] [-p #]\n"
 " -d              Turn on debugging.\n"
 " -p portnum	   Specify a port number to listen on.\n"
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
	MYSQL_RES		*res;	
	MYSQL_ROW		row;
	int			tcpsock, ch;
	int			i, nrows;
	unsigned int		length;
	struct sockaddr_in	name;
	struct in_addr		bossaddr;
	struct timeval		timeout;
	struct group		*group;
	struct sigaction	sa;
	sigset_t		actionsigmask;

	while ((ch = getopt(argc, argv, "dp:")) != -1)
		switch(ch) {
		case 'p':
			portnum = atoi(optarg);
			break;
		case 'd':
			debug++;
			break;
		case 'h':
		case '?':
		default:
			usage();
		}
	argc -= optind;
	argv += optind;

	if (argc)
		usage();

	openlog("capserver", LOG_PID, LOG_TESTBED);
	syslog(LOG_NOTICE, "daemon starting");

	if (!dbinit()) {
		syslog(LOG_ERR, "Could not connect to DB!");
		exit(1);
	}

	if (!regexinit()) {
		syslog(LOG_ERR, "Cannot compile REs!");
		exit(1);
	}

	sigemptyset(&actionsigmask);
	sigaddset(&actionsigmask, SIGINT);
	sigaddset(&actionsigmask, SIGTERM);
	memset(&sa, 0, sizeof sa);
	sa.sa_handler = sigterm;
	sa.sa_mask = actionsigmask;
	sigaction(SIGINT, &sa, NULL);
	sigaction(SIGTERM, &sa, NULL);

	inet_aton(BOSSNODE_IP, &bossaddr);

	/*
	 * Grab the GID for the default group.
	 */
	if ((group = getgrnam(TBADMINGROUP)) == NULL) {
		syslog(LOG_ERR, "Getting GID for %s", TBADMINGROUP);
		exit(1);
	}
	admingid = group->gr_gid;

	/*
	 * Find all the allowed tipserver machines and resolve their names.
	 */
	res = mydb_query("select server from tipservers", 1);
	if (!res) {
		syslog(LOG_ERR, "DB Error getting tipservers from DB!");
		exit(1);
	}
	if ((nrows = (int)mysql_num_rows(res)) == 0) {
		syslog(LOG_ERR, "No tipservers in DB!");
		mysql_free_result(res);
		exit(1);
	}

	servers = calloc(nrows, sizeof(struct sockaddr_in));
	if (servers == NULL) {
		syslog(LOG_ERR, "No memory for %d tipservers!", nrows);
		mysql_free_result(res);
		exit(1);
	}

	nservers = 0;
	while (nrows > 0) {
		struct hostent *he;

		nrows--;
		row = mysql_fetch_row(res);
		if ((he = gethostbyname(row[0])) == NULL) {
			syslog(LOG_WARNING,
			       "Could not resolve hostname '%s', ignored",
			       row[0]);
			continue;
		}
		if (he->h_addrtype != AF_INET ||
		    he->h_length != sizeof(struct in_addr)) {
			syslog(LOG_WARNING,
			       "Unknown addrtype/size for '%s', ignored",
			       row[0]);
			continue;
		}
		servers[nservers].name = strdup(row[0]);
		servers[nservers].ip = *(struct in_addr *)he->h_addr;
		nservers++;
	}
	mysql_free_result(res);

	/*
	 * Setup TCP socket
	 */

	/* Create socket from which to read. */
	tcpsock = socket(AF_INET, SOCK_STREAM, 0);
	if (tcpsock < 0) {
		syslog(LOG_ERR, "opening stream socket: %m");
		exit(1);
	}

	i = 1;
	if (setsockopt(tcpsock, SOL_SOCKET, SO_REUSEADDR,
		       (char *)&i, sizeof(i)) < 0)
		syslog(LOG_ERR, "control setsockopt: %m");;
	
	/* Create name. */
	name.sin_family = AF_INET;
	name.sin_addr.s_addr = INADDR_ANY;
	name.sin_port = htons((u_short) portnum);
	if (bind(tcpsock, (struct sockaddr *) &name, sizeof(name))) {
		syslog(LOG_ERR, "binding stream socket: %m");
		exit(1);
	}
	/* Find assigned port value and print it out. */
	length = sizeof(name);
	if (getsockname(tcpsock, (struct sockaddr *) &name, &length)) {
		syslog(LOG_ERR, "getting socket name: %m");
		exit(1);
	}
	if (listen(tcpsock, 40) < 0) {
		syslog(LOG_ERR, "listening on socket: %m");
		exit(1);
	}
	syslog(LOG_NOTICE, "listening on TCP port %d", ntohs(name.sin_port));

	if (!debug)
		(void)daemon(0, 0);

	if (!getuid()) {
		FILE	*fp;
		char    mybuf[BUFSIZ];
	    
		sprintf(mybuf, "%s/capserver.pid", _PATH_VARRUN);
		fp = fopen(mybuf, "w");
		if (fp != NULL) {
			fprintf(fp, "%d\n", getpid());
			(void) fclose(fp);
			Pidname = strdup(mybuf);
		}
	}

	while (1) {
		struct sockaddr_in client;
		int		   clientsock;
		int		   cc, port, srv;
		whoami_t	   whoami;
		char		   node_id[64], *server = "";
		tipowner_t	   tipown;
		void		  *reply = &tipown;
		size_t		   reply_size = sizeof(tipown);

		length = sizeof(client);
		if ((clientsock = accept(tcpsock,
					 (struct sockaddr *)&client,
					 &length)) < 0) {
			if (errno == ECONNABORTED) {
				syslog(LOG_ERR, "accept failed: %m; "
				       "continuing");
				continue;
			}
			syslog(LOG_ERR, "accept failed: %m; exiting");
			exit(1);
		}
		port = ntohs(client.sin_port);
		syslog(LOG_INFO, "%s connected from port %d",
		       inet_ntoa(client.sin_addr), port);

		/*
		 * Check IP address of server. Must be in tipservers table.
		 */
		if (client.sin_addr.s_addr == bossaddr.s_addr) {
			server = BOSSNODE;
		}
		else {
			for (srv = 0; srv < nservers; srv++)
				if (client.sin_addr.s_addr ==
				    servers[srv].ip.s_addr) {
					server = servers[srv].name;
					break;
				}
			if (srv == nservers) {
				syslog(LOG_ERR, "%s: Illegal server ignored.",
				       inet_ntoa(client.sin_addr));
				goto done;
			}
		}

		/*
		 * Check port number of sender. Must be a reserved port.
		 */
		if (port >= IPPORT_RESERVED || port < IPPORT_RESERVED / 2) {
			syslog(LOG_ERR, "%s: Illegal port %d Ignoring.",
			       inet_ntoa(client.sin_addr), port);
			goto done;
		}

		/*
		 * Set timeouts
		 */
		timeout.tv_sec  = 6;
		timeout.tv_usec = 0;
		
		if (setsockopt(clientsock, SOL_SOCKET, SO_RCVTIMEO,
			       &timeout, sizeof(timeout)) < 0) {
			syslog(LOG_ERR, "SO_RCVTIMEO failed: %m");
			goto done;
		}
		if (setsockopt(clientsock, SOL_SOCKET, SO_SNDTIMEO,
			       &timeout, sizeof(timeout)) < 0) {
			syslog(LOG_ERR, "SO_SNDTIMEO failed: %m");
			goto done;
		}
		
		/*
		 * Read and validate the whoami info.
		 */
		if ((cc = read(clientsock, &whoami, sizeof(whoami))) <= 0) {
			if (cc < 0)
				syslog(LOG_ERR, "Reading request: %m");
			syslog(LOG_ERR, "%s: Connection aborted (read)",
			       inet_ntoa(client.sin_addr));
			goto done;
		}
		if (cc != sizeof(whoami)) {
			syslog(LOG_ERR, "%s: Wrong byte count (read)!",
			       inet_ntoa(client.sin_addr));
			goto done;
		}
		if (!validwhoami(&whoami, debug)) {
			syslog(LOG_ERR, "%s: Invalid whoami info ignored",
			       inet_ntoa(client.sin_addr));
			goto done;
		}

		/*
		 * Make sure there is an entry for this tipline in
		 * the DB. If not, we just drop the info with an error
		 * message in the log file. Local tip will still work but
		 * remote tip will not.
		 */
		res = mydb_query("select server,node_id,portnum from tiplines "
				 "where tipname='%s'",
				 3, whoami.name);
		if (!res) {
			syslog(LOG_ERR, "DB Error getting tiplines for %s!",
			       whoami.name);
			goto done;
		}
		if ((int)mysql_num_rows(res) == 0) {
			syslog(LOG_ERR, "%s: No tipline info for %s!",
			       inet_ntoa(client.sin_addr), whoami.name);
			mysql_free_result(res);
			goto done;
		}
		row = mysql_fetch_row(res);
		if (strcmp(row[0], server) != 0) {
			syslog(LOG_WARNING,
			       "%s: caller ('%s') is not the right server "
			       "('%s') for node '%s'",
			       inet_ntoa(client.sin_addr), server,
			       row[0], row[1]);
		}
		strcpy(node_id, row[1]);
		port = -1;
		sscanf(row[2], "%d", &port);
		mysql_free_result(res);

		/*
		 * Figure out current owner. Might not be a reserved node,
		 * in which case set it to root/wheel by default. 
		 */
		res = mydb_query("select g.unix_gid from reserved as r "
				 "left join experiments as e on "
				 " r.pid=e.pid and r.eid=e.eid "
				 "left join groups as g on "
				 " g.pid=e.pid and g.gid=e.gid "
				 "where r.node_id='%s'",
				 1, node_id);

		if (!res) {
			syslog(LOG_ERR, "DB Error getting info for %s/%s!",
			       node_id, whoami.name);
			goto done;
		}
		if ((int)mysql_num_rows(res)) {
			row = mysql_fetch_row(res);

			tipown.uid = 0;
			if (row[0])
				tipown.gid = atoi(row[0]);
			else
				tipown.gid = admingid;
		}
		else {
			/*
			 * Default to root/root.
			 */
			tipown.uid = 0;
			tipown.gid = admingid;
		}
		mysql_free_result(res);

		if (whoami.portnum == -1) {
			reply = &port;
			reply_size = sizeof(port);
		}
		/*
		 * Update the DB.
		 */
		else if (! mydb_update("update tiplines set portnum=%d, "
				       "keylen=%d, keydata='%s' "
				       "where tipname='%s'", 
				       whoami.portnum,
				       whoami.key.keylen, whoami.key.key,
				       whoami.name)) {
			syslog(LOG_ERR, "DB Error updating tiplines for %s!",
			       whoami.name);
			goto done;
		}

		/*
		 * And now send the reply.
		 */
		if ((cc = write(clientsock, reply, reply_size)) <= 0) {
			if (cc < 0)
				syslog(LOG_ERR, "Writing reply: %m");
			syslog(LOG_ERR, "Connection aborted (write)");
			goto done;
		}
		if (cc != reply_size) {
			syslog(LOG_ERR, "Wrong byte count (write)!");
			goto done;
		}

		syslog(LOG_INFO,
		       "Tipline %s/%s, Port %d, Keylen %d, Key %s, Group %d\n",
		       node_id, whoami.name, whoami.portnum,
		       whoami.key.keylen, whoami.key.key, tipown.gid);
	done:
		close(clientsock);
	}
	close(tcpsock);
	syslog(LOG_NOTICE, "daemon terminating");
	cleanup();
	exit(0);
}

void
sigterm(int sig)
{
	cleanup();
	exit(0);
}

void
cleanup(void)
{
	syslog(LOG_NOTICE, "daemon exiting by signal");

	if (Pidname)
	    (void) unlink(Pidname);
}

#include <regex.h>
static regex_t re_nodeid, re_keystr;

int
regexinit(void)
{
	/* XXX get these from DB */
	if (regcomp(&re_nodeid, "^[-[:alnum:]_]+$",
		    REG_EXTENDED|REG_ICASE|REG_NOSUB))
		return 0;
	if (regcomp(&re_keystr, "^[0-9a-f]+$",
		    REG_EXTENDED|REG_ICASE|REG_NOSUB))
		return 0;

	return 1;
}

int
validwhoami(whoami_t *wai, int verbose)
{
	wai->name[sizeof(wai->name)-1] = '\0';
	if (regexec(&re_nodeid, wai->name, 0, NULL, 0)) {
		if (verbose)
			syslog(LOG_ERR, "Invalid node name string");
		return 0;
	}
	if (wai->portnum != -1 && (wai->portnum < 1 || wai->portnum > 65535)) {
		if (verbose)
			syslog(LOG_ERR, "Invalid port number");
		return 0;
	}
	if (wai->key.keylen < 0 || wai->key.keylen >= sizeof(wai->key.key)) {
		if (verbose)
			syslog(LOG_ERR, "Invalid key length");
		return 0;
	}
	wai->key.key[wai->key.keylen] = '\0';
	if (regexec(&re_keystr, wai->key.key, 0, NULL, 0)) {
		if (verbose)
			syslog(LOG_ERR, "Invalid key string");
		return 0;
	}

	return 1;
}
