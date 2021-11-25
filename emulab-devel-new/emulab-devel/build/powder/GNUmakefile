#
# Copyright (c) 2000-2021 University of Utah and the Flux Group.
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

SRCDIR		= ../../powder
TESTBED_SRCDIR	= ../..
OBJDIR		= ..
SUBDIR		= powder
ISMAINSITE	= 0
DEADMAN         = 0
RFMON           = 0
TARGETSYS       = UMASS

include $(OBJDIR)/Makeconf

SUBDIRS		= 

SBIN_SCRIPTS	= 
LIBEXEC_SCRIPTS	= $(WEB_SBIN_SCRIPTS)

ifeq ($(ISMAINSITE),1)
SBIN_SCRIPTS   += powder_keepalive powder_shutdown powderstats powder_report \
		  rfbaseline
WEB_SBIN_SCRIPTS= webpowder_shutdown
INSTALLTARGET   = mainsite-install
endif
ifeq ($(DEADMAN),1)
SBIN_SCRIPTS   += endpoint-monitor
INSTALLTARGET   = endpoint-install
endif
ifeq ($(RFMON),1)
SBIN_SCRIPTS   += pokerffe
endif
ifeq ($(TARGETSYS),POWDER-BUS)
SBIN_SCRIPTS   += mobile-update
endif

#
# Force dependencies on the scripts so that they will be rerun through
# configure if the .in file is changed.
#
TARGETS = $(SBIN_SCRIPTS) $(LIBEXEC_SCRIPTS) rfbaseline

all:	$(TARGETS)

subboss: 

include $(TESTBED_SRCDIR)/GNUmakerules

install: rfmonitor-install $(INSTALLTARGET) \
	$(addprefix $(INSTALL_SBINDIR)/, $(SBIN_SCRIPTS)) \
	$(addprefix $(INSTALL_LIBEXECDIR)/, $(LIBEXEC_SCRIPTS))

boss-install: install

rfmonitor-install: rfmonitor-subdir \
	$(INSTALL_WWWDIR)/rfmonitor/.htaccess \
	$(INSTALL_WWWDIR)/rfmonitor/listing.php

$(INSTALL_WWWDIR)/rfmonitor/.htaccess: htaccess
	$(INSTALL) -m 644 $< $@

$(INSTALL_WWWDIR)/rfmonitor/listing.php: listing.php
	$(INSTALL) -m 644 $< $@

rfmonitor-subdir:
	-mkdir -p $(INSTALL_WWWDIR)/rfmonitor
	-mkdir -p $(INSTALL_WWWDIR)/rfmonitor/archive

mainsite-install: $(INSTALL_DIR)/opsdir/sbin/rfbaseline
	$(INSTALL_DATA) $(SRCDIR)/rfbaseline.json \
		$(INSTALL_DIR)/opsdir/etc/rfbaseline.json

subboss-install: 

post-install:

endpoint-install: $(INSTALL_SBINDIR)/endpoint-monitor

endpoint-reinstall: endpoint-install
	-sudo $(INSTALL_RCDIR)/endpoint-monitor.sh stop
	sleep 1
	-sudo $(INSTALL_RCDIR)/endpoint-monitor.sh start

endpoint-remove-old:
	-$(INSTALL_RCDIR)/batterymon.sh stop
	-rm -f $(INSTALL_RCDIR)/batterymon.sh
	-pkill -l -f powder_deadman
	rm -f $(INSTALL_SBINDIR)/powder_deadman

# For install on a base station cnuc
cnuc-install: /usr/local/sbin/bs-monitor

/usr/local/sbin/bs-monitor: $(SRCDIR)/bs-monitor
	$(INSTALL_PROGRAM) $(SRCDIR)/bs-monitor /usr/local/sbin/bs-monitor

cnuc-reinstall: cnuc-install
	-systemctl stop bs-monitor
	-systemctl start bs-monitor

cnuc-systemd-install: /etc/systemd/system/bs-monitor.service

/etc/systemd/system/bs-monitor.service: $(SRCDIR)/bs-monitor.service
	$(INSTALL) -m 644 $(SRCDIR)/bs-monitor.service \
		/etc/systemd/system/bs-monitor.service
	-systemctl enable bs-monitor
	-systemctl daemon-reload
	-systemctl start bs-monitor

cnuc-systemd-remove-deadman:
	-systemctl stop bs_deadman
	-systemctl disable bs_deadman
	-rm -f /etc/systemd/system/bs_deadman.service
	-systemctl daemon-reload

#
# Control node installation (aka, ops)
#
control-install:

# Like the INSTALL_BINDIR target
$(INSTALL_RCDIR)/%: %
	@echo "Installing $<"
	-mkdir -p $(INSTALL_RCDIR)
	$(SUDO) $(INSTALL_PROGRAM) $< $@

$(INSTALL_DIR)/opsdir/sbin/%: %
	@echo "Installing $<"
	-mkdir -p $(INSTALL_DIR)/opsdir/sbin
	$(INSTALL) $< $@

# This rule says what web* script depends on which installed binary directory.
$(WEB_SBIN_SCRIPTS): $(INSTALL_SBINDIR)

# Just in case the dirs are not yet created,
$(INSTALL_SBINDIR) $(INSTALL_BINDIR):

# And then how to turn the template into the actual script. 
$(WEB_SBIN_SCRIPTS): $(TESTBED_SRCDIR)/WEBtemplate.in
	@echo "Generating $@"
	cat $< | sed -e 's,@PROGTOINVOKE@,$(word 2,$^)/$(subst web,,$@),' > $@

clean:	clean-subdirs
	-rm -f $(TARGETS) listing.php

# How to recursively descend into subdirectories to make general
# targets such as `all'.
%.MAKE:
	@$(MAKE) -C $(dir $@) $(basename $(notdir $@))
%-subdirs: $(addsuffix /%.MAKE,$(SUBDIRS)) ;

.PHONY:	$(SUBDIRS) install
