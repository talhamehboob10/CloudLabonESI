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

SRCDIR		= ../../../../protogeni/rspec-emulab/0.1
TESTBED_SRCDIR	= ../../../..
OBJDIR		= ../../..
SUBDIR		= protogeni/rspec-emulab/0.1

#
# Switch our VPATH over to where the actual files live.
#
MOSTLY_SRCDIRS  = $(subst rspec-emulab,rspec-geni,$(SRCDIR))

include $(OBJDIR)/Makeconf

SCHEMATA	= ad-common.xsd ad-top.xsd ad.xsd manifest-common.xsd \
		  manifest-request.xsd manifest-top.xsd manifest.xsd \
		  request-common.xsd request-top.xsd request.xsd

all:

include $(TESTBED_SRCDIR)/GNUmakerules

install: $(addprefix $(INSTALL_LIBDIR)/assign/0.1/, $(SCHEMATA))

control-install:

clean:
	rm -f *.o core

$(INSTALL_LIBDIR)/assign/0.1/%: %
	@echo "Installing $<"
	-mkdir -p $(INSTALL_LIBDIR)/assign/0.1
	$(INSTALL) $< $@

