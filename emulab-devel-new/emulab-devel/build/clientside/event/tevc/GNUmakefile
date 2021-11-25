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
SRCDIR		= ../../../../clientside/event/tevc
TESTBED_SRCDIR	= ../../../..
OBJDIR		= ../../..
SUBDIR		= $(subst $(TESTBED_SRCDIR)/,,$(SRCDIR))
SYSTEM	       := $(shell uname -s)

PROGRAMS	= tevc

include $(OBJDIR)/Makeconf

all:	$(PROGRAMS)

include $(TESTBED_SRCDIR)/GNUmakerules

LIBTBDIR    = $(TESTBED_LIBOBJDIR)/libtb
LIBEVENTDIR = $(TESTBED_LIBOBJDIR)/event

# Rules to make sure that some libraries we need from other directories get
# built first
$(LIBTBDIR)/%.o:
	@$(MAKE) -C $(LIBTBDIR) $(@F)

$(LIBEVENTDIR)/%.a:
	@$(MAKE) -C $(LIBEVENTDIR) $(@F)

CFLAGS   += -DDEBUG
CFLAGS	 += -O -g -Wall
CFLAGS   += -I. -I${OBJDIR}
CFLAGS   += -I$(TESTBED_LIBSRCDIR)/event -I$(TESTBED_LIBSRCDIR)/libtb
CFLAGS   += -I/usr/local/include

LDFLAGS  += -L$(TESTBED_LIBOBJDIR)
LDFLAGS  += -L$(TESTBED_LIBOBJDIR)/libtb -L$(TESTBED_LIBOBJDIR)/event
LIBS     += -levent
LIBS     += -lm -L/usr/local/lib -lpubsub -lssl -lcrypto -lcrypt
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
endif

ifeq ($(SYSTEM),Linux)
LIBS     += -ldl -lz
endif

# Link against some of the object files from libtb, instead of the
# whole library, since the latter cannot be built on clients (without mysql)
tevc-debug:	tevc.o $(LIBTBDIR)/log.o $(LIBTBDIR)/tbdefs.o \
			$(LIBEVENTDIR)/libevent.a ../../lib/event/event.h
	$(CC) $(LDFLAGS) -o $@ tevc.o $(LIBTBDIR)/log.o \
		$(LIBTBDIR)/tbdefs.o $(LIBS)

boss-install:	$(INSTALL_BINDIR)/tevc \
		$(INSTALL_DIR)/opsdir/bin/tevc

control-install:	all $(INSTALL_BINDIR)/tevc

client: tevc
client-install: client
	$(INSTALL_PROGRAM) tevc$(EXE) $(DESTDIR)$(CLIENT_BINDIR)/tevc$(EXE)

clean:
	rm -f *.o $(PROGRAMS) *-debug

$(INSTALL_DIR)/opsdir/bin/%: %
	@echo "Installing $<"
	-mkdir -p $(INSTALL_DIR)/opsdir/bin
	$(INSTALL) $< $@
