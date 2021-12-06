<?php
#
# Copyright (c) 2006-2011 University of Utah and the Flux Group.
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
# Only known and logged in users.
#
$this_user = CheckLoginOrDie();
$uid       = $this_user->uid();
$isadmin   = ISADMIN();

#
# Verify page arguments.
#
$reqargs = RequiredPageArguments("experiment", PAGEARG_EXPERIMENT);

# Need these below.
$pid = $experiment->pid();
$eid = $experiment->eid();
$project  = $experiment->Project();
$unix_pid = $project->unix_gid();

#
# Verify permission.
#
if (!$experiment->AccessCheck($this_user, $TB_EXPT_READINFO)) {
    USERERROR("You do not have permission to view events for $pid/$eid!", 1);
}

#
# A cleanup function to keep the child from becoming a zombie, since
# the script is terminated, but the children are left to roam.
#
$fp = 0;

function SPEWCLEANUP()
{
    global $fp;

    if (!$fp || !connection_aborted()) {
	exit();
    }
    pclose($fp);
    exit();
}
register_shutdown_function("SPEWCLEANUP");

if ($fp = popen("$TBSUEXEC_PATH $uid $unix_pid webspewevents -w $pid $eid", "r")) {
    header("Content-Type: text/plain");
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
}
else {
    USERERROR("Experiment $pid/$eid is no longer in transition!", 1);
}

?>
