// IpTree.h

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

#ifndef IP_TREE_H_DISTRIBUTED_DIJKSTRA_1
#define IP_TREE_H_DISTRIBUTED_DIJKSTRA_1

class IpTree
{
public:
    IpTree() {}
    virtual ~IpTree() {}

    // return a new default-constructed IpTree of the same type as the
    // current object is.
    virtual std::auto_ptr<IpTree> exemplar(void) const=0;

    // Reset the state of the tree. Remove any state and put it back
    // to how it was just after construction.
    virtual void reset(void)=0;


    // Fill the tree with an IP address. The recursively added address
    // is limited by depth.
    void addRoute(IPAddress ip, int newFirstHop)
    {
        addRoute(ip, newFirstHop, 0);
    }
    virtual void addRoute(IPAddress ip, int newFirstHop, int depth)=0;

    // Print out the routes for this subtree
    virtual void printRoutes(HostHostToIpMap const & ip, int source,
                             IPAddress subnet)=0;
private:
    IpTree(IpTree const &);
    IpTree & operator=(IpTree const &) { return *this; }
};

#endif
