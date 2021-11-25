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

#include "stub.h"
#include "log.h"

static FILE * logFile;
static int logFlags;
static int logTimestamp;

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
    logTimestamp = useTimestamp;
  }
}

void logCleanup(void)
{
}

// Print the timestamp and type of logging to the logFile.
static void logPrefix(int flags, struct timeval const * timestamp)
{
  if (flags & CONTROL_SEND)
  {
    fprintf(logFile, "CONTROL_SEND ");
  }
  if (flags & CONTROL_RECEIVE)
  {
    fprintf(logFile, "CONTROL_RECEIVE ");
  }
  if (flags & TCPTRACE_SEND)
  {
    fprintf(logFile, "TCPTRACE_SEND ");
  }
  if (flags & TCPTRACE_RECEIVE)
  {
    fprintf(logFile, "TCPTRACE_RECEIVE ");
  }
  if (flags & SNIFF_SEND)
  {
    fprintf(logFile, "SNIFF_SEND ");
  }
  if (flags & SNIFF_RECEIVE)
  {
    fprintf(logFile, "SNIFF_RECEIVE ");
  }
  if (flags & PEER_WRITE)
  {
    fprintf(logFile, "PEER_WRITE ");
  }
  if (flags & PEER_READ)
  {
    fprintf(logFile, "PEER_READ ");
  }
  if (flags & MAIN_LOOP)
  {
    fprintf(logFile, "MAIN_LOOP ");
  }
  if (flags & LOOKUP_DB)
  {
    fprintf(logFile, "LOOKUP_DB ");
  }
  if (flags & DELAY_DETAIL)
  {
      fprintf(logFile, "DELAY_DETAIL ");
  }
  if (flags & PACKET_BUFFER_DETAIL)
  {
      fprintf(logFile, "PACKET_BUFFER_DETAIL ");
  }
  if (logTimestamp)
  {
    struct timeval now;
    struct timeval const * timeptr = timestamp;
    if (timeptr == NULL)
    {
      gettimeofday(&now, NULL);
      timeptr = &now;
    }
    fprintf(logFile, "%f ", (double)(timeptr->tv_sec) +
            ((timeptr->tv_usec)/1000)/1000.0);
  }
  fprintf(logFile, ": ");
}

void logWrite(int flags, struct timeval const * timestamp,
              char const * format, ...)
{
  va_list va;
  va_start(va, format);
  if ((flags & logFlags) != 0)
  {
    logPrefix(flags & logFlags, timestamp);
    vfprintf(logFile, format, va);
    fprintf(logFile, "\n");
  }
  va_end(va);
}
