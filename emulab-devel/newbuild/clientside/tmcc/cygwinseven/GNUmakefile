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
# Similar to linux9, cygwinseven is an overlay on linux, which is an overlay
# on common.
#
# Trivial. These things just need to be installed into the right place
# on a testbed node before cutting an image.
#
#
SRCDIR		= ../../../../clientside/tmcc/cygwinseven
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

WINDOWS         = /cygdrive/c/Windows
SYSTEM32 	= $(WINDOWS)/System32
WBEM 		= $(SYSTEM32)/Wbem
SYSPREP 	= $(SYSTEM32)/sysprep
SPSCRIPTS	= $(WINDOWS)/Setup/Scripts

install client-install:	baselinux-install common-install etc-install \
			sup-install script-install bin-install
	@echo "Remember to install the PEM files if necessary"

simple-install:	common-install script-install

dir-install:

baselinux-install: dir-install
	(cd ../linux; $(MAKE) DIRGROUP=wheel client-install)
	rm -f $(BINDIR)/rc/rc.healthd
	rm -f $(BINDIR)/rc/rc.slothd

common-install:	dir-install
	(cd ../common; $(MAKE) local-install)

sup-install:	dir-install

bin-install:	dir-install

etc-install:	dir-install sysetc-install

sysetc-install:	dir-install
	# Watchdog assumes the ssh keys are in /etc/ssh.
	mkdir -p /etc/ssh
	ln -f -s /etc/ssh* /etc/ssh
	# Boot log files have to be writable by root under rc.cygwin .
	$(INSTALL) -c -m 775 -o root -d /var/log
	$(INSTALL) -c -m 775 -o root -d /var/db
	ln -f -s $(SYSTEM32)/getmac.exe /bin/getmac.exe
	ln -f -s $(SYSTEM32)/devcon.exe /bin/devcon.exe

script-install:	dir-install $(SCRIPTS)
	$(INSTALL) -m 755 $(SRCDIR)/liblocsetup.pm $(BINDIR)/liblocsetup.pm
	$(INSTALL) -m 755 $(SRCDIR)/prepare $(BINDIR)/prepare
	$(INSTALL) -m 755 $(SRCDIR)/tbshutdown $(BINDIR)/tbshutdown
	$(INSTALL) -c -m 755 -o root -d /sbin
	ln -f -s /bin/shutdown /sbin/shutdown
	ln -f -s /bin/reboot   /sbin/reboot
	$(INSTALL) -m 755 $(SRCDIR)/rc.cygwinseven $(BINDIR)/rc/rc.cygwin
	$(INSTALL) -m 755 $(SRCDIR)/rc.reboot $(BINDIR)/rc/rc.reboot
	$(INSTALL) -m 755 $(SRCDIR)/rc.lmhosts $(BINDIR)/rc/rc.lmhosts
	$(INSTALL) -m 755 $(SRCDIR)/netbt $(BINDIR)/netbt
	$(INSTALL) -c -m 755 -o Administrators -d $(SPSCRIPTS)
	$(INSTALL) -m 755 $(SRCDIR)/setupnode.ps1 $(SPSCRIPTS)/setupnode.ps1
	$(INSTALL) -m 755 $(SRCDIR)/SetupComplete.cmd $(SPSCRIPTS)/SetupComplete.cmd
	$(INSTALL) -m 755 $(SRCDIR)/reboot.sh /bin/reboot
	$(INSTALL) -m 755 $(SRCDIR)/hookservices $(BINDIR)/hookservices

sfs-install:

# create ifcfg-eth? files
ifcfgs:	$(SRCDIR)/mkifcfgs $(SRCDIR)/ifcfg.template
	$(SRCDIR)/mkifcfgs $(SRCDIR)/ifcfg.template
