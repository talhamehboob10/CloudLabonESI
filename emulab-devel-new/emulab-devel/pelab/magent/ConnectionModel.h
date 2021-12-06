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

// ConnectionModel.h

#ifndef CONNECTION_MODEL_H_PELAB_2
#define CONNECTION_MODEL_H_PELAB_2

class ConnectionModelCommand;

class ConnectionModel
{
public:
  virtual ~ConnectionModel() {}
  virtual std::auto_ptr<ConnectionModel> clone(void)=0;
  virtual void connect(PlanetOrder & planet)=0;
  virtual void addParam(ConnectionModelCommand const & param)=0;
  // Returns the number of bytes actually written or -1 if there was
  // an error. Errno is not preserved.
  virtual int writeMessage(int size, WriteResult & result)=0;
  virtual bool isConnected(void)=0;

  // These are static members which are used. They are called from
  // switch statements in main.cc
  // static void init(void);
  // static void addNewPeer(fd_set * readable);
  // static void readFromPeers(fd_set * readable);
  // static void packetCapture(fd_set * readable);
};

class ConnectionModelNull : public ConnectionModel
{
public:
  virtual ~ConnectionModelNull() {}
  virtual std::auto_ptr<ConnectionModel> clone(void)
  {
    return std::auto_ptr<ConnectionModel>(new ConnectionModelNull());
  }
  virtual void connect(PlanetOrder &) {}
  virtual void addParam(ConnectionModelCommand const &) {}

  static void init(void) {}
  static void addNewPeer(fd_set *) {}
  static void readFromPeers(fd_set *) {}
  static void packetCapture(fd_set *) {}
  virtual int writeMessage(int, WriteResult & result)
  {
    result.isConnected = false;
    result.bufferFull = false;
    return 0;
  }
  virtual int sendToMessage(int size, WriteResult & result)
  {
    result.isConnected = false;
    result.bufferFull = false;
    return 0;
  }
  virtual bool isConnected(void)
  {
    return false;
  }
};

#endif
