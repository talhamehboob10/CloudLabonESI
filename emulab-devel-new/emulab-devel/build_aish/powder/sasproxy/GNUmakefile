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

SRCDIR		= ../../../powder/sasproxy
TESTBED_SRCDIR	= ../../..
OBJDIR		= ../..
SUBDIR		= powder/sasproxy
ISMAINSITE	= 0

include $(OBJDIR)/Makeconf

SUBDIRS		= 
SBIN_SCRIPTS	= sasops manage_cbsd
TESTSCRIPTS     = test1 test13
LIBEXEC_SCRIPTS	= sas_daemon sas_proxy
LIB_STUFF       = sas.pm sasutil.pm APT_SAS.pm

#
# Force dependencies on the scripts so that they will be rerun through
# configure if the .in file is changed.
#
TARGETS = $(SBIN_SCRIPTS) $(LIBEXEC_SCRIPTS) $(LIB_STUFF)

all:	$(TARGETS) $(TESTSCRIPTS)

subboss: 

include $(TESTBED_SRCDIR)/GNUmakerules

install: $(addprefix $(INSTALL_SBINDIR)/, $(SBIN_SCRIPTS)) \
	$(addprefix $(INSTALL_LIBDIR)/, $(LIB_STUFF))

boss-install: install

post-install:

control-install:

# Like the INSTALL_BINDIR target
$(INSTALL_RCDIR)/%: %
	@echo "Installing $<"
	-mkdir -p $(INSTALL_RCDIR)
	$(SUDO) $(INSTALL_PROGRAM) $< $@

# Just in case the dirs are not yet created,
$(INSTALL_SBINDIR) $(INSTALL_BINDIR):

clean:	clean-subdirs
	-rm -f $(TARGETS)

# How to recursively descend into subdirectories to make general
# targets such as `all'.
%.MAKE:
	@$(MAKE) -C $(dir $@) $(basename $(notdir $@))
%-subdirs: $(addsuffix /%.MAKE,$(SUBDIRS)) ;

.PHONY:	$(SUBDIRS) install
