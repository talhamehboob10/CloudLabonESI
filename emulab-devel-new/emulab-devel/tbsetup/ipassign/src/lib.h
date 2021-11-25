// lib.h

/*
 * Copyright (c) 2003 University of Utah and the Flux Group.
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

// project-wide inclusions and declarations go here.

#ifndef LIB_H_IP_ASSIGN_1
#define LIB_H_IP_ASSIGN_1

#include <iostream>
#include <iomanip>
#include <vector>
#include <list>
#include <map>
#include <set>
#include <sstream>
#include <cmath>
#include <cstdio>
#include <algorithm>
#include <bitset>
#include <memory>
#include <climits>
#include <queue>
#include <iterator>

extern "C"
{
#include <metis.h>
}

#include "Exception.h"
#include "bitmath.h"

template <class T>
void swap_auto_ptr(std::auto_ptr<T> & left, std::auto_ptr<T> & right)
{
    std::auto_ptr<T> temp = left;
    left = right;
    right = temp;
}

extern const int totalBits;
extern const int prefixBits;
extern const int postfixBits;
extern const IPAddress prefix;
extern const IPAddress prefixMask;
extern const IPAddress postfixMask;

#endif

