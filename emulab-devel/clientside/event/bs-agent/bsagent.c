/*
 * Copyright (c) 2000-2015 University of Utah and the Flux Group.
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
 * Simple event agent to listen for BSTORE STOP events and shutdown
 * remote blockstores.
 *
 * Based on linktest.c.
 */

#include <stdio.h>
#include <unistd.h>
#include <string.h>
#include <errno.h>
#include <paths.h>
#include "tbdefs.h"
#include "log.h"
#include "event.h"

static int	      debug;
static char           *pideid;
static event_handle_t handle;
static int32_t	      token = ~0;

static void	      callback(event_handle_t handle,
			       event_notification_t notification, void *data);
     
void
usage(char *progname)
{
	fprintf(stderr,
		"Usage: %s [-d] "
		"[-s server] [-p port] [-k keyfile] [-l logfile] -e pid/eid\n",
		progname);
	exit(-1);
}

int
main(int argc, char **argv) {

	address_tuple_t	tuple;
	char *server = "event-server";
	char *port = NULL;
	char *keyfile = NULL;
	char *logfile = NULL;
	char *progname;
	int c;
	char buf[BUFSIZ];
	pideid = NULL;
	
	progname = argv[0];

	while ((c = getopt(argc, argv, "s:p:e:l:dk:")) != -1) {
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
	  case 'e':
	    pideid = optarg;
	    break;
	  case 'l':
	    logfile = optarg;
	    break;
	  case 'k':
	    keyfile = optarg;
	    break;
	  default:
	    fprintf(stderr, "*** invalid argument '%c'\n", c);
	    usage(progname);
	  }
	}

	if (!pideid) {
	  fprintf(stderr, "*** must specify pid/eid\n");
	  usage(progname);
	}

	if (debug)
		loginit(0, 0);
	else {
		if (logfile)
			loginit(0, logfile);
		else
			loginit(1, "linktest");
		/* See below for daemonization */
	}

	/*
	 * Convert server/port to elvin thing.
	 *
	 * XXX This elvin string stuff should be moved down a layer. 
	 */
	if (server) {
		snprintf(buf, sizeof(buf), "elvin://%s%s%s",
			 server,
			 (port ? ":"  : ""),
			 (port ? port : ""));
		server = buf;
	}

	/*
	 * Construct an address tuple for subscribing to events for
	 * this node.
	 */
	tuple = address_tuple_alloc();
	if (tuple == NULL) {
		fatal("could not allocate an address tuple");
	}
	/*
	 * Ask for just the events we care about. 
	 */
	tuple->expt      = pideid;
	tuple->objtype   = TBDB_OBJECTTYPE_BSTORE;
	tuple->eventtype =
		TBDB_EVENTTYPE_START ","
		TBDB_EVENTTYPE_STOP ","
		TBDB_EVENTTYPE_KILL;

	/*
	 * Register with the event system. 
	 */
	handle = event_register_withkeyfile(server, 0, keyfile);
	if (handle == NULL) {
	        fatal("could not register with event system");
	}
	
	/*
	 * Subscribe to the event we specified above.
	 */
	if (! event_subscribe(handle, callback, tuple, NULL)) {
		fatal("could not subscribe to event");
	}

	/*
	 * Do this now, once we have had a chance to fail on the above
	 * event system calls.
	 */
	if (!debug)
		daemon(0, 1);

	/*
	 * Write out a pidfile if root (after we daemonize).
	 */
	if (!getuid()) {
		FILE *fp;
		
		sprintf(buf, "%s/bsagent.pid", _PATH_VARRUN);
		fp = fopen(buf, "w");
		if (fp != NULL) {
			fprintf(fp, "%d\n", getpid());
			(void) fclose(fp);
		}
	}

	/*
	 * Begin the event loop, waiting to receive event notifications:
	 */
	event_main(handle);

	/*
	 * Unregister with the event system:
	 */
	if (event_unregister(handle) == 0) {
		fatal("could not unregister with event system");
	}

	return 0;
}
/*
 * Handle the events.
 */
static void
callback(event_handle_t handle, event_notification_t notification, void *data)
{
	char		objname[TBDB_FLEN_EVOBJTYPE];
	char		event[TBDB_FLEN_EVEVENTTYPE];
	char		args[BUFSIZ];
	struct timeval	now;

	gettimeofday(&now, NULL);
	
	if (! event_notification_get_objname(handle, notification,
					     objname, sizeof(objname))) {
		error("Could not get objname from notification!\n");
		return;
	}

	if (! event_notification_get_eventtype(handle, notification,
					       event, sizeof(event))) {
		error("Could not get event from notification!\n");
		return;
	}

	event_notification_get_int32(handle, notification,
				     "TOKEN", &token);

	event_notification_get_arguments(handle,
					 notification, args, sizeof(args));

	info("event: %s - %s - %s\n", objname, event, args);

	if (strcasecmp(objname, "rem-bstore") != 0) {
		error("Only handle 'rem-bstore' blockstore events\n");
		return;
	}

	/*
	 * Dispatch the event. 
	 */
	if (!strcmp(event, TBDB_EVENTTYPE_START)) {
		if (system("sudo /usr/local/etc/emulab/rc/rc.storageremote boot")) {
			error("Start up of remote blockstores failed!\n");
		} else {
			info("Remote blockstores started\n");
		}
	}
	else if (!strcmp(event, TBDB_EVENTTYPE_STOP) ||
		 !strcmp(event, TBDB_EVENTTYPE_KILL)) {
		if (system("sudo /usr/local/etc/emulab/rc/rc.storageremote shutdown")) {
			error("Shutdown of remote blockstores failed!\n");
		} else {
			info("Remote blockstores shutdown\n");
		}
	}
}
