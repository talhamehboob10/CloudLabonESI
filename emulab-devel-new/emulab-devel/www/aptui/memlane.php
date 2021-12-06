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
$page_title = "Experiment Record";

#
# Get current user.
#
$this_user = CheckLogin($check_status);
if (isset($this_user)) {
    CheckLoginOrDie();
}
else {
    RedirectLoginPage();
}
#
# We do not set the isfadmin flag if the user has normal permission
# to see this experiment, since that would change what the user sees.
# Okay for real admins, but not for foreign admins.
#
$isfadmin = (ISFOREIGN_ADMIN() ? 1 : 0);
$isadmin  = (ISADMIN() ? 1 : 0);

#
# Verify page arguments.
#
$reqargs = OptionalPageArguments("slice_uuid", PAGEARG_UUID,
                                 "uuid",       PAGEARG_UUID);

if (! (isset($slice_uuid) || isset($uuid))) {
    SPITHEADER(1);
    echo "<div class='align-center'>
            <p class='lead text-center'>
              What experiment record would you like to look at?
            </p>
          </div>\n";
    SPITNULLREQUIRE();
    SPITFOOTER();
    return;
}

#
# See if the record exists. 
#
if (isset($uuid)) {
    $record = InstanceHistory::Lookup($uuid);
}
else {
    $record = InstanceHistory::LookupbySlice($slice_uuid);
}
if (!$record) {
    SPITHEADER(1);
    echo "<div class='align-center'>
            <p class='lead text-center'>
              Experiment record does not exist. 
            </p>
          </div>\n";
    SPITNULLREQUIRE();
    SPITFOOTER();
    return;
}
$uuid = $record->uuid();

if (! (ISADMIN() || ISFOREIGN_ADMIN() || $record->CanView($this_user))) {
    PAGEERROR("You do not have permission to look at this experiment!");
}

if ($TBMAINSITE && $record->servername() != $_SERVER['SERVER_NAME']) {
    if ($record->servername() == "www.aptlab.net") {
        $url = "https://www.aptlab.net";
    }
    elseif ($record->servername() == "www.cloudlab.us") {
        $url = "https://www.cloudlab.us";
    }
    elseif ($record->servername() == "www.phantomnet.org") {
        $url = "https://www.phantomnet.org";
    }
    elseif ($record->servername() == "www.powderwireless.net") {
        $url = "https://www.powderwireless.net";
    }
    if (isset($url)) {
        $url = $url . str_replace("/portal/", "/", $_SERVER['REQUEST_URI']);
	header("Location: $url");
        return;
    }
}

SPITHEADER(1);


# Place to hang the toplevel template.
echo "<div id='page-body'>
        <center>
          <h4>
	  Please wait while we retrieve the data for this instance.
          </h4>
	  <br>
	  <br>
	  <img src='images/spinner.gif' />
	</center>
        </div>\n";

#
# Build up a blob of aggregates info used by this experiment.
#
$blob = array();
foreach ($record->slivers as $sliver) {
    $aggregate_urn = $sliver["aggregate_urn"];
    $aggregate     = Aggregate::Lookup($aggregate_urn);
    $weburl        = $aggregate->weburl();

    $blob[$aggregate_urn] = array("weburl" => $weburl,
                                  "name"   => $aggregate->name());
}
echo "<script type='text/plain' id='amlist-json'>\n";
echo json_encode($blob, JSON_HEX_APOS|JSON_HEX_QUOT|JSON_HEX_TAG|JSON_HEX_AMP);
echo "</script>\n";

echo "<script type='text/javascript'>\n";
echo "  window.uuid = '" . $uuid . "';\n";
echo "  window.isadmin = $isadmin;\n";
echo "  window.isfadmin = $isfadmin;\n";
echo "</script>\n";
echo "<script src='js/lib/d3.v3.js'></script>\n";
echo "<script src='js/lib/jquery-2.0.3.min.js'></script>\n";
echo "<script src='js/lib/jquery-ui.js'></script>\n";
echo "<script src='js/lib/codemirror-min.js'></script>\n";

REQUIRE_UNDERSCORE();
REQUIRE_SUP();
REQUIRE_JACKS();
REQUIRE_MOMENT();
REQUIRE_MARKED();
REQUIRE_URITEMPLATE();
AddLibrary("js/bindings.js");
AddLibrary("js/paramsets.js");
SPITREQUIRE("js/memlane.js");

echo "<link rel='stylesheet'
            href='css/jquery-ui-1.10.4.custom.min.css'>\n";
echo "<link rel='stylesheet' href='css/codemirror.css'>\n";

AddTemplateList(array("memlane", "waitwait-modal", "oops-modal",
                      "save-paramset-modal"));

SPITFOOTER();
?>
