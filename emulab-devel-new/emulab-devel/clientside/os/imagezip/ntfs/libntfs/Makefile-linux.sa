#
# Copyright (c) 2000-2005 University of Utah and the Flux Group.
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

all:	libntfs.a

NTFSDIR		= ntfsprogs-2.0.0
LIBSRCDIR	= $(NTFSDIR)/libntfs
INCLUDES        = -I${NTFSDIR}/include
CFLAGS	        = -O2 -g -static -Wall $(INCLUDES)

%.o:	$(LIBSRCDIR)/%.c
	$(CC) $(CFLAGS) -c -o $@ $<

libntfs.a: configureit
	$(MAKE) -C $(LIBSRCDIR) all
	cp -p $(LIBSRCDIR)/.libs/libntfs.a $@

configureit:
	wget -q -N http://www.emulab.net/distributions/ntfsprogs-2.0.0.tar.gz
	tar zxf ntfsprogs-2.0.0.tar.gz
	patch -sN -d $(NTFSDIR) -p1 < ntfsprogs-2.0.0.patch
	(cd $(NTFSDIR); ./configure $(NTFS_CONFIGURE_OPTS))
	cp $(NTFSDIR)/config.h $(NTFSDIR)/include
	touch configureit

clean:
	$(MAKE) -C $(LIBSRCDIR) clean
	rm -f libntfs.a
