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
include("webtask.php");
chdir("apt");
include("quickvm_sup.php");
$page_title = "List Reservations";

#
# Get current user.
#
RedirectSecure();
$this_user = CheckLoginOrRedirect();
$this_uid  = $this_user->uid();
$isadmin   = (ISADMIN() ? 1 : 0);

#
# Verify page arguments. Cluster is a domain that we turn into a URN.
#
$optargs = OptionalPageArguments("cluster", PAGEARG_STRING,
                                 "force"  , PAGEARG_BOOLEAN);

if (!$force || !($isadmin || $this_user->admin() || $this_user->stud())) {
    header("Location: list-resgroups.php");
    return;
}
SPITHEADER(1);

$amlist = array();

if (isset($cluster)) {
    if (!preg_match("/^[\w\.]+$/", $cluster)) {
        PAGEARGERROR("Invalid cluster argument");
        exit();
    }
    $aggregate = Aggregate::LookupByNickname($cluster);
    if (!$aggregate) {
        SPITUSERERROR("No such cluster");
        exit();
    }    
    $amlist[$aggregate->nickname()] = $aggregate->urn();
}
else {
    # List of clusters.
    $ams     = Aggregate::SupportsReservations();
    $amlist  = array();
    while (list($index, $aggregate) = each($ams)) {
        $amlist[$aggregate->nickname()] = $aggregate->urn();
    }
}
if (!count($amlist)) {
    SPITUSERERROR("No clusters support reservations.");
    exit();
}
echo "<script type='text/plain' id='amlist-json'>\n";
echo htmlentities(json_encode($amlist));
echo "</script>\n";

echo "<link rel='stylesheet'
            href='css/nv.d3.css'>\n";

# Place to hang the toplevel template.
echo "<div id='main-body'></div>\n";

echo "<script type='text/javascript'>\n";
echo "   window.ISADMIN  = $isadmin;\n";
echo "</script>\n";

REQUIRE_UNDERSCORE();
REQUIRE_SUP();
REQUIRE_MOMENT();
REQUIRE_TABLESORTER();
AddLibrary("js/resgraphs.js");
AddTemplateList(array("list-reservations", "reservation-list",
                      "prereservation-list",
                      "confirm-modal", "resusage-list", "resusage-graph",
                      "oops-modal", "waitwait-modal"));
SPITREQUIRE("js/list-reservations.js",
            "<script src='js/lib/d3.v3.js'></script>\n".
            "<script src='js/lib/nv.d3.js'></script>\n");
SPITFOOTER();
?>
