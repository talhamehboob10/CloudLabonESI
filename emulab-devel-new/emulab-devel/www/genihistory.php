<?php
#
# Copyright (c) 2000-2015, 2018 University of Utah and the Flux Group.
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
$searchbox = "user/slice urn or slice uuid or date";

#
# Verify Page Arguments.
#
$optargs = OptionalPageArguments("searchfor",  PAGEARG_STRING,
				 "search",     PAGEARG_STRING,
				 "slice_uuid", PAGEARG_STRING,
				 "ch",         PAGEARG_BOOLEAN,
				 "index",      PAGEARG_INTEGER);
if (!isset($index)) {
    $index = 0;
}
if (!isset($searchfor)) {
    $searchfor = $searchbox;
}
if (!isset($ch)) {
    $ch = 0;
}

#
# Standard Testbed Header
#
PAGEHEADER("Geni History");

if (! ($isadmin || STUDLY())) {
    USERERROR("You do not have permission to view Geni slice list!", 1);
}

#
# Spit out a search form
#
echo "<br>";
echo "<form action=genihistory.php method=post>
      <b>Search:</b> 
      <input type=text
             name=searchfor
             size=50
             value=\"$searchfor\"";
if ($searchfor == $searchbox) {
    echo "   onfocus='focus_text(this, \"$searchfor\")'
             onblur='blur_text(this, \"$searchfor\")'";
}
echo " />
      <b><input type=submit name=search value=Go></b> ";
if ($ISCLRHOUSE) {
    echo "<input type=checkbox name=ch value=1 ".
	($ch ? "checked" : "") . "> Search CH";
}
echo "</form>\n";

if (1) {
    $myindex = $index;
    $dblink  = GetDBLink(($ch ? "ch" : "cm"));
    $clause  = "";

    if (isset($slice_uuid)) {
	if (!preg_match("/^\w+\-\w+\-\w+\-\w+\-\w+$/", $slice_uuid)) {
	    USERERROR("Invalid slice uuid", 1);
	}
	$clause = "and a.slice_uuid='$slice_uuid' ";
    }
    else {
	if ($myindex) {
	    $clause = "and a.idx<$myindex ";
	}
	if (isset($search) && isset($searchfor)) {
	    $safe_searchfor = addslashes($searchfor);

	    if (preg_match("/^\w+\-\w+\-\w+\-\w+\-\w+$/", $searchfor)) {
		$clause = "$clause and a.slice_uuid='$safe_searchfor' ";
	    }
	    elseif (preg_match("/^urn:publicid:IDN\+[-\w\.:]+\+slice\+[-\w]*$/",
			       $searchfor)) {
		$clause = "$clause and a.slice_urn='$safe_searchfor' ";
	    }
	    elseif (preg_match("/^urn:publicid:IDN\+[-\w\.:]+\+user\+[-\w]*$/",
			       $searchfor)) {
		$clause = "$clause and a.creator_urn='$safe_searchfor' ";
	    }
	    elseif (strtotime($searchfor)) {
		$ts = strtotime($searchfor);
		$clause = "$clause and ($ts >= UNIX_TIMESTAMP(a.created) && ".
		 "(a.destroyed is null or $ts <= UNIX_TIMESTAMP(a.destroyed)))";
	    }
	    elseif ($searchfor == $searchbox) {
		# Just a press of the ch box, so dump out the CH records.
	    }
	    else {
		USERERROR("Invalid search specification", 1);
	    }
	}
    }
    $query_result =
	DBQueryFatal("select a.*,c.DN,s.portal_url,s.idx as slice_idx ".
		     "  from aggregate_history as a ".
		     "left join geni_slices as s on s.uuid=a.slice_uuid ".
		     "left join geni_certificates as c on ".
		     "     c.urn=a.creator_urn ".
		     "where a.type='Aggregate' $clause ".
		     "order by a.idx desc limit 20",
		     $dblink);

    echo "<center>\n";
    echo "<br>";
    echo "<font size=+1><b>Aggregate History</b></font>";
    echo "<br>\n";
    echo "<table>\n";
    echo " <thead>\n";
    echo "  <tr>\n";
    echo "   <th>ID</th>\n";
    echo "   <th>Slice/Creator</th>\n";
    echo "   <th>Created/Destroyed</th>\n";
    echo "   <th>Manifest/Portal</th>\n";
    echo "  </tr>\n";
    echo " </thead>\n";
    echo " <tbody>\n";

    if (mysql_num_rows($query_result)) {
	while ($row = mysql_fetch_array($query_result)) {
	    $idx         = $row["idx"];
	    $slice_idx   = $row["slice_idx"];
	    $uuid        = $row["uuid"];
	    $slice_hrn   = $row["slice_hrn"];
	    $slice_uuid  = $row["slice_uuid"];
	    $creator_hrn = $row["creator_hrn"];
	    $slice_urn   = $row["slice_urn"];
	    $creator_urn = $row["creator_urn"];
	    $created     = $row["created"];
	    $destroyed   = $row["destroyed"];
	    $DN          = $row["DN"];
            $portal_url  = "&nbsp";

	    # If we have urns, show those instead.
	    $slice_info = $slice_hrn;
	    if (isset($slice_urn)) {
		$slice_info = "$slice_urn";
	    }
	    $creator_info = $creator_hrn;
	    if (isset($creator_urn)) {
		$creator_info = "$creator_urn";
	    }
	    if (isset($DN) &&
		#
		# See if we can find the email.
		#
		(preg_match("/emailAddress=([A-Z0-9._%-]+@".
			    "[A-Z0-9.-]+\.[A-Z]{2,4})/i", $DN, $matches) ||
		 preg_match("/\/emailAddress=(.*)/", $DN, $matches) ||
		 preg_match("/^emailAddress=(.*),/", $DN, $matches))) {

		$creator_info .= "<br>" . $matches[1];
	    }
	    if ($destroyed) {
		$url = "<a href='showslicelogs.php?slice_uuid=$slice_uuid'>";
	    }
	    else {
		$url =
		    "<a href='showslice.php?slice_idx=$slice_idx&showtype=cm'>";
	    }
	    $url .= "$slice_info</a>";

	    $manifest_url = "<a href='manifesthistory.php?uuid=$uuid'>manifest</a>";
            #
            # Try to form a URL back to the (Utah) Portal. 
            #
            if ($row["portal_url"]) {
                $tmp = $row["portal_url"];
                $portal_url = "<a href='$tmp'>portal</a>";
            }
            elseif ($row["speaksfor_urn"] && $row["speaksfor_urn"] != "") {
                $active = ($destroyed ? 0 : 1);
                $tmp = GenPortalURL($active,
                                    $row["speaksfor_urn"], $slice_uuid);
                if ($tmp) {
                    $portal_url = "<a href='$tmp'>portal</a>";
                }
            }
            echo "<tr>";
            echo " <td rowspan=2>$idx</td>";
            echo " <td>$url</td>";
            echo " <td>$created</td>";
            echo " <td>$manifest_url</td>";
            echo "</tr>";
            echo "<tr>";
            echo " <td>$creator_info</td>";
            echo " <td>$destroyed</td>";
            echo " <td>$portal_url</td>";
            echo "</tr>";
	    echo "<tr></tr>\n";

	    $myindex = $idx;
	}
        echo "</tbody>\n";
        echo "</table>\n";
        echo "</center>\n";

	$query_result =
	    DBQueryFatal("select count(*) from aggregate_history as a ".
			 "where `type`='Aggregate' and a.idx<$myindex $clause ",
			 $dblink);

	$row = mysql_fetch_array($query_result);
	$remaining = $row[0];

	if ($remaining) {
	    $opts = "";
	    if ($ch) {
		$opts .= "&ch=$ch";
	    }
	    if (isset($search)) {
		$opts .= "&search=yes&searchfor=" .
		    rawurlencode($searchfor);
	    }
	    echo "<center>".
	      "<a href='genihistory.php?index=${myindex}${opts}'>".
	      "More Entries</a></center><br>\n";
	}
    }
}

#
# Standard Testbed Footer
# 
PAGEFOOTER();
?>

