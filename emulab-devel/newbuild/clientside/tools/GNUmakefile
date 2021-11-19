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
SRCDIR		= ../../../clientside/tools
TESTBED_SRCDIR	= ../../..
OBJDIR		= ../..
SUBDIR		= $(subst $(TESTBED_SRCDIR)/,,$(SRCDIR))
SYSTEM         := $(shell uname -s)

include $(OBJDIR)/Makeconf

# Cygwin doesn't support/provide pcap
ifeq ($(findstring CYGWIN_NT,$(SYSTEM)), CYGWIN_NT)
SUBDIRS		= 
else
SUBDIRS		= pcapper
endif

all:	all-subdirs

include $(TESTBED_SRCDIR)/GNUmakerules

boss-install:   all boss-install-subdirs
client:		client-subdirs
client-install: client client-install-subdirs
control-install: control-install-subdirs
fs-install:
subboss:
subboss-install:
post-install:	post-install-subdirs
clean:		clean-subdirs
distclean:	distclean-subdirs
mfs:
mfs-install:
frisbee-mfs:
frisbee-mfs-install:
onie-dongle-install: 

newnode-mfs:
	@$(MAKE) -C teachswitch all

newnode-mfs-install: newnode-mfs
	@$(MAKE) -C teachswitch client-install

# How to recursively descend into subdirectories to make general
# targets such as `all'.
%.MAKE:
	@$(MAKE) -C $(dir $@) $(basename $(notdir $@))
%-subdirs: $(addsuffix /%.MAKE,$(SUBDIRS)) ;

.PHONY:	$(SUBDIRS)
