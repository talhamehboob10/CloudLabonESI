// OptimalIpTree.h

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

// This algorithm comes from the paper 'Constructing Optimal IP
// Routing Tables' by Richard P. Draves, Christopher King, Srinivasan
// Venkatachary, and Brian D. Zill. It was published by the IEEE.

#ifndef OPTIMAL_IP_TREE_H_DISTRIBUTED_DIJKSTRA_1
#define OPTIMAL_IP_TREE_H_DISTRIBUTED_DIJKSTRA_1

#include "bitmath.h"
#include "IpTree.h"

class OptimalIpTree : public IpTree
{
public:
    OptimalIpTree();
    virtual ~OptimalIpTree();

    virtual std::auto_ptr<IpTree> exemplar(void) const;
    virtual void reset(void);
    virtual void addRoute(IPAddress ip, int newFirstHop, int depth);
    virtual void printRoutes(HostHostToIpMap const & ip, int source,
                             IPAddress subnet);
private:
    void printRoutes(int firstHop, HostHostToIpMap const & ip, int source,
                     IPAddress subnet);
    int size(void);
    // Take the sets of the children and join them together into a set
    // for the current node. If one of them is null, just copy up the
    // non-null child. Otherwise, do an IntersectionOrUnion operation
    // to initialize our set. Note that copying up the other set if
    // one is NULL is a departure from the algorithm in the paper.
    void joinSets(void);

    // Given two sets, if the intersection is non-empty, set result to
    // the intersection. Otherwise set the result to the union.
    static void IntersectionOrUnion(std::set<int> const & left,
                                    std::set<int> const & right,
                                    std::set<int> & result);

    // Classic set intersection
    static void Intersection(std::set<int> const & left,
                             std::set<int> const & right,
                             std::set<int> & result);

    // Classic set union
    static void Union(std::set<int> const & left,
                      std::set<int> const & right,
                      std::set<int> & result);
private:
    OptimalIpTree(OptimalIpTree const & right);
    OptimalIpTree & operator=(OptimalIpTree const & right);
private:
    int m_depth;
    std::set<int> m_firstHops;
    std::auto_ptr<OptimalIpTree> m_children[2];
};

#endif
