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
include("node_defs.php");
chdir("apt");
include("quickvm_sup.php");
# Must be after quickvm_sup.php since it changes the auth domain.
$page_title = "POWDER Map";

#
# Get current user.
#
RedirectSecure();
$this_user = CheckLogin($check_status);
# Operate as a guest user if not logged in,
if (! ($check_status & CHECKLOGIN_LOGGEDIN)) {
    $this_user = null;
}

$showfilter    = 1;
$showlegend    = 1;
$showavailable = ($this_user ? 1 : 0);
$showreserved  = ($this_user ? 1 : 0);
$showmobile    = ($this_user ? 1 : 0);

# Optional views
$optargs = OptionalPageArguments("baseonly",   PAGEARG_BOOLEAN,
                                 "experiment", PAGEARG_UUID,
                                 "nomobile",   PAGEARG_BOOLEAN,
                                 "showlinks",  PAGEARG_STRING,
                                 "location",   PAGEARG_STRING,
                                 "route",      PAGEARG_STRING);

if ($experiment) {
    $baseonly   = 0;
    $showfilter = $showreserved = 0;
    $showlegend = 1;
    $showmobile = 1;
}
elseif ($baseonly) {
    $baseonly   = 1;
    $showlegend = $showmobile = $showreserved = 0;
}
else {
    $baseonly   = 0;
}
if ($nomobile) {
    $showmobile = 0;
}
if (!isset($showlinks)) {
    $showlinks = "null";
}
else {
    $showlinks = "'$showlinks'";
}
SPITHEADER(1);

echo '<link rel="stylesheet"
            href="https://js.arcgis.com/4.14/esri/themes/light/main.css">';

# Place to hang the toplevel template.
echo "<div id='main-body'></div>\n";

echo "<script type='text/javascript'>\n";
echo "window.SHOWFILTER    = $showfilter;\n";
echo "window.SHOWLEGEND    = $showlegend;\n";
echo "window.SHOWAVAILABLE = $showavailable;\n";
echo "window.SHOWRESERVED  = $showreserved;\n";
echo "window.SHOWMOBILE    = $showmobile;\n";
echo "window.SHOWLINKS     = $showlinks;\n";
echo "window.BASEONLY      = $baseonly;\n";
if ($experiment) {
    echo "window.EXPERIMENT = '$experiment';\n";
}
if ($location) {
    echo "window.LOCATION   = '$location';\n";
}
if ($route) {
    echo "window.ROUTE   = '$route';\n";
}
echo "</script>\n";

REQUIRE_UNDERSCORE();
AddLibrary("js/quickvm_sup.js");
REQUIRE_MOMENT();
AddLibrary("js/lib/jquery.csv.js");
AddLibrary("js/powder-map-support.js");
SPITREQUIRE("js/powder-map.js",
            "<script src='https://js.arcgis.com/4.14/'></script>");

AddTemplateList(array("powder-map", "powder-filters"));
SPITFOOTER();

?>
