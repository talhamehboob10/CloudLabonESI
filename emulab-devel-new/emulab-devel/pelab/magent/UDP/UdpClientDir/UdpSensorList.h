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

#ifndef _UDP_SENSORLIST_PELAB_H
#define _UDP_SENSORLIST_PELAB_H
#include "UdpLibs.h"
#include "UdpSensor.h"
#include "UdpPacketSensor.h"
#include "UdpThroughputSensor.h"
#include "UdpMinDelaySensor.h"
#include "UdpMaxDelaySensor.h"
#include "UdpRttSensor.h"
#include "UdpLossSensor.h"
#include "UdpAvgThroughputSensor.h"

class UdpSensor;
class UdpPacketSensor;
class UdpThroughputSensor;
class UdpMinDelaySensor;
class UdpMaxDelaySensor;
class UdpRttSensor;
class UdpLossSensor;
class UdpAvgThroughputSensor;

class UdpSensorList {
	public:
	explicit UdpSensorList(ofstream &logStreamVal);
	~UdpSensorList();

	void addSensor(int);
	void capturePacket(char *packetData, int Len, int overheadLen, unsigned long long timeStamp, int packetDirection);
	void reset();
	void testFunc();

	private:
	void pushSensor(UdpSensor *);
	void addPacketSensor();
	void addThroughputSensor();
	void addMinDelaySensor();
	void addMaxDelaySensor();
	void addRttSensor();
	void addLossSensor();
	void addAvgThroughputSensor();

	UdpSensor *sensorListHead;
        UdpSensor *sensorListTail;

	UdpState udpStateInfo;
	ofstream &logStream;

	UdpPacketSensor *depPacketSensor;
	UdpThroughputSensor *depThroughputSensor;
	UdpMinDelaySensor *depMinDelaySensor;
	UdpMaxDelaySensor *depMaxDelaySensor;
	UdpRttSensor *depRttSensor;
	UdpLossSensor *depLossSensor;
	UdpAvgThroughputSensor *depAvgThroughputSensor;
};


#endif
