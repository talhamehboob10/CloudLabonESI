/*
 * Copyright (c) 2002-2017 University of Utah and the Flux Group.
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
 * Testbed event system interface
 * Supports sending of periodic events.
 */

#ifdef EMULAB_EVENTS

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <netdb.h>
#include <unistd.h>
#include <sys/types.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <sys/time.h> 
#include <inttypes.h>

//#include "libtb/tbdefs.h"
#include "event/event.h"

#include "decls.h"
#include "log.h"
#include "event.h"

static event_handle_t	ehandle;
static address_tuple_t	tuple;
static char		*eserver;

static int
EventReinit(void)
{
	if (ehandle == NULL) {
		if (eserver == NULL)
			return 1;

		ehandle = event_register(eserver, 0);
		if (ehandle == NULL) {
			FrisWarning("could not register with event server %s",
				    eserver);
			return 1;
		}

		tuple = address_tuple_alloc();
		if (tuple == NULL) {
			FrisWarning("could not allocate an address tuple");
			EventDeinit();
			return 1;
		}
	}

	return 0;
}

int
EventInit(char *server)
{
	char buf[BUFSIZ];

	if (server == NULL) {
		FrisWarning("no event server specified");
		return 1;
	}

	/*
	 * Convert server/port to elvin thing.
	 */
	snprintf(buf, sizeof(buf), "elvin://%s", server);
	eserver = strdup(buf);

	return EventReinit();
}

void
EventDeinit(void)
{
	if (ehandle != NULL) {
		if (tuple != NULL) {
			address_tuple_free(tuple);
			tuple = NULL;
		}
		event_unregister(ehandle);
		ehandle = NULL;
	}
}

/*
 * Put a signed 32-bit int into a notification.
 *
 * XXX we actually encode these all as strings since our Perl SWIG wrappers
 * are broken for handling OUT reference params. This is easier than fixing
 * the SWIG code.
 */
static inline void
putint32(event_handle_t hand, event_notification_t note, char *key, uint32_t val)
{
	char valbuf[12];

	snprintf(valbuf, sizeof valbuf, "%"PRIu32, val);
	(void) event_notification_put_string(hand, note, key, valbuf);
}

int
EventSendClientReport(char *node, char *image, uint32_t tstamp, uint32_t seq,
		      ClientSummary_t *summary, ClientStats_t *stats)
{
	event_notification_t	notification;

	/*
	 * In case we got disconnected
	 */
	if (ehandle == NULL && EventReinit())
		return 1;

	tuple->host      = BOSSNODE;
	tuple->objtype   = "FRISBEESTATUS";
	tuple->objname   = node;
	tuple->eventtype = image;

	notification = event_notification_alloc(ehandle, tuple);
	if (notification == NULL) {
		FrisWarning("EventSend: unable to allocate notification!");
		return 1;
	}

	/*
	 * Insert interesting key/value pairs:
	 *
	 * Always:
	 *   TSTAMP:      int32, unix timestamp of report from client
	 *   SEQUENCE:    int32, sequence number of report
	 *
	 * From summary (if present):
	 *   CHUNKS_RECV:    int32, chunks successfully received by client
	 *   CHUNKS_DECOMP:  int32, chunks successfully decompressed
	 *   MBYTES_WRITTEN: int32, mebibytes written to disk
	 *
	 * From stats (if present):
	 *   nothing right now as client does not pass this.
	 */
	putint32(ehandle, notification, "TSTAMP", tstamp);
	putint32(ehandle, notification, "SEQUENCE", seq);
	if (summary != NULL) {
		putint32(ehandle, notification, "CHUNKS_RECV",
			 summary->chunks_in);
		putint32(ehandle, notification, "CHUNKS_DECOMP",
			 summary->chunks_out);
		putint32(ehandle, notification, "MBYTES_WRITTEN",
			 (uint32_t)(summary->bytes_out / (1024*1024)));
	}

	if (event_notify(ehandle, notification) == 0) {
		event_notification_free(ehandle, notification);

		/*
		 * Disconnect from the event system, so that we will
		 * try reconnecting next time around.
		 */
		EventDeinit();
		return 1;
	}

	event_notification_free(ehandle, notification);

	return 0;
}
#endif
