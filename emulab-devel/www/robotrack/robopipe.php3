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

function SPITERROR($code, $msg)
{
    header("HTTP/1.0 $code $msg");
    exit();
}

#
# Only known and logged in users.
#
if (! ($this_user = CheckLogin($check_status)) ||
    ($check_status & CHECKLOGIN_LOGGEDIN) != CHECKLOGIN_LOGGEDIN) {
    SPITERROR(401, "Not logged in");
}
$uid = $this_user->uid();

$reqargs = RequiredPageArguments("pid",        PAGEARG_STRING,
				 "eid",        PAGEARG_STRING);
$optargs = OptionalPageArguments("building",   PAGEARG_STRING,
				 "floor",      PAGEARG_STRING);

if (isset($pid) && $pid != "" && isset($eid) && $eid != "") {
    if (!TBvalid_pid($pid)) {
	SPITERROR(400, "Invalid project ID.");
    }
    if (!TBvalid_eid($eid)) {
	SPITERROR(400, "Invalid experiment ID.");
    }

    if (! ($experiment = Experiment::LookupByPidEid($pid, $eid))) {
	SPITERROR(400, "The experiment $pid/$eid is not a valid experiment!");
    }
    if (!$experiment->AccessCheck($this_user, $TB_EXPT_READINFO)) {
	USERERROR(401,
		  "You do not have permission to view experiment $pid/$eid!");
    }
}
else {
    SPITERROR(400, "Must supply pid and eid arguments");
}

#
# Verify page arguments. Allow user to optionally specify building/floor.
#
if (isset($building) && $building != "") {
    # Sanitize for the shell.
    if (!preg_match("/^[-\w]+$/", $building)) {
	SPITERROR(400, "Invalid building argument.");
    }
    # Optional floor argument. Sanitize for the shell.
    if (isset($floor) && !preg_match("/^[-\w]+$/", $floor)) {
	SPITERROR(400, "Invalid floor argument.");
    }
}
else {
    $building = "MEB-ROBOTS";
    $floor    = 4;
}

#
# Need the locpiper port for this experiment.
#
$query_result =
    DBQueryFatal("select locpiper_port from experiments ".
	         "where pid='$pid' and eid='$eid'");
if (!mysql_num_rows($query_result)) {
    SPITERROR(400, "No such experiment!");
}
else {
    $row = mysql_fetch_array($query_result);
    $locpiper_port = $row["locpiper_port"];
}

# Initial goo.
header("Content-Type: text/plain");
header("Expires: Mon, 26 Jul 1997 05:00:00 GMT");
header("Cache-Control: no-cache, must-revalidate");
header("Pragma: no-cache");
flush();

if (isset($fake)) {
    #
    # Just loop forever writing out some stuff.
    #
    $x1 = 100;
    $y1 = 100;

    $x2 = 700;
    $y2 = 200;

    $i = 0;
    do {
	echo "garcia1 X=$x1,Y=$y1,OR=-90.0,DX=700,DY=300,DOR=-90.0\n";
	echo "garcia2 X=$x2,Y=$y2,OR=-5.66424,BATV=50.34567,BAT%=100.0\n";
	echo "garcia3 X=300,Y=300,OR=0.0,BATV=90,BAT%=95\n";
	flush();
	sleep(1);

	$x1 +=2;
	$y1 +=2;
	$x2 -=2;
	$y2 -=2;
    } while ($i < 100);
    return;
}

#
# Clean up when the remote user disconnects
#
$socket = 0;

function SPEWCLEANUP()
{
    global $socket;

    if (!$socket || !connection_aborted()) {
	exit();
    }
    fclose($socket);
    exit();
}
#ignore_user_abort(1);
set_time_limit(0);
register_shutdown_function("SPEWCLEANUP");

# Avoid PHP error reporting in sockopen that confuse the headers.
error_reporting(0);

$socket = fsockopen("localhost", $locpiper_port);
if (!$socket) {
    SPITERROR(404, "Error opening locpiper socket - $errstr");
}

while (! feof($socket)) {
    $buffer = fgets($socket, 1024);
    echo $buffer;
    flush();
}
fclose($socket);

?>
