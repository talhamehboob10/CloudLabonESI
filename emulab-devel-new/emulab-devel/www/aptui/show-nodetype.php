<?php
#
# Copyright (c) 2000-2019 University of Utah and the Flux Group.
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
include("node_defs.php");
chdir("apt");
include("quickvm_sup.php");
# Must be after quickvm_sup.php since it changes the auth domain.
$page_title = "Show NodeType";

#
# Get current user. GUEST USER ALLOWED.
#
RedirectSecure();
$this_user = CheckLogin($check_status);
# Operate as a guest user if not logged in,
if (! ($check_status & CHECKLOGIN_LOGGEDIN)) {
    $this_user = null;
}

#
# Verify page arguments.
#
$reqargs = RequiredPageArguments("type",  PAGEARG_STRING);
$optargs = OptionalPageArguments("edit",  PAGEARG_BOOLEAN);

if ($edit) {
    $this_user = CheckLoginOrRedirect();
    if (! ($this_user && ISADMIN())) {
        SPITUSERERROR("Not enough permission!");
    }
    $edit = 1;
}
else {
    $edit = 0;
}
if (!preg_match("/^[-\w]+$/", $type)) {
    SPITUSERERROR("$node_type contains illegal characters!");
}
$nodetype = NodeType::Lookup($type);
if (!$nodetype) {
    SPITUSERERROR("No such node type");
}

SPITHEADER(1);

#
# We need lists of osids and imageids for selection.
#
if ($edit) {
    $osid_result =
        DBQueryFatal("select o.osid,o.osname,o.pid from os_info as o ".
                     "left join os_info_versions as v on ".
                     "     v.osid=o.osid and v.vers=o.version ".
                     "where (v.path='' or v.path is NULL) and ".
                     "      o.pid='$TBOPSPID' ".
                     "order by o.osname");

    $mfs_result =
        DBQueryFatal("select o.osid,o.osname,o.pid from os_info as o ".
                     "left join os_info_versions as v on ".
                     "     v.osid=o.osid and v.vers=o.version ".
                     "where ((v.path is not NULL and v.path!='') or v.mfs=1) ".
                     "      and o.pid='$TBOPSPID' ".
                     "order by o.osname");

    $imageid_result =
        DBQueryFatal("select imageid,imagename,pid from images ".
                     "where pid='$TBOPSPID' ".
                     "order by imagename");
}
 
# Place to hang the toplevel template.
echo "<div id='main-body'></div>\n";

echo "<link rel='stylesheet'
            href='css/jquery-ui.min.css'>\n";

echo "<script type='text/javascript'>\n";
echo "    window.TYPE      = '$type';\n";
echo "    window.ISADMIN   = " . (ISADMIN() ? "true" : "false") . ";\n";
echo "    window.EDITING   = $edit;\n";
echo "    window.ISGUEST   = " . ($this_user ? "false" : "true") . ";\n";
echo "    window.HASHWINFO = " .
    ($nodetype->HasHardwareInfo() ? "true" : "false") . ";\n";
echo "</script>\n";

if ($edit) {
    $list = array();
    while ($row = mysql_fetch_array($imageid_result)) {
	$imageid   = $row["imageid"];
	$imagename = $row["imagename"];
	$pid       = $row["pid"];

        $list[] = array("osid" => $imageid,
                        "pid"  => $pid,
                        "name" => $imagename);
    }
    echo "<script type='text/plain' id='images-json'>\n";
    echo htmlentities(json_encode($list));
    echo "</script>\n";

    $list = array();
    while ($row = mysql_fetch_array($osid_result)) {
	$osid   = $row["osid"];
	$osname = $row["osname"];
	$pid    = $row["pid"];

        $list[] = array("osid" => $osid,
                        "pid"  => $pid,
                        "name" => $osname);
    }
    echo "<script type='text/plain' id='osinfo-json'>\n";
    echo htmlentities(json_encode($list));
    echo "</script>\n";

    $list = array();
    while ($row = mysql_fetch_array($mfs_result)) {
	$osid   = $row["osid"];
	$osname = $row["osname"];
	$pid    = $row["pid"];

        $list[] = array("osid" => $osid,
                        "pid"  => $pid,
                        "name" => $osname);
    }
    echo "<script type='text/plain' id='mfs-json'>\n";
    echo htmlentities(json_encode($list));
    echo "</script>\n";
}

REQUIRE_UNDERSCORE();
REQUIRE_SUP();
REQUIRE_MOMENT();
SPITREQUIRE("js/show-nodetype.js");
AddTemplateList(array("show-nodetype", "oops-modal", "waitwait-modal"));
SPITFOOTER();

?>
