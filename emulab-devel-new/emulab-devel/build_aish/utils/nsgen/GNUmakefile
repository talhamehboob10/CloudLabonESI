#
# Copyright (c) 2000-2003 University of Utah and the Flux Group.
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

SRCDIR		= ../../../utils/nsgen
TESTBED_SRCDIR	= ../../..
OBJDIR		= ../..
SUBDIR		= utils/nsgen

include $(OBJDIR)/Makeconf

BIN_STUFF	= nsgen
LIBEXEC_STUFF	= webnsgen

XML_STUFF	= $(notdir $(wildcard $(SRCDIR)/*.xml))

all:

include $(TESTBED_SRCDIR)/GNUmakerules

install:	install-bin install-data

install-bin:	$(addprefix $(INSTALL_BINDIR)/, $(BIN_STUFF)) \
		$(addprefix $(INSTALL_LIBEXECDIR)/, $(LIBEXEC_STUFF))

install-data:	$(addprefix $(INSTALL_ETCDIR)/nsgen/, $(XML_STUFF))

$(INSTALL_ETCDIR)/nsgen/%: %
	@echo "Installing $<"
	-mkdir -p $(INSTALL_ETCDIR)/nsgen
	$(INSTALL_DATA) $< $@
