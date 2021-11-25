#
# Copyright (c) 2000-2020 University of Utah and the Flux Group.
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
# XXX ONLY RUN THIS INSTALL ON AN UBUNTU LINUX TESTBED NODE!
#
# Trivial. These things just need to be installed into the right place
# on a testbed node before cutting an image.
#
#
SRCDIR		= ../../../../clientside/tmcc/ubuntu20-ppc64le
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
DEFRUNLVLDIR   ?= $(SYSETCDIR)/rc3.d

install client-install:	common-install etc-install \
			script-install bin-install sysetc-fixup sysetc-install \
			systemd-install
	@echo "Remember to install the PEM files if necessary"

simple-install:	common-install script-install bin-install

dir-install:
	(cd ../ubuntu20; $(MAKE) DESTDIR=$(DESTDIR) RCDIR=$(RCDIR) dir-install)

common-install:	dir-install
	(cd ../common; $(MAKE) DESTDIR=$(DESTDIR) local-install)

bin-install:	dir-install
	(cd ../ubuntu20; $(MAKE) DESTDIR=$(DESTDIR) RCDIR=$(RCDIR) bin-install)

etc-install:	dir-install common-sysetc-install
	(cd ../ubuntu20; $(MAKE) DESTDIR=$(DESTDIR) RCDIR=$(RCDIR) etc-install)
	$(INSTALL) -m 644 $(SRCDIR)/group $(ETCDIR)/group
	$(INSTALL) -m 644 $(SRCDIR)/passwd $(ETCDIR)/passwd
	$(INSTALL) -m 600 $(SRCDIR)/shadow $(ETCDIR)/shadow
	$(INSTALL) -m 600 $(SRCDIR)/gshadow $(ETCDIR)/gshadow

common-sysetc-install:	dir-install
	(cd ../ubuntu20; $(MAKE) DESTDIR=$(DESTDIR) RCDIR=$(RCDIR) common-sysetc-install)

sysetc-fixup:
	(cd ../ubuntu20; $(MAKE) DESTDIR=$(DESTDIR) RCDIR=$(RCDIR) sysetc-fixup)

sysetc-install:	dir-install
	(cd ../ubuntu20; $(MAKE) DESTDIR=$(DESTDIR) RCDIR=$(RCDIR) sysetc-install)

systemd-install: dir-install
	(cd ../ubuntu20; $(MAKE) DESTDIR=$(DESTDIR) RCDIR=$(RCDIR) systemd-install)

script-install:	dir-install $(SCRIPTS)
	(cd ../ubuntu20; $(MAKE) DESTDIR=$(DESTDIR) RCDIR=$(RCDIR) script-install)

genirack-install:

sfs-install:
