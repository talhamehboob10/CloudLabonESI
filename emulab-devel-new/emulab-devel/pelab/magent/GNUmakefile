#
# Copyright (c) 2006 University of Utah and the Flux Group.
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

SRCS=$(wildcard *.cc)
OBJS=$(SRCS:.cc=.o)
HDRS=$(wildcard *.h)
DEPFILE=.depends
CXXFLAGS=-I. -Wall -g
LDFLAGS=-lm -lpcap
# Turn this on for profiling
#CXXFLAGS+=-pg

all: $(DEPFILE) magent

magent: $(OBJS)
	$(CXX) $(CXXFLAGS) $(LDFLAGS) -o $@ $^

$(DEPFILE): $(SRCS) $(HDRS)
	$(CXX) -MM $(SRCS) > $(DEPFILE)

clean:
	-rm magent $(OBJS) $(DEPFILE)

-include $(DEPFILE)
