#!/usr/bin/perl -w
#
# Copyright (c) 2003-2006 University of Utah and the Flux Group.
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
use Errno;
#use POSIX;
#use Socket;
#use BSD::Resource;
#use URI::Escape;

use lib "/usr/testbed/lib";
use libdb;
use libtestbed;

my $query_result =
    DBQueryFatal("select pid,eid,state ".
		 "from experiments where batchmode=0");

while (my ($pid,$eid,$state) =
       $query_result->fetchrow_array) {
    my $batchstate;

    if ($state eq EXPTSTATE_ACTIVATING) {
	$batchstate = BATCHSTATE_ACTIVATING;
    }
    elsif ($state eq EXPTSTATE_ACTIVE) {
	$batchstate = BATCHSTATE_RUNNING;
    }
    elsif ($state eq EXPTSTATE_SWAPPED) {
	$batchstate = BATCHSTATE_PAUSED;
    }
    elsif ($state eq EXPTSTATE_SWAPPING ||
	   $state eq EXPTSTATE_TERMINATING ||
	   $state eq EXPTSTATE_TERMINATED) {
	$batchstate = BATCHSTATE_TERMINATING;
    }
    elsif ($state eq EXPTSTATE_NEW ||
	   $state eq EXPTSTATE_PRERUN) {
	$batchstate = BATCHSTATE_PAUSED;
    }

    print "update experiments set batchstate='$batchstate' ".
	"where pid='$pid' and eid='$eid';\n";
}
		 
