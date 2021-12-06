/*
 * Copyright (c) 2006 University of Utah and the Flux Group.
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

// CircularTraffic.h

#ifndef CIRCULAR_TRAFFIC_H_STUB_2
#define CIRCULAR_TRAFFIC_H_STUB_2

#include "TrafficModel.h"

class CircularTraffic : public TrafficModel
{
public:
  enum { EXPIRATION_TIME = 500 }; // in milliseconds
public:
  CircularTraffic();
  virtual ~CircularTraffic();
  virtual std::auto_ptr<TrafficModel> clone(void);
  virtual Time addWrite(TrafficWriteCommand const & newWrite,
                        Time const & deadline);
  virtual void writeToPeer(ConnectionModel * peer,
                           Time const & previousTime,
                           WriteResult & result);
private:
  // Quick function to treat the writes list as though it were
  // circular
  std::list<TrafficWriteCommand>::iterator advance(
    std::list<TrafficWriteCommand>::iterator old);
private:
  std::list<TrafficWriteCommand>::iterator current;
  std::list<TrafficWriteCommand> writes;
  unsigned int nextWriteSize;
};

#endif
