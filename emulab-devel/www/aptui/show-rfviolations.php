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
include("node_defs.php");
chdir("apt");
include("quickvm_sup.php");
# Must be after quickvm_sup.php since it changes the auth domain.
$page_title = "RF Violations";

#
# Get current user.
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
$reqargs = RequiredPageArguments("node",  PAGEARG_NODE);

if (!$node) {
    SPITUSERERROR("No such node!");
}
$node_id = $node->node_id();
$experiment = $node->Reservation();

SPITHEADER(1);

# Place to hang the toplevel template.
echo "<div id='main-body'></div>\n";

echo "<link rel='stylesheet'
            href='css/jquery-ui.min.css'>\n";

echo "<script type='text/javascript'>\n";
echo "    window.NODE_ID        = '$node_id';\n";
echo "    window.ISADMIN        = " . (ISADMIN() ? "true" : "false") . "\n";
echo "    window.ISGUEST        = " . ($this_user ? "false" : "true") . ";\n";
if ($experiment) {
    echo "    window.NODE_VNAME     = '" . $node->VirtName() . "';\n";
}
echo "</script>\n";

REQUIRE_UNDERSCORE();
REQUIRE_SUP();
REQUIRE_MOMENT();
REQUIRE_TABLESORTER();
SPITREQUIRE("js/show-rfviolations.js");
AddTemplateList(array("show-rfviolations", "oops-modal", "waitwait-modal"));
SPITFOOTER();

?>
