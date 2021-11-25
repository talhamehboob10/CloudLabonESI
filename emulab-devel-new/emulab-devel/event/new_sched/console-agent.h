/*
 * Copyright (c) 2005 University of Utah and the Flux Group.
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
 * @file console-agent.h
 */

#ifndef _console_agent_h
#define _console_agent_h

#include "event-sched.h"
#include "local-agent.h"

#ifdef __cplusplus
extern "C" {
#endif

#define TIPLOGDIR "/var/log/tiplogs"

/**
 * A local agent structure for Console objects.
 */
struct _console_agent {
	struct _local_agent ca_local_agent;	/*< Local agent base. */
	off_t ca_mark;
};

/**
 * Pointer type for the _console_agent structure.
 */
typedef struct _console_agent *console_agent_t;

/**
 * Create a console agent and intialize it with the default values.
 *
 * @return An initialized console agent object.
 */
console_agent_t create_console_agent(void);

/**
 * Check a console agent object against the following invariants:
 *
 * @li na_local_agent is sane
 *
 * @param na An initialized console agent object.
 * @return True.
 */
int console_agent_invariant(console_agent_t na);

#ifdef __cplusplus
}
#endif

#endif
