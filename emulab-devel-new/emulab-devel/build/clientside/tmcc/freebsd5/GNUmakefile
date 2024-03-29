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
# XXX ONLY RUN THIS INSTALL ON A FREEBSD TESTBED NODE!
#
# Trivial. These things just need to be installed into the right place
# on a testbed node before cutting an image.
#
#
SRCDIR		= ../../../../clientside/tmcc/freebsd5
TESTBED_SRCDIR	= ../../../..
OBJDIR		= ../../..
SUBDIR		= $(subst $(TESTBED_SRCDIR)/,,$(SRCDIR))

include $(OBJDIR)/Makeconf

SCRIPTS		= 

#
# Force dependencies on the scripts so that they will be rerun through
# configure if the .in file is changed.
# 
all:	supfile $(SCRIPTS)

include $(TESTBED_SRCDIR)/GNUmakerules

SYSETCDIR	= $(DESTDIR)/etc
JAILDIR		= $(SYSETCDIR)/jail
ETCDIR		= $(DESTDIR)$(CLIENT_ETCDIR)
BINDIR		= $(DESTDIR)$(CLIENT_BINDIR)
VARDIR		= $(DESTDIR)$(CLIENT_VARDIR)
RCDIR		= $(DESTDIR)/usr/local/etc/rc.d
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

subboss-install:	basefbsd-subboss-install \
			sup-install script-install bin-install

install client-install:	basefbsd-install etc-install \
			sup-install script-install bin-install # jail-install

mfs-install:	destdircheck basefbsdmfs-install etc-install \
			script-install bin-install
	cp $(SRCDIR)/mfs-rc.conf $(SYSETCDIR)/rc.conf
	$(INSTALL) -m 444 $(SRCDIR)/rc.dhclient $(SYSETCDIR)/rc.conf.d/dhclient
	@if [ ! -f $(ISMFS) ]; then \
	    echo >$(ISMFS) "This file indicates its the MFS. DO NOT DELETE!"; \
	fi

frisbee-mfs-install: destdircheck
	(cd ../freebsd; $(MAKE) frisbee-mfs-install)
	rm -f $(SYSETCDIR)/rc.early
	$(INSTALL) -m 644 $(SRCDIR)/frisbee/rc.conf $(SYSETCDIR)/rc.conf
	$(INSTALL) -m 644 $(SRCDIR)/frisbee/rc.local $(SYSETCDIR)/rc.local
	$(INSTALL) -m 755 -o root -g wheel -d $(SYSETCDIR)/rc.conf.d
	$(INSTALL) -m 444 $(SRCDIR)/rc.dhclient $(SYSETCDIR)/rc.conf.d/dhclient

cdboot-install:	destdircheck basefbsdcdboot-install etc-install \
			script-install bin-install
	rm -f $(SYSETCDIR)/start_if.* $(SYSETCDIR)/rc.early
	rm -f $(SYSETCDIR)/rc.cdroot $(SYSETCDIR)/fstab.lbs
	rm -f $(DESTDIR)/boot/loader.rc.lbs
	$(INSTALL) -m 755 $(SRCDIR)/cdboot/rc.conf $(SYSETCDIR)/rc.conf
	$(INSTALL) -m 755 $(SRCDIR)/cdboot/rc.dhclient $(SYSETCDIR)/rc.conf.d/dhclient
#	$(INSTALL) -m 755 $(SRCDIR)/cdboot/rc.cdboot $(BINDIR)/rc/rc.cdboot
	$(INSTALL) -m 755 $(SRCDIR)/cdboot/cdroot $(SYSETCDIR)/rc.d/cdroot
	cp $(SRCDIR)/cdboot/fstab $(SYSETCDIR)/fstab
	cp $(SRCDIR)/cdboot/loader.conf $(DESTDIR)/boot/loader.conf
#	cp $(SRCDIR)/cdboot/.profile $(DESTDIR)/.profile

simple-install:	script-install bin-install # jail-install

dir-install:
	$(INSTALL) -m 755 -o root -g wheel -d $(SYSETCDIR)
	$(INSTALL) -m 755 -o root -g wheel -d $(SYSETCDIR)/rc.d
	$(INSTALL) -m 755 -o root -g wheel -d $(SYSETCDIR)/rc.conf.d
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

basefbsd-install: dir-install
	(cd ../freebsd; $(MAKE) all install)
	rm -f $(SYSETCDIR)/start_if.* $(SYSETCDIR)/rc.early $(BINDIR)/dhclient

basefbsd-subboss-install: dir-install
	(cd ../freebsd; $(MAKE) all subboss-install)
	rm -f $(SYSETCDIR)/start_if.* $(SYSETCDIR)/rc.early $(BINDIR)/dhclient

basefbsdmfs-install: dir-install
	(cd ../freebsd; $(MAKE) mfs-install)
	rm -f $(SYSETCDIR)/start_if.* $(SYSETCDIR)/rc.early $(BINDIR)/dhclient

basefbsdcdboot-install: dir-install
	(cd ../freebsd; $(MAKE) DESTDIR=$(DESTDIR) all cdboot-install)
	rm -f $(SYSETCDIR)/start_if.* $(SYSETCDIR)/rc.early $(BINDIR)/dhclient

sup-install:	dir-install supfile
	$(INSTALL) -m 755 ./supfile $(ETCDIR)/supfile

bin-install:	dir-install

etc-install:	dir-install sysetc-install
	$(INSTALL) -m 644 $(SRCDIR)/group $(ETCDIR)/group
	$(INSTALL) -m 600 $(SRCDIR)/master.passwd $(ETCDIR)/master.passwd

sysetc-install:	dir-install
	$(INSTALL) -m 444 $(SRCDIR)/rc.conf $(SYSETCDIR)/rc.conf
	$(INSTALL) -m 444 $(SRCDIR)/rc.dhclient $(SYSETCDIR)/rc.conf.d/dhclient

script-install:	dir-install
#	$(INSTALL) -m 755 $(SRCDIR)/prepare $(BINDIR)/prepare

jail-install:	dir-install
	$(INSTALL) -m 755 -o root -g wheel -d $(JAILDIR)
	$(INSTALL) -m 644 $(SRCDIR)/jail/group $(JAILDIR)/group
	$(INSTALL) -m 640 $(SRCDIR)/jail/master.passwd $(JAILDIR)/master.passwd
	$(INSTALL) -m 755 $(SRCDIR)/jail/rc.conf $(JAILDIR)/rc.conf
	$(INSTALL) -m 755 $(SRCDIR)/jail/rc.local $(JAILDIR)/rc.local
	$(INSTALL) -m 755 $(SRCDIR)/jail/rc.injail $(BINDIR)/rc.injail
	$(INSTALL) -m 755 $(SRCDIR)/jail/crontab $(JAILDIR)/crontab
	$(INSTALL) -m 755 $(SRCDIR)/jail/jailsetup $(BINDIR)/jailsetup
	$(INSTALL) -m 755 $(SRCDIR)/jail/mkjail.pl $(BINDIR)/mkjail.pl
	$(INSTALL) -m 755 ./injail $(JAILDIR)/injail
