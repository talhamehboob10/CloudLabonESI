<?php
#
# Copyright (c) 2000-2017 University of Utah and the Flux Group.
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
include_once("template_defs.php");

#
# Note the difference with which this page gets it arguments!
# I invoke it using GET arguments, so uid and pid are are defined
# without having to find them in URI (like most of the other pages
# find the uid).
#

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
$project = $group->Project();
$pid     = $group->pid();
$gid     = $group->gid();

#
# Standard Testbed Header
#
PAGEHEADER("Group $pid/$gid");

#
# Verify permission to look at the group. This is a little different,
# since the standard test would look for permission in just the group,
# but we also want to allow users from the project with appropriate
# privs to look at the group.
#
if (! ($group->AccessCheck($this_user, $TB_PROJECT_READINFO) ||
       $project->AccessCheck($this_user, $TB_PROJECT_EDITGROUP))) {
    USERERROR("You do not have permission to view ".
	      "group $gid in project $pid!", 1);
}

#
# This menu only makes sense for people with privs to use them.
#
$showmenu = ($group->AccessCheck($this_user, $TB_PROJECT_EDITGROUP) ||
	     (! $group->IsProjectGroup() &&
	      $project->AccessCheck($this_user, $TB_PROJECT_DELGROUP)));

if ($showmenu) {
    SUBPAGESTART();
    SUBMENUSTART("Group Options");

    if ($group->AccessCheck($this_user, $TB_PROJECT_EDITGROUP)) {
	WRITESUBMENUBUTTON("Edit this Group",
			   "editgroup.php3?pid=$pid&gid=$gid");
    }

    #
    # A delete option, but not for the default group!
    #
    if (! $group->IsProjectGroup() &&
	  $project->AccessCheck($this_user, $TB_PROJECT_DELGROUP)) {
	WRITESUBMENUBUTTON("Delete this Group",
			   "deletegroup.php3?pid=$pid&gid=$gid");
    }
    SUBMENUEND();
}

$group->Show();
$group->ShowMembers($this_user);

if ($showmenu) {
    SUBPAGEEND();
}

# Project wide Templates.
if ($EXPOSETEMPLATES) {
    SHOWTEMPLATELIST("GROUP", 0, $uid, $pid, $gid);
}

#
# A list of Group experiments.
#
ShowExperimentList("GROUP", $this_user, $group);

if ($isadmin) {
    echo "<center>
          <h3>Group Stats</h3>
         </center>\n";

    $group->ShowStats();
}

#
# Standard Testbed Footer
# 
PAGEFOOTER();
?>
