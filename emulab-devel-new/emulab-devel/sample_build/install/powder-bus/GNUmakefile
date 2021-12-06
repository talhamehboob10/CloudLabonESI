#
# Copyright (c) 2000-2021 University of Utah and the Flux Group.
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
SRCDIR		= ../../../install/powder-bus
TESTBED_SRCDIR	= ../../..
OBJDIR		= ../..
SUBDIR		= install/powder-bus

include $(OBJDIR)/Makeconf

TARGETS		= dhcpd.conf.frag.one getcacerts.sh \
		 idlefix idlefix.sh poweron poweron.sh batterystats

#
# Force dependencies on the scripts so that they will be rerun through
# configure if the .in file is changed.
# 
all: $(TARGETS)

include $(TESTBED_SRCDIR)/GNUmakerules

install: $(INSTALL_ETCDIR)/dhcpd.conf.frag.one \
	 $(INSTALL_SBINDIR)/run_capture \
	 $(INSTALL_RCDIR)/getcacerts.sh

install-idlefix: $(INSTALL_SBINDIR)/idlefix \
	 $(INSTALL_RCDIR)/idlefix.sh

install-poweron: $(INSTALL_SBINDIR)/poweron \
	 $(INSTALL_RCDIR)/poweron.sh

# Like the INSTALL_BINDIR target
$(INSTALL_RCDIR)/%: %
	@echo "Installing $<"
	-mkdir -p $(INSTALL_RCDIR)
	$(INSTALL_PROGRAM) $< $@

clean: 
	rm -f $(TARGETS)

