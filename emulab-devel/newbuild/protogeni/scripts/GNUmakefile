#
# Copyright (c) 2008-2021 University of Utah and the Flux Group.
# 
# {{{GENIPUBLIC-LICENSE
# 
# GENI Public License
# 
# Permission is hereby granted, free of charge, to any person obtaining
# a copy of this software and/or hardware specification (the "Work") to
# deal in the Work without restriction, including without limitation the
# rights to use, copy, modify, merge, publish, distribute, sublicense,
# and/or sell copies of the Work, and to permit persons to whom the Work
# is furnished to do so, subject to the following conditions:
# 
# The above copyright notice and this permission notice shall be
# included in all copies or substantial portions of the Work.
# 
# THE WORK IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
# OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
# HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
# WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE WORK OR THE USE OR OTHER DEALINGS
# IN THE WORK.
# 
# }}}
#

SRCDIR		= ../../../protogeni/scripts
TESTBED_SRCDIR	= ../../..
OBJDIR		= ../..
SUBDIR		= protogeni/scripts
ISCLEARINGHOUSE = 0
PGENISUPPORT    = 1

include $(OBJDIR)/Makeconf

SBIN_STUFF	= cleanupslice gencabundle cleanupticket aptssh-setup \
		  sliveraction openvpn-setup

PSBIN_STUFF	= register_resources expire_daemon gencrl postcrl \
		  addauthority getcacerts ims_daemon \
		  gencrlbundle shutdownslice remauthority listusage \
		  update reregister listhistory \
		  register_sliver sa_daemon genadmincredential \
		  getchcredential genallow_extcred advt-merge.py \
		  reservevlans delgeniuser delegatecredential \
		  updatecert fixcerts initcerts cacontrol webcacontrol \
		  genextendcred rspeclint chstats listactive \
		  maptoslice webmaptoslice setexpiration \
		  mondbd parsecert creategeniuser webcreategeniuser \
		  updategeniuser webupdategeniuser verifycert webverifycert \
		  postimagedata getimagedata triggerimageupdate \
		  deleteimagedata secureimageget genimagecredential \
		  checkgeniuser webcheckgeniuser geniboot

ifeq ($(ISCLEARINGHOUSE),1)
PSBIN_STUFF     += ch_daemon
endif

# These scripts installed setuid, with sudo. 
SETUID_BIN_SCRIPTS   = 
SETUID_SBIN_SCRIPTS  = cleanupslice gencabundle cleanupticket aptssh-setup \
			sliveraction
SETUID_LIBX_SCRIPTS  =

#
# Force dependencies on the scripts so that they will be rerun through
# configure if the .in file is changed.
# 
all:	$(SBIN_STUFF) $(PSBIN_STUFF) \
	initsite resolve resolvenode resolve-ch getversion genspeaksfor \
	shellinabox.pl

include $(TESTBED_SRCDIR)/GNUmakerules

install: apt-install \
        $(addprefix $(INSTALL_SBINDIR)/, $(SBIN_STUFF)) \
	$(addprefix $(INSTALL_SBINDIR)/protogeni/, $(PSBIN_STUFF)) \
	$(INSTALL_LIBEXECDIR)/webcacontrol \
	$(INSTALL_LIBEXECDIR)/webcreategeniuser \
	$(INSTALL_LIBEXECDIR)/webupdategeniuser \
	$(INSTALL_LIBEXECDIR)/webcheckgeniuser \
	$(INSTALL_LIBEXECDIR)/webmaptoslice \
	$(INSTALL_LIBEXECDIR)/webverifycert
	-rm -f $(INSTALL_SBINDIR)/protogeni/cleanupticket

ifeq ($(PGENISUPPORT),1)
apt-install: $(addprefix $(INSTALL_DIR)/opsdir/cgi-bin/, shellinabox.pl) \
	     $(addprefix $(INSTALL_SBINDIR)/, aptssh-setup)
else
apt-install:
endif

control-install:

clean:
	rm -f *.o core *.pl *.pm *.py $(SBIN_STUFF) $(PSBIN_STUFF)
	rm -f shellinabox.pl aptssh-setup

$(INSTALL_SBINDIR)/protogeni/%: %
	@echo "Installing $<"
	-mkdir -p $(INSTALL_SBINDIR)/protogeni
	$(INSTALL) $< $@

$(INSTALL_DIR)/opsdir/cgi-bin/shellinabox.pl: shellinabox.pl
	echo "Installing (link to wrapper) $<"
	mkdir -p $(INSTALL_DIR)/opsdir/cgi-bin
	-rm -f $@
	ln -s $(INSTALL_LIBEXECDIR)/runsuid $@
	echo "Installing (real script) $<"
	-mkdir -p $(INSTALL_DIR)/opsdir/suidbin
	$(SUDO) $(INSTALL_PROGRAM) $< $(INSTALL_DIR)/opsdir/suidbin/$<
