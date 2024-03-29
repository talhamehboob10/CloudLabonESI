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

#
# XXX ONLY RUN THIS INSTALL ON A LINUX TESTBED NODE!
#
# Trivial. These things just need to be installed into the right place
# on a testbed node before cutting an image.
#
#
SRCDIR		= ../../../../clientside/tmcc/linux-sg
TESTBED_SRCDIR	= ../../../..
OBJDIR		= ../../..
SUBDIR		= $(subst $(TESTBED_SRCDIR)/,,$(SRCDIR))

include $(OBJDIR)/Makeconf

SCRIPTS		= 

#
# Force dependencies on the scripts so that they will be rerun through
# configure if the .in file is changed.
# 
all:	$(SCRIPTS)

include $(TESTBED_SRCDIR)/GNUmakerules

DESTDIR		=
SYSETCDIR	= $(DESTDIR)/etc
ETCDIR		= $(DESTDIR)$(CLIENT_ETCDIR)
BINDIR		= $(DESTDIR)$(CLIENT_BINDIR)
VARDIR		= $(DESTDIR)$(CLIENT_VARDIR)
export RCDIR		= $(SYSETCDIR)
INSTALL		= /usr/bin/install -c 
COMMON		= $(SRCDIR)/../common
export DEFRUNLVLDIR	= $(RCDIR)/rc2.d

install client-install:	baselinux-install common-install etc-install \
			sup-install script-install bin-install
	@echo "Remember to install the PEM files if necessary"

simple-install:	common-install script-install bin-install

dir-install:

baselinux-install: dir-install
	(cd ../linux; $(MAKE) client-install)

common-install:	dir-install
	(cd ../common; $(MAKE) local-install)

sup-install:	dir-install

bin-install:	dir-install

etc-install:	dir-install sysetc-remove sysetc-install
	-cp -f /dev/null $(ETCDIR)/isstargate

sysetc-install:	dir-install
	-mkdir -p $(SYSETCDIR)/dhcpc
	$(INSTALL) -m 755 $(SRCDIR)/dhcpcd.exe $(SYSETCDIR)/dhcpc/dhcpcd.exe
	$(INSTALL) -m 755 $(SRCDIR)/ntpd.sh $(RCDIR)/init.d/ntpd
	$(INSTALL) -m 755 $(SRCDIR)/mountallwrapper.sh \
		$(RCDIR)/init.d/mountallwrapper.sh
	$(INSTALL) -m 755 $(SRCDIR)/ntpd.sh $(RCDIR)/init.d/ntpd
	$(INSTALL) -m 755 $(SRCDIR)/testbed $(RCDIR)/init.d/testbed
	-mkdir -p $(SYSETCDIR)/pcmcia
	$(INSTALL) -m 755 $(SRCDIR)/wireless.opts \
		$(SYSETCDIR)/pcmcia/wireless.opts
	-ln -sf ../init.d/mountallwrapper.sh \
		$(RCDIR)/rcS.d/S05mountallwrapper.sh

sysetc-remove:
	-rm -f $(SYSETCDIR)/dhclient*
	-rm -f $(RCDIR)/rc.local
	-rm -f $(RCDIR)/rcS.d/S05mountall.sh
	-rm -f $(SYSETCDIR)/network-scripts/ifcfg-eth*

script-install:	dir-install $(SCRIPTS)
	$(INSTALL) -m 755 $(SRCDIR)/rc.stargate $(BINDIR)/rc/rc.stargate

sfs-install:

############
