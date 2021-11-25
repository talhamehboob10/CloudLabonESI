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
# Must be after quickvm_sup.php since it changes the auth domain.
$page_title = "Ranking";

#
# Get current user.
#
RedirectSecure();
$this_user = CheckLoginOrRedirect();
$this_idx  = $this_user->uid_idx();
$this_uid  = $this_user->uid();

$optargs = OptionalPageArguments("days",     PAGEARG_INTEGER,
                                 "allusers", PAGEARG_BOOLEAN);
if (!isset($days)) {
    $days = 30;
}
if (!isset($allusers)) {
    $allusers = 0;
}

#
# Verify page arguments.
#
SPITHEADER(1);

if (!ISADMIN() && !ISFOREIGN_ADMIN()) {
    SPITUSERERROR("You do not have permission to view this information!");
    return;
}

echo "<script type='text/javascript'>\n";
echo "    window.DAYS = $days;\n";
echo "    window.ALLUSERS = $allusers;\n";
echo "</script>\n";

# Place to hang the toplevel template.
echo "<div id='main-body'></div>\n";

function SpitRankList($target, $days, $allusers)
{
    $count = 1;

    if ($target == "user") {
        $which = "c.creator,c.creator_idx";
        $join  = "left join users as u on u.uid_idx=c.creator_idx ";
    }
    else {
        $which = "c.pid,c.pid_idx";
        $join  = "left join projects as p on p.pid_idx=c.pid_idx ".
            "     left join users as u on u.uid_idx=p.head_idx";
    }
    $query_result =
        DBQueryFatal("select $which,SUM(physnode_count) as physnode_count,".
                     "   SUM(phours) as phours,u.usr_name,u.usr_affil, ".
                     "   u.uid from ".
                     " ((select $which,physnode_count,started,NULL, ".
                     "   physnode_count * (TIMESTAMPDIFF(HOUR, ".
                     "    IF(started > DATE_SUB(now(), INTERVAL $days DAY), ".
                     "       started, DATE_SUB(now(), INTERVAL $days DAY)), now())) ".
                     "    as phours ".
                     "   from apt_instances as c ".
                     "   where physnode_count>0) ".
                     "  union ".
                     "  (select $which,physnode_count,started,destroyed, ".
                     "   physnode_count * (TIMESTAMPDIFF(HOUR, ".
                     "    IF(started > DATE_SUB(now(), INTERVAL $days DAY), ".
                     "       started, DATE_SUB(now(), INTERVAL $days DAY)), destroyed))".
                     "    as phours ".
                     "   from apt_instance_history as c ".
                     "   where physnode_count>0 and ".
                     "         destroyed>DATE_SUB(now(),INTERVAL $days DAY)))".
                     "   as c ".
                     "$join ".
                     "group by $which ".
                     "order by phours desc ".
                     ($allusers ? "" : "limit 250"));
    
    $results = array();

    while ($row = mysql_fetch_array($query_result)) {
        $blob = array();
        $blob["rank"]       = $count++;
        $blob["usr_uid"]    = $row["uid"];
        $blob["usr_name"]   = $row["usr_name"];
        $blob["usr_affil"]  = $row["usr_affil"];
        $blob["pnodes"]     = $row["physnode_count"];
        $blob["phours"]     = $row["phours"];
        $results[$row[0]] = $blob;
    }
    echo "<script type='text/plain' id='${target}-json'>\n";
    echo json_encode($results);
    echo "</script>\n";
}
SpitRankList("user", $days, $allusers);
SpitRankList("project", $days, 0);

#
# Most popular profiles.
#
$profiles = array();
$rank = 1;

$query_result =
    DBQueryFatal("select p.uuid,p.name,count(h.profile_id) as count,p.pid, ".
                 "   v.pid,v.name ".
                 "   from apt_instance_history as h ".
                 "left join apt_profiles as p on ".
                 "   p.profileid=h.profile_id ".
                 "left join apt_profile_versions as v on ".
                 "   v.profileid=h.profile_id and ".
                 "   v.version=h.profile_version ".
                 "where h.started>DATE_SUB(now(),INTERVAL $days DAY) ".
                 "group by profile_id,v.pid,v.name ".
		 "order by count desc limit 100");

while ($row = mysql_fetch_array($query_result)) {
    $name       = $row["name"];
    $count      = $row["count"];
    $uuid       = $row["uuid"];
    $pid        = $row["pid"];

    $profiles[$rank] = array("name"  => $name,
                             "uuid"  => $uuid,
                             "pid"   => $pid,
                             "rank"  => $rank++,
                             "count" => $count);
}
echo "<script type='text/plain' id='profile-json'>\n";
echo json_encode($profiles);
echo "</script>\n";

REQUIRE_UNDERSCORE();
REQUIRE_SUP();
REQUIRE_TABLESORTER(array('js/lib/tablesorter/widgets/widget-output.js'));
SPITREQUIRE("js/ranking.js");
AddTemplate("ranking");
AddTemplate("output-dropdown");
SPITFOOTER();
?>
