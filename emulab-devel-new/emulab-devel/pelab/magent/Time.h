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

// Time.h

#ifndef TIME_H_STUB_2
#define TIME_H_STUB_2

class Time
{
public:
  Time();
  Time(struct timeval const & newData);
  long long toMilliseconds(void) const;
  // Udp - CHANGES - Begin
  unsigned long long toMicroseconds(void) const;
  // Udp - CHANGES - End
  double toDouble(void) const;
  struct timeval * getTimeval(void);
  struct timeval const * getTimeval(void) const;
  Time operator+(int const & right) const;
  Time operator-(Time const & right) const;
  bool operator<(Time const & right) const;
  bool operator>(Time const & right) const;
  bool operator==(Time const & right) const;
  bool operator!=(Time const & right) const;
private:
  struct timeval data;
};

Time getCurrentTime(void);

#endif
