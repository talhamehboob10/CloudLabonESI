#
# Copyright (c) 2000-2021 University of Utah and the Flux Group.
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
# XXX ONLY RUN THIS INSTALL ON A TESTBED NODE!
#
# These things need to be installed into the right place on a testbed
# node before cutting an image. This directory is installed first,
# followed by the system-specific directory.
#
#
SRCDIR		= ../../../../clientside/tmcc/common
TESTBED_SRCDIR	= ../../../..
OBJDIR		= ../../..
SUBDIR		= $(subst $(TESTBED_SRCDIR)/,,$(SRCDIR))

include $(OBJDIR)/Makeconf

all:

include $(TESTBED_SRCDIR)/GNUmakerules

DESTDIR		=
ETCDIR		= $(DESTDIR)$(CLIENT_ETCDIR)
BINDIR		= $(DESTDIR)$(CLIENT_BINDIR)
VARDIR		= $(DESTDIR)$(CLIENT_VARDIR)
RCDIR		= $(BINDIR)/rc
SYSRCDIR	= $(DESTDIR)/usr/local/etc/rc.d
TBBINDIR	= $(DESTDIR)/usr/testbed/bin
TBLIBDIR	= $(DESTDIR)/usr/testbed/lib
INSTALL		= /usr/bin/install -c

install client-install:
	@echo "You should probably not run this install directly!"
	@echo "If you do, be sure to install from the system specific "
	@echo "directory afterwards."


local-install:		path-install local-script-install symlinks
remote-install:		path-install remote-script-install
control-install:	path-install control-script-install
fs-install:		path-install fs-script-install
subboss-local-install:	path-install subboss-local-script-install symlinks

mobile-control-install: path-install
	$(INSTALL) -m 755 $(SRCDIR)/libtmcc.pm $(BINDIR)/libtmcc.pm
	$(INSTALL) -m 755 $(SRCDIR)/libtestbed.pm $(BINDIR)/libtestbed.pm

other-install:
	(cd ../../os; $(MAKE) DESTDIR=$(DESTDIR) client-install)
	(cd ../../event; $(MAKE) DESTDIR=$(DESTDIR) client-install)
	(cd ../../sensors/slothd; $(MAKE) DESTDIR=$(DESTDIR) client-install)
	(cd ../../tools; $(MAKE) DESTDIR=$(DESTDIR) client-install)

dir-install:
	$(INSTALL) -m 755 -o root -d $(ETCDIR)
	$(INSTALL) -m 755 -o root -d $(BINDIR)
	$(INSTALL) -m 755 -o root -d $(RCDIR)
	$(INSTALL) -m 755 -o root -d $(VARDIR)
	$(INSTALL) -m 755 -o root -d $(VARDIR)/db
	$(INSTALL) -m 755 -o root -d $(VARDIR)/jails
	$(INSTALL) -m 755 -o root -d $(VARDIR)/logs
	$(INSTALL) -m 755 -o root -d $(VARDIR)/boot
	$(INSTALL) -m 755 -o root -d $(VARDIR)/lock
	$(INSTALL) -m 755 -o root -d $(TBBINDIR)

path-install:	dir-install
	$(INSTALL) -m 755 $(SRCDIR)/paths.pm $(ETCDIR)/paths.pm
	$(INSTALL) -m 755 $(SRCDIR)/paths.sh $(ETCDIR)/paths.sh

nodecheck-install:	dir-install
	$(INSTALL) -m 644 $(SRCDIR)/checknode/checkutils.sh $(BINDIR)/checkutils.sh
	$(INSTALL) -m 644 $(SRCDIR)/checknode/hbis.sh $(BINDIR)/hbis.sh

	$(INSTALL) -m 755 $(SRCDIR)/checknode/cpucheck $(BINDIR)/cpucheck
	$(INSTALL) -m 755 $(SRCDIR)/checknode/diskcheck $(BINDIR)/diskcheck
	$(INSTALL) -m 755 $(SRCDIR)/checknode/memcheck $(BINDIR)/memcheck
	$(INSTALL) -m 755 $(SRCDIR)/checknode/niccheck $(BINDIR)/niccheck
	$(INSTALL) -m 755 $(SRCDIR)/checknode/timecheck $(BINDIR)/timecheck
	$(INSTALL) -m 755 $(SRCDIR)/checknode/checknode $(BINDIR)/checknode
	$(INSTALL) -m 755 $(SRCDIR)/checknode/rc.nodecheck $(RCDIR)/rc.nodecheck

common-script-install:	dir-install
	$(INSTALL) -m 755 $(SRCDIR)/libsetup.pm $(BINDIR)/libsetup.pm
	$(INSTALL) -m 755 $(SRCDIR)/libtmcc.pm $(BINDIR)/libtmcc.pm
	$(INSTALL) -m 755 $(SRCDIR)/libtestbed.pm $(BINDIR)/libtestbed.pm
	$(INSTALL) -m 755 $(SRCDIR)/libgenvnode.pm $(BINDIR)/libgenvnode.pm
	$(INSTALL) -m 755 $(SRCDIR)/libutil.pm $(BINDIR)/libutil.pm
	$(INSTALL) -m 755 $(SRCDIR)/tmcc.pl $(BINDIR)/tmcc
	$(INSTALL) -m 755 $(SRCDIR)/logboot $(BINDIR)/logboot
	$(INSTALL) -m 755 $(SRCDIR)/watchdog $(BINDIR)/watchdog
	$(INSTALL) -m 755 $(SRCDIR)/ntpstart $(BINDIR)/ntpstart
	$(INSTALL) -m 755 $(SRCDIR)/runstartup $(BINDIR)/runstartup
	$(INSTALL) -m 755 $(SRCDIR)/runcvsup.sh $(BINDIR)/runcvsup.sh
	$(INSTALL) -m 755 $(SRCDIR)/update $(BINDIR)/update
	$(INSTALL) -m 755 $(SRCDIR)/ifsetup $(BINDIR)/ifsetup
	$(INSTALL) -m 755 $(SRCDIR)/ifdynconfig $(BINDIR)/ifdynconfig
	$(INSTALL) -m 755 $(SRCDIR)/vnodesetup $(BINDIR)/vnodesetup
	$(INSTALL) -m 755 $(SRCDIR)/mkvnode.pl $(BINDIR)/mkvnode.pl
	$(INSTALL) -m 755 $(SRCDIR)/bootsubnodes $(BINDIR)/bootsubnodes
	$(INSTALL) -m 755 $(SRCDIR)/bootvnodes $(BINDIR)/bootvnodes
	$(INSTALL) -m 755 $(SRCDIR)/startcmddone $(BINDIR)/startcmddone
	$(INSTALL) -m 755 $(SRCDIR)/getblob $(BINDIR)/getblob
	$(INSTALL) -m 755 $(SRCDIR)/fixarpinfo $(BINDIR)/fixarpinfo
	$(INSTALL) -m 755 $(SRCDIR)/removecert $(BINDIR)/removecert
	(cd config; $(MAKE) DESTDIR=$(DESTDIR) script-install)

subboss-common-script-install:	dir-install
	$(INSTALL) -m 755 $(SRCDIR)/libsetup.pm $(BINDIR)/libsetup.pm
	$(INSTALL) -m 755 $(SRCDIR)/libtmcc.pm $(BINDIR)/libtmcc.pm
	$(INSTALL) -m 755 $(SRCDIR)/libtestbed.pm $(BINDIR)/libtestbed.pm
	$(INSTALL) -m 755 $(SRCDIR)/tmcc.pl $(BINDIR)/tmcc
	$(INSTALL) -m 755 $(SRCDIR)/logboot $(BINDIR)/logboot
	$(INSTALL) -m 755 $(SRCDIR)/watchdog $(BINDIR)/watchdog
	$(INSTALL) -m 755 $(SRCDIR)/ntpstart $(BINDIR)/ntpstart
	$(INSTALL) -m 755 $(SRCDIR)/runstartup $(BINDIR)/runstartup
	$(INSTALL) -m 755 $(SRCDIR)/update $(BINDIR)/update
	$(INSTALL) -m 755 $(SRCDIR)/ifsetup $(BINDIR)/ifsetup
	$(INSTALL) -m 755 $(SRCDIR)/ifdynconfig $(BINDIR)/ifdynconfig
	$(INSTALL) -m 755 $(SRCDIR)/startcmddone $(BINDIR)/startcmddone
	$(INSTALL) -m 755 $(SRCDIR)/localize_image $(BINDIR)/localize_image
	$(INSTALL) -m 755 $(SRCDIR)/getblob $(BINDIR)/getblob
	$(INSTALL) -m 755 $(SRCDIR)/fixarpinfo $(BINDIR)/fixarpinfo
	(cd config; $(MAKE) DESTDIR=$(DESTDIR) subboss-script-install)

symlinks:	dir-install
	rm -f $(TBBINDIR)/tevc$(EXE)
	ln -s $(CLIENT_BINDIR)/tevc$(EXE) $(TBBINDIR)/tevc$(EXE)
	rm -f $(TBBINDIR)/emulab-sync$(EXE)
	ln -s $(CLIENT_BINDIR)/emulab-sync$(EXE) $(TBBINDIR)/emulab-sync$(EXE)
	rm -f $(TBBINDIR)/mkextrafs
	ln -s $(CLIENT_BINDIR)/mkextrafs.pl $(TBBINDIR)/mkextrafs
	rm -f $(TBLIBDIR)
	ln -s $(CLIENT_BINDIR) $(TBLIBDIR)

local-script-install:	common-script-install nodecheck-install
	$(INSTALL) -m 755 $(SRCDIR)/sendevent $(BINDIR)/sendevent
	$(INSTALL) -m 755 $(SRCDIR)/rc.testbed $(RCDIR)/rc.testbed
	$(INSTALL) -m 755 $(SRCDIR)/rc.bootsetup $(RCDIR)/rc.bootsetup
	$(INSTALL) -m 755 $(SRCDIR)/rc.slothd $(RCDIR)/rc.slothd
	$(INSTALL) -m 755 $(SRCDIR)/rc.canaryd $(RCDIR)/rc.canaryd
	$(INSTALL) -m 755 $(SRCDIR)/rc.linktest $(RCDIR)/rc.linktest
	$(INSTALL) -m 755 $(SRCDIR)/rc.delayagent $(RCDIR)/rc.delayagent
	$(INSTALL) -m 755 $(SRCDIR)/rc.inelab $(RCDIR)/rc.inelab
	$(INSTALL) -m 755 $(SRCDIR)/rc.pgeni $(RCDIR)/rc.pgeni
	# Symlink this cause we invoke it from boss, and its too much
	# of a hassle to worry about right now.
	rm -f $(ETCDIR)/update
	-ln -s $(CLIENT_BINDIR)/update $(ETCDIR)/update

subboss-local-script-install:	subboss-common-script-install
	$(INSTALL) -m 755 $(SRCDIR)/sendevent $(BINDIR)/sendevent
	$(INSTALL) -m 755 $(SRCDIR)/rc.testbed $(RCDIR)/rc.testbed
	$(INSTALL) -m 755 $(SRCDIR)/rc.bootsetup $(RCDIR)/rc.bootsetup
	$(INSTALL) -m 755 $(SRCDIR)/rc.inelab $(RCDIR)/rc.inelab
	$(INSTALL) -m 755 $(SRCDIR)/rc.pgeni $(RCDIR)/rc.pgeni
	# Symlink this cause we invoke it from boss, and its too much
	# of a hassle to worry about right now.
	rm -f $(ETCDIR)/update
	-ln -s $(CLIENT_BINDIR)/update $(ETCDIR)/update

remote-script-install:	common-script-install
	-chown root $(BINDIR)/vnodesetup
	-chmod u+s $(BINDIR)/vnodesetup

control-script-install:	dir-install bossnode
	$(INSTALL) -m 755 $(SRCDIR)/libsetup.pm $(BINDIR)/libsetup.pm
	$(INSTALL) -m 755 $(SRCDIR)/libtmcc.pm $(BINDIR)/libtmcc.pm
	$(INSTALL) -m 755 $(SRCDIR)/libtestbed.pm $(BINDIR)/libtestbed.pm
	$(INSTALL) -m 755 $(SRCDIR)/tmcc.pl $(BINDIR)/tmcc
	$(INSTALL) -m 755 $(SRCDIR)/ctrlnode.sh $(SYSRCDIR)/ctrlnode.sh
	$(INSTALL) -m 755 $(SRCDIR)/rc.ctrlnode $(RCDIR)/rc.ctrlnode
	$(INSTALL) -m 755 $(SRCDIR)/config/librc.pm $(BINDIR)/librc.pm
	$(INSTALL) -m 755 $(SRCDIR)/fixarpinfo $(BINDIR)/fixarpinfo
	$(INSTALL) bossnode $(ETCDIR)/bossnode

fs-script-install:	dir-install bossnode
	$(INSTALL) -m 755 $(SRCDIR)/libsetup.pm $(BINDIR)/libsetup.pm
	$(INSTALL) -m 755 $(SRCDIR)/libtmcc.pm $(BINDIR)/libtmcc.pm
	$(INSTALL) -m 755 $(SRCDIR)/libtestbed.pm $(BINDIR)/libtestbed.pm
	$(INSTALL) -m 755 $(SRCDIR)/tmcc.pl $(BINDIR)/tmcc
	$(INSTALL) -m 755 $(SRCDIR)/ctrlnode.sh $(SYSRCDIR)/ctrlnode.sh
	$(INSTALL) -m 755 $(SRCDIR)/rc.ctrlnode $(RCDIR)/rc.ctrlnode
	$(INSTALL) -m 755 $(SRCDIR)/config/librc.pm $(BINDIR)/librc.pm
	$(INSTALL) -m 755 $(SRCDIR)/fixarpinfo $(BINDIR)/fixarpinfo
	$(INSTALL) bossnode $(ETCDIR)/bossnode

PGENIFILES = rc.ifconfig rc.topomap rc.progagent rc.pgeni \
		rc.tarfiles rc.rpms rc.trafgen

pgeni-tarball:
	-rm -f $(TBROOT)/www/downloads/geniclient.tar
	rm -rf /tmp/mk1
	($(MAKE) DESTDIR=/tmp/mk1 local-install)
	tar cf $(TBROOT)/www/downloads/geniclient.tar \
                -C /tmp/mk1/usr/local/etc/emulab \
		libsetup.pm libtmcc.pm runstartup watchdog \
		$(addprefix rc/, $(PGENIFILES))
	rm -rf /tmp/mk1

bossnode:	GNUmakefile
	echo >$@ "$(BOSSNODE)"
