<?php
#
# Copyright (c) 2005-2012 University of Utah and the Flux Group.
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
# No Testbed Header; we zap back.
#

#
# Only known and logged in users.
#
$this_user = CheckLoginOrDie();
$uid       = $this_user->uid();
$isadmin   = ISADMIN();

#
# Verify page arguments.
#
$reqargs = RequiredPageArguments("listname",        PAGEARG_STRING);
$optargs = OptionalPageArguments("canceled",        PAGEARG_BOOLEAN,
				 "confirmed",       PAGEARG_BOOLEAN);

if (! TBvalid_mailman_listname($listname)) {
    $listname = CleanString($listname);
    PAGEARGERROR("Invalid characters in $listname!");
}

#
# Grab the DB state.
#
$query_result = DBQueryFatal("select owner_idx from mailman_listnames ".
			     "where listname='$listname'");

if (!mysql_num_rows($query_result)) {
    USERERROR("No such list $listname!", 1);
}
$row = mysql_fetch_array($query_result);
$owner_idx = $row['owner_idx'];

#
# Verify permission.
#
if ($this_user->uid_idx() != $owner_idx && !$isadmin) {
    USERERROR("You do not have permission to delete list $listname!", 1);
}

#
# We run this twice. The first time we are checking for a confirmation
# by putting up a form. The next time through the confirmation will be
# set. Or, the user can hit the cancel button, in which case we should
# probably redirect the browser back up a level.
#
if (isset($canceled) && $canceled) {
    PAGEHEADER("Delete a Mailman List");
    
    echo "<center><h2>
          List removal canceled!
          </h2></center>\n";
    
    PAGEFOOTER();
    return;
}

if (!isset($confirmed)) {
    PAGEHEADER("Delete a Mailman List");
    
    echo "<center><h2>
          Are you <b>REALLY</b> sure you want to remove $listname
          </h2>\n";
    
    echo "<form action='delmmlist.php3?listname=$listname' method=post>";
    echo "<b><input type=submit name=confirmed value=Confirm></b>\n";
    echo "<b><input type=submit name=canceled value=Cancel></b>\n";
    echo "</form>\n";
    echo "</center>\n";

    PAGEFOOTER();
    return;
}

PAGEHEADER("Delete a Mailman List");
STARTBUSY("Deleting list $listname");
SUEXEC($uid, $TBADMINGROUP, "webdelmmlist -u $listname", SUEXEC_ACTION_DIE);
STOPBUSY();

#
# Worked, so delete the record from the DB.
#
DBQueryFatal("delete from mailman_listnames ".
	     "where listname='$listname'");
#
# Back to the lists list.
# 
PAGEREPLACE("showmmlists.php3");

#
# Standard Testbed Footer
# 
PAGEFOOTER();
?>
