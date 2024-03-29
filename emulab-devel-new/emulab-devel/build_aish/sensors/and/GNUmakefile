#
# Copyright (c) 2004, 2005 University of Utah and the Flux Group.
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
# This is the Emulab specific makefile.
#

#
# Makefile for auto nice daemon
#
# 1999-2004 Patrick Schemitz <schemitz@users.sourceforge.net>
# http://and.sourceforge.net/
#

SRCDIR          = ../../../sensors/and
TESTBED_SRCDIR  = ../../..
OBJDIR          = ../..
SUBDIR          = sensors/and

include $(OBJDIR)/Makeconf

all: and doc and-emulab.conf

include $(TESTBED_SRCDIR)/GNUmakerules

#
# Init script.
#
INITSCRIPT=and.init

#
# Install to the ops directory.
#
PREFIX=$(INSTALL_DIR)/opsdir
INSTALL_ETC=$(PREFIX)/etc
INSTALL_INITD=$(PREFIX)/etc/rc.d
INSTALL_SBIN=$(PREFIX)/sbin
INSTALL_MAN=$(PREFIX)/man

#
# Version and date
#
VERSION=1.2.1-emulab
DATE="25 Oct 2004"

#
# Man pages
#
MANPAGES=and.8 and.conf.5 and.priorities.5

#
# Determine architecture from uname(1)
#
ARCH=$(shell uname)

#
# Architecture-dependent settings: ANSI C compiler and linker
#
ifeq (${ARCH},Linux)
  LIBS =
else
ifeq (${ARCH},OSF1)
  LIBS =
else
ifeq (${ARCH},OpenBSD)
  LIBS = -lkvm
else
ifeq (${ARCH},FreeBSD)
  LIBS = -lkvm
endif
endif
endif
endif


#
# Build the auto-nice daemon.
#
and: and.o $(INITSCRIPT) and-$(ARCH).o
	$(LD) and.o and-$(ARCH).o -o and $(LIBS)


#
# Independent part: configuration management, priority database.
#
# XXX Emulab note: We cannot use INSTALL_ETC for the paths since those may
# not exist on ops.
#
and.o: and.c and.h
	$(CC) -DDEFAULT_INTERVAL=60 -DDEFAULT_NICE=0 \
	  -DDEFAULT_CONFIG_FILE=\"$(INSTALL_DIR)/etc/and.conf\" \
	  -DDEFAULT_DATABASE_FILE=\"$(INSTALL_DIR)/etc/and.priorities\" \
	  -DAND_VERSION=\"$(VERSION)\" -DAND_DATE=\"$(DATE)\" -c $<


#
# Unix variant specific stuff
#
and-Linux.o: and-Linux.c and.h
	$(CC) -c $<

and-OpenBSD.o: and-OpenBSD.c and.h
	$(CC) -c $<

and-FreeBSD.o: and-OpenBSD.c and.h
	$(CC) -c $< -o $@

and-OSF1.o: and-OSF1.c and.h
	$(CC) -c $< $@

and-IRIX.o: and-OSF1.c and.h
	$(CC) -c $< -o $@

and-IRIX64.o: and-OSF1.c and.h
	$(CC) -c $< -o $@

and-SunOS.o: and-OSF1.c and.h
	$(CC) -c $< -o $@



#
# Create script for SysV init
#
and.init: and.startup
	sed s:INSTALL_SBIN:$(INSTALL_SBINDIR):g < $< > $@
	chmod +x and.init


#
# Man pages
#
doc:	$(MANPAGES)

and.8:	and.8.man
	cat $< | \
		sed s/__VERSION__/$(VERSION)/g | \
		sed s/__DATE__/$(DATE)/g > $@

and.conf.5:	and.conf.5.man
	cat $< | \
		sed s/__VERSION__/$(VERSION)/g | \
		sed s/__DATE__/$(DATE)/g > $@

and.priorities.5:	and.priorities.5.man
	cat $< | \
		sed s/__VERSION__/$(VERSION)/g | \
		sed s/__DATE__/$(DATE)/g > $@

#
# Nothing to do for client install.
#
client client-install:

#
# Install and under $(PREFIX)/bin etc.
#
install: all
	strip and
#-mkdir $(PREFIX)
	-mkdir -p $(DESTDIR)$(INSTALL_SBIN)
	-mkdir -p $(DESTDIR)$(INSTALL_ETC)
	-mkdir -p $(DESTDIR)$(INSTALL_INITD)
	-mkdir -p $(DESTDIR)$(INSTALL_MAN)/man5
	-mkdir -p $(DESTDIR)$(INSTALL_MAN)/man8
	$(INSTALL) -m 0755 and $(DESTDIR)$(INSTALL_SBIN)
	$(INSTALL) -m 0644 and-emulab.conf $(DESTDIR)$(INSTALL_ETC)/and.conf
	$(INSTALL) -m 0644 $(SRCDIR)/and-emulab.priorities \
		$(DESTDIR)$(INSTALL_ETC)/and.priorities
ifneq (${INITSCRIPT},)
ifneq (${INSTALL_INITD},)
	@echo "Installing SysV script in $(DESTDIR)$(INSTALL_INITD)"
	$(INSTALL) -m 0755 $(INITSCRIPT) $(DESTDIR)$(INSTALL_INITD)/and
else
	@echo "Installing SysV script in $(DESTDIR)$(INSTALL_SBIN)"
	$(INSTALL) -m 0755 $(INITSCRIPT) $(DESTDIR)$(INSTALL_SBIN)
	@echo "Installing SysV init.d finder in $(DESTDIR)$(INSTALL_SBIN)"
	$(INSTALL) -m 0755 and-find-init.d $(DESTDIR)$(INSTALL_SBIN)
endif
endif
	$(INSTALL) -m 0644 and.8 $(DESTDIR)$(INSTALL_MAN)/man8
	$(INSTALL) -m 0644 and.conf.5 $(DESTDIR)$(INSTALL_MAN)/man5
	$(INSTALL) -m 0644 and.priorities.5 $(DESTDIR)$(INSTALL_MAN)/man5

control-install: all
	strip and
#-mkdir $(PREFIX)
	-mkdir -p $(INSTALL_DIR)/sbin
	-mkdir -p $(INSTALL_DIR)/etc
	-mkdir -p $(INSTALL_DIR)/etc/rc.d
	-mkdir -p $(INSTALL_DIR)/man/man5
	-mkdir -p $(INSTALL_DIR)/man/man8
	$(INSTALL) -m 0755 and $(INSTALL_DIR)/sbin/and
	$(INSTALL) -m 0644 and-emulab.conf $(INSTALL_DIR)/etc/and.conf
	$(INSTALL) -m 0644 $(SRCDIR)/and-emulab.priorities \
		$(INSTALL_DIR)/etc/and.priorities
ifneq (${INITSCRIPT},)
ifneq (${INSTALL_INITD},)
	@echo "Installing SysV script in $(INSTALL_DIR)/etc/rc.d"
	$(INSTALL) -m 0755 $(INITSCRIPT) $(INSTALL_DIR)/etc/rc.d/and
else
	@echo "Installing SysV script in $(INSTALL_DIR)/sbin"
	$(INSTALL) -m 0755 $(INITSCRIPT) $(INSTALL_DIR)/sbin
	@echo "Installing SysV init.d finder in $(INSTALL_DIR)/sbin"
	$(INSTALL) -m 0755 and-find-init.d $(INSTALL_DIR)/sbin
endif
endif
	$(INSTALL) -m 0644 and.8 $(INSTALL_DIR)/man/man8
	$(INSTALL) -m 0644 and.conf.5 $(INSTALL_DIR)/man/man5
	$(INSTALL) -m 0644 and.priorities.5 $(INSTALL_DIR)/man/man5

simpleinstall: and and.init
	strip and
	mkdir -p $(DESTDIR)$(INSTALL_SBIN) $(DESTDIR)$(INSTALL_ETC)
	mkdir -p $(DESTDIR)$(INSTALL_INITD)
	mkdir -p $(DESTDIR)$(INSTALL_MAN)/man5 $(DESTDIR)$(INSTALL_MAN)/man8
	cp and $(DESTDIR)$(INSTALL_SBIN)
	test -e $(DESTDIR)$(INSTALL_ETC)/and.conf || \
	   cp and.conf $(DESTDIR)$(INSTALL_ETC)
	test -e $(DESTDIR)$(INSTALL_ETC)/and.priorities || \
	   cp and.priorities $(DESTDIR)$(INSTALL_ETC)
ifneq (${INITSCRIPT},) # on SysV only
	cp $(INITSCRIPT) $(DESTDIR)$(INSTALL_INITD)/and
endif
	cp and.8 $(DESTDIR)$(INSTALL_MAN)/man8
	cp and.conf.5 $(DESTDIR)$(INSTALL_MAN)/man5
	cp and.priorities.5 $(DESTDIR)$(INSTALL_MAN)/man5

uninstall:
	rm -f $(DESTDIR)$(INSTALL_SBIN)/and
	rm -f $(DESTDIR)$(INSTALL_INITD)/and
	rm -f $(DESTDIR)$(INSTALL_ETC)/and.conf
	rm -f $(DESTDIR)$(INSTALL_ETC)/and.priorities
	rm -f $(DESTDIR)$(INSTALL_MAN)/man8/and.8
	rm -f $(DESTDIR)$(INSTALL_MAN)/man5/and.conf.5
	rm -f $(DESTDIR)$(INSTALL_MAN)/man5/and.priorities.5


#
# Clean up generated files.
#
clean:
	rm -f *.o and and.init $(MANPAGES)
