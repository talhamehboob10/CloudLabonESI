#
# Copyright (c) 2000-2013 University of Utah and the Flux Group.
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

SRCDIR		= ../../../protogeni/pubxmlrpc
TESTBED_SRCDIR	= ../../..
OBJDIR		= ../..
SUBDIR		= protogeni/pubxmlrpc

include $(OBJDIR)/Makeconf

# These scripts installed setuid, with sudo. 
SETUID_BIN_SCRIPTS   = 
SETUID_SBIN_SCRIPTS  = 
SETUID_SUEXEC_SCRIPTS  = pubgeni-wrapper.pl

#
# Force dependencies on the scripts so that they will be rerun through
# configure if the .in file is changed.
# 
all:	geni-sr.pm pubgeni-wrapper.pl

include $(TESTBED_SRCDIR)/GNUmakerules

install-libs: $(INSTALL_LIBDIR)/geni-sr.pm

install-scripts: $(INSTALL_LIBEXECDIR)/pubgeni-wrapper.pl
	-mkdir -m 0775 -p $(INSTALL_DIR)/protogeni/pubxmlrpc
	-rm -f $(INSTALL_DIR)/protogeni/pubxmlrpc/pubgeni-wrapper.pl
	ln  $< $(INSTALL_DIR)/protogeni/pubxmlrpc/pubgeni-wrapper.pl

install: all install-libs install-scripts

control-install:

clean:
	rm -f *.o core *.pl *.pm *.py

$(INSTALL_DIR)/protogeni/pubxmlrpc/%: %
	@echo "Installing $<"
	-mkdir -m 0775 -p $(INSTALL_DIR)/protogeni/pubxmlrpc
	$(INSTALL) $< $@
