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

/* 
 * This is a very slightly modified version of
 * example code from Unix Netwok Programming, edition 2.
 */

#include "discvr.h"

//


char *
net_rt_iflist(int family, int flags, size_t *lenp)
{
	int		mib[6];
	char	*buf;

	// Meaning of each parameter is explained below -ik
	mib[0] = CTL_NET; 		// network related system information
	mib[1] = PF_ROUTE;		// get the routing messages
	mib[2] = 0;				// protocol number (always zero!)
	mib[3] = family;		// get addresses of only this family 
	mib[4] = NET_RT_IFLIST; // return "interface" list
	mib[5] = flags;			/* interface index, or 0*/ // "man" says NONE?!

	// Call "sysctl" to get the length of buffer needed for storing the list
	// of interfaces. The "oldp" parameter is supplied with NULL to get just
	// the size. -ik
	if (sysctl(mib, 6, NULL, lenp, NULL, 0) < 0)
		return(NULL);

	// Allocate a buffer to store the list of interfaces. -ik
	if ( (buf = malloc(*lenp)) == NULL)
		return(NULL);

	// Get the list of interfaces in the "buf". -ik
	if (sysctl(mib, 6, buf, lenp, NULL, 0) < 0)
		return(NULL);

	// Return the list of interfaces. -ik
	return(buf);
}


