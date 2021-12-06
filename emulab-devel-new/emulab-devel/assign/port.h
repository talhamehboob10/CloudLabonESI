/*
 * Copyright (c) 2002-2010 University of Utah and the Flux Group.
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

// This file may need to be changed depending on the architecture.
#ifndef __PORT_H
#define __PORT_H
#include <limits.h>

#ifndef WCHAR_MIN
#define WCHAR_MIN INT_MIN
#define WCHAR_MAX INT_MAX
#endif

/*
 * We have to do these includes differently depending on which version of gcc
 * we're compiling with
 *
 * In G++ 4.3, hash_set and hash_map were formally deprecated and
 * moved from ext/ to backward/.  Well, that's what the release notes
 * claim.  In fact, on my system, hash_set and hash_map appear in both
 * ext/ and backward/.  But, hash_fun.h is only in backward/, necessi-
 * tating the NEWER_GCC macro.
 *
 * The real fix is to replace
 *   hash_set with tr1::unordered_set in <tr1/unordered_set>
 *   hash_map with tr1::unordered_map in <tr1/unordered_map>
 */
#if (__GNUC__ == 3 && __GNUC_MINOR__ > 0) || (__GNUC__ > 3)
#ifndef __clang__
#define NEW_GCC
#endif
#endif

#if (__GNUC__ == 4 && __GNUC_MINOR__ >= 3) || (__GNUC__ > 4)
#ifndef __clang__
#define NEWER_GCC
#endif
#endif

#ifdef __clang__
#undef NEW_GCC
#undef NEWER_GCC
#include <forward_list>
template<typename T>
using slist = std::forward_list<T>;
#endif

#ifdef NEW_GCC
#include <ext/slist>
using namespace __gnu_cxx;
#elif ! defined __clang__
#include <slist>
#endif

#ifdef NEWER_BOOST
#define BOOST_PMAP_HEADER <boost/property_map/property_map.hpp>
#else
#define BOOST_PMAP_HEADER <boost/property_map.hpp>
#endif

/*
 * We have to do these includes differently depending on which version of gcc
 * we're compiling with
 */
#ifdef NEW_GCC
#include <ext/hash_map>
#include <ext/hash_set>
#ifdef NEWER_GCC
  #include <backward/hash_fun.h>
#else
  #include <ext/hash_fun.h>
#endif

using namespace __gnu_cxx;
#define RANDOM() random()
#elif ! defined __clang__
#include <hash_map>
#include <hash_set>
#define RANDOM() std::random()
#endif

#ifdef __clang__

#include <functional>
#include <unordered_map>
#include <unordered_set>

template < typename T, typename U, typename F=std::hash<T> >
using hash_map = std::unordered_map<T, U, F>;

template < typename T, typename F=std::hash<T> >
using hash_set = std::unordered_set<T, F>;
#define RANDOM() std::rand()

#endif

#else
#endif
