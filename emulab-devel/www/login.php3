<?php
#
# Copyright (c) 2000-2021 University of Utah and the Flux Group.
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
$optargs = OptionalPageArguments("login",    PAGEARG_STRING,
				 "uid",      PAGEARG_STRING,
				 "password", PAGEARG_PASSWORD,
				 "key",      PAGEARG_STRING,
				 "vuid",     PAGEARG_STRING,
				 "simple",   PAGEARG_BOOLEAN,
				 "adminmode",PAGEARG_BOOLEAN,
				 "referrer", PAGEARG_URL,
				 "error",    PAGEARG_STRING);
				 
# Allow adminmode to be passed along to new login. Handy for letting admins
# log in when NOLOGINS() is on.
if (!isset($adminmode)) {
    $adminmode = 0;
}
# Display a simpler version of this page
if (! isset($simple)) {
    $simple = 0;
}
if (! isset($key)) {
    $key = null;
}
if (! isset($error)) {
    $error = null;
}
# For redirect from the geni tool login.
$isgenitool = 0;

if (! isset($referrer)) {
    $referrer = null;
}

# If redirecting from the geni tool, show a different message.
if (isset($referrer) && preg_match("/getsslcertjs/", $referrer)) {
    $isgenitool = 1;
}

#
# Turn off some of the decorations and menus for the simple view
#
if ($simple) {
    $view = array('hide_banner' => 1, 'hide_copyright' => 1,
	'hide_sidebar' => 1);
} else {
    $view = array();
}

if (NOLOGINS() && !$adminmode) {
    PAGEHEADER("Login", $view);

    USERERROR("Sorry. The Web Interface is ".
	      "<a href=nologins.php3>Temporarily Unavailable!</a>", 1);

    PAGEFOOTER($view);
    die("");
}

#
# Must not be logged in already.
#
if (($this_user = CheckLogin($status))) {
    $this_webid = $this_user->webid();
    
    if ($status & CHECKLOGIN_LOGGEDIN) {
	#
	# If doing a verification for the logged in user, zap to that page.
	# If doing a verification for another user, then must login in again.
	#
	if (isset($key) && (!isset($vuid) || $vuid == $this_webid)) {
	    header("Location: $TBBASE/verifyusr.php3?key=$key");
	    return;
	}

	PAGEHEADER("Login",$view);

	echo "<h3>
              You are still logged in. Please log out first if you want
              to log in as another user!
              </h3>\n";

	PAGEFOOTER($view);
	die("");
    }
}

#
# Spit out the form.
#
# The uid can be an email address, and in fact defaults to that now. 
# 
function SPITFORM($uid, $key, $referrer, $error, $adminmode, $simple, $view)
{
    global $TBDB_UIDLEN, $TBBASE;
    global $isgenitool;
    global $UI_EXTERNAL_ACCOUNTS;
    
    PAGEHEADER("Login",$view);

    if ($isgenitool) {
	$premessage = "A request from a <b>Geni Tool</b> requres you to login<br>";
    }
    else {
	$premessage = "Please login to our secure server.";
    }

    if ($error) {
	echo "<center>";
        echo "<font size=+1 color=red>";
    	switch ($error) {
        case "failed": 
            echo "Login attempt failed! Please try again.";
            break;
        case "notloggedin":
	    if (! $isgenitool) {
		echo "You do not appear to be logged in!";
		$premessage = "Please log in again.";
	    }
            break;
        case "timedout":
	    echo "Your login has timed out!";
	    if (! $isgenitool) {
		$premessage = "Please log in again.";
	    }
	    break;
	default:
	    echo "Unknown Error ($error)!";
        }
        echo "</font>";
        echo "</center><br>\n";
    }

    echo "<center>
          <font size=+1>
          $premessage<br>
          (You must have cookies enabled)
          </font>
          </center>\n";

    $pagearg = "";
    if ($adminmode == 1)
	$pagearg  = "?adminmode=1";
    if ($key)
	$pagearg .= (($adminmode == 1) ? "&" : "?") . "key=$key";

    echo "<table align=center border=1>
          <form action='${TBBASE}/login.php3${pagearg}' method=post>
          <tr>
              <td>Email Address:<br>
                   <font size=-2>(or UserName)</font></td>
              <td><input type=text
                         value=\"$uid\"
                         name=uid size=30></td>
          </tr>
          <tr>
              <td>Password:</td>
              <td><input type=password name=password size=12></td>
          </tr>
          <tr>
             <td align=center colspan=2>
                 <b><input type=submit value=Login name=login></b></td>
          </tr>\n";
    
    if ($referrer) {
	echo "<input type=hidden name=referrer value='$referrer'>\n";
    }

    if ($simple) {
	echo "<input type=hidden name=simple value=$simple>\n";
    }

    echo "</form>
          </table>\n";

    if ($UI_EXTERNAL_ACCOUNTS == 0) {
	echo "<center><h2>
	    <a href='password.php3'>Forgot your password?</a>
	    </h2></center>\n";
    }
}

#
# If not clicked, then put up a form.
#
if (! isset($login)) {
    # Allow page arg to override what we think is the UID to log in as.
    # Use email address now, for the login uid. Still allow real uid though.
    if (isset($vuid)) {
	# For login during verification step, from email message.
	$login_id = $vuid;
    }
    else {
	$login_id = REMEMBERED_ID();
    }

    SPITFORM($login_id, $key, $referrer, $error, $adminmode, $simple, $view);
    PAGEFOOTER($view);
    return;
}

#
# Login clicked.
#
$STATUS_LOGGEDIN  = 1;
$STATUS_LOGINFAIL = 2;
$login_status     = 0;
$adminmode        = (isset($adminmode) && $adminmode == 1);

if (!isset($uid) || $uid == "" || !isset($password) || $password == "") {
    $login_status = $STATUS_LOGINFAIL;
}
else {
    $dologin_status = DOLOGIN($uid, $password, $adminmode);

    if ($dologin_status == DOLOGIN_STATUS_WEBFREEZE) {
	# Short delay.
	sleep(1);

	PAGEHEADER("Login", $view);
	echo "<h4>
              Your account has been frozen due to earlier login attempt
              failures. You must contact $TBMAILADDR to have your account
              restored. <br> <br>
              Please do not attempt to login again; it will not work!
              </h4>\n";
	PAGEFOOTER($view);
	die("");
    }
    else if ($dologin_status == DOLOGIN_STATUS_IPFREEZE) {
	# Short delay.
	sleep(1);
	$IP = $_SERVER['REMOTE_ADDR'];

	PAGEHEADER("Login", $view);
	echo "<h4>
              There have been too many failures from your IP address, we
              have blocked $IP from further attempts.
              You must contact $TBMAILADDR to have this IP unblocked.
              <br> <br>
              Please do not attempt to login again; it will not work!
              </h4>\n";
	PAGEFOOTER($view);
	die("");
    }
    else if ($dologin_status == DOLOGIN_STATUS_INACTIVE) {
	# Short delay.
	sleep(1);

	PAGEHEADER("Login", $view);
	echo "<h4>
              Your account has gone <b>inactive</b> since it has been so
              long since your last login. Please contact $TBMAILADDR 
              to have your account restored. <br> <br>
              Please do not attempt to login again; it will not work!
              </h4>\n";
	PAGEFOOTER($view);
	die("");
    }
    else if ($dologin_status == DOLOGIN_STATUS_NOGENIUSER) {
	# Short delay.
	sleep(1);

	PAGEHEADER("Login", $view);
	echo "<h4>
              This account was created by logging in via the <b>Geni Login</b>
              button. Login not allowed.</h4>\n";
	PAGEFOOTER($view);
	die("");
    }
    else if ($dologin_status == DOLOGIN_STATUS_OKAY) {
	$login_status = $STATUS_LOGGEDIN;
    }
    else {
	# Short delay.
	sleep(1);
	$login_status = $STATUS_LOGINFAIL;
    }
}

#
# Failed, then try again with an error message.
# 
if ($login_status == $STATUS_LOGINFAIL) {
    SPITFORM($uid, $key, $referrer, "failed", $adminmode, $simple, $view);
    PAGEFOOTER($view);
    return;
}

if (isset($key)) {
    #
    # If doing a verification, zap to that page.
    #
    header("Location: $TBBASE/verifyusr.php3?key=$key");
}
elseif (isset($referrer)) {
    #
    # Zap back to page that started the login request.
    #
    header("Location: $referrer");
}
else {
    #
    # Zap back to front page in secure mode.
    # 
    header("Location: $TBBASE/");
}
return;

?>
