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
$page_title = "Show Hardware";

#a
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
$reqargs = OptionalPageArguments("type",     PAGEARG_STRING,
                                 "typelist", PAGEARG_STRING,
                                 "node",     PAGEARG_NODE);

if (isset($type)) {
    if (!TBvalid_node_type($type)) {
        SPITUSERERROR("$type contains illegal characters!");
    }
    $query_result =
        DBQueryFatal("select type from node_types where type='$type'");
    if (!mysql_num_rows($query_result)) {
        SPITUSERERROR("No such node type");
    }
}
elseif (isset($typelist)) {
    foreach (preg_split("/,/", $typelist) as $t) {
        if (!TBvalid_node_type($t)) {
            SPITUSERERROR("$t contains illegal characters!");
        }
        $query_result =
            DBQueryFatal("select type from node_types where type='$t'");
        if (!mysql_num_rows($query_result)) {
            SPITUSERERROR("No such node type $t");
        }
    }
}
elseif (!isset($node)) {
    SPITUSERERROR("Must provide a node type or node ID");
}

SPITHEADER(1);

#
# XXX Need to incorporate this ...
#
echo "<link rel='stylesheet' href='css/jstree.css'>\n";
echo "<script src='js/lib/jstree.js'></script>\n";

# Place to hang the toplevel template.
echo "<div id='main-body'></div>\n";

echo "<script type='text/javascript'>\n";
echo "    window.ISADMIN   = " . (ISADMIN() ? "true" : "false") . ";\n";
echo "    window.ISGUEST   = " . ($this_user ? "false" : "true") . ";\n";
if (isset($node)) {
    echo "    window.NODEID    = '" . $node->node_id() . "';\n";
}
elseif (isset($typelist)) {
    echo "    window.TYPELIST  = '$typelist';\n";
}
else {
    echo "    window.TYPE      = '$type';\n";
}
echo "</script>\n";

REQUIRE_UNDERSCORE();
REQUIRE_SUP();
REQUIRE_MOMENT();
SPITREQUIRE("js/show-hardware.js");
AddTemplateList(array("show-hardware", "oops-modal", "waitwait-modal"));
SPITFOOTER();

?>
