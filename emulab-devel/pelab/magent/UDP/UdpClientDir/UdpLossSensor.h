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

#ifndef UDP_LOSS_SENSOR_PELAB_H
#define UDP_LOSS_SENSOR_PELAB_H

#include "UdpLibs.h"
#include "UdpState.h"
#include "UdpSensor.h"
#include "UdpPacketSensor.h"
#include "UdpRttSensor.h"

class UdpSensor;
class UdpPacketSensor;
class UdpRttSensor;

class UdpLossSensor:public UdpSensor{
	public:

		explicit UdpLossSensor(UdpPacketSensor *packetHistoryVal, UdpRttSensor *rttSensorVal, UdpState &udpStateVal, ofstream &logStreamVal);
		~UdpLossSensor();


		void localSend(char *packetData, int Len,int overheadLen, unsigned long long timeStamp);
		void localAck(char *packetData, int Len,int overheadLen, unsigned long long timeStamp);

		long getPacketLoss();
		void resetLoss();
		long totalLoss;
	private:
		long packetLoss;
		UdpState &udpStateInfo;
		ofstream &logStream;

		UdpPacketSensor *packetHistory;
		UdpRttSensor *rttSensor;
};

#endif
