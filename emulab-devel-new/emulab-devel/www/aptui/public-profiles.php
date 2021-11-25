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
$page_title = "Public Profiles";
$isguest = 0;

#
# Guest users allowed 
#
RedirectSecure();

SPITHEADER(1);

# Place to hang the toplevel template.
echo "<div id='main-body'></div>\n";

echo "<script type='text/javascript'>\n";
echo "</script>\n";

$profiles = array();

# Make sure the profile is public, no point in showing it if not.
$query_result
    = DBQueryFatal("select p.uuid,p.version,p.name,v.created,v.rspec, ".
                   "    count(h.profile_id) as count,p.lastused,u.usr_name ".
                   "  from apt_instance_history as h ".
                   "left join apt_profiles as p on p.profileid=h.profile_id ".
                   "left join projects as pp on p.pid_idx=pp.pid_idx ".
                   "left join apt_profile_versions as v on ".
                   "     v.profileid=p.profileid and ".
                   "     v.version=p.version ".
                   "left join users as u on u.uid_idx=v.creator_idx ".
                   "where p.uuid is not null and p.public!=0 and ".
                   "      p.disabled=0 and v.disabled=0 and ".
                   "      pp.portal='$PORTAL_GENESIS' ".
                   "group by profile_id order by count desc limit 100");

while ($row = mysql_fetch_array($query_result)) {
    $blob = array();
    $anonname = $row["usr_name"];
    $tokens = preg_split("/\s+/", $anonname);
    if (count($tokens) == 1) {
        $anonname = $tokens[0];
    }
    else {
        $anonname = $tokens[0] . " " . substr(end($tokens), 0 , 1);
    }
    $blob["creator"]   = $anonname;
    $blob["uuid"]      = $row["uuid"];
    $blob["version"]   = $row["version"];
    $blob["name"]      = $row["name"];
    $blob["desc"]      = "";
    $blob["created"]   = DateStringGMT($row["created"]);
    $blob["lastused"]  = DateStringGMT($row["lastused"]);
    $blob["count"]     = $row["count"];

    $parsed_xml = simplexml_load_string($row["rspec"]);
    if ($parsed_xml &&
        $parsed_xml->rspec_tour && $parsed_xml->rspec_tour->description) {
        $desc = $parsed_xml->rspec_tour->description;
        $blob["desc"] = CleanString($desc);
    }
    $profiles[] = $blob;
}

echo "<script type='text/plain' id='most-used-json'>\n";
echo htmlentities(json_encode($profiles)) . "\n";
echo "</script>\n";

$profiles = array();

# Now most recently used
$query_result
    = DBQueryFatal("select p.uuid,p.version,p.name,v.created,v.rspec, ".
                   "    count(h.profile_id) as count,p.lastused,u.usr_name ".
                   "  from apt_instance_history as h ".
                   "left join apt_profiles as p on p.profileid=h.profile_id ".
                   "left join projects as pp on p.pid_idx=pp.pid_idx ".
                   "left join apt_profile_versions as v on ".
                   "     v.profileid=p.profileid and ".
                   "     v.version=p.version ".
                   "left join users as u on u.uid_idx=v.creator_idx ".
                   "where p.uuid is not null and p.public!=0 and ".
                   "      p.disabled=0 and v.disabled=0 and ".
                   "      pp.portal='$PORTAL_GENESIS' ".
                   "group by profile_id order by p.lastused desc limit 100");

while ($row = mysql_fetch_array($query_result)) {
    $blob = array();
    $anonname = $row["usr_name"];
    $tokens = preg_split("/\s+/", $anonname);
    if (count($tokens) == 1) {
        $anonname = $tokens[0];
    }
    else {
        $anonname = $tokens[0] . " " . substr(end($tokens), 0 , 1);
    }
    $blob["creator"]   = $anonname;
    $blob["uuid"]      = $row["uuid"];
    $blob["version"]   = $row["version"];
    $blob["name"]      = $row["name"];
    $blob["desc"]      = "";
    $blob["created"]   = DateStringGMT($row["created"]);
    $blob["lastused"]  = DateStringGMT($row["lastused"]);
    $blob["count"]     = $row["count"];

    $parsed_xml = simplexml_load_string($row["rspec"]);
    if ($parsed_xml &&
        $parsed_xml->rspec_tour && $parsed_xml->rspec_tour->description) {
        $desc = $parsed_xml->rspec_tour->description;
        $blob["desc"] = CleanString($desc);
    }
    $profiles[] = $blob;
}

echo "<script type='text/plain' id='recently-used-json'>\n";
echo htmlentities(json_encode($profiles)) . "\n";
echo "</script>\n";

$profiles = array();

# Recently created
$query_result
    = DBQueryFatal("select p.uuid,p.version,p.name,v.created,v.rspec, ".
                   "    count(h.profile_id) as count,p.lastused,u.usr_name ".
                   "  from apt_instance_history as h ".
                   "left join apt_profiles as p on p.profileid=h.profile_id ".
                   "left join projects as pp on p.pid_idx=pp.pid_idx ".
                   "left join apt_profile_versions as v on ".
                   "     v.profileid=p.profileid and ".
                   "     v.version=p.version ".
                   "left join users as u on u.uid_idx=v.creator_idx ".
                   "where p.uuid is not null and p.public!=0 and ".
                   "      p.disabled=0 and v.disabled=0 and ".
                   "      pp.portal='$PORTAL_GENESIS' ".
                   "group by profile_id order by v.created desc limit 50");

while ($row = mysql_fetch_array($query_result)) {
    $blob = array();
    $anonname = $row["usr_name"];
    $tokens = preg_split("/\s+/", $anonname);
    if (count($tokens) == 1) {
        $anonname = $tokens[0];
    }
    else {
        $anonname = $tokens[0] . " " . substr(end($tokens), 0 , 1);
    }
    $blob["creator"]   = $anonname;
    $blob["uuid"]      = $row["uuid"];
    $blob["version"]   = $row["version"];
    $blob["name"]      = $row["name"];
    $blob["desc"]      = "";
    $blob["created"]   = DateStringGMT($row["created"]);
    $blob["lastused"]  = DateStringGMT($row["lastused"]);
    $blob["count"]     = $row["count"];

    $parsed_xml = simplexml_load_string($row["rspec"]);
    if ($parsed_xml &&
        $parsed_xml->rspec_tour && $parsed_xml->rspec_tour->description) {
        $desc = $parsed_xml->rspec_tour->description;
        $blob["desc"] = CleanString($desc);
    }
    $profiles[] = $blob;
}

echo "<script type='text/plain' id='recently-created-json'>\n";
echo htmlentities(json_encode($profiles)) . "\n";
echo "</script>\n";

$profiles = array();

# Examples
$query_result
    = DBQueryFatal("select p.uuid,p.version,p.name,v.created,v.rspec, ".
                   "    count(h.profile_id) as count,p.lastused,u.usr_name ".
                   "  from apt_instance_history as h ".
                   "left join apt_profiles as p on p.profileid=h.profile_id ".
                   "left join apt_profile_versions as v on ".
                   "     v.profileid=p.profileid and ".
                   "     v.version=p.version ".
                   "left join users as u on u.uid_idx=v.creator_idx ".
                   "where p.uuid is not null and p.public!=0 and ".
                   "      p.disabled=0 and v.disabled=0 and ".
                   "      FIND_IN_SET('$PORTAL_GENESIS',examples_portals) ".
                   "group by profile_id ".
                   "order by " .
                   ($ISPOWDER ? "examples_portals,p.name" : "p.name"));

while ($row = mysql_fetch_array($query_result)) {
    $blob = array();
    $anonname = $row["usr_name"];
    $tokens = preg_split("/\s+/", $anonname);
    if (count($tokens) == 1) {
        $anonname = $tokens[0];
    }
    else {
        $anonname = $tokens[0] . " " . substr(end($tokens), 0 , 1);
    }
    $blob["creator"]   = $anonname;
    $blob["uuid"]      = $row["uuid"];
    $blob["version"]   = $row["version"];
    $blob["name"]      = $row["name"];
    $blob["desc"]      = "";
    $blob["created"]   = DateStringGMT($row["created"]);
    $blob["lastused"]  = DateStringGMT($row["lastused"]);
    $blob["count"]     = $row["count"];

    $parsed_xml = simplexml_load_string($row["rspec"]);
    if ($parsed_xml &&
        $parsed_xml->rspec_tour && $parsed_xml->rspec_tour->description) {
        $desc = $parsed_xml->rspec_tour->description;
        $blob["desc"] = CleanString($desc);
    }
    $profiles[] = $blob;
}

echo "<script type='text/plain' id='examples-json'>\n";
echo htmlentities(json_encode($profiles)) . "\n";
echo "</script>\n";

REQUIRE_UNDERSCORE();
REQUIRE_SUP();
REQUIRE_MOMENT();
REQUIRE_MARKED();
REQUIRE_TABLESORTER();
AddTemplateList(array("public-profiles",
                      "profile-list", "oops-modal", "waitwait-modal"));
SPITREQUIRE("js/public-profiles.js");

SPITFOOTER();
?>
