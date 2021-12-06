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
 */

#include <stdlib.h>
#include <unistd.h>
#include <sys/socket.h>

/*
 * Quick hack: just open a socket.
 * Return 0 if it works, non-zero otherwise.
 * When run under instrument.sh, will tell us if netmond is ready for traffic.
 */
int
main()
{
	int rv = socket(PF_INET, SOCK_DGRAM, 0);
	if (rv >= 0) {
		close(rv);
		exit(0);
	}
	exit(rv);
}
