#
# Copyright (c) 2000-2004, 2007 University of Utah and the Flux Group.
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
SRCDIR		= ../../../cdrom/tbbootconfig
TESTBED_SRCDIR	= ../../..
EVENTSYS	= 1
OBJDIR		= ../..
SUBDIR		= cdrom/tbbootconfig

include $(OBJDIR)/Makeconf

all:	tbbootconfig

include $(TESTBED_SRCDIR)/GNUmakerules

CFLAGS	+= -O -g -Wall -I${OBJDIR} 
LFLAGS  += -lz

tbbootconfig: tbbootconfig.c
	$(CC) $(CFLAGS) $(LDSTATIC) -g -o tbbootconfig $< $(LFLAGS)

client: tbbootconfig

client-install: client
	$(INSTALL_PROGRAM) tbbootconfig $(DESTDIR)$(CLIENT_BINDIR)

clean:
	rm -f *.o core tbbootconfig version.c
