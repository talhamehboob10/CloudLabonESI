/*
 * Copyright (c) 2000-2016 University of Utah and the Flux Group.
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
#include <paths.h>
#include <unistd.h>
#include <stdlib.h>
#include <string.h>
#include <signal.h>
#include <db.h>
#include <fcntl.h>
#include <time.h>
#include "log.h"
#include "tbdefs.h"
#include "bootwhat.h"
#include "bootinfo.h"

/*
 * Minimum number of seconds that must pass before we send another
 * event for a node. This is to decrease the number of spurious events
 * we get from nodes when bootinfo packets are lost. 
 */
#define MINEVENTTIME	10

static int	bicache_init(void);
#ifdef	EVENTSYS
static int	bicache_needevent(struct in_addr ipaddr);
#ifdef __clang__
__attribute__((unused)) /* Suppress warning */
#endif
static void	bicache_clearevent(struct in_addr ipaddr);
#endif

int
bootinfo_init(void)
{
	int	err;
	
	/* Initialize data base */
	err = open_bootinfo_db();
	if (err) {
		error("could not open database\n");
		return -1;
	}
	err = bicache_init();
	if (err) {
		error("could not initialize cache\n");
		return -1;
	}
#ifdef EVENTSYS
	err = bievent_init();
	if (err) {
		error("could not initialize event system\n");
		return -1;
	}
#endif
	return 0;
}

int
bootinfo(struct in_addr ipaddr, char *node_id, struct boot_info *boot_info, 
	 void *opaque, int no_event_send, int *event_sent)
{
	boot_what_t	*boot_whatp = (boot_what_t *) &boot_info->data;
	int		err;
#ifdef	EVENTSYS
	int		needevent = 0, eventfailed = 0;
	int		doevents = 0, no_boot_event_send = no_event_send;

	/*
	 * We are not going to send any events for nodes we don't know about,
	 * or PXEBOOTING/BOOTING events for "pxelinux" nodes.
	 */
	if (!findnode_bootinfo_db(ipaddr, &doevents))
		no_boot_event_send = no_event_send = 1;
	else if (!no_event_send)
		no_boot_event_send = doevents ? 0 : 1;
#endif

	switch (boot_info->opcode) {
	case BIOPCODE_BOOTWHAT_KEYED_REQUEST:
		info("%s: KEYED REQUEST (key=[%s], vers %d)\n",
			inet_ntoa(ipaddr), boot_info->data, boot_info->version);
#ifdef	EVENTSYS
		if (!no_event_send) {
			needevent = bicache_needevent(ipaddr);
#if defined(BOOTINFO_PXEEVENTS)
			if (!no_boot_event_send && needevent &&
			    bievent_send(ipaddr, opaque,
					 TBDB_NODESTATE_PXEBOOTING)) {
				/* send failed, clear the cache entry */
				bicache_clearevent(ipaddr);
				eventfailed = 1;
			}
#endif
		}
#endif
		err = query_bootinfo_db(ipaddr, node_id, boot_info->version, 
					boot_whatp, boot_info->data);
		break;
	case BIOPCODE_BOOTWHAT_REQUEST:
	case BIOPCODE_BOOTWHAT_INFO:
		info("%s: REQUEST (vers %d)\n",
		     inet_ntoa(ipaddr), boot_info->version);
#ifdef	EVENTSYS
		if (!no_event_send) {
			needevent = bicache_needevent(ipaddr);
#if defined(BOOTINFO_PXEEVENTS)
			if (!no_boot_event_send && needevent &&
			    bievent_send(ipaddr, opaque,
					 TBDB_NODESTATE_PXEBOOTING)) {
				/* send failed, clear the cache entry */
				bicache_clearevent(ipaddr);
				eventfailed = 1;
			}
#endif
		}
#endif
		err = query_bootinfo_db(ipaddr, node_id,
					boot_info->version, boot_whatp, NULL);
		break;

	default:
		info("%s: invalid packet %d\n",
		     inet_ntoa(ipaddr), boot_info->opcode);
#ifdef	EVENTSYS
		if (event_sent)
			*event_sent = 0;
#endif
		return -1;
	}
	if (err)
		boot_info->status = BISTAT_FAIL;
	else {
		boot_info->status = BISTAT_SUCCESS;
#ifdef	EVENTSYS
		if (needevent) {
			/*
			 * Retry a failed PXEBOOTING event.
			 *
			 * Chances are, a failure here will amplify down
			 * the road as stated gets out of sync. So pause
			 * here and try to stay on track.
			 */
			if (!no_boot_event_send && eventfailed) {
				sleep(1);
				info("%s: retry failed PXEBOOTING event\n",
				     inet_ntoa(ipaddr));
				bicache_needevent(ipaddr);
#if defined(BOOTINFO_PXEEVENTS)
				if (bievent_send(ipaddr, opaque,
						 TBDB_NODESTATE_PXEBOOTING))
					bicache_clearevent(ipaddr);
#endif
			}
			switch (boot_whatp->type) {
			case BIBOOTWHAT_TYPE_PART:
			case BIBOOTWHAT_TYPE_DISKPART:
			case BIBOOTWHAT_TYPE_SYSID:
			case BIBOOTWHAT_TYPE_MB:
			case BIBOOTWHAT_TYPE_MFS:
#if defined(BOOTINFO_PXEEVENTS)
				if (!no_boot_event_send) {
					bievent_send(ipaddr, opaque,
						     TBDB_NODESTATE_BOOTING);
					break;
				}
#endif
				needevent = 0;
				break;
					
			case BIBOOTWHAT_TYPE_WAIT:
				bievent_send(ipaddr, opaque,
					     TBDB_NODESTATE_PXEWAIT);
				break;

			case BIBOOTWHAT_TYPE_REBOOT:
				bievent_send(ipaddr, opaque, 
					     TBDB_NODESTATE_REBOOTING);
				break;

			default:
				error("%s: invalid boot directive: %d\n",
				      inet_ntoa(ipaddr), boot_whatp->type);
				needevent = 0;
				break;
			}
		}
#endif
	}

#ifdef	EVENTSYS
	if (event_sent)
		*event_sent = needevent;
#endif
	return 0;
}

/*
 * Simple cache to prevent dups when bootinfo packets get lost.
 */
static DB      *dbp;

/*
 * Initialize an in-memory DB
 */
static int
bicache_init(void)
{
	if ((dbp = dbopen(NULL, O_CREAT|O_TRUNC|O_RDWR, 664, DB_HASH, NULL))
	    == NULL) {
		pfatal("failed to initialize the bootinfo DBM");
		return -1;
	}
	return 0;
}

#ifdef	EVENTSYS
/*
 * This does both a check and an insert. The idea is that we store the
 * current time of the request, returning yes/no to the caller if the
 * current request is is within a small delta of the previous request.
 * This should keep the number of repeats to a minimum, since a requests
 * coming within a few seconds of each other indicate lost bootinfo packets.
 */
static int
bicache_needevent(struct in_addr ipaddr)
{
	DBT	key, item;
	time_t  tt;
	int	rval = 1, r;

	/* So we can include bootinfo into tmcd; always send the event. */
	if (!dbp)
		return 1;

	tt = time(NULL);
	key.data = (void *) &ipaddr;
	key.size = sizeof(ipaddr);

	/*
	 * First find current value.
	 */
	if ((r = (dbp->get)(dbp, &key, &item, 0)) != 0) {
		if (r == -1) {
			errorc("Could not retrieve entry from DBM for %s\n",
			       inet_ntoa(ipaddr));
		}
	}
	if (r == 0) {
		time_t	oldtt = *((time_t *)item.data);

		if (debug) {
			info("Timestamps: old:%ld new:%ld\n", oldtt, tt);
		}

		/*
		 * XXX sanity check, in case time goes backward while we
		 * are running.
		 */
		if (tt < oldtt) {
			info("%s: Whoa! time went backwards (%ld -> %ld),"
			     "fixing...\n",
			     inet_ntoa(ipaddr), oldtt, tt);
		} else if (tt - oldtt <= MINEVENTTIME) {
			rval = 0;
			info("%s: no event will be sent: last:%ld cur:%ld\n",
			     inet_ntoa(ipaddr), oldtt, tt);
		}
	}
	if (rval) {
		item.data = (void *) &tt;
		item.size = sizeof(tt);

		if ((dbp->put)(dbp, &key, &item, 0) != 0) {
			errorc("Could not insert DBM entry for %s\n",
			       inet_ntoa(ipaddr));
		}
	}
	return rval;
}

/*
 * Clear a timestamp in the cache.
 * We call this if an event send fails.
 */
#ifdef __clang__
__attribute__((unused)) /* Suppress warning */
#endif
static void
bicache_clearevent(struct in_addr ipaddr)
{
	DBT	key, item;
	time_t  tt;

	if (dbp) {
		key.data = (void *) &ipaddr;
		key.size = sizeof(ipaddr);

		tt = 0;
		item.data = (void *) &tt;
		item.size = sizeof(tt);

		if ((dbp->put)(dbp, &key, &item, 0) != 0) {
			errorc("Could not insert DBM entry for %s\n",
			       inet_ntoa(ipaddr));
		}
	}
}
#endif
