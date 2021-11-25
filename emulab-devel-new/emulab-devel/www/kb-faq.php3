<?php
#
# Copyright (c) 2005 University of Utah and the Flux Group.
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
require("defs.php3");

#
# Standard Testbed Header
#
PAGEHEADER("Emulab FAQ");

#
# Get all FAQ entries.
# 
$search_result =
    DBQueryFatal("select * from knowledge_base_entries ".
		 "where faq_entry=1 ".
		 "order by section,date_created");

if (! mysql_num_rows($search_result)) {
    USERERROR("There are no FAQ entries in the Emulab Knowledge Base!", 1);
    return;
}

echo "<center><h2>Frequently Asked Questions</h2></center>\n";
echo "<blockquote>\n";
echo "<ul>\n";

$lastsection = "";

while ($row = mysql_fetch_array($search_result)) {
    $section  = $row['section'];
    $title    = $row['title'];
    $idx      = $row['idx'];
    $xref_tag = $row['xref_tag'];

    if ($lastsection != $section) {
	if ($lastsection != "") {
	    echo "</ul><hr>\n";
	}
	$lastsection = $section;
	
	echo "<li><font size=+1><b>$section</b></font>\n";
	echo "<ul>\n";
    }
    echo "<li>";
    if (isset($xref_tag) && $xref_tag != "") {
	echo "<a NAME='$xref_tag'></a>";
	echo "<a href=kb-show.php3?xref_tag=$xref_tag>$title</a>\n";
    }
    else {
	echo "<a href=kb-show.php3?idx=$idx>$title</a>\n";
    }
}

echo "</ul>\n";
echo "</blockquote>\n";

#
# Standard Testbed Footer
# 
PAGEFOOTER();
?>

