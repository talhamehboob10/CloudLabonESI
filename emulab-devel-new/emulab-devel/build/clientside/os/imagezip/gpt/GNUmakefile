#
# Copyright (c) 2000-2014 University of Utah and the Flux Group.
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
SRCDIR		= ../../../../../clientside/os/imagezip/gpt
TESTBED_SRCDIR	= ../../../../..
OBJDIR		= ../../../..
SUBDIR		= $(subst $(TESTBED_SRCDIR)/,,$(SRCDIR))
MAINDIR		= $(SRCDIR)/..

include $(OBJDIR)/Makeconf

CFLAGS		+= -DIMAGEZIP $(SUBDIRCFLAGS) -I$(MAINDIR) -I$(SRCDIR)

# XXX avoid a symbol conflict
CFLAGS		+= -Dcrc32=gpt_crc32

all:	libgpt.a

include $(TESTBED_SRCDIR)/GNUmakerules

OBJS = gpt.o crc32.o gpt_glue.o

gpt.o: gpt_glue.h gpt.h
crc32.o: crc32.h
gpt_glue.o: gpt_glue.h gpt.h
gpt_glue.o: $(MAINDIR)/global.h $(MAINDIR)/sliceinfo.h $(MAINDIR)/imagehdr.h

libgpt.a:	$(OBJS)
	$(AR) $(ARFLAGS) $@ $?
	$(RANLIB) $@

install: 

clean:
	rm -f libgpt.a $(OBJS)
