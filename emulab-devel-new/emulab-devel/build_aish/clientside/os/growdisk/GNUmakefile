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
SRCDIR		= ../../../../clientside/os/growdisk
TESTBED_SRCDIR	= ../../../..
OBJDIR		= ../../..
SUBDIR		= $(subst $(TESTBED_SRCDIR)/,,$(SRCDIR))

include $(OBJDIR)/Makeconf

all:	growdisk

include $(TESTBED_SRCDIR)/GNUmakerules

CFLAGS = -O -g $(LDSTATIC) -I$(SRCDIR)/../imagezip

growdisk: growdisk.o
	$(CC) $(CFLAGS) growdisk.o -o growdisk
	cp growdisk growdisk.debug
	strip growdisk

install:

control:
control-install:
subboss:
subboss-install:

client: all
client-install: client
	$(INSTALL_PROGRAM) -s growdisk$(EXE) $(DESTDIR)$(CLIENT_BINDIR)$(EXE)

clean:
	rm -f *.o growdisk growdisk.debug
