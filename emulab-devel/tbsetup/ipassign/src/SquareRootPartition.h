// SquareRootPartition.h

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

#ifndef SQUARE_ROOT_PARTITION_H_IP_ASSIGN_2
#define SQUARE_ROOT_PARTITION_H_IP_ASSIGN_2

#include "Partition.h"

class SquareRootPartition : public Partition
{
public:
    SquareRootPartition()
        : m_lanCount(0)
        , m_partitionCount(0)
    {
    }

    virtual void addLan(void)
    {
        ++m_lanCount;
    }

    virtual void partition(std::vector<int> & indexes,
                           std::vector<int> & neighbors,
                           std::vector<int> & weights,
                           std::vector<int> & partitions)
    {
        partitions.resize(indexes.size() - 1);
        fill(partitions.begin(), partitions.end(), 0);
        m_partitionCount = static_cast<int>(sqrt(m_lanCount));
        Partition::partitionN(m_partitionCount, indexes, neighbors, weights,
                              partitions);
        m_partitionCount = Partition::makeConnectedGraph(m_partitionCount,
                                                         indexes, neighbors,
                                                         weights, partitions);
    }

    virtual std::auto_ptr<Partition> clone(void)
    {
        return std::auto_ptr<Partition>(new SquareRootPartition(*this));
    }

    virtual int getPartitionCount(void)
    {
        return m_partitionCount;
    }
private:
    int m_lanCount;
    int m_partitionCount;
};

#endif
