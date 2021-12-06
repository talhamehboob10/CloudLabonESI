/*
 * Copyright (c) 2004, 2005 University of Utah and the Flux Group.
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
 * @file node-agent.h
 */

#ifndef _node_agent_h
#define _node_agent_h

#include "event-sched.h"
#include "local-agent.h"

#ifdef __cplusplus
extern "C" {
#endif

#define NODE_DUMP_DIR "logs/%s"
#define NODE_DUMP_FILE "logs/%s/node-control.%d"

/**
 * A local agent structure for Node objects.
 */
struct _node_agent {
	struct _local_agent na_local_agent;	/*< Local agent base. */
};

/**
 * Pointer type for the _node_agent structure.
 */
typedef struct _node_agent *node_agent_t;

/**
 * Create a node agent and intialize it with the default values.
 *
 * @return An initialized node agent object.
 */
node_agent_t create_node_agent(void);

/**
 * Check a node agent object against the following invariants:
 *
 * @li na_local_agent is sane
 *
 * @param na An initialized node agent object.
 * @return True.
 */
int node_agent_invariant(node_agent_t na);

#ifdef __cplusplus
}
#endif

#endif
