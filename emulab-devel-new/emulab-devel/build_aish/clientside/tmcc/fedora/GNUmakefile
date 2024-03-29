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
SRCDIR		= ../../../../clientside/tmcc/fedora
TESTBED_SRCDIR	= ../../../..
OBJDIR		= ../../..
SUBDIR		= $(subst $(TESTBED_SRCDIR)/,,$(SRCDIR))

include $(OBJDIR)/Makeconf

SCRIPTS		= 

MYINSTALL	= $(SRCDIR)/myinstall

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

install client-install:	baselinux-client-install common-install etc-install \
			sup-install script-install bin-install
	@echo "Remember to install the PEM files if necessary"

mfs-install: client-install baselinux-mfs-install

frisbee-mfs-install: baselinux-frisbee-mfs-install

simple-install:	common-install script-install bin-install

openvz-install:	baselinux-common-install common-install \
                baselinux-script-install script-install \
		baselinux-openvz-install etc-install

dir-install:
	$(INSTALL) -m 755 -o root -g root -d $(SYSETCDIR)/init.d

baselinux-%: dir-install
	(cd ../linux; $(MAKE) DESTDIR=$(DESTDIR) $(subst baselinux-,,$@))

common-install:	dir-install
	@echo "no fedora-specific common files"

sup-install:	dir-install supfile
	$(INSTALL) -m 755 ./supfile $(ETCDIR)/supfile
	@echo "fedora-specific sup-install done"

bin-install:	dir-install
	@echo "no fedora-specific bin files"

etc-install:	dir-install sysetc-remove sysetc-install
	@echo "fedora-specific etc-install done"

sysetc-install:	ifcfgs dir-install
	$(INSTALL) -m 644 $(SRCDIR)/ntp.conf $(SYSETCDIR)/ntp.conf
	$(INSTALL) -m 755 $(SRCDIR)/ntpd $(SYSETCDIR)/init.d/ntpd
	$(INSTALL) -m 644 $(SRCDIR)/ifcfg-eth99 $(SYSETCDIR)/sysconfig/network-scripts
	$(INSTALL) -m 644 ifcfg-eth[0-9]* $(SYSETCDIR)/sysconfig/network-scripts

sysetc-remove:
	rm -rf $(SYSETCDIR)/modules.conf $(SYSETCDIR)/ntp.conf $(SYSETCDIR)/cron.pend

# stuff we don't really need to do all the time and may not even be correct
# or sufficient for all FCs
sysetc-onceonly-install:
	@$(MYINSTALL) $(SRCDIR)/emulab-ld.so.conf $(SYSETCDIR)/ld.so.conf.d/emulab.conf
	@$(MYINSTALL) $(SRCDIR)/inittab $(SYSETCDIR)/inittab
	@$(MYINSTALL) $(SRCDIR)/login.defs $(SYSETCDIR)/login.defs
	@$(MYINSTALL) $(SRCDIR)/modprobe.conf $(SYSETCDIR)/modprobe.conf
	@$(MYINSTALL) -m 600 $(SRCDIR)/securetty $(SYSETCDIR)/securetty
	@$(MYINSTALL) -m 440 $(SRCDIR)/sudoers $(SYSETCDIR)/sudoers
	@$(MYINSTALL) $(SRCDIR)/syslog.conf $(SYSETCDIR)/syslog.conf

script-install:	dir-install $(SCRIPTS)
	$(INSTALL) -m 755 $(SRCDIR)/delaysetup $(BINDIR)/delaysetup

sfs-install:
	@echo "no fedora-specific sfs files"

# create ifcfg-eth? files
ifcfgs:	$(SRCDIR)/mkifcfgs $(SRCDIR)/ifcfg.template
	$(SRCDIR)/mkifcfgs $(SRCDIR)/ifcfg.template

clean:
	rm -f ifcfg-eth? supfile
