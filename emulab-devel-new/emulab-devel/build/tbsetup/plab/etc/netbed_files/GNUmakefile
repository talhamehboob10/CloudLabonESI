#
# Copyright (c) 2003 University of Utah and the Flux Group.
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

SRCDIR		= ../../../../../tbsetup/plab/etc/netbed_files
TESTBED_SRCDIR	= ../../../../..
OBJDIR		= ../../../..
SUBDIR		= tbsetup/plab/etc/netbed_files

include $(OBJDIR)/Makeconf

SBIN_STUFF      = installcron.sh thttpd.restart
FILES_DIR	= $(INSTALL_ETCDIR)/plab/netbed_files
SBIN_DIR	= $(FILES_DIR)/sbin
LOG_DIR		= $(FILES_DIR)/log
WWW_DIR		= $(FILES_DIR)/www

include $(TESTBED_SRCDIR)/GNUmakerules

mkdirs: $(LOG_DIR) $(WWW_DIR)

install: sbin-install mkdirs

sbin-install: $(addprefix $(SBIN_DIR)/, $(SBIN_STUFF))

#
# We have to change perms on these files, because rsync will preserve them
#
post-install: 
	chmod 770 $(FILES_DIR)
	chmod 770 $(SBIN_DIR)
	chmod 770 $(LOG_DIR)
	chmod 775 $(WWW_DIR)

all: $(SBIN_STUFF)

$(SBIN_DIR)/%: %
	@echo "Installing $<"
	-mkdir -p $(SBIN_DIR)
	$(INSTALL_PROGRAM) $< $@

$(LOG_DIR):
	mkdir -p $@

$(WWW_DIR):
	mkdir -p $@

