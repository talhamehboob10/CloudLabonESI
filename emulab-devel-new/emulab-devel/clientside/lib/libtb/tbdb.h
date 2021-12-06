/*
 * Copyright (c) 2000-2010 University of Utah and the Flux Group.
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
 * Testbed DB interface and support.
 */
#include <stdarg.h>
#include <mysql/mysql.h>
#include "tbdefs.h"

/*
 * Generic interface.
 */
int		dbinit(void);
int		dbinit_withparams(char *host,
				  char *user, char *passwd, char *name);
void		dbclose(void);

/*
 * TB functions.
 */
int	mydb_iptonodeid(char *ipaddr, char *bufp);
int	mydb_nodeidtoip(char *nodeid, char *bufp);
int	mydb_setnodeeventstate(char *nodeid, char *eventtype);
int	mydb_checkexptnodeeventstate(char *pid, char *eid,char *ev,int *count);
int	mydb_seteventschedulerpid(char *pid, char *eid, int processid);

/*
 * mysql specific routines.
 */
MYSQL_RES      *mydb_query(char *query, int ncols, ...);
int		mydb_update(char *query, ...);
int		mydb_insertid(void);
unsigned long  mydb_escape_string(char *to, const char *from,
				  unsigned long length);

