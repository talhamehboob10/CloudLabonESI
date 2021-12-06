#
# Copyright (c) 2004-2020 University of Utah and the Flux Group.
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
SRCDIR		= ../../../clientside/xmlrpc
TESTBED_SRCDIR	= ../../..
OBJDIR		= ../..
SUBDIR		= $(subst $(TESTBED_SRCDIR)/,,$(SRCDIR))

include $(OBJDIR)/Makeconf

BIN_SCRIPTS	= sslxmlrpc_client.py
LIB_STUFF	= emulabclient.py libxmlrpc.pm
DOWNLOAD_STUFF  = emulabclient.py README \
                  script_wrapper.py sslxmlrpc_client.py

#
# These are the ones installed on plastic (users, control, etc). 
# 
CLIENTBINS      = script_wrapper.py sslxmlrpc_client.py
USERLIBS	= emulabclient.py libxmlrpc.pm BasicXMLRPCServers.py
SYMLINKS        = node_admin node_reboot os_load create_image node_list \
		  delay_config wilink_config savelogs portstats \
		  eventsys_control \
		  readycount nscheck startexp batchexp startexp swapexp endexp \
		  modexp expinfo node_avail tbuisp expwait template_commit \
		  template_export template_swapin template_swapout \
		  template_stoprun template_instantiate template_startrun \
		  template_checkout node_avail_list mkblob rmblob \
		  createdataset deletedataset showdataset extenddataset \
		  startExperiment terminateExperiment experimentStatus \
		  extendExperiment experimentManifests imageinfo \
		  experimentReboot

LINKS		= cd $(INSTALL_BINDIR) && \
		  list='$(SYMLINKS)'; for file in $$list; do \
			rm -f $$file; \
			ln -s script_wrapper.py $$file; \
		  done;

OPSLINKS	= cd $(INSTALL_DIR)/opsdir/bin && \
		  list='$(SYMLINKS)'; for file in $$list; do \
			rm -f $$file; \
			ln -s script_wrapper.py $$file; \
		  done;

#
# Force dependencies on the scripts so that they will be rerun through
# configure if the .in file is changed.
# 
all:	$(BIN_SCRIPTS) $(LIB_STUFF) \
	$(DOWNLOAD_STUFF) $(CLIENTBINS) $(USERLIBS) BasicXMLRPCServers.py

include $(TESTBED_SRCDIR)/GNUmakerules

install: $(addprefix $(INSTALL_BINDIR)/, $(BIN_SCRIPTS)) \
	$(addprefix $(INSTALL_WWWDIR)/downloads/xmlrpc/, $(DOWNLOAD_STUFF)) \
	$(addprefix $(INSTALL_LIBDIR)/, $(LIB_STUFF)) \
	$(addprefix $(INSTALL_DIR)/opsdir/lib/, $(USERLIBS)) \
	$(addprefix $(INSTALL_DIR)/opsdir/bin/, $(CLIENTBINS))
	$(OPSLINKS)

boss-install: install

$(INSTALL_WWWDIR)/%: %
	@echo "Installing $<"
	-mkdir -p $(patsubst %/,%,$(dir $@))
	$(INSTALL_DATA) $(subst $$,\$$,$<) $(subst $$,\$$,$@) 

$(INSTALL_WWWDIR)/downloads/xmlrpc/%: %
	@echo "Installing $<"
	-mkdir -p $(patsubst %/,%,$(dir $@))
	$(INSTALL_DATA) $(subst $$,\$$,$<) $(subst $$,\$$,$@)

$(INSTALL_DIR)/opsdir/bin/%: %
	@echo "Installing $<"
	-mkdir -p $(INSTALL_DIR)/opsdir/bin
	$(INSTALL) $< $@

$(INSTALL_DIR)/opsdir/lib/%: %
	@echo "Installing $<"
	-mkdir -p $(INSTALL_DIR)/opsdir/lib
	$(INSTALL) $< $@

#
# Control node installation (okay, plastic)
#
control-install:	$(CLIENTBINS) $(USERLIBS) \
			$(addprefix $(INSTALL_LIBDIR)/, $(USERLIBS)) \
			$(addprefix $(INSTALL_BINDIR)/, $(CLIENTBINS))
	$(LINKS)

client:

client-install: client $(CLIENTBINS) $(USERLIBS) \
			$(addprefix $(INSTALL_LIBDIR)/, $(USERLIBS)) \
			$(addprefix $(INSTALL_BINDIR)/, $(CLIENTBINS))
	$(LINKS)

# Nothing installed in these targets.
subboss: 
subboss-install: 
post-install:
fs-install:
mfs:
mfs-install: 
frisbee-mfs: 
frisbee-mfs-install:
newnode-mfs:
newnode-mfs-install:

clean:

