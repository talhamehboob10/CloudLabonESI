<?php
#
# Copyright (c) 2000-2014 University of Utah and the Flux Group.
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

# This will not return if its a sajax request.
include("showlogfile_sup.php3");

#
# Verify page arguments.
#
$reqargs = RequiredPageArguments("experiment", PAGEARG_EXPERIMENT);
$optargs = OptionalPageArguments("canceled",   PAGEARG_BOOLEAN,
				 "confirmed",  PAGEARG_BOOLEAN,
				 "level",      PAGEARG_INTEGER,
				 "clear",      PAGEARG_BOOLEAN);

# Need these below.
$pid = $experiment->pid();
$eid = $experiment->eid();
$unix_gid = $experiment->UnixGID();
$project  = $experiment->Project();
$unix_pid = $project->unix_gid();

# Canceled operation redirects back to showexp page. See below.
if (isset($canceled) && $canceled) {
    header("Location: " . CreateURL("showexp", $experiment));
    return;
}

#
# Standard Testbed Header, after checking for cancel above.
#
PAGEHEADER("Press the Panic Button!");

#
# Verify permissions.
#
if (!$experiment->AccessCheck($this_user, $TB_EXPT_MODIFY)) {
    USERERROR("You do not have permission to press/clear the panic button.", 1);
}

if (isset($level)) {
    if ($level < 1 || $level > 2) {
	USERERROR("Improper level argument", 1);
    }
}
else {
    $level = 1;
}
if (!isset($clear)) {
    $clear = 0;
}

echo $experiment->PageHeader();
echo "<br>\n";
    
#
# We run this twice. The first time we are checking for a confirmation
# by putting up a form. The next time through the confirmation will be
# set. Or, the user can hit the cancel button, in which case redirect the
# browser back up a level.
#
if (!isset($confirmed)) {
    echo "<center><h3><br>
          Are you <b>REALLY</b>
          sure you want to " . ($clear ? "clear" : "press") .
	  " the panic button for Experiment '$eid?'
          </h3>\n";

    $experiment->Show(1);

    $url = CreateURL("panicbutton", $experiment);
    
    echo "<form action='$url' method=post>";
    echo "<b><input type=submit name=confirmed value=Confirm></b>\n";
    echo "<b><input type=submit name=canceled value=Cancel></b>\n";
    echo "<b><input type=hidden name=level value=$level></b>\n";
    if ($clear) {
	echo "<b><input type=hidden name=clear value=$clear></b>\n";
    }
    echo "</form>\n";
    echo "</center>\n";

    PAGEFOOTER();
    return;
}

#
# We run a wrapper script that does all the work.
#
if ($clear) {
    $opt = "-r";
}
else {
    $opt = "-l $level";
}
$retval = SUEXEC($uid, "$unix_pid,$unix_gid", "webpanic -w $opt $pid $eid",
		 SUEXEC_ACTION_IGNORE);

#
# Fatal Error. Report to the user, even though there is not much he can
# do with the error. Also reports to tbops.
# 
if ($retval < 0) {
    SUEXECERROR(SUEXEC_ACTION_DIE);
    #
    # Never returns ...
    #
    die("");
}

#
# Exit status >0 means the operation could not proceed.
# Exit status =0 means the experiment is terminating in the background.
#
if ($retval) {
    echo "<h3>Panic Button failure</h3>";
    echo "<blockquote><pre>$suexec_output<pre></blockquote>";
}
else {
    if ($clear) {
	echo "<h3>Clearing the panic button!</h3>\n";
    }
    else {
	echo "<h3>Pressing the panic button!</h3>\n";
    }
    STARTLOG($experiment);
}

#
# Standard Testbed Footer
# 
PAGEFOOTER();
?>
