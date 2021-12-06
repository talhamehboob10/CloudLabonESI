/*
 * Copyright (c) 2004 University of Utah and the Flux Group.
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

/**
 * @file timeline-agent.h
 */

#ifndef _timeline_agent_h
#define _timeline_agent_h

#include "listNode.h"
#include "local-agent.h"

#ifdef __cplusplus
extern "C" {
#endif

struct _ts_agent {
	struct _local_agent ta_local_agent;
	sched_event_t *ta_events;
	int ta_token;
	unsigned int ta_count;
	int ta_current_event;
};

typedef struct _ts_agent *timeline_agent_t;

typedef struct _ts_agent *sequence_agent_t;

typedef enum {
	TA_TIMELINE,
	TA_SEQUENCE,
	TA_GATE,
} ta_kind_t;

struct _ts_agent *create_timeline_agent(ta_kind_t tk);

int timeline_agent_invariant(struct _ts_agent *ta);

int timeline_agent_append(struct _ts_agent *ta, sched_event_t *se);

int sequence_agent_enqueue_next(sequence_agent_t ta);

int sequence_agent_handle_complete(event_handle_t handle,
				   struct lnList *list,
				   struct agent *agent,
				   int ctoken,
				   int agerror);

#ifdef __cplusplus
}
#endif

#endif
