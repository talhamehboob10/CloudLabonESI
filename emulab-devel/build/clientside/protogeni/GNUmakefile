#
# Copyright (c) 2013-2018 University of Utah and the Flux Group.
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
SRCDIR		= ../../../clientside/protogeni
TESTBED_SRCDIR	= ../../..
OBJDIR		= ../..
SUBDIR		= $(subst $(TESTBED_SRCDIR)/,,$(SRCDIR))
SYSTEM	       := $(shell uname -s)
# GENI people never decided where geni-get should go, other than to say
# "it's in the user's $PATH".  We don't know what users will set their path
# to.  But we can reasonably assume that /usr/bin will be in it.
USRBINDIR	= $(DESTDIR)/usr/bin

PROGRAMS	= shared-node-monitor

include $(OBJDIR)/Makeconf

all:

include $(TESTBED_SRCDIR)/GNUmakerules

LIBEVENTDIR = $(TESTBED_LIBOBJDIR)/event

# Rules to make sure that some libraries we need from other directories get
# built first
$(LIBEVENTDIR)/%.a:
	@$(MAKE) -C $(LIBEVENTDIR) $(@F)

CFLAGS   += -I. -I${OBJDIR}
CFLAGS   += -I$(TESTBED_LIBSRCDIR)/event
CFLAGS   += -I/usr/local/include

LDFLAGS  += -L$(TESTBED_LIBOBJDIR)
LDFLAGS  += -L$(TESTBED_LIBOBJDIR)/event
LIBS     += -levent -lcrypto
LIBS     += -lm -L/usr/local/lib -lpubsub -lssl
LDFLAGS  += $(LDSTATIC)

ifeq ($(SYSTEM),Linux)
shared-node-monitor: shared-node-monitor.o $(TESTBED_LIBOBJDIR)/event/libevent.a
	$(CC) $(LDFLAGS) -o $@ shared-node-monitor.o $(LIBS)

shared-node-monitor.o: shared-node-monitor.c 
	$(CC) $(CFLAGS) -o $@ -c $<
else
shared-node-monitor:
endif

boss-install:

control-install: 

fs-install:

client: shared-node-monitor

client-install: client
	-mkdir -p $(USRBINDIR)
	$(INSTALL_PROGRAM) $(SRCDIR)/geni-get $(USRBINDIR)
ifeq ($(SYSTEM),Linux)
	$(INSTALL_PROGRAM) shared-node-monitor $(DESTDIR)$(CLIENT_BINDIR)/shared-node-monitor
endif

subboss:

subboss-install:

post-install:

clean:		
	rm -f *.o $(PROGRAMS)

distclean:	

mfs:

mfs-install:

frisbee-mfs:

frisbee-mfs-install:

newnode-mfs:

newnode-mfs-install:
