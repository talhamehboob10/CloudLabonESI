#
# Copyright (c) 2000-2011, 2018 University of Utah and the Flux Group.
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
SRCDIR		= ../../../../clientside/event/program-agent
TESTBED_SRCDIR	= ../../../..
OBJDIR		= ../../..
SUBDIR		= $(subst $(TESTBED_SRCDIR)/,,$(SRCDIR))

SYSTEM	       := $(shell uname -s)
PROGRAMS	= program-agent

include $(OBJDIR)/Makeconf

all:	$(PROGRAMS)

include $(TESTBED_SRCDIR)/GNUmakerules

CFLAGS   += -DDEBUG
CFLAGS	 += -O -g -Wall
CFLAGS   += -I. -I${OBJDIR}
CFLAGS   += -I$(TESTBED_LIBSRCDIR)/event -I$(TESTBED_LIBSRCDIR)/libtb
CFLAGS	 += -I/usr/local/include
CFLAGS	 += -DHAVE_PUBSUB
CFLAGS   += -DCLIENT_BINDIR='"$(CLIENT_BINDIR)"'

LDFLAGS  += -g -L${TESTBED_LIBOBJDIR}/event -L${TESTBED_LIBOBJDIR}/libtb
LIBS     += -levent -ltb 
LIBS	 += -L/usr/local/lib -lpubsub -lssl -lcrypto -lcrypt
LDFLAGS  += $(LDSTATIC)

# Deal with the presence/absence of kerberos in the linux ssl library
ifeq ($(SYSTEM),Linux)
ifneq ($(LDSTATIC),)
NOKERB := $(shell nm /usr/lib/libssl.a | grep -q krb; echo $$?)
else
NOKERB := 1
endif
ifeq ($(NOKERB),0)
CFLAGS   += `/usr/kerberos/bin/krb5-config --cflags`
LIBS     += `/usr/kerberos/bin/krb5-config --libs krb5`
ifneq ($(wildcard /usr/lib/libkrb5support.a),)
LIBS     += -lkrb5support
endif
endif
LIBS	 += -ldl
endif

version.c: program-agent.c
	echo >$@ "char build_info[] = \"Built on `date +%d-%b-%Y` by `id -nu`@`hostname | sed 's/\..*//'`:`pwd`\";"

program-agent-debug: program-agent.o version.o
	$(CC) $(LDFLAGS) -o $@ program-agent.o version.o $(LIBS)

$(PROGRAMS):	${TESTBED_LIBOBJDIR}/event/libevent.a \
		${TESTBED_LIBSRCDIR}/event/event.h

boss-install:	$(INSTALL_DIR)/opsdir/sbin/program-agent
	-mkdir -p $(INSTALL_DIR)/opsdir/man/man8
	$(INSTALL) -m 0644 $(SRCDIR)/program-agent.8 \
		$(INSTALL_DIR)/opsdir/man/man8/program-agent.8

control-install:	$(INSTALL_SBINDIR)/program-agent

post-install:

client: $(PROGRAMS)
client-install: client
	$(INSTALL_PROGRAM) program-agent$(EXE) $(DESTDIR)$(CLIENT_BINDIR)/program-agent$(EXE)
	chmod u+s-w $(DESTDIR)$(CLIENT_BINDIR)/program-agent
	-mkdir -p $(DESTDIR)$(CLIENT_MANDIR)/man8
	$(INSTALL) -m 644 $(SRCDIR)/program-agent.8 $(DESTDIR)$(CLIENT_MANDIR)/man8/program-agent.8

clean:
	/bin/rm -f *.o $(PROGRAMS)

$(INSTALL_DIR)/opsdir/sbin/%: %
	@echo "Installing $<"
	-mkdir -p $(INSTALL_DIR)/opsdir/sbin
	$(INSTALL) $< $@
