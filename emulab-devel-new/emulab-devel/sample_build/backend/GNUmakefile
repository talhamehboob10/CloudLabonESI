#
# Copyright (c) 2000-2008 University of Utah and the Flux Group.
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

SRCDIR		= ../../backend
TESTBED_SRCDIR	= ../..
OBJDIR		= ..
SUBDIR		= backend
UNIFIED         = 0

include $(OBJDIR)/Makeconf

BIN_SCRIPTS     = newosid moduserinfo newgroup newmmlist editexp editimageid \
		  editnodetype editsitevars newimageid editgroup \
		  newimageid_ez joinproject newscript
WEB_BIN_SCRIPTS = webnewosid webmoduserinfo webnewgroup webnewmmlist \
		  webeditexp webeditimageid webeditnodetype webeditsitevars \
		  webnewimageid webeditgroup webnewimageid_ez 
WEB_SBIN_SCRIPTS= 
LIBEXEC_SCRIPTS	= $(WEB_BIN_SCRIPTS) $(WEB_SBIN_SCRIPTS)

#
# Force dependencies on the scripts so that they will be rerun through
# configure if the .in file is changed.
# 
all:	$(BIN_SCRIPTS) $(LIBEXEC_SCRIPTS)

include $(TESTBED_SRCDIR)/GNUmakerules

install: $(addprefix $(INSTALL_BINDIR)/, $(BIN_SCRIPTS)) \
	$(addprefix $(INSTALL_LIBEXECDIR)/, $(LIBEXEC_SCRIPTS))
	@echo "Don't forget to do a post-install as root"

boss-install: install

post-install: 

#
# Control node installation (okay, plastic)
#
control-install:

# This rule says what web* script depends on which installed binary directory.
$(WEB_SBIN_SCRIPTS): $(INSTALL_SBINDIR)
$(WEB_BIN_SCRIPTS):  $(INSTALL_BINDIR)

# Just in case the dirs are not yet created,
$(INSTALL_SBINDIR) $(INSTALL_BINDIR):

# And then how to turn the template into the actual script. 
$(WEB_SBIN_SCRIPTS) $(WEB_BIN_SCRIPTS): $(TESTBED_SRCDIR)/WEBtemplate.in
	@echo "Generating $@"
	cat $< | sed -e 's,@PROGTOINVOKE@,$(word 2,$^)/$(subst web,,$@),' > $@

clean:
