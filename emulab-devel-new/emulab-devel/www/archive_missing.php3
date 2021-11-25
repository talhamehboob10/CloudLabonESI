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

#
# Only known and logged in users can end experiments.
#
$this_user = CheckLoginOrDie();
$uid       = $this_user->uid();
$isadmin   = ISADMIN();

#
# Verify page arguments.
#
$reqargs  = RequiredPageArguments("experiment", PAGEARG_EXPERIMENT);

# Need these below.
$pid = $experiment->pid();
$eid = $experiment->eid();
$gid = $experiment->gid();

# Permission
if (!$isadmin &&
    !$experiment->AccessCheck($this_user, $TB_PROJECT_READINFO)) {
    USERERROR("You do not have permission to view missing files for ".
	      "archive in $pid/$eid!", 1);
}

#
# Move files requested.
#
if (isset($movesome)) {
    #
    # Go through the post list and find all the filenames.
    #
    $fileargs = "";
    
    while (list ($var, $value) = each ($_POST)) {
	if (preg_match('/^fn[\d]+$/', $var) &&
	    preg_match('/^([-\w\/\.\+\@,~]+)$/', $value)) {
	    $fileargs = "$fileargs " . escapeshellarg($value);
	}
    }
    SUEXEC($uid, "$pid,$gid",
	   "webarchive_control addtoarchive $pid $eid $fileargs",
	   SUEXEC_ACTION_DUPDIE);
    
    header("Location: " . CreateURL("archive_missing", $experiment));
    return;
}

#
# Standard Testbed Header
#
PAGEHEADER("Add Missing Files");

echo "<script language=JavaScript>
      <!--
          function NormalSubmit() {
              document.form1.target='_self';
              document.form1.submit();
          }
          function SelectAll() {
              var i;
              var setval;

              if (document.form1.selectall.value == 'Select All') {
                   document.form1.selectall.value = 'Clear All'
                   setval = true;
              }
              else {
                   document.form1.selectall.value = 'Select All'
                   setval = false;
              }

              for (i = 0; i < document.form1.elements.length; i++) {
                  var element = document.form1.elements[i];

                  if (element.type == 'checkbox') {
                      element.checked = setval;
                  }
              }
          }
          //-->
          </script>\n";

echo $experiment->PageHeader();
echo "<br><br>\n";

#
# We ask an external script for the list of missing files. 
#
SUEXEC($uid, "$pid,$gid",
       "webarchive_control missing $pid $eid",
       SUEXEC_ACTION_DIE);

#
# Show the user the output.
#
if (count($suexec_output_array)) {
    echo "<br>".
	"<b>These files have been referenced by your experiment, but ".
	"are not contained within the experiments archive directory. ".
	"Selecting these files will move them into the experiment archive ".
	"directory, leaving symlinks behind.";
    echo "</b><br><br>";

    echo "<table border=1>\n";
    echo "<form action='" .
	          CreateURL("archive_missing", $experiment) . "' " .
	       "onsubmit=\"return false;\"
                name=form1 method=post>\n";
    echo "<input type=hidden name=movesome value=Submit>\n";    
    echo "<tr><td align=center colspan=2>\n";
    echo "<input type=button name=movesome value='Move Selected'
                 onclick=\"NormalSubmit();\"></b>";
    echo "&nbsp;&nbsp;&nbsp; ";
    echo "<input type=button name=selectall value='Select All'
                 onclick=\"SelectAll();\"></b>";
    echo "</td></tr>\n";

    echo "<tr>
           <th>Pathname</th>
           <th>Move to Archive</th>
          </tr>\n";
    
    for ($i = 0; $i < count($suexec_output_array); $i++) {
	$fn = rtrim($suexec_output_array[$i]);
	$name = "fn$i";
	
	echo "<tr>\n";
	echo "<td><tt>" . $fn . "</tt></td>";
	echo "<td><input type=checkbox name=$name value='$fn'>&nbsp</td>\n";
	echo "</tr>\n";
    }
    echo "</form>\n";
    echo "</table>\n";
}

#
# Standard Testbed Footer
#
PAGEFOOTER();
?>
