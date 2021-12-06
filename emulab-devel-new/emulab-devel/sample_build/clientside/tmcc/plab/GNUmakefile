#
# Copyright (c) 2003-2011 University of Utah and the Flux Group.
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
SRCDIR		= ../../../../clientside/tmcc/plab
TESTBED_SRCDIR	= ../../../..
OBJDIR		= ../../..
SUBDIR		= $(subst $(TESTBED_SRCDIR)/,,$(SRCDIR))

#
# The scripts the tarball depends on
#
COMSCRIPTS	= $(addprefix $(TESTBED_SRCDIR)/tmcd/common/, \
		    paths.sh paths.pm runstartup vnodesetup update watchdog \
                    libtmcc.pm libsetup.pm libtestbed.pm startcmddone)
LINSCRIPTS	= $(TESTBED_SRCDIR)/tmcd/linux/liblocsetup.pm
PLABSCRIPTS	= $(addprefix $(TESTBED_SRCDIR)/tmcd/plab/, \
                    rc.inplab plabrusage runevents)
OSSCRIPTS	= $(addprefix $(TESTBED_SRCDIR)/os/, \
		    install-tarfile install-rpm)
EVSCRIPTS	= $(addprefix $(TESTBED_SRCDIR)/event/lib/, \
                    event.pm)
EESCRIPTS	= $(TESTBED_SRCDIR)/tmcd/plab/rc.vinit
ULEESCRIPTS	= $(COMSCRIPTS) $(LINSCRIPTS) $(PLABSCRIPTS) $(EVSCRIPTS)
ALLSCRIPTS	= $(ULEESCRIPTS) $(OSSCRIPTS) $(EESCRIPTS)
THISDIR         = $(PWD)

#
# Root of tree containing stock package stuff that is needed
# in the plab vserver environment to support Emulab (e.g. sshd)
#
PKGSRCTREE	= /share/plab/pkgroot

#
# Configuration, or other files necessary for tarball
#
ETCCONFS	= $(TESTBED_SRCDIR)/tmcd/plab/sudoers
ALLCONFS	= $(ETCCONFS)

#
# Emulab certs for tmcc communication
#
CERTS		= $(addprefix /usr/testbed/etc/, emulab.pem pcplab.pem)
ALLCERTS	= $(CERTS)

#
# Name and rootball revision
#
ROOTBALLNAME	= @PLAB_ROOTBALL@

include $(OBJDIR)/Makeconf

all:	rootball

include $(TESTBED_SRCDIR)/GNUmakerules

rootball:	$(ROOTBALLNAME)

$(ROOTBALLNAME): copyfiles mkhosts
	chown -R 0:0 plabroot
	gtar cf - --numeric-owner -C plabroot . | bzip2 -c -9 > $(ROOTBALLNAME)

copyfiles: $(ALLSCRIPTS) $(ALLCONFS) $(ALLCERTS) $(PKGSRCTREE) mkdirtree
	(cd ../common/config; $(MAKE) script-install DESTDIR=$(THISDIR)/plabroot)
	$(INSTALL_PROGRAM) $(ULEESCRIPTS) plabroot/usr/local/etc/emulab
	chmod u+s plabroot/usr/local/etc/emulab/vnodesetup
	chmod u+s plabroot/usr/local/etc/emulab/update
	$(INSTALL_PROGRAM) $(OSSCRIPTS)   plabroot/usr/local/bin
	$(INSTALL_PROGRAM) $(TESTBED_SRCDIR)/tmcd/common/tmcc.pl \
					  plabroot/usr/local/etc/emulab/tmcc
	$(INSTALL_PROGRAM) $(EESCRIPTS)   plabroot/etc
	$(INSTALL) -m 440  $(TESTBED_SRCDIR)/tmcd/plab/sudoers \
					  plabroot/etc/sudoers
	$(INSTALL_DATA) /usr/testbed/etc/pcplab.pem \
	                plabroot/usr/local/etc/emulab/client.pem
	$(INSTALL_DATA) /usr/testbed/etc/emulab.pem \
			plabroot/usr/local/etc/emulab
	cp -pR $(PKGSRCTREE)/ plabroot
	chmod 4555 plabroot/usr/local/etc/emulab/program-agent
	echo "boss.cloudlab.umass.edu" > plabroot/usr/local/etc/emulab/bossnode
	cp /dev/null plabroot/usr/local/etc/emulab/isrem

mkdirtree:
	mkdir -p plabroot/usr/local/etc/emulab/rc
	mkdir -p plabroot/usr/local/bin
	mkdir -p plabroot/usr/bin
	mkdir -p plabroot/etc
	mkdir -p plabroot/bin
	ln -fs ../usr/local/etc/emulab plabroot/etc/emulab

mkhosts:
	echo "127.0.0.1 localhost"               >  plabroot/etc/hosts
	echo "198.22.255.3 boss.cloudlab.umass.edu" >> plabroot/etc/hosts
	echo "198.22.255.4 ops.cloudlab.umass.edu" >> plabroot/etc/hosts

tmcc:
	@echo "*** Error:"
	@echo "You must copy the tmcc linux binary into this dir"
	@echo "prior to building the tarball."
	@false

install client-install:

rootball-install: 
	$(INSTALL_DATA) $(ROOTBALLNAME) $(INSTALL_ETCDIR)/plab

clean: 
	rm -rf plabroot $(ROOTBALLNAME)
