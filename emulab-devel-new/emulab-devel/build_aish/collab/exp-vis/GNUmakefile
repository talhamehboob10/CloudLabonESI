#
# Copyright (c) 2009-2012 University of Utah and the Flux Group.
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

SRCDIR		= ../../../collab/exp-vis
TESTBED_SRCDIR	= ../../..
OBJDIR		= ../..
SUBDIR		= collab/exp-vis

include $(OBJDIR)/Makeconf

CGI_SCRIPTS = fetch-vis
LIBEXEC_SCRIPTS = write-vis-auth
CTRL_LIBEXEC_SCRIPTS = write-vis-auth.proxy

SETUID_SUEXEC_SCRIPTS = write-vis-auth

#
# Force dependencies on the scripts so that they will be rerun through
# configure if the .in file is changed.
# 
all:	$(CGI_SCRIPTS) $(LIBEXEC_SCRIPTS) $(CTRL_LIBEXEC_SCRIPTS) 

include $(TESTBED_SRCDIR)/GNUmakerules

install: \
	$(addprefix $(INSTALL_LIBEXECDIR)/, $(LIBEXEC_SCRIPTS)) \
	$(addprefix $(TBROOT)/opsdir/www/cgi-bin/, $(CGI_SCRIPTS)) \
	$(addprefix $(INSTALL_DIR)/opsdir/libexec/, $(CTRL_LIBEXEC_SCRIPTS))

$(TBROOT)/opsdir/www/cgi-bin/fetch-vis: fetch-vis
	-$(SUDO) mkdir -m 775 $(TBROOT)/opsdir/www/cgi-bin
	$(SUDO) $(INSTALL) -o root -m 4775 $< $@

$(INSTALL_DIR)/opsdir/libexec/write-vis-auth.proxy: write-vis-auth.proxy
	-mkdir -p $(INSTALL_DIR)/opsdir/libexec
	$(INSTALL) $< $@

post-install:

clean:

