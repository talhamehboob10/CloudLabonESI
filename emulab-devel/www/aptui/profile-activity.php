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
include("profile_defs.php");
$page_title = "My Profiles";

#
# Verify page arguments.
#
$reqargs = RequiredPageArguments("uuid",  PAGEARG_STRING);

#
# Get current user.
#
RedirectSecure();
$this_user = CheckLoginOrRedirect();
$this_idx  = $this_user->uid_idx();

SPITHEADER(1);

$profile = Profile::Lookup($uuid);
if (!$profile) {
    SPITUSERERROR("No such profile!");
}
else if (! ($profile->CanView($this_user) || ISADMIN())) {
    SPITUSERERROR("Not enough permission!");
}
$profileid = $profile->profileid();
$profile_pid = $profile->pid();
$profile_name = $profile->name();
$instances = array();

#
# First existing instances and then the history table.
#
$query1_result =
    DBQueryFatal("select 1 as active, ".
                 "   i.uuid,i.profile_version,i.started,'' as destroyed, ".
		 "   i.creator,p.uuid as profile_uuid,u.email,".
                 "   GROUP_CONCAT(ia.public_url) as public_urls, ".
                 "   GROUP_CONCAT(aa.abbreviation) as clusters, ".
                 "   i.slice_uuid,f.exitmessage,f.exitcode,i.pid,i.name ".
		 "  from apt_instances as i ".
                 "left join apt_instance_failures as f ".
                 "     on f.uuid=i.uuid ".
                 "left join apt_instance_aggregates as ia ".
                 "     on ia.uuid=i.uuid ".
		 "left join apt_profile_versions as p on ".
		 "     p.profileid=i.profile_id and ".
		 "     p.version=i.profile_version ".
		 "left join geni.geni_users as u on u.uuid=i.creator_uuid ".
                 "left join apt_aggregates as aa on aa.urn=ia.aggregate_urn ".
		 "where i.profile_id='$profileid' ".
                 (!ISADMIN() ? "and i.creator_idx='$this_idx' " : "") .
		 "group by i.uuid order by i.started desc");

$query2_result =
    DBQueryFatal("select 0 as active, ".
                 "    h.uuid,h.profile_version,h.started,h.destroyed, ".
		 "    h.creator,p.uuid as profile_uuid,u.email, ".
                 "    GROUP_CONCAT(ia.public_url) as public_urls, ".
                 "    GROUP_CONCAT(aa.abbreviation) as clusters, ".
                 "    h.slice_uuid,f.exitmessage,f.exitcode,h.pid,h.name ".
		 "  from apt_instance_history as h ".
                 "left join apt_instance_failures as f ".
                 "     on f.uuid=h.uuid ".
                 "left join apt_instance_aggregate_history as ia ".
                 "     on ia.uuid=h.uuid ".
		 "left join apt_profile_versions as p on ".
		 "     p.profileid=h.profile_id and ".
		 "     p.version=h.profile_version ".
		 "left join geni.geni_users as u on u.uuid=h.creator_uuid ".
                 "left join apt_aggregates as aa on aa.urn=ia.aggregate_urn ".
		 "where h.profile_id='$profileid' ".
                 (!ISADMIN() ? "and h.creator_idx='$this_idx' " : "") .
		 "group by h.uuid order by h.started desc");

if (mysql_num_rows($query1_result) == 0 &&
    mysql_num_rows($query2_result) == 0) {
    $message = "<b>Oops, there is no activity to show you.</b><br>";
    SPITUSERERROR($message);
    exit();
}

foreach (array($query1_result, $query2_result) as $query_result) {
    while ($row = mysql_fetch_array($query_result)) {
        $active    = $row["active"];
	$uuid      = $row["uuid"];
	$puuid     = $row["profile_uuid"];
	$pversion  = $row["profile_version"];
	$created   = DateStringGMT($row["started"]);
	$destroyed = DateStringGMT($row["destroyed"]);
	$creator   = $row["creator"];
	$email     = $row["email"];
        $exitmessage= $row["exitmessage"];
        $exitcode   = $row["exitcode"];
        $public_urls= $row["public_urls"];
        $slice_uuid= $row["slice_uuid"];
        $clusters  = $row["clusters"];
	# If a guest user, use email instead.
	if (isset($email)) {
	    $creator = $email;
	}
	$instance = array();
        $instance["active"]      = intval($active);
	$instance["uuid"]        = $uuid;
	$instance["pid"]         = $row["pid"];
	$instance["name"]        = $row["name"];
	$instance["p_uuid"]      = $puuid;
	$instance["p_version"]   = $pversion;
	$instance["creator"]     = $creator;
	$instance["created"]     = $created;
	$instance["destroyed"]   = $destroyed;
	$instance["clusters"]    = ($clusters ? $clusters : "n/a");
        if (isset($exitcode)) {
            $instance["iserror"]       = 1;

            if ($exitcode >= 0 && $exitcode <= count($geni_response_codes)) {
                $instance["error_reason"] = $geni_response_codes[$exitcode];
            }
            elseif ($exitcode == GENIRESPONSE_STITCHER_ERROR) {
                $instance["error_reason"] = "Stitcher Failed";
            }
            else {
                $instance["error_reason"]  = $exitcode;
            }
            $instance["error_message"] = $exitmessage;
        }
	$instances[] = $instance;
    }
}

# Place to hang the toplevel template.
echo "<div id='activity-body'></div>\n";

echo "<script type='text/javascript'>\n";
echo "    window.AJAXURL  = 'server-ajax.php';\n";
echo "    window.PROFILE_UUID = '$uuid';\n";
echo "    window.PROFILE_PID = '$profile_pid';\n";
echo "    window.PROFILE_NAME = '$profile_name';\n";
echo "    window.ISADMIN  = " . (ISADMIN() ? "true" : "false") . ";\n";
echo "</script>\n";
echo "<script type='text/plain' id='instances-json'>\n";
echo json_encode($instances,
                 JSON_HEX_APOS|JSON_HEX_QUOT|JSON_HEX_TAG|JSON_HEX_AMP);
echo "</script>\n";
echo "<script src='js/lib/jquery-2.0.3.min.js'></script>\n";

REQUIRE_UNDERSCORE();
REQUIRE_SUP();
REQUIRE_MOMENT();
REQUIRE_TABLESORTER();
SPITREQUIRE("js/profile-activity.js");

AddTemplate("profile-activity");
SPITFOOTER();
?>
