<?php
#
# Copyright (c) 2000-2007 University of Utah and the Flux Group.
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
include("defs.php3");

#
# Only known and logged in users.
#
$this_user = CheckLoginOrDie();
$uid       = $this_user->uid();
$isadmin   = ISADMIN();

#
# Verify page arguments.
#
$reqargs = RequiredPageArguments("group", PAGEARG_GROUP);
$optargs = OptionalPageArguments("canceled", PAGEARG_BOOLEAN,
				 "confirmed", PAGEARG_BOOLEAN);

# Needed below.
$pid = $group->pid();
$gid = $group->gid();
$project  = $group->Project();
$unix_gid = $project->unix_gid();
$gid_idx  = $group->gid_idx();

#
# We do not allow the default group to be deleted. Never ever!
#
if ($group->IsProjectGroup()) {
    USERERROR("You are not allowed to delete a project's default group!", 1);
}

#
# Verify permission, for the project not the group
#
if (! $project->AccessCheck($this_user, $TB_PROJECT_DELGROUP)) {
    USERERROR("You do not have permission to delete groups in project $pid!",
	      1);
}

#
# Standard Testbed Header
#
PAGEHEADER("Delete a Group");

#
# Check to see if there are any active experiments. Abort if there are.
#
if ($group->ExperimentList(0)) {
    USERERROR("Project/Group '$pid/$gid' has active experiments.<br> ".
	      "You must terminate ".
	      "those experiments before you can remove the group!", 1);
}

#
# We run this twice. The first time we are checking for a confirmation
# by putting up a form. The next time through the confirmation will be
# set. Or, the user can hit the cancel button, in which case we should
# probably redirect the browser back up a level.
#
if (isset($canceled) && $canceled) {
    echo "<center><h2>
          Group removal canceled!
          </h2></center>\n";
    
    PAGEFOOTER();
    return;
}

if (!isset($confirmed)) {
    echo "<center><h2>
          Are you <b>REALLY</b> sure you want to remove Group $gid
          in Project $pid?
          </h2>\n";

    $url = CreateURL("deletegroup", $group);
    
    echo "<form action='$url' method=post>";
    echo "<b><input type=submit name=confirmed value=Confirm></b>\n";
    echo "<b><input type=submit name=canceled value=Cancel></b>\n";
    echo "</form>\n";
    echo "</center>\n";

    PAGEFOOTER();
    return;
}

STARTBUSY("Group '$gid' in project '$pid' is being removed!");

#
# Run the script. They will remove the group directory and the unix group,
# and the DB state.
#
SUEXEC($uid, $unix_gid, "webrmgroup $gid_idx", SUEXEC_ACTION_DIE);
STOPBUSY();

PAGEREPLACE(CreateURL("showproject", $project));

#
# Standard Testbed Footer
# 
PAGEFOOTER();
?>
