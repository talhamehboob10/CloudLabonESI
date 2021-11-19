#
# Copyright (c) 2004 University of Utah and the Flux Group.
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

#
# These are the paths to the ARM cross-compiler on ibapah.flux.utah.edu -
# should put something more general here
#
CXX=/usr/local/arm/3.4.1/bin/arm-linux-g++
CXXFLAGS=-static
STRIP=/usr/local/arm/3.4.1/bin/arm-linux-strip
CC=/usr/local/arm/3.4.1/bin/arm-linux-gcc

OBJS=SGGPIO.o

all: motepower moteleds

motepower: motepower.C $(OBJS)
	$(CXX) $(CXXFLAGS) -o motepower motepower.C $(OBJS)
	$(STRIP) motepower

moteleds: moteleds.C $(OBJS)
	$(CXX) $(CXXFLAGS) -o moteleds moteleds.C $(OBJS)
	$(STRIP) moteleds



clean:
	rm -f $(OBJS) motepower moteleds
