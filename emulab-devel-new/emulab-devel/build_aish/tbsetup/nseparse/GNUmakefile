#
# Copyright (c) 2000-2003, 2006 University of Utah and the Flux Group.
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
SRCDIR		= ../../../tbsetup/nseparse
TESTBED_SRCDIR	= ../../..
OBJDIR		= ../..
SUBDIR		= tbsetup/nseparse

include $(OBJDIR)/Makeconf

LIB_STUFF    =  nse.node.tcl nse.sim.tcl nse.null.tcl \
		  nse.agent.tcl nse.parse.tcl tb_compat.tcl
BOSSLIBEXEC  = parse-nse
USERLIBEXEC  = nse.parse.proxy

# These scripts installed setuid, with sudo. 
SETUID_BIN_SCRIPTS   = 
SETUID_SBIN_SCRIPTS  = 
SETUID_LIBX_SCRIPTS  = parse-nse

#
# Force dependencies on the scripts so that they will be rerun through
# configure if the .in file is changed.
# 
all: $(LIB_STUFF) $(BOSSLIBEXEC) $(USERLIBEXEC)

include $(TESTBED_SRCDIR)/GNUmakerules

install:	control-install \
	$(addprefix $(INSTALL_LIBEXECDIR)/, $(BOSSLIBEXEC)) \
	$(addprefix $(INSTALL_DIR)/opsdir/lib/nseparse/, $(LIB_STUFF)) \
	$(addprefix $(INSTALL_DIR)/opsdir/libexec/nseparse/, $(USERLIBEXEC))

control-install: $(addprefix $(INSTALL_LIBDIR)/nseparse/, $(LIB_STUFF)) \
	$(addprefix $(INSTALL_LIBEXECDIR)/nseparse/, $(USERLIBEXEC))

post-install: 
	chmod 775 $(INSTALL_LIBEXECDIR)
	chown root $(INSTALL_LIBEXECDIR)/parse-nse
	chmod 775 $(INSTALL_LIBEXECDIR)/nseparse
	chmod u+s $(INSTALL_LIBEXECDIR)/parse-nse
	chmod 775 $(INSTALL_DIR)/opsdir/lib/nseparse
	chmod 775 $(INSTALL_DIR)/opsdir/libexec/nseparse

$(INSTALL_LIBDIR)/nseparse/%: %
	@echo "Installing $<"
	-mkdir -p -m 775 $(INSTALL_LIBDIR)/nseparse
	$(INSTALL) $< $@

$(INSTALL_LIBEXECDIR)/nseparse/%: %
	@echo "Installing $<"
	-mkdir -p $(INSTALL_LIBEXECDIR)/nseparse
	$(INSTALL) $< $@

$(INSTALL_DIR)/opsdir/lib/nseparse/%: %
	@echo "Installing $<"
	-mkdir -p $(INSTALL_DIR)/opsdir/lib/nseparse
	$(INSTALL) $< $@

$(INSTALL_DIR)/opsdir/libexec/nseparse/%: %
	@echo "Installing $<"
	-mkdir -p $(INSTALL_DIR)/opsdir/libexec/nseparse
	$(INSTALL) $< $@

clean:
