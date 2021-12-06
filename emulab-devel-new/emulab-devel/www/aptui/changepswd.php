<?php
#
# Copyright (c) 2000-2020 University of Utah and the Flux Group.
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
chdir("..");
include("defs.php3");
chdir("apt");
include("quickvm_sup.php");
$page_title = "Change Password";

RedirectSecure();

#
# Verify page arguments.
#
$optargs = OptionalPageArguments("user",      PAGEARG_USER,
				 "key",       PAGEARG_STRING,
                                 "reset",     PAGEARG_STRING);
#
# see if UI change password is disabled (e.g. passwords externally managed)
#
if ($UI_EXTERNAL_ACCOUNTS) {
    SPITUSERERROR("Password change disabled on this system");
    return;
}

#
# We use this page for both resetting a forgotten password, and for
# a logged in user to change their password. We use the "key" argument
# to tell us its a reset.
#
if (isset($key) || isset($reset)) {
    if (!isset($user)) {
	SPITUSERERROR("Missing user argument");
	return;
    }
    if (isset($reset)) {
        if ($reset == "" || !preg_match("/^[\w]+$/", $reset)) {
            SPITUSERERROR("Invalid reset hash in request");
            return;
        }
        # The complete key.
        $key = $reset;
    }
    else {
        # Half the key in the URL.
        $keyB = $key;
        # We also need the other half of the key from the browser.
        $keyA = (isset($_COOKIE[$TBAUTHCOOKIE]) ? $_COOKIE[$TBAUTHCOOKIE] : "");

        # If the browser part is missing, direct user to answer
        if ((isset($keyB) && $keyB != "") && (!isset($keyA) || $keyA == "")) {
            SPITUSERERROR("Oops, not able to proceed!<br>".
                          "Please read this ".
                          "<a href='https://gitlab.flux.utah.edu/emulab/emulab-devel/-/wikis/faq/I-Forgot-My-Password'>FAQ Entry</a>".
                          "to see what the likely cause is.", 1);
            return;
        }
        if (!isset($keyA) || $keyA == "" || !preg_match("/^[\w]+$/", $keyA) ||
            !isset($keyB) || $keyB == "" || !preg_match("/^[\w]+$/", $keyB)) {
            SPITUSERERROR("Invalid keys in request");
            return;
        }
        # The complete key.
        $key = $keyA . $keyB;
    }

    if (!$user->chpasswd_key() || !$user->chpasswd_expires()) {
	SPITUSERERROR("Why are you here?");
	return;
    }
    if ($user->chpasswd_key() != $key) {
	SPITUSERERROR("Invalid key in request.");
	return;
    }
    if (time() > $user->chpasswd_expires()) {
	SPITUSERERROR("Your key has expired. Please request a
               <a href='forgotpswd.php'>new key</a>.");
	return;
    }
    $needold = 0;
    $key = "'$key'";
}
else {
    #
    # The user must be logged in.
    #
    $this_user = CheckLoginOrRedirect(CHECKLOGIN_USERSTATUS|
				      CHECKLOGIN_PSWDEXPIRED);

    # Check for admin setting another users password.
    if (!isset($user)) {
	$user = $this_user;
    }
    elseif (!$this_user->SameUser($user) && !ISADMIN()) {
	SPITUSERERROR("Not enough permission to reset password for user");
	return;
    }
    #
    # admins do not need to provide an old password when changing another
    # user password, but they need it to change their own password.
    #
    if ((ISADMIN() && !$this_user->SameUser($user)) ||
        ($user->nonlocal_id() && $user->pswd() == "*")) {
        $needold = 0;
    }
    else {
        $needold = 1;
    }
    $key = "null";
}
$uid = $user->uid();

SPITHEADER(1);
echo "<script>\n";
echo "window.NEEDOLD = $needold;\n";
echo "window.KEY = $key;\n";
echo "window.USER = '$uid';\n";
echo "</script>\n";
echo "<div id='page-body'></div>\n";
echo "<div id='oops_div'></div>\n";
echo "<div id='waitwait_div'></div>\n";
echo "</script>\n";

REQUIRE_UNDERSCORE();
REQUIRE_SUP();
REQUIRE_APTFORMS();
SPITREQUIRE("js/changepswd.js");

AddTemplateList(array("changepswd", "oops-modal", "waitwait-modal"));
SPITFOOTER();
?>
