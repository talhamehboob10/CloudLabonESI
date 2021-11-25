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

// ThroughputSensor.h

// For every ack, this calculates the

#ifndef THROUGHPUT_SENSOR_H_STUB_2
#define THROUGHPUT_SENSOR_H_STUB_2

#include "Sensor.h"

class PacketSensor;
class StateSensor;

class ThroughputSensor : public Sensor
{
public:
  ThroughputSensor(PacketSensor const * newPacketHistory,
                   StateSensor const * newState);
  int getThroughputInKbps(void) const;
protected:
  virtual void localSend(PacketInfo * packet);
  virtual void localAck(PacketInfo * packet);
private:
  int throughputInKbps;
  int maxThroughput;
  Time lastAckTime;
  PacketSensor const * packetHistory;
  StateSensor const * state;
};

#endif
