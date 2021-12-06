<?php
#
# Copyright (c) 2005-2012 University of Utah and the Flux Group.
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
# Only known and logged in admins can update last_power times.
#
$this_user = CheckLoginOrDie();
$uid       = $this_user->uid();
$isadmin   = ISADMIN();

if (!$isadmin && !STUDLY()) {
    USERERROR("Not enough permission.", 1);
}

#
# Verify page arguments. Note that "node_id" appears to be a comma separated
# list of nodes, while "nodes" is an array passed by the form.
#
$optargs = OptionalPageArguments("node_id",   PAGEARG_STRING,
				 "nodes",     PAGEARG_ARRAY,
				 "poweron",   PAGEARG_STRING,
				 "confirmed", PAGEARG_STRING);

if ((!isset($node_id) || strcmp($node_id, "") == 0) && !isset($nodes)) {
    USERERROR("You must provide a node ID.", 1);
}

$body_str = "<center>";

if (isset($confirmed)) {
    $body_str .= "Updated power time for:<br><br>";
    foreach ($nodes as $ni) {
	if (!TBvalid_node_id($ni)) {
	    $ni = CleanString($ni);
	    USERERROR("Invalid node ID: $ni", 1);
	}
	if (! ($node = Node::Lookup($ni))) {
	    USERERROR("Invalid node ID: $ni", 1);
	}

	if (isset($poweron) && $poweron == "Yep") {
		DBQueryFatal("update outlets " .
			     "set last_power=CURRENT_TIMESTAMP " .
			     "where node_id='$ni'");
	}
	if (!isset($poweron) || $poweron != "Yep") {
		DBQueryFatal("update nodes " .
			     "set eventstate='POWEROFF'," .
			     "state_timestamp=unix_timestamp(NOW()) " .
			     "where node_id='$ni'");
	}
	$body_str .= "<b>$ni</b><br>";
    }
}
else {
    $body_str .= "Update last power time for:<br>";
    $body_str .= "<form action='powertime.php3' method=get><br><table>";
    $body_str .= "<tr><th>Update?</th><th>Node ID</th><th>Last Power</th></tr>";
    foreach (preg_split("/,/", $node_id) as $ni) {
	if (!TBvalid_node_id($ni)) {
	    $ni = CleanString($ni);
	    USERERROR("Invalid node ID: $ni", 1);
	}
	if (! ($node = Node::Lookup($ni))) {
	    USERERROR("Invalid node ID: $ni", 1);
	}
	
	$query_result =
		DBQueryFatal("SELECT (UNIX_TIMESTAMP(NOW()) - ".
			     "UNIX_TIMESTAMP(last_power)) ".
			     "FROM outlets WHERE node_id='$ni'");
	$row = mysql_fetch_array($query_result);
	$last_power_min = floor($row[0] / 60);
	
	$body_str .= "<tr>
		      <td class=pad4 align=center>
		        <input type=checkbox
			       name=\"nodes[]\"
			       value=\"$ni\"
			       checked>
		      </td>
		      <td class=pad4>$ni</td>
		      <td class=pad4><b>$last_power_min</b> minutes ago</td>
		     </tr>";
    }
    $body_str .= "</table><br>";
    $body_str .= "<input type=checkbox name=poweron value=Yep checked>Power On";
    $body_str .= "<br><input type=submit name=confirmed value=Confirm></form>";
}

$body_str .= "</center>";

#
# Standard Testbed Header
#
PAGEHEADER("Update Power Time");

echo "$body_str";

#
# Standard Testbed Footer
# 
PAGEFOOTER();
?>
