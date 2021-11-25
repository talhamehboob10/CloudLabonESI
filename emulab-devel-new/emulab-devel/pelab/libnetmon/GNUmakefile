#
# Copyright (c) 2006 University of Utah and the Flux Group.
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

SYSTEM :=	$(shell uname -s)

# I like using -pedantic, but it gives us some trouble with function pointers
CFLAGS=-Wall -Werror -std=c99 -g

ifeq ($(SYSTEM),Linux)
    LD_FLAGS=-ldl
else
    LD_FLAGS=
endif

all: libnetmon.so netmond netmonup

%.so: %.c %.h
	$(CC) $(CFLAGS) $(LD_FLAGS) -shared -o $@ $<

clean:
	-rm *.so netmond netmonup
