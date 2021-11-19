/*
 * Copyright (c) 2014-2015 University of Utah and the Flux Group.
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

#include <stdio.h>
#include <string.h>
#include <sys/statfs.h>
#include <sys/time.h>
#include <unistd.h>
#include "event.h"

#define INTERVAL 30

#define MAX_ERRS 0x80

#define INTERFACE_MAX 0x10
#define VLAN_MAX 0x1000
struct interface {
    long old_rx_b, old_rx_p, old_rx_e, old_rx_d,
	old_tx_b, old_tx_p, old_tx_e, old_tx_d;
    time_t t;
} interfaces[ INTERFACE_MAX ][ VLAN_MAX ];

static void cpu_util( char *buf ) {

    static long o0, o3;
    FILE *f;
    long n0, n1, n2, n3;

    f = fopen( "/proc/stat", "r" );

    rewind( f );

    fscanf( f, "%*s %ld %ld %ld %ld", &n0, &n1, &n2, &n3 );
    n0 += n1 + n2;    

    sprintf( buf, "%.1f", ( 100.0 * ( n0 - o0 ) ) / ( n0 + n3 - o0 - o3 ) );

    o0 = n0;
    o3 = n3;

    fclose( f );
}

static void disk_part_max_used( char *buf ) {

    struct statfs s;
    
    statfs( "/", &s );

    sprintf( buf, "%.1f", ( 100.0 * ( s.f_blocks - s.f_bfree ) ) /
	     s.f_blocks );
}

static void mem_used_kb( char *buf ) {

    FILE *f;
    long tot, fr;
    
    f = fopen( "/proc/meminfo", "r" );

    fscanf( f, "%*s %ld %*s\n", &tot );
    fscanf( f, "%*s %ld %*s\n", &fr );
    
    fclose( f );

    sprintf( buf, "%ld", tot - fr );
}

static void num_vms_allocated( char *buf ) {

    FILE *f;
    int n;
    
    f = popen( "sudo xl vm-list|grep -v Domain-0 | wc -l", "r" );
    fscanf( f, "%d", &n );
    pclose( f );

    sprintf( buf, "%d", n - 1 );
}

static void swap_free( char *buf ) {

    FILE *f;
    long tot, fr;
    long n;
    char s[ 0x100 ];
    
    f = fopen( "/proc/meminfo", "r" );

    while( !feof( f ) ) {
	fscanf( f, "%s %ld %*s\n", s, &n );

	if( !strcmp( s, "SwapTotal:" ) )
	    tot = n;
	else if( !strcmp( s, "SwapFree:" ) )
	    fr = n;
    }
    
    fclose( f );

    sprintf( buf, "%.1f", 100.0 * fr / tot );
}

static void send_notification( event_handle_t h, address_tuple_t tuple,
			       char *tab, char *id, char *v ) {
		
    event_notification_t notification;
    struct timeval tv;
    static int err_cnt;
    
    if( !( notification = event_notification_alloc( h, tuple ) ) ) {
	fputs( "failed to allocate notification", stderr );

	exit( 1 );
    }

    if( !event_notification_put_string( h, notification, "tab", tab ) )
	fputs( "error adding tab", stderr );
    
    if( !event_notification_put_string( h, notification, "id", id ) )
	fputs( "error adding id", stderr );

    gettimeofday( &tv, NULL );
    if( !event_notification_put_int64( h, notification, "ts",
				       (long long) tv.tv_sec * 1000000 +
				       tv.tv_usec ) )
	fputs( "error adding ts", stderr );

    if( !event_notification_put_string( h, notification, "v", v ) )
	fputs( "error adding v", stderr );
    
    if( !event_notify( h, notification ) ) {
	fputs( "failed to send notification", stderr );

	if( ++err_cnt > MAX_ERRS )
	    exit( 1 );
    } else
	err_cnt = 0;

    event_notification_free( h, notification );
}

extern int main( void ) {

    event_handle_t h;
    address_tuple_t tuple;
    char hostname[ 0x100 ];
    char *domain;
    char node[ 0x100 ], id[ 0x100 ], interface_id[ 0x100 ];
    FILE *f;
    char *eid, buf[ 0x100 ];

    /* Shared pool experiments are not named consistently... grr. */
    if( !eaccess( "/proj/emulab-ops/exp/shared-nodes/tbdata/eventkey", R_OK ) )
	eid = "shared-nodes";
    else
	eid = "shared-node";

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

    if( !( f = popen( "/usr/testbed/lib/tmcc nodeid", "r" ) ) ) { /* FIXME config */
	perror( "tmcc" );

	return 1;
    }
    fscanf( f, "%s", node );
    pclose( f );
    
    gethostname( hostname, sizeof hostname );
    for( domain = hostname; *domain != '.'; domain++ )
	;
    domain++;
    for( ; *domain != '.'; domain++ )
	;
    domain++;
    for( ; *domain != '.'; domain++ )
	;
    domain++;

    sprintf( id, "%s_node_%s", domain, node );
    sprintf( interface_id, "%s_interface_%s:eth", domain, node );

    /* FIXME go into background */
    
    while( 1 ) {
	static const struct measurement {
	    void ( *f )( char * );
	    char *name;
	} m[] = {
	    { cpu_util, "ops_node_cpu_util" },
	    { disk_part_max_used, "ops_node_disk_part_max_used" },
	    { mem_used_kb, "ops_node_mem_used_kb" },
	    { num_vms_allocated, "ops_node_num_vms_allocated" },
	    { swap_free, "ops_node_swap_free" },
	};
	int i;
	time_t t;

	time( &t );
	
	for( i = 0; i < sizeof m / sizeof *m; i++ ) {
	    char buf[ 0x100 ];

	    m[ i ].f( buf );
	    send_notification( h, tuple, m[ i ].name, id, buf );
	}

	if( !( f = fopen( "/proc/net/dev", "r" ) ) ) {
	    perror( "/proc/net/dev" );

	    return 1;
	}

	do {
	    char ifacename[ 0x10 ];
	    int c, vlan;

	    i = -1;
	    
	    if( fscanf( f, " eth%15[^:]:", ifacename ) == 1 ) {
		char *p, *endp;
		
		i = strtol( ifacename, &endp, 10 );

		if( *endp == '.' ) {
		    /* 802.1q interface */
		    vlan = strtol( endp + 1, &endp, 10 );
		    if( vlan < 1 || vlan >= VLAN_MAX )
			i = -1;
		} else if( !*endp )
		    /* physical interface */
		    vlan = 0;
		else
		    /* invalid */
		    i = -1;
	    }

	    if( i != -1 ) {
		long rx_b, rx_p, rx_e, rx_d, tx_b, tx_p, tx_e, tx_d;
		struct interface *interface = interfaces[ i ] + vlan;
		
		if( fscanf( f, " %ld %ld %ld %ld %*d %*d %*d %*d "
			    "%ld %ld %ld %ld", &rx_b, &rx_p, &rx_e, &rx_d,
			    &tx_b, &tx_p, &tx_e, &tx_d ) < 8 )
		    continue;

		if( interface->t > t - 3600 ) {
		    char *p = strchr( interface_id, 0 );
		    char buf[ 0x100 ];

		    if( vlan )
			sprintf( p, "%d:%d", i, vlan );
		    else
			sprintf( p, "%d", i );
		    
		    sprintf( buf, "%.1f", ( rx_b - interface->old_rx_b ) /
			     (double) INTERVAL );
		    send_notification( h, tuple, vlan ?
				       "ops_interfacevlan_rx_bps" :
				       "ops_interface_rx_bps",
				       interface_id, buf );
		    sprintf( buf, "%.1f", ( rx_p - interface->old_rx_p ) /
			     (double) INTERVAL );
		    send_notification( h, tuple, vlan ?
				       "ops_interfacevlan_rx_pps" :
				       "ops_interface_rx_pps",
				       interface_id, buf );
		    sprintf( buf, "%.1f", ( rx_e - interface->old_rx_e ) /
			     (double) INTERVAL );
		    send_notification( h, tuple, vlan ?
				       "ops_interfacevlan_rx_eps" :
				       "ops_interface_rx_eps",
				       interface_id, buf );
		    sprintf( buf, "%.1f", ( rx_d - interface->old_rx_d ) /
			     (double) INTERVAL );
		    send_notification( h, tuple, vlan ?
				       "ops_interfacevlan_rx_dps" :
				       "ops_interface_rx_dps",
				       interface_id, buf );
		    sprintf( buf, "%.1f", ( tx_b - interface->old_tx_b ) /
			     (double) INTERVAL );
		    send_notification( h, tuple, vlan ?
				       "ops_interfacevlan_tx_bps" :
				       "ops_interface_tx_bps",
				       interface_id, buf );
		    sprintf( buf, "%.1f", ( tx_p - interface->old_tx_p ) /
			     (double) INTERVAL );
		    send_notification( h, tuple, vlan ?
				       "ops_interfacevlan_tx_pps" :
				       "ops_interface_tx_pps",
				       interface_id, buf );
		    sprintf( buf, "%.1f", ( tx_e - interface->old_tx_e ) /
			     (double) INTERVAL );
		    send_notification( h, tuple, vlan ?
				       "ops_interfacevlan_tx_eps" :
				       "ops_interface_tx_eps",
				       interface_id, buf );
		    sprintf( buf, "%.1f", ( tx_d - interface->old_tx_d ) /
			     (double) INTERVAL );
		    send_notification( h, tuple, vlan ?
				       "ops_interfacevlan_tx_dps" :
				       "ops_interface_tx_dps",
				       interface_id, buf );

		    *p = 0;
		}

		interface->old_rx_b = rx_b;
		interface->old_rx_p = rx_p;
		interface->old_rx_e = rx_e;
		interface->old_rx_d = rx_d;
		interface->old_tx_b = tx_b;
		interface->old_tx_p = tx_p;
		interface->old_tx_e = tx_e;
		interface->old_tx_d = tx_d;
		interface->t = t;
	    }		
		
	    do
		c = getc( f );
	    while( c != '\n' && c != EOF );
	} while( !feof( f ) );

	fclose( f );
	
	sleep( INTERVAL );
    }
    
    return 0;
}
