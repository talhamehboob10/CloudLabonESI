#
# Copyright (c) 2000-2012, 2015, 2016, 2017 University of Utah and the Flux Group.
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
SRCDIR		= ../../../../clientside/tmcc/ubuntu16
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
# group to use for directories (dir-install)
DIRGROUP	?= root

install client-install:	common-install etc-install \
			script-install bin-install sysetc-fixup sysetc-install \
			systemd-install
	@echo "Remember to install the PEM files if necessary"

simple-install:	common-install script-install bin-install

dir-install:
	$(INSTALL) -m 755 -o root -g root -d $(SYSETCDIR)/dhcp
	$(INSTALL) -m 755 -o root -g root -d $(SYSETCDIR)/dhcp/dhclient-enter-hooks.d
	$(INSTALL) -m 755 -o root -g root -d $(SYSETCDIR)/dhcp/dhclient-exit-hooks.d
	$(INSTALL) -m 755 -o root -g root -d $(SYSETCDIR)/network
	$(INSTALL) -m 755 -o root -g root -d $(SYSETCDIR)/rsyslog.d
	$(INSTALL) -m 755 -o root -g root -d $(SYSETCDIR)/sudoers.d
	$(INSTALL) -m 755 -o root -g root -d $(SYSETCDIR)/systemd
	$(INSTALL) -m 755 -o root -g root -d $(SYSETCDIR)/systemd/system
	$(INSTALL) -m 755 -o root -g root -d $(SYSETCDIR)/systemd/system/network-online.target.wants
	$(INSTALL) -m 755 -o root -g root -d $(SYSETCDIR)/systemd/system/networking.service.wants
	$(INSTALL) -m 755 -o root -g root -d $(SYSETCDIR)/systemd/system/multi-user.target.wants
	$(INSTALL) -m 755 -o root -g root -d $(SYSETCDIR)/udev
	$(INSTALL) -m 755 -o root -g root -d $(SYSETCDIR)/udev/rules.d

common-install:	dir-install
	(cd ../common; $(MAKE) DESTDIR=$(DESTDIR) local-install)

bin-install:	dir-install
	(cd ../linux; $(MAKE) DESTDIR=$(DESTDIR) RCDIR=$(RCDIR) USES_SYSTEMD=1 bin-install)
	$(INSTALL) -m 755 $(SRCDIR)/findcnet $(BINDIR)/findcnet
	$(INSTALL) -m 755 $(SRCDIR)/emulab-udev-network-interfaces-handler \
		$(BINDIR)/emulab-udev-network-interfaces-handler

etc-install:	dir-install common-sysetc-install
	$(INSTALL) -m 644 $(SRCDIR)/group $(ETCDIR)/group
	$(INSTALL) -m 644 $(SRCDIR)/passwd $(ETCDIR)/passwd
	$(INSTALL) -m 600 $(SRCDIR)/shadow $(ETCDIR)/shadow
	$(INSTALL) -m 600 $(SRCDIR)/gshadow $(ETCDIR)/gshadow
	$(INSTALL) -m 644 $(SRCDIR)/hosts $(ETCDIR)/hosts

common-sysetc-install:	dir-install
	# Tell ../linux/GNUMakefile.in that we want systemd files, not SYSV
	(cd ../linux; $(MAKE) DESTDIR=$(DESTDIR) RCDIR=$(RCDIR) RRCDIR=$(RRCDIR) USES_SYSTEMD=1 sysetc-install)

sysetc-fixup:
	rm -rf $(SYSETCDIR)/modules.conf $(SYSETCDIR)/cron.pend \
		$(SYSETCDIR)/sysconfig $(SYSETCDIR)/init.d/ntpd
	rm -f $(SYSETCDIR)/ntp.drift
	rm -f $(SYSETCDIR)/dhclient-enter-hooks $(SYSETCDIR)/dhclient-exit-hooks
	rm -f $(SYSETCDIR)/rc.local

sysetc-install:	dir-install
	$(INSTALL) -m 755 $(SRCDIR)/dhclient.conf \
			$(SYSETCDIR)/dhcp/dhclient.conf
	$(INSTALL) -m 755 $(SRCDIR)/dhclient-exit-hooks \
			$(SYSETCDIR)/dhcp/dhclient-exit-hooks.d/emulab
	$(INSTALL) -m 755 $(SRCDIR)/dhclient-enter-hooks \
			$(SYSETCDIR)/dhcp/dhclient-enter-hooks.d/emulab
	$(INSTALL) -m 644 $(SRCDIR)/rsyslog-emulab.conf $(SYSETCDIR)/rsyslog.d/40-emulab.conf
	rm -f $(SYSETCDIR)/rsyslog.d/60-emulab.conf
	$(INSTALL) -m 755 $(SRCDIR)/rc.local $(SYSETCDIR)/rc.local
	$(INSTALL) -m 644 $(SRCDIR)/interfaces $(SYSETCDIR)/network/interfaces
	$(INSTALL) -m 644 $(SRCDIR)/sudoers $(SYSETCDIR)/sudoers.d/99-emulab
	$(INSTALL) -m 644 $(SRCDIR)/ntp.conf $(SYSETCDIR)/ntp.conf
	$(INSTALL) -m 644 -o ntp -g ntp /dev/null /var/lib/ntp/ntp.drift
	$(INSTALL) -m 644 $(SRCDIR)/99-emulab-control-network.rules \
		$(SYSETCDIR)/udev/rules.d/99-emulab-control-network.rules

systemd-install: dir-install
	$(INSTALL) -m 644 $(SRCDIR)/ifup-wait-emulab-cnet.service \
		 $(SYSETCDIR)/systemd/system/ifup-wait-emulab-cnet.service
	$(INSTALL) -m 644 $(SRCDIR)/ifup-wait-emulab-cnet.service \
		 $(ETCDIR)/ifup-wait-emulab-cnet.service
	rm -f $(SYSETCDIR)/systemd/system/network-online.target.wants/ifup-wait-all-auto.service
	ln -sf ../ifup-wait-emulab-cnet.service \
		$(SYSETCDIR)/systemd/system/network-online.target.wants/ifup-wait-emulab-cnet.service
	$(INSTALL) -m 644 $(SRCDIR)/networking-emulab.service \
		$(SYSETCDIR)/systemd/system/networking-emulab.service
	ln -sf ../networking-emulab.service \
		$(SYSETCDIR)/systemd/system/networking.service.wants/networking-emulab.service
	ln -sf ../networking-emulab.service \
		$(SYSETCDIR)/systemd/system/network-online.target.wants/networking-emulab.service
	$(INSTALL) -m 644 $(SRCDIR)/ntp.service $(SYSETCDIR)/systemd/system
	ln -sf $(SYSETCDIR)/systemd/system/ntp.service \
		$(SYSETCDIR)/systemd/system/multi-user.target.wants/ntp.service
	# Kick the init process to read our newly-installed unit files
	# (i.e., so an immediate tbprepare will work...)
	@if [ -z "$(DESTDIR)" ]; then \
	    systemctl daemon-reload || /bin/true; \
	fi

script-install:	dir-install $(SCRIPTS)
	(cd ../linux; $(MAKE) DESTDIR=$(DESTDIR) RCDIR=$(RCDIR) USES_SYSTEMD=1 script-install)

genirack-install:

sfs-install:
