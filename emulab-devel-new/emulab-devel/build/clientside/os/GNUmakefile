#
# Copyright (c) 2000-2018 University of Utah and the Flux Group.
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
SRCDIR		= ../../../clientside/os
TESTBED_SRCDIR	= ../../..
OBJDIR		= ../..
SUBDIR		= $(subst $(TESTBED_SRCDIR)/,,$(SRCDIR))
SYSTEM	       := $(shell uname -s)
CBINDIR		= $(DESTDIR)$(CLIENT_BINDIR)
LBINDIR		= $(DESTDIR)/usr/local/bin
LSBINDIR	= $(DESTDIR)/usr/local/sbin
SYSTEM	       := $(shell uname -s)

include $(OBJDIR)/Makeconf

SUBDIRS	= syncd dijkstra genhostsfile imagezip frisbee.redux capture bootinfo
ifeq ($(SYSTEM),FreeBSD)
SUBDIRS += growdisk
endif

# XXX: Remove imagezip and frisbee from Cygwin builds - not working.
ifeq ($(findstring CYGWIN_NT,$(SYSTEM)),CYGWIN_NT)
SUBDIRS := $(filter-out imagezip frisbee.redux,$(SUBDIRS))
endif

ifeq ($(SYSTEM),Linux)
OSTAG=$(shell $(SRCDIR)/../tmcc/osstuff.sh -t)
ifeq ($(OSTAG),alpine)
SUBDIRS := $(filter-out imagezip frisbee.redux capture,$(SUBDIRS))
endif
endif

all:	all-subdirs

include $(TESTBED_SRCDIR)/GNUmakerules

boss-install:
	$(MAKE) -C genhostsfile boss-install
	$(MAKE) -C syncd boss-install
	$(MAKE) -C imagezip boss-install
	$(MAKE) -C frisbee.redux install
	$(MAKE) -C capture install
	-mkdir -p $(INSTALL_DIR)/opsdir/man/man1
	$(INSTALL) -m 644 $(SRCDIR)/install-tarfile.1 \
		$(INSTALL_DIR)/opsdir/man/man1/install-tarfile.1

control: control-subdirs

control-install: 
	@$(MAKE) -C imagezip install
	$(MAKE) -C frisbee.redux control-install

fs-install:

client: client-subdirs

client-install: client
	-mkdir -p $(LBINDIR) $(LSBINDIR)
	$(INSTALL_PROGRAM) $(SRCDIR)/install-tarfile $(LBINDIR)/install-tarfile
	-mkdir -p $(DESTDIR)$(CLIENT_MANDIR)/man1
	$(INSTALL) -m 644 $(SRCDIR)/install-tarfile.1 $(DESTDIR)$(CLIENT_MANDIR)/man1/install-tarfile.1
	$(INSTALL_PROGRAM) $(SRCDIR)/install-rpm $(LBINDIR)/install-rpm
	$(MAKE) -C syncd client-install
	$(MAKE) -C dijkstra client-install
ifneq ($(findstring CYGWIN_NT,$(SYSTEM)),CYGWIN_NT) # Filter out again...
ifneq ($(OSTAG),alpine)
	$(MAKE) -C imagezip client-install
	$(MAKE) -C frisbee.redux client-install
	$(MAKE) -C capture client-install
endif
endif
	$(MAKE) -C genhostsfile client-install
ifeq ($(SYSTEM),FreeBSD)
	$(MAKE) -C growdisk client-install
	$(INSTALL_PROGRAM) $(SRCDIR)/create-swapimage $(LBINDIR)/
endif
	$(INSTALL_PROGRAM) $(SRCDIR)/create-image $(LBINDIR)/
	$(INSTALL_PROGRAM) $(SRCDIR)/create-versioned-image $(LBINDIR)/

mfs:
	$(MAKE) -C growdisk client
	$(MAKE) -C zapdisk mfs
	$(MAKE) -C imagezip client
	$(MAKE) -C frisbee.redux client

subboss: subboss-subdirs

subboss-install: subboss
	$(MAKE) -C genhostsfile subboss-install
ifneq ($(findstring CYGWIN_NT,$(SYSTEM)),CYGWIN_NT) # Filter out again...
	$(MAKE) -C capture client-install
	$(MAKE) -C imagezip client-install
	$(MAKE) -C frisbee.redux subboss-install
endif

remote-install: 
	-mkdir -p $(LBINDIR)
	$(INSTALL_PROGRAM) $(SRCDIR)/install-tarfile $(LBINDIR)/install-tarfile
	$(INSTALL_PROGRAM) $(SRCDIR)/install-rpm $(LBINDIR)/install-rpm

clean:		clean-subdirs
distclean:	subdir-distclean

frisbee-mfs:
	$(MAKE) -C growdisk client
	$(MAKE) -C zapdisk mfs
	$(MAKE) -C frisbee.redux frisbee-mfs

frisbee-mfs-install:
ifeq ($(SYSTEM),FreeBSD)
	CLIENT_BINDIR=/etc/testbed $(MAKE) -e -C frisbee.redux frisbee-mfs-install
	CLIENT_BINDIR=/etc/testbed $(MAKE) -e -C growdisk client-install
	CLIENT_BINDIR=/etc/testbed $(MAKE) -e -C zapdisk frisbee-mfs-install
else
	$(MAKE) -C frisbee.redux client-install
	$(MAKE) -C growdisk client-install
	$(MAKE) -C zapdisk frisbee-mfs-install
	rm -f $(CBINDIR)/frisbee $(CBINDIR)/frisupload
endif

mfs-install:
	$(MAKE) -C imagezip client-install
	$(MAKE) -C frisbee.redux client-install
	$(MAKE) -C growdisk client-install
	$(MAKE) -C zapdisk mfs-install
	$(INSTALL_PROGRAM) $(SRCDIR)/create-image $(LBINDIR)/
	$(INSTALL_PROGRAM) $(SRCDIR)/create-versioned-image $(LBINDIR)/
	$(INSTALL_PROGRAM) $(SRCDIR)/create-swapimage $(LBINDIR)/
	rm -f $(CBINDIR)/frisbee $(CBINDIR)/frisupload
	rm -f $(CBINDIR)/imagezip $(CBINDIR)/imageunzip $(CBINDIR)/imagedump

newnode-mfs: mfs
newnode-mfs-install: mfs-install
cdboot-install: mfs-install

onie-dongle: 
	$(MAKE) -C bootinfo onie-dongle

onie-dongle-install: 
	$(MAKE) -C bootinfo onie-dongle-install

rack-control: 
	$(MAKE) -C capture rack-control

rack-control-install: 
	$(MAKE) -C capture rack-control-install

subdir-distclean:
	@$(MAKE) -C imagezip distclean

# How to recursively descend into subdirectories to make general
# targets such as `all'.
%.MAKE:
	@$(MAKE) -C $(dir $@) $(basename $(notdir $@))
%-subdirs: $(addsuffix /%.MAKE,$(SUBDIRS)) ;

.PHONY:	$(SUBDIRS)

