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
# XXX ONLY RUN THIS INSTALL ON A FREEBSD RON NODE!
#
# Trivial. These things just need to be installed into the right place
# on a testbed node before cutting an image.
#
#
SRCDIR		= ../../../../clientside/tmcc/ron
TESTBED_SRCDIR	= ../../../..
OBJDIR		= ../../..
SUBDIR		= $(subst $(TESTBED_SRCDIR)/,,$(SRCDIR))

include $(OBJDIR)/Makeconf

all:	bossnode

include $(TESTBED_SRCDIR)/GNUmakerules

DISTDIR		= /var/tmp/emulab
DESTDIR		= 
SYSETCDIR	= $(DESTDIR)/etc
ETCDIR		= $(DESTDIR)$(CLIENT_ETCDIR)
BINDIR		= $(DESTDIR)$(CLIENT_BINDIR)
VARDIR		= $(DESTDIR)$(CLIENT_VARDIR)
RCDIR		= $(DESTDIR)/usr/local/etc/rc.d
INSTALL		= /usr/bin/install -c

client-install:
wa-install:	wa-stuff doinstall
ron-install:	ron-stuff doinstall
doinstall:	common-install etc-install sysetc-install other-install \
			sup-install script-install bin-install
	@echo "Remember to install the PEM files if necessary"
	@echo "Don't forget to do a post-install as root"

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
	$(INSTALL) -m 755 -o root -g wheel -d $(DESTDIR)/var/log/vtund
	$(INSTALL) -m 755 -o root -g wheel -d $(DESTDIR)/var/lock/vtund
	$(INSTALL) -m 755 -o root -g wheel -d $(SYSETCDIR)
	$(INSTALL) -m 755 -o root -g wheel -d $(SYSETCDIR)/jail
	-rm -rf $(DESTDIR)/etc/testbed
	ln -s emulab $(DESTDIR)/etc/testbed
	-rm -rf $(DESTDIR)/usr/local/etc/testbed
	ln -s emulab $(DESTDIR)/usr/local/etc/testbed

common-install:	dir-install
	(cd ../common; $(MAKE) DESTDIR=$(DESTDIR) remote-install)

other-install:	dir-install
	(cd ../../event/trafgen; $(MAKE) DESTDIR=$(DESTDIR) client-install)
	(cd ../freebsd; $(MAKE) DESTDIR=$(DESTDIR) remote-install)
	(cd ../../os; $(MAKE) DESTDIR=$(DESTDIR) remote-install)

sup-install:	dir-install
	$(INSTALL) -m 755 -o root -g wheel -d $(DESTDIR)/root
	$(INSTALL) -m 750 -o root -g wheel -d $(DESTDIR)/root/.cvsup
	$(INSTALL) -m 600 $(SRCDIR)/cvsup.auth $(DESTDIR)/root/.cvsup/auth

bin-install:	dir-install
	$(INSTALL_PROGRAM) ../tmcc $(BINDIR)/tmcc.bin

etc-install:	dir-install bossnode
	cp /dev/null $(ETCDIR)/isrem
	$(INSTALL) bossnode $(ETCDIR)/bossnode
	$(INSTALL) -m 644 $(SRCDIR)/group $(ETCDIR)/group
	$(INSTALL) -m 600 $(SRCDIR)/master.passwd $(ETCDIR)/master.passwd
	$(INSTALL) $(SRCDIR)/emulabkey $(ETCDIR)/emulabkey

sysetc-install:
	$(INSTALL) -m 644 $(SRCDIR)/ntp.conf $(SYSETCDIR)/ntp.conf

script-install:	dir-install
	$(INSTALL_PROGRAM) $(SRCDIR)/emulabctl $(BINDIR)/emulabctl
	$(INSTALL_PROGRAM) $(SRCDIR)/mkemuman.sh $(BINDIR)/mkemuman.sh
	$(INSTALL_PROGRAM) $(SRCDIR)/webserver.pl $(BINDIR)/webserver.pl
	$(INSTALL_PROGRAM) $(SRCDIR)/prepare $(BINDIR)/prepare
ifndef	NORCD
	rm -f $(RCDIR)/testbed.sh
	rm -f $(RCDIR)/emulab.sh
	rm -f $(RCDIR)/z.emulab.sh
	$(INSTALL_PROGRAM) $(SRCDIR)/cvsup.sh $(RCDIR)/0.cvsup.sh
	$(INSTALL_PROGRAM) $(SRCDIR)/emulab.sh $(RCDIR)/z.emulab.sh
endif

post-install:
	$(BINDIR)/mkemuman.sh
	(chown emulabman $(BINDIR) $(BINDIR)/*)
	(chgrp bin $(BINDIR) $(BINDIR)/*)
	(chown emulabman $(ETCDIR) $(ETCDIR)/*)
	(chgrp bin $(ETCDIR) $(ETCDIR)/*)
	chown root $(BINDIR)/update
	chmod u+s $(BINDIR)/update
	chown root $(BINDIR)/vnodesetup
	chmod u+s $(BINDIR)/vnodesetup
	-chown root $(DESTDIR)/usr/bin/suidperl
	-chmod u+s $(DESTDIR)/usr/bin/suidperl

#
# We build the bossnode file from config info
#
bossnode:	GNUmakefile
	echo >$@ "$(BOSSNODE)"

wa-stuff:	dir-install
	$(INSTALL) -m 755 $(SRCDIR)/supfile.wa $(ETCDIR)/supfile

ron-stuff:	dir-install
	$(INSTALL) -m 755 $(SRCDIR)/supfile.ron $(ETCDIR)/supfile

ron-dist:	distdir
	($(MAKE) DESTDIR=$(DISTDIR)/root ron-install)
	rm -f /tmp/emulab-ron.tar
	tar cf /tmp/emulab-ron.tar -C $(DISTDIR) .

distdir:
	rm -rf $(DISTDIR)
	mkdir -p $(DISTDIR)

clean:
	rm -f bossnode
