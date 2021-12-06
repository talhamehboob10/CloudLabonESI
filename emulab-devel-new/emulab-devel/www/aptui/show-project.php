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
$page_title = "Show Project";

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
$reqargs = RequiredPageArguments("project", PAGEARG_PROJECT);

SPITHEADER(1);

if (!ISADMIN() && !ISFOREIGN_ADMIN() &&
    !$project->AccessCheck($this_user, $TB_PROJECT_READINFO)) {
    SPITUSERERROR("You do not have permission to view this information!");
    return;
}
$emulablink = "$TBBASE/showproject.php3?project=" . $project->pid();
$canapprove = $project->AccessCheck($this_user, $TB_PROJECT_ADDUSER) ? 1 : 0;
$canbestow  = $project->AccessCheck($this_user,
                                    $TB_PROJECT_BESTOWGROUPROOT) ? 1 : 0;
$isleader   = $project->IsLeader($this_user);
$ismanager  = $project->IsManager($this_user);

echo "<script type='text/javascript'>\n";
echo "  window.ISADMIN        = $isadmin;\n";
echo "  window.ISLEADER       = $isleader;\n";
echo "  window.ISMANAGER      = $ismanager;\n";
echo "  window.CANAPPROVE     = $canapprove;\n";
echo "  window.CANBESTOW      = $canbestow;\n";
echo "  window.EMULAB_LINK    = '$emulablink';\n";
echo "  window.TARGET_PROJECT = '" . $project->pid() . "';\n";
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
REQUIRE_MARKED();
REQUIRE_MOMENT();
REQUIRE_TABLESORTER();
REQUIRE_JACKS();
AddLibrary("js/list-resgroups.js");
AddLibrary("js/profile-support.js");
AddTemplateList(array('confirm-delete-profile', 'profile-list-modal'));
SPITREQUIRE("js/show-project.js");

AddTemplateList(array("show-project", "experiment-list", "profile-list", "member-list", "dataset-list", "project-profile", "classic-explist", "group-list", "waitwait-modal", "oops-modal", "conversion-help-modal", "resgroup-list"));
SPITFOOTER();
?>
