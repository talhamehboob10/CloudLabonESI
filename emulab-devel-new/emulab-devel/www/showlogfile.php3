<?php
#
# Copyright (c) 2005, 2006, 2007 University of Utah and the Flux Group.
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

$reqargs = RequiredPageArguments("experiment", PAGEARG_EXPERIMENT);

# Need these below.
$pid = $experiment->pid();
$eid = $experiment->eid();

if (! $experiment->AccessCheck($this_user, $TB_EXPT_READINFO)) {
    USERERROR("You do not have permission to view the log for $pid/$eid!", 1);
}

#
# Check for a logfile. This file is transient, so it could be gone by
# the time we get to reading it.
#
$logfile = $experiment->GetLogfile();
if (! $logfile) {
    USERERROR("Experiment $pid/$eid is no longer in transition!", 1);
}

#
# Standard Testbed Header
#
PAGEHEADER("Experiment Activity Log");

echo $experiment->PageHeader();
echo "<br /><br />\n";

STARTWATCHER($experiment);
# This spits out the frame.
STARTLOG($logfile);

#
# Standard Testbed Footer
# 
PAGEFOOTER();
?>
