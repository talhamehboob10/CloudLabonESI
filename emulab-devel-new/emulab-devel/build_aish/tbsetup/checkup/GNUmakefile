#
# Copyright (c) 2006 University of Utah and the Flux Group.
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
# Insert Copyright Here.
#
SRCDIR		= ../../../tbsetup/checkup
TESTBED_SRCDIR	= ../../..
OBJDIR		= ../..
SUBDIR		= tbsetup/checkup

include $(OBJDIR)/Makeconf

LIB_STUFF     = linktest.ns
LIBEXEC_STUFF = example_checkup
SBIN_STUFF    = checkup_daemon
MAN_STUFF     = checkup_daemon.8

#
# Force dependencies on the scripts so that they will be rerun through
# configure if the .in file is changed.
# 
all: $(LIB_STUFF) $(SBIN_STUFF)

include $(TESTBED_SRCDIR)/GNUmakerules

install: $(addprefix $(INSTALL_SBINDIR)/, $(SBIN_STUFF)) \
	$(addprefix $(INSTALL_LIBDIR)/checkup/, $(LIB_STUFF)) \
	$(addprefix $(INSTALL_LIBEXECDIR)/checkup/, $(LIBEXEC_STUFF)) \
	$(addprefix $(INSTALL_DIR)/man/man8/, $(MAN_STUFF))

$(INSTALL_DIR)/man/man8/%: %
	@echo "Installing $<"
	-mkdir -p $(INSTALL_DIR)/man/man8
	$(INSTALL_DATA) $< $@

$(INSTALL_LIBDIR)/checkup/%: %
	@echo "Installing $<"
	-mkdir -p $(INSTALL_LIBDIR)/checkup
	$(INSTALL_DATA) $< $@

$(INSTALL_LIBEXECDIR)/checkup/%: %
	@echo "Installing $<"
	-mkdir -p $(INSTALL_LIBEXECDIR)/checkup
	$(INSTALL) $< $@

clean:
