#
# Copyright (c) 2004, 2005 University of Utah and the Flux Group.
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

SRCDIR		= ../../../mote/sgtools
TESTBED_SRCDIR	= ../../..
OBJDIR		= ../..
SUBDIR		= mote/sgtools

include $(OBJDIR)/Makeconf

OBJS=SGGPIO.o

all client: motepower moteleds wagthedog

include $(TESTBED_SRCDIR)/GNUmakerules

motepower-debug: motepower.o $(OBJS)
	$(CXX) $(CXXFLAGS) -static -o $@ $^

moteleds-debug: moteleds.o $(OBJS)
	$(CXX) $(CXXFLAGS) -static -o $@ $^

wagthedog-debug: wagthedog.o $(OBJS)
	$(CXX) $(CXXFLAGS) -static -o $@ $^

client-install: client
	$(INSTALL) -m 755 -d $(DESTDIR)$(CLIENT_BINDIR)
	$(INSTALL_PROGRAM) moteleds \
		$(DESTDIR)$(CLIENT_BINDIR)/moteleds
	$(INSTALL_PROGRAM) wagthedog \
		$(DESTDIR)$(CLIENT_BINDIR)/wagthedog

clean:
	rm -f $(OBJS) motepower moteleds wagthedog
