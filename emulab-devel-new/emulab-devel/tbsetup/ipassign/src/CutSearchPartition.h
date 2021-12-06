// CutSearchPartition.h

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

#ifndef CUT_SEARCH_PARTITION_H_IP_ASSIGN_2
#define CUT_SEARCH_PARTITION_H_IP_ASSIGN_2

#include "Partition.h"

class CutSearchPartition : public Partition
{
public:
    CutSearchPartition()
        : m_lanCount(0)
        , m_finalCount(0)
    {
    }

    std::auto_ptr<Partition> clone()
    {
        return std::auto_ptr<Partition>(new CutSearchPartition(*this));
    }

    virtual void addLan()
    {
    }

    virtual void partition(std::vector<int> & indexes,
                           std::vector<int> & neighbors,
                           std::vector<int> & weights,
                           std::vector<int> & partitions)
    {
        m_lanCount = static_cast<int>(indexes.size() - 1);
        partitions.resize(indexes.size() - 1);
        fill(partitions.begin(), partitions.end(), 0);
        int limit = static_cast<int>(sqrt(m_lanCount));
        double bestScore = 1e37;
        int bestCount = 1;

        std::vector<int> current;
        current.resize(partitions.size());
        double currentScore = 0;

        for (int i = 2; i < limit; ++i)
        {
            int partitionCount = i;
            int temp = Partition::partitionN(partitionCount, indexes,
                                             neighbors, weights,
                                             current);
            partitionCount = Partition::makeConnectedGraph(partitionCount,
                                                           indexes, neighbors,
                                                           weights,
                                                           current);
            currentScore = static_cast<double>(temp) / partitionCount;
            if (currentScore < bestScore)
            {
                bestCount = partitionCount;
                bestScore = currentScore;
                partitions = current;
                std::cerr << "NewBest: " << i << ":" << partitionCount
                          << std::endl;
            }
        }
        m_finalCount = bestCount;
    }

    virtual int getPartitionCount(void)
    {
        return m_finalCount;
    }
private:
    int m_lanCount;
    int m_finalCount;
};

#endif


