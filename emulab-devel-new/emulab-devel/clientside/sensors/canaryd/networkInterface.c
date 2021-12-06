/*
 * Copyright (c) 2000-2004 University of Utah and the Flux Group.
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
 * @file networkInterface.c
 *
 * Implemenation of the network interface convenience functions.
 *
 * NOTE: Most of this was taken from the JanosVM.
 */

#include <errno.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include <sys/types.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <sys/socket.h>
#include <net/if.h>
#include <ifaddrs.h>

#if defined(__FreeBSD__)
#include <net/if_dl.h>
#include <net/if_arp.h>
#include <net/if_types.h>
#endif

#include "networkInterface.h"

char *niFormatMACAddress(char *dest, struct sockaddr *sa)
{
    char *retval = dest;
    int lpc, hlen;
    char *haddr;
    
#if defined(AF_LINK)
    /* FreeBSD link layer address. */
    struct sockaddr_dl *sdl;
    
    sdl = (struct sockaddr_dl *)sa;
    hlen = sdl->sdl_alen;
    haddr = sdl->sdl_data + sdl->sdl_nlen;
#else
    hlen = 0;
#endif
    for( lpc = 0; lpc < hlen; lpc++ )
    {
	sprintf(dest,
		"%s%02x",
		(lpc > 0) ? ":" : "",
		haddr[lpc] & 0xff);
	dest += strlen(dest);
    }
    return( retval );
}
