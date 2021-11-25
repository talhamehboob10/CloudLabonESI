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

#ifndef UDP_AVG_THROUGHPUT_SENSOR_PELAB_H
#define UDP_AVG_THROUGHPUT_SENSOR_PELAB_H

#include "UdpLibs.h"
#include "UdpState.h"
#include "UdpSensor.h"
#include "UdpLossSensor.h"

class UdpSensor;
class UdpLossSensor;

class UdpAvgThroughputSensor:public UdpSensor{
	public:

		explicit UdpAvgThroughputSensor(UdpLossSensor *lossSensorVal, UdpState &udpStateVal, ofstream &logStreamVal);
		~UdpAvgThroughputSensor();
		void localSend(char *packetData, int Len, int overheadLen, unsigned long long timeStamp);
		void localAck(char *packetData, int Len,int overheadLen, unsigned long long timeStamp);

	private:
		void calculateTput(unsigned long long timeStamp);

		unsigned long long lastAckTime;
		UdpLossSensor *lossSensor;
		double throughputKbps;
		UdpState &udpStateInfo;
		ofstream &logStream;

		UdpAck ackList[100];
		int minSamples;
		int queuePtr;
};

#endif
