#
# Copyright (c) 2000-2004 University of Utah and the Flux Group.
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

SRCDIR		= ../../../event/etc
TESTBED_SRCDIR	= ../../..
OBJDIR		= ../..
SUBDIR		= event/etc
SYS_ETCDIR	= /usr/local/etc

include $(OBJDIR)/Makeconf

CONFIGS		= elvind-inetd.conf elvind-ops.conf elvind-boss.conf

all:		$(CONFIGS)

include $(TESTBED_SRCDIR)/GNUmakerules

install: 
	$(INSTALL_DATA) elvind-boss.conf $(SYS_ETCDIR)/elvind.conf
	$(INSTALL_DATA) elvind-inetd.conf $(INSTALL_ETCDIR)/inetd.conf

control-install:
	$(INSTALL_DATA) elvind-ops.conf $(SYS_ETCDIR)/elvind.conf

clean:
	rm -f $(CONFIGS)
