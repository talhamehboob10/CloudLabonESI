// NoneCompressor.cc

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
#include "NoneCompressor.h"

using namespace std;

NoneCompressor::NoneCompressor()
{
}

NoneCompressor::~NoneCompressor()
{
}

void NoneCompressor::printRoutes(SingleSource const & graph,
                                 HostHostToIpMap const & ip)
{
    printRoutesFromHost(graph.getSource(), graph, ip);
}

void NoneCompressor::printRoutesFromHost(int source,
                                         SingleSource const & graph,
                                         HostHostToIpMap const & ip)
{
    for (int i = 0; i < graph.getVertexCount(); ++i)
    {
        if (i != source)
        {
            printRoutesToHost(source, i, graph, ip);
        }
    }
}

void NoneCompressor::printRoutesToHost(int source, int dest,
                                       SingleSource const & graph,
                                       HostHostToIpMap const & ip)
{
    string sourceIp;
    string firstHopIp;
    calculateSourceInfo(source, dest, graph, ip, sourceIp, firstHopIp);

    multimap< int, pair<string, string> >::const_iterator pos;
    pos = ip[dest].begin();
    multimap< int, pair<string, string> >::const_iterator limit;
    limit = ip[dest].end();
    string previous;

    for ( ; pos != limit; ++pos)
    {
        string const & destIp = pos->second.first;
        if (destIp != previous)
        {
            printRouteToIp(sourceIp, firstHopIp, destIp,
                           graph.getDistance(dest));
            previous = destIp;
        }
    }
}

void NoneCompressor::calculateSourceInfo(int source, int dest,
                                         SingleSource const & graph,
                                         HostHostToIpMap const & ip,
                                         string & outSourceIp,
                                         string & outFirstHopIp)
{
    multimap< int, pair<string, string> >::const_iterator sourcePos;
    sourcePos = ip[source].find(graph.getFirstHop(dest));
    if (sourcePos == ip[source].end())
    {
        throw RouteNotFoundException(source, dest, graph.getFirstHop(dest));
    }
    outSourceIp = sourcePos->second.first;
    outFirstHopIp = sourcePos->second.second;
}
