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
# XXX ONLY RUN THIS INSTALL ON A CYGWIN / WINDOWS XP NODE!
# Similar to linux9, cygwinxp is an overlay on linux, which is an overlay
# on common.
#
# Trivial. These things just need to be installed into the right place
# on a testbed node before cutting an image.
#
#
SRCDIR		= ../../../../clientside/tmcc/cygwinxp
TESTBED_SRCDIR	= ../../../..
OBJDIR		= ../../..
SUBDIR		= $(subst $(TESTBED_SRCDIR)/,,$(SRCDIR))

include $(OBJDIR)/Makeconf

SCRIPTS		= 

#
# Force dependencies on the scripts so that they will be rerun through
# configure if the .in file is changed.
# 
all:	$(SCRIPTS)

include $(TESTBED_SRCDIR)/GNUmakerules

DESTDIR		=
SYSETCDIR	= $(DESTDIR)/etc
ETCDIR		= $(DESTDIR)$(CLIENT_ETCDIR)
BINDIR		= $(DESTDIR)$(CLIENT_BINDIR)
VARDIR		= $(DESTDIR)$(CLIENT_VARDIR)
RCDIR		= $(SYSETCDIR)/rc.d
INSTALL		= /usr/bin/install -c 
COMMON		= $(SRCDIR)/../common

install client-install:	baselinux-install common-install etc-install \
			sup-install script-install bin-install
	@echo "Remember to install the PEM files if necessary"

simple-install:	common-install script-install bin-install

dir-install:

baselinux-install: dir-install
	(cd ../linux; $(MAKE) DIRGROUP=wheel client-install)
	rm -f $(BINDIR)/rc/rc.healthd
	rm -f $(BINDIR)/rc/rc.slothd

common-install:	dir-install
	(cd ../common; $(MAKE) local-install)

sup-install:	dir-install

SYSTEM32 = /cygdrive/c/Windows/System32
WBEM = $(SYSTEM32)/Wbem
bin-install:	dir-install
	# These are found in the /share/windows directory.
	$(INSTALL) -m 755 $(SRCDIR)/WSName.exe $(BINDIR)/WSName.exe
	$(INSTALL) -m 755 $(SRCDIR)/addusers.exe $(BINDIR)/addusers.exe
	$(INSTALL) -m 755 $(SRCDIR)/usrtogrp.exe $(BINDIR)/usrtogrp.exe
	# Setx is run under CMD early in the user login to make HOME for Emacs.
	$(INSTALL) -m 755 $(SRCDIR)/setx.exe $(SYSTEM32)/setx.exe
	# Devcon is used by rc.cygwin and rc.ifc to disable/enable NIC's.
	$(INSTALL) -m 755 $(SRCDIR)/devcon.exe $(BINDIR)/devcon.exe
	# These are used by tmcd/findif.
	$(INSTALL) -m 755 $(SYSTEM32)/getmac.exe $(BINDIR)/getmac.exe
	$(INSTALL) -m 755 $(WBEM)/framedyn.dll $(BINDIR)/framedyn.dll

etc-install:	dir-install sysetc-remove sysetc-install

sysetc-install:	dir-install ###ifcfgs
	# Watchdog assumes the ssh keys are in /etc/ssh.
	ln -f -s /etc /etc/ssh
	# Boot log files have to be writable by root under rc.cygwin .
	$(INSTALL) -c -m 775 -o root -d /var/log
	$(INSTALL) -c -m 775 -o root -d /var/db
	# Need an /etc/shells file for rc.acounts.
	$(INSTALL) -m 755 $(SRCDIR)/shells /etc/shells

sysetc-remove:
	rm -f /etc/shells

script-install:	dir-install $(SCRIPTS)
	$(INSTALL) -m 755 $(SRCDIR)/liblocsetup.pm $(BINDIR)/liblocsetup.pm
	$(INSTALL) -m 755 $(SRCDIR)/prepare $(BINDIR)/prepare
	$(INSTALL) -m 755 $(SRCDIR)/tbshutdown $(BINDIR)/tbshutdown
	$(INSTALL) -c -m 755 -o root -d /sbin
	$(INSTALL) -m 755 $(SRCDIR)/reboot /sbin/reboot
	# Put the tcsh desktop startup script in the CygWin root directory.
	$(INSTALL) -m 755 $(SRCDIR)/cygwin-tcsh.bat /
	ln -f -s /bin/shutdown /sbin/shutdown
	# Everybody is in the Administrators group already, so sudo is irrelevant.
	$(INSTALL) -m 755 $(SRCDIR)/sudo.dummy /bin/sudo
	$(INSTALL) -m 755 $(SRCDIR)/rc.firstboot $(BINDIR)/rc/rc.firstboot
	$(INSTALL) -m 755 $(SRCDIR)/rc.cygwinxp $(BINDIR)/rc/rc.cygwin
	$(INSTALL) -m 755 $(SRCDIR)/clean_logonui $(BINDIR)/clean_logonui
	$(INSTALL) -m 755 $(SRCDIR)/rc.reboot $(BINDIR)/rc/rc.reboot
	$(INSTALL) -m 755 $(SRCDIR)/rc.lmhosts $(BINDIR)/rc/rc.lmhosts
	$(INSTALL) -m 755 $(SRCDIR)/netbt $(BINDIR)/netbt

sfs-install:

# create ifcfg-eth? files
ifcfgs:	$(SRCDIR)/mkifcfgs $(SRCDIR)/ifcfg.template
	$(SRCDIR)/mkifcfgs $(SRCDIR)/ifcfg.template
