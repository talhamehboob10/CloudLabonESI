<?php
#
# Copyright (c) 2006, 2007 University of Utah and the Flux Group.
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
$optargs = OptionalPageArguments("showevents", PAGEARG_BOOLEAN);

# Need these below.
$pid = $experiment->pid();
$eid = $experiment->eid();

#
# Verify permission.
#
if (!$experiment->AccessCheck($this_user, $TB_EXPT_READINFO)) {
    USERERROR("Not enough permission to view experiment $pid/$eid", 1);
}

$output = array();
$retval = 0;

if (isset($showevents) && $showevents) {
    $flags = "-v";
}
else {
    # Show event summary and firewall info.
    $flags = "-b -e -f";
}

$result =
    exec("$TBSUEXEC_PATH $uid $TBADMINGROUP webtbreport $flags $pid $eid",
	 $output, $retval);

header("Content-Type: text/plain");
for ($i = 0; $i < count($output); $i++) {
    echo "$output[$i]\n";
}
echo "\n";

?>
