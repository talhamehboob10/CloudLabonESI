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
$page_title = "Show Node History";

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
$reqargs = OptionalPageArguments("node_id", PAGEARG_STRING,
                                 "IP",      PAGEARG_STRING);

if (! ($isadmin || OPSGUY())) {
    SPITUSERERROR("Not enough permission!");
}

SPITHEADER(1);

# Place to hang the toplevel template.
echo "<div class=row>
        <div id='main-body'></div>
      </div>\n";

echo "<script type='text/javascript'>\n";
if (isset($node_id)) {
    echo "    window.TARGET       = '$node_id';\n";
}
elseif (isset($IP)) {
    echo "    window.TARGET       = '$IP';\n";
}
echo "    window.ISADMIN      = $isadmin;\n";
echo "</script>\n";

REQUIRE_UNDERSCORE();
REQUIRE_SUP();
REQUIRE_MOMENT();
REQUIRE_TABLESORTER();
SPITREQUIRE("js/show-nodehistory.js");
AddTemplateList(array("show-nodehistory", "nodehistory-list",
                      "oops-modal", "waitwait-modal"));
SPITFOOTER();

?>
