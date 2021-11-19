<?php
#
# Copyright (c) 2000-2019 University of Utah and the Flux Group.
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

#
# Verify page arguments.
#
$reqargs = RequiredPageArguments("user",       PAGEARG_USER,
				 "key",        PAGEARG_STRING);
$optargs = OptionalPageArguments("redirected", PAGEARG_BOOLEAN);

if (! $PEER_ENABLE) {
    USERERROR("No Peer Portal", 1);
}

#
# Need this extra redirect so that the cookies get set properly. 
#
if (!isset($redirected) || $redirected == 0) {
    $uri = $_SERVER['REQUEST_URI'] . "&redirected=1";

    header("Location: https://$WWWHOST". $uri);
    return;
}

#
# Check the login table for the user, and see if the key is really
# the md5 of the login hash. If so, do a login. 
#
$target_uid = $user->uid();
$safe_key   = addslashes($key);

$query_result =
    DBQueryFatal("select * from login ".
		 "where uid='$target_uid' and hashhash='$safe_key' and ".
		 "      timeout > UNIX_TIMESTAMP(now())");
if (!mysql_num_rows($query_result)) {
    # Short delay.
    sleep(1);

    PAGEERROR("Invalid peer login request");
}
# Delete the entry so it cannot be reused, even on failure.
DBQueryFatal("delete from login ".
	     "where uid='$target_uid' and hashhash='$safe_key'");

#
# Now do the login, which can still fail.
#  
$dologin_status = DOLOGIN($user->uid(), "", 0, 1);

if ($dologin_status == DOLOGIN_STATUS_WEBFREEZE) {
    # Short delay.
    sleep(1);

    PAGEHEADER("Login");
    echo "<h3>
              Your account has been frozen due to earlier login attempt
              failures. You must contact $TBMAILADDR to have your account
              restored. <br> <br>
              Please do not attempt to login again; it will not work!
              </h3>\n";
    PAGEFOOTER();
    die("");
}
else if ($dologin_status != DOLOGIN_STATUS_OKAY) {
    # Short delay.
    sleep(1);
    PAGEHEADER("Login");

    echo "<h3>Peer login failed. Please contact $TBMAILADDR</h3>\n";
    PAGEFOOTER();
    die("");
}
else {
    #
    # Zap back to front page in secure mode.
    # 
    header("Location: $TBBASE/showuser.php3?user=$target_uid");
}

?>
