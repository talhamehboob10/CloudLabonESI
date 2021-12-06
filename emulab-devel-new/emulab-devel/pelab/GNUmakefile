#
# Copyright (c) 2007, 2008 University of Utah and the Flux Group.
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
# Standalone makefile for building Flexlab binaries
#

SUBDIRS = libnetmon magent iperfd magent/UDP/UdpServerDir

all:   all-subdirs
clean: clean-subdirs

control-install:
	@$(MAKE) -C bgmon control-install

# How to recursively descend into subdirectories to make general
# targets such as `all'.
%.MAKE:
	@$(MAKE) -C $(dir $@) $(basename $(notdir $@))
%-subdirs: $(addsuffix /%.MAKE,$(SUBDIRS)) ;

#
# Rules for making a distribution
#

# Files and directories to exclude
DISTFILE=flexlab-dist.tar.gz
EXCLUDES=CVS stub *.tar.gz supafly $(DISTFILE) *.core .\#* bgmon *.bak \
	 db doc schedmon iplane parastream .??*
	 
EXCLUDE_TARSTR=$(foreach pat,$(EXCLUDES),--exclude '$(pat)')

dist:
	$(MAKE) clean
	gtar czvf $(DISTFILE) $^ $(EXCLUDE_TARSTR) -C ../ pelab/
