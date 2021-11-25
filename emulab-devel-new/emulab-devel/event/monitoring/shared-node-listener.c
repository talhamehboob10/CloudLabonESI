/*
 * Copyright (c) 2014 University of Utah and the Flux Group.
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

#include <mysql/mysql.h>
#include <stdio.h>
#include <string.h>
#include <unistd.h>
#include <sys/types.h>
#include <sys/stat.h>
#include "event.h"

static MYSQL db;

void notification( event_handle_t h, event_notification_t n, void *unused ) {

    char tab[ 0x400 ], id[ 0x400 ], v[ 0x400 ], eid[ 0x800 ], ev[ 0x800 ],
	query[ 0x2000 ], *p;
    int64_t ts;
    
    event_notification_get_string( h, n, "tab", tab, sizeof tab );
    event_notification_get_string( h, n, "id", id, sizeof id );
    event_notification_get_int64( h, n, "ts", &ts );
    event_notification_get_string( h, n, "v", v, sizeof v );

    /* Be very careful about SQL injection in "tab", since it will be
       used unescaped.  Permit letters and underscore only. */
    for( p = tab; *p; p++ )
	if( !( ( *p >= 'a' && *p <= 'z' ) ||
	       ( *p >= 'A' && *p <= 'Z' ) ||
	       *p == '_' ) )
	    return;

    /* The schema interpretation of "bps" changed from bytes per second
       to bits per second in June 2015.  To avoid client-side version
       headaches, we'll do the conversion here. */
    if( strstr( tab, "_bps" ) )
	sprintf( v, "%.1f", atof( v ) * 8.0 );
    
    mysql_real_escape_string( &db, eid, id, strlen( id ) );
    mysql_real_escape_string( &db, ev, v, strlen( v ) );

    sprintf( query, "INSERT INTO %s SET id='%s', ts=%lld, v='%s';",
	     tab, eid, (long long) ts, ev );
    mysql_query( &db, query );
}

extern int main( void ) {

    event_handle_t h;
    address_tuple_t tuple;
    char *eid, buf[ 0x100 ];

    if (getuid() != 0)
    {
        printf("Can only run as root\n");
        exit(1);
    }
    FILE    *fp;
    char    mybuf[BUFSIZ];
    int pid;
    
    sprintf(mybuf, "/var/run/shared-node-listener.pid");
    fp = fopen(mybuf, "r");
    if (fp != NULL) 
    {
        fscanf(fp, "%d\n",&pid);
        (void) fclose(fp);
        if(kill(pid,0) == 0)
        {
            printf("process already runnning\n");
            exit (1);
        }
    }

    (void)daemon(0, 0);


    /* Shared pool experiments are not named consistently... grr. */
    if( !eaccess( "/proj/emulab-ops/exp/shared-nodes/tbdata/eventkey", R_OK ) )
	eid = "shared-nodes";
    else
	eid = "shared-node";

    mysql_init( &db );

    if( !mysql_real_connect( &db, NULL, NULL, NULL, "monitoring",
			     0, NULL, 0 ) ) {
	fprintf( stderr, "monitoring: %s\n", mysql_error( &db ) );

	return 1;
    }			     

    sprintf( buf, "/proj/emulab-ops/exp/%s/tbdata/eventkey", eid );
    if( !( h = event_register_withkeyfile( "elvin://event-server", 0, buf ) ) ) {
	fputs( "failed to register with event-server", stderr );

	return 1;
    }

    if( !( tuple = address_tuple_alloc() ) ) {
	fputs( "failed to allocate address tuple", stderr );

	return 1;
    }

    tuple->site = NULL;
    sprintf( buf, "emulab-ops/%s", eid );
    tuple->expt = buf;
    tuple->group = NULL;
    tuple->host = NULL;
    tuple->objtype = "CUSTOM";
    tuple->objname = "MONITOR";
    tuple->eventtype = "REPORT";

    if( !event_subscribe( h, notification, tuple, NULL ) ) {
	fputs( "failed to subscribe", stderr );

	return 1;
    }

    fp = fopen(mybuf, "w");
    if (fp != NULL) 
    {
        fprintf(fp, "%d\n", getpid());
        (void) fclose(fp);
    }

    event_main( h );
    
    return 0;
}
