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
include_once("node_defs.php");

#
# No PAGEHEADER since we spit out plain text.
# 

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

if (! $isadmin &&
    ! $node->AccessCheck($this_user, $TB_NODEACCESS_REBOOT)) {
    USERERROR("You do not have permission to view the bootlog node", 1);
}
$node_id = $node->node_id();

#
# See if we have a bootlog recorded. 
#
$log   = null;
$stamp = null;
if ($node->BootLog($log, $stamp) || is_null($log)) {
    USERERROR("There is no bootlog for $node_id", 1);
}

header("Content-Type: text/plain");
header("Expires: Mon, 26 Jul 1997 05:00:00 GMT");
header("Cache-Control: no-cache, must-revalidate");
header("Pragma: no-cache");

echo "Bootlog reported on $stamp\n\n";
echo $log;

?>
