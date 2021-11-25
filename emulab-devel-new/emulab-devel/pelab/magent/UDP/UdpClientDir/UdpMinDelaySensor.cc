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

#include "UdpMinDelaySensor.h"

UdpMinDelaySensor::UdpMinDelaySensor(UdpState &udpStateVal, ofstream &logStreamVal)
	: minDelay(ULONG_LONG_MAX),
	udpStateInfo(udpStateVal),
	logStream(logStreamVal)
{

}

UdpMinDelaySensor::~UdpMinDelaySensor()
{

}


void UdpMinDelaySensor::localSend(char *packetData, int Len,int overheadLen,unsigned long long timeStamp)
{
	// Do nothing.

}

void UdpMinDelaySensor::localAck(char *packetData, int Len,int overheadLen, unsigned long long timeStamp)
{
        if(Len < globalConsts::minAckPacketSize)
        {
                logStream << "ERROR::UDP packet data sent to MinDelaySensor::localAck was less than the "
                        " required minimum "<< globalConsts::minAckPacketSize << " bytes\n";
                return;
        }

	 // This is a re-ordered ACK - don't do anything
	// with it - just return.
	if( udpStateInfo.ackError == true )
		return;

	unsigned short int seqNum = *(unsigned short int *)(packetData + 1);
	unsigned short int echoedPacketSize = *(unsigned short int *)(packetData + 1 + globalConsts::USHORT_INT_SIZE);
	unsigned long long echoedTimestamp = *(unsigned long long *)(packetData + 1 + 2*globalConsts::USHORT_INT_SIZE + globalConsts::ULONG_LONG_SIZE);

	unsigned long long oneWayDelay;
	bool eventFlag = false;

	vector<UdpPacketInfo >::iterator vecIterator;
	vecIterator = find_if(udpStateInfo.currentAckedPackets.begin(), udpStateInfo.currentAckedPackets.end(), bind2nd(equalSeqNum(), seqNum));

	// Calculate the one way delay as half of RTT.

	// We lost this packet send time due to loss in libpcap, use the 
	// time echoed in the ACK packet.
	if(udpStateInfo.isAckFake == true)
		oneWayDelay = (timeStamp - echoedTimestamp)/2;
	else
		oneWayDelay = (timeStamp - (*vecIterator).timeStamp)/2;

	// Calculate the delay for the maximum sized packet.

	// We lost this packet size details due to loss in libpcap, use the 
	// size echoed in the ACK packet - this does not included the header
	// overhead for the packet - we assume that the packet on the reverse path
	// has the same overhead length as the original packet.
	if(udpStateInfo.isAckFake == true)
		oneWayDelay = ( oneWayDelay ) * 1518 / (echoedPacketSize);
	else
		oneWayDelay = ( oneWayDelay ) * 1518 / ( (*vecIterator).packetSize);

	// Set this as the new minimum one way delay.
	if(oneWayDelay < minDelay)
	{
		eventFlag = true;
		minDelay = oneWayDelay;
	}

	// We should not be calculating the minimum delay based on the
	// redundant ACKs - because we cannot exactly calculate their
	// RTT values, from just the receiver timestamps.

	// Send an event message to the monitor to change the value of minimum one way delay.
	if(eventFlag == true)
	{
		logStream << "VALUE::New Min delay = " << minDelay << "\n";
	}
	logStream << "MIND:TIME="<<timeStamp<<",MIND="<<minDelay<<endl;
	udpStateInfo.minDelay = minDelay;
}
