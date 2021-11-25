// Compressor.cc

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

#include "lib.h"
#include "Compressor.h"

using namespace std;

const int Compressor::shift[PRIVATE_SUBNET_COUNT] = {IP_SIZE - 8,
                                                     IP_SIZE - 12,
                                                     IP_SIZE - 16};

const IPAddress Compressor::prefix[PRIVATE_SUBNET_COUNT] = {10,
                                                            (172 << 8) + 16,
                                                            (192 << 8) + 168};

Compressor::PRIVATE_SUBNET Compressor::whichSubnet(IPAddress destIp)
{
#ifdef ROCKETFUEL_TEST
    return SUB_10;
#else
    for (PRIVATE_SUBNET i = PRIVATE_SUBNET_MIN; i < PRIVATE_SUBNET_COUNT;
         i = static_cast<PRIVATE_SUBNET>(i + PRIVATE_SUBNET_UNIT))
    {
        if ((destIp >> shift[i]) == prefix[i])
        {
            return i;
        }
    }
    return PRIVATE_SUBNET_INVALID;
#endif
}
