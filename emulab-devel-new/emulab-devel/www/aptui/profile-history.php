<?php
#
# Copyright (c) 2000-2016 University of Utah and the Flux Group.
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

SPITHEADER(1);

$profile = Profile::Lookup($uuid);
if (!$profile) {
    SPITUSERERROR("No such profile!");
}
else if ($this_user->uid_idx() != $profile->creator_idx() && !ISADMIN()) {
    SPITUSERERROR("Not enough permission!");
}
$profileid = $profile->profileid();
$profiles  = array();

$query_result =
    DBQueryFatal("select v.*,DATE(v.created) as created,vp.uuid as parent_uuid ".
		 "  from apt_profile_versions as v ".
                 "left join apt_profile_versions as vp on ".
                 "     v.parent_profileid is not null and ".
                 "     vp.profileid=v.parent_profileid and ".
                 "     vp.version=v.parent_version ".
		 "where v.profileid='$profileid' and v.deleted is null ".
		 "order by v.created desc");

while ($row = mysql_fetch_array($query_result)) {
    $idx     = $row["profileid"];
    $pidx    = $row["parent_profileid"];
    $uuid    = $row["uuid"];
    $puuid   = $row["parent_uuid"];
    $version = $row["version"];
    $pversion= $row["parent_version"];
    $name    = $row["name"];
    $pid     = $row["pid"];
    $created = $row["created"];
    $published = $row["published"];
    $creator = ($version == 0 ? $row["creator"] : $row["updater"]);
    $rspec   = $row["rspec"];
    $desc    = '';

    if (!$published) {
	$published = " ";
    }
    $parsed_xml = simplexml_load_string($rspec);
    if ($parsed_xml &&
	$parsed_xml->rspec_tour && $parsed_xml->rspec_tour->description) {
	$desc = (string) $parsed_xml->rspec_tour->description;
    }

    $profile = array();
    $profile["uuid"]    = $uuid;
    $profile["version"] = $version;
    $profile["creator"] = $creator;
    $profile["description"] = $desc;
    $profile["created"]     = $created;
    $profile["published"]   = $published;
    $profile["parent_uuid"] = $puuid;
    $profile["parent_version"] = $pversion;

    $profiles[] = $profile;
}

# Place to hang the toplevel template.
echo "<div id='history-body'></div>\n";

echo "<script type='text/javascript'>\n";
echo "    window.AJAXURL  = 'server-ajax.php';\n";
echo "    window.WITHPUBLISHING = $WITHPUBLISHING;\n";
echo "</script>\n";
echo "<script type='text/plain' id='profiles-json'>\n";
echo json_encode($profiles);
echo "</script>\n";
echo "<script src='js/lib/jquery-2.0.3.min.js'></script>\n";

REQUIRE_UNDERSCORE();
REQUIRE_SUP();
SPITREQUIRE("js/profile-history.js");

AddTemplate("profile-history");
SPITFOOTER();
?>
