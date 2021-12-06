#!/usr/bin/perl
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

#
# Configure variables
#
use lib '/usr/testbed/lib';

use event;
use Getopt::Std;
use strict;
use libwanetmon;

sub usage {
    warn "Usage: $0 [-i managerID] [-e pid/eid] [-p period] [-d duration]".
	"<srcnode> <dstnode> <testtype> <COMMAND>\n";
    return 1;
}

my %opt = ();
getopt("i:e:p:d:h",\%opt);
if ($opt{h}) { exit &usage; }
my ($managerid, $period, $duration, $type, $srcnode, $dstnode, $cmd);
my ($server,$bgmonexpt);
$server = "localhost";
if($opt{i}){ $managerid=$opt{i}; } else{ $managerid = "testsend"; }
if($opt{e}){ $bgmonexpt=$opt{e}; } else{ $bgmonexpt = "tbres/pelabbgmon"; }
if($opt{p}){ $period = $opt{p}; } else{ $period = 0; }
if($opt{d}){ $duration = $opt{d}; } else{ $duration = 0; }
my $URL = "elvin://$server";
#if ($port) { $URL .= ":$port"; }

if (@ARGV != 4) { exit &usage; }
($srcnode, $dstnode, $type, $cmd) = @ARGV;

my $handle = event_register($URL,0);
if (!$handle) { die "Unable to register with event system\n"; }

my $tuple = address_tuple_alloc();
if (!$tuple) { die "Could not allocate an address tuple\n"; }

my %cmdhash = ( managerID => $managerid,
	    srcnode => $srcnode,
	    dstnode => $dstnode,
	    testtype => $type,
	    testper => "$period",
	    duration => "$duration",
	    expid    => "$bgmonexpt"
	    );

sendcmd_evsys($cmd, \%cmdhash, $handle);

print "$cmd\n";
foreach my $key (keys %cmdhash){
    print "$key => $cmdhash{$key}\n";
}


if (event_unregister($handle) == 0) {
    die("could not unregister with event system");
}

exit(0);
