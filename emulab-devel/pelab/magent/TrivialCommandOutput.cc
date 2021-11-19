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

// TrivialCommandOutput.cc

#include "lib.h"
#include "TrivialCommandOutput.h"
#include "CommandInput.h"

using namespace std;

TrivialCommandOutput::TrivialCommandOutput()
  : start(0)
  , end(0)
{
}

TrivialCommandOutput::~TrivialCommandOutput()
{
}

int TrivialCommandOutput::startMessage(int size)
{
  attemptWrite();
  if (start == end && global::input->getMonitorSocket() != -1)
  {
    partial.resize(size);
    start = 0;
    end = 0;
    return SENDING_MESSAGE;
  }
  else
  {
    return DISCARDING_MESSAGE;
  }
}

void TrivialCommandOutput::endMessage(void)
{
  attemptWrite();
}

void TrivialCommandOutput::writeMessage(char const * message, int count)
{
  if (end + count <= partial.size())
  {
    memcpy(& partial[end], message, count);
    end += count;
  }
}

void TrivialCommandOutput::attemptWrite(void)
{
  if (start < end)
  {
    int fd = global::input->getMonitorSocket();
    if (fd == -1)
    {
      logWrite(ROBUST, "Unable to write because there is no connection to "
               "the monitor");
      return;
    }
    int error = send(fd, & partial[start], end - start, 0);
    if (error > 0)
    {
      start += error;
    }
    else if (error == -1)
    {
      switch(errno)
      {
      case EBADF:
      case EINVAL:
        logWrite(ERROR, "Problem with descriptor on command channel: %s",
                 strerror(errno));
        break;
      case EAGAIN:
      case EINTR:
        break;
      default:
        logWrite(EXCEPTION, "Failed write on command channel: %s",
                 strerror(errno));
        break;
      }
    }
    else
    {
      // error == 0. This means that the connection has gone away.
      global::input->disconnect();
      partial.resize(0);
      start = 0;
      end = 0;
      logWrite(ROBUST, "Command channel was closed from the other side.");
    }
  }
}
