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
include("imageid_defs.php");
include("osiddefs.php3");
include("node_defs.php");
chdir("apt");
include("quickvm_sup.php");
include_once("profile_defs.php");
# Must be after quickvm_sup.php since it changes the auth domain.
$page_title = "Clone Image";

#
# Get current user.
#
RedirectSecure();
$this_user = CheckLoginOrRedirect();
if (NOPROJECTMEMBERSHIP()) {
    return NoProjectMembershipError($this_user);
}
$this_idx  = $this_user->uid_idx();
$isadmin   = (ISADMIN() ? "true" : "false");

#
# Verify page arguments.
#
$optargs = OptionalPageArguments("node",	 PAGEARG_NODE,
				 "baseimage",    PAGEARG_IMAGE);

SPITHEADER(1);

#
# If starting from a specific node we can derive baseimage from it.
#
if (isset($node)) {
    $baseimage = $node->def_boot_image();
    if (!isset($baseimage)) {
        USERERROR("Cannot determine base image from node", 1);
    }
    if (!$node->AccessCheck($this_user, $TB_NODEACCESS_LOADIMAGE)) {
        USERERROR("No permission to clone this node", 1);
    }
}
elseif (!isset($baseimage)) {
    USERERROR("Must supply an image or a node to clone", 1);
}
$baseimage_uuid    = $baseimage->uuid();
$baseimage_name    = $baseimage->imagename();
$baseimage_version = $baseimage->version();

# Must be allowed to read the image. 
if (! $baseimage->AccessCheck($this_user, $TB_IMAGEID_READINFO)) {
    $errors["error"] = "Not enough permission to clone image";
}

# Place to hang the toplevel template.
echo "<div id='main-body'></div>\n";

#
# See what projects the user can do this in.
#
$projlist = $this_user->ProjectAccessList($TB_PROJECT_MAKEIMAGEID);

echo "<script type='text/plain' id='projects-json'>\n";
echo htmlentities(json_encode($projlist));
echo "</script>\n";

#
# Need a list of node types. We join this over the nodes table so that
# we get a list of just the nodes that currently in the testbed, not
# just in the node_types table.
#
$types_result =
    DBQueryFatal("select distinct n.type from nodes as n ".
		 "left join node_type_attributes as a on a.type=n.type ".
		 "where a.attrkey='imageable' and ".
		 "      a.attrvalue!='0'");
$alltypes = array();
while ($row = mysql_fetch_array($types_result)) {
    $alltypes[] = $row["type"];
}
echo "<script type='text/plain' id='alltypes-json'>\n";
echo htmlentities(json_encode($alltypes));
echo "</script>\n";

echo "<script type='text/plain' id='oslist-json'>\n";
echo htmlentities(json_encode($osid_oslist));
echo "</script>\n";

echo "<script type='text/plain' id='osfeatures-json'>\n";
echo htmlentities(json_encode($osid_featurelist));
echo "</script>\n";

echo "<link rel='stylesheet'
            href='css/jquery-ui.min.css'>\n";
    
echo "<script type='text/javascript'>\n";
echo "    window.ISADMIN           = $isadmin;\n";
echo "    window.BASEIMAGE_UUID    = '$baseimage_uuid';\n";
echo "    window.BASEIMAGE_NAME    = '$baseimage_name';\n";
echo "    window.BASEIMAGE_VERSION = $baseimage_version;\n";
if (isset($node)) {
    $node_id = $node->node_id();
    echo "    window.NODE = '$node_id';\n";
}
echo "</script>\n";

REQUIRE_UNDERSCORE();
REQUIRE_SUP();
REQUIRE_MOMENT();
REQUIRE_APTFORMS();
REQUIRE_IMAGE();
SPITREQUIRE("js/clone-image.js");
AddTemplateList(array("clone-image",
                      "oops-modal", "waitwait-modal"));
SPITFOOTER();
?>
