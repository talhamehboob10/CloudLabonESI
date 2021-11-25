#!/usr/bin/perl -w

#
# Copyright (c) 2015 University of Utah and the Flux Group.
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
# Generate a tip ACL in the DB for the indicated node and time
#
use English;
use strict;

use lib "/usr/testbed/lib";
use Node;

my $node_id;
my $secs;

if (@ARGV < 1) {
    print STDERR "Usage: $0 node [ valid-len-in-sec ]\n";
    exit(1);
}

if ($ARGV[0] =~ /^([\w-]+)$/) {
    $node_id = $1;
} else {
    print STDERR "Invalid node string '$ARGV[0]'\n";
    exit(1);
}

if (@ARGV > 1) {
    if ($ARGV[1] =~ /^(\d+)$/) {
	$secs = $1;
    } else {
	print STDERR "Invalid time interval '$ARGV[1]'\n";
	exit(1);
    }
} else {
    $secs = 300;
}

my $node = Node->Lookup($node_id);
if (!$node) {
    print STDERR "Invalid node '$node_id'\n";
    exit(1);
}

my $url = $node->GenTipAclUrl(time() + $secs);
if (!$url) {
    print STDERR "Could not generate tipacl for $node_id\n";
    exit(1);
}

print "URL: '$url'\n";
print "Good for $secs seconds\n";

exit(0);
