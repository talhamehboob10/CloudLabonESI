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
include_once("node_defs.php");

#
# Only known and logged in users can do this.
#
$this_user = CheckLoginOrDie();
$uid       = $this_user->uid();
$isadmin   = ISADMIN();

if (!$isadmin && !STUDLY()) {
    USERERROR("You are not allowed to view this page!", 1);
}

#
# Verify page arguments.
#
$optargs = OptionalPageArguments("type",        PAGEARG_STRING);

#
# Standard Testbed Header
#
PAGEHEADER("Node Control Center");

$query_result =
    DBQueryFatal("select n.inception,util.*, ".
		 "  UNIX_TIMESTAMP(now())-UNIX_TIMESTAMP(n.inception) as age ".
		 "  from node_utilization as util ".
		 "left join nodes as n on n.node_id=util.node_id ".
		 "left join node_types as t on t.type=n.type ".
		 "where n.inception is not null and t.class='pc' and ".
		 "      role='testnode'" .
		 "order BY priority");

if (mysql_num_rows($query_result) == 0) {
    echo "<center>Oops, no nodes to show you!</center>";
    PAGEFOOTER();
    exit();
}

echo "<center>
      <table id='nodetable' align=center cellpadding=2 border=1>
      <thead class='sort'>
        <tr>
         <th>Node ID</th>
         <th>Inception Date</th>
         <th align=center>Age<br>(seconds)</th>
         <th align=center>Free<br>(seconds)</th>
         <th align=center>Free<br>(percent)</th>
         <th align=center>Alloc<br>(seconds)</th>
         <th align=center>Alloc<br>(percent)</th>
         <th align=center>Down<br>(seconds)</th>
         <th align=center>Down<br>(percent)</th>
        </tr>
      </thead>\n";

while ($row = mysql_fetch_array($query_result)) {
    $node_id            = $row["node_id"];
    $inception          = $row["inception"];
    $age                = $row["age"];
    $alloctime          = $row["allocated"];
    $downtime           = $row["down"];
    $freetime           = $age - ($alloctime + $downtime);
    $allocpercent       = sprintf("%.3f", ($alloctime / $age) * 100);
    $freepercent        = sprintf("%.3f", ($freetime / $age) * 100);
    $downpercent        = sprintf("%.3f", ($downtime / $age) * 100);
    $url                = CreateURL("shownode", URLARG_NODEID, $node_id);

    echo "<tr>
           <td><a href='$url'>$node_id</a></td>
           <td>$inception</td>
           <td>$age</td>
           <td>$freetime</td>
           <td>$freepercent</td>
           <td>$alloctime</td>
           <td>$allocpercent</td>
           <td>$downtime</td>
           <td>$downpercent</td>
          </tr>\n";
}
echo "</table></center>\n";

echo "<script type='text/javascript' language='javascript'>
        sorttable.makeSortable(getObjbyName('nodetable'));
      </script>\n";

#
# Standard Testbed Footer
# 
PAGEFOOTER();
?>
