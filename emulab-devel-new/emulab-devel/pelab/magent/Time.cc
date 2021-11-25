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

// Time.cc

#include "lib.h"
#include "Time.h"

using namespace std;

Time::Time()
{
  data.tv_sec = 0;
  data.tv_usec = 0;
}

Time::Time(struct timeval const & newData)
{
  data = newData;
}

long long Time::toMilliseconds(void) const
{
  long long result = data.tv_sec * 1000 + data.tv_usec / 1000;
  return result;
}

// Udp - CHANGES - Begin
unsigned long long Time::toMicroseconds(void) const
{
  unsigned long long result_sec = data.tv_sec; 
  unsigned long long result_usec = data.tv_usec;
  unsigned long long result = result_sec*1000000 + result_usec;
  return result;
}
// Udp - CHANGES - End

double Time::toDouble(void) const
{
  double result = data.tv_sec + data.tv_usec / 1000000.0;
  return result;
}

struct timeval * Time::getTimeval(void)
{
  return &data;
}

struct timeval const * Time::getTimeval(void) const
{
  return &data;
}

Time Time::operator+(int const & right) const
{
  Time result;
  result.data.tv_sec = data.tv_sec + right/1000;
  result.data.tv_usec = data.tv_usec + (right%1000)*1000;
  if (result.data.tv_usec < 0)
  {
    --(result.data.tv_sec);
    result.data.tv_usec += 1000000;
  }
  if (result.data.tv_usec >= 1000000)
  {
    ++(result.data.tv_sec);
    result.data.tv_usec -= 1000000;
  }
  return result;
}

Time Time::operator-(Time const & right) const
{
  Time result;
  result.data.tv_sec = data.tv_sec - right.data.tv_sec;
  long usec = data.tv_usec - right.data.tv_usec;
  if (usec < 0)
  {
    --(result.data.tv_sec);
    usec += 1000000;
  }
  result.data.tv_usec = usec;
  return result;
}

bool Time::operator<(Time const & right) const
{
  return make_pair(data.tv_sec, data.tv_usec)
    < make_pair(right.data.tv_sec, right.data.tv_usec);
}

bool Time::operator>(Time const & right) const
{
  return make_pair(data.tv_sec, data.tv_usec)
    > make_pair(right.data.tv_sec, right.data.tv_usec);
}

bool Time::operator==(Time const & right) const
{
  return make_pair(data.tv_sec, data.tv_usec)
    == make_pair(right.data.tv_sec, right.data.tv_usec);
}

bool Time::operator!=(Time const & right) const
{
  return !(*this == right);
}

Time getCurrentTime(void)
{
  Time now;
  gettimeofday(now.getTimeval(), NULL);
  return now;
}
