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

// Command.cc

#include "lib.h"
#include "Command.h"
#include "Sensor.h"
#include "Connection.h"
#include "ConnectionModel.h"
#include "TrafficModel.h"
#include "CircularTraffic.h"

using namespace std;

void NewConnectionCommand::run(std::multimap<Time, Connection *> &)
{
  logWrite(COMMAND_INPUT, "Running NEW_CONNECTION_COMMAND: %s",
           key.toString().c_str());
  std::map<ElabOrder, Connection>::iterator pos
    = global::connections.find(key);
  if (pos == global::connections.end())
  {
    pos = global::connections.insert(make_pair(key, Connection())).first;
    pos->second.reset(key, global::connectionModelExemplar->clone(),
                      transport);
  }
}

void NewConnectionCommand::runConnect(Connection *,
                          std::multimap<Time, Connection *> &)
{
}

//-----------------------

void TrafficModelCommand::runConnect(Connection * conn,
                          std::multimap<Time, Connection *> &)
{
  logWrite(COMMAND_INPUT, "Running TRAFFIC_MODEL_COMMAND: %s",
           key.toString().c_str());
  std::auto_ptr<TrafficModel> model(new CircularTraffic());
  conn->setTraffic(model);
}

//-----------------------

void ConnectionModelCommand::runConnect(Connection * conn,
                          std::multimap<Time, Connection *> &)
{
  logWrite(COMMAND_INPUT, "Running CONNECTION_MODEL_COMMAND: %s",
           key.toString().c_str());
  conn->addConnectionModelParam(*this);
}

//-----------------------

void SensorCommand::runConnect(Connection * conn,
                          std::multimap<Time, Connection *> &)
{
  logWrite(COMMAND_INPUT, "Running SENSOR_COMMAND: %s",
           key.toString().c_str());
  conn->addSensor(*this);
}

//-----------------------

void ConnectCommand::runConnect(Connection * conn,
                          std::multimap<Time, Connection *> &)
{
  logWrite(COMMAND_INPUT, "Running CONNECT_COMMAND: %s",
           key.toString().c_str());
  conn->connect(ip);
}

//-----------------------

void TrafficWriteCommand::runConnect(Connection * conn,
                          std::multimap<Time, Connection *> & schedule)
{
//  logWrite(COMMAND_INPUT, "Running TRAFFIC_WRITE_COMMAND");
  conn->addTrafficWrite(*this, schedule);
}

//-----------------------

void DeleteConnectionCommand::run(std::multimap<Time, Connection *> & schedule)
{
  logWrite(COMMAND_INPUT, "Running DELETE_CONNECTION_COMMAND: %s",
           key.toString().c_str());
  std::map<ElabOrder, Connection>::iterator pos
    = global::connections.find(key);
  if (pos != global::connections.end())
  {
    pos->second.cleanup(schedule);
    global::connections.erase(pos);
  }
}

void DeleteConnectionCommand::runConnect(Connection * conn,
                          std::multimap<Time, Connection *> &)
{
}
