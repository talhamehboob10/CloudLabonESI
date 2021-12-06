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
include("defs.php3");
include("lease_defs.php");

#
# Only known and logged in users can end experiments.
#
$this_user = CheckLoginOrDie();
$uid       = $this_user->uid();
$isadmin   = ISADMIN();

#
# Currently, only admin users can do this. Change later.
#
if (! $isadmin) {
    USERERROR("You do not have permission to remove projects", 1);
}

#
# Verify page arguments.
#
$reqargs = RequiredPageArguments("project",   PAGEARG_PROJECT);
$optargs = OptionalPageArguments("canceled",  PAGEARG_BOOLEAN,
				 "confirmed", PAGEARG_BOOLEAN,
				 "confirmed_twice", PAGEARG_BOOLEAN);

# Need these below.
$pid = $project->pid();


#
# Standard Testbed Header
#
PAGEHEADER("Terminating Project and Remove all Trace");

#
# Check to see if there are any active experiments. Abort if there are.
#
if ($project->ExperimentList(0)) {
    USERERROR("Project '$pid' has active experiments.<br>".
	      "You must terminate ".
	      "those experiments before you can remove the project!", 1);
}
# Ditto Leases.
if (Lease::LookupAllByProject($project)) {
    USERERROR("Project '$pid' has active leases.<br>".
	      "You must delete ".
	      "those leases before you can remove the project!", 1);
}

#
# We run this twice. The first time we are checking for a confirmation
# by putting up a form. The next time through the confirmation will be
# set. Or, the user can hit the cancel button, in which case we should
# probably redirect the browser back up a level.
#
if (isset($canceled) && $canceled) {
    echo "<center><h2>
          Project removal canceled!
          </h2></center>\n";
    
    PAGEFOOTER();
    return;
}

if (!isset($confirmed)) {
    echo "<center><h2>
          Are you <b>REALLY</b> sure you want to remove Project '$pid?'
          </h2>\n";

    $url = CreateURL("deleteproject", $project);
    
    echo "<form action='$url' method=\"post\">";
    echo "<b><input type=submit name=confirmed value=Confirm></b>\n";
    echo "<b><input type=submit name=canceled value=Cancel></b>\n";
    echo "</form>\n";
    echo "</center>\n";

    PAGEFOOTER();
    return;
}

if (!isset($confirmed_twice)) {
    echo "<center><h2>
	  Okay, lets be sure.<br>
          Are you <b>REALLY REALLY</b> sure you want to remove Project '$pid?'
          </h2>\n";
    
    $url = CreateURL("deleteproject", $project);
    
    echo "<form action='$url' method=\"post\">";
    echo "<input type=hidden name=confirmed value=Confirm>\n";
    echo "<b><input type=submit name=confirmed_twice value=Confirm></b>\n";
    echo "<b><input type=submit name=canceled value=Cancel></b>\n";
    echo "</form>\n";
    echo "</center>\n";

    PAGEFOOTER();
    return;
}

STARTBUSY("Removing all trace of project '$pid'");
SUEXEC($uid, $TBADMINGROUP, "webrmproj $pid", SUEXEC_ACTION_DIE);
STOPBUSY();

#
# Standard Testbed Footer
# 
PAGEFOOTER();
?>
