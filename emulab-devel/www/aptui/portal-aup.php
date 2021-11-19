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
chdir("apt");
include("quickvm_sup.php");
$page_title = "AUP";

#
# Only POWDER.
#
$AUPURL = "https://www.powderwireless.net/powder/templates/powder-aup-20.md";

#
# Get current user.
#
RedirectSecure();
$this_user = CheckLoginOrRedirect();
$optargs = OptionalPageArguments("referrer", PAGEARG_URL);

SPITHEADER(1);

echo "<div id='main-body'></div>\n";

echo "<script type='text/javascript'>\n";
echo "    window.AUPURL = '$AUPURL';\n";
if ($referrer) {
    #$referrer = CleanString($referrer);
    echo "    window.REFERRER = '$referrer';\n";
}
echo "</script>\n";
echo "<script src='js/lib/jquery-2.0.3.min.js'></script>\n";

REQUIRE_UNDERSCORE();
REQUIRE_MARKED();
REQUIRE_SUP();
AddTemplateList(array("aup"));
SPITREQUIRE("js/aup.js");

SPITFOOTER();
?>
