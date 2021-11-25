<?php
#
# Copyright (c) 2000-2014 University of Utah and the Flux Group.
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
include_once("geni_defs.php");
include("table_defs.php");

#
#
# Only known and logged in users allowed.
#
$this_user = CheckLoginOrDie();
$uid       = $this_user->uid();
$isadmin   = ISADMIN();
$defaultsearchstring = 'Search CM for URN or IP or MAC or VLAN';

#
# Verify Page Arguments.
#
$optargs = OptionalPageArguments("showtype",   PAGEARG_STRING,
				 "query",      PAGEARG_STRING);
$showtypes = array();

if (isset($query) && $query != $defaultsearchstring) {
    $showtypes[] = "cm";
}
elseif (!isset($showtype)) {
    $showtypes[] = "cm";
    $showtypes[] = "sa";
    $showtypes[] = "ch";
}
else {
    if (! ($showtype == "sa"|| $showtype == "cm" || $showtype == "ch")) {
	USERERROR("Improper argument: showtype=$showtype", 1);
    }
    $showtypes[] = $showtype;
}

#
# Standard Testbed Header
#
PAGEHEADER("Geni Slice List");

if (! ($isadmin || STUDLY())) {
    USERERROR("You do not have permission to view Geni slice list!", 1);
}

#
# Search box for CM only. 
#
if (isset($query) && $query != $defaultsearchstring) {
    $searchstring = $query;
}
else {
    $searchstring = $defaultsearchstring;
}
echo "<center>";
echo "<table class=stealth>\n";
echo "<tr>";
echo "<td class=stealth>";
echo "<form method='get' action='genislices.php'>";
echo "<input name='query' class='textInputEmpty'
        size=64 id='searchbox'
	value='$searchstring' 
        onfocus='focus_text(this, \"$defaultsearchstring\")'
        onblur='blur_text(this, \"$defaultsearchstring\")' />";
echo "</td><td><input type='submit' id='searchsub' value=Go />";
echo "</form>";
echo "</td></tr></table>";
echo "</center>\n";

foreach ($showtypes as $type) {
    if ($type == "cm" && isset($query) && $query != $defaultsearchstring) {
	$slicelist  = array();
	$uuidlist   = array();
	$safe_query = escapeshellarg($query);
	
	$fp = popen("$TBSUEXEC_PATH $uid nobody ".
		    "webmaptoslice -w $safe_query", "r");
	if (!$fp) {
	    TBERROR("Could not start maptoslice: $safe_query", 1);
	}
	while ($line = fgets($fp)) {
	    $uuidlist[] = rtrim($line);
	}
	$status = pclose($fp);
	if ($status > 0 || !count($uuidlist)) {
	    USERERROR("No slices matching your search term", 1);
	}
	elseif ($status < 0) {
	    TBERROR("Could not run maptoslice: $safe_query", 1);
	}
	foreach ($uuidlist as $uuid) {
	    $slicelist[] = GeniSlice::Lookup($type, $uuid);
	}
    }
    else {
	$slicelist = GeniSlice::AllSlices($type);
    }
    $which = ($type == "cm" ? "Component Manager" :
	      ($type == "sa" ? "Slice Authority" : "Clearing House"));

    if (!$slicelist || !count($slicelist))
	continue;

    # The form attributes:
    $table = array('#id'       => $type,
		   '#title'    => $which,
		   '#sortable' => 1,
		   '#headings' => array("idx"          => "ID",
					"hrn"          => "HRN",
					"created"      => "Created",
					"expires"      => "Expires"));

    $rows = array();

    foreach ($slicelist as $slice) {
	$slice_idx  = $slice->idx();
	$slice_hrn  = $slice->hrn();
	$created    = $slice->created();
	$expires    = $slice->expires();

	$url = CreateURL("showslice", "showtype", $type,
			 "slice_idx", $slice_idx);
	$href = "<a href='$url'>$slice_hrn</a>";

	$experiment = Experiment::LookupByUUID($slice->uuid());
	if ($experiment) {
	    $eid     = $experiment->eid();
	    $expurl  = CreateURL("showexp", $experiment);
	    $href    = "$href (<a href='$expurl'>$eid</a>)";
	}
	$rows[$slice_idx] = array("idx"       => $slice_idx,
				  "hrn"       => $href,
				  "created"   => $created,
				  "expires"   => $expires);
    }
    list ($html, $button) = TableRender($table, $rows);
    echo $html;
}

#
# Standard Testbed Footer
# 
PAGEFOOTER();
?>

