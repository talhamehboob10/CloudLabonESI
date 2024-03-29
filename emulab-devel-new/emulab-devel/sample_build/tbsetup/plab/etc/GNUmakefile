#
# Copyright (c) 2000-2003 University of Utah and the Flux Group.
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

SRCDIR		= ../../../../tbsetup/plab/etc
TESTBED_SRCDIR	= ../../../..
OBJDIR		= ../../..
SUBDIR		= tbsetup/plab/etc
UNIFIED         = 0

include $(OBJDIR)/Makeconf

#
# Only do the netbed_files subdir in the main install tree
#
ifeq ($(TBROOT),/usr/testbed)
SUBDIRS		= netbed_files
NF_INSTALL	= @$(MAKE) -C netbed_files install
NF_POST_INSTALL	= @$(MAKE) -C netbed_files post-install 
else
SUBDIRS		= netbed_files
NF_INSTALL	= @$(MAKE) -C netbed_files install
NF_POST_INSTALL	= @$(MAKE) -C netbed_files post-install 
endif

ETC_STUFF       = fixsudo.sh # plabroot.tgz 

CERTS		= cacert.pem cert.pem key.pem pubkey.pem req.pem

#
# Force dependencies on the scripts so that they will be rerun through
# configure if the .in file is changed.
# 
all:	$(ETC_STUFF) $(SUBDIRS) # $(CERTS)

include $(TESTBED_SRCDIR)/GNUmakerules

install: all data-install subdir-install

#
# Automate this part at some point.
# 
data-install: $(addprefix $(INSTALL_ETCDIR)/plab/, $(ETC_STUFF)) # \
#		$(addprefix $(INSTALL_ETCDIR)/plab/, $(CERTS))
	@echo Make sure etc/plab/ has the necessary certificates
	@echo See tbsetup/plab/etc/README for instructions

post-install:  subdir-post-install
	chmod 775 $(INSTALL_ETCDIR)
	chmod 775 $(INSTALL_ETCDIR)/plab

clean:

$(INSTALL_ETCDIR)/plab/%: %
	@echo "Installing $<"
	-mkdir -p $(INSTALL_ETCDIR)/plab
	$(INSTALL_DATA) $< $@

subdir-install:
	${NF_INSTALL}

subdir-post-install:
	${NF_POST_INSTALL}
