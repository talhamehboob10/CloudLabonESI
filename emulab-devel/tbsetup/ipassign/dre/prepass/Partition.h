// Partition.h

/*
 * Copyright (c) 2005 University of Utah and the Flux Group.
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

#ifndef PARTITION_H_IPASSIGN_3
#define PARTITION_H_IPASSIGN_3

// The partition is a collection of all the information needed to
// output a sub-graph to a pipe and interpret the results.
class Partition
{
public:
    Partition(int newNumber = 0);
    void setNumber(int newNumber);
    int getNumber(void) const;
    void setAddress(int newAddress);
    int getAddress(void) const;
    // Add a lan to the information. This increases the count and adds
    // the lan number to the mappings.
    void addLan(int lanNumber);
    void dispatch(void);
    int getLanCount(void);
    void setTree(void);
private:
    struct OrderCount
    {
        OrderCount() : order(0), count(0) {}
        int order;
        int count;
    };
private:
    void parseError(std::istream & input);
    void mapHosts(void);
    void printGraph(std::ostream & output);
    void getNumbering(std::istream & input);
private:
    int number;
    int address;
    bool isTree;
    int lanCount;
    int hostCount;
    // This provides a mappings back and forth from sub-program
    // concepts to user concepts. We process our pipe output and then
    // input based on these mappings.
    std::map<int, int> lanToOrder;
    std::map<int, int> orderToLan;
    // The hostToOrder thing is a little different from the other
    // mappings. In order to determine whether we want to count a host
    // at all, we have to check to make sure that it touches two or
    // more hosts. That is what the count attached to this is.
    std::map<std::string, OrderCount> hostToOrder;
    std::map<int, std::string> orderToHost;
};

#endif
