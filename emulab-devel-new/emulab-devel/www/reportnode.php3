<?php
#
# Copyright (c) 2005-2013 University of Utah and the Flux Group.
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
include_once("node_defs.php");

#
# Only known and logged in users.
#
$this_user = CheckLoginOrDie();
$uid       = $this_user->uid();
$isadmin   = ISADMIN();

#
# Verify page arguments.
#
$reqargs = RequiredPageArguments("node",       PAGEARG_NODE);
$optargs = OptionalPageArguments("message",    PAGEARG_ANYTHING,
				 "canceled",   PAGEARG_STRING,
				 "send",       PAGEARG_STRING);

#
# Standard Testbed Header
#
PAGEHEADER("Report a Problem with a Node");

echo $node->PageHeader();
echo "<br>";

#
# We run this twice. The first time we are checking for a confirmation
# by putting up a form. The next time through the confirmation will be
# set. Or, the user can hit the cancel button, in which case we should
# probably redirect the browser back up a level.
#
if (isset($canceled) && $canceled) {
    echo "<center><h3>Problem report canceled!</h3>
          </center>\n";
    PAGEFOOTER();
    return;
}

if (!isset($send)) {
    $node_id = $node->node_id();
    $url = CreateURL("reportnode", $node);

    echo "<br>";
    echo "If you would like to report a problem with $node_id, please ";
    echo "use the box below to describe the problem, and someone from the ";
    echo "operations staff will get back to you shortly. Problems you should ";
    echo "report are hardware problems, connectivity problems, etc.";
    echo "<br><br>\n";
   
    echo "<form action='$url' method=post>\n";
    echo "<table border=1>\n";
    echo "  <tr><td><textarea rows=5 cols=60 name=message></textarea>
	      </td></tr>
	    <tr><td><center>\n";
    echo "    <input type=submit name=send value='Send Report'>\n";
    echo "    &nbsp; &nbsp;\n";
    echo "    <input type=submit name=canceled value=Cancel>\n";
    echo "    </center></td></tr>\n";
    echo "</table>\n";
    echo "</form>\n";

    PAGEFOOTER();
    return;
}

$node_id = $node->node_id();
$user_name  = $this_user->name();
$user_email = $this_user->email();

TBMAIL($TBMAIL_OPS,
       "Problem with $node_id - Please help!",
       "Hi. I am having a problem with $node_id.\n\n".
       "$message\n",
       "From: $user_name <$user_email>");

echo "<center><h2>Message sent!</h2>
      </center>\n";

#
# Standard Testbed Footer
# 
PAGEFOOTER();
?>
