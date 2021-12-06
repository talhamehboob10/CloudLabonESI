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
SRCDIR		= ../../../../tbsetup/plab/libdslice
TESTBED_SRCDIR	= ../../../..
OBJDIR		= ../../..
SUBDIR		= tbsetup/plab/libdslice

include $(OBJDIR)/Makeconf

#
# Force dependencies to make sure configure regenerates if the .in file
# is changed.
# 
all: 

include $(TESTBED_SRCDIR)/GNUmakerules

#
# Generate a list of all the files we want to install from the current
# directory and the source directory. 
#
FILES	= $(wildcard *.py)
FILES  += $(wildcard $(SRCDIR)/*.py)

DSLICEFILES  = $(wildcard dslice/*.py)
DSLICEFILES += $(wildcard $(SRCDIR)/dslice/*.py)

HTMLGENFILES  = $(wildcard HTMLgen/*.py)
HTMLGENFILES += $(wildcard $(SRCDIR)/HTMLgen/*.py)

#
# Kill the directory part of the names. The vpath rule will do the rest.
#
ALLFILES   = $(notdir $(FILES))
ALLDSLICE  = $(notdir $(DSLICEFILES))
ALLHTMLGEN = $(notdir $(HTMLGENFILES))

install: $(addprefix $(INSTALL_LIBDIR)/dslice/, $(ALLFILES)) \
	$(addprefix $(INSTALL_LIBDIR)/dslice/dslice/, $(ALLDSLICE)) \
	$(addprefix $(INSTALL_LIBDIR)/dslice/HTMLgen/, $(ALLHTMLGEN))

post-install:


$(INSTALL_LIBDIR)/dslice/%: %
	@echo "Installing $<"
	-mkdir -p $(patsubst %/,%,$(dir $@))
	$(INSTALL) $(subst $$,\$$,$<) $(subst $$,\$$,$@) 
