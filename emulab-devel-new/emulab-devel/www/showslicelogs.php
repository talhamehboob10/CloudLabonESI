<?php
#
# Copyright (c) 2000-2013 University of Utah and the Flux Group.
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
$optargs = OptionalPageArguments("slice_idx",  PAGEARG_INTEGER,
				 "slice_uuid", PAGEARG_STRING,
				 "download",   PAGEARG_BOOLEAN);
if (!isset($download)) {
    $download = 0;
}

#
# Standard Testbed Header
#
if (!$download) {
    PAGEHEADER("Geni Slice Logs");
}

if (! ($isadmin || STUDLY())) {
    USERERROR("You do not have permission to view Geni slices!", 1);
}
if (! (isset($slice_idx) || isset($slice_uuid))) {
    PAGEARGERROR("Must provide a slice idx or UUID");
}
$whereclause = (isset($slice_idx) ?
		"where m.metakey='slice_idx'  and m.metaval='$slice_idx'" :
		"where m.metakey='slice_uuid' and m.metaval='$slice_uuid'");
$urlarg = (isset($slice_idx) ?
	   "slice_idx=$slice_idx" : "slice_uuid=$slice_uuid");

#
# Find all logs associated with this slice.
#
$query_result =
    DBQueryFatal("select m.logidx,l.logid,l.date_created,m2.metaval ".
		 "  from logfile_metadata as m ".
		 "left join logfiles as l on l.logidx=m.logidx ".
		 "left join logfile_metadata as m2 on ".
		 "      m2.logidx=m.logidx and m2.metakey='Method' ".
		 "$whereclause ".
		 "order by l.date_created asc");

if ($query_result && mysql_num_rows($query_result)) {
    if ($download) {
	header("Content-Type: text/plain");
	header("Expires: Mon, 26 Jul 1997 05:00:00 GMT");
	header("Cache-Control: no-cache, must-revalidate");
	header("Pragma: no-cache");
	flush();
	
	while ($row = mysql_fetch_array($query_result)) {
	    $logid  = $row["logid"];
	    $logidx = $row["logidx"];

	    if ($fp =
		popen("$TBSUEXEC_PATH $uid nobody ".
		      "spewlogfile -w -i $logid", "r")) {

		while (!feof($fp)) {
		    $string = fgets($fp, 1024);
		    echo "$string";
		}
		flush();
		pclose($fp);
		$fp = 0;
	    }
	}
	return;
    }
    $table = array('#id'	   => 'logfiles',
		   '#title'        => "Log Files",
		   '#headings'     => array("idx"      => "ID",
					    "method"   => "Op",
					    "created"  => "When",
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
            <a href='showslicelogs.php?${urlarg}&download=1'>
            Download All Logs</a></center>";
}

#
# Standard Testbed Footer
# 
PAGEFOOTER();
?>

