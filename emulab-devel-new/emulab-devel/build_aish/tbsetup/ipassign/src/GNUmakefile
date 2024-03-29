#
# Copyright (c) 2000-2003 University of Utah and the Flux Group.
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

SRCDIR		= ../../../../tbsetup/ipassign/src
TESTBED_SRCDIR	= ../../../..
OBJDIR		= ../../..
SUBDIR		= tbsetup/ipassign/src
UNIFIED         = 0
ROUTECALC_PATH	= \"$(INSTALL_LIBEXECDIR)/rcalc\"

include $(OBJDIR)/Makeconf

CXXFLAGS	+= -O3 -I/usr/local/include/metis

LDFLAGS		+= -L/usr/local/lib

LIBEXEC_STUFF	= ipassign

BIN_STUFF	= difference add-x inet2graph brite2graph top2graph

IPASSIGN_OBJECTS = ConservativeAssigner.o Framework.o \
                   HierarchicalAssigner.o bitmath.o \
                   coprocess.o ipassign.o

ROUTECALC_OBJECTS = routecalc.o

BIN_OBJECTS	= $(addsuffix .o, $(BIN_STUFF))

HEADERS 	= Assigner.h ConservativeAssigner.h Exception.h \
                  FixedPartition.h Framework.h GraphConverter.h \
                  HierarchicalAssigner.h \
                  PTree.h Partition.h SearchPartition.h \
                  SquareRootPartition.h bitmath.h coprocess.h lib.h

#
# Force dependencies on the scripts so that they will be rerun through
# configure if the .in file is changed.
# 
all:	$(LIBEXEC_STUFF) $(BIN_STUFF)

include $(TESTBED_SRCDIR)/GNUmakerules

install: all libexec-install bin-install

#
# Automate this part at some point.
# 
libexec-install:	$(addprefix $(INSTALL_LIBEXECDIR)/, $(LIBEXEC_STUFF))

bin-install:		$(addprefix $(INSTALL_BINDIR)/, $(BIN_STUFF))

ipassign: $(IPASSIGN_OBJECTS) $(HEADERS)
	$(CXX) $(CXXFLAGS) $(LDFLAGS) $(IPASSIGN_OBJECTS) -lm -lmetis -o ipassign

$(BIN_STUFF): $(BIN_OBJECTS) $(HEADERS)
	$(CXX) $(CXXFLAGS) $(LDFLAGS) $< -o $@ -lm -lmetis

$(IPASSIGN_OBJECTS): $(HEADERS)

$(BIN_OBJECTS): $(HEADERS)

post-install: 
	chmod 775 $(INSTALL_LIBEXECDIR)

clean:
	rm -f *.o $(LIBEXEC_STUFF) $(BIN_STUFF)

distclean:

