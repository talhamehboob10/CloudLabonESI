#
# Copyright (c) 2000-2013 University of Utah and the Flux Group.
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
SRCDIR		= ../../ipod
TESTBED_SRCDIR	= ../..
OBJDIR		= ..
SUBDIR		= ipod

include $(OBJDIR)/Makeconf

all: ipod apod

# These binaries installed setuid, with sudo. 
SETUID_SBIN_PROGS    = ipod

include $(TESTBED_SRCDIR)/GNUmakerules

CFLAGS= -g -O2

ipod: ipod.c
	$(CC) $(CFLAGS) -o ipod $<

install: all $(INSTALL_SBINDIR)/ipod $(INSTALL_SBINDIR)/apod

post-install:

#
# Control node installation (okay, plastic)
#
control-install:
	@echo "No wrapper for IPOD yet"

clean:
	rm -f ipod apod
