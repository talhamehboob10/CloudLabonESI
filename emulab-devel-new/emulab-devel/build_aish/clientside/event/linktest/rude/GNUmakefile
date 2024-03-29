#
# Copyright (c) 2000-2011 University of Utah and the Flux Group.
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
SRCDIR		= ../../../../../clientside/event/linktest/rude
TESTBED_SRCDIR	= ../../../../..
OBJDIR		= ../../../..
SUBDIR		= $(subst $(TESTBED_SRCDIR)/,,$(SRCDIR))

# be sure to change version in rude-fetch.sh too
VERSION		= 0.70
TARBALL		= rude-0.70.tar.gz

include $(OBJDIR)/Makeconf

SYSTEM         := $(patsubst CYGWIN%,CYGWIN,$(shell uname -s))

ifeq ($(host_cpu),arm)
# not on stargates
TARGETS =
ITARGETS =
else
TARGETS = src/emulab-rude
ITARGETS = rude-install crude-install
endif

all: $(TARGETS)

include $(TESTBED_SRCDIR)/GNUmakerules

# Next two rules for linux, where make=gmake.
%-am:		Makefile force
	$(MAKE) -f Makefile $@

%-recursive:	Makefile force
	$(MAKE) -f Makefile $@

src/emulab-rude:	rude-$(VERSION) config.status build-rude

build-rude: Makefile
	$(MAKE) -f Makefile all

client: all

rude-install: build-rude
	$(INSTALL_PROGRAM) -s rude/rude $(DESTDIR)$(CLIENT_BINDIR)/emulab-rude

crude-install: build-rude
	$(INSTALL_PROGRAM) -s crude/crude $(DESTDIR)$(CLIENT_BINDIR)/emulab-crude

client-install: $(ITARGETS)

# Note: GNU make wants to pass options in MAKEFLAGS (w) that are incompatible
# with BSD make.  So we just force configure to assume/use gmake for BSD.
config.status:
	MAKE=$(MAKE) rude-$(VERSION)/configure $(CONFIG_ARGS)

rude-$(VERSION):
	$(SRCDIR)/rude-fetch.sh $(SRCDIR) $(TARBALL)

clean:
	@if [ -r Makefile ]; then $(MAKE) -f Makefile clean; fi

reallyclean:
	rm -rf rude-$(VERSION) $(TARBALL)

Makefile: config.status

force: ;
