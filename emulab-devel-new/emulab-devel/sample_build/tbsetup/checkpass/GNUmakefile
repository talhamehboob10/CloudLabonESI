#
# Copyright (c) 2000-2006 University of Utah and the Flux Group.
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
SRCDIR		= ../../../tbsetup/checkpass
TESTBED_SRCDIR	= ../../..
OBJDIR		= ../..
SUBDIR		= tbsetup/checkpass

include $(OBJDIR)/Makeconf

all: checkpass

#
# XXX This code needs to be "imported" in the accepted manner. This
# is for vpath.
#
SRCDIR	+= $(TESTBED_SRCDIR)/$(SUBDIR)/cracklib,2.7/cracklib
OBJECTS  = fascist.o packlib.o rules.o stringlib.o
CFLAGS  += -g -I$(TESTBED_SRCDIR)/$(SUBDIR)/cracklib,2.7/cracklib -DIN_CRACKLIB

include $(TESTBED_SRCDIR)/GNUmakerules

checkpass: checkpass.o $(OBJECTS)
	${CC} -g -o checkpass checkpass.o $(OBJECTS) -lm

cracklib:
	gmake -C cracklib,2.7 all

install:	$(INSTALL_LIBEXECDIR)/checkpass

clean:
#	gmake -C cracklib,2.7 clean
	/bin/rm -f *.o checkpass

