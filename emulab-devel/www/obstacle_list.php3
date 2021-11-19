<?php
#
# Copyright (c) 2005, 2006 University of Utah and the Flux Group.
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
#
# Only known and logged in users allowed.
#
$this_user = CheckLoginOrDie();
$uid       = $this_user->uid();
$isadmin   = ISADMIN();

#
# Standard Testbed Header
#
PAGEHEADER("Obstacle List");

#
# Spit out all the obstacles. At some point this page should take
# optional building/floor params.
#
$query_result =
    DBQueryFatal("select o.*,f.pixels_per_meter from obstacles as o ".
		 "left join floorimages as f on f.floor=o.floor and ".
		 "     f.building=o.building and f.scale=1 ".
		 "order by o.obstacle_id");

if (!mysql_num_rows($query_result)) {
    USERERROR("There are no obstacles!", 1);
}
$count = mysql_num_rows($query_result);

echo "<center>
       There are $count obstacles.
      </center><br>\n";

echo "<table width=\"100%\" border=2 cellpadding=1 cellspacing=2
       align='center'>\n";

echo "<tr>
          <th rowspan=2>ID</th>
          <th>X1</th>
          <th>Y1</th>
          <th>Z1</th>
          <th align=center rowspan=2>Description</th>
      </tr>
      <tr>
          <th>X2</th>
          <th>Y2</th>
          <th>Z2</th>
      </tr>\n";

while ($row = mysql_fetch_array($query_result)) {
    $id       = $row["obstacle_id"];
    $x1       = $row["x1"];
    $x2       = $row["x2"];
    $y1       = $row["y1"];
    $y2       = $row["y2"];
    $z1       = $row["z1"];
    $z2       = $row["z2"];
    $desc     = $row["description"];
    $ppm      = $row["pixels_per_meter"];

    if (isset($ppm) && $ppm != 0.0) {
	$x1 = sprintf("%.3f", $x1 / $ppm);
	$x2 = sprintf("%.3f", $x2 / $ppm);
	$y1 = sprintf("%.3f", $y1 / $ppm);
	$y2 = sprintf("%.3f", $y2 / $ppm);
	$z1 = sprintf("%.3f", $z1 / $ppm);
	$z2 = sprintf("%.3f", $z2 / $ppm);
    }

    echo "<tr>
            <td rowspan=2><a href=showobstacle.php3?id=$id>$id</a></td>
	    <td>$x1</td>
	    <td>$y1</td>
	    <td>$z1</td>
            <td rowspan=2>$desc</td>
          </tr>
          <tr>
	    <td>$x2</td>
	    <td>$y2</td>
	    <td>$z2</td>
          </tr>\n";
}
echo "</table>\n";

#
# Standard Testbed Footer
# 
PAGEFOOTER();
?>
