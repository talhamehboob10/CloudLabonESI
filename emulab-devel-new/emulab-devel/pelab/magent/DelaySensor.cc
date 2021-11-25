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

// DelaySensor.cc

#include "lib.h"
#include "DelaySensor.h"
#include "PacketSensor.h"
#include "StateSensor.h"
#include "Time.h"
#include "TSThroughputSensor.h"

using namespace std;

DelaySensor::DelaySensor(PacketSensor const * newPacketHistory,
                         StateSensor const * newState)
  : state(newState)
{
  lastDelay = 0;
  packetHistory = newPacketHistory;
}

int DelaySensor::getLastDelay(void) const
{
  if (ackValid)
  {
    return lastDelay;
  }
  else
  {
    logWrite(ERROR,
             "DelaySensor::getLastDelay() called with invalid ack data");
    return 0;
  }
}

void DelaySensor::localSend(PacketInfo *)
{
  ackValid = false;
  sendValid = true;
}

void DelaySensor::localAck(PacketInfo * packet)
{
  sendValid = false;
  /*
   * According to RFC 2988, TCP MUST use Karn's algorithm for RTT
   * calculation, which means that it cannot use retransmitted packets to
   * caculate RTT (since it is ambiguous which of the two packets is being
   * ACKed) unless using TCP timestamps
   */
  if (state->isAckValid() && packetHistory->isAckValid()
      && !packetHistory->getIsRetransmit()
      && state->getState() == StateSensor::ESTABLISHED
      && (packetHistory->getRegionState() == PacketSensor::VALID_REGION
          || packetHistory->getRegionState()
                  == PacketSensor::BEGIN_VALID_REGION))
  {
    Time diff = packet->packetTime - packetHistory->getAckedSendTime();
    lastDelay = diff.toMilliseconds();
    // Failsafe - if this happens, we need to fix the cause, but in the
    // meantime, let's just make sure that it doesn't make it to the monitor
    if (lastDelay < 0) {
      logWrite(ERROR, "DelaySensor::localAck() Bogus delay %lli (%lli - %lli)", lastDelay,
              packet->packetTime.toMilliseconds(),
              packetHistory->getAckedSendTime().toMilliseconds());
      ackValid = false;
    } else {
      logWrite(SENSOR, "DELAY: %d ms", lastDelay);
      ackValid = true;
    }
  }
  else
  {
    ackValid = false;
  }
}
