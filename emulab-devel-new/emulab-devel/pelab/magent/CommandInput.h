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

// CommandInput.h

// This is the abstract base class for various kinds of control
// input. Each input is broken down into one of a number of
// commands. 'nextCommand' attempts to read enough bytes to make up
// the next command while 'getCommand' returns the current command or
// NULL if the previous 'nextCommand' had failed to acquire enough
// bytes.

#ifndef COMMAND_INPUT_H_STUB_2
#define COMMAND_INPUT_H_STUB_2

#include "Command.h"

class CommandInput
{
public:
  virtual ~CommandInput() {}
  virtual Command * getCommand(void)
  {
    return currentCommand.get();
  }
  virtual void nextCommand(fd_set * readable)=0;
  virtual int getMonitorSocket(void)=0;
  virtual void disconnect(void)=0;
protected:
  std::auto_ptr<Command> currentCommand;
};

class NullCommandInput : public CommandInput
{
public:
  virtual ~NullCommandInput() {}
  virtual void nextCommand(fd_set *) {}
  virtual int getMonitorSocket(void) { return -1; }
  virtual void disconnect(void) {}
};

#endif
