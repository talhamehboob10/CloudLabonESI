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

// log.c

#include "lib.h"
#include "log.h"

static FILE * logFile;
static int logFlags;
static int logTimestamp;
static int startSeconds;

void logInit(FILE * destFile, int flags, int useTimestamp)
{
  if (destFile == NULL || flags == LOG_NOTHING)
  {
    logFile = NULL;
    logFlags = LOG_NOTHING;
    logTimestamp = 0;
  }
  else
  {
    logFile = destFile;
    logFlags = flags;
    if ((logFlags & SENSOR_COMPLETE) != 0)
    {
      logFlags = logFlags | SENSOR_DETAIL | SENSOR;
    }
    else if ((logFlags & SENSOR_DETAIL) != 0)
    {
      logFlags = logFlags | SENSOR;
    }
    logTimestamp = useTimestamp;
    struct timeval now;
    gettimeofday(&now, NULL);
    startSeconds = now.tv_sec;
  }
}

void logCleanup(void)
{
}

// Print the timestamp and type of logging to the logFile.
static void logPrefix(int which)
{
  char * messageClass = "LOG_ERROR ";
  switch(which)
  {
  case ERROR:
    messageClass = "ERROR ";
    break;
  case EXCEPTION:
    messageClass = "EXCEPTION ";
    break;
  case PEER_CYCLE:
    messageClass = "PEER_CYCLE ";
    break;
  case SENSOR_COMPLETE:
  case SENSOR_DETAIL:
  case SENSOR:
    messageClass = "SENSOR ";
    break;
  case CONNECTION_MODEL:
    messageClass = "CONNECTION_MODEL ";
    break;
  case ROBUST:
    messageClass = "ROBUST ";
    break;
  case MAIN_LOOP:
    messageClass = "MAIN_LOOP ";
    break;
  case COMMAND_INPUT:
    messageClass = "COMMAND_INPUT ";
    break;
  case CONNECTION:
    messageClass = "CONNECTION ";
    break;
  case PCAP:
    messageClass = "PCAP ";
    break;
  case COMMAND_OUTPUT:
    messageClass = "COMMAND_OUTPUT ";
    break;
  case REPLAY:
    messageClass = "REPLAY ";
    break;
  default:
    messageClass = "LOG_ERROR ";
    break;
  }
  if (logTimestamp)
  {
    struct timeval now;
    gettimeofday(&now, NULL);
    fprintf(logFile, "\n%s %f: ", messageClass,
            (double)(now.tv_sec) + ((now.tv_usec)/1000)/1000.0);
  }
  else
  {
    fprintf(logFile, "\n%s: ", messageClass);
  }
}

void logWrite(int flags, char const * format, ...)
{
  va_list va;
  va_start(va, format);
  if ((flags & logFlags) != 0)
  {
    logPrefix(flags & logFlags);
    vfprintf(logFile, format, va);
  }
  va_end(va);
}
