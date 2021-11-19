<?php
#
# Copyright (c) 2000-2011 University of Utah and the Flux Group.
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
# Only known and logged in users allowed.
#
$this_user = CheckLoginOrDie();

if (!ISADMIN()) {
    USERERROR("You do not have permission to do this!", 1);
}

#
# Verify arguments.
#
$reqargs = RequiredPageArguments("target_user", PAGEARG_USER);
$target_uid = $target_user->uid();

if (DOLOGIN_MAGIC($target_user->uid(), $target_user->uid_idx()) < 0) {
    USERERROR("Could not log you in as $target_uid", 1);
}
# So the menu and headers get spit out properly.
$_COOKIE[$TBNAMECOOKIE] = $target_uid;

PAGEHEADER("SU as User");

echo "<center>";
echo "<br><br>";
echo "<font size=+2>You are now logged in as <b>$target_uid</b></font>\n";
echo "<br><br>";
echo "<font size=+1>Be Careful!</font>\n";
echo "</center>";

sleep(2);
PAGEREPLACE($TBBASE);

#
# Standard Testbed Footer
# 
PAGEFOOTER();
?>
