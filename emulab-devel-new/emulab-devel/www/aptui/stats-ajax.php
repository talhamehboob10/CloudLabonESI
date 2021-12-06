<?php
#
# Copyright (c) 2000-2021 University of Utah and the Flux Group.
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
chdir("..");
include("defs.php3");
chdir("apt");
include("quickvm_sup.php");

# 
# Allow this to be fetched from pages loaded anywhere
#
header("Access-Control-Allow-Origin: *");

#
# We use the server to determine which portal.
#
$portal = $PORTAL_GENESIS;
$servername = $APTHOST;
# Include classic numbers.
if ($portal == "emulab") {
    $portalclause = "(p.portal='$portal' or p.portal is null)";
}
else {
    $portalclause = "(p.portal='$portal')";
}    

#
# For the Cloudlab front page, to display some current stats.
#
$blob = array("active_experiments" => 0,
              "total_experiments"  => 0,
              "projects"  => 0,
              "distinct_users"  => 0);

#
# Number of active experiments.
#
$query_result =
    DBQueryFatal("select count(*) from apt_instances " .
                 "where portal='$portal'");
if ($query_result) {
    $row = mysql_fetch_array($query_result);
    $blob["active_experiments"] = $row[0];
}
# Add classic to emulab portal numbers,
if ($portal == "emulab") {
    $query_result =
        DBQueryFatal("select count(*) from experiments ".
                     "where geniflags=0 && state='active'");
}
if ($query_result) {
    $row = mysql_fetch_array($query_result);
    $blob["active_experiments"] += $row[0];
}

#
# Number of experiments ever
#
$query_result =
    DBQueryFatal("select portal,count(*) as count from apt_instance_history ".
                 "group by portal");
while ($row = mysql_fetch_array($query_result)) {
    if ($row["portal"] == $portal) {
        $blob["total_experiments"] = $row["count"];
    }
}
# Add classic to emulab portal numbers,
if ($portal == "emulab") {
    $query_result =
        DBQueryFatal("select count(*) from experiment_stats ".
                     "where geniflags is null");
}
if ($query_result) {
    $row = mysql_fetch_array($query_result);
    $blob["total_experiments"] += $row[0];
}

#
# Number Cloudlab projects.
#
$query_result =
    DBQueryFatal("select count(*) from projects as p ".
                 "where p.approved=1 and $portalclause");
if ($query_result) {
    $row = mysql_fetch_array($query_result);
    $blob["projects"] = $row[0];
}

#
# Number of users who have ever created an experiment.
#
if ($portal == "emulab") {
    $query_result =
        DBQueryFatal("select count(distinct creator_idx) from projects as p ".
                     "join experiment_stats as s on p.pid_idx=s.pid_idx ".
                     "where geniflags is null or ".
                     "      (p.portal='emulab' or p.portal is null)");
}
else {
    $query_result =
        DBQueryFatal("select count(distinct creator_idx) from ".
                     "     apt_instance_history ".
                     "   where portal='$PORTAL_GENESIS';");
}
if ($query_result) {
    $row = mysql_fetch_array($query_result);
    $blob["distinct_users"] = $row[0];
}

#
# Number of profiles (both public and private)
#
$query_result =
    DBQueryFatal("select count(*) from apt_profiles as a ".
                 "left join projects as p on p.pid_idx=a.pid_idx ".
                 "where $portalclause");
if ($query_result) {
    $row = mysql_fetch_array($query_result);
    $blob["profiles"] = $row[0];
}

#
# For the Emulab Portal frontpage, we return inuse/free counts for
# the allocatable node types, mostly so we have something interesting
# to show.
#
$typeinfo  = array();
$prunelist = Instance::NodeTypePruneList(null, true);

#
# Get total number of nodes.
#
$query_result =
   DBQueryFatal("select n.type,count(*) as count from nodes as n ".
                "left join node_types as nt on n.type=nt.type ".
                "left join node_type_attributes as attr on ".
                "     attr.type=n.type and ".
                "     attr.attrkey='noshowfreenodes' ".
                "where (role='testnode') and class='pc' and ".
                "      attr.attrvalue is null ".
                "group BY n.type");

while ($row = mysql_fetch_array($query_result)) {
    $type  = $row["type"];
    $count = $row["count"];

    if (!array_key_exists($type, $prunelist)) {
        $typeinfo[$type] = array("total" => $count, "free" => 0);
    }
}

# Get free totals by type.
$query_result =
   DBQueryFatal("select n.type,count(*) as count from nodes as n ".
                "left join node_types as nt on n.type=nt.type ".
                "left join reserved as r on r.node_id=n.node_id ".
                "left join node_type_attributes as attr on ".
                "     attr.type=n.type and ".
                "     attr.attrkey='noshowfreenodes' ".
                "where (role='testnode') and class='pc' and ".
                "      r.pid is null and ".
                "      attr.attrvalue is null and ".
                "      (n.reserved_pid is null) AND ".
                "      (n.eventstate='" . TBDB_NODESTATE_ISUP . "' or ".
                "       n.eventstate='" . TBDB_NODESTATE_POWEROFF . "' or ".
                "       n.eventstate='" . TBDB_NODESTATE_ALWAYSUP . "' or ".
                "       n.eventstate='" . TBDB_NODESTATE_PXEWAIT . "') ".
                "group BY n.type");

while ($row = mysql_fetch_array($query_result)) {
    $type  = $row["type"];
    $count = $row["count"];

    if (!array_key_exists($type, $prunelist)) {
        $typeinfo[$type]["free"] = $count;
    }
}

$blob["typeinfo"] = $typeinfo;

echo json_encode($blob);
