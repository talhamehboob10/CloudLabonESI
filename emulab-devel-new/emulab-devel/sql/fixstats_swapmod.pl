#!/usr/bin/perl -w
#
# Copyright (c) 2000-2004 University of Utah and the Flux Group.
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

my %exptstats = ();

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
    DBQueryFatal("select *,UNIX_TIMESTAMP(end_time) as foo ".
		 " from testbed_stats ".
		 "where exitcode=0 and ".
		 "  (UNIX_TIMESTAMP(end_time) > ".
		 "   UNIX_TIMESTAMP('2003-05-23 10:06:02')) ".
		 "order by end_time,idx asc");

while (my $rowref = $query_result->fetchrow_hashref()) {
    my $idx       = $rowref->{"idx"};
    my $uid       = $rowref->{"uid"};
    my $exptidx   = $rowref->{"exptidx"};
    my $rsrcidx   = $rowref->{"rsrcidx"};
    my $action    = $rowref->{"action"};
    my $endtime   = $rowref->{"foo"};
    my $curstate;
    my $laststamp;
    my $lastuid;

    if (exists($exptstats{$exptidx})) {
	($curstate,$laststamp,$lastuid) = @{ $exptstats{$exptidx} };
    }

    if ($action eq "preload") {
	$exptstats{$exptidx} = [ "preload", $endtime, $uid ];
	next;
    }
    if ($action eq "destroy") {
	delete($exptstats{$exptidx});
	next;
    }
    if ($action eq "start" || $action eq "swapin") {
	$exptstats{$exptidx} = [ "active", $endtime, $uid ];
	next;
    }
    if ($action eq "swapout") {
	$exptstats{$exptidx} = [ "swapped", $endtime, $uid ];
	next;
    }
    if ($action ne "swapmod") {
	die("Unknown action $action for index $idx\n");
    }
    if (!defined($curstate)) {
	#print("Unknown current state for index $exptidx. Skipping ...\n");
	next;
    }
    $exptstats{$exptidx} = [ $curstate, $endtime, $uid ];
    next
	if ($curstate eq "active");

    my $pnodes   = 0;
    my $vnodes   = 0;
    my $duration = ($curstate eq "preload" ? 0 : $endtime - $laststamp);
    my ($pid, $eid, $gid);

    my $d_result =
	DBQueryFatal("select s.pid,s.eid,s.gid ".
		     " from experiment_stats as s ".
		     "where s.exptidx=$exptidx");

    if ($d_result && $d_result->numrows) {
	($pid,$eid,$gid) = $d_result->fetchrow_array;
    }
    else {
	die("Could not get pid/eid/gid info for index $exptidx\n");
    }

  if (1) {
    print("update project_stats ".
	  "set allexpt_duration=allexpt_duration-${duration}, ".
	  "    allexpt_vnodes=allexpt_vnodes-${vnodes}, ".
	  "    allexpt_pnodes=allexpt_pnodes-${pnodes}, ".
	  "    allexpt_vnode_duration=".
	  "        allexpt_vnode_duration-($vnodes * ${duration}), ".
	  "    allexpt_pnode_duration=".
	  "        allexpt_pnode_duration-($pnodes * ${duration}) ".
	  "where pid='$pid';\n");

    print("update group_stats ".
	  "set allexpt_duration=allexpt_duration-${duration}, ".
	  "    allexpt_vnodes=allexpt_vnodes-${vnodes}, ".
	  "    allexpt_pnodes=allexpt_pnodes-${pnodes}, ".
	  "    allexpt_vnode_duration=".
	  "        allexpt_vnode_duration-($vnodes * ${duration}), ".
	  "    allexpt_pnode_duration=".
	  "        allexpt_pnode_duration-($pnodes * ${duration}) ".
	  "where pid='$pid' and gid='$gid';\n");
    
    print("update user_stats ".
	  "set allexpt_duration=allexpt_duration-${duration}, ".
	  "    allexpt_vnodes=allexpt_vnodes-${vnodes}, ".
	  "    allexpt_pnodes=allexpt_pnodes-${pnodes}, ".
	  "    allexpt_vnode_duration=".
	  "        allexpt_vnode_duration-($vnodes * ${duration}), ".
	  "    allexpt_pnode_duration=".
	  "        allexpt_pnode_duration-($pnodes * ${duration}) ".
	  "where uid='$lastuid';\n");

    print("update experiment_stats ".
	  "set swapin_duration=swapin_duration-${duration} ".
	  "where pid='$pid' and eid='$eid' and  ".
	  "      exptidx=$exptidx;\n");
   }
   else {
       print("IDX:$exptidx ($pid,$eid,$gid,$lastuid): ".
	     "$duration $pnodes $vnodes\n");
   }
}

