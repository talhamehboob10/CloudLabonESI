<?php
#
# Copyright (c) 2000-2012 University of Utah and the Flux Group.
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
require("defs.php3");

#
# Spit back a text message we can display to the user on the console
# of the node running the checkin. We could return an http error, but
# that would be of no help to the user on the other side.
#
function SPITSTATUS($code, $msg)
{
    header("HTTP/1.0 $code $msg");
    exit();
}

# Required arguments
$reqargs = RequiredPageArguments("xmlstuff",   PAGEARG_ANYTHING);

$xmlname = tempnam("/tmp", "sitecheckin");
if (! $xmlname) {
    TBERROR("Could not create temporary filename", 0);
    SPITSTATUS(404, "Could not create temporary file!");
}
if (! ($fp = fopen($xmlname, "w"))) {
    TBERROR("Could not open temp file $xmlname", 0);
    SPITSTATUS(404, "Could not open temporary file!");
}
fwrite($fp, $xmlstuff);
fclose($fp);
chmod($xmlname, 0666);

#
# Invoke the backend and return the status. 
#
$retval = SUEXEC("elabman", $TBADMINGROUP, "websitecheckin $xmlname",
		 SUEXEC_ACTION_IGNORE);
if ($retval) {
    SUEXECERROR(SUEXEC_ACTION_CONTINUE);
    SPITSTATUS(404, "Could not do a site checkin!");
}
unlink($xmlname);

?>
