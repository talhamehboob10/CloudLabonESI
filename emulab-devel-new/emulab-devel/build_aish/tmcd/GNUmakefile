#
# Copyright (c) 2000-2021 University of Utah and the Flux Group.
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
SRCDIR		= ../../tmcd
TESTBED_SRCDIR	= ../..
EVENTSYS	= 1
OBJDIR		= ..
SUBDIR		= tmcd
SYSTEM	       := $(shell $(TESTBED_SRCDIR)/utils/osstuff.sh -o)

include $(OBJDIR)/Makeconf

all:	server
server: tmcd tmcd.restart

# For VPATH.
MOSTLY_SRCDIRS = ${TESTBED_LIBSRCDIR}/libtb ${TESTBED_SRCDIR}/pxe \
		 ${TESTBED_LIBSRCDIR}/tmcd

include $(TESTBED_SRCDIR)/GNUmakerules

CFLAGS	+= -O -g -Wall -DUDP \
		-I${OBJDIR} -I/usr/local/include \
		-I${TESTBED_LIBSRCDIR}/libtb -I${TESTBED_SRCDIR}/pxe \
		-I${TESTBED_SRCDIR}/clientside/os/bootinfo \
		-I${TESTBED_LIBSRCDIR}/tmcd
TMLIBS	 = ${TESTBED_LIBOBJDIR}/libtb/libtb.a
BOOTINFO = ${OBJDIR}/pxe/bootinfo.o ${OBJDIR}/pxe/bootinfo_mysql.o
LDFLAGS += -L/usr/local/lib $(LDSTATIC)

#
# For SSL enabled tmcd/tmcc
#
CFLAGS	+= -DETCDIR='"$(INSTALL_ETCDIR)"'
SSLFLAGS = -DWITHSSL 
TMLIBS	+= -lssl -lcrypto -lcrypt
NOTPMLIB = ${TESTBED_LIBOBJDIR}/tmcd/libtmcd.a

ifeq ($(SYSTEM),Linux)
ifneq ($(LDSTATIC),)
NOKERB := $(shell nm /usr/lib/libssl.a | grep -q krb; echo $$?)
else
NOKERB := 1
endif
ifeq ($(NOKERB),0)
CFLAGS   += `/usr/kerberos/bin/krb5-config --cflags`
TMLIBS   += `/usr/kerberos/bin/krb5-config --libs krb5`
ifneq ($(wildcard /usr/lib/libkrb5support.a),)
TMLIBS     += -lkrb5support
endif
endif
TMLIBS  += -ldl
endif

ifeq ($(EVENTSYS),1)
TMCDCFLAGS  = -I$(TESTBED_LIBSRCDIR)/event -DEVENTSYS
TMCDLIBS    = ${TESTBED_LIBOBJDIR}/event/libevent.a
ELVINFLAGS  = -lm -L/usr/local/lib -lpubsub 
endif

tmcd: tmcd.c ${TMCDLIBS} tmcd.h version.o $(BOOTINFO) $(NOTPMLIB)
	$(CC) $(TMCDCFLAGS) $(CFLAGS) $(SSLFLAGS) -o tmcd $< \
		version.o $(NOTPMLIB) $(BOOTINFO) \
		$(LDFLAGS) -L/usr/local/lib/mysql -lmysqlclient \
		$(ELVINFLAGS) $(TMCDLDFLAGS) $(TMCDLIBS) $(TMLIBS) 

version.c: tmcd.c
	echo >$@ "char build_info[] = \"Built `date +%d-%b-%Y` by `id -nu`@`hostname | sed 's/\..*//'`:`pwd`\";"

install:	all

install:	$(INSTALL_SBINDIR)/tmcd \
		$(INSTALL_SBINDIR)/tmcd.restart

control-install:
boss-install: install
subboss-install:
client-install:

$(INSTALL_BINDIR)/tmcd/%: %
	@echo "Installing $<"
	-mkdir -p $(INSTALL_BINDIR)/tmcd
	$(INSTALL_PROGRAM) $< $@

# XXX using ${OBJDIR}/pxe/% didn't seem to work
${OBJDIR}/pxe/bootinfo.o:
	cd ${OBJDIR}/pxe && gmake bootinfo.o
${OBJDIR}/pxe/bootinfo_mysql.o:
	cd ${OBJDIR}/pxe && gmake bootinfo_mysql.o

#
# Here so that the event system libraries, and libraries they depend upon,
# can get made.
#
${TESTBED_LIBOBJDIR}/event/%:
	cd ${TESTBED_LIBOBJDIR}/event && gmake $<
${TESTBED_LIBOBJDIR}/libtb/%:
	cd ${TESTBED_LIBOBJDIR}/tbdb && gmake $<
${TESTBED_LIBOBJDIR}/tmcd/%:
	cd ${TESTBED_LIBOBJDIR}/tmcd && gmake $<

clean:
	rm -f *.o core tmcd *-debug version.c
