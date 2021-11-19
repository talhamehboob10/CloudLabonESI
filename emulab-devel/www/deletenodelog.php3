<?php
#
# Copyright (c) 2000-2012 University of Utah and the Flux Group.
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
# Only known and logged in users can end experiments.
#
$this_user = CheckLoginOrDie();
$uid       = $this_user->uid();
$isadmin   = ISADMIN();

#
# Verify page arguments.
#
$reqargs = RequiredPageArguments("node", PAGEARG_NODE,
				 "log_id", PAGEARG_INTEGER);
$optargs = OptionalPageArguments("canceled", PAGEARG_BOOLEAN,
				 "confirmed", PAGEARG_BOOLEAN);

#
# Only Admins can delete log entries.
#
if (! ($isadmin || OPSGUY())) {
    USERERROR("You do not have permission to delete log entries!", 1);
}

# Need these below
$node_id = $node->node_id();

#
# Standard Testbed Header
#
PAGEHEADER("Delete a Node Log Entry");

#
# We run this twice. The first time we are checking for a confirmation
# by putting up a form. The next time through the confirmation will be
# set. Or, the user can hit the cancel button, in which case we should
# probably redirect the browser back up a level.
#
if (isset($canceled) && $canceled) {
    echo "<center><h2><br>
          Log Entry Deletion canceled!
          </h2></center>\n";
    
    PAGEFOOTER();
    return;
}

if (!isset($confirmed)) {
    echo "<center><h2><br>
          Are you sure you want to delete this log entry?'
          </h2>\n";

    $node->ShowLogEntry($log_id);

    $url = CreateURL("deletenodelog", $node, "log_id", $log_id);
    
    echo "<form action='$url' method=post>";
    echo "<b><input type=submit name=confirmed value=Confirm></b>\n";
    echo "<b><input type=submit name=canceled value=Cancel></b>\n";
    echo "</form>\n";
    echo "</center>\n";

    PAGEFOOTER();
    return;
}

#
# Delete the record,
#
$node->DeleteNodeLog($log_id);
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
