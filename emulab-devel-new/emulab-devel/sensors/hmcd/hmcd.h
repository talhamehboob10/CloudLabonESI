/*
 * Copyright (c) 2000-2002 University of Utah and the Flux Group.
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

/* hmcd.h - header file for Healthd Master Collection Daemon, and peer
   query program hmcdgrab.
*/
#ifndef HMCD_H
#define HMCD_H

#include <unistd.h>
#include <stdlib.h>
#include <stdio.h>
#include <ctype.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <sys/socket.h>
#include <sys/un.h>
#include <string.h>
#include <netinet/in.h>
#include <netdb.h>
#include <errno.h>
#include <signal.h>
#include <syslog.h>

#define PUSH_PORT 8505
#define MAX_HOSTS 1000
#define SOCKPATH "/tmp/hwcollectsock"
#define MAXCLIENTS 5

typedef struct {
  char *id;      /* Host identifier - probably local part of hostname */
  char *data;    /* String containing monitor output values */
} HMONENT;

extern int errno;

#endif
