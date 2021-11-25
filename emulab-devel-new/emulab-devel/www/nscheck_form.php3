<?php
#
# Copyright (c) 2000-2004, 2006, 2007 University of Utah and the Flux Group.
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
# Only known and logged in users can begin experiments.
#
$this_user = CheckLoginOrDie();
$uid       = $this_user->uid();
$isadmin   = ISADMIN();

#
# Standard Testbed Header
#
PAGEHEADER("Syntax Check your NS file");

?>
<table align="center" border="1"> 
<tr>
    <td align="center" colspan="3">
        <font size="+1">
               Use this page to syntax check your NS file before
               submitting it.
        </font>
    </td>
</tr>

<?php
echo "<form enctype=\"multipart/form-data\"
            action=\"nscheck.php3\" method=\"post\">\n";


#
# NS file upload or on server.
# 
echo "<tr>
          <td rowspan>*Your NS file: &nbsp</td>

          <td rowspan><center>Upload (500K max)<br>
                                   <br>
                                   Or<br>
                                   <br>
                              On Server <br> ($TBVALIDDIRS)
                      </center></td>

          <td rowspan>
              <input type=\"hidden\" name=\"MAX_FILE_SIZE\" value=\"512000\">
              <input type=\"file\" name=\"exp_nsfile\" size=\"30\">
              <br>
              <br>
              <input type=\"text\" name=\"formfields[exp_localnsfile]\"
                     size=\"40\">
              </td>
      </tr>\n";

?>

<tr>
    <td align="center" colspan="3">
        <b><input type="submit" value="Check"></b></td>
</tr>
</form>
</table>

<?php
#
# Standard Testbed Footer
# 
PAGEFOOTER();
?>
