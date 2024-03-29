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
SRCDIR		= ../../../../clientside/os/syncd
TESTBED_SRCDIR	= ../../../..
OBJDIR		= ../../..
SUBDIR		= $(subst $(TESTBED_SRCDIR)/,,$(SRCDIR))

include $(OBJDIR)/Makeconf

CFLAGS	= -Wall -O2 -g -I${OBJDIR} -I${TESTBED_LIBSRCDIR}/libtb
LIBS	= ${TESTBED_LIBOBJDIR}/libtb/libtb.a
LDFLAGS =
LDFLAGS  += $(LDSTATIC)

TESTS = $(SRCDIR)/syncd_test.sh

all:	emulab-syncd emulab-sync

include $(TESTBED_SRCDIR)/GNUmakerules

emulab-syncd-debug:	emulab-syncd.o version.o decls.h
	$(CC) $(CFLAGS) emulab-syncd.o version.o $(LDFLAGS) $(LIBS) -o $@

emulab-sync-debug:	emulab-sync.o version.o decls.h
	$(CC) $(CFLAGS) emulab-sync.o version.o $(LDFLAGS) $(LIBS) -o $@

version.c: emulab-syncd.c 
	echo >$@ "char build_info[] = \"Built `date +%d-%b-%Y` by `id -nu`@`hostname | sed 's/\..*//'`:`pwd`\";"

boss-install:
	-mkdir -p $(INSTALL_DIR)/opsdir/man/man1
	$(INSTALL) -m 644 $(SRCDIR)/emulab-syncd.1 \
		$(INSTALL_DIR)/opsdir/man/man1/emulab-syncd.1
	$(INSTALL) -m 644 $(SRCDIR)/emulab-sync.1 \
		$(INSTALL_DIR)/opsdir/man/man1/emulab-sync.1

control:
control-install:
subboss:
subboss-install:

client: all
client-install: client
	$(INSTALL_PROGRAM) emulab-syncd$(EXE) $(DESTDIR)$(CLIENT_BINDIR)/emulab-syncd$(EXE)
	$(INSTALL_PROGRAM) emulab-sync$(EXE) $(DESTDIR)$(CLIENT_BINDIR)/emulab-sync$(EXE)
	$(INSTALL) -m 755 -o root -d $(DESTDIR)$(CLIENT_MANDIR)/man1
	$(INSTALL_DATA) $(SRCDIR)/emulab-syncd.1 $(DESTDIR)$(CLIENT_MANDIR)/man1/emulab-syncd.1
	$(INSTALL_DATA) $(SRCDIR)/emulab-sync.1 $(DESTDIR)$(CLIENT_MANDIR)/man1/emulab-sync.1

clean:
	rm -f *.o emulab-syncd emulab-sync *.debug version.c

