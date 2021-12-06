<?php
#
# Copyright (c) 2006, 2007 University of Utah and the Flux Group.
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
$reqargs  = RequiredPageArguments("experiment", PAGEARG_EXPERIMENT);
$optargs  = OptionalPageArguments("action", PAGEARG_STRING);

if (!isset($action) || $action == "tag" || $action == "commit") {
    $action    = "commit";
}

#
# Verify Permission.
#
if (! $experiment->AccessCheck($this_user, $TB_EXPT_MODIFY)) {
    USERERROR("You do not have permission to view experiment $eid!", 1);
}

# Group to suexc as.
$pid = $experiment->pid();
$gid = $experiment->gid();

if ($action == "commit") {
    SUEXEC($uid, "$pid,$gid",
	   "webarchive_control commit $pid $eid",
	   SUEXEC_ACTION_DIE);

    $newurl = preg_replace("/archive_control/",
			   "archive_view", $_SERVER['REQUEST_URI']);

    header("Location: $newurl");
    exit(0);
}

?>
