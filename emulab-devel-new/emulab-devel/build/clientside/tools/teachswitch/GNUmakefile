#
# Copyright (c) 2003-2017 University of Utah and the Flux Group.
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

SRCDIR          = ../../../../clientside/tools/teachswitch
TESTBED_SRCDIR  = ../../../..
OBJDIR          = ../../..
SUBDIR          = $(subst $(TESTBED_SRCDIR)/,,$(SRCDIR))

include $(OBJDIR)/Makeconf

all: teachswitch

include $(TESTBED_SRCDIR)/GNUmakerules

teachswitch: GNUmakefile teachswitch.o
	$(CC) $(CFLAGS) $(LDFLAGS) teachswitch.o -o teachswitch
		cp teachswitch teachswitch.debug
		strip teachswitch

teachswitch.o: teachswitch.c
	$(CC) -c -o teachswitch.o $(CFLAGS) $<

client-install: teachswitch
	$(INSTALL_PROGRAM) teachswitch $(DESTDIR)$(CLIENT_BINDIR)

clean:
	rm -f *.o core teachswitch teachswitch.debug
