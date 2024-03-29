#
# Copyright (c) 2015 University of Utah and the Flux Group.
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
#
# For installation only.
#
SRCDIR		= ../../autofs
TESTBED_SRCDIR	= ../..
OBJDIR		= ..
SUBDIR		= autofs

SYSETCDIR	= $(DESTDIR)/etc

SYSTEM	       := $(shell uname -s)
ifeq ($(SYSTEM),FreeBSD)
FBSDREL	:= $(shell uname -r | sed -e 's/\([^-][^-]*\)-.*/\1/')
FBSDMAJ := $(basename $(FBSDREL))
endif

include $(OBJDIR)/Makeconf

AUTOFS_FILES	= autofs_boss.sh

#
# Force dependencies to make sure configure regenerates if the .in file
# is changed.
# 
all: $(AUTOFS_FILES)

include $(TESTBED_SRCDIR)/GNUmakerules

freebsd-os-check:
	@if [ -z "$(FBSDMAJ)" -o $(FBSDMAJ) -lt 10 -o \
	      \( $(FBSDMAJ) -eq 10 -a \
	         \( $(FBSDREL) = "10.0" -o $(FBSDREL) = "10.1" \) \) ]; then \
	    echo "Can only install autofs on FreeBSD 10.2 or later"; \
	    false; \
	fi

first-install: freebsd-os-check install
	$(INSTALL) -m 644 $(SRCDIR)/auto_master $(SYSETCDIR)/auto_master
	ln -sf $(INSTALL_ETCDIR)/autofs_boss.sh $(SYSETCDIR)/auto_users
	ln -sf $(INSTALL_ETCDIR)/autofs_boss.sh $(SYSETCDIR)/auto_proj
	ln -sf $(INSTALL_ETCDIR)/autofs_boss.sh $(SYSETCDIR)/auto_groups
	@echo "NOTE: Be sure to add 'autofs_enable=\"YES\"' to /etc/rc.conf"

install: all
	$(INSTALL) -m 755 autofs_boss.sh $(INSTALL_ETCDIR)/autofs_boss.sh

post-install:

control-install:

clean:
	rm -f $(AUTOFS_FILES)
