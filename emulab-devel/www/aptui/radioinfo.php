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
chdir("apt");
include("quickvm_sup.php");
include_once("aggregate_defs.php");
$page_title = "Radio Info";

#
# Get current user.
#
RedirectSecure();
$this_user = CheckLogin($check_status);
$isadmin   = 0;
# Operate as a guest user if not logged in,
if (! ($check_status & CHECKLOGIN_LOGGEDIN)) {
    $this_user = null;
}
elseif (ISADMIN()) {
    $isadmin = 1;
}

SPITHEADER(1);

# Place to hang the toplevel template.
echo "<div id='main-body'></div>\n";

# Place to hang the modals for now
echo "<div id='oops_div'></div>
      <div id='waitwait_div'></div>\n";

$aggregates = Aggregate::AllAggregatesList();

foreach ($aggregates as $aggregate) {
    $aggregate_urn = $aggregate->urn();
    $weburl        = $aggregate->weburl();

    $blob[$aggregate_urn] =
        array("weburl"       => $weburl,
              "name"         => $aggregate->name(),
              "nickname"     => $aggregate->nickname(),
              "abbreviation" => $aggregate->abbreviation(),
              "isME"         => $aggregate->ismobile(),
              "isFE"         => $aggregate->isFE());
}
echo "<script type='text/plain' id='amlist-json'>\n";
echo json_encode($blob, JSON_HEX_APOS|JSON_HEX_QUOT|JSON_HEX_TAG|JSON_HEX_AMP);
echo "</script>\n";

$radioinfo = Aggregate::RadioInfoNew();
echo "<script type='text/plain' id='radioinfo-json'>\n";
echo htmlentities(json_encode($radioinfo, JSON_NUMERIC_CHECK));
echo "</script>\n";

echo "<script type='text/javascript'>\n";
echo "    window.ISADMIN     = $isadmin;\n";
echo "</script>\n";

REQUIRE_UNDERSCORE();
REQUIRE_SUP();
REQUIRE_MOMENT();
REQUIRE_TABLESORTER();
AddTemplateList(array("radioinfo", "waitwait-modal", "oops-modal"));
SPITREQUIRE("js/radioinfo.js");
SPITFOOTER();
?>
