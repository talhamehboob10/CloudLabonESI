#!/usr/bin/perl
#
# Copyright (c) 2002-2016 University of Utah and the Flux Group.
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
# Debug the event system by subscribing to and printing all events - event
# system analog of tcpdump. An trivial modification of tbrecv.pl
#

#
# Configure variables
#

use lib '/users/mshobana/emulab-devel/build/lib';

use event;
use Getopt::Std;
use strict;

sub usage {
	warn "Usage: $0 [-b] [-s server] [-p port] [pid/eid]\n";
	return 1;
}

my %opt = ();
my $expt = "";
getopt("s:p:hb", \%opt);

if ($opt{h}) { exit &usage; }
if (@ARGV) {
    $expt = shift @ARGV;
}
if (@ARGV) {
    usage();
    exit 1;
}


my ($server,$port);
if ($opt{s}) { $server = $opt{s}; } else { $server = "localhost"; }
if ($opt{b}) { $port = 16505 ; }
if ($opt{p}) { $port = $opt{p}; }

my $URL = "elvin://$server";
if ($port) { $URL .= ":$port"; }

my $handle = event_register($URL,0);
if (!$handle) { die "Unable to register with event system\n"; }

my $tuple = address_tuple_alloc();
if (!$tuple) { die "Could not allocate an address tuple\n"; }

if ($expt) {
    %$tuple = ( expt => $expt );
}

my $gotone;

sub callbackFunc($$$) {
	my ($handle,$notification,$data) = @_;

	my $time      = time();
	my $site      = event_notification_get_site($handle, $notification);
	my $expt      = event_notification_get_expt($handle, $notification);
	my $group     = event_notification_get_group($handle, $notification);
	my $host      = event_notification_get_host($handle, $notification);
	my $objtype   = event_notification_get_objtype($handle, $notification);
	my $objname   = event_notification_get_objname($handle, $notification);
	my $eventtype = event_notification_get_eventtype($handle,
		$notification);
	print "Event: $time $site $expt $group $host $objtype $objname " .
		"$eventtype\n";

	$gotone++;
}

if (!event_subscribe($handle,\&callbackFunc,$tuple)) {
	die "Could not subscribe to event\n";
}

#
# Note a difference from tbrecv.c - we don't yet have event_main() functional
# in perl, so we have to poll. (Nothing special about the select, it's just
# a wacky way to get usleep() )
#
while (1) {
    $gotone = 1;
    while ($gotone) {
	$gotone = 0;
	event_poll($handle);
    }
    event_poll_blocking($handle, 5000);
}

if (event_unregister($handle) == 0) {
	die "Unable to unregister with event system\n";
}

exit(0);

