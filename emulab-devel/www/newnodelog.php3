<?php
#
# Copyright (c) 2000-2010 University of Utah and the Flux Group.
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
include_once("node_defs.php");

#
# Only known and logged in users.
#
$this_user = CheckLoginOrDie();
$uid       = $this_user->uid();
$isadmin   = ISADMIN();

#
# Verify page arguments.
#
$reqargs = RequiredPageArguments("node",      PAGEARG_NODE,
				 "log_type",  PAGEARG_STRING,
				 "log_entry", PAGEARG_ANYTHING);

#
# Only Admins can enter log entries.
#
if (! ($isadmin || OPSGUY())) {
    USERERROR("You do not have permission to enter log entries!", 1);
}

#
# Check log type. Strictly letters, not too long. 
#
if (!preg_match('/^[a-zA-Z]+$/', $log_type) || strlen($log_type) > 32) {
    USERERROR("The log type you gave looks funky!", 1);
}

# Anything allowed, but not too long.
if (! TBvalid_description($log_entry)) {
    USERERROR("Invalid log entry: " . TBFieldErrorString(), 1);
}

$log_type  = escapeshellarg($log_type);
$log_entry = escapeshellarg($log_entry);
$node_id   = $node->node_id();

#
# Standard Testbed Header
#
PAGEHEADER("Enter Node Log Entry");

#
# Run the external script. 
#
SUEXEC($uid, $TBADMINGROUP,
       "webnodelog -t $log_type -m $log_entry $node_id", 1);

#
# Show result.
# 
$node->ShowLog();

#
# New Entry option.
#
$url = CreateURL("newnodelog_form", $node);
echo "<p><center>
           Do you want to enter a log entry?
            <A href='$url'>Yes</a>
         </center>\n";

#
# Standard Testbed Footer
# 
PAGEFOOTER();
?>
