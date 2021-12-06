<?php
#
# Copyright (c) 2000-2014 University of Utah and the Flux Group.
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
$page_title = "Approve User";

#
# Get current user in case we need an error message.
#
RedirectSecure();
$this_user = CheckLoginOrRedirect();

#
# Verify page arguments.
#
$optargs = RequiredPageArguments("action",      PAGEARG_STRING,
				 "project",     PAGEARG_PROJECT,
				 "user",        PAGEARG_USER);

#
# The user must be logged in.
#
if (!$this_user) {
    RedirectLoginPage();
    exit();
}
$this_idx = $this_user->uid_idx();
$this_uid = $this_user->uid();
$user_uid = $user->uid();
$pid      = $project->pid();

SPITHEADER(1);
SpitWaitModal("waitwait-modal");
SpitOopsModal("oops");
echo "<div id='page-body'></div>\n";

if ($action != "approve" && $action != "deny") {
    SPITUSERERROR("Action is not one of approve or deny");
    return;
}

#
# Check that the current user has the necessary trust level
# to approver users in the project/group.
#
if (! $project->AccessCheck($this_user, $TB_PROJECT_ADDUSER)) {
    SPITUSERERROR("You are not allowed to approve users in this project");
    return;
}

#
# Must be an unapproved member ...
#
$approved = 0;
if (! $project->IsMember($user, $approved)) {
    SPITUSERERROR("User $user_uid is not a member of project $pid");
    return;
}

if ($approved) {
    SPITUSERERROR("User $user_uid is already an approved ".
		  "member of project $pid");
    return;
}

echo "<script type='text/javascript'>\n";
echo "    window.ACTION  = '$action';\n";
echo "    window.USER    = '$user_uid';\n";
echo "    window.PROJECT = '$pid';\n";
echo "    window.AJAXURL = 'server-ajax.php';\n";
echo "</script>\n";

echo "<script src='js/lib/jquery-2.0.3.min.js'></script>\n";
REQUIRE_SUP();
SPITREQUIRE("js/approveuser.js");

SPITFOOTER();
