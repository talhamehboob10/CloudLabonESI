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
# XXX ONLY RUN THIS INSTALL ON A LINUX DATAPOSITORY NODE
#
# Trivial. These things just need to be installed into the right place
# on a testbed node before cutting an image.
#
#
SRCDIR		= ../../../../clientside/tmcc/dp
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
RCDIR		= $(SYSETCDIR)
INSTALL		= /usr/bin/install -c

client-install:
dp-install:	dp-stuff doinstall
doinstall:	common-install etc-install sysetc-install other-install \
			script-install bin-install
	@echo "Remember to install the PEM files if necessary"
	@echo "Don't forget to do a post-install as root"

dir-install:
	$(INSTALL) -m 755 -o root -g root -d $(SYSETCDIR)/emulab
	$(INSTALL) -m 755 -o root -g root -d $(ETCDIR)
	$(INSTALL) -m 755 -o root -g root -d $(BINDIR)
	$(INSTALL) -m 755 -o root -g root -d $(VARDIR)
	$(INSTALL) -m 755 -o root -g root -d $(VARDIR)/db
	$(INSTALL) -m 755 -o root -g root -d $(VARDIR)/logs
	$(INSTALL) -m 755 -o root -g root -d $(VARDIR)/boot
	$(INSTALL) -m 755 -o root -g root -d $(VARDIR)/boot/tmcc
	$(INSTALL) -m 755 -o root -g root -d $(VARDIR)/lock

common-install:	dir-install
	(cd ../common; $(MAKE) DESTDIR=$(DESTDIR) remote-install)

other-install:	dir-install

bin-install:	dir-install
	$(INSTALL_PROGRAM) ../tmcc $(BINDIR)/tmcc.bin

etc-install:	dir-install bossnode
	cp /dev/null $(ETCDIR)/isrem
	$(INSTALL) bossnode $(ETCDIR)/bossnode
	$(INSTALL) $(SRCDIR)/emulabkey $(ETCDIR)/emulabkey

sysetc-install:
	$(INSTALL) $(SRCDIR)/emulab.sh $(SYSETCDIR)/init.d/emulab
	-ln -sf ../init.d/emulab $(SYSETCDIR)/rc0.d/K96emulab
	-ln -sf ../init.d/emulab $(SYSETCDIR)/rc1.d/K96emulab
	-ln -sf ../init.d/emulab $(SYSETCDIR)/rc2.d/S96emulab
	-ln -sf ../init.d/emulab $(SYSETCDIR)/rc3.d/S96emulab
	-ln -sf ../init.d/emulab $(SYSETCDIR)/rc4.d/S96emulab
	-ln -sf ../init.d/emulab $(SYSETCDIR)/rc5.d/S96emulab
	-ln -sf ../init.d/emulab $(SYSETCDIR)/rc6.d/K96emulab

script-install:	dir-install
	$(INSTALL_PROGRAM) $(SRCDIR)/emulabctl $(BINDIR)/emulabctl
	$(INSTALL_PROGRAM) $(SRCDIR)/mkemuman.sh $(BINDIR)/mkemuman.sh

post-install:
	$(BINDIR)/mkemuman.sh
	(chown emulabman $(BINDIR) $(BINDIR)/*)
	(chgrp bin $(BINDIR) $(BINDIR)/*)
	(chown emulabman $(ETCDIR) $(ETCDIR)/*)
	(chgrp bin $(ETCDIR) $(ETCDIR)/*)
	chown root $(BINDIR)/update
	chmod u+s $(BINDIR)/update
	-chown root $(DESTDIR)/usr/bin/suidperl
	-chmod u+s $(DESTDIR)/usr/bin/suidperl

#
# We build the bossnode file from config info
#
bossnode:	GNUmakefile
	echo >$@ "$(BOSSNODE)"

distdir:
	rm -rf $(DISTDIR)
	mkdir -p $(DISTDIR)

clean:
	rm -f bossnode
