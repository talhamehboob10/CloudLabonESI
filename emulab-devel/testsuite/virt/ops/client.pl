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

sub printLog
{
    my $line = shift(@_);
    my $time = `date +%F_%H:%M:%S`;
    chomp($time);
    print STDERR  $time . " " . $line . "\n";
}

if (scalar(@ARGV) != 4)
{
    print STDERR "Usage: client.pl <barrier-name> <pair-number> <duration (s)> <run-path>\n";
    exit(1);
}

$DELAY = 1;

$name = $ARGV[0];
$num = $ARGV[1];
$duration = $ARGV[2];
$runPrefix = $ARGV[3];

printLog("$num Client Begin");

printLog("$num Client Before server barrier");
$status = (system("$runPrefix/run-sync.pl 30 -n $name-server") >> 8);

if ($status == 240)
{
    exit(1);
}

printLog("$num Client Before iperf");
system("/usr/local/etc/emulab/emulab-iperf -c server-$num -w 256k -i $DELAY -p 4000 -t $duration");

printLog("$num Client Before client barrier");
system("$runPrefix/run-sync.pl $duration -n $name-client");

printLog("$num Client End");
