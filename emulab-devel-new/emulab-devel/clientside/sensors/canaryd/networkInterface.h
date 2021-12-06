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
 * @file networkInterface.h
 *
 * Header file for network interface convenience functions.
 *
 * NOTE: Most of this was taken from the JanosVM.
 */

#ifndef NETWORK_INTERFACE_H
#define NETWORK_INTERFACE_H

#include <sys/types.h>
#include <sys/socket.h>

/**
 * Format a link layer socket address into a string.
 *
 * <p>Example output: 00:02:b3:65:b6:46
 *
 * @param dest The destination for the formatted address string.
 * @param sa The socket address to convert.
 * @return dest
 */
char *niFormatMACAddress(char *dest, struct sockaddr *sa);

#endif
