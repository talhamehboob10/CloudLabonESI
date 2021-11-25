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
# Only known and logged in users.
#
$this_user = CheckLoginOrDie();
$uid       = $this_user->uid();
$isadmin   = ISADMIN();

#
# Verify page arguments. Allow user to optionally specify building/floor.
#
$optargs = OptionalPageArguments("building",      PAGEARG_STRING,
				 "floor",         PAGEARG_STRING);

if (isset($building) && $building != "") {
    # Sanitize for the shell.
    if (!preg_match("/^[-\w]+$/", $building)) {
	PAGEARGERROR("Invalid building argument.");
    }
    # Optional floor argument. Sanitize for the shell.
    if (isset($floor) && !preg_match("/^[-\w]+$/", $floor)) {
	PAGEARGERROR("Invalid floor argument.");
    }
}
else {
    $building = "MEB-ROBOTS";
    $floor    = 4;
}

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

#
# Get the obstacle information. This stuff is in pixels, but we want to
# always send meters to the applet.
#
$query_result =
    DBQueryFatal("select o.*,f.pixels_per_meter from obstacles as o ".
		 "left join floorimages as f on ".
		 "  o.building=f.building and o.floor=f.floor ".
 		 "where o.building='$building' and o.floor='$floor'");

while ($row = mysql_fetch_array($query_result)) {
    $id    = $row["obstacle_id"];
    $x1    = $row["x1"];
    $y1    = $row["y1"];
    $x2    = $row["x2"];
    $y2    = $row["y2"];
    $desc  = $row["description"];
    $ppm   = $row["pixels_per_meter"];

    if (!isset($desc))
	$desc = "";

    $meters_x1 = sprintf("%.4f", $x1 / $ppm);
    $meters_y1 = sprintf("%.4f", $y1 / $ppm);
    $meters_x2 = sprintf("%.4f", $x2 / $ppm);
    $meters_y2 = sprintf("%.4f", $y2 / $ppm);
    
    echo "$id, $meters_x1, $meters_y1, $meters_x2, $meters_y2, $desc\n";
}

?>
