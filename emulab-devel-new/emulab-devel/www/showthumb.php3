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

#
# This script generates the contents of an image. No headers or footers,
# just spit back an image. The thumbs are public, so no checking is done.
# To obfuscate, do not use pid/eid, but rather use the resource index. 
#
$reqargs = RequiredPageArguments("idx", PAGEARG_INTEGER);

#
# Get the thumb from the DB. 
#
$query_result =
    DBQueryFatal("select thumbnail from experiment_resources ".
		 "where idx='$idx'");

if ($query_result && mysql_num_rows($query_result)) {
    $row  = mysql_fetch_array($query_result);
    $data = $row["thumbnail"];

    if (strlen($data)) {
	# Gack, this is easiest way to tell them apart.
	if (strncmp($data, "<svg", 4) == 0) {
	    header("Content-type: image/svg+xml");
	}
	else {   
	    header("Content-type: image/png");
	}
	echo "$data";
	return;
    }
}

# No Data. Spit back a stub image.
header("Content-type: image/gif");
readfile("coming-soon-thumb.gif");

#
# No Footer!
# 
?>
