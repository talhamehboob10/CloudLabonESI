#
# Copyright (c) 2000-2015 University of Utah and the Flux Group.
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

SRCDIR		= ../../named
TESTBED_SRCDIR	= ../..
OBJDIR		= ..
SUBDIR		= named

ETCDIR          = /etc
NAMEDB_DIR	= $(ETCDIR)/namedb
OURDOMAIN       = cloudlab.umass.edu

# This is silly. Needs to be done properly.
TESTBED_NETWORK          = 198.22.255.0
EXTERNAL_TESTBED_NETWORK = 198.22.255.0
IPV6_ENABLED             = 0
IPV6_SUBNET_PREFIX       = 
DISABLE_NAMED_INSTALL    = 0

REVERSE_MAPNAME          = \
		$(shell echo 198.22.255.0 | sed -e 's,.0$$,,')
EXTERNAL_REVERSE_MAPNAME = \
		$(shell echo 198.22.255.0 | sed -e 's,.0$$,,')

REVFILES                 = $(REVERSE_MAPNAME).db.head
ifneq ($(REVERSE_MAPNAME), $(EXTERNAL_REVERSE_MAPNAME))
REVFILES                += $(EXTERNAL_REVERSE_MAPNAME).db.head
endif
ifeq ($(IPV6_ENABLED),1)
IPV6_MAPNAME             = \
		$(shell echo  | sed -e 's,\:,\.,g')
REVFILES                += $(IPV6_MAPNAME).db.head
endif

BOSSTOKEN       = $(shell echo boss.cloudlab.umass.edu | sed -e 's/\..*//')
USERTOKEN       = $(shell echo ops.cloudlab.umass.edu | sed -e 's/\..*//')

NAMED_FILES	= named.conf.template named_makeconf named_makerev \
		 reverse.head \
		 resolv.conf localhost.rev forward.head named_makeforw \
		 $(REVFILES) $(OURDOMAIN).db.head\
		 $(OURDOMAIN).internal.db.head \
		 named.conf resolv.conf.ops mail.access

include $(OBJDIR)/Makeconf

#
# Force dependencies on the scripts so that they will be rerun through
# configure if the .in file is changed.
# 
all: $(NAMED_FILES)
	echo $(REVFILES)

include $(TESTBED_SRCDIR)/GNUmakerules

$(OURDOMAIN).db.head: forward.head named_makeforw
	perl named_makeforw -external forward.head > $@

$(OURDOMAIN).internal.db.head: forward.head named_makeforw
	perl named_makeforw -internal forward.head > $@

named.conf:	named.conf.template named_makeconf
	perl named_makeconf named.conf.template > named.conf

mail.access: mail_makeaccess
	perl mail_makeaccess > mail.access

$(REVFILES):	reverse.head named_makerev
	perl named_makerev reverse.head

# This is not a safe install target after initial install!
install:
	@echo "Are you sure you want to reinstall the namedb files!"
	@echo "Use the install-real target if you are sure"

ifeq ($(DISABLE_NAMED_INSTALL),0)
install-real:	install-real-force
else
install-real:	
	@echo "Refusing to install cause DISABLE_NAMED_INSTALL=1";
	@echo "Use the install-real-force target if you are sure"
endif

install-real-force: \
		resolv.conf \
		$(NAMEDB_DIR)/named.conf \
		$(NAMEDB_DIR)/localhost.rev \
		install-reverse install-head
	$(INSTALL_DATA) resolv.conf $(ETCDIR)/resolv.conf

install-reverse: \
		$(addprefix $(NAMEDB_DIR)/reverse/, $(wildcard *.db.head))

install-head: \
		$(NAMEDB_DIR)/$(OURDOMAIN).db.head \
		$(NAMEDB_DIR)/$(OURDOMAIN).internal.db.head

clean: 
	rm -f $(NAMED_FILES)

$(ETCDIR)/%: %
	@echo "Installing $<"
	-mkdir -p $(ETCDIR)
	$(INSTALL) $< $@

$(NAMEDB_DIR)/%: %
	@echo "Installing $<"
	-mkdir -p $(NAMEDB_DIR)
	$(INSTALL) $< $@

$(NAMEDB_DIR)/reverse/%: %
	@echo "Installing $<"
	-mkdir -p $(NAMEDB_DIR)/reverse
	$(INSTALL) $< $@

