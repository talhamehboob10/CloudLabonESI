#
# Copyright (c) 2000-2004, 2007 University of Utah and the Flux Group.
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

SRCDIR		= ../../../cdrom/groklilo
TESTBED_SRCDIR	= ../../..
EVENTSYS	= 1
OBJDIR		= ../..
SUBDIR		= cdrom/groklilo

include $(OBJDIR)/Makeconf

all:	groklilo

include $(TESTBED_SRCDIR)/GNUmakerules

CFLAGS	+= -O -g -Wall -I${OBJDIR} -UINBOOTLOADER

groklilo: groklilo.c
	$(CC) $(CFLAGS) $(LDSTATIC) -g -o groklilo $< $(LFLAGS)

client: groklilo

client-install: client
	$(INSTALL_PROGRAM) -s groklilo $(DESTDIR)$(CLIENT_BINDIR)

clean:
	rm -f *.o core groklilo
