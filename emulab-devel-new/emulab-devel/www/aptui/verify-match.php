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
$page_title = "User Match";

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
$optargs = OptionalPageArguments("target_user", PAGEARG_USER,
                                 "referrer",    PAGEARG_URL);

if (! isset($target_user)) {
    $target_user = $this_user;
}
if (!$isadmin && !$target_user->SameUser($this_user)) {
    SPITUSERERROR("You do not have permission to view this information!");
    return;
}

SPITHEADER(1);

echo "<script type='text/javascript'>\n";
echo "  window.ISADMIN     = $isadmin;\n";
echo "  window.TARGET_USER = '" . $target_user->uid() . "';\n";
if ($referrer) {
    #$referrer = CleanString($referrer);
    echo "    window.REFERRER = '$referrer';\n";
}
echo "</script>\n";

# Place to hang the toplevel template.
echo "<div id='main-body'></div>\n";
# Place to hang some modals.
echo "<div id='oops_div'></div>
      <div id='waitwait_div'></div>\n";

REQUIRE_UNDERSCORE();
REQUIRE_TABLESORTER();
REQUIRE_SUP();
REQUIRE_MOMENT();
SPITREQUIRE("js/verify-match.js");

AddTemplateList(array("verify-match", "oops-modal", "waitwait-modal"));
SPITFOOTER();
?>
