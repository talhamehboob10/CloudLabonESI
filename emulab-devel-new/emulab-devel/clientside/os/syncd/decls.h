/*
 * Copyright (c) 2002-2012 University of Utah and the Flux Group.
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

#include <inttypes.h>

#define SERVER_SERVNAME		"emulab_syncd"
#define SERVER_PORTNUM		16534
#define SOCKBUFSIZE		(1024 * 128)

/*
 * The barrier request structure sent to the daemon.  A single integer is
 * returned, its value is zero or the maximum of the error codes from the
 * clients.
 */
typedef struct {
	char		name[64];	/* An arbitrary string */
	int16_t		request;	/* Either init or wait */
	int16_t		flags;		/* See below */
	int32_t		count;		/* Number of waiters */
	int32_t		error;		/* Error code (0 == no error) */
} barrier_req_t;

/* Request */
#define BARRIER_INIT		1
#define BARRIER_WAIT		2

/* Flags */
#define BARRIER_INIT_NOWAIT	0x1	/* Initializer does not wait! */

/* Default name is not specified */
#define DEFAULT_BARRIER "barrier"

/* Info */
#define CURRENT_VERSION 2

/* Start of error codes for the server */
#define SERVER_ERROR_BASE	240
/* Error code for server got a SIGHUP */
#define SERVER_ERROR_SIGHUP	(SERVER_ERROR_BASE)
