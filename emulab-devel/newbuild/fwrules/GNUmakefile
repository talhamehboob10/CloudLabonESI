#
# Copyright (c) 2000-2012 University of Utah and the Flux Group.
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

SRCDIR		= ../../fwrules
TESTBED_SRCDIR	= ../..
OBJDIR		= ..
SUBDIR		= fwrules

ETCDIR          = /etc
OURDOMAIN       = cloudlab.umass.edu
ISMAINSITE	= 0

# Configure
FIREWALL_BOSS   = 0
FIREWALL_OPS    = 0
FIREWALL_BOSS_LOCALRULETMPL = 
FIREWALL_OPS_LOCALRULETMPL  = 

BOSSTOKEN       = boss
USERTOKEN       = ops

FWRULES_FILES	=
ifneq ($(FIREWALL_BOSS_LOCALRULETMPL),"")
FWRULES_FILES  += $(FIREWALL_BOSS_LOCALRULETMPL).ipfw
endif
ifeq ($(FIREWALL_BOSS),1)
FWRULES_FILES  += $(BOSSTOKEN).ipfw
endif
ifneq ($(FIREWALL_OPS_LOCALRULETMPL),"")
FWRULES_FILES  += $(FIREWALL_OPS_LOCALRULETMPL).ipfw
endif
ifeq ($(FIREWALL_OPS),1)
FWRULES_FILES  += $(USERTOKEN).ipfw
endif

include $(OBJDIR)/Makeconf

#
# Force dependencies on the scripts so that they will be rerun through
# configure if the .in file is changed.
# 
all: mkfwrules $(FWRULES_FILES)

include $(TESTBED_SRCDIR)/GNUmakerules

%.ipfw:	%.tmpl
	perl mkfwrules $< > $@

$(LOCAL_FWRULES) $(FWRULES_FILES): mkfwrules

# This is not a safe install target after initial install!
ifeq ($(FIREWALL_BOSS),1)
install:
	@echo "Are you sure you want to reinstall the fwrules files!"
	@echo "Use the install-real target if you are sure"

install-real: $(ETCDIR)/boss.ipfw
else
install:
	@echo "FIREWALL_BOSS is not set in your defs file!"
endif

ifeq ($(FIREWALL_OPS),1)
control-install:
	@echo "Are you sure you want to reinstall the fwrules files!"
	@echo "Use the control-install-real target if you are sure"

control-install-real: $(ETCDIR)/ops.ipfw
else
control-install:
	@echo "FIREWALL_OPS is not set in your defs file!"
endif

clean: 
	rm -f mkfwrules $(FWRULES_FILES)

$(ETCDIR)/%: %
	@echo "Installing $<"
	-mkdir -p $(ETCDIR)
	$(INSTALL) $< $@

