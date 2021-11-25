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
$page_title = "Example Profiles";

#
# Get current user.
#
RedirectSecure();
$this_user = CheckLogin($check_status);
if (isset($this_user)) {
    CheckLoginOrDie(CHECKLOGIN_NONLOCAL|CHECKLOGIN_WEBONLY);
}
else {
}

SPITHEADER(1);

# Place to hang the toplevel template.
echo "<div id='main-body'></div>\n";

echo "<script type='text/javascript'>\n";
echo "</script>\n";

$profiles = array();

# Make sure the profile is public, no point in showing it if not.
$query_result
    = DBQueryFatal("select p.*,v.*,DATE(v.created) as created ".
                   "   from apt_profiles as p ".
                   "left join apt_profile_versions as v on ".
                   "     v.profileid=p.profileid and ".
                   "     v.version=p.version ".
                   "where (p.public!=0 and ".
                   "        FIND_IN_SET('$PORTAL_GENESIS',examples_portals)) ".
                   "order by " .
                   ($ISPOWDER ? "examples_portals,p.name" : "p.name"));

while ($row = mysql_fetch_array($query_result)) {
    $blob = array();

    $blob["uuid"]      = $row["uuid"];
    $blob["version"]   = $row["version"];
    $blob["name"]      = $row["name"];
    $blob["pid"]       = $row["pid"];
    $blob["desc"]      = CleanString($row["description"]);
    $blob["created"]   = DateStringGMT($row["created"]);

    $parsed_xml = simplexml_load_string($row["rspec"]);
    if ($parsed_xml &&
        $parsed_xml->rspec_tour && $parsed_xml->rspec_tour->description) {
        $desc = $parsed_xml->rspec_tour->description;
        $blob["desc"] = CleanString($desc);
    }
    $profiles[] = $blob;
}

echo "<script type='text/plain' id='profiles-json'>\n";
echo htmlentities(json_encode($profiles)) . "\n";
echo "</script>\n";

REQUIRE_UNDERSCORE();
REQUIRE_SUP();
REQUIRE_MOMENT();
REQUIRE_MARKED();
REQUIRE_TABLESORTER();
AddTemplateList(array("example-profiles"));
SPITREQUIRE("js/example-profiles.js");

SPITFOOTER();
?>
