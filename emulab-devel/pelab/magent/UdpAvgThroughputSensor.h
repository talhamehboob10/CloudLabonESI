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

#include "lib.h"
#include "Sensor.h"
#include "UdpPacketSensor.h"
#include "UdpLossSensor.h"

class Sensor;
class UdpPacketSensor;
class UdpLossSensor;

struct UdpAck {
	unsigned long long timeTaken;
	long packetSize;
	unsigned short seqNum;
	bool isRedun;
	int numPackets;
};


class UdpAvgThroughputSensor:public Sensor{
	public:

		explicit UdpAvgThroughputSensor(UdpPacketSensor const *packetHistoryVal, UdpLossSensor const *lossSensorVal);
		~UdpAvgThroughputSensor();
		void localSend(PacketInfo *packet);
		void localAck(PacketInfo *packet);

	private:
		void calculateTput(unsigned long long timeStamp, PacketInfo *packet);

		UdpPacketSensor const *packetHistory;
		UdpLossSensor const *lossSensor;

		const static int MIN_SAMPLES = 5;
		const static int MAX_SAMPLES = 100;
		const static unsigned long long MAX_TIME_PERIOD = 500000;

		unsigned long long lastAckTime;
		double throughputKbps;
		int lastSeenThroughput;

		UdpAck ackList[MAX_SAMPLES];
		int numSamples;
		int queuePtr;
};

#endif
