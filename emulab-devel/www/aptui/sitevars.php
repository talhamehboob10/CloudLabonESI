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
include_once("geni_defs.php");
chdir("apt");
include("quickvm_sup.php");
$page_title = "Site Variables";

#
# Get current user.
#
RedirectSecure();
$this_user = CheckLoginOrRedirect();
$isadmin   = (ISADMIN() ? 1 : 0);

if (!ISADMIN()) {
    SPITUSERERROR("You do not have permission to view this page");
}
SPITHEADER(1);

echo "<div>
       <div id='page-body'></div>
       <div id='waitwait_div'></div>
       <div id='oops_div'></div>
       <div id='confirm_div'></div>
      </div>\n";

echo "<script type='text/javascript'>\n";
echo "    window.ISADMIN    = $isadmin;\n";
echo "</script>\n";

REQUIRE_UNDERSCORE();
REQUIRE_SUP();
REQUIRE_MOMENT();
REQUIRE_TABLESORTER(array('js/lib/tablesorter/widget-stickyHeaders.js'));
SPITREQUIRE("js/sitevars.js");

AddTemplateList(array("sitevars", "waitwait-modal", "oops-modal",
                      "confirm-something"));
SPITFOOTER();
?>
