#
# Copyright (c) 2008-2016 University of Utah and the Flux Group.
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

SRCDIR		= ../../protogeni
TESTBED_SRCDIR	= ../..
OBJDIR		= ..
SUBDIR		= protogeni
RSPECGENI       = $(SRCDIR)/rspec-geni/.git
ELABINELAB      = 0

include $(OBJDIR)/Makeconf

SUBDIRS	= security xmlrpc lib scripts etc rspec-emulab pubxmlrpc event

all:	check-submodule all-subdirs

include $(TESTBED_SRCDIR)/GNUmakerules

install: 
	@$(MAKE) -C security install
	@$(MAKE) -C xmlrpc install
	@$(MAKE) -C lib install
	@$(MAKE) -C scripts install
	@$(MAKE) -C etc install
	@$(MAKE) -C rspec-emulab install
	@$(MAKE) -C test install
	@$(MAKE) -C pubxmlrpc install
	@$(MAKE) -C event install

check-submodule: 
	@if [ ! -e "rspec-emulab" ]; then \
	    echo '*** rspec-emulab does not exist; you need to reconfigure!'; \
	    false; \
	fi
ifeq ($(ELABINELAB),0)
	@if [ -e "$(SRCDIR)/.git" -a ! -e "$(RSPECGENI)" ]; then \
	    echo '*** rspec-geni has not been updated; you need to reconfigure!'; \
	    false; \
	fi
endif

install-genischemacheck:
	@$(MAKE) -C lib install-genischemacheck

control-install: 

# Clearinghouse install.
clrhouse-install: install

clean:		clean-subdirs
distclean:	subdir-distclean

subdir-distclean:
	@$(MAKE) -C imagezip distclean

# How to recursively descend into subdirectories to make general
# targets such as `all'.
%.MAKE:
	@$(MAKE) -C $(dir $@) $(basename $(notdir $@))
%-subdirs: $(addsuffix /%.MAKE,$(SUBDIRS)) ;

.PHONY:	$(SUBDIRS) install
