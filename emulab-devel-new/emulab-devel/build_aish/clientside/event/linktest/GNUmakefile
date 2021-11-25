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
SRCDIR		= ../../../../clientside/event/linktest
TESTBED_SRCDIR	= ../../../..
OBJDIR		= ../../..
SUBDIR		= $(subst $(TESTBED_SRCDIR)/,,$(SRCDIR))

LIBTBDIR        = $(TESTBED_LIBOBJDIR)/libtb
LIBEVENTDIR     = ${TESTBED_LIBOBJDIR}/event
DAEMON	        = linktest
LTEVENT		= ltevent
SCRIPT		= linktest.pl
SCRIPT_ELAB	= elab_linktest.pl
SCRIPT_RUN	= run_linktest.pl
SCRIPT_PROXY	= linktest.proxy
SCRIPT_CONTROL  = linktest_control

# These scripts installed setuid, with sudo. 
SETUID_BIN_SCRIPTS   = 
SETUID_SBIN_SCRIPTS  = $(SCRIPT_CONTROL)
SETUID_LIBX_SCRIPTS  = 


SYSTEM	       := $(patsubst CYGWIN%,CYGWIN,$(shell uname -s))

include $(OBJDIR)/Makeconf

all:	binaries $(SCRIPT) $(SCRIPT_ELAB) $(SCRIPT_RUN) $(SCRIPT_PROXY) \
		weblinktest linktest_control

include $(TESTBED_SRCDIR)/GNUmakerules

CFLAGS   += -DDEBUG -DCLIENT_BINDIR='"$(CLIENT_BINDIR)"'
CFLAGS	 += -O -g -Wall
CFLAGS   += -I. -I${OBJDIR}
CFLAGS   += -I$(TESTBED_LIBSRCDIR)/event -I$(TESTBED_LIBSRCDIR)/libtb
CFLAGS   += -I/usr/local/include

LDFLAGS  += -L${LIBEVENTDIR} -L${LIBTBDIR}
LIBS     += -levent -lcrypto -lssl
LIBS     += -L/usr/local/lib -lpubsub -lm -lssl
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

LIBTB_OBJS	= $(LIBTBDIR)/log.o $(LIBTBDIR)/tbdefs.o $(LIBTBDIR)/be_user.o
DAEMON_OBJS	= linktest.o version.o
LTEVENT_OBJS	= ltevent.o

# Rules to make sure that some libraries we need from other directories get
# built first
$(LIBTBDIR)/%.o:
	@$(MAKE) -C $(LIBTBDIR) $(@F)

$(LIBEVENTDIR)/%.a:
	@$(MAKE) -C $(LIBEVENTDIR) $(@F)

binaries: $(DAEMON) $(LTEVENT) 

$(DAEMON)-debug: $(DAEMON_OBJS) $(LIBTB_OBJS)
	$(CC) $(LDFLAGS) $(DAEMON_OBJS) $(LIBTB_OBJS) $(LIBS) -o $@

$(LTEVENT)-debug: $(LTEVENT_OBJS) $(LIBTB_OBJS)
	$(CC) $(LDFLAGS) $(LTEVENT_OBJS) $(LIBTB_OBJS) $(LIBS) -o $@

version.c: linktest.c
	echo >$@ "char build_info[] = \"Built `date +%d-%b-%Y` by `id -nu`@`hostname | sed 's/\..*//'`:`pwd`\";"

$(DAEMON_OBJS): ${TESTBED_LIBOBJDIR}/event/libevent.a \
		${TESTBED_LIBSRCDIR}/event/event.h

$(LTEVENT_OBJS): ${TESTBED_LIBOBJDIR}/event/libevent.a \
		${TESTBED_LIBSRCDIR}/event/event.h

# We install just enough to fire off the test from boss and wait. 
boss-install: weblinktest $(SCRIPT_RUN) $(SCRIPT_PROXY) $(LTEVENT) \
		$(INSTALL_SBINDIR)/$(SCRIPT_CONTROL) 
	$(INSTALL_PROGRAM) weblinktest $(INSTALL_LIBEXECDIR)
	-mkdir -p $(INSTALL_DIR)/opsdir/bin
	-mkdir -p $(INSTALL_DIR)/opsdir/sbin
	-mkdir -p $(INSTALL_DIR)/opsdir/libexec
	$(INSTALL_PROGRAM) $(SCRIPT_RUN) \
			$(INSTALL_DIR)/opsdir/bin/$(SCRIPT_RUN)
	$(INSTALL_PROGRAM) $(SCRIPT_PROXY) \
			$(INSTALL_DIR)/opsdir/sbin/$(SCRIPT_PROXY)
	$(INSTALL_PROGRAM) $(LTEVENT) \
			$(INSTALL_DIR)/opsdir/libexec/$(LTEVENT)

control-install:	binaries $(SCRIPT_RUN) $(SCRIPT_PROXY)
	$(INSTALL_PROGRAM) $(LTEVENT) $(INSTALL_LIBEXECDIR)
	$(INSTALL_PROGRAM) $(SCRIPT_RUN) $(INSTALL_BINDIR)
	$(INSTALL_PROGRAM) $(SCRIPT_PROXY) $(INSTALL_BINDIR)

client: all
	cd iperf && $(MAKE) client
	cd rude && $(MAKE) client

client-install: client
	@if test ! -x '$(CLIENT_BINDIR)/emulab-rude$(EXE)' -o \
	    	 ! -x '$(CLIENT_BINDIR)/emulab-crude$(EXE)' -o \
		 ! -x '$(CLIENT_BINDIR)/emulab-iperf$(EXE)'; then \
	  echo "**********************************************************"; \
	  echo "*                                                        *"; \
	  echo "* WARNING: Some tools needed by linktest were not found. *"; \
	  echo "*                                                        *"; \
	  echo "* Make sure the following executables are installed:     *"; \
	  echo "*                                                        *"; \
	  echo "*   $(CLIENT_BINDIR)/emulab-rude$(EXE)                   *"; \
	  echo "*   $(CLIENT_BINDIR)/emulab-crude$(EXE)                  *"; \
	  echo "*   $(CLIENT_BINDIR)/emulab-iperf$(EXE)                  *"; \
	  echo "*                                                        *"; \
	  echo "**********************************************************"; \
	fi
	$(INSTALL_PROGRAM) $(DAEMON) $(DESTDIR)$(CLIENT_BINDIR)/$(DAEMON)
	$(INSTALL_PROGRAM) $(LTEVENT) $(DESTDIR)$(CLIENT_BINDIR)/$(LTEVENT)
	$(INSTALL_PROGRAM) $(SRCDIR)/$(SCRIPT) $(DESTDIR)$(CLIENT_BINDIR)/$(SCRIPT)
	$(INSTALL_PROGRAM) $(SCRIPT_ELAB) $(DESTDIR)$(CLIENT_BINDIR)/$(SCRIPT_ELAB)
	$(INSTALL_PROGRAM) $(SCRIPT_RUN) $(DESTDIR)$(CLIENT_BINDIR)/$(SCRIPT_RUN)
	$(MAKE) -C iperf client-install
	$(MAKE) -C rude client-install

clean:
	rm -f *.o *-debug $(TESTS) $(SCRIPT) $(SCRIPT_ELAB) $(SCRIPT_RUN) $(SCRIPT_PROXY) \
		weblinktest linktest_control $(DAEMON) $(LTEVENT) version.c
	-$(MAKE) -C iperf clean
	-$(MAKE) -C rude clean
