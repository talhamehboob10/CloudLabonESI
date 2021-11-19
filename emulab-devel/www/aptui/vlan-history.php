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
include_once("geni_defs.php");
chdir("apt");
include("quickvm_sup.php");
$page_title = "Vlan History";

#
# Get current user.
#
RedirectSecure();
$this_user = CheckLoginOrRedirect();
$isadmin   = (ISADMIN() ? 1 : 0);
$isfadmin  = (ISFOREIGN_ADMIN() ? 1 : 0);

if (! (ISADMIN() || ISFOREIGN_ADMIN())) {
    SPITUSERERROR("You do not have permission to view this page");
}
SPITHEADER(1);

echo "<div id='page-body'>
        <div id='history-div'></div>
        <div id='waitwait-div'></div>
        <div id='oops-div'></div>
      </div>\n";

echo "<script type='text/javascript'>\n";
echo "    window.ISADMIN    = $isadmin;\n";
echo "    window.ISFADMIN   = $isfadmin;\n";
echo "</script>\n";

REQUIRE_UNDERSCORE();
REQUIRE_SUP();
REQUIRE_MOMENT();
REQUIRE_TABLESORTER();
SPITREQUIRE("js/vlan-history");

AddTemplateList(array("vlan-history", "waitwait-modal", "oops-modal"));
SPITFOOTER();
?>
