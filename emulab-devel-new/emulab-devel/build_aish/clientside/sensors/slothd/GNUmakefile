#
# Copyright (c) 2000-2016 University of Utah and the Flux Group.
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
SRCDIR		= ../../../../clientside/sensors/slothd
TESTBED_SRCDIR	= ../../../..
OBJDIR		= ../../..
SUBDIR		= $(subst $(TESTBED_SRCDIR)/,,$(SRCDIR))
SYSTEM	       := $(shell uname -s)
SLOTHD_DIR	= unknownclient
TBLIB		= $(TESTBED_LIBOBJDIR)/libtb/libtb.a

SD_USER         = nobody
SD_DATADIR      = $(INSTALL_TOPDIR)/data/slothd_rrd
SD_DOSTATS      = 1
SD_USE_RRDTOOL  = 1

SBIN_SCRIPTS    = sdisrunning sddeploy
BIN_SCRIPTS     = idlestats
SDPROGS		= sdcollectd$(EXE) slothd$(EXE)

include $(OBJDIR)/Makeconf

CC?=gcc
## For debug compilation
##CFLAGS+= -g
CFLAGS+= -Wall -I${OBJDIR} -I/usr/local/include -I$(TESTBED_LIBSRCDIR)/libtb \
		-DCLIENT_BINDIR='"$(CLIENT_BINDIR)"' -DDOSTATS=$(SD_DOSTATS) \
		-DLOG_TESTBED=$(LOG_TESTBED) -DRUNASUSER='"$(SD_USER)"'
LDFLAGS+= $(LDSTATIC) -L${TESTBED_LIBOBJDIR}/libtb -L/usr/local/lib/mysql
SDLIBS+= -ltb -lmysqlclient
LIBS= $(MLIBS)

ifeq ($(SD_USE_RRDTOOL),1)
CFLAGS+= -DUSE_RRDTOOL
LDFLAGS+= -L/usr/local/lib
SDLIBS+= -lrrd
endif

ifeq ($(findstring CYGWIN_NT,$(SYSTEM)),CYGWIN_NT)
# Cygwin on  Windows XP/7
MLIBS += -liphlpapi

WINCLIENT = idlemon
WINPROGS = idlemon$(EXE)
WINCLIENTSRC = idlemon.c
CVR = /HKEY_LOCAL_MACHINE/SOFTWARE/Microsoft/Windows/CurrentVersion/Run
IDLEKEY = $(CVR)/EmulabIdle
IDLEMONEXE = $(DESTDIR)$(CLIENT_BINDIR)/idlemon$(EXE)

else
CFLAGS+= -DUSE_TMCCINFO
endif

all: $(SDPROGS) client $(BIN_SCRIPTS) $(SBIN_SCRIPTS) webfeedback

include ${TESTBED_SRCDIR}/GNUmakerules

slothd-debug: slothd.o slothd.h version.o
	$(CC) $(CFLAGS) $(LDFLAGS) -o $@ slothd.o version.o $(LIBS)

# This is started up at user login on Windows to monitor desktop events for slothd.
idlemon-debug: idlemon.o version.o
	$(CC) $(CFLAGS) $(LDFLAGS) -o $@ idlemon.o version.o $(LIBS)

sdcollectd: sdcollectd.o sdcollectd.h version.o $(TBLIB)
	$(CC) $(CFLAGS) $(LDFLAGS) -o $@ sdcollectd.o version.o $(SDLIBS)

$(TBLIB):
	gmake -C $(OBJDIR)/lib

version.c: slothd.c slothd.h sdcollectd.c sdcollectd.h $(WINCLIENTSRC)
	echo >$@ "char build_info[] = \"Built `date +%d-%b-%Y` by `id -nu`@`hostname | sed 's/\..*//'`:`pwd`\";"

client: slothd $(WINCLIENT)

boss-install: $(addprefix $(INSTALL_SBINDIR)/, $(SBIN_SCRIPTS) sdcollectd) \
	      $(addprefix $(INSTALL_BINDIR)/, $(BIN_SCRIPTS)) \
	      webfeedback
	$(INSTALL_PROGRAM) $(SRCDIR)/digest-slothd $(INSTALL_LIBEXECDIR)
	$(INSTALL_PROGRAM) $(SRCDIR)/digest-slothd $(INSTALL_DIR)/opsdir/sbin/digest-slothd
	$(INSTALL_PROGRAM) webfeedback $(INSTALL_LIBEXECDIR)
ifeq ($(SD_USE_RRDTOOL),1)
	$(SUDO) $(INSTALL) -d -m 0755 -o $(SD_USER) $(SD_DATADIR)
endif

client-install: client
	$(INSTALL_PROGRAM) slothd$(EXE) $(DESTDIR)$(CLIENT_BINDIR)/slothd$(EXE)

ifeq ($(findstring CYGWIN_NT,$(SYSTEM)),CYGWIN_NT)
	# If there are any RDP logins active, idlemon will be busy.  Try moving it.
	-mv $(IDLEMONEXE) $(IDLEMONEXE).prev
	$(INSTALL_PROGRAM) idlemon$(EXE) $(IDLEMONEXE)

	# Wrap the idlemon program in a VBS script to hide its window away.
	$(INSTALL_PROGRAM) $(SRCDIR)/idlemon.vbs $(DESTDIR)$(CLIENT_BINDIR)/idlemon.vbs

	# Run the wrapped idlemon as part of any Windows desktop login.
	regtool -s set $(IDLEKEY) 'C:\cygwin\usr\local\etc\emulab\idlemon.vbs'
endif

control-install:
mfs:	client
mfs-install: client-install

clean:
	rm -f *.o $(SDPROGS) $(WINPROGS) slothd-debug *~ core *.core version.c
