#
# Copyright (c) 2008-2010 University of Utah and the Flux Group.
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

SRCDIR		= ../../../protogeni/test
TESTBED_SRCDIR	= ../../..
OBJDIR		= ../..
SUBDIR		= protogeni/test

include $(OBJDIR)/Makeconf

# These scripts installed setuid, with sudo. 
SETUID_BIN_SCRIPTS   = 
SETUID_SBIN_SCRIPTS  = 
SETUID_LIBX_SCRIPTS  =

#
# Force dependencies on the scripts so that they will be rerun through
# configure if the .in file is changed.
# 
all:	

include $(TESTBED_SRCDIR)/GNUmakerules

FILES	 = $(wildcard *.py)
FILES   += $(wildcard $(SRCDIR)/*.py)
FILES   += $(wildcard $(SRCDIR)/*.rspec)
ALLFILES = $(notdir $(FILES))

# Gather up the AM tests and include their subdirectory
AMFILES1  = $(wildcard $(SRCDIR)/am/*.py)
AMFILES   = $(addprefix am/, $(notdir $(AMFILES1)))
ALLFILES += $(AMFILES)

TARBALL  = $(INSTALL_WWWDIR)/downloads/protogeni-tests.tar.gz

install:	install-mkdir \
	$(addprefix $(INSTALL_TOPDIR)/opsdir/protogeni/test/, $(ALLFILES)) \
	$(TARBALL)

control-install:

install-mkdir:
	-mkdir -p $(INSTALL_TOPDIR)/opsdir/protogeni/test/am

clean:
	rm -f *.o core *.pl *.pm *.py

$(INSTALL_TOPDIR)/opsdir/protogeni/test/%: %
	@echo "Installing $<"
	$(INSTALL_PROGRAM) $(subst $$,\$$,$<) $(subst $$,\$$,$@) 

$(TARBALL): $(ALLFILES)
	-mkdir -p $(INSTALL_WWWDIR)/downloads
	rm -f $(TARBALL)
	tar czf $(TARBALL) -C $(SRCDIR) $(ALLFILES)
