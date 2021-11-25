/*
 * Copyright (c) 2003-2006 University of Utah and the Flux Group.
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
 * A simple header that provides definitions of some maps used in assign
 */

#ifndef __MAPS_H
#define __MAPS_H

#include "fstring.h"

/*
 * A hash function for graph edges
 */
struct hashedge {
  size_t operator()(vedge const &A) const {
    hashptr<void *> ptrhash;
    return ptrhash(target(A,VG))/2+ptrhash(source(A,VG))/2;
  }
};

/*
 * Map types
 */
typedef hash_map<vvertex,pvertex,hashptr<void *> > node_map;
typedef hash_map<vvertex,bool,hashptr<void *> > assigned_map;
typedef hash_map<pvertex,fstring,hashptr<void *> > type_map;
typedef hash_map<vedge,tb_link_info,hashedge> link_map;


#endif
