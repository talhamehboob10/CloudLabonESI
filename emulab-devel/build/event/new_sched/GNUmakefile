#
# Copyright (c) 2000-2014 University of Utah and the Flux Group.
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

SRCDIR		= ../../../event/new_sched
TESTBED_SRCDIR	= ../../..
OBJDIR		= ../..
SUBDIR		= event/new_sched

include $(OBJDIR)/Makeconf

ARCH	       := $(shell uname -m)

all: event-sched_rrpc

include $(TESTBED_SRCDIR)/GNUmakerules

CFLAGS   += -g -D_THREAD_SAFE -pthread -DBINDIR='"$(INSTALL_BINDIR)"'
CFLAGS   += -DSBINDIR='"$(INSTALL_SBINDIR)"'
#CFLAGS  += -DDEBUG
CFLAGS	 += -O -Wall
CFLAGS   += -I. -I${OBJDIR}
CFLAGS   += -I$(TESTBED_LIBSRCDIR)/event -I$(TESTBED_LIBSRCDIR)/libtb
CFLAGS   += -I/usr/local/include

LDFLAGS  += -pthread
LDFLAGS  += -L${TESTBED_LIBOBJDIR}/event -L${TESTBED_LIBOBJDIR}/libtb
LDFLAGS  += $(LDSTATIC)
DBLIBS    = -L/usr/local/lib/mysql -lmysqlclient -lz
LIBS     += -lpthread -levent_r -ltb -lz

CXXFLAGS += -pthread -O -I$(OBJDIR)
CXXFLAGS +=  -I$(TESTBED_LIBSRCDIR)/event -I$(TESTBED_LIBSRCDIR)/libtb
XMLRPCINC = `xmlrpc-c-config c++2 client --cflags`
CXXFLAGS += $(XMLRPCINC)
XMLRPCLIBS = `xmlrpc-c-config c++2 client --libs`

#
# XXX elvin-config adds -lc which is rather bogus, and messes up -pthread
#     build on freebsd. I made a vain attempt to filter it out, but
#     gave up quickly. Deal with it later. 
#
#LIBS     += `elvin-config --libs vin4mt`
LIBS	 += -L/usr/local/lib -lpubsub_r -lssl -lcrypto -lm

OBJS	  = event-sched.o 

version.c: event-sched.c
	echo >$@ "char build_info[] = \"Built on `date +%d-%b-%Y` by `id -nu`@`hostname | sed 's/\..*//'`:`pwd`\";"

OBJS = \
	emulab_proxy.o \
	console-agent.o \
	error-record.o \
	event-sched_rpc.o \
	group-agent.o \
	listNode.o \
	local-agent.o \
	node-agent.o \
	queue.o \
	rrpc.o \
	simulator-agent.o \
	timeline-agent.o \
	version.o

event-sched_rrpc: $(OBJS) event-sched.h $(TESTBED_LIBOBJDIR)/event/libevent.a
	$(CXX) $(CFLAGS) $(LDFLAGS) -o $@ $(OBJS) $(XMLRPCLIBS) $(LIBS)

DEPS = \
	console-agent.h error-record.h event-sched.h group-agent.h listNode.h \
	local-agent.h node-agent.h rpc.h simulator-agent.h timeline-agent.h \
	${TESTBED_LIBSRCDIR}/event/event.h

emulab_proxy.o:		emulab_proxy.cc $(DEPS)
queue.o:		queue.c $(DEPS)
listNode.o:		listNode.c $(DEPS)
error-record.o:		error-record.c $(DEPS)
local-agent.o:		local-agent.c $(DEPS)
group-agent.o:		group-agent.c $(DEPS)
simulator-agent.o:	simulator-agent.cc $(DEPS)
console-agent.o:	console-agent.cc $(DEPS)
node-agent.o:		node-agent.cc $(DEPS)
event-sched_rpc.o:	event-sched.c $(DEPS)
	$(CC) $(CFLAGS) -DRPC -c -o $@ $<
rpc.o:			rpc.cc rpc.h event-sched.h
	$(CXX) $(CXXFLAGS) -DSSHRPC $(XMLRPCINC) -c $<

rrpc.o:			rpc.cc $(DEPS)
	$(CXX) -g $(CXXFLAGS) -DSSLRPC $(XMLRPCINC) -c -o rrpc.o $<

install: event-sched_rrpc
	-mkdir -p $(INSTALL_DIR)/opsdir/sbin
	$(INSTALL_PROGRAM) $< $(INSTALL_DIR)/opsdir/sbin/new-event-sched
ifeq ($(ARCH),amd64)
	ln -sf new-event-sched $(INSTALL_DIR)/opsdir/sbin/event-sched
endif
	-mkdir -p $(INSTALL_DIR)/opsdir/man/man8
	$(INSTALL) -m 0644 $(SRCDIR)/event-sched.8 \
		$(INSTALL_DIR)/opsdir/man/man8/event-sched.8
	-mkdir -p $(INSTALL_DIR)/opsdir/bin
	$(INSTALL_PROGRAM) $(SRCDIR)/elog2xplot \
		$(INSTALL_DIR)/opsdir/bin/elog2xplot

control-install: event-sched_rrpc
	$(INSTALL_PROGRAM) $< $(INSTALL_SBINDIR)/new-event-sched
ifeq ($(ARCH),amd64)
	ln -sf new-event-sched $(INSTALL_SBINDIR)/event-sched
endif

# not a client thing
client:
client-install: client

clean:
	/bin/rm -f *.o event-sched event-sched_rpc event-sched_rrpc version.c
