#
# Copyright (c) 2000-2018 University of Utah and the Flux Group.
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
SRCDIR		= ../../../../clientside/os/dijkstra
TESTBED_SRCDIR	= ../../../..
OBJDIR		= ../../..
SUBDIR		= $(subst $(TESTBED_SRCDIR)/,,$(SRCDIR))

include $(OBJDIR)/Makeconf

CXXFLAGS	= -Wall -O2 -I/usr/local/include -ftemplate-depth-40 -g
CXXFLAGS	+= $(LDSTATIC)

all:	dijkstra

include $(TESTBED_SRCDIR)/GNUmakerules

dijkstra-debug: Compressor.o TreeCompressor.o dijkstra.o \
                NoneCompressor.o VoteIpTree.o SingleSource.o \
                OptimalIpTree.o bitmath.o \
                Compressor.h OptimalIpTree.h VoteIpTree.h \
                Exception.h SetIterator.h bitmath.h \
                IpTree.h SingleSource.h dijkstra.h \
                NoneCompressor.h TreeCompressor.h lib.h

	$(CXX) $(CXXFLAGS) Compressor.o TreeCompressor.o dijkstra.o \
                NoneCompressor.o VoteIpTree.o SingleSource.o \
                OptimalIpTree.o bitmath.o $(LIBS) -o $@

boss-install:
control:
control-install:
subboss:
subboss-install:
client: all
client-install: client
	$(INSTALL_PROGRAM) dijkstra$(EXE) $(DESTDIR)$(CLIENT_BINDIR)/dijkstra$(EXE)

clean:
	rm -f *.o dijkstra

