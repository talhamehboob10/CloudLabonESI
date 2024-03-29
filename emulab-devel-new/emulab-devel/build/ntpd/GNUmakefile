#
# Copyright (c) 2014 University of Utah and the Flux Group.
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
# For installation only.
#
SRCDIR		= ../../ntpd
TESTBED_SRCDIR	= ../..
OBJDIR		= ..
SUBDIR		= ntpd

NTPSERVER	= ops

include $(OBJDIR)/Makeconf

CONFIG_FILES	= ntp.conf-client ntp.conf-server ntp.conf-external
ifeq ($(NTPSERVER),boss)
BOSS_FILE=ntp.conf-server
OPS_FILE=ntp.conf-client
FS_FILE=ntp.conf-client
else
ifeq ($(NTPSERVER),ops)
BOSS_FILE=ntp.conf-client
OPS_FILE=ntp.conf-server
FS_FILE=ntp.conf-client
else
ifeq ($(NTPSERVER),fs)
$(error we do not support NTP server on FS node right now)
else
BOSS_FILE=ntp.conf-external
OPS_FILE=ntp.conf-external
FS_FILE=ntp.conf-external
endif
endif
endif
NODE_FILE=ntp.conf-node

#
# Force dependencies to make sure configure regenerates if the .in file
# is changed.
# 
all: $(CONFIG_FILES) $(NODE_FILE)

include $(TESTBED_SRCDIR)/GNUmakerules

#
# Well, this is awkward.  Make sure we don't try to install anything from
# a dev tree both because it doesn't make any sense and because it would
# clobber the "real" version.
#
ifeq ($(TBROOT),/usr/testbed)
install: $(BOSS_FILE) clientconfig
	mv -f $(DESTDIR)/etc/ntp.conf $(DESTDIR)/etc/ntp.conf.bak
	$(INSTALL_DATA) $(BOSS_FILE) $(DESTDIR)/etc/ntp.conf
control-install: $(OPS_FILE)
	mv -f $(DESTDIR)/etc/ntp.conf $(DESTDIR)/etc/ntp.conf.bak
	$(INSTALL_DATA) $(OPS_FILE) $(DESTDIR)/etc/ntp.conf
fs-install: $(FS_FILE)
	mv -f $(DESTDIR)/etc/ntp.conf $(DESTDIR)/etc/ntp.conf.bak
	$(INSTALL_DATA) $(FS_FILE) $(DESTDIR)/etc/ntp.conf
clientconfig: $(NODE_FILE)
	$(INSTALL_DATA) $(NODE_FILE) $(TBROOT)/etc/image_ntp.conf
else
install control-install fs-install clientconfig:
	@echo "Cannot install NTP config in dev tree"
endif

clean:
	rm -f $(CONFIG_FILES)
