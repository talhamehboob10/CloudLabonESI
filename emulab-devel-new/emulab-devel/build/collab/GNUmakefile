#
# Copyright (c) 2005-2013 University of Utah and the Flux Group.
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

SRCDIR		= ../../collab
TESTBED_SRCDIR	= ../..
OBJDIR		= ..
SUBDIR		= collab
ISMAINSITE	= 0

include $(OBJDIR)/Makeconf

SUBDIRS	= mailman cvstools jabber trac
ifeq ($(ISMAINSITE),1)
#SUBDIRS += plone
endif
ifeq ($(EXP_VIS_SUPPORT),1)
SUBDIRS += exp-vis
endif

all:	all-subdirs

include $(TESTBED_SRCDIR)/GNUmakerules

control-install: 
	@$(MAKE) -C mailman control-install
	@$(MAKE) -C cvstools control-install
	@$(MAKE) -C trac control-install
ifeq ($(ISMAINSITE),1)
	@$(MAKE) -C plone control-install
endif

install:	install-subdirs
clean:		clean-subdirs
boss-install:	install

post-install:
	@$(MAKE) -C mailman post-install
	@$(MAKE) -C cvstools post-install
	@$(MAKE) -C jabber post-install
	@$(MAKE) -C trac post-install
ifeq ($(ISMAINSITE),1)
	@$(MAKE) -C plone post-install
endif
ifeq ($(EXP_VIS_SUPPORT),1)
	@$(MAKE) -C exp-vis post-install
endif

# How to recursively descend into subdirectories to make general
# targets such as `all'.
%.MAKE:
	@$(MAKE) -C $(dir $@) $(basename $(notdir $@))
%-subdirs: $(addsuffix /%.MAKE,$(SUBDIRS)) ;

.PHONY:	$(SUBDIRS)

