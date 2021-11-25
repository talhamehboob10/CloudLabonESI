<?php
#
# Copyright (c) 2000-2020 University of Utah and the Flux Group.
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
include("node_defs.php");
chdir("apt");
include("quickvm_sup.php");
# Must be after quickvm_sup.php since it changes the auth domain.
$page_title = "Show Image";

#
# Get current user.
#
RedirectSecure();
$this_user = CheckLoginOrRedirect();
$this_idx  = $this_user->uid_idx();
$isadmin   = (ISADMIN() ? "true" : "false");

#
# Verify page arguments.
#
$reqargs = RequiredPageArguments("image", PAGEARG_IMAGE);
$optargs = OptionalPageArguments("showsnapstatus", PAGEARG_BOOLEAN,
                                 "autosnap",       PAGEARG_BOOLEAN,
                                 "node",           PAGEARG_NODE);
$showsnapstatus = (isset($showsnapstatus) ? $showsnapstatus : 0);
$autosnap = (isset($autosnap) ? $autosnap : 0);
if (($autosnap || $showsnapstatus) && isset($node)) {
    $snapnode = $node->node_id();
}

if (!$image) {
    SPITUSERERROR("No such image!");
}
if (!$image->AccessCheck($this_user, $TB_IMAGEID_READINFO)) {
    SPITUSERERROR("Not enough permission!");
}
$uuid = $image->uuid();
$canedit   = ($image->AccessCheck($this_user,
                                  $TB_IMAGEID_MODIFYINFO) ? "true" : "false");
$candelete = ($image->AccessCheck($this_user,
                                  $TB_IMAGEID_DESTROY) ? "true" : "false");

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
$alltypes[] = "pcvm";

SPITHEADER(1);

# Place to hang the toplevel template.
echo "<div class=row>
        <div id='main-body'></div>
        <div id='oops_div'></div>
        <div id='waitwait_div'></div>
        <div id='imaging_div'></div>
      </div>\n";

echo "<link rel='stylesheet'
            href='css/jquery-ui.min.css'>\n";

# For progress bubbles in the imaging modal.
echo "<link rel='stylesheet' href='css/progress.css'>\n";

echo "<script type='text/javascript'>\n";
echo "    window.UUID           = '$uuid';\n";
echo "    window.ISADMIN        = $isadmin;\n";
echo "    window.CANEDIT        = $canedit;\n";
echo "    window.CANDELETE      = $candelete;\n";
echo "    window.SHOWSNAPSTATUS = $showsnapstatus;\n";
echo "    window.AUTOSNAP       = $autosnap;\n";
if (isset($snapnode)) {
    echo "    window.SNAPNODE   = '$snapnode';\n";
}
echo "</script>\n";

echo "<script type='text/plain' id='alltypes-json'>\n";
echo json_encode($alltypes,
                 JSON_HEX_APOS|JSON_HEX_QUOT|JSON_HEX_TAG|JSON_HEX_AMP);
echo "</script>\n";

REQUIRE_UNDERSCORE();
REQUIRE_SUP();
REQUIRE_MOMENT();
REQUIRE_IMAGE();
SPITREQUIRE("js/show-image.js");
AddTemplateList(array("show-image", "oops-modal", "waitwait-modal"));
SPITFOOTER();

?>
