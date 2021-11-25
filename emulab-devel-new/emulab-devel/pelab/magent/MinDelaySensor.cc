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

// MinDelaySensor.cc

#include "lib.h"
#include "MinDelaySensor.h"
#include "DelaySensor.h"
#include "CommandOutput.h"

using namespace std;

MinDelaySensor::MinDelaySensor(DelaySensor const * newDelay)
  : minimum(1000000, -0.01), minDelay(1000000), lastreported(-1)
{
  delay = newDelay;
}

int MinDelaySensor::getMinDelay(void) const
{
  if (ackValid)
  {
    return minDelay;
  }
  else
  {
    logWrite(ERROR,
             "MinDelaySensor::getMinDelay() called with invalid ack data");
    return 0;
  }
}

void MinDelaySensor::localSend(PacketInfo *)
{
  ackValid = false;
  sendValid = true;
}

void MinDelaySensor::localAck(PacketInfo * packet)
{
  sendValid = false;
  if (delay->isAckValid())
  {
    int current = delay->getLastDelay();
    int oneway = current / 2;
    if (current < minimum && oneway != lastreported)
    {
      minDelay = current;
      ostringstream buffer;
      buffer << "delay=" << oneway;
      minimum.reset(current);
      global::output->eventMessage(buffer.str(), packet->elab,
                                   CommandOutput::FORWARD_PATH);
      global::output->eventMessage(buffer.str(), packet->elab,
                                   CommandOutput::BACKWARD_PATH);
      lastreported = oneway;
    }
    else
    {
      minimum.decay();
    }
    logWrite(SENSOR_DETAIL,"MinDelaySensor::localAck() sez: cur=%i one=%i min=%i last=%i",
            current, oneway, minimum.get(), lastreported);
    ackValid = true;
  }
  else
  {
    ackValid = false;
  }
}
