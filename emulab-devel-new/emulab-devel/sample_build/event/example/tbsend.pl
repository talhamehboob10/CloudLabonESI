#!/usr/bin/perl
#
# Copyright (c) 2002-2004 University of Utah and the Flux Group.
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
# This is a sample event generator to send TBEXAMPLE events to all nodes
# in an experiment. Perl equivalent of tbsend.c
#

#
# Configure variables
#
use lib '/users/mshobana/CloudLabonESI/emulab-devel-new/emulab-devel/sample_build/lib';

use event;
use Getopt::Std;
use strict;

sub usage {
    warn "Usage: $0 [-s server] [-p port] <event>\n";
    return 1;
}

my %opt = ();
getopt(\%opt,"s:p:h");

if ($opt{h}) { exit &usage; }
if (@ARGV != 1) { exit &usage; }

my ($server,$port);
if ($opt{s}) { $server = $opt{s}; } else { $server = "localhost"; }
if ($opt{p}) { $port = $opt{p}; }

my $URL = "elvin://$server";
if ($port) { $URL .= ":$port"; }

my $handle = event_register($URL,0);
if (!$handle) { die "Unable to register with event system\n"; }

my $tuple = address_tuple_alloc();
if (!$tuple) { die "Could not allocate an address tuple\n"; }

%$tuple = ( objtype => "TBEXAMPLE",
	    eventtype => $ARGV[0],
	    host => "*");

my $notification = event_notification_alloc($handle,$tuple);
if (!$notification) { die "Could not allocate notification\n"; }
print "Sent at time " . time() . "\n";

if (!event_notify($handle, $notification)) {
    die("could not send test event notification");
}

event_notification_free($handle, $notification);

if (event_unregister($handle) == 0) {
    die("could not unregister with event system");
}

exit(0);
