/*
 * Copyright (c) 2003-2016 University of Utah and the Flux Group.
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
 *
 */
#include <stdio.h>
#include <ctype.h>
#include <netdb.h>
#include <unistd.h>
#include <string.h>
#include <errno.h>
#include <time.h>
#include <math.h>
#include <paths.h>
#include <sys/types.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <pthread.h>
#include <signal.h>
#include "config.h"
#include "event.h"
#include "tbdefs.h"
#include "log.h"

static int debug = 0;
static int stop  = 0;
static event_handle_t localhandle;
static event_handle_t clusterhandle;
static char *MYURN = "urn:publicid:IDN+" OURDOMAIN "+authority+cm";

void
usage(char *progname)
{
    fprintf(stderr,
	    "Usage: %s [-s server] [-i pidfile]\n", progname);
    exit(-1);
}

static void
notify_callback(event_handle_t handle,
	 event_notification_t notification, void *data);

static void
sigterm(int sig)
{
	stop = 1;
}

int
main(int argc, char **argv)
{
	address_tuple_t		tuple;
	char			*progname;
	char			*server = NULL;
	char			*port = NULL;
	char			*pidfile = NULL;
	char			buf[BUFSIZ];
	int			c;
	FILE			*fp;

	progname = argv[0];
	
	while ((c = getopt(argc, argv, "ds:p:i:v:")) != -1) {
		switch (c) {
		case 'd':
			debug++;
			break;
		case 's':
			server = optarg;
			break;
		case 'p':
			port = optarg;
			break;
		case 'i':
			pidfile = optarg;
			break;
			break;
		case 'v':
			fprintf(stderr, "WARNING: -v option ignored\n");
			break;
		default:
			usage(progname);
		}
	}
	argc -= optind;
	argv += optind;

	if (argc)
		usage(progname);

	if (debug)
		loginit(0, 0);
	else {
		loginit(1, "evproxy");
		/* See below for daemonization */
	}

	/*
	 * If server is not specified, then it defaults to localhost.
	 */
	if (!server)
		server = "localhost";

	/*
	 * XXX Need to daemonize earlier or the threads go away.
	 */
	if (!debug && daemon(0, 0))
		fatal("could not daemonize");
	
	/*
	 * Convert server/port to elvin thing.
	 *
	 * XXX This elvin string stuff should be moved down a layer. 
	 */
	snprintf(buf, sizeof(buf), "elvin://%s%s%s",
		 server,
		 (port ? ":"  : ""),
		 (port ? port : ""));
	server = buf;

	/*
	 * Construct an address tuple for generating the event.
	 */
	tuple = address_tuple_alloc();
	if (tuple == NULL) {
		fatal("could not allocate an address tuple");
	}
	
	/* Register with the local clusterd */
	clusterhandle = event_register(server, 1);
	if (clusterhandle == NULL) {
		fatal("could not register with clusterd on %s", server);
	}

	/* Register with the event system on the local node */
	localhandle = event_register("elvin://localhost", 1);
	if (localhandle == NULL) {
		fatal("could not register with local event system");
	}
	
	/*
	 * We want all events from the local boss. 
	 */
	if (! event_subscribe(localhandle, notify_callback, tuple, NULL)) {
		fatal("could not subscribe to events on local server");
	}

	signal(SIGTERM, sigterm);

	/*
	 * Stash the pid away.
	 */
	if (!geteuid()) {
		if (! pidfile) {
			sprintf(buf, "%s/igeventproxy.pid", _PATH_VARRUN);
			pidfile = buf;
		}
		fp = fopen(pidfile, "w");
		if (fp != NULL) {
			fprintf(fp, "%d\n", getpid());
			(void) fclose(fp);
		}
	}

	/* Begin the event loop, waiting to receive event notifications */
	while (! stop) {
		struct timeval  tv = { 5, 0 };

		select(0, NULL, NULL, NULL, &tv);
	}
	unlink(pidfile);

	/* Unregister with the local clusterd: */
	if (event_unregister(clusterhandle) == 0) {
		fatal("could not unregister with local clusterd");
	}
	/* Unregister with the local event system: */
	if (event_unregister(localhandle) == 0) {
		fatal("could not unregister with local event system");
	}

	return 0;
}

/*
 * Handle incoming events from the local server. We filter/process and
 * and then send them to the local clusterd to forward on. 
 */
static void
notify_callback(event_handle_t handle,
		event_notification_t notification, void *data)
{
	char		site[TBDB_FLEN_EVEVENTSITE];
	char		expt[TBDB_FLEN_EVEVENTEXPT];

	event_notification_get_site(handle,
				    notification, site, sizeof(site));
	event_notification_get_expt(handle,
				    notification, expt, sizeof(expt));

	if (debug && site[0] && strcmp(site, ADDRESSTUPLE_ALL)) {
		info("%s %s\n", site, expt);
	}
	/*
	 * If the URN is set, then we forward the notification on, since it
	 * generated by a subsystem that knows what is going on. Otherwise,
	 * we want to look at what the notification is saying, and if it is
	 * something we want to forward, add in a site urn and send it.
	 */
	if (!site[0] || !strcmp(site, ADDRESSTUPLE_ALL)) {
		char	otype[TBDB_FLEN_EVEVENTTYPE];

		event_notification_get_objtype(handle,
				       notification, otype, sizeof(otype));

		if (debug) {
			info("T: %s\n", otype);
		}
		
		if (strcmp(otype, TBDB_OBJECTTYPE_STATE)) {
			return;
		}
		if (site[0]) {
			event_notification_clear_site(handle, notification);
		}
		event_notification_put_site(handle, notification, MYURN);
	}
	
	/*
	 * Resend the notification to the local clusterd
	 */
	if (! event_notify(clusterhandle, notification))
		error("Failed to deliver notification to local clusterd!");
}

