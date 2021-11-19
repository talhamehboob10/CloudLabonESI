#
# Copyright (c) 2000-2020 University of Utah and the Flux Group.
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

SRCDIR		= ../../install
TESTBED_SRCDIR	= ../..
OBJDIR		= ..
SUBDIR		= install
GENIRACK        = 0
SUBDIRS	        =

include $(OBJDIR)/Makeconf

ifeq ($(STANDALONE_CLEARINGHOUSE),0)
TARGETS	= libinstall.pm boss-install ops-install fs-install dump-descriptors \
	load-descriptors update-install update-mfs update-testbed testbed-version \
	installvars.pm emulab-install
else
TARGETS = clrhouse-install
endif

ifeq ($(GENIRACK),1)
SUBDIRS		= genirack
endif
ifeq ("UMASS","POWDER-BUS")
SUBDIRS		= powder-bus
endif

#
# Force dependencies on the scripts so that they will be rerun through
# configure if the .in file is changed.
# 
all: $(TARGETS) all-subdirs

include $(TESTBED_SRCDIR)/GNUmakerules

install: install-subdirs \
	$(INSTALL_LIBDIR)/libinstall.pm \
	$(INSTALL_LIBDIR)/installvars.pm \
	$(INSTALL_SBINDIR)/update-install \
	$(INSTALL_SBINDIR)/update-testbed \
	$(INSTALL_SBINDIR)/testbed-version \
	$(INSTALL_SBINDIR)/load-descriptors

clean: 
	rm -f $(TARGETS)

# How to recursively descend into subdirectories to make general
# targets such as `all'.
%.MAKE:
	@$(MAKE) -C $(dir $@) $(basename $(notdir $@))
%-subdirs: $(addsuffix /%.MAKE,$(SUBDIRS)) ;

.PHONY:	${SUBDIRS}
