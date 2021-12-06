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

#ifndef UDP_MAX_DELAY_SENSOR_PELAB_H
#define UDP_MAX_DELAY_SENSOR_PELAB_H

#include "lib.h"
#include "UdpPacketSensor.h"
#include "UdpMinDelaySensor.h"
#include "UdpLossSensor.h"
#include "Sensor.h"

class Sensor;
class UdpPacketSensor;
class UdpMinDelaySensor;
class UdpLossSensor;
struct UdpPacketInfo;

class UdpMaxDelaySensor:public Sensor{
	public:

		explicit UdpMaxDelaySensor(UdpPacketSensor const *udpPacketSensorVal, UdpMinDelaySensor const *minDelaySensorVal, UdpLossSensor const *lossSensorVal);
		~UdpMaxDelaySensor();


		void localSend(PacketInfo *packet);
		void localAck(PacketInfo *packet);

	private:
		unsigned long long maxDelay;
		unsigned long long sentDelay;
		UdpPacketSensor const *packetHistory;
		UdpMinDelaySensor const *minDelaySensor;
		UdpLossSensor const *lossSensor;
};

#endif
