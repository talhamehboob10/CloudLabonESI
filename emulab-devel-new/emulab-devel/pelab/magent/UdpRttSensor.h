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

#ifndef UDP_RTT_SENSOR_PELAB_H
#define UDP_RTT_SENSOR_PELAB_H

#include "lib.h"
#include "Sensor.h"
#include "UdpPacketSensor.h"

class UdpPacketInfo;
class equalSeqNum;
class Sensor;
class UdpPacketSensor;

class UdpRttSensor:public Sensor{
	public:

		explicit UdpRttSensor(UdpPacketSensor const *packetHistoryVal);
		~UdpRttSensor();


		void localSend(PacketInfo *packet);
		void localAck(PacketInfo *packet);
		unsigned long long getRtt() const;
		unsigned long long getDevRtt() const;

	private:
		unsigned long long ewmaRtt, ewmaDevRtt;
		UdpPacketSensor const *packetHistory;
};

#endif
