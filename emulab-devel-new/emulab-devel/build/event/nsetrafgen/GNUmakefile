#
# Copyright (c) 2000-2011 University of Utah and the Flux Group.
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

SRCDIR		= ../../../event/nsetrafgen
TESTBED_SRCDIR	= ../../..
OBJDIR		= ../..
SUBDIR		= event/nsetrafgen
INSTALL_SUPDIR	= /usr/testbed/sup/sup/FBSD45-STD/root
INSTALL_FILES	= nseinput.tcl $(SRCDIR)/startnse
INSTALL_NSE     = nse

include $(OBJDIR)/Makeconf

all: msg

msg:
	@echo ""
	@echo -n "WARNING! You must first do a \"make buildnse\" "
	@echo "if nse is not built"
	@echo "WARNING! It takes about 15 minutes for buildnse"
	@echo ""

include $(TESTBED_SRCDIR)/GNUmakerules

# Symlinking all these files is the only way to ensure the build
# succeeds with a pre-built nse.patch file. Since we run both
# the testbed as well as ns configure script, we need to resort
# to this kind of hack
buildnse:
	ln -sf $(SRCDIR)/tbevent.h .
	ln -sf $(SRCDIR)/tbevent.cc .
	ln -sf $(SRCDIR)/tbnexthop.h .
	ln -sf $(SRCDIR)/tbnexthop.cc .
	ln -sf $(SRCDIR)/ip_fw.h .
	ln -sf $(TESTBED_LIBSRCDIR)/libtb/log.h .
	ln -sf $(TESTBED_LIBSRCDIR)/libtb/tbdefs.h .
	ln -sf $(TESTBED_LIBSRCDIR)/event/event.h .
	$(SRCDIR)/nse-install $(SRCDIR)/nse.patch

makepatch:
	chmod +x nse-makepatch
	./nse-makepatch

sup-install:
	-mkdir -p $(INSTALL_SUPDIR)/$(CLIENT_BINDIR)/
	-cp $(INSTALL_FILES) $(INSTALL_SUPDIR)/$(CLIENT_BINDIR)
	-mkdir -p $(INSTALL_SUPDIR)/usr/local/bin/
	-cp $(INSTALL_NSE) $(INSTALL_SUPDIR)/usr/local/bin

# XXX requires Shashi-magic right now
tmpmsg:
	@echo "WARNING: just installing scripts"
	@echo "         do 'make real-<target>' if you want to install NSE"

client: tmpmsg
client-install: client
	$(INSTALL_PROGRAM) $(INSTALL_FILES) $(DESTDIR)$(CLIENT_BINDIR)

real-client: all
real-client-install:
	cp -p $(INSTALL_FILES) $(DESTDIR)$(CLIENT_BINDIR)
	if [ -x $(INSTALL_NSE) ]; then \
	    $(INSTALL) -m 755 -o root -d $(DESTDIR)/usr/local/bin; \
	    cp -p $(INSTALL_NSE) $(DESTDIR)/usr/local/bin; \
	fi

clean:
	rm -f $(INSTALL_NSE)
