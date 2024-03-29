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
SRCDIR		= ../../../../clientside/lib/tmcd
TESTBED_SRCDIR	= ../../../..
OBJDIR		= ../../..
SUBDIR		= $(subst $(TESTBED_SRCDIR)/,,$(SRCDIR))
EVENTSYS	= 1
SYSTEM	       := $(shell uname -s)

include $(OBJDIR)/Makeconf

all:	libtmcc.a libtmcd.a

include $(TESTBED_SRCDIR)/GNUmakerules

CFLAGS	+= -O -g -Wall -DUDP \
		-I${OBJDIR} -I/usr/local/include \
		-I${TESTBED_LIBSRCDIR}/libtb \
		-L/usr/local/lib
LDFLAGS += $(LDSTATIC)

#
# For SSL enabled tmcd/tmcc
#
CFLAGS	+= -DETCDIR='"$(INSTALL_ETCDIR)"'
SSLFLAGS = -DWITHSSL

#
# Kerberos foo for really old Linux clients
#
ifeq ($(SYSTEM),Linux)
ifneq ($(wildcard /usr/kerberos/bin/krb5-config),)
CFLAGS   += `/usr/kerberos/bin/krb5-config --cflags`
endif
endif

libtmcc.a:	ssl.o tpm.o 
	$(AR) crv $@ ssl.o tpm.o
	$(RANLIB) $@

libtmcd.a:	ssl.o notpm.o
	$(AR) crv $@ ssl.o notpm.o
	$(RANLIB) $@

tpm.o:	tpm.c
	$(CC) -c $(CFLAGS) $(SSLFLAGS) $<

notpm.o: tpm.c
	$(CC) -c -o notpm.o $(CFLAGS) $(SSLFLAGS) -DTPMOVERRIDE $<

ssl.o:	ssl.c ssl.h tmcd.h
tpm.o: tpm.h ssl.h tmcd.h
notpm.o: tpm.h ssl.h tmcd.h

install: all
client: all
client-install:
boss-install:
control-install: all
fs-install: all
subboss-install:
client-install:
mfs:
mfs-install:
frisbee-mfs:
frisbee-mfs-install:

clean:
	rm -f *.o libtmcd.a libtmcc.a
