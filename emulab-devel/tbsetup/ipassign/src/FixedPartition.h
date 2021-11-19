// FixedPartition.h

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

// This partitioning scheme uses a fixed number of partitions set on the
// command line. METIS is used.

#ifndef FIXED_PARTITION_H_IP_ASSIGN_2
#define FIXED_PARTITION_H_IP_ASSIGN_2

#include "Partition.h"

class FixedPartition : public Partition
{
public:
    // The number of partitions is set in the constructor.
    FixedPartition(int newCount = 0)
        : m_originalPartitionCount(newCount)
        , m_partitionCount(newCount)
    {
    }

    // This does nothing because the number of partitions is fixed.
    virtual void addLan(void)
    {
    }

    // Pass off the partitioning job to the common code in Partition.
    // We know how many partitions we are supposed to have.
    virtual void partition(std::vector<int> & indexes,
                           std::vector<int> & neighbors,
                           std::vector<int> & weights,
                           std::vector<int> & partitions)
    {
        m_partitionCount = m_originalPartitionCount;
        partitions.resize(indexes.size() - 1);
        fill(partitions.begin(), partitions.end(), 0);
        Partition::partitionN(m_partitionCount, indexes, neighbors, weights,
                              partitions);
        m_partitionCount = Partition::makeConnectedGraph(m_partitionCount,
                                                         indexes, neighbors,
                                                         weights, partitions);
    }

    virtual std::auto_ptr<Partition> clone(void)
    {
        return std::auto_ptr<Partition>(new FixedPartition(*this));
    }

    virtual int getPartitionCount(void)
    {
        return m_partitionCount;
    }
private:
    int m_originalPartitionCount;
    int m_partitionCount;
};

#endif
