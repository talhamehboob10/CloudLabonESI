#
# Copyright (c) 2000-2014 University of Utah and the Flux Group.
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

SRCDIR		= ../../os
TESTBED_SRCDIR	= ../..
OBJDIR		= ..
SUBDIR		= os

LBINDIR		= $(DESTDIR)/usr/local/bin
SYSTEM	       := $(shell uname -s)

include $(OBJDIR)/Makeconf

SUBDIRS	= 

all:	all-subdirs split-image.sh

include $(TESTBED_SRCDIR)/GNUmakerules

install: $(INSTALL_SBINDIR)/split-image.sh
	$(INSTALL_PROGRAM) $(SRCDIR)/template_record \
		$(INSTALL_DIR)/opsdir/bin/template_record

control-install: 
	$(INSTALL_PROGRAM) $(SRCDIR)/template_record $(LBINDIR)/template_record

client:

client-install: client
	$(INSTALL_PROGRAM) $(SRCDIR)/template_record $(LBINDIR)/template_record

subboss: client

subboss-install: subboss client-install

mfs:

mfs-install: mfs

frisbee-mfs:

frisbee-mfs-install: frisbee-mfs

cdboot-install: mfs-install

remote-install: 

clean:		clean-subdirs
distclean:	subdir-distclean

subdir-distclean:

# How to recursively descend into subdirectories to make general
# targets such as `all'.
%.MAKE:
	@$(MAKE) -C $(dir $@) $(basename $(notdir $@))
%-subdirs: $(addsuffix /%.MAKE,$(SUBDIRS)) ;

.PHONY:	$(SUBDIRS)

