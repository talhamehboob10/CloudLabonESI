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

// Sensor.h

// This is the abstract base class for all of the individual
// measurement code, filters, and others. It includes code which
// allows a Sensor to represent a polymorphic list.

#ifndef SENSOR_H_STUB_2
#define SENSOR_H_STUB_2

#include "log.h"

class Sensor
{
public:
  Sensor();
  virtual ~Sensor();
  Sensor * getTail(void);
  void addNode(std::auto_ptr<Sensor> node);
  void capturePacket(PacketInfo * packet);
  bool isSendValid(void) const;
  bool isAckValid(void) const;
private:
  std::auto_ptr<Sensor> next;
protected:
  virtual void localSend(PacketInfo * packet)=0;
  virtual void localAck(PacketInfo * packet)=0;
protected:
  // This is used for functions which only yield data on a send.
  bool sendValid;
  // This is used for functions which only yield data on an ack.
  bool ackValid;
};

class NullSensor : public Sensor
{
public:
  NullSensor();
  virtual ~NullSensor();
protected:
  virtual void localSend(PacketInfo *);
  virtual void localAck(PacketInfo * packet);
  
  // This is used to detect packets that we see in a different order than
  // the appeared on the wire
  Time lastPacketTime;

};

#endif
