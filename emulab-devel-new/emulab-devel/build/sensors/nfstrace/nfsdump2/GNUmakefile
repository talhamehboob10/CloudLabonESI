#
# Copyright (c) 2000-2010 University of Utah and the Flux Group.
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

SRCDIR		= ../../../../sensors/nfstrace/nfsdump2
TESTBED_SRCDIR	= ../../../..
OBJDIR		= ../../..
SUBDIR		= sensors/nfstrace/nfsdump2
ND2SRCDIR	= nfsdump2
PROGRAMS	= nfsdump2/nfsdump2

TARBALL		= nfsdump-v1.01-031204.tgz

include $(OBJDIR)/Makeconf

all:	$(SRCDIR)/GNUmakefile.in $(PROGRAMS)

include $(TESTBED_SRCDIR)/GNUmakerules

$(ND2SRCDIR)/Makefile:
	$(SRCDIR)/nfsdump2-install $(SRCDIR) $(TARBALL)
	cd $(ND2SRCDIR) && ./configure

nfsdump2/nfsdump2: $(ND2SRCDIR)/Makefile
	cd $(ND2SRCDIR) && ./config.status
	cd $(ND2SRCDIR) && $(MAKE)

clean:
	-@if [ -d "$(ND2SRCDIR)" ]; then \
	    cd $(ND2SRCDIR) && $(MAKE) clean; \
        fi

reallyclean:
	/bin/rm -rf $(ND2SRCDIR) $(TARBALL)
