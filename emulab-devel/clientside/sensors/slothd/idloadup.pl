#!/usr/bin/perl
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

# You don't want to run this script unless you want to fatten up the DB
# for idle-detection testing

use lib '/usr/testbed/lib';

use libdb;
use English;
use Getopt::Long;
use strict;

my %opts = ();
my $numnodes;

GetOptions(\%opts,'n=i','r');

# security check.

my @whgrp = getgrnam("wheel");
my $uname = getpwuid($UID);

if (!TBAdmin($UID) && !($whgrp[3] =~ /$uname/)) {
    print "You must either be a testbed admin, or in the wheel group\n".
        "to run this script.\n";
    exit 1;
}

srand(time());

my @currow;
my $qres = DBQuery("SELECT node_id FROM nodes WHERE node_id LIKE 'pc%'");

print "number of nodes: ". $qres->numrows ."\n";

while (@currow = $qres->fetchrow_array()) {
    my $curnode = $currow[0];
    my $qmac = DBQuery("SELECT mac FROM interfaces ".
                       "WHERE node_id = '$curnode'");
    my @macs = ();

    while (my @macrow = $qmac->fetchrow_array()) {
        push @macs, $macrow[0];
    }

    print "adding random idle data entries for $curnode\n";
    for (my $i = Rand() % 10 + 1; $i > 0; --$i) {
        my $maddr;
        my $now = time();
        my $randtime = $now - (Rand() % 432000);
        my $randidle = $randtime - (Rand() % $randtime);
        
        DBQuery("INSERT INTO node_idlestats VALUES ('$curnode', ".
                "FROM_UNIXTIME($randtime), ".
                "FROM_UNIXTIME($randidle), ".
                Rand() % 100 .", ". 
                Rand() % 100 .", ". 
                Rand() % 100 .")");

        foreach $maddr (@macs) {
            DBQuery("INSERT INTO iface_counters VALUES ('$curnode', ".
                    "FROM_UNIXTIME($randtime), ".
                    "'$maddr', ".
                    Rand() .", ".
                    Rand() .")");
        }
    }
}

sub Rand() {
    return int(rand(2**32));
}
