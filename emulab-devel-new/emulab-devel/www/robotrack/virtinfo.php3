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
# Verify page arguments.
#
$reqargs = RequiredPageArguments("experiment", PAGEARG_EXPERIMENT);

#
# Verify Permission.
#
if (!$experiment->AccessCheck($this_user, $TB_EXPT_READINFO)) {
    USERERROR("You do not have permission to access experiment!", 1);
}
$pid = $experiment->pid();
$eid = $experiment->eid();

# Initial goo.
header("Content-Type: text/plain");
header("Expires: Mon, 26 Jul 1997 05:00:00 GMT");
header("Cache-Control: no-cache, must-revalidate");
header("Pragma: no-cache");
flush();

#
# Clean up when the remote user disconnects
#
function SPEWCLEANUP()
{
    exit(0);
}
register_shutdown_function("SPEWCLEANUP");

# Get the virtual node info
$query_result =
    DBQueryFatal("select v.vname,fixed,vis.x,vis.y from virt_nodes as v ".
		 "left join vis_nodes as vis on ".
		 "     vis.pid=v.pid and vis.eid=v.eid and vis.vname=v.vname ".
		 "where v.pid='$pid' and v.eid='$eid' ".
		 "order by v.vname");

while ($row = mysql_fetch_array($query_result)) {
    $vname  = $row["vname"];
    $fixed  = $row["fixed"];
    $x      = (int) $row["x"];
    $y      = (int) $row["y"];

    if (!isset($fixed))
	$fixed = "";
							      
    echo "$vname, $fixed, $x, $y\n";
}

?>
