#
# Copyright (c) 2005-2012 University of Utah and the Flux Group.
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

SRCDIR          = ../../../tools/whol
TESTBED_SRCDIR  = ../../..
OBJDIR          = ../..
SUBDIR          = tools/whol

include $(OBJDIR)/Makeconf

# These binaries installed setuid, with sudo. 
SETUID_SBIN_PROGS    = whol

# These scripts installed setuid, with sudo. 
SETUID_BIN_SCRIPTS   = 
SETUID_SBIN_SCRIPTS  =
SETUID_LIBX_SCRIPTS  =

all: whol

include $(TESTBED_SRCDIR)/GNUmakerules

whol: GNUmakefile whol.o
	$(CC) $(CFLAGS) $(LDFLAGS) whol.o -o whol
		cp whol whol.debug
		strip whol

whol.o: whol.c
	$(CC) -c -o whol.o $(CFLAGS) $<

install boss-install: $(INSTALL_SBINDIR)/whol
	@echo "Don't forget to do a post-install as root"

post-install: 
	chown root $(INSTALL_SBINDIR)/whol
	chmod u+s $(INSTALL_SBINDIR)/whol

clean:
	rm -f *.o core whol whol.debug
