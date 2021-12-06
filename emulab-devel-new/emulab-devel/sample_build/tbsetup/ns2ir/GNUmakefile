#
# Copyright (c) 2000-2018 University of Utah and the Flux Group.
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
SRCDIR		= ../../../tbsetup/ns2ir
TESTBED_SRCDIR	= ../../..
OBJDIR		= ../..
SUBDIR		= tbsetup/ns2ir

include $(OBJDIR)/Makeconf

LIB_STUFF    = lanlink.tcl node.tcl sim.tcl tb_compat.tcl null.tcl \
		nsobject.tcl traffic.tcl vtype.tcl parse.tcl program.tcl \
		nsenode.tcl nstb_compat.tcl event.tcl firewall.tcl \
		elabinelab.ns elabinelab-withfsnode.ns \
		elabinelab-opsvm.ns elabinelab-xenopsvm.ns \
		fw.ns timeline.tcl sequence.tcl \
		topography.tcl console.tcl path.tcl \
		disk.tcl custom.tcl elabinelab-xen.ns \
		blockstore.tcl

BOSSLIBEXEC  = parse-ns
USERLIBEXEC  = parse.proxy

# These scripts installed setuid, with sudo. 
SETUID_BIN_SCRIPTS   = 
SETUID_SBIN_SCRIPTS  = 
SETUID_LIBX_SCRIPTS  = parse-ns

#
# Force dependencies on the scripts so that they will be rerun through
# configure if the .in file is changed.
# 
all: $(LIB_STUFF) $(BOSSLIBEXEC) $(USERLIBEXEC)

include $(TESTBED_SRCDIR)/GNUmakerules

install:	control-install \
	$(addprefix $(INSTALL_LIBEXECDIR)/, $(BOSSLIBEXEC)) \
	$(addprefix $(INSTALL_DIR)/opsdir/lib/ns2ir/, $(LIB_STUFF)) \
	$(addprefix $(INSTALL_DIR)/opsdir/libexec/ns2ir/, $(USERLIBEXEC))

control-install: $(addprefix $(INSTALL_LIBDIR)/ns2ir/, $(LIB_STUFF)) \
	$(addprefix $(INSTALL_LIBEXECDIR)/ns2ir/, $(USERLIBEXEC))

post-install: 
	chmod 775 $(INSTALL_LIBEXECDIR)
	chown root $(INSTALL_LIBEXECDIR)/parse-ns
	chmod 775 $(INSTALL_LIBEXECDIR)/ns2ir
	chmod u+s $(INSTALL_LIBEXECDIR)/parse-ns
	chmod 775 $(INSTALL_LIBDIR)/ns2ir
	chmod 775 $(INSTALL_DIR)/opsdir/lib/ns2ir
	chmod 775 $(INSTALL_DIR)/opsdir/libexec/ns2ir

$(INSTALL_LIBDIR)/ns2ir/%: %
	@echo "Installing $<"
	-mkdir -p $(INSTALL_LIBDIR)/ns2ir
	$(INSTALL) $< $@

$(INSTALL_LIBEXECDIR)/ns2ir/%: %
	@echo "Installing $<"
	-mkdir -p $(INSTALL_LIBEXECDIR)/ns2ir
	$(INSTALL) $< $@

$(INSTALL_DIR)/opsdir/lib/ns2ir/%: %
	@echo "Installing $<"
	-mkdir -p $(INSTALL_DIR)/opsdir/lib/ns2ir
	$(INSTALL) $< $@

$(INSTALL_DIR)/opsdir/libexec/ns2ir/%: %
	@echo "Installing $<"
	-mkdir -p $(INSTALL_DIR)/opsdir/libexec/ns2ir
	$(INSTALL) $< $@

clean:
