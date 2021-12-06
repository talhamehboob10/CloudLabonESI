// lib.h

/*
 * Copyright (c) 2004 University of Utah and the Flux Group.
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

#ifndef LIB_H_DISTRIBUTED_DIJKSTRA_1
#define LIB_H_DISTRIBUTED_DIJKSTRA_1

#include <iostream>
#include <map>
#include <string>
#include <utility>
#include <sstream>
#include <cstdio>
#include <cstdlib>
#include <vector>
#include <memory>
#include <set>
#include <cassert>

// A convenient converter
inline std::string intToString(int num)
{
    std::ostringstream stream;
    stream << num;
    return stream.str();
}


// Sparse array of hosts. The first string is the IP address of an
// interface on the host represented by the whole multimap. The second
// string is the IP address of an interface on the host represented by
// the key. The two interfaces are linked.
typedef std::multimap<int,std::pair<std::string,std::string> > HostEntry;

// Map every pair of adjascent hosts to the IP addresses of their interfaces.
typedef std::vector<HostEntry> HostHostToIpMap;

enum { IP_SIZE = 32 };

#endif
