#
# Copyright (c) 2000-2004, 2007 University of Utah and the Flux Group.
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

SRCDIR		= ../../flash
TESTBED_SRCDIR	= ../..
OBJDIR		= ..
SUBDIR		= flash

SYSETCDIR	= $(DESTDIR)/etc
ETCDIR		= $(DESTDIR)$(CLIENT_ETCDIR)
BINDIR		= $(DESTDIR)$(CLIENT_BINDIR)
VARDIR		= $(DESTDIR)$(CLIENT_VARDIR)
RCDIR		= $(DESTDIR)/usr/local/etc/rc.d
INSTALL		= /usr/bin/install -c

include $(OBJDIR)/Makeconf

all:	

destdircheck:
	@if [ -z "$(DESTDIR)" ]; then \
	    echo "You must define DESTDIR for this target!"; \
	    false; \
	fi
	@if [ "$(DESTDIR)" = "/" ]; then \
	    echo "DESTDIR is '/', really really bad idea!"; \
	    false; \
	fi

client:
	$(MAKE) -C ../cdrom/groklilo client
	$(MAKE) -C ../cdrom/tbbootconfig client

client-install: destdircheck client
	$(MAKE) -C ../cdrom/groklilo client-install
	$(MAKE) -C ../cdrom/tbbootconfig client-install
	$(INSTALL) -m 644 $(SRCDIR)/rc.conf $(SYSETCDIR)/rc.conf
	$(INSTALL) -m 555 $(SRCDIR)/cdroot $(SYSETCDIR)/rc.d/cdroot
	$(INSTALL) -m 644 $(SRCDIR)/fstab $(SYSETCDIR)/fstab
	$(INSTALL) -m 644 $(SRCDIR)/loader.rc $(DESTDIR)/boot/loader.rc
	$(INSTALL) -m 440 $(SRCDIR)/sudoers $(DESTDIR)/usr/local/etc/sudoers
	rm -f $(SYSETCDIR)/rc.conf.d/dhclient
	rm -f $(DESTDIR)/usr/local/etc/emulab/dhclient
	rm -f $(DESTDIR)/etc/emulab/frisbee $(DESTDIR)/etc/emulab/growdisk
	rm -rf $(DESTDIR)/etc/emulab/supfile $(DESTDIR)/root/.cvsup
	cp /dev/null $(DESTDIR)/etc/emulab/nosup
	rm -rf $(DESTDIR)/etc/jail
	date '+FLASHBOOT-%y%m%d' > $(DESTDIR)/etc/emulab/emuboot-volid
	@echo "NOTE: you will need to install $(DESTDIR)/etc/emulab/mbr*.dd"

clean:
	$(MAKE) -C ../cdrom/groklilo clean
	$(MAKE) -C ../cdrom/tbbootconfig clean

include $(TESTBED_SRCDIR)/GNUmakerules
