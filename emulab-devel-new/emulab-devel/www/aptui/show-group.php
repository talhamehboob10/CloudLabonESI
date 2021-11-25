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
# Must be after quickvm_sup.php since it changes the auth domain.
$page_title = "Show Group";

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
$optargs = RequiredPageArguments("group", PAGEARG_GROUP);

SPITHEADER(1);

if (!ISADMIN() && !ISFOREIGN_ADMIN() &&
    !$group->AccessCheck($this_user, $TB_PROJECT_READINFO)) {
    SPITUSERERROR("You do not have permission to view this information!");
    return;
}
$emulablink = "$TBBASE/showgroup.php3?group=" . $group->gid_idx();
$canapprove = $group->AccessCheck($this_user, $TB_PROJECT_ADDUSER) ? 1 : 0;
$candelete  = $group->AccessCheck($this_user, $TB_PROJECT_DELGROUP) ? 1 : 0;
$canedit    = $group->AccessCheck($this_user, $TB_PROJECT_EDITGROUP) ? 1 : 0;
$canbestow  = $group->AccessCheck($this_user,
                                  $TB_PROJECT_BESTOWGROUPROOT) ? 1 : 0;
# Never allowed to delete project group.
if ($group->pid() == $group->gid()) {
    $candelete = 0;
}

echo "<link rel='stylesheet'
            href='css/jquery.smartmenus.bootstrap.css'>\n";

echo "<script type='text/javascript'>\n";
echo "  window.ISADMIN        = $isadmin;\n";
echo "  window.CANAPPROVE     = $canapprove;\n";
echo "  window.CANDELETE      = $candelete;\n";
echo "  window.CANEDIT        = $canedit;\n";
echo "  window.CANBESTOW      = $canbestow;\n";
echo "  window.EMULAB_LINK    = '$emulablink';\n";
echo "  window.TARGET_PROJECT = '" . $group->pid() . "';\n";
echo "  window.TARGET_GROUP   = '" . $group->gid() . "';\n";
echo "</script>\n";

# Place to hang the toplevel template.
echo "<div id='main-body'></div>\n";

REQUIRE_UNDERSCORE();
REQUIRE_SUP();
REQUIRE_JACKS();
REQUIRE_MOMENT();
REQUIRE_TABLESORTER();
REQUIRE_APTFORMS();
SPITREQUIRE("js/show-group.js");

AddTemplateList(array("show-group", "experiment-list", "member-list", "group-profile", "classic-explist", "oops-modal", "waitwait-modal"));
SPITFOOTER();
?>
