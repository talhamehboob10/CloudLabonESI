/*
 * Copyright (c) 2000-2014 University of Utah and the Flux Group.
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
struct boot_what;
struct boot_info;

int		open_bootinfo_db(void);
int		close_bootinfo_db(void);
int		bootinfo_init(void);
int		bootinfo(struct in_addr ipaddr, char *node_id,
			 struct boot_info *info, void *opaque,
			 int no_event_send, int *event_sent);
int		query_bootinfo_db(struct in_addr ipaddr, char *node_id, 
				  int version, struct boot_what *info, 
				  char *key);
int		findnode_bootinfo_db(struct in_addr ipaddr, int *events);
int		elabinelab_hackcheck(struct sockaddr_in *target);

extern int debug;

#ifdef EVENTSYS
int		bievent_init(void);
int		bievent_shutdown(void);
int		bievent_send(struct in_addr ipaddr, void *opaque, char *event);
#endif

