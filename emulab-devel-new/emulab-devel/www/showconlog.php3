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
include_once("node_defs.php");

#
# Only known and logged in users can do this.
#
$this_user = CheckLoginOrDie();
$uid       = $this_user->uid();
$isadmin   = ISADMIN();

#
# Verify page arguments.
#
$reqargs = RequiredPageArguments("node",      PAGEARG_NODE);
$optargs = OptionalPageArguments("linecount", PAGEARG_INTEGER);
$node_id = $node->node_id();

#
# Standard Testbed Header
#
PAGEHEADER("Console Log for $node_id");

if (!$isadmin &&
    !$node->AccessCheck($this_user, $TB_NODEACCESS_READINFO)) {
    USERERROR("You do not have permission to view the console!", 1);
}

$url = CreateURL("spewconlog", $node);

#
# Look for linecount argument
#
if (isset($linecount) && $linecount != "") {
    $url .= "&linecount=$linecount";
}

echo $node->PageHeader();
echo "<br><br>\n";

echo "<center>
      <iframe src='$url'
              width=90% height=500 scrolling=auto frameborder=1>
      Your user agent does not support frames or is currently configured
      not to display frames. However, you may visit
      <A href='$url'>the log file directly.</A>
      </iframe></center>\n";

#
# Standard Testbed Footer
# 
PAGEFOOTER();
?>
