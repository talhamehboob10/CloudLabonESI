#
# Copyright (c) 2000-2002 University of Utah and the Flux Group.
# 
# {{{EMULAB-LICENSE
# 
# This file is part of the Emulab network testbed software.
# 
# This file is free software: you can redistribute it and/or modify it
# under the terms of the GNU Affero General Public License as published by
# the Free Software Foundation, either version 3 of the License, or (at
# your option) any later version.
# 
# This file is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
# FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Affero General Public
# License for more details.
# 
# You should have received a copy of the GNU Affero General Public License
# along with this file.  If not, see <http://www.gnu.org/licenses/>.
# 
# }}}
#

CC?=gcc
CFLAGS+= -Wall
CPPFLAGS+= -I.
LDFLAGS=
LIBS=

.c.o:
	$(CC) -c $(CFLAGS) $<

all: hmcd hmcdgrab

hmcd: hmcd.o hmcd.h
	$(CC) $(CFLAGS) $(LDFLAGS) -o $@ hmcd.o $(LIBS)

hmcdgrab: hmcdgrab.o hmcd.h
	$(CC) $(CFLAGS) $(LDFLAGS) -o $@ hmcd.o $(LIBS)

clean:
	rm -f *.o hmcd hmcdgrab *~
