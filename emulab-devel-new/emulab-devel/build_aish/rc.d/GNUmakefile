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
# For installation.
#
SRCDIR		= ../../rc.d
TESTBED_SRCDIR	= ../..
OBJDIR		= ..
SUBDIR		= rc.d

WINSUPPORT      = 0
PELABSUPPORT    = 0
ELVINCOMPAT	= 0
TBMAINSITE	= 0
PROTOGENI       = 1
CLUSTER_PORTAL  = boss.emulab.net
CONFIG_TARGETSYS= 1
TARGETSYS       = UMASS
BOSSNODE        = boss.cloudlab.umass.edu
POWDER_DEADMAN  = 0
WEBSSH          = 1

SYSTEM         := $(shell uname -s)

include $(OBJDIR)/Makeconf

RC_SCRIPTS	= 2.mysql-server.sh 3.mfrisbeed.sh 3.testbed.sh \
		  2.dhcpd.sh 1.mysql-client.sh 2.tbdbcheck.sh 
SUBBOSS_SCRIPTS	= 2.dhcpd.sh 3.mfrisbeed-subboss.sh arplock.sh \
		  3.reportboot-subboss.sh
OPS_SCRIPTS     = 3.and.sh arplock-opsfs.sh \
		  3.mfrisbeed-ops.sh
ifneq ($(CLUSTER_PORTAL),)
ifeq ($(CLUSTER_PORTAL),$(BOSSNODE))
RC_SCRIPTS     += 2.portalpsd.sh
endif
endif
ifeq ($(ELVINCOMPAT),1)
OPS_SCRIPTS    += 2.elvind.sh 3.elvin_gateway.sh
endif
FS_SCRIPTS	= arplock-opsfs.sh
TIP_SCRIPTS	=

#
# A bit of wonkyness for the write back monitor:
# runs on ops on the mothership
# runs on boss on participating aggregates
#
ifeq ($(TBMAINSITE),1)
OPS_SCRIPTS	+= wbstore.sh
else
RC_SCRIPTS	+= wbstore.sh
endif

# New firewall stuff.
ifeq ($(TBMAINSITE),1)
OPS_SCRIPTS	+= 3.sshbanlist.sh
endif

ifeq ($(PROTOGENI),1)
RC_SCRIPTS	+= geniboot.sh
endif

# Powder
ifeq ($(TBMAINSITE),1)
RC_SCRIPTS	+= powder_keepalive.sh
endif
ifeq ($(POWDER_DEADMAN),1)
RC_SCRIPTS	+= endpoint-monitor.sh
endif

ifeq ($(SYSTEM),FreeBSD)
FBSDVERSION   := $(shell uname -v | sed -e 's/FreeBSD \([0-9][0-9]*\).*/FreeBSD\1/')

ifneq ($(FBSDVERSION),FreeBSD4)
ifeq ($(WINSUPPORT),1)
OPS_SCRIPTS += silly.sh
endif
# install without .sh
TIP_SCRIPTS += capture
else
RC_SCRIPTS  += 1.named.sh
TIP_SCRIPTS += capture.sh
endif
endif
ifeq ($(PELABSUPPORT),1)
OPS_SCRIPTS += pelab.sh
endif
ifeq ($(CONFIG_TARGETSYS),0)
OPS_SCRIPTS += 1.mysql-client.sh 1.mysql-server.sh 
endif
ifeq ($(WEBSSH),1)
OPS_SCRIPTS += webssh.sh
endif
ifeq ($(TARGETSYS),POWDER-BUS)
RC_SCRIPTS   += mobile-update.sh
endif

#
# Force dependencies to make sure configure regenerates if the .in file
# is changed.
# 
all: $(RC_SCRIPTS) $(OPS_SCRIPTS) $(FS_SCRIPTS) $(SUBBOSS_SCRIPTS) \
	capture.sh 3.v0_gateway.sh 2.tbdbcheck.sh

control-build:	$(OPS_SCRIPTS) 
fs-build:	$(FS_SCRIPTS) 
subboss-build:	$(SUBBOSS_SCRIPTS) 

include $(TESTBED_SRCDIR)/GNUmakerules

# Like the INSTALL_BINDIR target
$(INSTALL_RCDIR)/%: %
	@echo "Installing $<"
	-mkdir -p $(INSTALL_RCDIR)
	$(INSTALL_PROGRAM) $< $@

# special case for capture.sh -> capture
$(INSTALL_RCDIR)/capture: capture.sh
	@echo "Installing $<"
	-mkdir -p $(INSTALL_RCDIR)
	$(INSTALL_PROGRAM) capture.sh $@

$(INSTALL_RCDIR)/geniboot.sh: geniboot.sh
	@echo "Installing $<"
	-mkdir -p $(INSTALL_RCDIR)
ifeq ($(TBMAINSITE),0)
	sed -i "" -e '/portalpsd/d' geniboot.sh
endif
	$(INSTALL_PROGRAM) geniboot.sh $@

#
# Well, this is awkward.  Make sure we don't try to install anything from
# a dev tree both because it doesn't make any sense and because it would
# clobber the "real" version.
#
ifeq ($(TBROOT),/usr/testbed)

install:		$(addprefix $(INSTALL_RCDIR)/, $(RC_SCRIPTS))

control-install:	control-build \
			$(addprefix $(INSTALL_RCDIR)/, $(OPS_SCRIPTS))

fs-install:		fs-build \
			$(addprefix $(INSTALL_RCDIR)/, $(FS_SCRIPTS))

subboss-install:	subboss-build \
			$(addprefix $(INSTALL_RCDIR)/, $(SUBBOSS_SCRIPTS))

clrhouse-install:	$(INSTALL_RCDIR)/2.mysql-server.sh \
			$(INSTALL_RCDIR)/1.mysql-client.sh

gateway-install:	$(INSTALL_RCDIR)/3.v0_gateway.sh

tipserv-install:	$(addprefix $(INSTALL_RCDIR)/, $(TIP_SCRIPTS))
else
install control-install fs-install subboss-install clrhouse-install gateway-install tipserv-install:
	@echo "Cannot install startup scripts in dev tree"
endif
