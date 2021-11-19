// NoneCompressor.h

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

// This function-object carries out route compression. Actually, the
// point of this object is to represent no-compression. This object
// simply prints out the routes generated without trying to compress
// anything. This is used if the user doesn't want any route
// compression or while testing a route-compression method.

#ifndef NONE_COMPRESSOR_H_DISTRIBUTED_DIJKSTRA_1
#define NONE_COMPRESSOR_H_DISTRIBUTED_DIJKSTRA_1

#include "Compressor.h"

class NoneCompressor : public Compressor
{
public:
    NoneCompressor();
    virtual ~NoneCompressor();

    virtual void printRoutes(SingleSource const & graph,
                             HostHostToIpMap const & ip);
private:
    // Print all routes from a particular host to every destination.
    void printRoutesFromHost(int source, SingleSource const & graph,
                             HostHostToIpMap const & ip);

    // Print all routes from a particular host to a particular host
    void printRoutesToHost(int source, int dest, SingleSource const & graph,
                           HostHostToIpMap const & ip);

    // Calculate the source ip address and the first hop ip address
    // between a particular pair of hosts.
    void calculateSourceInfo(int source, int dest,
                             SingleSource const & graph,
                             HostHostToIpMap const & ip,
                             std::string & OutSourceIp,
                             std::string & OutFirstHopIp);
private:
    NoneCompressor(NoneCompressor const &);
    NoneCompressor & operator=(NoneCompressor const &) { return *this; }
};

#endif
