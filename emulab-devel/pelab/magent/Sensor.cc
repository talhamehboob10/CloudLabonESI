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

// Sensor.cc

#include "lib.h"
#include "Sensor.h"

using namespace std;

Sensor::Sensor()
  : sendValid(false)
  , ackValid(false)
{
}

Sensor::~Sensor()
{
}

Sensor * Sensor::getTail(void)
{
  if (next.get() == NULL)
  {
    return this;
  }
  else
  {
    return next->getTail();
  }
}

void Sensor::addNode(auto_ptr<Sensor> node)
{
  if (next.get() == NULL)
  {
    next = node;
  }
  else
  {
    logWrite(ERROR, "Sensor::addNode(): A list tail was asked to add a node.");
  }
}

void Sensor::capturePacket(PacketInfo * packet)
{
  if (packet->packetType == PACKET_INFO_SEND_COMMAND)
  {
    localSend(packet);
  }
  else if (packet->packetType == PACKET_INFO_ACK_COMMAND)
  {
    localAck(packet);
  } else {
    logWrite(ERROR,"Sensor::capturePacket() got unexpected packet type %d",
             packet->packetType);
  }
  if (next.get() != NULL)
  {
    next->capturePacket(packet);
  }
}

bool Sensor::isSendValid(void) const
{
  return sendValid;
}

bool Sensor::isAckValid(void) const
{
  return ackValid;
}


NullSensor::NullSensor() : lastPacketTime()
{
}

NullSensor::~NullSensor()
{
}

void NullSensor::localSend(PacketInfo * packet)
{
  ackValid = false;
  sendValid = true;
  logWrite(SENSOR, "----------------------------------------");
  logWrite(SENSOR, "Stream ID: %s", packet->elab.toString().c_str());
  logWrite(SENSOR, "Send received: Time: %f", packet->packetTime.toDouble());
  if (packet->packetTime < lastPacketTime) {
    logWrite(EXCEPTION,"Reordered packets! Old %f New %f",lastPacketTime.toDouble(),
            packet->packetTime.toDouble());
  }
  lastPacketTime = packet->packetTime;
}

void NullSensor::localAck(PacketInfo * packet)
{
  sendValid = false;
  ackValid = true;
  logWrite(SENSOR, "----------------------------------------");
  logWrite(SENSOR, "Stream ID: %s", packet->elab.toString().c_str());
  logWrite(SENSOR, "Ack received: Time: %f", packet->packetTime.toDouble());
  if(packet->transport == TCP_CONNECTION)
  {
    list<Option>::iterator pos = packet->tcpOptions->begin();
    list<Option>::iterator limit = packet->tcpOptions->end();
    for (; pos != limit; ++pos)
    {
      logWrite(SENSOR, "TCP Option: %d", pos->type);
    }
  }
  if (packet->packetTime < lastPacketTime) {
    logWrite(EXCEPTION,"Reordered packets! Old %f New %f",lastPacketTime.toDouble(),
            packet->packetTime.toDouble());
  }
  lastPacketTime = packet->packetTime;
}
