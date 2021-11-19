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

#ifndef UDP_STATE_PELAB_H
#define UDP_STATE_PELAB_H

#include "UdpLibs.h"
#include "UdpPacketInfo.h"

using namespace std;

class UdpPacketInfo;

class UdpState{
	public:
	// vector of info about packets sent from this host,
        // sequence number, timestamp & size of the packet.
	vector< UdpPacketInfo > currentAckedPackets;

	// Indicates the number of packets lost -
	// updated whenever an ACK is received.
	int packetLoss;

	// This is the total number of packets lost till now for the connection.
	int totalPacketLoss;

	// Did we drop any packets in libpcap ?
	// This number only indicates the number of sent packets that
	// were dropped in pcap buffer - based on the differences between
	// the sequence numbers seen.
	int libpcapSendLoss;

	unsigned long long minDelay;
	unsigned long long maxDelay;

	bool ackError, isAckFake;

	UdpState()
		:packetLoss(0),
		totalPacketLoss(0),
		libpcapSendLoss(0)
	{

	}

	void reset()
	{
		packetLoss = 0;
		totalPacketLoss = 0;
		libpcapSendLoss = 0;

		ackError = false;
		isAckFake = false;

	}

	~UdpState()
	{
		// Remove any packets stored in the vector.
		currentAckedPackets.clear();
	}
};

class equalSeqNum:public binary_function<UdpPacketInfo , unsigned short int, bool> {
        public:
        bool operator()(const UdpPacketInfo& packet, unsigned short int seqNum) const
        {
                return (packet.seqNum == seqNum);
        }
};

class lessSeqNum:public binary_function<UdpPacketInfo , unsigned short int, bool> {
        public:
        bool operator()(const UdpPacketInfo& packet,unsigned short int seqNum) const
        {
                return (packet.seqNum < seqNum);
        }
};


#endif
