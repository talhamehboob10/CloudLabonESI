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
# in an experiment. Like tbsend.pl, but uses the shorter EventSendFatal
# function, to show off how easy it is. This function, though, should only
# be used in scripts the only occasionally send events.
#

#
# Configure variables
#
use lib '/test/lib';

use event;
use Getopt::Std;
use strict;

sub usage {
    warn "Usage: $0 <event>\n";
    return 1;
}

my %opt = ();
getopt(\%opt,"h");
if ($opt{h}) { exit &usage; }
if (@ARGV != 1) { exit &usage; }

print "Sent at time " . time() . "\n";

EventSendFatal(objtype   => "TBEXAMPLE",
	       eventtype => $ARGV[0],
	       host     => "*" );

exit(0);
