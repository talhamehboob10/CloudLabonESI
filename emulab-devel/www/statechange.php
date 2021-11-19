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
include("defs.php3");

$currentusage  = 0;

#
# Only known and logged in users.
#
$this_user = CheckLoginOrDie();
$uid       = $this_user->uid();
$isadmin   = ISADMIN();

PAGEBEGINNING("Experiment State Change", 0, 1);

#
# Verify page arguments.
#
$reqargs = RequiredPageArguments("experiment", PAGEARG_EXPERIMENT,
				 "state",      PAGEARG_STRING);

# Need these below.
$pid = $experiment->pid();
$eid = $experiment->eid();

echo "<div class=contentbody id=statechange>\n";
echo "<br><br><font size=+1>
          Emulab experiment $pid/$eid is now $state.</font><br>\n";
echo "<br><br>\n";
echo "<center><button name=close type=button onClick='window.close();'>";
echo "Close Window</button></center>\n";
echo "</div>\n";
echo "</body></html>";

?>
