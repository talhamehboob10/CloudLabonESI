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
$page_title = "User/Project List";

#
# Get current user.
#
RedirectSecure();
$this_user = CheckLoginOrRedirect();
$this_idx  = $this_user->uid_idx();
$this_uid  = $this_user->uid();

# Recent means current login or did something in last N days.
$days = 30;

#
# Verify page arguments.
#
SPITHEADER(1);

if (!ISADMIN()) {
    SPITUSERERROR("You do not have permission to view this information!");
    return;
}

# Place to hang the toplevel template.
echo "<div id='main-body'></div>\n";

function SpitUserList($days)
{
    global $PORTAL_GENESIS, $APTHOST;
    
    $query_result =
        DBQueryFatal("(select distinct u.uid,u.usr_name,u.usr_affil ".
                     "   from login as l ".
                     " left join users as u on u.uid_idx=l.uid_idx ".
                     " where l.portal='$PORTAL_GENESIS' and ".
                     "       l.timeout > UNIX_TIMESTAMP(now())) ".
                     "union ".
                     " (select distinct u.uid,u.usr_name,u.usr_affil ".
                     "   from apt_instances as i ".
                     " left join users as u on u.uid_idx=i.creator_idx ".
                     " where i.servername='$APTHOST')");

    while ($row = mysql_fetch_array($query_result)) {
        $blob = array();
        $blob["usr_uid"]    = $row["uid"];
        $blob["usr_name"]   = $row["usr_name"];
        $blob["usr_affil"]  = $row["usr_affil"];
        $results[$row[0]] = $blob;
    }
    echo "<script type='text/plain' id='users-json'>\n";
    echo json_encode($results,
                     JSON_HEX_APOS|JSON_HEX_QUOT|JSON_HEX_TAG|JSON_HEX_AMP);
    echo "</script>\n";
}
function SpitProjectList($days)
{
    global $PORTAL_GENESIS, $APTHOST;
    
    $query_result =
        DBQueryFatal("(select distinct i.pid,u.uid,u.usr_name,u.usr_affil ".
                     "   from apt_instances as i ".
                     " left join projects as p on p.pid_idx=i.pid_idx ".
                     " left join users as u on u.uid_idx=p.head_idx ".
                     " where i.servername='$APTHOST') ".
                     "union ".
                     "(select distinct i.pid,u.uid,u.usr_name,u.usr_affil ".
                     "   from apt_instance_history as i ".
                     " left join projects as p on p.pid_idx=i.pid_idx ".
                     " left join users as u on u.uid_idx=p.head_idx ".
                     " where i.servername='$APTHOST' and ".
                     "       i.started>DATE_SUB(curdate(), INTERVAL 2 MONTH))");
                     
    $results = array();

    while ($row = mysql_fetch_array($query_result)) {
        $blob = array();
        $blob["usr_uid"]    = $row["uid"];
        $blob["usr_name"]   = $row["usr_name"];
        $blob["usr_affil"]  = $row["usr_affil"];
        $results[$row[0]] = $blob;
    }
    echo "<script type='text/plain' id='projects-json'>\n";
    echo json_encode($results,
                     JSON_HEX_APOS|JSON_HEX_QUOT|JSON_HEX_TAG|JSON_HEX_AMP);
    echo "</script>\n";
}
SpitUserList($days);
SpitProjectList($days);

REQUIRE_UNDERSCORE();
REQUIRE_SUP();
REQUIRE_MOMENT();
REQUIRE_TABLESORTER();
SPITREQUIRE("js/lists.js");
AddTemplate("lists");
SPITFOOTER();
?>
