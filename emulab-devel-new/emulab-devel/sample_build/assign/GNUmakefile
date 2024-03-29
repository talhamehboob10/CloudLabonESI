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
SRCDIR		= ../../assign
TESTBED_SRCDIR	= ../..
OBJDIR		= ..
SUBDIR		= assign
MAKEFILE_IN	= ../../assign/GNUmakefile.in
HAVE_XERCES	= 
NEWER_BOOST	= yes
USING_CLANG	= no

include $(OBJDIR)/Makeconf

#
# Uncomment these to build with gcc3.3
#
#CC=gcc33
#CPP=cpp33
#CXX=g++33	

all: assign

SCHEMATA = vtop.xsd ptop.xsd vtop-top.xsd ptop-top.xsd

include $(TESTBED_SRCDIR)/GNUmakerules

OBJS=parse_top.o parse_ptop.o assign.o pclass.o vclass.o score.o \
     parser.o solution.o anneal.o featuredesire.o neighborhood.o fstring.o \
     config.o
LIBS+= -lm
LDFLAGS+= -pipe -O3
CXXFLAGS = -pipe -I/usr/local/include -ftemplate-depth-80
# For OSX w/ macports
CXXFLAGS += -I/opt/local/include
LIBS += -L/opt/local/lib

#
# If we are on FreeBSD 10 with clang, we need to use C++11 extensions:
#
ifeq ($(USING_CLANG),yes)
CXXFLAGS += -Wno-c++11-extensions
endif

ifeq ($(HAVE_XERCES),yes)
CXXFLAGS += -DWITH_XML
LIBS += -L/usr/local/lib -lxerces-c
OBJS += parse_ptop_xml.o parse_vtop_xml.o parse_policy_xml.o parse_error_handler.o xmlhelpers.o parse_advertisement_rspec.o parse_request_rspec.o annotate_rspec_v2.o annotate_rspec.o annotate_vtop.o annotate.o rspec_parser_helper.o rspec_parser.o rspec_parser_v1.o rspec_parser_v2.o emulab_extensions_parser.o
endif

ifeq ($(NEWER_BOOST),yes)
CXXFLAGS += -DNEWER_BOOST
endif

# Pick either this
CXXFLAGS += -O3
# or this
#CXXFLAGS += -O0 -g -Wall -DVERBOSE
# and then zero or more of these
#CXXFLAGS += -DSCORE_DEBUG
#CXXFLAGS += -DSCORE_DEBUG_MORE
#CXXFLAGS += -DPCLASS_DEBUG
#CXXFLAGS += -DDUMP_GRAPH
#CXXFLAGS += -DSCORE_DEBUG_LOTS

# And then, regardless, you can also have this
#CXXFLAGS += -DSTATS

# This is added to disable link mapping while we figure out how to get assign
# to deal with interfaces on switches
#CXXFLAGS += -DDISABLE_LINK_ANNOTATION

# assign now supports a dizzing array of defines, which are as-yet undocumented
# Here are the ones used for a typical build:
# Pick cooling schedule
CXXFLAGS += -DMELT -DEPSILON_TERMINATE -DCHILL -DNEIGHBOR_LENGTH \
    -DLOCAL_DERIVATIVE -DALLOW_NEGATIVE_DELTA
# Bug/scoring fixes
CXXFLAGS += -DINTERSWITCH_LENGTH
# Various tweaks to the simulated annealing behavior
CXXFLAGS += -DFIND_PNODE_SEARCH -DNO_REVERT
# Keeps information about which pclasses are potential mappings for vnodes on a
# per-vnode basis, not a per-type basis
CXXFLAGS += -DPER_VNODE_TT
# Make sure that all emulated links that are assigned to a plink have the same
# endpoints
CXXFLAGS += -DFIX_PLINK_ENDPOINTS
# Allow pnodes to cap the amount of trivial link bandwidth they can handle
CXXFLAGS += -DTRIVIAL_LINK_BW
# Use the old acceptance criteria, which gives special treatment to violations
CXXFLAGS += -DSPECIAL_VIOLATION_TREATMENT
# Pass the Emulab installation root directory
CXXFLAGS += -DTBROOT='"$(TBROOT)"'

# If you're looking to turn on or off USE_OPTIMAL, its now a cmdline
# option. Use OP={0,1} on the command line at run time... :)

DEPLIBS=$(OBJS)

assign: ${MAKEFILE_IN} ${DEPLIBS} ${OBJS}
	${CXX} -o assign ${LIBS} $(OBJS) ${LDFLAGS}

install: install-schemata $(INSTALL_LIBEXECDIR)/assign

install-schemata: $(addprefix $(INSTALL_LIBDIR)/assign/, $(SCHEMATA))

# XXX: This is a hack having to do with the fact that there have, historically,
# been both a config.c and a config.cc, and CVS doesn't always delete config.c
# on an update. This confuses make. So, here's an explicit rule to build
# config.o from config.cc (note that the dependencies for config.cc are below)
config.o:
	${CXX} -c -o $@ ${CXXFLAGS} $(SRCDIR)/config.cc

clean:
	-${RM} *.o assign 

$(INSTALL_LIBDIR)/assign/%: %
	@echo "Installing $<"
	-mkdir -p $(INSTALL_LIBDIR)/assign
	$(INSTALL) $< $@

#
# All this crap generated with 'g++ -MM' - don't want to do all the makefile goo
# to make this automatic, since none of it ever changes
#
anneal.o: anneal.cc anneal.h port.h delay.h physical.h common.h fstring.h \
  featuredesire.h forwarding.h pclass.h virtual.h maps.h score.h \
  solution.h vclass.h neighborhood.h
annotate.o: annotate.cc
annotate_rspec.o: annotate_rspec.cc
annotate_rspec_v2.o: annotate_rspec_v2.cc
annotate_vtop.o: annotate_vtop.cc
assign.o: assign.cc port.h common.h fstring.h delay.h physical.h \
  featuredesire.h forwarding.h virtual.h vclass.h pclass.h score.h \
  solution.h maps.h anneal.h config.h
config.o: config.cc config.h common.h port.h fstring.h score.h physical.h \
  delay.h featuredesire.h forwarding.h virtual.h anneal.h pclass.h
emulab_extensions_parser.o: emulab_extensions_parser.cc
featuredesire.o: featuredesire.cc featuredesire.h common.h port.h \
  fstring.h score.h physical.h delay.h forwarding.h virtual.h
forwarding.o: forwarding.cc forwarding.h port.h fstring.h physical.h \
  common.h delay.h featuredesire.h
fstring.o: fstring.cc fstring.h port.h
fstringtest.o: fstringtest.cc fstring.h port.h
neighborhood.o: neighborhood.cc neighborhood.h port.h common.h fstring.h \
  physical.h delay.h featuredesire.h forwarding.h vclass.h virtual.h \
  pclass.h
parse_advertisement_rspec.o: parse_advertisement_rspec.cc
parse_error_handler.o: parse_error_handler.cc
parse_policy_xml.o: parse_policy_xml.cc
parse_ptop.o: parse_ptop.cc port.h delay.h physical.h common.h fstring.h \
  featuredesire.h forwarding.h parser.h
parse_ptop_xml.o: parse_ptop_xml.cc
parse_request_rspec.o: parse_request_rspec.cc
parse_top.o: parse_top.cc port.h common.h fstring.h vclass.h delay.h \
  physical.h featuredesire.h forwarding.h virtual.h parser.h anneal.h \
  pclass.h
parse_vtop_xml.o: parse_vtop_xml.cc
parser.o: parser.cc parser.h port.h
pclass.o: pclass.cc port.h common.h fstring.h delay.h physical.h \
  featuredesire.h forwarding.h virtual.h pclass.h
rspec_parser.o: rspec_parser.cc
rspec_parser_helper.o: rspec_parser_helper.cc
rspec_parser_v1.o: rspec_parser_v1.cc
rspec_parser_v2.o: rspec_parser_v2.cc
score.o: score.cc port.h common.h fstring.h vclass.h delay.h physical.h \
  featuredesire.h forwarding.h virtual.h pclass.h score.h
solution.o: solution.cc solution.h port.h delay.h physical.h common.h \
  fstring.h featuredesire.h forwarding.h virtual.h maps.h vclass.h
vclass.o: vclass.cc port.h common.h fstring.h vclass.h delay.h physical.h \
  featuredesire.h forwarding.h virtual.h
xmlhelpers.o: xmlhelpers.cc
