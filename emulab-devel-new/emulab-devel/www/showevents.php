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

# Need these below.
$pid = $experiment->pid();
$eid = $experiment->eid();
$url = CreateURL("spewevents", $experiment);

#
# Verify permission.
#
if (!$experiment->AccessCheck($this_user, $TB_EXPT_READINFO)) {
    USERERROR("You do not have permission to view events for $pid/$eid!", 1);
}

#
# Standard Testbed Header
#
PAGEHEADER("Watch Event Log");

echo $experiment->PageHeader();
echo "<br>\n";
echo "<br>\n";
echo "<b>Watch events as they are dispatched from the event scheduler.</b>";
echo "<br>\n";

echo "<div><iframe id='outputframe' ".
      "width=100% height=600 scrolling=auto border=4></iframe></div>\n";
    
echo "<script type='text/javascript' language='javascript'>\n";
echo "SetupOutputArea('outputframe', true);\n"; 
echo "</script>\n";

echo "<iframe id='inputframe' name='inputframe' width=0 height=0
              src='$url'
              onload='StopOutput();'
              border=0 style='width:0px; height:0px; border: 0px'>
      </iframe>\n";

echo "<script type='text/javascript' language='javascript'>\n";
echo "StartOutput('inputframe', 'outputframe');\n"; 
echo "</script>\n";

#
# Standard Testbed Footer
# 
PAGEFOOTER();
?>
