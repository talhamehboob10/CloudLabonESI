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
SRCDIR		= ../../../../clientside/tmcc/linux9
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
RCDIR		= $(SYSETCDIR)/rc.d
INSTALL		= /usr/bin/install -c 
COMMON		= $(SRCDIR)/../common

install client-install:	baselinux-install common-install etc-install \
			sup-install script-install bin-install
	@echo "Remember to install the PEM files if necessary"

simple-install:	common-install script-install bin-install

dir-install:

baselinux-install: dir-install
	(cd ../linux; $(MAKE) DESTDIR=$(DESTDIR) client-install)

common-install:	dir-install
	(cd ../common; $(MAKE) DESTDIR=$(DESTDIR) local-install)

sup-install:	dir-install supfile
	$(INSTALL) -m 755 ./supfile $(ETCDIR)/supfile

bin-install:	dir-install

etc-install:	dir-install sysetc-remove sysetc-install

sysetc-install:	ifcfgs dir-install
	$(INSTALL) -m 644 $(SRCDIR)/modules.conf $(SYSETCDIR)/modules.conf
	$(INSTALL) -m 644 $(SRCDIR)/ntp.conf $(SYSETCDIR)/ntp.conf
	$(INSTALL) -m 644 $(SRCDIR)/ifcfg-eth99 $(SYSETCDIR)/sysconfig/network-scripts
	$(INSTALL) -m 644 ifcfg-eth[0-9]* $(SYSETCDIR)/sysconfig/network-scripts

sysetc-remove:

script-install:	dir-install $(SCRIPTS)

sfs-install:

# create ifcfg-eth? files
ifcfgs:	$(SRCDIR)/mkifcfgs $(SRCDIR)/ifcfg.template
	$(SRCDIR)/mkifcfgs $(SRCDIR)/ifcfg.template
