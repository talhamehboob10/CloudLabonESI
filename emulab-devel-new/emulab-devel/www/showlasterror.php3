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
$exptidx = $experiment->idx();

#
# Standard Testbed Header
#
PAGEHEADER("Last Error");

#
# Must have permission to view experiment details.
#
if (!$isadmin &&
    !$experiment->AccessCheck($this_user, $TB_EXPT_READINFO)) {
    USERERROR("You do not have permission to view experiment last error!", 1);
}

$query_result =
    DBQueryFatal("select e.cause,e.confidence,e.mesg,cause_desc ".
		 "   from experiment_stats as s,errors as e, causes as c ".
	         "where s.exptidx = $exptidx and e.cause = c.cause and ".
		 "      s.last_error = e.session and rank = 0");

if (mysql_num_rows($query_result) != 0) {
  $row = mysql_fetch_array($query_result);
  echo "<h2>$row[cause_desc]</h2>\n";
  echo "<pre>\n";
  echo htmlspecialchars($row["mesg"])."\n";
  echo "\n";
  echo "Cause: $row[cause]\n";
  echo "Confidence: $row[confidence]\n";
  echo "</pre>\n";
} else {
  echo "Nothing\n";
}

#
# Standard Testbed Footer
# 
PAGEFOOTER();
?>
