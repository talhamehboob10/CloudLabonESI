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
# Only known and logged in users can do this.
#
$this_user = CheckLoginOrDie();
$uid       = $this_user->uid();
$isadmin   = ISADMIN();

#
# Verify page arguments.
#
$optargs = OptionalPageArguments("node", PAGEARG_NODE);

#
# Only Admins can enter log entries. Or members of emulab-ops project
# if the node is free or reserved to emulab-ops.
#
if (! ($isadmin || OPSGUY())) {
    USERERROR("You do not have permission to enter log entries!", 1);
}

#
# Standard Testbed Header
#
PAGEHEADER("Enter Node Log Entry");

echo "<table align=center border=1> 
      <tr>
         <td align=center colspan=2>
             <em>(Fields marked with * are required)</em>
         </td>
      </tr>
     <form action='newnodelog.php3' method=post>\n";

#
# Node ID:
#
# Note DB max length.
#
if (isset($node)) {
    echo "<tr>
              <td>*Node ID:</td>
              <td><input type=text name=node_id
                         value=" . $node->node_id() . " 
	                 size=$TBDB_NODEIDLEN maxlength=$TBDB_NODEIDLEN>
      </tr>\n";
}
else {
    echo "<tr>
              <td>*Node ID:</td>
              <td><input type=text name=node_id size=$TBDB_NODEIDLEN
                         maxlength=$TBDB_NODEIDLEN>
              </td>
      </tr>\n";
}

#
# Log Type.
#
echo "<tr>
          <td>*Log Type:</td>
          <td><select name=log_type>
               <option selected value='misc'>Misc</option>
              </select>
          </td>
      </tr>\n";

#
# Log Entry.
#
echo "<tr>
         <td>*Log Entry:</td>
         <td><input type=text name=log_entry size=50 maxlength=128></td>
      </tr>\n";

echo "<tr>
         <td align=center colspan=2>
            <b><input type=submit value=Submit></b>
         </td>
      </tr>\n";

echo "</form>
      </table>\n";

#
# Standard Testbed Footer
# 
PAGEFOOTER();
?>
