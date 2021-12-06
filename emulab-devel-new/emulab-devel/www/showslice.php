<?php
#
# Copyright (c) 2000-2018 University of Utah and the Flux Group.
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

#
# Verify Page Arguments.
#
$reqargs = RequiredPageArguments("slice_idx",  PAGEARG_INTEGER);
$optargs = OptionalPageArguments("showtype",   PAGEARG_STRING);

if (!isset($showtype)) {
    $showtype='sa';
}

#
# Standard Testbed Header
#
PAGEHEADER("Geni Slice");

if (! ($isadmin || STUDLY())) {
    USERERROR("You do not have permission to view Geni slices!", 1);
}

if (! ($showtype == "sa"|| $showtype == "cm" || $showtype == "ch")) {
    USERERROR("Improper argument: showtype=$showtype", 1);
}

$slice = GeniSlice::Lookup($showtype, $slice_idx);
if (!$slice) {
    USERERROR("No such slice $slice_idx", 1);
}

function GeneratePopupDiv($id, $text) {
    return "<div id=\"$id\" ".
	"style='display:none;width:700;height:400;overflow:auto;'>\n" .
	"$text\n".
	"</div>\n";
}
$manifestidx = 0;

# The table attributes:
$table = array('#id'	   => 'form1',
	       '#title'    => "Slice $slice_idx ($showtype)");
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
if ($slice->expiration_max()) {
    $rows[] = array("expires limit"  => $slice->expiration_max());
}
if ($slice->renew_limit()) {
    $rows[] = array("renew limit"  => $slice->renew_limit());
}
if ($slice->monitor_pid()) {
    $rows[] = array("Monitor PID"  => $slice->monitor_pid());
}
if ($slice->publicid()) {
    $url = "$TBBASE/showslicepub.php?publicid=" . $slice->publicid();
    
    $rows[] = array("Public URL" => "<a href='$url'>https:// ...</a>");
}
if ($slice->portal_tag()) {
    $rows[] = array("Portal" => $slice->portal_tag());
    if ($slice->portal_url()) {
        $url = $slice->portal_url();
        $rows[] = array("Portal URL" => "<a href='$url'>https:// ...</a>");
    }
}
elseif ($slice->speaksfor_urn()) {
    $portal_url = GenPortalURL(1, $slice->speaksfor_urn(), $slice->uuid());
    if ($portal_url) {
        $rows[] = array("Portal URL" =>
                        "<a href='$portal_url'>https:// ...</a>");
    }
}
if (($manifest = $slice->GetManifest())) {
    $popups[] = GeneratePopupDiv("manifest$manifestidx", $manifest);
    $rows[] = array("manifest" =>
		    "<a href='#' title='' ".
		    "onclick='PopUpWindowFromDiv(\"manifest$manifestidx\");'".
		    ">manifest</a>\n");
    $manifestidx++;
}

$experiment = Experiment::LookupByUUID($slice->uuid());
if ($experiment) {
    $eid = $experiment->eid();
    $exptidx = $experiment->idx();
    $url = CreateURL("showexp", $experiment);
    $rows[] = array("Experiment"  => "<a href='$url'>$eid ($exptidx)</a>");
}

$geniuser = GeniUser::Lookup($showtype, $slice->creator_uuid());
if ($geniuser) {
    $rows[] = array("Creator" => $geniuser->urn());
    if ($geniuser->email()) {
	$rows[] = array("Email" => $geniuser->email());
    }
}
else {
    $user = User::LookupByUUID($slice->creator_uuid());
    if ($user) {
	$url = CreateURL("showuser", $user);
	$rows[] = array("Creator" => "<a href='$url'>". $user->uid() ."</a>");
    }
}

if ($showtype != "sa") {
    $saslice = GeniSlice::Lookup("sa", $slice->uuid());
    if ($saslice) {
	$saidx = $saslice->idx();
	$url   = CreateURL("showslice", "slice_idx", $saidx, "showtype", "sa");

	$rows[] = array("SA Slice" => "<a href='$url'>$saidx</a>");
    }
}
if ($showtype != "cm") {
    $cmslice = GeniSlice::Lookup("cm", $slice->uuid());
    if ($cmslice) {
	$cmidx = $cmslice->idx();
	$url   = CreateURL("showslice", "slice_idx", $cmidx, "showtype", "cm");

	$rows[] = array("CM Slice" => "<a href='$url'>$cmidx</a>");
    }
}

list ($html, $button) = TableRender($table, $rows);
echo $html;

$clientslivers = ClientSliver::SliverList($slice);
if ($clientslivers && count($clientslivers)) {
    $table = array('#id'	   => 'clientslivers',
		   '#title'        => "Client Slivers",
		   '#headings'     => array("idx"      => "ID",
					    "urn"      => "URN",
					    "manager"  => "Manager URN",
					    "created"  => "Created",
					    "manifest" => "Manifest"));
    $rows = array();

    foreach ($clientslivers as $clientsliver) {
	$row = array("idx"      => $clientsliver->idx(),
		     "urn"      => $clientsliver->urn(),
		     "manager"  => $clientsliver->manager_urn(),
		     "created"  => $clientsliver->created());

	if ($clientsliver->manifest()) {
	    $popups[] = GeneratePopupDiv("manifest$manifestidx",
					 $clientsliver->manifest());
	    $row["manifest"] =
		"<a href='#' title='' ".
		"onclick='PopUpWindowFromDiv(\"manifest$manifestidx\");'>".
		"Manifest</a>";
	    $manifestidx++;
	}
	else {
	    $row["manifest"] = "Unknown";
	}
	$rows[] = $row;
    }

    list ($html, $button) = TableRender($table, $rows);
    echo $html;
}
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

