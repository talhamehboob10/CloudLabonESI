/*
 * Copyright (c) 2000-2011 University of Utah and the Flux Group.
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
 * event-sched.h --
 *
 *      This file contains definitions for the testbed event
 *      scheduler.
 *
 */

#ifndef __SCHED_H__
#define __SCHED_H__

#include <stdio.h>
#include <sys/time.h>
#include "event.h"
#include "log.h"
#include "tbdefs.h"

#include "listNode.h"

#ifndef MAXHOSTNAMELEN
#define MAXHOSTNAMELEN 64
#endif /* MAXHOSTNAMELEN */

#define LOGDIR		"/local/logs"

#ifdef __cplusplus
extern "C" {
#endif

struct _local_agent;

struct agent {
	struct  lnNode link;
	char    name[TBDB_FLEN_EVOBJNAME];
	char    nodeid[TBDB_FLEN_NODEID];
	char    vnode[TBDB_FLEN_VNAME];
	char	objtype[TBDB_FLEN_EVOBJTYPE];
	char	ipaddr[32];
	struct _local_agent *handler;
};

extern struct lnList agents;

enum {
	SEB_COMPLETE_EVENT,
	SEB_TIME_START,
	SEB_SENDS_COMPLETE,
	SEB_SINGLE_HANDLER,
};

enum {
	/** Flag for events that are COMPLETEs and should not be forwarded. */
	SEF_COMPLETE_EVENT = (1L << SEB_COMPLETE_EVENT),
	SEF_TIME_START = (1L << SEB_TIME_START),
	/** Flag for events that will send back a COMPLETE. */
	SEF_SENDS_COMPLETE = (1L << SEB_SENDS_COMPLETE),
	SEF_SINGLE_HANDLER = (1L << SEB_SINGLE_HANDLER),
};

/* Scheduler-internal representation of an event. */
typedef struct sched_event {
	union {
		struct agent *s;
		struct agent **m;
	} agent;
	event_notification_t notification;
	struct timeval time;			/* event firing time */
	unsigned short length;
	unsigned short flags;
} sched_event_t;

extern char	pideid[BUFSIZ];
extern char	*pid, *eid;

extern int debug;
extern int32_t next_token;

/*
 * Function prototypes:
 */

int agent_invariant(struct agent *agent);
int sends_complete(struct agent *agent, const char *evtype);

void sched_event_free(event_handle_t handle, sched_event_t *se);
int sched_event_prepare(event_handle_t handle, sched_event_t *se);
int sched_event_enqueue_copy(event_handle_t handle,
			     sched_event_t *se,
			     struct timeval *new_time);

/* queue.c */
void sched_event_init(void);
int sched_event_enqueue(sched_event_t event);
int sched_event_dequeue(sched_event_t *event, int wait);
void sched_event_queue_dump(FILE *fp);

extern char build_info[];

#ifdef __cplusplus
}
#endif

#endif /* __SCHED_H__ */
