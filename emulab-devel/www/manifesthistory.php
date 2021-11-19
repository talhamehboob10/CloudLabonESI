<?php
#
# Copyright (c) 2015 University of Utah and the Flux Group.
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
$optargs = OptionalPageArguments("uuid", PAGEARG_STRING,
				 "ch",   PAGEARG_BOOLEAN);

if (!isset($uuid)) {
    $uuid = "";
}
if (!isset($ch)) {
    $ch = 0;
}

if (! ($isadmin || STUDLY())) {
    PAGEHEADER("Geni History");
    
    USERERROR("You do not have permission to view Geni manifest history!", 1);
    
    PAGEFOOTER();
} else {
    $dblink  = GetDBLink(($ch ? "ch" : "cm"));
    $manifest_result = DBQueryFatal("select manifest from manifest_history ".
			     	    "where aggregate_uuid='$uuid' ".
			     	    "order by idx desc limit 1", $dblink);

    if (mysql_num_rows($manifest_result)) {
	$mrow = mysql_fetch_array($manifest_result);
	$manifest = $mrow["manifest"];

	header( "Content-Type: text/xml" );
	print "$manifest";
    } else {
        PAGEHEADER("Geni History");
    
        USERERROR("Manifest not found.", 1);
    
	PAGEFOOTER();
    }
}
