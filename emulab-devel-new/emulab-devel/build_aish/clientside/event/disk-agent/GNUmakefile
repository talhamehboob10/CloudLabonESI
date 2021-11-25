#
# Copyright (c) 2000-2012 University of Utah and the Flux Group.
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
SRCDIR		= ../../../../clientside/event/disk-agent
TESTBED_SRCDIR	= ../../../..
OBJDIR		= ../../..
SUBDIR		= $(subst $(TESTBED_SRCDIR)/,,$(SRCDIR))

SYSTEM	       := $(shell uname -s)
PROGRAMS	= disk-agent

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
LIBS     += -levent -ltb -lcrypto -ldevmapper
LIBS	 += -L/usr/local/lib -lpubsub
LDFLAGS  += $(LDSTATIC)

# Make sure we have libdevmapper
ifneq ($(wildcard /usr/lib/libdevmapper.so*),)
HAVEDEVMAPPER=1
else
HAVEDEVMAPPER=0
endif

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
CXXFLAGS = $(CFLAGS)

# client-side only
boss-install:
control-install:
post-install:

ifeq ($(HAVEDEVMAPPER),0)
$(PROGRAMS) client client-install:
	@echo "*** WARNING: no libdevmapper, not building disk-agent"
else
disk-agent-debug: disk-agent.o 
	$(CXX) $(LDFLAGS) -o $@ disk-agent.o $(LIBS)

$(PROGRAMS):	${TESTBED_LIBOBJDIR}/event/libevent.a \
		${TESTBED_LIBSRCDIR}/event/event.h

client: $(PROGRAMS)

client-install: client
	$(INSTALL_PROGRAM) disk-agent$(EXE) $(DESTDIR)$(CLIENT_BINDIR)/disk-agent$(EXE)
endif

clean:
	/bin/rm -f *.o $(PROGRAMS)

$(INSTALL_DIR)/opsdir/sbin/%: %
	@echo "Installing $<"
	-mkdir -p $(INSTALL_DIR)/opsdir/sbin
	$(INSTALL) $< $@
