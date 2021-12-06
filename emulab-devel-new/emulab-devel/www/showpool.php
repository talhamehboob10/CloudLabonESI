<?php
#
# Copyright (c) 2009-2019 University of Utah and the Flux Group.
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
include("defs.php3");
include("showstuff.php3");
include("table_defs.php");

#
# Only known and logged in users can look at experiments.
#
$this_user = CheckLoginOrDie();
$uid       = $this_user->uid();
$isadmin   = ISADMIN();

#
# Verify page arguments.
#
$optargs = OptionalPageArguments("sortby",     PAGEARG_STRING);

if (!isset($sortby)) {
    $sortby = "";
}

PAGEHEADER("Shared Pool");

$experiment = Experiment::LookupByPidEid("emulab-ops", "shared-nodes");
if (!$experiment) {
    $experiment = Experiment::LookupByPidEid("emulab-ops", "shared-node");
}
if (!$experiment) {
    USERERROR("No shared pool experiment!", 1);
}
$pid = $experiment->pid();
$eid = $experiment->eid();
$counts = array();
$nodes  = array();

#
# Get the counts per node.
#
$query_result =
    DBQueryFatal("select phys_nodeid,count(phys_nodeid) as vcount ".
		 "  from reserved as r ".
		 "left join nodes as n on n.node_id=r.node_id ".
		 "where n.node_id!=n.phys_nodeid and ".
		 "      r.sharing_mode is not null ".
		 "group by phys_nodeid");
while ($row = mysql_fetch_array($query_result)) {
    $node_id  = $row["phys_nodeid"];
    $count    = $row["vcount"];
    
    $counts[$node_id] = $count;
}

#
# Get the distinct set of nodes using the shared nodes.
#
$query_result =
    DBQueryFatal("select r.node_id from reserved as r ".
		 "left join nodes as n on n.node_id=r.node_id ".
		 "left join reserved as r2 on r2.node_id=n.phys_nodeid ".
		 "where n.node_id!=n.phys_nodeid and ".
		 "      r.sharing_mode is not null and " .
		 "      r2.pid='$pid' and r2.eid='$eid' ".
		 "order by node_id");
while ($row = mysql_fetch_array($query_result)) {
    $node_id  = $row["node_id"];
    
    $nodes[$node_id] = $node_id;
}

$query_result =
    DBQueryFatal("select ru.*,r.node_id,n.type,n.def_boot_osid,o.osname, ".
		 " ns.status as nodestatus, ".
		 " date_format(rsrv_time,\"%Y-%m-%d&nbsp;%T\") as rsrvtime ".
		 "from reserved as r ".
		 "left join nodes as n on n.node_id=r.node_id ".
		 "left join node_types as nt on nt.type=n.type ".
		 "left join node_status as ns on ns.node_id=r.node_id ".
		 "left join node_rusage as ru on ru.node_id=r.node_id ".
		 "left join os_info as o on o.osid=n.def_boot_osid ".
		 "where r.pid='$pid' and r.eid='$eid' ".
		 "order BY rsrvtime");

$url = CreateURL("showexp", $experiment);

echo "These are the nodes in the <a href='$url'>shared pool</a>. ";
echo "Please see the <a href='$WIKIDOCURL/SharedNodes'>documentation</a> ";
echo "on how to use shared nodes in your experiment.<br>";

echo "<table width=\"100%\" border=2 cellpadding=1 cellspacing=2 
       id='pooltable' align='center'>\n";
echo "<thead class='sort'>";
echo "<tr>
          <th>NodeID</th>
	  <th>Type</th>
          <th>Reserved</th>
          <th>Default OSID</th>
          <th>Count</th>
          <th>Node<br>Status</th>
          <th>Load Avg<br>1min/5min</th>\n";
echo "</tr>\n";
echo "</thead>\n";

while ($row = mysql_fetch_array($query_result)) {
    $node_id   = $row["node_id"];
    $rsrvtime  = $row["rsrvtime"];
    $type      = $row["type"];
    $status    = $row["nodestatus"];
    $osname    = $row["osname"];
    $osid      = $row["def_boot_osid"];
    $loadavg1  = $row["load_1min"];
    $loadavg5  = $row["load_5min"];
    $vcount    = 0;

    if (array_key_exists($node_id, $counts)) {
	$vcount = $counts[$node_id];
    }

    echo "<tr>";

    if ($isadmin) {
	$url = CreateURL("shownode", URLARG_NODEID, $node_id);
	echo "<td><a href='$url'>$node_id</a></td>\n";
    }
    else {
	echo "<td>$node_id</td>\n";
    }	
    echo "<td><a href='shownodetype.php3?node_type=$type'>$type</a></td>\n";
    echo "<td>$rsrvtime</td>\n";
    
    $url = CreateURL("showosinfo", URLARG_OSID, $osid);
    echo "<td><a href='$url'>$osname</a></td>\n";
    echo "<td>$vcount</td>\n";
    echo "<td>$status</td>\n";
    echo "<td>$loadavg1/$loadavg5</td>\n";
    echo "</tr>\n";
}
echo "</table>\n";

# Sort initialized later when page fully loaded.
AddSortedTable('pooltable');

#
#
#
if ($isadmin) {
    $table = array('#id'       => "Containers",
		   '#title'    => "Containers",
		   '#sortable' => 1,
		   '#headings' => array("node_id"      => "node_id",
					"PID"          => "PID",
					"EID"          => "EID",
					"Status"       => "Status",
					));

    $rows = array();
    
    foreach ($nodes as $node_id) {
	$node = Node::Lookup($node_id);
	if (! $node)
	    continue;

	$status     = $node->RealNodeStatus();
	$experiment = $node->Reservation();
	$pid       = $experiment->pid();
	$eid       = $experiment->eid();
	$creator   = $experiment->creator();
	$nodeurl   = CreateURL("shownode", $node);
	$nodehref  = "<a href='$nodeurl'>$node_id</a>";
	$expurl    = CreateURL("showexp", $experiment);
	$exphref   = "<a href='$expurl'>$eid</a>";

	$rows[$node_id] = array("node_id"   => $nodehref,
				"PID"       => $pid,
				"EID"       => $exphref,
				"Status"    => $status,
                               );
    }
    list ($html, $button) = TableRender($table, $rows);
    echo $html;
}
    
#
# Standard Testbed Footer
# 
PAGEFOOTER();
?>
