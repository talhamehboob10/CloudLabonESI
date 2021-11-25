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

#include "UdpLossSensor.h"

using namespace std;

UdpLossSensor::UdpLossSensor(UdpPacketSensor const *packetHistoryVal, UdpRttSensor const *rttSensorVal)
	: packetLoss(0),
	totalLoss(0),
	packetHistory(packetHistoryVal),
	rttSensor(rttSensorVal)
{
}

UdpLossSensor::~UdpLossSensor()
{

}


void UdpLossSensor::localSend(PacketInfo *packet)
{

}

void UdpLossSensor::localAck(PacketInfo *packet)
{
	 // This is a re-ordered ACK - don't do anything
	// with it - just return.
	if( packetHistory->isAckValid() == false )
	{
		ackValid = false;
		return;
	}

        unsigned short int seqNum = *(unsigned short int *)(packet->payload + 1);

	list<UdpPacketInfo>& unAckedPackets = (const_cast<UdpPacketSensor *>(packetHistory))->getUnAckedPacketList();
        list<UdpPacketInfo>::iterator vecIterator = unAckedPackets.begin();
	list<UdpPacketInfo>::iterator tempIterator;
	unsigned long long ewmaRtt = rttSensor->getRtt();
	unsigned long long ewmaDevRtt = rttSensor->getDevRtt();

	unsigned long long timeStamp = packet->packetTime.toMicroseconds();

	while(vecIterator != unAckedPackets.end())
	{
		if(seqNum > ((*vecIterator).seqNum + 10) || ( timeStamp > (*vecIterator).timeStamp + 10*( ewmaRtt + 4*ewmaDevRtt)) )
		{
			logWrite(SENSOR,"UDP_LOSS_SENSOR: Lost packet seqNum=%d", (*vecIterator).seqNum);
			tempIterator = vecIterator;
			vecIterator++;
			unAckedPackets.erase(tempIterator);
			packetLoss++;
		}
		else
			vecIterator++;

	}
}

long UdpLossSensor::getPacketLoss() const
{
	return packetLoss;
}

long UdpLossSensor::getTotalPacketLoss() const
{
	return totalLoss;
}

void UdpLossSensor::resetLoss()
{
	totalLoss += packetLoss;
	packetLoss = 0;
}
