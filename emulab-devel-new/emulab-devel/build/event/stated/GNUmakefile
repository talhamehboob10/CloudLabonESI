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

SRCDIR		= ../../../event/stated
TESTBED_SRCDIR	= ../../..
OBJDIR		= ../..
SUBDIR		= event/stated

include $(OBJDIR)/Makeconf

SBIN_STUFF	= stated waitForState

LIB_STUFF	= TimeoutQueue.pm StateWait.pm

all:	$(SBIN_STUFF) $(LIB_STUFF)

include $(TESTBED_SRCDIR)/GNUmakerules

install:	 all \
	$(addprefix $(INSTALL_SBINDIR)/, $(SBIN_STUFF)) \
	$(addprefix $(INSTALL_LIBDIR)/,  $(LIB_STUFF)) 

clean:
	rm -f $(SBIN_STUFF)

# not a control thing
control:
control-install: control

# not a client thing
client:
client-install: client
