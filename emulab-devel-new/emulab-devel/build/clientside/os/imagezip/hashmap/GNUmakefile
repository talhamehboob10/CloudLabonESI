#
# Copyright (c) 2000-2012 University of Utah and the Flux Group.
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
SRCDIR		= ../../../../../clientside/os/imagezip/hashmap
TESTBED_SRCDIR	= ../../../../..
OBJDIR		= ../../../..
SUBDIR		= $(subst $(TESTBED_SRCDIR)/,,$(SRCDIR))
MAINDIR		= $(SRCDIR)/..

include $(OBJDIR)/Makeconf

CFLAGS		+= $(SUBDIRCFLAGS) -I$(MAINDIR) -I$(SRCDIR)

all:	libhashmap.a

include $(TESTBED_SRCDIR)/GNUmakerules

OBJS = hashmap.o

hashmap.o: hashmap.h $(MAINDIR)/imagehdr.h $(MAINDIR)/imagehash.h

libhashmap.a:	$(OBJS)
	$(AR) $(ARFLAGS) $@ $?
	$(RANLIB) $@

install: 

clean:
	rm -f hashmap.o
