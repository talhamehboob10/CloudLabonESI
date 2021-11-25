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
include("node_defs.php");

#
# Only known and logged in users can do this.
#
$this_user = CheckLoginOrDie();
$uid       = $this_user->uid();
$isadmin   = ISADMIN();

#
# Verify page arguments.
#
$reqargs = RequiredPageArguments("node", PAGEARG_NODE);
$optargs = OptionalPageArguments("classic", PAGEARG_BOOLEAN);
$node_id = $node->node_id();

if (!$classic) {
    header("Location: portal/show-nodelog.php?node_id=$node_id");
    return;
}

#
# Standard Testbed Header
#
PAGEHEADER("Node Log");

#
# Perm check.
#
if (! ($isadmin || OPSGUY())) {
    USERERROR("You do not have permission to view node logs!", 1);
}

$node->ShowLog();

#
# New Entry option.
#
$url =CreateURL("newnodelog_form", $node);

echo "<p><center>
           Do you want to enter a log entry?
           <A href='$url'>Yes</a>
         </center>\n";

#
# Standard Testbed Footer
# 
PAGEFOOTER();
?>
