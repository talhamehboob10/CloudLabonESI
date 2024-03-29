#
# Copyright (c) 2000-2015 University of Utah and the Flux Group.
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
SRCDIR		= ../../../../../clientside/os/imagezip/libndz
TESTBED_SRCDIR	= ../../../../..
OBJDIR		= ../../../..
SUBDIR		= $(subst $(TESTBED_SRCDIR)/,,$(SRCDIR))
MAINDIR		= $(SRCDIR)/..

include $(OBJDIR)/Makeconf

CFLAGS		+= -DSTATS $(SUBDIRCFLAGS) -I$(MAINDIR) -I$(SRCDIR) # -DCOMPDELTA_DEBUG #-DDEBUG

all:	libndz.a

include $(TESTBED_SRCDIR)/GNUmakerules

OBJS = rangemap.o ndzfile.o ndzdata.o chunk.o hash.o reloc.o

rangemap.o: rangemap.h
ndzfile.o: libndz.h $(MAINDIR)/imagehdr.h
ndzdata.o: libndz.h $(MAINDIR)/imagehdr.h
chunk.o: libndz.h $(MAINDIR)/imagehdr.h
hash.o: libndz.h $(MAINDIR)/imagehdr.h $(MAINDIR)/imagehash.h
reloc.o: libndz.h $(MAINDIR)/imagehdr.h $(MAINDIR)/imagehash.h

libndz.a:	$(OBJS)
	$(AR) $(ARFLAGS) $@ $?
	$(RANLIB) $@

tests: ndzfiletest ndzdatatest rangemaptest
ndzfiletest: libndz.a
	$(CC) -DNDZFILE_TEST $(CFLAGS) -o ndzfiletest $(SRCDIR)/ndzfile.c libndz.a

ndzdatatest: libndz.a
	$(CC) -DNDZDATA_TEST $(CFLAGS) -o ndzdatatest $(SRCDIR)/ndzdata.c libndz.a -lz

rangemaptest:
	$(CC) -DRANGEMAP_TEST $(CFLAGS) -o rangemaptest $(SRCDIR)/rangemap.c

install: 

clean:
	rm -f libndz.a $(OBJS) ndzfiletest ndzdatatest rangemaptest
