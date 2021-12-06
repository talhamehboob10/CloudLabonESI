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
chdir("..");
include("defs.php3");

#
# Only known and logged in users can watch LEDs
#
$this_user = CheckLoginOrDie();
$uid       = $this_user->uid();
$isadmin   = ISADMIN();

#
# When called from the applet, the variable "fromapplet" will be set.
# In that case, spit back simple text based errors that can go into
# a dialog box.
#
if (isset($_REQUEST("fromapplet"))) {
    $session_interactive  = 0;
    $session_errorhandler = 'handle_error';
}
else {
    PAGEHEADER("Set Robot Destination");
}

#
# Capture script errors in non-interactive case.
#
function handle_error($message, $death)
{
    header("Content-Type: text/plain");
    echo "$message";
    if ($death)
	exit(1);
}

#
# Verify page arguments.
#
$reqargs = RequiredPageArguments("experiment", PAGEARG_EXPERIMENT,
				 "nodelist",   PAGEARG_ARRAY);

#
# Verify Permission.
#
if (!$experiment->AccessCheck($this_user, $TB_EXPT_READINFO)) {
    USERERROR("You do not have permission to access this experiment!", 1);
}

#
# Go through the list and check the args. Bail if any are bad.
# 
while (list ($vname, $pname) = each ($nodelist)) {
    if (!TBvalid_node_id($pname)) {
	USERERROR("Illegal characters in node ID.", 1);
    }
    if (!TBvalid_node_id($vname)) {
	USERERROR("Illegal characters in vname.", 1);
    }
    if (! Node::Lookup($pname)) {
	USERERROR("$node_id is not a valid node name!", 1);
    }
}

#
# Okay, now do it for real ...
#
$pid = $experiment->pid();
$eid = $experiment->eid();

reset($nodelist);
while (list ($vname, $pname) = each ($nodelist)) {
    DBQueryFatal("update virt_nodes set fixed='$pname' ".
		 "where pid='$pid' and eid='$eid' and vname='$vname'");
}

#
# Standard testbed footer
#
if (!isset($fromapplet)) {
    PAGEFOOTER();
}

?>
