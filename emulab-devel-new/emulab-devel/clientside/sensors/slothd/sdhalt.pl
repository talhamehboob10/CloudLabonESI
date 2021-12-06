#!/usr/bin/perl -w
#
# Copyright (c) 2000-2002 University of Utah and the Flux Group.
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

use lib '/usr/testbed/lib';

use libdb;
use English;
use strict;

sub usage() {
    print "Usage: $0 <pid> <eid>\n";
}

if (@ARGV < 2) {
    exit &usage;
}

my ($pid, $eid) = @ARGV;

print "pid: $pid\neid: $eid\n";

my $nodeos;
my $j;

foreach $j (ExpNodes($pid, $eid)) {
    print "stopping slothd on $j\n";
    `sudo ssh -q $j killall slothd`;
}

exit 0;
