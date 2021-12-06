<?php
#
# Copyright (c) 2000-2010 University of Utah and the Flux Group.
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

chdir("..");
include("defs.php3");

# this is just saving data; it isnt human readable.

#
# Verify page arguments.
#
$optargs = OptionalPageArguments("guid", PAGEARG_INTEGER,
				 "nsref", PAGEARG_INTEGER,
				 "nsdata", PAGEARG_ANYTHING,
				 "uid", PAGEARG_STRING);

#
# Only known and logged in users.
#
if (isset($guid) && preg_match('/^[0-9]+$/', $guid)) {
	$uid = $guid;
}
else {
	if (isset($uid)) {
	        $this_user = CheckLoginOrDie();
	        $uid       = $this_user->uid();
	}
	else {
		USERERROR("Need to send guid or uid!", 1);
        } 
}

if (!isset($nsdata)) {
	USERERROR("Need to send NSFILE!", 1);
} 

if (!isset($nsref) || !preg_match('/^[0-9]+$/', $nsref)) {
	USERERROR("Need to send valid NSREF!", 1);
}

$nsfilename = "/tmp/$uid-$nsref.nsfile";

if (! ($fp = fopen($nsfilename, "w"))) {
	TBERROR("Could not create temporary file $nsfile", 1);
}

if (strlen( $nsdata ) > 50000) {
	$nsdata = "#(NS file was >50kb big)\n" .
                  "!!! ERROR: NS File Truncated !!!\n";
}

fwrite($fp, $nsdata);
fclose($fp);

header("Content-Type: text/plain");
echo "success!";
?>