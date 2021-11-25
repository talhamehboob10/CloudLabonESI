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

// DirectInput.h

#ifndef DIRECT_INPUT_H_STUB_2
#define DIRECT_INPUT_H_STUB_2

#include "CommandInput.h"
#include "saveload.h"

class DirectInput : public CommandInput
{
public:
  DirectInput();
  virtual ~DirectInput();
  virtual void nextCommand(fd_set * readable);
  virtual int getMonitorSocket(void);
  virtual void disconnect(void);
  int checksum(void);
private:
  enum MonitorState
  {
    ACCEPTING,
    HEADER_PREFIX,
    HEADER,
    BODY
  };
private:
  MonitorState state;
  int monitorAccept;
  int monitorSocket;
  int index;
  char headerBuffer[Header::maxHeaderSize];
  int versionSize;
  Header commandHeader;
  enum { bodyBufferSize = 0xffff };
  char bodyBuffer[bodyBufferSize];
};

#endif
