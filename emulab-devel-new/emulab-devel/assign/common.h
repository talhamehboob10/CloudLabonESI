/*
 * Copyright (c) 2000-2010 University of Utah and the Flux Group.
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

#ifndef __COMMON_H
#define __COMMON_H

#include "port.h"

#include <utility>
#include "fstring.h"

#include <boost/graph/adjacency_list.hpp>

/*
 * Exit vaules from assign
 */

// A solution with no violations was found
#define EXIT_SUCCESS 0

// No valid solution was found, but one may exist
// No violation-free solution was found after annealing.
#define EXIT_RETRYABLE 1

// It is not possible to map the given top file into the given ptop file,
// so there's no point in re-running assign.
#define EXIT_UNRETRYABLE 2

// An internal error occured, or there was a problem with the input - for
// example, the top or ptop file does not exist or cannot be parsed
#define EXIT_FATAL -1

#ifdef NEW_GCC
namespace __gnu_cxx
{
#endif
#ifdef __clang__
    template<> struct std::hash< std::string >
    {
        size_t operator()( const std::string& x ) const
        {
            return hash< const char* >()( x.c_str() );
        }
    };
#else
    template<> struct hash< std::string >
    {
        size_t operator()( const std::string& x ) const
        {
            return hash< const char* >()( x.c_str() );
        }
    };
#endif
#ifdef NEW_GCC
}
#endif


enum edge_data_t {edge_data};
enum vertex_data_t {vertex_data};

namespace boost {
  BOOST_INSTALL_PROPERTY(edge,data);
  BOOST_INSTALL_PROPERTY(vertex,data);
}

/*
 * Used to count the number of nodes in each ptype and vtype
 */
typedef hash_map<fstring,int> name_count_map;
typedef hash_map<fstring,vector<fstring> > name_list_map;

/*
 * A hash function for pointers
 */
template <class T> struct hashptr {
  size_t operator()(T const &A) const {
    return (size_t) A;
  }
};

/*
 * Misc. debugging stuff
 */
#ifdef ROB_DEBUG
#define RDEBUG(a) a
#else
#define RDEBUG(a)
#endif

/*
 * Needed for the transition from gcc 2.95 to 3.x - the new gcc puts some
 * non-standard (ie. SGI) STL extensions in different place
 */
#ifdef NEW_GCC
#define HASH_MAP <ext/hash_map>
#else
#define HASH_MAP
#endif

// For use in functions that want to return a score/violations pair
typedef pair<double,int> score_and_violations;

#endif
