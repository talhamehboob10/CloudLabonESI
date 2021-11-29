#!/usr/bin/perl -w
#
# Copyright (c) 2006, 2013, 2018 University of Utah and the Flux Group.
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

use English;

#
# A silly little script to figure out what version of perl is running
# so we can find headers for the swig generated goo.
#
foreach my $p (@INC) {
    if ($p =~ /perl5\/(\d+\.\d+\.\d+)\//) {
	print "$1";
	exit(0);
    }
}
#
# Around mid-2013 FreeBSD started installing into X.X rather than X.X.X
#
foreach my $p (@INC) {
    if ($p =~ /perl5\/(\d+\.\d+)\//) {
	print "$1";
	exit(0);
    }
}

#
# Some Linuxes just don't have a perl5/<major>.<minor>.<patch>; they only
# have perl/<major>.<minor>.<patch>; so accept that if all else fails.
#
foreach my $p (@INC) {
    if ($p =~ /perl\/(\d+\.\d+\.\d+)$/) {
	print "$1";
	exit(0);
    }
}
exit(1);
