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
    print STDERR "Usage: server.pl <barrier-name> <pair-number> <duration> <run-path>\n";
    exit(1);
}

$name = $ARGV[0];
$num = $ARGV[1];
$duration = $ARGV[2];
$runPrefix = $ARGV[3];

$timeout = $duration * 2;

printLog("$num Server Begin");

system("/usr/local/etc/emulab/emulab-iperf -s -w 256k -p 4000 &");

printLog("$num Server Before server barrier");
system("$runPrefix/run-sync.pl 30 -n $name-server");

printLog("$num Server Before client barrier");
system("$runPrefix/run-sync.pl $timeout -n $name-client");

system("killall -9 iperf");
printLog("$num Server End");
