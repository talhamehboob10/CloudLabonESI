#
# Copyright (c) 2003 University of Utah and the Flux Group.
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
# For installation.
#
SRCDIR		= ../../../install/newnode_sshkeys
TESTBED_SRCDIR	= ../../..
OBJDIR		= ../..
SUBDIR		= install/newnode_sshkeys
TBADMINGROUP    = tbadmin

KEY_FILES	= identity.newnode identity.newnode.pub

include $(OBJDIR)/Makeconf

all:

include $(TESTBED_SRCDIR)/GNUmakerules

install: $(addprefix $(INSTALL_ETCDIR)/, $(KEY_FILES))
	chmod 600 $(INSTALL_ETCDIR)/identity.newnode

clean:
