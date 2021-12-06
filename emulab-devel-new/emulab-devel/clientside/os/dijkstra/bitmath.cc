// bitmath.cc

/*
 * Copyright (c) 2003-2004 University of Utah and the Flux Group.
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

#include <string>
#include <sstream>

using namespace std;

#include "Exception.h"
#include "bitmath.h"

string ipToString(IPAddress ip)
{
    static unsigned int charMask = 0x000000FF;
    ostringstream buffer;
    for (int i = 3; i >= 0; --i)
    {
        buffer << ((ip >> i*8) & charMask);
        if (i > 0)
        {
            buffer << '.';
        }
    }
    return buffer.str();
}

IPAddress stringToIP(string const & source)
{
    size_t index = 0;
    bool success = true;
    IPAddress result = 0;
    for (size_t i = 0; i < 4 && success; ++i)
    {
        istringstream buffer(source.substr(index));
        IPAddress current = 0xf00;
        buffer >> current;
        if (current <= 0xff)
        {
            result = result | (current << ((3 - i)*8));
        }
        else
        {
            success = false;
        }
        index = source.find(".", index);
        // if a dot is on the last iteration, then no dot should
        // be found. Otherwise, there should be another dot.
        if (i < 3)
        {
            success = !(index == string::npos);
        }
        else
        {
            success = (index == string::npos);
        }
        ++index;
    }
    if (!success)
    {
        throw BadStringToIPConversionException(source);
    }
    return result;
}
