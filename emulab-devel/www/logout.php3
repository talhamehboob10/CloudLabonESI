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
require("defs.php3");

# Get current login.
$this_user = CheckLoginOrDie(CHECKLOGIN_MODMASK);
$uid       = $this_user->uid();
$isadmin   = ISADMIN();

#
# Verify page arguments.
#
$optargs = OptionalPageArguments("target_user",   PAGEARG_USER,
				 "next_page",     PAGEARG_STRING);

if (isset($target_user)) {
    # Only admin users can logout someone other then themself.
    if (!$isadmin && !$target_user->SameUser($this_user)) {
	PAGEHEADER("Logout");
	echo "<center>
                  <h3>You do not have permission to logout other users!</h3>
              </center>\n";
	PAGEFOOTER();
    }
}
else {
    $target_user = $this_user;
}
$target_user = $this_user;
$target_uid  = $uid;

if (DOLOGOUT($target_user) != 0) {
    PAGEHEADER("Logout");
    echo "<center><h3>Logout '$target_uid' failed!</h3></center>\n";
    PAGEFOOTER();
    return;
}

#
# Success. Zap the user back to the front page, in nonsecure mode, or a page
# the caller specified
# 
if (isset($next_page)) {
    header("Location: $next_page");
} else {
    header("Location: $TBBASE/");
}
?>


