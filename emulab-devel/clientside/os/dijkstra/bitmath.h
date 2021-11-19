// bitmath.h

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

// Utilities for dealing with ip numbers

#ifndef BITMATH_H_IP_ASSIGN_2
#define BITMATH_H_IP_ASSIGN_2

#include "Exception.h"

typedef unsigned int IPAddress;

class BadStringToIPConversionException : public StringException
{
public:
    explicit BadStringToIPConversionException(std::string const & error)
        : StringException("Bad String to IP conversion: " + error)
    {
    }
};

// take an unsigned int and produce a dotted quadruplet based on it.
// can throw bad_alloc
std::string ipToString(IPAddress ip);
IPAddress stringToIP(std::string const & source);

#endif
