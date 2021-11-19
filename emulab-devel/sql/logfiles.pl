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
use Logfile;

#
# Untaint the path
# 
$ENV{'PATH'} = '/bin:/usr/bin:/usr/sbin';
delete @ENV{'IFS', 'CDPATH', 'ENV', 'BASH_ENV'};

my $query_result =
    DBQueryFatal("select idx,logfile,gid_idx from experiments ".
		 "where logfile!='' and logfile is not null");

while (my ($idx, $logname, $gid_idx) = $query_result->fetchrow_array()) {
    next
	if (! ($logname =~ /^\//));
    
    my $experiment = Experiment->Lookup($idx);
    if (!defined($experiment)) {
	print "Could not lookup experiment object for $idx\n";
	next;
    }
    my $logfile = Logfile->Create($gid_idx, $logname);
    $experiment->SetLogFile($logfile);
}

