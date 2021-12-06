<?php
#
# Copyright (c) 2000-2007 University of Utah and the Flux Group.
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

#
# Only known and logged in users.
#
$this_user = CheckLoginOrDie();
$uid       = $this_user->uid();
$isadmin   = ISADMIN();

#
# Verify page args
#
$reqargs = RequiredPageArguments("building",      PAGEARG_STRING,
				 "floor",         PAGEARG_STRING);

# Sanitize for the shell.
if (!preg_match("/^[-\w]+$/", $building)) {
    PAGEARGERROR("Invalid building argument.");
}
if (!preg_match("/^[-\w]+$/", $floor)) {
    PAGEARGERROR("Invalid floor argument.");
}

#
# Make sure it exists in the DB.
#
$query_result =
    DBQueryFatal("select pixels_per_meter from floorimages ".
		 "where building='$building' and floor='$floor'");
if (!mysql_num_rows($query_result)) {
    PAGEARGERROR("No such building/floor $building/$floor");
}

#
# Need cleanup "handler" to make sure temp files get deleted! 
#
function CLEANUP()
{
    global $prefix, $uid;

    #
    # The backend script (vis/floormap.in) removes all the temp files
    # with the -c option. Yucky, but file perms and owners make this
    # the easiest way to do it.
    # 
    if (isset($prefix)) {
	SUEXEC($uid, "nobody", "webfloormap -o $prefix -k ",
	       SUEXEC_ACTION_IGNORE);
	# This file does belong to the web server.
	unlink($prefix);
    }
    exit();
}
register_shutdown_function("CLEANUP");

#
# Create a tempfile to use as a unique prefix; it is not actually used but
# serves the same purpose (The script uses ${prefix}.jpg and ${prefix}.map .)
# 
$prefix = tempnam("/tmp", "floormap");

#
# Build the image.
# 
$perl_args = "-o $prefix -t -z -n -x -v -y -f $floor $building";

$retval = SUEXEC($uid, "nobody", "webfloormap $perl_args",
		 SUEXEC_ACTION_IGNORE);

if ($retval) {
    SUEXECERROR(SUEXEC_ACTION_USERERROR);
    # Never returns.
    die("");
}

#
# Now spit it back.
# 
if (($fp = fopen("${prefix}.jpg", "r"))) {
    header("Content-type: image/jpg");
    fpassthru($fp);
}
else {
    # No Data. Spit back a stub image.
    header("Content-type: image/gif");
    readfile("coming-soon-thumb.gif");
}
?>
