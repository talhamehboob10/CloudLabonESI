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
# XXX ONLY RUN THIS INSTALL ON A FREEBSD TESTBED NODE!
#
# Trivial. These things just need to be installed into the right place
# on a testbed node before cutting an image.
#
#
SRCDIR		= ../../../../clientside/tmcc/openbsd
TESTBED_SRCDIR	= ../../../..
OBJDIR		= ../../..
SUBDIR		= $(subst $(TESTBED_SRCDIR)/,,$(SRCDIR))

include $(OBJDIR)/Makeconf

all:	supfile

include $(TESTBED_SRCDIR)/GNUmakerules

DESTDIR		=
SYSETCDIR	= $(DESTDIR)/etc
SYSSBINDIR	= $(DESTDIR)/sbin
JAILDIR		= $(SYSETCDIR)/jail
ETCDIR		= $(DESTDIR)$(CLIENT_ETCDIR)
BINDIR		= $(DESTDIR)$(CLIENT_BINDIR)
VARDIR		= $(DESTDIR)$(CLIENT_VARDIR)
RCDIR		= $(DESTDIR)/usr/local/etc/rc.d
ISMFS		= $(ETCDIR)/ismfs
INSTALL		= /usr/bin/install -c

install client-install:	common-install etc-install \
			sup-install script-install bin-install jail-install
	@echo "Remember to install the PEM files if necessary"

mfs-install:	common-install etc-install \
			script-install bin-install
	echo >$(ISMFS) "This file indicates its the MFS. DO NOT DELETE!"

lbs-install:	simple-install
	cp /dev/null $(BINDIR)/isrem
	cp /dev/null $(ETCDIR)/isrem
	@echo "Remember to install the PEM files if necessary"

simple-install:	common-install \
			script-install bin-install jail-install

dir-install:
	$(INSTALL) -m 755 -o root -g wheel -d $(ETCDIR)
	$(INSTALL) -m 755 -o root -g wheel -d $(BINDIR)
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
	-rm -rf $(DESTDIR)/usr/local/etc/testbed
	ln -s emulab $(DESTDIR)/usr/local/etc/testbed

common-install:	dir-install
# XXX not yet
#	(cd ../common; $(MAKE) local-install)

sup-install:	dir-install
# XXX not yet
#	$(INSTALL) -m 755 ./supfile $(ETCDIR)/supfile
#	$(INSTALL) -m 750 -o root -g wheel -d $(DESTDIR)/root/.cvsup
#	$(INSTALL) -m 600 $(SRCDIR)/cvsup.auth $(DESTDIR)/root/.cvsup/auth

bin-install:	dir-install
# XXX not yet
#	$(INSTALL) -m 755 ../tmcc-nossl $(BINDIR)/tmcc
#	$(INSTALL) -m 755 ../findif $(BINDIR)/findif

etc-install:	dir-install sysetc-install syssbin-install
	$(INSTALL) -m 644 $(SRCDIR)/dhclient $(ETCDIR)/dhclient
# XXX not yet
#	$(INSTALL) -m 644 $(SRCDIR)/group $(ETCDIR)/group
#	$(INSTALL) -m 600 $(SRCDIR)/master.passwd $(ETCDIR)/master.passwd
#	$(INSTALL) -m 644 $(SRCDIR)/hosts $(ETCDIR)/hosts

sysetc-install:	dir-install
	$(INSTALL) -m 755 $(SRCDIR)/rc.conf $(SYSETCDIR)/rc.conf
	$(INSTALL) -m 755 $(SRCDIR)/rc.conf.local $(SYSETCDIR)/rc.conf.local
	$(INSTALL) -m 755 $(SRCDIR)/dhclient-exit-hooks \
			$(SYSETCDIR)/dhclient-exit-hooks
# XXX not yet
#	$(INSTALL) -m 755 $(SRCDIR)/periodic.conf $(SYSETCDIR)/periodic.conf
#	$(INSTALL) -m 755 $(SRCDIR)/testbed.sh $(RCDIR)/testbed.sh

syssbin-install: dir-install
	$(INSTALL) -m 755 $(SRCDIR)/dhclient-script \
			$(SYSSBINDIR)/dhclient-script

script-install:	dir-install
	$(INSTALL) -m 755 $(SRCDIR)/nodetype $(BINDIR)/nodetype
	$(INSTALL) -m 755 $(SRCDIR)/chipset.awk $(BINDIR)/chipset.awk
	$(INSTALL) -m 755 $(SRCDIR)/cpuspeed.awk $(BINDIR)/cpuspeed.awk
	$(INSTALL) -m 755 $(SRCDIR)/control_interface \
			$(BINDIR)/control_interface
# XXX not yet
#	$(INSTALL) -m 755 $(SRCDIR)/prepare $(BINDIR)/prepare
#	$(INSTALL) -m 755 $(SRCDIR)/liblocsetup.pm $(BINDIR)/liblocsetup.pm
#	$(INSTALL) -m 755 $(SRCDIR)/rc.delayagent $(BINDIR)/rc.delayagent
#	$(INSTALL) -m 755 $(SRCDIR)/rc.healthd $(BINDIR)/rc.healthd
#	$(INSTALL) -m 755 $(SRCDIR)/rc.mfs $(BINDIR)/rc.mfs
#	$(INSTALL) -m 755 $(SRCDIR)/rc.ipod $(BINDIR)/rc.ipod
#	$(INSTALL) -m 755 $(SRCDIR)/sethostname $(BINDIR)/sethostname
#	$(INSTALL) -m 755 $(SRCDIR)/tbshutdown $(BINDIR)/tbshutdown
#	$(INSTALL) -m 644 $(SRCDIR)/gated_fxp0.conf $(BINDIR)/gated_fxp0.conf
#	$(INSTALL) -m 644 $(SRCDIR)/gated_fxp1.conf $(BINDIR)/gated_fxp1.conf
#	$(INSTALL) -m 644 $(SRCDIR)/gated_fxp4.conf $(BINDIR)/gated_fxp4.conf

sfs-install:
# XXX not yet
#	$(INSTALL) -m 755 -o root -g wheel -d $(DESTDIR)/etc/sfs
#	$(INSTALL) -m 755 $(SRCDIR)/sfs.sh $(RCDIR)/sfs.sh
#	$(INSTALL) -m 644 $(SRCDIR)/exports $(SYSETCDIR)/exports
#	$(INSTALL) -m 644 $(SRCDIR)/sfsrwsd_config \
			$(SYSETCDIR)/sfs/sfsrwsd_config
#	$(INSTALL) -m 644 $(SRCDIR)/sfssd_config \
			$(SYSETCDIR)/sfs/sfssd_config
#	$(INSTALL) -m 755 -o sfs -g sfs -d $(DESTDIR)/var/sfs
#	$(INSTALL) -m 775 -o sfs -g sfs -d $(DESTDIR)/var/sfs/root
#	$(INSTALL) -m 775 -o sfs -g sfs -d $(DESTDIR)/var/sfs/root/var
#	$(INSTALL) -m 775 -o sfs -g sfs -d $(DESTDIR)/var/sfs/root/usr

jail-install:	dir-install
# XXX not yet
#	$(INSTALL) -m 755 -o root -g wheel -d $(JAILDIR)
#	$(INSTALL) -m 644 $(SRCDIR)/jail/group $(JAILDIR)/group
#	$(INSTALL) -m 640 $(SRCDIR)/jail/master.passwd $(JAILDIR)/master.passwd
#	$(INSTALL) -m 755 $(SRCDIR)/jail/rc.conf $(JAILDIR)/rc.conf
#	$(INSTALL) -m 755 $(SRCDIR)/jail/rc.local $(JAILDIR)/rc.local
#	$(INSTALL) -m 755 $(SRCDIR)/jail/injail.pl $(JAILDIR)/injail.pl
#	$(INSTALL) -m 755 $(SRCDIR)/jail/jaildog.pl $(BINDIR)/jaildog.pl
#	$(INSTALL) -m 755 $(SRCDIR)/jail/jailctl $(BINDIR)/jailctl
#	$(INSTALL) -m 755 $(SRCDIR)/jail/mkjail.pl $(BINDIR)/mkjail.pl

# Invoked from ../ron
remote-install:	jail-install
# XXX not yet
#	$(INSTALL) -m 755 $(SRCDIR)/rc.ipod $(BINDIR)/rc.ipod
#	$(INSTALL) -m 755 $(SRCDIR)/liblocsetup.pm $(BINDIR)/liblocsetup.pm

# Invoked from ../ron
locrem-install:
	-rm -f $(BINDIR)/sethostname
	-rm -f $(SYSETCDIR)/dhclient-exit-hooks
	$(INSTALL) -m 755 $(SRCDIR)/nodetype $(BINDIR)/nodetype
	$(INSTALL) -m 755 $(SRCDIR)/chipset.awk $(BINDIR)/chipset.awk
	$(INSTALL) -m 755 $(SRCDIR)/cpuspeed.awk $(BINDIR)/cpuspeed.awk
	$(INSTALL) -m 755 $(SRCDIR)/control_interface \
			$(BINDIR)/control_interface
