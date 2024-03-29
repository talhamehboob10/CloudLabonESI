#
# Copyright (c) 2002-2012 University of Utah and the Flux Group.
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
SRCDIR		= ../../sensors
TESTBED_SRCDIR	= ../..
OBJDIR		= ..
SUBDIR		= sensors
EVENTSYS	= 1
ISMAINSITE	= 0

include $(OBJDIR)/Makeconf

SYSTEM        := $(shell uname -s)
ifeq ($(SYSTEM),FreeBSD)
FBSDVERSION   := $(shell uname -v | sed -e 's/FreeBSD \([0-9]\).*/FreeBSD\1/')
FBSDARCH      := $(shell uname -m)
endif

SUBDIRS	= powermon

# XXX a couple of FreeBSD-only utilities
ifeq ($(SYSTEM),FreeBSD)

# XXX only at Utah...
ifeq ($(ISMAINSITE),1)
# XXX ...and FreeBSD 7 and below...
ifneq ($(FBSDVERSION),FreeBSD8)
ifneq ($(FBSDVERSION),FreeBSD9)
# XXX ...and only if 32-bit (til we work out linuxthread dependency)!
ifeq ($(FREEBSDARCH),i386)
SUBDIRS += nfstrace
endif
endif
endif
endif

# XXX not on FreeBSD 5/6 til I get a chance to fix it
ifeq ($(FBSDVERSION),FreeBSD4)
SUBDIRS += and 
endif
endif

###############################################################################

## `ACTIONS' is the set of actions that may be taken on a subdirectory or on
## the current directory.  These become phony targets.
##
ACTIONS = all install client client-install control-install clean distclean

## `TARGETS' is the set of all `<subdir>.<action>' targets.
##
TARGETS = $(foreach action,$(ACTIONS),$(addsuffix .$(action),$(SUBDIRS)))

###############################################################################

## Explicitly mention `all' first, so that it will be the default target.  This
## must be a double colon rule; see the rule for `ACTIONS' below.
##
.PHONY: all
all::

## Rules for generic actions.  Each is made by applying the action to all of
## the subdirectories.  Note that these are defined as double-colon rules so
## that one can add extra statements in separate rules if necessary.
##
.PHONY: $(ACTIONS)
$(ACTIONS):: %: $(addsuffix .%,$(SUBDIRS))

## Rules for targets of the form `<subdir>.<action>'.
##
.PHONY: $(TARGETS)
$(TARGETS):
	@$(MAKE) -C $(basename $@) $(patsubst .%,%,$(suffix $@))

## Making a subdirectory is the same as making `<subdir>.<all>'.
##
.PHONY: $(SUBDIRS)
$(SUBDIRS): %: %.all

#
# Rules to regen configure written files.
#
%: %.in
	@echo "Regenerating $@"
	cd $(OBJDIR) && CONFIG_FILES=$(SUBDIR)/$@ ./config.status

###############################################################################

## Any extra actions can be defined here, e.g.:
##
## clean::
##	$(RM) core

###############################################################################

fs-install:
	@$(MAKE) -C nfstrace fs-install

mfs:
mfs-install:

.PHONY: mfs mfs-install
