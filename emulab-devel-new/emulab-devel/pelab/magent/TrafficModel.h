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

// TrafficModel.h

#ifndef TRAFFIC_MODEL_H_STUB_2
#define TRAFFIC_MODEL_H_STUB_2

class TrafficWriteCommand;
class ConnectionModel;

class TrafficModel
{
public:
  virtual ~TrafficModel() {}
  virtual std::auto_ptr<TrafficModel> clone(void)=0;
  virtual Time addWrite(TrafficWriteCommand const & newWrite,
                        Time const & deadline)=0;
  virtual void writeToPeer(ConnectionModel * peer,
                           Time const & previousTime,
                           WriteResult & result)=0;
};

class NullTrafficModel : public TrafficModel
{
public:
  virtual ~NullTrafficModel() {}
  virtual std::auto_ptr<TrafficModel> clone(void)
  {
    return std::auto_ptr<TrafficModel>(new NullTrafficModel());
  }
  virtual Time addWrite(TrafficWriteCommand const &,
                        Time const &)
  {
    return Time();
  }
  virtual void writeToPeer(ConnectionModel * peer,
                           Time const & previousTime,
                           WriteResult & result)
  {
    result.isConnected = false;
    result.bufferFull = false;
    result.nextWrite = Time();
  }
};

#endif
