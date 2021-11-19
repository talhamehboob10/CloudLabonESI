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

// KernelTcp.h

#ifndef KERNEL_TCP_H_PELAB_2
#define KERNEL_TCP_H_PELAB_2

#include "ConnectionModel.h"

enum ConnectionState
{
  DISCONNECTED,
  CONNECTED
};


class KernelTcp : public ConnectionModel
{
public:
  KernelTcp();
  virtual ~KernelTcp();
  virtual std::auto_ptr<ConnectionModel> clone(void);
  virtual void connect(PlanetOrder & planet);
  virtual void addParam(ConnectionModelCommand const & param);
  virtual int writeMessage(int size, WriteResult & result);
  virtual bool isConnected(void);

  int getSock(void) const;
private:
  int writeTcpMessage(int size, WriteResult & result);
  int writeUdpMessage(int size, WriteResult & result);
private:
  ConnectionState state;
  // Udp - CHANGES - Begin
  unsigned short udpCurSeqNum;
  struct sockaddr_in udpLocalAddr;
  // Udp - CHANGES - End
  int peersock;
  int sendBufferSize;
  int receiveBufferSize;
  int maxSegmentSize;
  int useNagles;
private:
  Time debugPrevTime;
  int debugByteCount;
public:
  static pcap_t * pcapDescriptor;
  static int pcapfd;
  static char udpPacketBuffer[66000];
  static void init(void);
  static void addNewPeer(fd_set * readable);
  static void readFromPeers(fd_set * readable);
  static void packetCapture(fd_set * readable);
};

#endif
