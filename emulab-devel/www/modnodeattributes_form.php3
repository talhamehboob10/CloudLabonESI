<?php
#
# Copyright (c) 2000-2021 University of Utah and the Flux Group.
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
# Only known and logged in users can do this.
#
$this_user = CheckLoginOrDie();
$uid       = $this_user->uid();
$isadmin   = ISADMIN();

#
# Only admin users can modify node attributes.
#
if (! $isadmin) {
    USERERROR("You do not have permission to modify node attributes!", 1);
}

#
# Verify form arguments.
#
$reqargs = RequiredPageArguments("node",         PAGEARG_NODE);
$optargs = OptionalPageArguments("add_numattrs", PAGEARG_INTEGER);

# Need these below ...
$node_id = $node->node_id();
$type    = $node->type();
$url     = CreateURL("modnodeattributes", $node);

#
# Standard Testbed Header
#
PAGEHEADER("Modify Node Attributes Form");

#
# Get any node attributes that might exist
#
$node_attrs = array();
$attr_result =
    DBQueryFatal("select attrkey,attrvalue from node_attributes ".
		 "where node_id='$node_id'");
while($row = mysql_fetch_array($attr_result)) {
    $node_attrs[$row["attrkey"]] = $row["attrvalue"];
}

#
# Print out node id and type
#

echo "<table border=0 cellpadding=0 cellspacing=2
       align='center'>\n";

echo "<tr>
          <td align=\"center\"><b>Node ID: $node_id</b></td>
      </tr>\n";

echo "<tr>
          <td align=\"center\"><b>Node Type: $type</b></td>
      </tr>\n";
echo "</table><br><br><br><br>\n";

#
# Generate the form. 
# 
echo "<table border=2 cellpadding=0 cellspacing=2
       align='center'>\n";
echo "<form action='$url' method=\"post\">\n";
#
# Print out any node attributes already set
#
if ($node_attrs) {
  echo "<tr><td><table border=2 cellpadding=0 cellspacing=2
                 align='left'>\n";
  echo "<tr>
            <td align=\"center\" colspan=\"0\">
                <b>Current Node Attributes</b></td>
        </tr>
        <tr>
            <td>Del?</td><td>Attribute</td><td>Value</td>
        </tr>\n";
  foreach ($node_attrs as $attrkey => $attrval) {
    echo "<tr>
              <td><input type=\"checkbox\" name=\"_delattrs[$attrkey]\">
              <td>$attrkey</td>
              <td class=\"left\">
                  <input type=\"text\" name=\"_modattrs[$attrkey]\" size=\"60\"
                         value=\"$attrval\"></td>
          </tr>\n";
  }
  echo "</table></td></tr>\n";
}

#
# Print out fields for adding new attributes.
# The number of attributes defaults to 1, but this can be changed
# by specifying the number to add in the "add_numattrs" CGI variable.
#

echo "<tr><td><table border=2 cellpadding=0 cellspacing=2
       align='left'>\n";
echo "<tr>
          <td align=\"center\" colspan=\"0\"><b>Add Node Attribute</b></td>
      </tr>\n";

if (!isset($add_numattrs)) {
    $add_numattrs = 1;
}

for ($i = 0; $i < $add_numattrs; $i++) {
  echo "<tr>
            <td class=\"left\">
                <input type=\"text\" name=\"_newattrs[$i]\" size=\"32\"></td>
            <td class=\"left\">
                <input type=\"text\" name=\"_newvals[$i]\" size=\"60\"></td>
            </td>
        </tr>\n";
}

echo "<tr>
          <td colspan=2 align=center>
              <b><input type=\"submit\" value=\"Submit\"></b>
          </td>
     </tr>
     </form>
     </table></td></tr>\n";

echo "</table>\n";

#
# Standard Testbed Footer
# 
PAGEFOOTER();
?>
