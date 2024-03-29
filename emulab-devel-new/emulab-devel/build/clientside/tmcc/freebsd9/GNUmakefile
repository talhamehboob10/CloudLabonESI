#
# Copyright (c) 2000-2015 University of Utah and the Flux Group.
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
# XXX ONLY RUN THIS INSTALL ON A FREEBSD 9.x TESTBED NODE!
#
# Trivial. These things just need to be installed into the right place
# on a testbed node before cutting an image.
#
#
SRCDIR		= ../../../../clientside/tmcc/freebsd9
TESTBED_SRCDIR	= ../../../..
OBJDIR		= ../../..
SUBDIR		= $(subst $(TESTBED_SRCDIR)/,,$(SRCDIR))

include $(OBJDIR)/Makeconf

SCRIPTS		= 

#
# Force dependencies on the scripts so that they will be rerun through
# configure if the .in file is changed.
# 
all:	netif-emulab $(SCRIPTS)

include $(TESTBED_SRCDIR)/GNUmakerules

SYSETCDIR	= $(DESTDIR)/etc
JAILDIR		= $(SYSETCDIR)/jail
ETCDIR		= $(DESTDIR)$(CLIENT_ETCDIR)
BINDIR		= $(DESTDIR)$(CLIENT_BINDIR)
VARDIR		= $(DESTDIR)$(CLIENT_VARDIR)
LETCDIR		= $(DESTDIR)/usr/local/etc
RCDIR		= $(LETCDIR)/rc.d
ISMFS		= $(ETCDIR)/ismfs
INSTALL		= /usr/bin/install -c

destdircheck:
	@if [ -z "$(DESTDIR)" ]; then \
	    echo "You must define DESTDIR for this target!"; \
	    false; \
	fi
	@if [ "$(DESTDIR)" = "/" ]; then \
	    echo "DESTDIR is '/', really really bad idea!"; \
	    false; \
	fi

install client-install:	bincheck basefbsd-install etc-install \
			sup-install script-install bin-install

subboss-install:	bincheck basefbsd-subboss-install subboss-etc-install \
			sup-install script-install bin-install

simple-install:	script-install bin-install

#
# XXX make sure the isc-dhcpd port is installed,
# XXX as of June 2015, the FreeBSD port no longer maintains the
#     /usr/bin/perl symlink which we rely on, so it may be wrong or missing.
#
bincheck:
	@if [ ! -x /usr/local/sbin/dhclient ]; then \
		echo "Need to install net/isc-dhcp3-client port"; \
		false; \
	fi
	@if [ ! -x /usr/bin/perl ]; then \
		ln -sf /usr/local/bin/perl5 /usr/bin/perl; \
	fi

dir-install:
	$(INSTALL) -m 755 -o root -g wheel -d $(DESTDIR)/boot
	$(INSTALL) -m 755 -o root -g wheel -d $(SYSETCDIR)
	$(INSTALL) -m 755 -o root -g wheel -d $(SYSETCDIR)/rc.d
	$(INSTALL) -m 755 -o root -g wheel -d $(SYSETCDIR)/rc.conf.d
	$(INSTALL) -m 755 -o root -g wheel -d $(ETCDIR)
	$(INSTALL) -m 755 -o root -g wheel -d $(BINDIR)
	$(INSTALL) -m 755 -o root -g wheel -d $(LETCDIR)/sudoers.d
	$(INSTALL) -m 755 -o root -g wheel -d $(RCDIR)
	$(INSTALL) -m 755 -o root -g wheel -d $(VARDIR)
	$(INSTALL) -m 755 -o root -g wheel -d $(VARDIR)/db
	$(INSTALL) -m 755 -o root -g wheel -d $(VARDIR)/jails
	$(INSTALL) -m 755 -o root -g wheel -d $(VARDIR)/logs
	$(INSTALL) -m 755 -o root -g wheel -d $(VARDIR)/sup
	$(INSTALL) -m 755 -o root -g wheel -d $(VARDIR)/boot
	$(INSTALL) -m 755 -o root -g wheel -d $(VARDIR)/lock
	-rm -rf $(DESTDIR)/etc/testbed
	ln -s emulab $(DESTDIR)/etc/testbed
	-rm -rf $(LETCDIR)/testbed
	ln -s emulab $(LETCDIR)/testbed

basefbsd-install: dir-install
	(cd ../freebsd5; $(MAKE) all install)
	rm -rf $(SYSETCDIR)/rc.conf.d
	rm -f $(LETCDIR)/dhclient*
	ln -s /etc/dhclient-enter-hooks $(LETCDIR)/
	ln -s /etc/dhclient-exit-hooks $(LETCDIR)/
	$(INSTALL) -m 644 $(SRCDIR)/sudoers.emulab $(LETCDIR)/sudoers.d/emulab

basefbsd-subboss-install: dir-install
	(cd ../freebsd5; $(MAKE) all subboss-install)
	rm -rf $(SYSETCDIR)/rc.conf.d
	rm -f $(LETCDIR)/dhclient*
	ln -s /etc/dhclient-enter-hooks $(LETCDIR)/
	ln -s /etc/dhclient-exit-hooks $(LETCDIR)/
	$(INSTALL) -m 644 $(SRCDIR)/sudoers.emulab $(LETCDIR)/sudoers.d/emulab

tweak-syslog:
	@if [ -f $(SYSETCDIR)/newsyslog.conf ]; then \
	    if `grep -q 'Added by Emulab' $(SYSETCDIR)/newsyslog.conf`; then \
		sed -i .preemulab -e '/Added by Emulab/,$$d' $(SYSETCDIR)/newsyslog.conf; \
	    fi; \
	    cat $(SRCDIR)/newsyslog.conf.tail >> $(SYSETCDIR)/newsyslog.conf; \
	fi

# Do not even pretend to do cvsup anymore
sup-install:	dir-install
	rm -f $(ETCDIR)/supfile

bin-install:	dir-install

etc-install:	dir-install sysetc-install
	$(INSTALL) -m 644 $(SRCDIR)/group $(ETCDIR)/group
	$(INSTALL) -m 600 $(SRCDIR)/master.passwd $(ETCDIR)/master.passwd
	$(INSTALL) -m 444 $(SRCDIR)/hosts $(ETCDIR)/hosts

subboss-etc-install:	dir-install netif-emulab
	$(INSTALL) -m 555 ./netif-emulab $(SYSETCDIR)/rc.d/netif-emulab

sysetc-install:	dir-install netif-emulab tweak-syslog
	$(INSTALL) -m 444 $(SRCDIR)/rc.conf $(SYSETCDIR)/rc.conf
	$(INSTALL) -m 444 $(SRCDIR)/sysctl.conf $(SYSETCDIR)/sysctl.conf
	$(INSTALL) -m 555 ./netif-emulab $(SYSETCDIR)/rc.d/netif-emulab
	rm -f $(SYSETCDIR)/rc.early
	$(INSTALL) -m 644 $(SRCDIR)/loader.conf $(DESTDIR)/boot/loader.conf
	$(INSTALL) -m 755 $(SRCDIR)/dhclient-exit-hooks \
			$(SYSETCDIR)/dhclient-exit-hooks

script-install:	dir-install
	$(INSTALL) -m 755 $(SRCDIR)/rc.freebsd $(BINDIR)/rc

#
# XXX we still do this like freebsd5!
#
frisbee-mfs-install: destdircheck
	(cd ../freebsd5; $(MAKE) all frisbee-mfs-install)
	rm -rf $(SYSETCDIR)/rc.conf.d
	rm -f $(SYSETCDIR)/testbed/dhclient
	rm -f $(LETCDIR)/dhclient*
	ln -s /etc/dhclient-enter-hooks $(LETCDIR)/
	ln -s /etc/dhclient-exit-hooks $(LETCDIR)/
	rmdir $(LETCDIR)/emulab
	$(INSTALL) -m 644 $(SRCDIR)/mfs-frisbee-rc.conf $(SYSETCDIR)/rc.conf
	$(INSTALL) -m 555 ./netif-emulab $(SYSETCDIR)/rc.d/netif-emulab
	@if [ -r $(SRCDIR)/master.passwd ]; then \
	    $(INSTALL) -m 600 $(SRCDIR)/master.passwd $(SYSETCDIR); \
	    pwd_mkdb -d $(SYSETCDIR) $(SYSETCDIR)/master.passwd; \
	fi
	@if [ -r $(SRCDIR)/group ]; then \
	    $(INSTALL) -m 644 $(SRCDIR)/group $(SYSETCDIR); \
	fi

mfs-install: destdircheck
	(cd ../freebsd5; $(MAKE) all mfs-install)
	rm -rf $(JAILDIR)
	rm -rf $(SYSETCDIR)/rc.conf.d
	rm -rf $(DESTDIR)/root/.cvsup
	rm -f $(SYSETCDIR)/testbed/dhclient
	rm -f $(LETCDIR)/dhclient*
	ln -s /etc/dhclient-enter-hooks $(LETCDIR)/
	ln -s /etc/dhclient-exit-hooks $(LETCDIR)/
	$(INSTALL) -m 644 $(SRCDIR)/mfs-rc.conf $(SYSETCDIR)/rc.conf
	$(INSTALL) -m 555 ./netif-emulab $(SYSETCDIR)/rc.d/netif-emulab
	@if [ -r $(SRCDIR)/master.passwd ]; then \
	    $(INSTALL) -m 600 $(SRCDIR)/master.passwd $(SYSETCDIR); \
	    pwd_mkdb -d $(SYSETCDIR) $(SYSETCDIR)/master.passwd; \
	fi
	@if [ -r $(SRCDIR)/group ]; then \
	    $(INSTALL) -m 644 $(SRCDIR)/group $(SYSETCDIR); \
	fi
