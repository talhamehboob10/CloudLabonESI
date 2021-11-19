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

#ifndef _GEN_NAM_FILE_H_
#define _GEN_NAM_FILE_H_

#define HOSTNAME_LEN 10
#define MAC_ADDR_STR_LEN 15
typedef struct link_struct
{
	u_char *pointA;
	u_char *pointB;
	struct lan_node *lan_if_list;
	struct link_struct *next;
}link_type;

typedef struct lan_node
{
	u_char node[ETHADDRSIZ];
	struct lan_node *next;
}lan_node_type;

void 
add_link(struct topd_nbor *p);
int 
get_id(u_char *mac_addr);
void
gen_nam_file(const char *mesg, size_t nbytes, char *);
void
get_hostname(char *addr,char *hostname);
void
read_mac_db();
void
print_links_list();
int 
not_in_node_list(u_char *mac_addr);


#endif
