#
# Copyright (c) 2000-2007 University of Utah and the Flux Group.
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

SRCDIR		= ../../../tbsetup/template_cvsroot
TESTBED_SRCDIR	= ../../..
OBJDIR		= ../..
SUBDIR		= tbsetup/template_cvsroot

include $(OBJDIR)/Makeconf

#LIB_STUFF    = commit_prep commit_logmsg commit_finish
#OTHER_STUFF  = commitinfo loginfo verifymsg

LIB_STUFF    = logtag
OTHER_STUFF  = taginfo
CTRLSBIN_STUFF= rtag_commit

#
# Force dependencies on the scripts so that they will be rerun through
# configure if the .in file is changed.
# 
all: $(LIB_STUFF) $(CTRLSBIN_STUFF)

include $(TESTBED_SRCDIR)/GNUmakerules

install: \
	$(addprefix $(INSTALL_LIBDIR)/cvsroot/, $(LIB_STUFF)) \
	$(addprefix $(INSTALL_LIBDIR)/cvsroot/, $(OTHER_STUFF)) \
	$(addprefix $(INSTALL_DIR)/opsdir/sbin/, $(CTRLSBIN_STUFF)) 

$(INSTALL_LIBDIR)/cvsroot/%: %
	@echo "Installing $<"
	-mkdir -p $(INSTALL_LIBDIR)/cvsroot
	$(INSTALL) $< $@

$(INSTALL_DIR)/opsdir/sbin/%: %
	@echo "Installing $<"
	-mkdir -p $(INSTALL_DIR)/opsdir/sbin
	$(INSTALL) $< $@

clean:
