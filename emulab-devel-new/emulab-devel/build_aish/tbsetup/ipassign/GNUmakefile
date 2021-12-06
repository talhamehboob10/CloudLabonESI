#
# Copyright (c) 2000-2003 University of Utah and the Flux Group.
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

SRCDIR		= ../../../tbsetup/ipassign
TESTBED_SRCDIR	= ../../..
OBJDIR		= ../..
SUBDIR		= tbsetup/ipassign
UNIFIED         = 0

include $(OBJDIR)/Makeconf

IPASSIGN_SCRIPTS = ipassign_wrapper

#
# Force dependencies on the scripts so that they will be rerun through
# configure if the .in file is changed.
# 
all:	src $(IPASSIGN_SCRIPTS)

include $(TESTBED_SRCDIR)/GNUmakerules

.PHONY:	src

src:
	@$(MAKE) -C src all

install: all subdir-install script-install

#
# Automate this part at some point.
# 

script-install:		$(addprefix $(INSTALL_LIBEXECDIR)/, $(IPASSIGN_SCRIPTS))

subdir-install:
	@$(MAKE) -C src install

post-install: 
	@$(MAKE) -C src post-install

clean:	subdir-clean
	-rm -f $(IPASSIGN_SCRIPTS)

subdir-clean:
	@$(MAKE) -C src clean

distclean:	subdir-distclean

subdir-distclean:
	@$(MAKE) -C src distclean










