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

SRCDIR		= ../../tools
TESTBED_SRCDIR	= ../..
OBJDIR		= ..
SUBDIR		= tools
ISMAINSITE	= 0

include $(OBJDIR)/Makeconf

SUBDIRS = webcamapplet whol svn

all:	all-subdirs

include $(TESTBED_SRCDIR)/GNUmakerules

client:
client-install:

post-install:
	@$(MAKE) -C whol post-install

clean:	clean-subdirs

# How to recursively descend into subdirectories to make general
# targets such as `all'.
%.MAKE:
	@$(MAKE) -C $(dir $@) $(basename $(notdir $@))
%-subdirs: $(addsuffix /%.MAKE,$(SUBDIRS)) ;

.PHONY: post-install
