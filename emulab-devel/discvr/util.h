/* 
 * Copyright (c) 2000 The University of Utah and the Flux Group.
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
 * ---------------------------
 *
 * Filename: util.h
 *   -- Author: Kristin Wright <kwright@cs.utah.edu> 
 *
 * ---------------------------
 *
 * $Id: util.h,v 1.7 2004-06-17 18:17:01 mike Exp $
 */

void 
print_haddr(u_char *haddr, u_short hlen);

void 
println_haddr(u_char *haddr, u_short hlen);

u_char*
max_haddr(u_char *ha1, u_char *ha2);

void
print_tdinq(const char *mesg);

void
print_tdreply(const char *mesg, size_t nbytes); 

void
print_tdnbrlist(struct topd_nborlist * list);

void
print_tdpairs(const char *mesg, size_t nbytes);

void
print_tdifinbrs(struct ifi_info *ifihead);

void
get_mac_addr(u_char *haddr, u_short hlen, char* addr);




