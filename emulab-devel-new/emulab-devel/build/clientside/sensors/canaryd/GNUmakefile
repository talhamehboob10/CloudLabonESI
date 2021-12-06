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
SRCDIR		= ../../../../clientside/sensors/canaryd
TESTBED_SRCDIR	= ../../../..
OBJDIR		= ../../..
SUBDIR		= $(subst $(TESTBED_SRCDIR)/,,$(SRCDIR))
TBLIB		= $(TESTBED_LIBOBJDIR)/libtb/libtb.a

SBIN_SCRIPTS    = 
CDPROGS		= canaryd alertlistener

include $(OBJDIR)/Makeconf

CC?=gcc
CFLAGS+= -Wall -g -I${OBJDIR} \
		-I$(TESTBED_LIBSRCDIR)/libtb \
		-I$(TESTBED_LIBSRCDIR)/event \
		-DCLIENT_BINDIR='"$(CLIENT_BINDIR)"' \
		-DLOG_TESTBED=$(LOG_TESTBED) \
		-I/usr/local/include
LDFLAGS+= -L${TESTBED_LIBOBJDIR}/libtb -L/usr/local/lib/mysql -L${TESTBED_LIBOBJDIR}/event
LDFLAGS+= $(LDSTATIC)
LIBS+= -ltb -levent -lcrypto -L/usr/local/lib -lpubsub -lm
CP= cp -pf

SYSTEM  := $(shell uname -s)

all: $(CDPROGS) client

include ${TESTBED_SRCDIR}/GNUmakerules

canaryd: canaryd.o childProcess.o networkInterface.o canarydEvents.o auxfuncs.o version.o
	$(CC) $(CFLAGS) $(LDFLAGS) -o $@ canaryd.o childProcess.o networkInterface.o canarydEvents.o auxfuncs.o version.o $(LIBS) -ldevstat

alertlistener: alertlistener.o
	$(CC) $(CFLAGS) $(LDFLAGS) -o $@ alertlistener.o $(LIBS)

$(TBLIB):
	gmake -C ${TESTBED_LIBOBJDIR}

version.c: canaryd.c childProcess.h childProcess.c networkInterface.h networkInterface.c canarydEvents.h canarydEvents.c auxfuncs.c auxfuncs.h alertlistener.c
	echo >$@ "char build_info[] = \"Built `date +%d-%b-%Y` by `id -nu`@`hostname | sed 's/\..*//'`:`pwd`\";"

client: canaryd

boss-install: $(addprefix $(INSTALL_SBINDIR)/, $(SBIN_SCRIPTS) alertlistener) \
	feedbacklogs
	$(INSTALL_PROGRAM) feedbacklogs $(INSTALL_DIR)/opsdir/sbin/feedbacklogs

client-install: client
	$(INSTALL_PROGRAM) -s canaryd$(EXE) $(DESTDIR)$(CLIENT_BINDIR)$(EXE)

control-install:
mfs:
mfs-install:

clean:
	rm -f *.o $(CDPROGS) *~ core *.core version.c

