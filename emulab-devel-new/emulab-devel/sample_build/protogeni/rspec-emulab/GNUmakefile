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

SRCDIR		= ../../../protogeni/rspec-emulab
TESTBED_SRCDIR	= ../../..
OBJDIR		= ../..
SUBDIR		= protogeni/rspec-emulab

include $(OBJDIR)/Makeconf

SUBDIRS	= 0.1 0.2 2

# xsdgen must be run manually if necessary.
all: all-subdirs

include $(TESTBED_SRCDIR)/GNUmakerules

install: 
	@$(MAKE) -C 0.1 install
	@$(MAKE) -C 0.2 install
	@$(MAKE) -C 2 install

control-install:

clean:		clean-subdirs

# How to recursively descend into subdirectories to make general
# targets such as `all'.
%.MAKE:
	@$(MAKE) -C $(dir $@) $(basename $(notdir $@))
%-subdirs: $(addsuffix /%.MAKE,$(SUBDIRS)) ;

.PHONY:	$(SUBDIRS) install
