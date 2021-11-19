#!/usr/bin/perl -w
#
# Copyright (c) 2006, 2007 University of Utah and the Flux Group.
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
use English;

use lib "/usr/testbed/lib";
use libdb;
use libtestbed;
use Experiment;

my $tmpfile = "/tmp/nsfile.$$";

#
# Untaint the path
# 
$ENV{'PATH'} = '/bin:/usr/bin:/usr/sbin';
delete @ENV{'IFS', 'CDPATH', 'ENV', 'BASH_ENV'};

my $query_result =
    DBQueryFatal("select * from nsfiles");

while (my ($pid, $eid, $exptidx, $nsfile) = $query_result->fetchrow_array()) {
    my $experiment = Experiment->Lookup($exptidx);
    if (!defined($experiment)) {
	print "Could not lookup experiment object for $exptidx\n";
	next;
    }
    open(NSFILE, ">$tmpfile")
	or die("Could not open $tmpfile for writing!\n");
    print NSFILE $nsfile;
    close(NSFILE);

    $experiment->SetNSFile($tmpfile) == 0
	or die("Could not add $tmpfile to $experiment!\n");
}

