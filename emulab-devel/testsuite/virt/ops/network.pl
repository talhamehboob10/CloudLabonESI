#!/usr/bin/perl
#
# Copyright (c) 2009 University of Utah and the Flux Group.
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

if (scalar(@ARGV) != 5)
{
    print STDERR "Usage: network.pl <proj> <exp> <pair-count> <bw> <delay>\n";
}

$proj = $ARGV[0];
$exp = $ARGV[1];
$count = $ARGV[2];
$bw = $ARGV[3];
$delay = $ARGV[4];

for ($i = 1; $i <= $count; ++$i)
{
#    $command = "/usr/testbed/bin/tevc -e $proj/$exp now link-$i modify delay=$delay";
#    print $command."\n";
#    system($command);
    $command = "/usr/testbed/bin/tevc -e $proj/$exp now link-$i modify bandwidth=$bw";
    print $command."\n";
    system($command);
}
