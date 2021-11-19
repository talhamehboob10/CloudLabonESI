<?php
#
# Copyright (c) 2003-2012 University of Utah and the Flux Group.
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
require("defs.php3");

if (! $ISCLRHOUSE) {
    header("HTTP/1.0 404 Not Found");
    return;
}

#
# Note - this script is not meant to be called by humans! It returns no useful
# information whatsoever, and expects the client to fill in all fields
# properly.
#
$reqargs = RequiredPageArguments("cert", PAGEARG_ANYTHING);

# Silent error if unusually big.
if (strlen($cert) > 0x4000) {
    return;
}

$fname = tempnam("/tmp", "register_ca");
if (! $fname) {
    TBERROR("Could not create temporary filename", 0);
    return;
}
if (! ($fp = fopen($fname, "w"))) {
    TBERROR("Could not open temp file $fname", 0);
    return;
}
fwrite($fp, $cert);
fclose($fp);
chmod($fname, 0666);

$retval = SUEXEC("geniuser", $TBADMINGROUP, "webcacontrol -w $fname",
		 SUEXEC_ACTION_IGNORE);
unlink($fname);

if ($retval) {
    #
    # Want to return status to the caller.
    #
    header("HTTP/1.0 406 Not Acceptable");
}

?>
