#
# Copyright (c) 2006-2010 University of Utah and the Flux Group.
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
# Insert Copyright Here.
#
SRCDIR		= ../../../tbsetup/nsverify
TESTBED_SRCDIR	= ../../..
OBJDIR		= ../..
SUBDIR		= tbsetup/nsverify

# XXX these need to be in synch with ns-fetch.sh
NS_VERSION=2.34
TCLCL_VERSION=1.19

NS_SRC_TARBALL=ns-allinone-$(NS_VERSION).tar.gz
LOCALPKGHOST	= 
FETCH		= fetch -m

include $(OBJDIR)/Makeconf

LIB_STUFF = tb_compat.tcl
LIBEXEC_STUFF = nstbparse
BOSSLIBEXEC = verify-ns

# These scripts installed setuid, with sudo. 
SETUID_BIN_SCRIPTS   = 
SETUID_SBIN_SCRIPTS  = 
SETUID_LIBX_SCRIPTS  = verify-ns

all: $(LIB_STUFF) $(LIBEXEC_STUFF) $(BOSSLIBEXEC)

include $(TESTBED_SRCDIR)/GNUmakerules

install: \
	$(addprefix $(INSTALL_LIBEXECDIR)/, $(BOSSLIBEXEC)) \
	$(addprefix $(INSTALL_DIR)/opsdir/lib/nsverify/, $(LIB_STUFF)) \
	$(addprefix $(INSTALL_DIR)/opsdir/libexec/nsverify/, $(LIBEXEC_STUFF))

post-install: 
	chmod 775 $(INSTALL_LIBEXECDIR)
	chown root $(INSTALL_LIBEXECDIR)/verify-ns
	chmod u+s $(INSTALL_LIBEXECDIR)/verify-ns

ns-allinone-$(NS_VERSION):
	$(SRCDIR)/ns-fetch.sh $(SRCDIR) $(NS_SRC_TARBALL) $(LOCALPKGHOST)

nstb: ns-allinone-$(NS_VERSION)
	@cd $</tclcl-$(TCLCL_VERSION); \
		./configure --with-tcl=/usr/local; \
		$(MAKE)
	@cd $</ns-$(NS_VERSION); \
		./configure; \
		$(MAKE)
	cp $</ns-$(NS_VERSION)/ns $@

control-install: $(LIB_STUFF) $(LIBEXEC_STUFF) nstb \
	$(addprefix $(INSTALL_LIBDIR)/nsverify/, $(LIB_STUFF)) \
	$(addprefix $(INSTALL_LIBEXECDIR)/nsverify/, $(LIBEXEC_STUFF) nstb)

$(INSTALL_LIBDIR)/nsverify/%: %
	@echo "Installing $<"
	-mkdir -p $(INSTALL_LIBDIR)/nsverify
	$(INSTALL) $< $@

$(INSTALL_LIBEXECDIR)/nsverify/%: %
	@echo "Installing $<"
	-mkdir -p $(INSTALL_LIBEXECDIR)/nsverify
	$(INSTALL) $< $@

$(INSTALL_DIR)/opsdir/lib/nsverify/%: %
	@echo "Installing $<"
	-mkdir -p $(INSTALL_DIR)/opsdir/lib/nsverify
	$(INSTALL) $< $@

$(INSTALL_DIR)/opsdir/libexec/nsverify/%: %
	@echo "Installing $<"
	-mkdir -p $(INSTALL_DIR)/opsdir/libexec/nsverify
	$(INSTALL) $< $@

clean:
	rm -f $(LIB_STUFF) $(LIBEXEC_STUFF) $(BOSSLIBEXEC)

reallyclean:
	rm -rf ns-allinone-$(NS_VERSION) $(NS_SRC_TARBALL)
