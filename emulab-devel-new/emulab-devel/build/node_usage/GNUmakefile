#
# Copyright (c) 2009-2015 University of Utah and the Flux Group.
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

SRCDIR		= ../../node_usage
TESTBED_SRCDIR	= ../..
OBJDIR		= ..
SUBDIR		= node_usage

include $(OBJDIR)/Makeconf

ifeq ($(NODE_USAGE_SUPPORT),1)
LIBEXEC_NODE_USAGE = analy mk-plots refresh analy2 gather publish mk-php-pages get-start-date freenodes
else
LIBEXEC_NODE_USAGE =
endif

#
# These are Utah emulab specific
#
NODE_USAGE_OTHER = from_ptop sanity

#
# Force dependencies on the scripts so that they will be rerun through
# configure if the .in file is changed.
# 
all:	$(LIBEXEC_NODE_USAGE)

include $(TESTBED_SRCDIR)/GNUmakerules

install: \
	$(addprefix $(INSTALL_LIBEXECDIR)/node_usage/, $(LIBEXEC_NODE_USAGE))

$(INSTALL_LIBEXECDIR)/node_usage/%: %
	@echo "Installing $<"
	sudo mkdir -p /users/mshobana/emulab-devel/build/data/node_usage
	sudo chmod 775 /users/mshobana/emulab-devel/build/data/node_usage
	mkdir -p $(INSTALL_LIBEXECDIR)/node_usage
	chmod 775 $(INSTALL_LIBEXECDIR)/node_usage
	$(INSTALL) $< $@

post-install:

clean:

