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
# XXX ONLY RUN THIS INSTALL ON A LINUX TESTBED NODE!
#
# Trivial. These things just need to be installed into the right place
# on a testbed node before cutting an image.
#
#
SRCDIR		= ../../../../clientside/tmcc/fedora15
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
DEFRUNLVLDIR	= $(RCDIR)/rc3.d

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
	$(INSTALL) -m 755 -o root -g root -d $(SYSETCDIR)/dhcp
	$(INSTALL) -m 755 -o root -g root -d $(SYSETCDIR)/logrotate.d
	$(INSTALL) -m 755 -o root -g root -d $(SYSETCDIR)/systemd
	$(INSTALL) -m 755 -o root -g root -d $(SYSETCDIR)/systemd/system

baselinux-%: dir-install
	(cd ../linux; $(MAKE) DESTDIR=$(DESTDIR) $(subst baselinux-,,$@))

common-install:	dir-install
	@echo "no fedora-specific common files"

sup-install:	dir-install
	$(INSTALL) -m 755 /dev/null $(ETCDIR)/supfile
	@echo "fedora-specific sup-install done"

bin-install:	dir-install
	$(INSTALL) -m 755 $(SRCDIR)/emulab-systemd-swaps $(BINDIR)
	@echo "no fedora-specific bin files"

etc-install:	dir-install sysetc-remove sysetc-install
	$(INSTALL) -m 644 $(SRCDIR)/group $(ETCDIR)/group
	$(INSTALL) -m 644 $(SRCDIR)/passwd $(ETCDIR)/passwd
	$(INSTALL) -m 600 $(SRCDIR)/shadow $(ETCDIR)/shadow
	$(INSTALL) -m 600 $(SRCDIR)/gshadow $(ETCDIR)/gshadow
	$(INSTALL) -m 755 $(SRCDIR)/rc.local $(RCDIR)/rc.local
	$(INSTALL) -m 755 $(SRCDIR)/testbed $(RCDIR)/init.d/testbed
	@echo "fedora-specific etc-install done"

sysetc-install:	ifcfgs dir-install
	# Clean up stuff from the base linux install. Ick.
	# See ntpd.service below.
	rm -f $(RCDIR)/init.d/ntpd
	rm -f $(DEFRUNLVLDIR)/S58ntpd
	ln -sf /etc/dhclient-enter-hooks $(SYSETCDIR)/dhcp/
	ln -sf /etc/dhclient-exit-hooks $(SYSETCDIR)/dhcp/
	$(INSTALL) -m 644 $(SRCDIR)/ntp.conf $(SYSETCDIR)/ntp.conf
	$(INSTALL) -m 644 $(SRCDIR)/ifcfg-eth99 $(SYSETCDIR)/sysconfig/network-scripts
	$(INSTALL) -m 644 ifcfg-eth[0-9]* $(SYSETCDIR)/sysconfig/network-scripts
	$(INSTALL) -m 744 $(SRCDIR)/ifup-emulabcnet $(SYSETCDIR)/sysconfig/network-scripts
	$(INSTALL) -m 644 $(SRCDIR)/logrotate-syslog $(SYSETCDIR)/logrotate.d/syslog
	$(INSTALL) -m 644 $(SRCDIR)/emulab-fstab-fixup.service $(SYSETCDIR)/systemd/system
	$(INSTALL) -m 644 $(SRCDIR)/ntpd.service $(SYSETCDIR)/systemd/system
	rm -f $(SYSETCDIR)/systemd/system/multi-user.target.wants/ntpd.service
	systemctl enable emulab-fstab-fixup.service
	systemctl enable ntpd.service

sysetc-remove:
	rm -rf $(SYSETCDIR)/modules.conf $(SYSETCDIR)/ntp.conf $(SYSETCDIR)/cron.pend

# stuff we don't really need to do all the time and may not even be correct
# or sufficient for all FCs
sysetc-onceonly-install:
	@$(MYINSTALL) $(SRCDIR)/emulab-ld.so.conf $(SYSETCDIR)/ld.so.conf.d/emulab.conf
	@$(MYINSTALL) $(SRCDIR)/network $(SYSETCDIR)/sysconfig/network
	@$(MYINSTALL) $(SRCDIR)/init $(SYSETCDIR)/sysconfig/init
	@$(MYINSTALL) -m 644 $(SRCDIR)/i18n $(SYSETCDIR)/sysconfig/i18n
	@$(MYINSTALL) -m 600 $(SRCDIR)/login.defs $(SYSETCDIR)/login.defs
	@$(MYINSTALL) -m 600 $(SRCDIR)/securetty $(SYSETCDIR)/securetty
	@$(MYINSTALL) -m 440 $(SRCDIR)/sudoers $(SYSETCDIR)/sudoers
	@$(MYINSTALL) $(SRCDIR)/rsyslog.conf $(SYSETCDIR)/rsyslog.conf
	@$(MYINSTALL) $(SRCDIR)/selinux-config $(SYSETCDIR)/selinux/config

script-install:	dir-install $(SCRIPTS)
	$(INSTALL) -m 755 $(SRCDIR)/delaysetup $(BINDIR)/delaysetup

sfs-install:
	@echo "no fedora-specific sfs files"

# create ifcfg-eth? files
ifcfgs:	$(SRCDIR)/mkifcfgs $(SRCDIR)/ifcfg.template
	$(SRCDIR)/mkifcfgs $(SRCDIR)/ifcfg.template

clean:
	rm -f ifcfg-eth? supfile
