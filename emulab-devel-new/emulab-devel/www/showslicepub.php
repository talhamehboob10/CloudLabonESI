<?php
#
# Copyright (c) 2000-2015 University of Utah and the Flux Group.
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
# Get current user.
#
$this_user = CheckLogin($check_status);

#
# Public info, if you know the public token for the slice. 
#
$reqargs = RequiredPageArguments("publicid",  PAGEARG_STRING);

$slice = GeniSlice::LookupByPublicID("cm", $publicid);
if (!$slice) {
    USERERROR("No such slice $publicid", 1);
}
$slice_idx = $slice->idx();

#
# Send admins to the non-public page.
#
if (ISADMIN()) {
    header("Location: ".
           "$TBBASE/showslice.php?slice_idx=${slice_idx}&showtype=cm");
    return;
}

#
# Standard Testbed Header
#
PAGEHEADER("Geni Slice");

function GeneratePopupDiv($id, $text) {
    return "<div id=\"$id\" ".
	"style='display:none;width:700;height:400;overflow:auto;'>\n" .
	"$text\n".
	"</div>\n";
}
$manifestidx = 0;

# The table attributes:
$table = array('#id'	   => 'form1',
	       '#title'    => "Slice $slice_idx");
$rows = array();
$popups = array();

$rows[] = array("idx"      => $slice->idx());
$rows[] = array("hrn"      => $slice->hrn());
$urn = $slice->urn();
if ($urn) {
    $rows[] = array("urn"      => $slice->urn());
}
$rows[] = array("uuid"     => $slice->uuid());
$rows[] = array("created"  => $slice->created());
$rows[] = array("expires"  => $slice->expires());
if ($slice->locked()) {
    $rows[] = array("locked"  => $slice->locked());
}
if (($manifest = $slice->GetManifest())) {
    $popups[] = GeneratePopupDiv("manifest$manifestidx", $manifest);
    $rows[] = array("manifest" =>
		    "<a href='#' title='' ".
		    "onclick='PopUpWindowFromDiv(\"manifest$manifestidx\");'".
		    ">manifest</a>\n");
    $manifestidx++;
}

$geniuser = GeniUser::Lookup("cm", $slice->creator_uuid());
if ($geniuser) {
    $rows[] = array("Creator" => $geniuser->urn());
}
else {
    $user = User::LookupByUUID($slice->creator_uuid());
    if ($user) {
	$rows[] = array("Creator" => $user->uid());
    }
}

list ($html, $button) = TableRender($table, $rows);
echo $html;

foreach ($popups as $i => $popup) {
    echo "$popup\n";
}

#
# Find all logs associated with this slice.
#
$query_result =
    DBQueryFatal("select m.logidx,l.logid,l.date_created,m2.metaval ".
		 "  from logfile_metadata as m ".
		 "left join logfiles as l on l.logidx=m.logidx ".
		 "left join logfile_metadata as m2 on ".
		 "      m2.logidx=m.logidx and m2.metakey='Method' ".
		 "where m.metakey='slice_idx' and m.metaval='$slice_idx' ".
		 "order by l.date_created asc");

if ($query_result && mysql_num_rows($query_result)) {
    $table = array('#id'	   => 'logfiles',
		   '#title'        => "Log Files",
		   '#headings'     => array("idx"      => "ID",
					    "method"   => "Op",
					    "created"  => "Created",
					    "log"      => "Link"));
    $rows = array();
    $img  = "<img border='0' src='greenball.gif' />";
    
    while ($row = mysql_fetch_array($query_result)) {
	$logidx = $row["logidx"];
	$logid  = $row["logid"];
	$op     = $row["metaval"];
	$date   = $row["date_created"];
	$url    = CreateURL("spewlogfile", "logfile", $logid);

	$row = array("idx"      => $logidx,
		     "method"   => $op,
		     "created"  => $date,
		     "log"      => "<a href='$url'>$img</a>",
	    );
	
	$rows[] = $row;
    }
    list ($html, $button) = TableRender($table, $rows);
    echo $html;
    echo "<center>
            <a href='showslicelogs.php?slice_idx=$slice_idx&download=1'>
            Download All Logs</a></center>";
}

#
# Standard Testbed Footer
# 
PAGEFOOTER();
?>

