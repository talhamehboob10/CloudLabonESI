<?php
#
# Copyright (c) 2000-2002, 2007 University of Utah and the Flux Group.
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
# Standard Testbed Header
#
# Change when do check for number of experiments.
PAGEHEADER("Projects that have actively used ".strtolower($THISHOMEBASE));

#
# We let anyone access this page.  Its basically a pretty-printed version
# of the current testbed clients, who have not opted out from this display.
#
# Complete information is better viewed with the "Project Information" link.
# That requires a logged in user though. 
#

#
# Helper
#
function GENPLIST ($query_result)
{
    echo "<tr>
             <th>Name</th>
             <th>Institution</th>
          </tr>\n";

    while ($projectrow = mysql_fetch_array($query_result)) {
	$pname  = $projectrow["name"];
	$url    = $projectrow["URL"];
	$affil  = $projectrow["usr_affil"];

	echo "<tr>\n";

	if (!$url || strcmp($url, "") == 0) {
	    echo "<td>$pname</td>\n";
	}
	else {
	    echo "<td><A href=\"$url\">$pname</A></td>\n";
	}

	echo "<td>$affil</td>\n";

	echo "</tr>\n";

    }
}

#
# Get the "active" project list.
#
$query_result =
    DBQueryFatal("SELECT pid,name,URL,usr_affil FROM projects ".
		 "left join users on projects.head_idx=users.uid_idx ".
		 "where public=1 and approved=1 and expt_count>0 ".
		 "order by name");

echo "<table width=\"100%\" border=0 cellpadding=2 cellspacing=2
             align='center'>\n";

if (mysql_num_rows($query_result)) {
    GENPLIST($query_result);
}

#
# Get the "inactive" project list.
#
$query_result =
    DBQueryFatal("SELECT pid,name,URL,usr_affil FROM projects ".
		 "left join users on projects.head_idx=users.uid_idx ".
		 "where public=1 and approved=1 and expt_count=0 ".
		 "order by name");

if (mysql_num_rows($query_result)) {
    echo "<tr><th colspan=2>
              Other projects registered on $THISHOMEBASE:</h4>
              </th>
          </tr>\n";
    GENPLIST($query_result);
}

echo "</table>\n";

#
# Standard Testbed Footer
# 
PAGEFOOTER();
?>
