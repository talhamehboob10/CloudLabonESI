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
include("profile_defs.php");
$page_title = "Profile Paramsets";

#
# Verify page arguments.
#
$reqargs = RequiredPageArguments("uuid",  PAGEARG_UUID);

#
# Get current user.
#
RedirectSecure();
$this_user = CheckLoginOrRedirect();
$this_idx  = $this_user->uid_idx();

SPITHEADER(1);

$profile = Profile::Lookup($uuid);
if (!$profile) {
    SPITUSERERROR("No such profile!");
}
else if (! ($profile->CanView($this_user) || ISADMIN())) {
    SPITUSERERROR("Not enough permission!");
}
$profile_pid = $profile->pid();
$profile_name = $profile->name();

# Place to hang the toplevel template.
echo "<div id='page-body'></div>\n";

echo "<script type='text/javascript'>\n";
echo "    window.PROFILE_UUID = '$uuid';\n";
echo "    window.PROFILE_PID = '$profile_pid';\n";
echo "    window.PROFILE_NAME = '$profile_name';\n";
echo "    window.ISADMIN  = " . (ISADMIN() ? "true" : "false") . ";\n";
echo "</script>\n";

REQUIRE_UNDERSCORE();
REQUIRE_SUP();
REQUIRE_MOMENT();
REQUIRE_TABLESORTER();
SPITREQUIRE("js/profile-paramsets.js");
AddTemplate("profile-paramsets");
AddTemplate("paramsets-list");
SPITFOOTER();
?>
