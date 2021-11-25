/*
 * Copyright (c) 2005-2006 University of Utah and the Flux Group.
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
 * A set of functions useful for exploring the neighborhood of a particular
 * solution.
 */

#ifndef __NEIGHBORHOOD_H
#define __NEIGHBORHOOD_H

#include "port.h"
#include "common.h"
#include "physical.h"
#include "vclass.h"
#include "virtual.h"
#include "pclass.h"

/*
 * This overly-verbose function returns true if it's okay to map vn to pn,
 * false otherwise
 */
inline bool pnode_is_match(tb_vnode *vn, tb_pnode *pn);

/*
 * Finds a pnode which:
 * 1) One of the vnode's neighbors is mapped to
 * 2) Satisifies the usual pnode mapping constraints
 * 3) The vnode is not already mapped to
 */
tb_pnode *find_pnode_connected(vvertex vv, tb_vnode *vn);

tb_pnode *find_pnode(tb_vnode *vn);

#endif
