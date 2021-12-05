#
# Copyright (c) 2000-2011, 2014 University of Utah and the Flux Group.
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

SRCDIR		= ../../account
TESTBED_SRCDIR	= ../..
OBJDIR		= ..
SUBDIR		= account
UNIFIED         = 0

include $(OBJDIR)/Makeconf

SBIN_STUFF	= tbacct addsfskey addpubkey mkusercert quotamail genpubkeys \
		  newuser newproj mksyscert spewcert dumpuser dumpproject \
		  manageremote
LIBEXEC_STUFF	= webtbacct webaddsfskey webaddpubkey webmkusercert \
		  webnewuser webnewproj webspewcert webmanageremote
CTRLSBIN_STUFF  = adduserhook accountsetup

# These scripts installed setuid, with sudo. 
SETUID_BIN_SCRIPTS   = 
SETUID_SBIN_SCRIPTS  = tbacct addpubkey mkusercert mksyscert
SETUID_LIBX_SCRIPTS  =

ifeq ($(PROTOGENI_SUPPORT),1)
SBIN_STUFF += manageremote
SETUID_SBIN_SCRIPTS += manageremote
endif

#
# Targets
#
ifeq ($(STANDALONE_CLEARINGHOUSE),0)
TARGETS	= $(SBIN_STUFF) $(LIBEXEC_STUFF) $(CTRLSBIN_STUFF)
else
TARGETS = mksyscert
SETUID_SBIN_SCRIPTS  = mksyscert
endif

#
# Force dependencies on the scripts so that they will be rerun through
# configure if the .in file is changed.
# 
all:	$(TARGETS)

include $(TESTBED_SRCDIR)/GNUmakerules

ifeq ($(STANDALONE_CLEARINGHOUSE),0)
install: boss-install
else
install: clrhouse-install
endif

boss-install: all script-install
	@echo "Don't forget to do a post-install as root"

script-install:	$(addprefix $(INSTALL_SBINDIR)/, $(SBIN_STUFF)) \
	 $(addprefix $(INSTALL_LIBEXECDIR)/, $(LIBEXEC_STUFF)) \
	$(addprefix $(INSTALL_DIR)/opsdir/sbin/, $(CTRLSBIN_STUFF))

post-install: 
	chmod 775 $(INSTALL_BINDIR)
	chmod 775 $(INSTALL_SBINDIR)
	chmod 775 $(INSTALL_LIBDIR)
	chmod 775 $(INSTALL_LIBEXECDIR)
	chown root $(INSTALL_SBINDIR)/tbacct
	chmod u+s $(INSTALL_SBINDIR)/tbacct
	chown root $(INSTALL_SBINDIR)/addpubkey
	chmod u+s $(INSTALL_SBINDIR)/addpubkey
	chown root $(INSTALL_SBINDIR)/mkusercert
	chmod u+s $(INSTALL_SBINDIR)/mkusercert

control-install:

hook-install: $(addprefix $(INSTALL_DIR)/opsdir/sbin/, $(CTRLSBIN_STUFF))

# Clearinghouse install.
clrhouse-install: $(INSTALL_SBINDIR)/mksyscert

# This rule says what web* script depends on which installed binary directory.
$(LIBEXEC_STUFF): $(INSTALL_SBINDIR)

# Just in case the dirs are not yet created,
$(INSTALL_SBINDIR):

# And then how to turn the template into the actual script. 
$(LIBEXEC_STUFF): $(TESTBED_SRCDIR)/WEBtemplate.in
	@echo "Generating $@"
	cat $< | sed -e 's,@PROGTOINVOKE@,$(word 2,$^)/$(subst web,,$@),' > $@

clean:
	rm -f *.o core

$(INSTALL_DIR)/opsdir/sbin/%: %
	@echo "Installing $<"
	-mkdir -p $(INSTALL_DIR)/opsdir/sbin
	$(INSTALL) $< $@
