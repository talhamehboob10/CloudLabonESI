#
# Copyright (c) 2000-2005 University of Utah and the Flux Group.
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

SRCDIR		= ../../../sensors/powermon
TESTBED_SRCDIR	= ../../..
OBJDIR		= ../..
SUBDIR		= sensors/powermon

include $(OBJDIR)/Makeconf

SBIN_STUFF	= powermon

#
# Force dependencies on the scripts so that they will be rerun through
# configure if the .in file is changed.
# 
all:	$(SBIN_STUFF)

include $(TESTBED_SRCDIR)/GNUmakerules

install: all script-install
	@echo "Don't forget to do a post-install as root"

boss-install: install

#
# Automate this part at some point.
# 
script-install:	$(addprefix $(INSTALL_SBINDIR)/, $(SBIN_STUFF))

post-install: 
	chmod 775 $(INSTALL_SBINDIR)

#
# Control node installation (okay, plastic)
#
control-install:

#
# Tip server installation
#
tipserv-install:

#
# Client side
#
client:
client-install: client

clean:	subdir-clean
	rm -f $(SBIN_STUFF)

subdir-clean:

distclean:	subdir-distclean

subdir-distclean:
