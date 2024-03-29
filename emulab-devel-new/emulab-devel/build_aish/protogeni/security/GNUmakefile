#
# Copyright (c) 2000-2009 University of Utah and the Flux Group.
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

SRCDIR		= ../../../protogeni/security
TESTBED_SRCDIR	= ../../..
OBJDIR		= ../..
SUBDIR		= protogeni/security

include $(OBJDIR)/Makeconf

SBIN_STUFF	= signgenicred verifygenicred
LIBEXEC_STUFF	= 
CTRLSBIN_STUFF  =
LIBFILES        = credential.xsd sig.xsd xml.xsd top.xsd \
		  protogeni-rspec-common.xsd

# These scripts installed setuid, with sudo. 
SETUID_BIN_SCRIPTS   = 
SETUID_SBIN_SCRIPTS  = 
SETUID_LIBX_SCRIPTS  =

#
# Force dependencies on the scripts so that they will be rerun through
# configure if the .in file is changed.
# 
all:	$(SBIN_STUFF) $(LIBEXEC_STUFF) $(CTRLSBIN_STUFF) $(LIBFILES)

include $(TESTBED_SRCDIR)/GNUmakerules

install: all script-install
	@echo "Don't forget to do a post-install as root"

script-install:	$(addprefix $(INSTALL_SBINDIR)/, $(SBIN_STUFF)) \
	 $(addprefix $(INSTALL_LIBEXECDIR)/, $(LIBEXEC_STUFF)) \
         $(addprefix $(INSTALL_LIBDIR)/protogeni/security/, $(LIBFILES))

post-install: 
	chmod 775 $(INSTALL_BINDIR)
	chmod 775 $(INSTALL_SBINDIR)
	chmod 775 $(INSTALL_LIBDIR)
	chmod 775 $(INSTALL_LIBEXECDIR)

control-install:

# This rule says what web* script depends on which installed binary directory.
$(LIBEXEC_STUFF): $(INSTALL_SBINDIR)

# Just in case the dirs are not yet created,
$(INSTALL_SBINDIR):

clean:
	rm -f *.o core $(SBIN_STUFF)

$(INSTALL_DIR)/opsdir/sbin/%: %
	@echo "Installing $<"
	-mkdir -p $(INSTALL_DIR)/opsdir/sbin
	$(INSTALL) $< $@

$(INSTALL_LIBDIR)/protogeni/security/%: %
	@echo "Installing $<"
	-mkdir -p $(INSTALL_LIBDIR)/protogeni/security
	$(INSTALL) $< $@
