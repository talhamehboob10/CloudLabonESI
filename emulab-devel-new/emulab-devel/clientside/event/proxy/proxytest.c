/*
 * Copyright (c) 2003-2011 University of Utah and the Flux Group.
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
 * Test the proxy.
 */

#include <stdio.h>
#include <unistd.h>
#include <ctype.h>
#include <unistd.h>
#include <time.h>
#include <sys/time.h>
#include <sys/types.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include "event.h"
#include "tbdefs.h"
#include "log.h"

static char	*progname;
static int	debug = 0;

void
usage()
{
	fprintf(stderr,	"Usage: %s [-s server] [-p port]\n", progname);
	exit(-1);
}

static void
callback(event_handle_t handle,
	 event_notification_t notification, void *data);

int
main(int argc, char **argv)
{
	event_handle_t handle;
	address_tuple_t	tuple;
	char *server = "localhost";
	char *port = NULL;
	char buf[BUFSIZ];
	int c;
	
	progname = argv[0];
	
	while ((c = getopt(argc, argv, "s:p:d")) != -1) {
		switch (c) {
		case 'd':
			debug = 1;
			break;
		case 's':
			server = optarg;
			break;
		case 'p':
			port = optarg;
			break;
		default:
			usage();
		}
	}
	argc -= optind;
	argv += optind;

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
	 * Construct an address tuple for generating the event.
	 */
	tuple = address_tuple_alloc();
	if (tuple == NULL) {
		fatal("could not allocate an address tuple");
	}

	/* Register with the event system: */
	handle = event_register(server, 0);
	if (handle == NULL) {
		fatal("could not register with event system");
	}

	/* Subscribe to the test event: */
	if (! event_subscribe(handle, callback, tuple, "event received")) {
		fatal("could not subscribe to event");
	}

	/* Begin the event loop, waiting to receive event notifications: */
	event_main(handle);

	/* Unregister with the event system: */
	if (event_unregister(handle) == 0) {
		fatal("could not unregister with event system");
	}

	return 0;
}

/*
 * Handle Events
 */
static void
callback(event_handle_t handle, event_notification_t notification, void *data)
{
	char		eventtype[TBDB_FLEN_EVEVENTTYPE];
	char		objecttype[TBDB_FLEN_EVOBJTYPE];
	char		objectname[TBDB_FLEN_EVOBJNAME];
	struct timeval  now, then, diff;
	int32_t		sec, usec;
			
	gettimeofday(&now, NULL);

	event_notification_get_eventtype(handle,
				notification, eventtype, sizeof(eventtype));
	event_notification_get_objtype(handle,
				notification, objecttype, sizeof(objecttype));
	event_notification_get_objname(handle,
				notification, objectname, sizeof(objectname));
	event_notification_get_int32(handle, notification, "time_usec", &usec);
	event_notification_get_int32(handle, notification, "time_sec", &sec);
	then.tv_sec = sec;
	then.tv_usec = usec;
	timersub(&now, &then, &diff);

	info("%s %s %s %d %d %d %d %d %d\n", eventtype, objecttype,
	     objectname, now.tv_sec, now.tv_usec, then.tv_sec, then.tv_usec,
	     diff.tv_sec, diff.tv_usec);
}
