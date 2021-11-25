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
# Must be after quickvm_sup.php since it changes the auth domain.
$page_title = "User Dashboard";

#
# Get current user.
#
RedirectSecure();
$this_user = CheckLoginOrRedirect();
$this_idx  = $this_user->uid_idx();
$this_uid  = $this_user->uid();
$isadmin   = (ISADMIN() ? 1 : 0);

#
# Verify page arguments.
#
$optargs = OptionalPageArguments("target_user", PAGEARG_USER);

if (! isset($target_user)) {
    $target_user = $this_user;
}
#
# Verify that this uid is a member of one of the projects that the
# target_uid is in. Must have proper permission in that group too. 
#
if (!$isadmin && !ISFOREIGN_ADMIN() &&
    !$target_user->AccessCheck($this_user, $TB_USERINFO_READINFO)) {
    SPITUSERERROR("You do not have permission to view this information!");
    return;
}
$emulablink = "$TBBASE/showuser.php3?user=" . $target_user->uid();

SPITHEADER(1);

echo "<script type='text/javascript'>\n";
echo "  window.ISADMIN     = $isadmin;\n";
echo "  window.EMULAB_LINK = '$emulablink';\n";
echo "  window.TARGET_USER = '" . $target_user->uid() . "';\n";
echo "  window.UI_DISABLE_DATASETS = '" . $UI_DISABLE_DATASETS . "';\n";
echo "  window.UI_DISABLE_RESERVATIONS = '" .
        $UI_DISABLE_RESERVATIONS . "';\n";
echo "  window.EMBEDDED_RESGROUPS = true;\n";
echo "  window.EMBEDDED_RESGROUPS_SELECT = false;\n";
echo "</script>\n";

# Place to hang the toplevel template.
echo "<div id='main-body'></div>\n";

REQUIRE_UNDERSCORE();
REQUIRE_SUP();
REQUIRE_MOMENT();
REQUIRE_TABLESORTER();
REQUIRE_JACKS();
AddLibrary("js/paramsets.js");
AddLibrary("js/list-resgroups.js");
AddLibrary("js/profile-support.js");
AddTemplateList(array('confirm-delete-profile', 'profile-list-modal'));
SPITREQUIRE("js/user-dashboard.js");

AddTemplateList(array("user-dashboard", "experiment-list", "profile-list", "project-list", "dataset-list", "user-profile", "oops-modal", "waitwait-modal", "classic-explist", "conversion-help-modal", "paramsets-list", "resgroup-list"));
SPITFOOTER();
?>
