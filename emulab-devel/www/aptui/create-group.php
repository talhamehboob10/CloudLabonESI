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
$page_title = "Create Group";

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
$optargs = OptionalPageArguments("leader",  PAGEARG_USER);

if (!$project->AccessCheck($this_user, $TB_PROJECT_MAKEGROUP)) {
    SPITUSERERROR("You do not have permission to create groups in ".
                  "project " . $project->pid());
}
if (isset($leader)) {
    $isapproved = 0;
    if (! ($project->IsMember($leader, $isapproved) && $isapproved)) {
        SPITUSERERROR($leader->uid(). " is not a member of project " .
                      $project->uid());
    }
}

SPITHEADER(1);

# Place to hang the toplevel template.
echo "<div id='main-body'></div>\n";

# Initial form contents.
$formfields = array();
$formfields["project"]      = $project->pid();
$formfields["group_id"]     = "";
$formfields["group_leader"] = (isset($leader) ? $leader->uid() : $this_uid);
$formfields["group_description"] = "";

#
# Drop down of all members of the group.
#
$members = array();
foreach ($project->MemberList() as $user) {
    $members[$user->uid_idx()] = $user->uid();
}

echo "<script type='text/plain' id='form-json'>\n";
echo htmlentities(json_encode($formfields)) . "\n";
echo "</script>\n";
echo "<script type='text/plain' id='members-json'>\n";
echo htmlentities(json_encode($members)) . "\n";
echo "</script>\n";

echo "<script type='text/javascript'>\n";
echo "    window.ISADMIN  = $isadmin;\n";
echo "</script>\n";

REQUIRE_UNDERSCORE();
REQUIRE_SUP();
REQUIRE_MOMENT();
REQUIRE_APTFORMS();
SPITREQUIRE("js/create-group.js");

AddTemplateList(array("create-group", "oops-modal", "waitwait-modal"));
SPITFOOTER();

?>
