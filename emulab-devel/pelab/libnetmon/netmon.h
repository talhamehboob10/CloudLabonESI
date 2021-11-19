/*
 * Copyright (c) 2006 University of Utah and the Flux Group.
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
 *
 * libnetmon, a library for monitoring network traffic sent by a process. See
 * README for instructions.
 *
 * This file contains constants needed by both libnetmon and netmond
 */

#ifndef __NETMON_H
#define __NETMON_H

#define SOCKPATH "/var/tmp/netmon.sock"
#define CONTROLSOCK SOCKPATH ".control"

/*
 * For convience
 */
typedef enum {true = 1, false = 0} bool;

/*
 * Control messages
 */
#define CONTROL_MESSAGE_SIZE 256
#define CONTROL_MESSAGE_PAYLOAD_SIZE (CONTROL_MESSAGE_SIZE - sizeof(unsigned int))

typedef enum {
    /*
     * Messages from server to clients
     */
    CM_MAXSOCKSIZE = 0,
    CM_OUTPUTVER,
    CM_REPORTS,
    CM_MONITORDUP,

    CM_SOCKSIZE = 64,
    CM_QUERY
} control_message_types;

/*
 * Generic messages
 */
typedef struct {
    unsigned int type;
    char payload[CONTROL_MESSAGE_PAYLOAD_SIZE];
} generic_m;


/*
 * A query - no more fields required
 */
typedef struct {
    unsigned int type;
} query_m;

/*
 * Maximum socket size report
 */
typedef struct {
    unsigned int type;
    unsigned char limit;      /* 0 - don't impose a limit */
    unsigned int limit_size; /* In bytes */
    unsigned char force;      /* 0 - don't impose force a specific size */
    unsigned int force_size; /* In bytes */
} max_socket_m;

/*
 * Output version report
 */
typedef struct {
    unsigned int type;
    unsigned int version;
} out_ver_m;

/*
 * Report, err, report. Okay, bad name.
 */
typedef struct {
    unsigned int type;
    char reports[CONTROL_MESSAGE_PAYLOAD_SIZE];
} reports_m;

/*
 * Boolean: are we supposed to monitor UDP sockets?
 */
typedef struct {
    unsigned int type;
    unsigned char enable;
} monitorudp_m;

/*
 * Socket size change report
 */

#endif // __NETMON_H
