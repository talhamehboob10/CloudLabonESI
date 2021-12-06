<?php
#
# Copyright (c) 2005-2016 University of Utah and the Flux Group.
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
# No PAGEHEADER since we spit out a Location header later. See below.
# 

#
# Verify page arguments.
#
$reqargs = RequiredPageArguments("node",      PAGEARG_NODE);
$optargs = OptionalPageArguments("linecount", PAGEARG_INTEGER,
                                 "key",       PAGEARG_STRING);
$node_id = $node->node_id();

if (isset($key)) {
    $safe_key = addslashes($key);
    
    $query_result =
	DBQueryFatal("select urlstamp, reuseurl from tiplines ".
		     "where node_id='$node_id' and urlhash='$safe_key' and ".
		     "      urlstamp!=0");
    
    if (mysql_num_rows($query_result) == 0) {
	USERERROR("Invalid node or invalid key", 1);
    } else {
	$row = mysql_fetch_array($query_result);
	$stamp = $row['urlstamp'];
	if ($stamp <= time()) {
	    DBQueryFatal("update tiplines set urlhash=NULL,urlstamp=0,".
			 "reuseurl=0 ".
	    		 "where node_id='$node_id'");
	    USERERROR("Key is no longer valid", 1);
	}
    }
    $uid     = "nobody";
    $isadmin = 0;
    $optarg  = "-k " . escapeshellarg($key);
    $reuse = $row['reuseurl'];
    if ($reuse == 1) {
      $optarg .= " -r";
    }
}
else {
    #
    # Only known and logged in users can do this.
    #
    $this_user = CheckLoginOrDie();
    $uid       = $this_user->uid();
    $isadmin   = ISADMIN();
    $optarg    = "";
    
    if (!$isadmin &&
        !$node->AccessCheck($this_user, $TB_NODEACCESS_READINFO)) {
        USERERROR("You do not have permission to view the console log ".
                  "for $node_id!", 1);
    }
}

#
# Look for linecount argument
#
if (isset($linecount) && $linecount != "") {
    if (! TBvalid_integer($linecount)) {
	PAGEARGERROR("Illegal characters in linecount!");
    }
    $optarg .= " -l $linecount";
}

#
# A cleanup function to keep the child from becoming a zombie.
#
$fp = 0;

function SPEWCLEANUP()
{
    global $fp;

    if (connection_aborted() && $fp) {
	pclose($fp);
    }
    exit();
}
register_shutdown_function("SPEWCLEANUP");

$fp = popen("$TBSUEXEC_PATH $uid nobody webspewconlog $optarg $node_id", "r");
if (! $fp) {
    USERERROR("Spew console log failed!", 1);
}

header("Content-Type: text/plain; charset=us-ascii");
header("X-Content-Type-Options: nosniff");
header("Expires: Mon, 26 Jul 1997 05:00:00 GMT");
header("Cache-Control: no-cache, must-revalidate");
header("Pragma: no-cache");
flush();
while (!feof($fp)) {
    $string = fgets($fp, 1024);
    echo "$string";
    flush();
}
pclose($fp);
$fp = 0;

?>
