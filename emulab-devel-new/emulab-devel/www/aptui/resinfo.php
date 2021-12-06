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
include_once("instance_defs.php");
include_once("aggregate_defs.php");
$page_title = "Reservation Info";

#
# Get current user.
#
RedirectSecure();
$this_user = CheckLoginOrRedirect();
$isadmin   = (ISADMIN() ? 1 : 0);
$isfadmin  = (ISFOREIGN_ADMIN() ? 1 : 0);

#
# Verify page arguments. Cluster is a domain that we turn into a URN.
#
$optargs = OptionalPageArguments("debug",    PAGEARG_BOOLEAN,
                                 "cluster",  PAGEARG_STRING);

if (isset($cluster)) {
    $aggregate = Aggregate::LookupByNickname($cluster);
    if (!$aggregate) {
        SPITUSERERROR("No such cluster: $cluster");
        exit();
    }
}

SPITHEADER(1);

echo "<link rel='stylesheet'
            href='css/nv.d3.css'>\n";
echo "<link rel='stylesheet'
            href='https://fonts.googleapis.com/css?family=Muli'>\n";
echo "<link rel='stylesheet'
            href='css/visavail.css'>\n";
echo "<link rel='stylesheet'
            href='https://use.fontawesome.com/releases/v5.0.12/css/all.css'>\n";

# Place to hang the toplevel template.
echo "<div id='main-body'></div>\n";

# List of clusters.
if (isset($aggregate)) {
    $ams = array($aggregate);
}
elseif (isset($debug) && $debug) {
    $ams = array(Aggregate::ThisAggregate());
}
else {
    $ams = Aggregate::SupportsReservations($this_user);
}
if (!count($ams)) {
    SPITUSERERROR("No clusters support reservations.");
    exit();
}
$amlist  = array();
while (list($index, $aggregate) = each($ams)) {
    $urn = $aggregate->urn();
    $am  = $aggregate->name();

    # Lets not show mobile nodes on this page.
    if ($aggregate->ismobile()) {
        continue;
    }

    $amlist[$urn] = array("urn"      => $urn,
                          "name"     => $am,
                          "weburl"   => $aggregate->weburl(),
                          "nickname" => $aggregate->nickname(),
                          "typeinfo" => $aggregate->typeinfo,
                          "abbreviation"     => $aggregate->nickname(),
                          "reservable_nodes" => $aggregate->ReservableNodes(),
                          "radiotypes"       => $aggregate->RadioTypes(),
                          "isFE"             => $aggregate->isFE(),
                          "isME"             => $aggregate->ismobile());
}
echo "<script type='text/plain' id='amlist-json'>\n";
echo htmlentities(json_encode($amlist, JSON_NUMERIC_CHECK));
echo "</script>\n";
if ($ISPOWDER) {
    $radioinfo = Aggregate::RadioInfoNew();
    echo "<script type='text/plain' id='radioinfo-json'>\n";
    echo htmlentities(json_encode($radioinfo, JSON_NUMERIC_CHECK));
    echo "</script>\n";
    $matrixinfo = Aggregate::MatrixInfo();
    echo "<script type='text/plain' id='matrixinfo-json'>\n";
    echo htmlentities(json_encode($matrixinfo, JSON_NUMERIC_CHECK));
    echo "</script>\n";
}
echo "<script type='text/javascript'>\n";
echo "   window.ISADMIN   = $isadmin;\n";
echo "   window.EMULABURN = '$DEFAULT_AGGREGATE_URN';\n";
echo "</script>\n";

REQUIRE_UNDERSCORE();
REQUIRE_SUP();
REQUIRE_MOMENT();
REQUIRE_TABLESORTER();
AddLibrary("js/resgraphs.js");
AddTemplateList(array("resinfo", "resinfo-totals", "reservation-graph",
                      "range-list", "oops-modal", "waitwait-modal",
                      "visavail-graph"));
SPITREQUIRE("js/resinfo.js",
            "<script src='js/lib/d3.v3.js'></script>\n".
            "<script src='js/lib/d3.v5.js'></script>\n".
            "<script src='js/lib/nv.d3.js'></script>\n".
            "<script src='js/lib/visavail.js'></script>\n");
SPITFOOTER();
?>
