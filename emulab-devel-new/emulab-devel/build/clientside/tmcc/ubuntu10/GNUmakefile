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

#
# XXX ONLY RUN THIS INSTALL ON AN UBUNTO LINUX TESTBED NODE!
#
# Trivial. These things just need to be installed into the right place
# on a testbed node before cutting an image.
#
#
SRCDIR		= ../../../../clientside/tmcc/ubuntu10
TESTBED_SRCDIR	= ../../../..
OBJDIR		= ../../..
SUBDIR		= $(subst $(TESTBED_SRCDIR)/,,$(SRCDIR))

include $(OBJDIR)/Makeconf

SCRIPTS		= 

#
# Force dependencies on the scripts so that they will be rerun through
# configure if the .in file is changed.
# 
all:	supfile ifcfgs

include $(TESTBED_SRCDIR)/GNUmakerules

SYSETCDIR	= $(DESTDIR)/etc
ETCDIR		= $(DESTDIR)$(CLIENT_ETCDIR)
BINDIR		= $(DESTDIR)$(CLIENT_BINDIR)
VARDIR		= $(DESTDIR)$(CLIENT_VARDIR)
RCDIR		= $(SYSETCDIR)
RRCDIR		= /etc
INSTALL		= /usr/bin/install -c 
COMMON		= $(SRCDIR)/../common

install client-install:	common-install etc-install \
			script-install bin-install sysetc-fixup
	@echo "Remember to install the PEM files if necessary"

simple-install:	common-install script-install bin-install

dir-install:
	$(INSTALL) -m 755 -o root -g root -d $(SYSETCDIR)/dhcp3
	$(INSTALL) -m 755 -o root -g root -d $(SYSETCDIR)/init
	$(INSTALL) -m 755 -o root -g root -d $(SYSETCDIR)/network
	$(INSTALL) -m 755 -o root -g root -d $(SYSETCDIR)/rsyslog.d

common-install:	dir-install
	(cd ../common; $(MAKE) DESTDIR=$(DESTDIR) local-install)

bin-install:	dir-install
	(cd ../linux; $(MAKE) DESTDIR=$(DESTDIR) RCDIR=$(RCDIR) bin-install)
	$(INSTALL) -m 755 $(SRCDIR)/findcnet $(BINDIR)/findcnet

etc-install:	dir-install common-sysetc-install

common-sysetc-install:	dir-install
	(cd ../linux; $(MAKE) DESTDIR=$(DESTDIR) RCDIR=$(RCDIR) RRCDIR=$(RRCDIR) sysetc-install)

sysetc-fixup:
	rm -rf $(SYSETCDIR)/modules.conf $(SYSETCDIR)/cron.pend $(SYSETCDIR)/sysconfig $(SYSETCDIR)/init.d/ntpd
	rm -f $(SYSETCDIR)/dhclient-enter-hooks \
		$(SYSETCDIR)/dhclient-exit-hooks
	$(INSTALL) -m 755 $(SRCDIR)/dhclient-exit-hooks \
			$(SYSETCDIR)/dhcp3/dhclient-exit-hooks
	$(INSTALL) -m 755 $(SRCDIR)/dhclient-enter-hooks \
			$(SYSETCDIR)/dhcp3/dhclient-enter-hooks
	rm -f $(RRCDIR)/rc.local $(SYSETCDIR)/rc.local
	$(INSTALL) -m 644 $(SRCDIR)/rc-sysinit.conf $(SYSETCDIR)/init/rc-sysinit.conf
	$(INSTALL) -m 644 $(SRCDIR)/rsyslog-emulab.conf $(SYSETCDIR)/rsyslog.d/60-emulab.conf
	$(INSTALL) -m 755 $(SRCDIR)/rc.local $(SYSETCDIR)/rc.local
	$(INSTALL) -m 644 $(SRCDIR)/interfaces $(SYSETCDIR)/network/interfaces

script-install:	dir-install $(SCRIPTS)
	(cd ../linux; $(MAKE) DESTDIR=$(DESTDIR) RCDIR=$(RCDIR) script-install)

sfs-install:
