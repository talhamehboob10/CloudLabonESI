
# Copyright (c) 2000-2016 University of Utah and the Flux Group.
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
SRCDIR		= ../../../protogeni/event
TESTBED_SRCDIR	= ../../..
OBJDIR		= ../..
SUBDIR		= $(subst $(TESTBED_SRCDIR)/,,$(SRCDIR))
SYSTEM	       := $(shell uname -s)

PROGRAMS	= igevent_daemon
PGLIBSCRIPTS    = 

include $(OBJDIR)/Makeconf

all:	$(PROGRAMS) igevent_debug.pl

include $(TESTBED_SRCDIR)/GNUmakerules

control-install:

install:	$(INSTALL_DIR)/sbin/protogeni/igevent_daemon

clean:
	/bin/rm -f *.o $(PROGRAMS) igevent_debug.pl

$(INSTALL_SBINDIR)/protogeni/%: %
	@echo "Installing $<"
	-mkdir -p $(INSTALL_SBINDIR)/protogeni
	$(INSTALL) $< $@

