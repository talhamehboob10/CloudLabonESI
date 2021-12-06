#!/usr/bin/perl -w
#
# Copyright (c) 2005 University of Utah and the Flux Group.
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

#
# Turn off line buffering on output
#
$| = 1;

#
# Untaint the path
# 
$ENV{'PATH'} = '/bin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin';
delete @ENV{'IFS', 'CDPATH', 'ENV', 'BASH_ENV'};

my $query_result =
    DBQueryFatal("select t.*,s.* from testbed_stats as t ".
		 "left join experiment_stats as s on s.exptidx=t.exptidx ".
		 "where start_time=end_time and action='swapin' and ".
		 "      exitcode=0 ");

while (my $row = $query_result->fetchrow_hashref()) {
    my $uid     = $row->{'uid'};
    my $idx     = $row->{'idx'};
    my $pid     = $row->{'pid'};
    my $eid     = $row->{'eid'};
    my $gid     = $row->{'gid'};
    my $exptidx = $row->{'exptidx'};
    my $rsrcidx = $row->{'rsrcidx'};

#    print "$uid $pid $eid $gid $idx $exptidx\n";

    print("update project_stats set exptswapin_count=exptswapin_count-1 ".
	  "where pid='$pid';\n");
    print("update group_stats set exptswapin_count=exptswapin_count-1 ".
	  "where pid='$pid' and gid='$gid';\n");
    print("update user_stats set exptswapin_count=exptswapin_count-1 ".
	  "where uid='$uid';\n");
    print("update projects set expt_count=expt_count-1 ".
	  "where pid='$pid';\n");
    print("update groups set expt_count=expt_count-1 ".
	  "where pid='$pid' and gid='$gid';\n");
    print("update experiment_stats set swapin_count=swapin_count-1 ".
	  "where pid='$pid' and eid='$eid' and exptidx=$exptidx;\n");
    print("delete from testbed_stats where idx='$idx';\n");
}

