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
 * Filename: packet.h
 *   -- Author: Kristin Wright <kwright@cs.utah.edu> 
 *
 * ---------------------------
 *
 * $Id: packet.h,v 1.8 2004-06-17 18:17:01 mike Exp $
 */

#ifndef _TOPD_PACKET_H_
#define _TOPD_PACKET_H_

#include "discvr.h"

/*
 * Node IDs are the highest MAC address on the machine.
 * The easiest but not the most portable thing to
 * do is assume a 6-byte hardware address. This isn't
 * completely ridiculous as most of this tool's 
 * target platforms use ethernet. 
 * 
 * typedef u_char topd_nodeID_t[ETHADDRSIZ]; 
 */

/* 
 * Inquiry packet has only a unique Inquiry ID
 * comprised of [timestamp, sender-nodeID] pair. Timestamps
 * are struct timevals returned by gettimeofday().
 */
typedef struct topd_inqid {
	struct timeval     tdi_tv;
	u_int16_t          tdi_ttl;
	u_int16_t          tdi_factor;
	u_char             tdi_nodeID[ETHADDRSIZ];
	u_char			   tdi_p_nodeIF[ETHADDRSIZ];
	int				   lans_exist;                
} topd_inqid_t;

#define TOPD_INQ_SIZ ALIGN(sizeof(struct topd_inqid))

struct topd_inqnode {
        struct topd_inqnode *inqn_next;
        struct topd_inqid   *inqn_inq;
};

/*
 * Neighbor (reply) packets consist of 
 *
 *     [Neighbor ID, Route]
 *
 * pairs. Routes identify the interface through which
 * the node can reach the neighbor. These interfaces
 * are not necessarily local. Rather, they are 
 * interfaces belonging to the neighbor's parent.
 */
struct topd_nbor {
  u_char  tdnbor_pnode[ETHADDRSIZ]; /* path nodeID */
  u_char  tdnbor_pif[ETHADDRSIZ];   /* path if */
  u_char  tdnbor_dnode[ETHADDRSIZ]; /* dest nodeID */
  u_char  tdnbor_dif[ETHADDRSIZ];   /* dest if */
};

struct topd_nborlist {
  struct topd_nborlist *tdnbl_next;          /* next of these structures */
  u_int32_t            tdnbl_n;              /* number of neighbors in neighbor list */ 
  u_char               *tdnbl_nbors;         /* neighbor list */
};



#endif /* _TOPD_PACKET_H_ */
