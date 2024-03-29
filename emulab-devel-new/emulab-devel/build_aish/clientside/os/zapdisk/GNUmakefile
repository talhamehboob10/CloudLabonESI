#
# Copyright (c) 2000-2017 University of Utah and the Flux Group.
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
SRCDIR		= ../../../../clientside/os/zapdisk
TESTBED_SRCDIR	= ../../../..
OBJDIR		= ../../..
SUBDIR		= $(subst $(TESTBED_SRCDIR)/,,$(SRCDIR))

CBINDIR		= $(DESTDIR)$(CLIENT_BINDIR)
LBINDIR		= $(DESTDIR)/usr/local/bin
IZSRCDIR	= $(SRCDIR)/../imagezip
IZOBJDIR	= ../imagezip

#
# XXX should be in sync with imagezip/GNUmakefile
#
WITH_MBR	= 1
WITH_GPT	= 1
WITH_ERASE	= 1

include $(OBJDIR)/Makeconf

PARTFLAGS	= -I$(IZSRCDIR)
PARTLIBS	=
ifeq ($(WITH_MBR),1)
PARTLIBS	+= $(IZOBJDIR)/mbr/libmbr.a
PARTFLAGS	+= -DWITH_MBR
endif
ifeq ($(WITH_GPT),1)
PARTLIBS	+= $(IZOBJDIR)/gpt/libgpt.a
PARTFLAGS	+= -DWITH_GPT
endif
ifeq ($(WITH_ERASE),1)
EFLAGS		=
EOBJS		= erase.o
else
EFLAGS		+= -DNO_ERASE
EOBJS		= 
endif

all:

include $(TESTBED_SRCDIR)/GNUmakerules

CFLAGS		= -O -g $(LDSTATIC) $(PARTFLAGS) $(EFLAGS)

zapdisk: zapdisk.o disksize.o $(EOBJS) $(PARTLIBS)
	$(CC) $(CFLAGS) zapdisk.o disksize.o $(EOBJS) $(PARTLIBS) -o zapdisk
	cp zapdisk zapdisk.debug
	strip zapdisk

disksize.o:	$(IZSRCDIR)/disksize.c
	$(CC) -c $(CFLAGS) -o disksize.o $<

erase.o:	$(IZSRCDIR)/erase.c
	$(CC) -c $(CFLAGS) -o erase.o $<

$(PARTLIBS):
	@$(MAKE) -C $(IZOBJDIR) partlibs

install:

mfs frisbee-mfs: zapdisk

mfs-install: mfs
	$(INSTALL_PROGRAM) -m 700 -s zapdisk$(EXE) $(CBINDIR)/zapdisk$(EXE)
	$(INSTALL_PROGRAM) -m 700 $(SRCDIR)/diskzap $(LBINDIR)/diskzap

frisbee-mfs-install: frisbee-mfs
	$(INSTALL_PROGRAM) -m 700 -s zapdisk$(EXE) $(CBINDIR)/zapdisk$(EXE)

clean:
	rm -f *.o zapdisk zapdisk.debug
