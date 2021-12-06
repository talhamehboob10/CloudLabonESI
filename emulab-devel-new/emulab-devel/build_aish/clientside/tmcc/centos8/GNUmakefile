#
# Copyright (c) 2000-2019 University of Utah and the Flux Group.
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
SRCDIR		= ../../../../clientside/tmcc/centos8
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
all:

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
			script-install bin-install \
			sysetc-onceonly-install
	@echo "Remember to install the PEM files if necessary"

mfs-install: client-install baselinux-mfs-install

xxfrisbee-mfs-install: baselinux-frisbee-mfs-install

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
	$(INSTALL) -m 755 -o root -g root -d $(SYSETCDIR)/systemd/system/multi-user.target.wants
	$(INSTALL) -m 755 -o root -g root -d $(SYSETCDIR)/dracut.conf.d
	$(INSTALL) -m 750 -o root -g root -d $(SYSETCDIR)/sudoers.d
	$(INSTALL) -m 755 -o root -g root -d $(SYSETCDIR)/selinux
	$(INSTALL) -m 755 -o root -g root -d $(SYSETCDIR)/ld.so.conf.d
	$(INSTALL) -m 755 -o root -g root -d $(SYSETCDIR)/rsyslog.d
	@echo "dir-install"

baselinux-%: dir-install
	# Tell ../linux/GNUMakefile.in that we want systemd files, not SYSV
	(cd ../linux; $(MAKE) DESTDIR=$(DESTDIR) USES_SYSTEMD=1 $(subst baselinux-,,$@))

common-install:	dir-install
	@echo "no centos-specific common files"

bin-install:	dir-install
	$(INSTALL) -m 755 $(SRCDIR)/chronystart $(BINDIR)/chronystart
	@echo "centos-specific bin-install done"

etc-install:	dir-install sysetc-install sysetc-remove
	$(INSTALL) -m 644 $(SRCDIR)/group $(ETCDIR)/group
	$(INSTALL) -m 644 $(SRCDIR)/passwd $(ETCDIR)/passwd
	$(INSTALL) -m 600 $(SRCDIR)/shadow $(ETCDIR)/shadow
	$(INSTALL) -m 600 $(SRCDIR)/gshadow $(ETCDIR)/gshadow
	$(INSTALL) -m 755 $(SRCDIR)/rc.local $(RCDIR)/rc.local
	@echo "centos-specific etc-install done"

sysetc-install:	dir-install
	# Install our version of dhclient-enter-hooks that overrides the
	# lease time in dhclient-script's invocation of the `ip addr
	# ... valid_lft ... preferred_lft ...` command to "forever".
	$(INSTALL) -m 755 $(SRCDIR)/dhclient-enter-hooks $(SYSETCDIR)/dhclient-enter-hooks
	# Clean up stuff from the base linux install. Ick.
	ln -sf /etc/dhclient-enter-hooks $(SYSETCDIR)/dhcp/
	ln -sf /etc/dhclient-exit-hooks $(SYSETCDIR)/dhcp/
	$(INSTALL) -m 644 $(SRCDIR)/ifcfg-eth99 $(SYSETCDIR)/sysconfig/network-scripts
	$(INSTALL) -m 744 $(SRCDIR)/ifup-emulabcnet $(SYSETCDIR)/sysconfig/network-scripts
	$(INSTALL) -m 644 $(SRCDIR)/logrotate-syslog $(SYSETCDIR)/logrotate.d/syslog
	$(INSTALL) -m 644 $(SRCDIR)/rsyslog-emulab.conf $(SYSETCDIR)/rsyslog.d/40-emulab.conf
	$(INSTALL) -m 644 $(SRCDIR)/chrony.conf $(SYSETCDIR)/chrony.conf
	$(INSTALL) -m 644 $(SRCDIR)/chronyd.service \
		$(SYSETCDIR)/systemd/system/chronyd.service
	ln -sf ../chronyd.service \
		$(SYSETCDIR)/systemd/system/multi-user.target.wants/chronyd.service
	-@if [ -z "$(DESTDIR)" ]; then \
	    systemctl daemon-reload || /bin/true; \
	fi

sysetc-remove:
	rm -rf $(SYSETCDIR)/modules.conf $(SYSETCDIR)/ntp.conf \
		$(SYSETCDIR)/cron.pend \
		$(SYSETCDIR)/sysconfig/network-scripts/ifcfg-eth?

# stuff we don't really need to do all the time and may not even be correct
# or sufficient for all FCs
sysetc-onceonly-install:
	@$(MYINSTALL) $(SRCDIR)/emulab-ld.so.conf $(SYSETCDIR)/ld.so.conf.d/emulab.conf
	@$(MYINSTALL) $(SRCDIR)/network $(SYSETCDIR)/sysconfig/network
	@$(MYINSTALL) -m 440 $(SRCDIR)/sudoers $(SYSETCDIR)/sudoers.d/99-emulab
	#@$(MYINSTALL) $(SRCDIR)/rsyslog.conf $(SYSETCDIR)/rsyslog.conf
	@$(MYINSTALL) $(SRCDIR)/selinux-config $(SYSETCDIR)/selinux/config
	@$(MYINSTALL) $(SRCDIR)/emulab-dracut.conf $(SYSETCDIR)/dracut.conf.d/01-dist.conf
	@echo "sysetc-onceonly-install"

script-install:	dir-install $(SCRIPTS)
	@echo "no centos-specific script files"

sfs-install:
	@echo "no centos-specific sfs files"

clean:
	rm -f supfile
