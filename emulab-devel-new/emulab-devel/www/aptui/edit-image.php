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
include("imageid_defs.php");
chdir("apt");
include("quickvm_sup.php");
# Must be after quickvm_sup.php since it changes the auth domain.
$page_title = "Show Image";

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
$reqargs = RequiredPageArguments("image",       PAGEARG_IMAGE);
$optargs = OptionalPageArguments("edit",        PAGEARG_BOOLEAN,
				 "formfields",  PAGEARG_ARRAY);

if (!$image) {
    SPITUSERERROR("No such image!");
}
if (!$image->AccessCheck($this_user, $TB_IMAGEID_MODIFYINFO)) {
    SPITUSERERROR("Not enough permission!");
}
$uuid = $image->uuid();

if ($edit) {
    $action = "edit";
}
else {
    $action = "view";
}

SPITHEADER(1);

# Place to hang the toplevel template.
echo "<div id='main-body'></div>\n";

echo "<link rel='stylesheet'
            href='css/jquery-ui.min.css'>\n";

echo "<script type='text/javascript'>\n";
echo "    window.UUID     = '$uuid';\n";
echo "    window.ACTION   = '$action';\n";
echo "    window.ISADMIN  = $isadmin;\n";
echo "</script>\n";

REQUIRE_UNDERSCORE();
REQUIRE_SUP();
REQUIRE_MOMENT();
REQUIRE_APTFORMS();
SPITREQUIRE("js/create-image.js");
AddTemplateList(array("create-image",
                      "oops-modal", "waitwait-modal"));
SPITFOOTER();

?>
