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

/*
 * TSThroughputSensor.h
 * NOTE: This file is very similar to ThroughputSensor.h - however, it uses
 * TCP timestamps, instead of packet times stamped by the kernel, for its
 * inter-packet timing mechanism
 * Technically, what we're doing here isn't legal - ie. the only thing you're
 * supposed to use TSVal for is to echo it back to the other side with your
 * ACKs. There are no universal units for TSVal, so we are relying on the other
 * side of the connections using the same units for timestamps
 */

#ifndef TSTHROUGHPUT_SENSOR_H_STUB_2
#define TSTHROUGHPUT_SENSOR_H_STUB_2

#include "Sensor.h"
#include "ThroughputSensor.h"

class PacketSensor;
class StateSensor;

class TSThroughputSensor : public Sensor
{
public:
  TSThroughputSensor(PacketSensor const * newPacketHistory,
                   StateSensor const * newState);
  int getThroughputInKbps(void) const;
  static int getThroughputInKbps(uint32_t period, int byteCount);
  uint32_t getLastPeriod(void) const;
  int getLastByteCount(void) const;
protected:
  virtual void localSend(PacketInfo * packet);
  virtual void localAck(PacketInfo * packet);
private:
//  int throughputInKbps;
  uint32_t lastPeriod;
  int lastByteCount;
  uint32_t lastAckTS;
  PacketSensor const * packetHistory;
  StateSensor const * state;
  int deferredBytes;
};

uint32_t findTcpTimestamp(PacketInfo * packet);

#endif
