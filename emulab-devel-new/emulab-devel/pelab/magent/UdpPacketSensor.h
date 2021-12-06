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

#ifndef UDP_PACKET_SENSOR_PELAB_H
#define UDP_PACKET_SENSOR_PELAB_H

#include "lib.h"
#include "Sensor.h"

class UdpPacketInfo;
class equalSeqNum;
class Sensor;


class UdpPacketSensor:public Sensor{

  public:

    UdpPacketSensor();
    ~UdpPacketSensor();
    void localSend(PacketInfo *packet);
    void localAck(PacketInfo *packet);
    bool isAckFake() const;
    int getPacketLoss() const;
    std::vector<UdpPacketInfo> getAckedPackets() const;
    //CHANGE:
    std::list<UdpPacketInfo>& getUnAckedPacketList();


  private:

    //CHANGE:
    bool handleReorderedAck(PacketInfo *packet);

    std::list<UdpPacketInfo> sentPacketList;
    std::vector< UdpPacketInfo > ackedPackets;
    //CHANGE:
    std::list<UdpPacketInfo> unAckedPacketList;

    long lastSeenSeqNum;
    int packetLoss;
    int totalPacketLoss;

    int libpcapSendLoss;
    //CHANGE:
    int statReorderedPackets;
    bool ackFake;


};


#endif
