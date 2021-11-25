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

// ThroughputSensor.cc

#include "lib.h"
#include "ThroughputSensor.h"
#include "PacketSensor.h"
#include "StateSensor.h"

using namespace std;

ThroughputSensor::ThroughputSensor(PacketSensor const * newPacketHistory,
                                   StateSensor const * newState)
  : throughputInKbps(0)
  , maxThroughput(0)
  , packetHistory(newPacketHistory)
  , state(newState)
{
}

int ThroughputSensor::getThroughputInKbps(void) const
{
  if (ackValid)
  {
    return throughputInKbps;
  }
  else
  {
    logWrite(ERROR,
             "ThroughputSensor::getThroughputInKbps() "
             "called with invalid data");
    return 0;
  }
}

void ThroughputSensor::localSend(PacketInfo *)
{
  ackValid = false;
  sendValid = true;
}

void ThroughputSensor::localAck(PacketInfo * packet)
{
  sendValid = false;
  if (state->isAckValid() && packetHistory->isAckValid() &&
      state->getState() == StateSensor::ESTABLISHED)
  {
    ackValid = true;
    Time currentAckTime = packet->packetTime;
    if (lastAckTime != Time() && currentAckTime != lastAckTime)
    {
      // period is in seconds.
      double period = (currentAckTime - lastAckTime).toMilliseconds() / 1000.0;
      double kilobits = packetHistory->getAckedSize() * (8.0/1000.0);
      int latest = static_cast<int>(kilobits/period);
      if (state->isSaturated() || latest > maxThroughput)
      {
        throughputInKbps = latest;
        maxThroughput = latest;
        logWrite(SENSOR, "THROUGHPUT: %d kbps", throughputInKbps);
      }
    }
    else
    {
      throughputInKbps = 0;
      ackValid = false;
    }
    lastAckTime = currentAckTime;
  }
  else
  {
    throughputInKbps = 0;
    lastAckTime = Time();
    ackValid = false;
  }
}
