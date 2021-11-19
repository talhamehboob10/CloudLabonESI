#
# Copyright (c) 2000-2020 University of Utah and the Flux Group.
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

SRCDIR		= ../../apt
TESTBED_SRCDIR	= ../..
OBJDIR		= ..
SUBDIR		= apt

include $(OBJDIR)/Makeconf

SUBDIRS		= 

BIN_SCRIPTS	= manage_profile manage_instance manage_dataset \
                  create_instance rungenilib ns2rspec nsgenilib.py \
                  rspec2genilib ns2genilib manage_reservations manage_gitrepo \
                  manage_images rtecheck checkprofile manage_extensions \
		  create_slivers searchip start-experiment manage_resgroup
SBIN_SCRIPTS	= apt_daemon aptevent_daemon portal_xmlrpc apt_checkup \
		  portal_monitor apt_scheduler portal_resources \
		  manage_licenses manage_aggregate \
		  rfmonitor_daemon aptimage_daemon aptexpire_daemon \
		  recalcmaxext aptresgroup_daemon aptbus_monitor \
		  aptroute_monitor manage_rfranges verifycredentials
LIB_SCRIPTS     = APT_Profile.pm APT_Instance.pm APT_Dataset.pm APT_Geni.pm \
		  APT_Aggregate.pm APT_Utility.pm APT_Rspec.pm \
		  APT_Reservation.pm APT_RFRange.pm
WEB_BIN_SCRIPTS = webmanage_profile webmanage_instance webmanage_dataset \
                  webcreate_instance webrungenilib webns2rspec webns2genilib \
		  webrspec2genilib webmanage_reservations webmanage_gitrepo \
                  webmanage_images webrtecheck websearchip webmanage_resgroup
APACHEHOOKS     = apt_gitrepo.hook
WEB_SBIN_SCRIPTS= webportal_xmlrpc webmanage_licenses webpowder_shutdown
LIBEXEC_SCRIPTS	= $(WEB_BIN_SCRIPTS) $(WEB_SBIN_SCRIPTS)
USERLIBEXEC     = rungenilib.proxy genilib-jail genilib-iocage gitrepo.proxy

# These scripts installed setuid, with sudo. 
SETUID_BIN_SCRIPTS   = rungenilib manage_gitrepo
SETUID_SBIN_SCRIPTS  = 
SETUID_SUEXEC_SCRIPTS= apt_gitrepo.hook

#
# Force dependencies on the scripts so that they will be rerun through
# configure if the .in file is changed.
# 
all:	$(BIN_SCRIPTS) $(SBIN_SCRIPTS) $(LIBEXEC_SCRIPTS) $(SUBDIRS) \
	$(LIB_SCRIPTS) $(USERLIBEXEC) $(APACHEHOOKS) all-subdirs

subboss: 

include $(TESTBED_SRCDIR)/GNUmakerules

install: $(addprefix $(INSTALL_BINDIR)/, $(BIN_SCRIPTS)) \
	$(addprefix $(INSTALL_SBINDIR)/, $(SBIN_SCRIPTS)) \
	$(addprefix $(INSTALL_LIBDIR)/, $(LIB_SCRIPTS)) \
	$(addprefix $(INSTALL_LIBEXECDIR)/, $(LIBEXEC_SCRIPTS)) \
	$(addprefix $(INSTALL_LIBEXECDIR)/, $(APACHEHOOKS)) \
	$(addprefix $(INSTALL_DIR)/opsdir/libexec/, $(USERLIBEXEC)) \
	$(addprefix $(INSTALL_DIR)/apt/, $(APACHEHOOKS)) \
	$(INSTALL_ETCDIR)/cloudlab-fedonly.json \
	$(INSTALL_ETCDIR)/cloudlab-nofed.json

boss-install: install install-subdirs
	-mkdir -p $(INSTALL_WWWDIR)/rfmonitor

subboss-install: 

post-install: 

#
# Control node installation (aka, ops)
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

clean:	clean-subdirs

# How to recursively descend into subdirectories to make general
# targets such as `all'.
%.MAKE:
	@$(MAKE) -C $(dir $@) $(basename $(notdir $@))
%-subdirs: $(addsuffix /%.MAKE,$(SUBDIRS)) ;

$(INSTALL_DIR)/opsdir/libexec/%: %
	@echo "Installing $<"
	-mkdir -p $(INSTALL_DIR)/opsdir/libexec
	$(INSTALL) $< $@

$(INSTALL_DIR)/apt/%: %
	@echo "Installing $@"
	-mkdir -p $(INSTALL_DIR)/apt
	-rm -f $(INSTALL_DIR)/apt/$<
	ln $(INSTALL_LIBEXECDIR)/$< $(INSTALL_DIR)/apt/$<

.PHONY:	$(SUBDIRS) install
