#
# Copyright (c) 2000-2013 University of Utah and the Flux Group.
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

SRCDIR		= ../../vis
TESTBED_SRCDIR	= ../..
OBJDIR		= ..
SUBDIR		= vis

include $(OBJDIR)/Makeconf

BIN_SCRIPTS	= dbvistopology
LIBEXEC_SCRIPTS = webvistopology webfloormap
LIBEXEC_VIS	= prerender render prerender_all floormap svgrender

#
# Force dependencies on the scripts so that they will be rerun through
# configure if the .in file is changed.
# 
all:	$(LIBEXEC_SCRIPTS) $(LIBEXEC_VIS) $(BIN_SCRIPTS)

include $(TESTBED_SRCDIR)/GNUmakerules

install: \
	$(addprefix $(INSTALL_BINDIR)/, $(BIN_SCRIPTS)) \
	$(addprefix $(INSTALL_LIBEXECDIR)/, $(LIBEXEC_SCRIPTS)) \
	$(addprefix $(INSTALL_LIBEXECDIR)/vis/, $(LIBEXEC_VIS))

post-install:

$(INSTALL_LIBEXECDIR)/vis/%: %
	@echo "Installing $<"
	-mkdir -p $(INSTALL_LIBEXECDIR)/vis
	$(INSTALL) $< $@

clean:
