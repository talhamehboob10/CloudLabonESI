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

// EwmaThroughputSensor.cc

#include "lib.h"
#include "EwmaThroughputSensor.h"
#include "ThroughputSensor.h"
#include "CommandOutput.h"
#include "StateSensor.h"

using namespace std;

EwmaThroughputSensor::EwmaThroughputSensor(
  ThroughputSensor const * newThroughputSource,
  StateSensor const * newState)
  : maxThroughput(0)
  , bandwidth(0.0)
  , throughputSource(newThroughputSource)
  , state(newState)
{
}

void EwmaThroughputSensor::localSend(PacketInfo * packet)
{
  ackValid = false;
  sendValid = true;
}

void EwmaThroughputSensor::localAck(PacketInfo * packet)
{
  sendValid = false;
  if (throughputSource->isAckValid() && state->isAckValid())
  {
    int latest = throughputSource->getThroughputInKbps();
    if (state->isSaturated())
    {
      // The link is saturated, so we know that the throughput
      // measurement is the real bandwidth.
      if (bandwidth == 0.0)
      {
        bandwidth = latest;
      }
      else
      {
        static const double alpha = 0.1;
        bandwidth = bandwidth*(1.0-alpha) + latest*alpha;
      }
      // We have got an actual bandwidth measurement, so reset
      // maxThroughput accordingly.
      maxThroughput = static_cast<int>(bandwidth);
      ostringstream buffer;
      buffer << static_cast<int>(bandwidth);
      global::output->genericMessage(AUTHORITATIVE_BANDWIDTH, buffer.str(),
                                     packet->elab);
    }
    else
    {
      // The link isn't saturated, so we don't know whether this
      // throughput measurement represents real bandwidth or not.
      if (latest > maxThroughput)
      {
        maxThroughput = latest;
        // Send out a tentative number
        ostringstream buffer;
        buffer << maxThroughput;
        global::output->genericMessage(TENTATIVE_THROUGHPUT, buffer.str(),
                                       packet->elab);
      }
    }
    ackValid = true;
  }
  else
  {
    ackValid = false;
  }
}
