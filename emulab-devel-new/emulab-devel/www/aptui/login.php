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
chdir("..");
include("defs.php3");
chdir("apt");
include("quickvm_sup.php");
$page_title = "Login";
AddTemplate("waitwait-modal");

#
# Get current user in case we need an error message.
#
$this_user = CheckLogin($check_status);

#
# Verify page arguments.
#
$optargs = OptionalPageArguments("login",       PAGEARG_STRING,
				 "uid",         PAGEARG_STRING,
				 "password",    PAGEARG_PASSWORD,
				 "referrer",    PAGEARG_URL,
				 "from",        PAGEARG_STRING,
				 "adminmode",   PAGEARG_BOOLEAN,
                                 "cleanmode",   PAGEARG_BOOLEAN,
				 "ajax_request",PAGEARG_BOOLEAN);
if (! isset($referrer)) {
    $referrer = null;
}
# Allow adminmode to be passed along to new login. Handy for letting admins
# log in when NOLOGINS() is on.
if (!isset($adminmode)) {
    $adminmode = 0;
}
# For Rob to make screen shots. We do not want to use the cookie here,
# just the url argument.
if (isset($_GET['cleanmode']) && $_GET['cleanmode']) {
    $cleanmode = 1;
}
else {
    $cleanmode = 0;
}

if (NOLOGINS() && !$adminmode) {
    if ($ajax_request) {
	SPITAJAX_ERROR(1, "logins are temporarily disabled");
	exit();
    }
    SPITHEADER();
    SPITUSERERROR("Sorry, logins are temporarily disabled, ".
		  "please try again later.");
    echo "<script src='js/lib/jquery-2.0.3.min.js'></script>\n";
    SPITNULLREQUIRE();
    SPITFOOTER();
    return;
}

#
# Spit out the form.
# 
function SPITFORM($uid, $referrer, $error)
{
    global $PORTAL_PASSWORD_HELP;
    global $TBDB_UIDLEN, $TBBASE;
    global $ISAPT, $ISCLOUD, $ISPNET, $ISPOWDER, $PROTOGENI_GENIWEBLOGIN;
    global $adminmode, $cleanmode;
    global $UI_EXTERNAL_ACCOUNTS;

    header("Last-Modified: " . gmdate("D, d M Y H:i:s") . " GMT");
    header("Expires: Mon, 26 Jul 1997 05:00:00 GMT");
    header("Cache-Control: no-cache, max-age=0, must-revalidate, no-store");
    header("Pragma: no-cache");

    SPITHEADER();
 
    echo "<div class='row'>
          <div class='col-lg-6  col-lg-offset-3
                      col-md-6  col-md-offset-3
                      col-sm-8  col-sm-offset-2
                      col-xs-12 col-xs-offset-0'>\n";
    $action = "login.php";
    if ($adminmode || $cleanmode) {
        if ($adminmode && $cleanmode) {
            $action .= "?adminmode=1&cleanmode=1";
        }
        elseif ($adminmode) {
            $action .= "?adminmode=1";
        }
        elseif ($cleanmode) {
            $action .= "?cleanmode=1";
        }
    }
    echo "<form id='quickvm_login_form' role='form'
            method='post' action='$action'>\n";
    echo "<div class='panel panel-default'>
           <div class='panel-heading'>
              <h3 class='panel-title'>
                 Login</h3></div>
           <div class='panel-body form-horizontal'>\n";

    if ($error) {
        echo "<span class='help-block'><font color=red>";
    	switch ($error) {
        case "failed": 
            echo "Login attempt failed! Please try again.";
            break;
        case "notloggedin":
	    echo "You do not appear to be logged in!";
            break;
        case "timedout":
	    echo "Your login has timed out!";
	    break;
        case "alreadyloggedin":
	    echo "You are already logged in. Logout first?";
	    break;
	default:
	    echo "Unknown Error ($error)!";
        }
        echo "</font></span>";
    }
    if ($referrer) {
	echo "<input type=hidden name=referrer id='login_referrer' ".
            "value='$referrer'>\n";
    }
?>
             <div class='form-group'>
                <label for='uid' class='col-sm-2 control-label'>Username</label>
                <div class='col-sm-10'>
                    <input name='uid' class='form-control'
                           placeholder='<?php echo $PORTAL_PASSWORD_HELP ?>'
                           autofocus type='text'>
                </div>
             </div>
             <div class='form-group'>
                <label for='password' class='col-sm-2 control-label'>Password
					  </label>
                <div class='col-sm-10'>
                   <input name='password' class='form-control'
                          placeholder='Password'
                          type='password'>
                </div>
             </div>
             <div class='form-group'>
               <div class='col-sm-offset-2 col-sm-10'>
<?php
    if ($PROTOGENI_GENIWEBLOGIN) {
	?>
                 <button class='btn btn-info btn-sm pull-left'
		    type='button'
                    data-toggle="tooltip" data-placement="left"
		    title="You can use your geni credentials to login"
                    id='quickvm_geni_login_button'>Geni User?</button>
        <?php
    }
?>
                 <button class='btn btn-primary btn-sm pull-right'
                         id='quickvm_login_modal_button'
                         type='submit' name='login'>Login</button>
               </div>
             </div>
	     <div class='form-group'>
<!--	       <div class="col-sm-12"> -->
<?php
             if ($UI_EXTERNAL_ACCOUNTS == 0) {
?>
                 <a class='pull-right'
		    type='button' href='forgotpswd.php'
                    style='margin-right: 10px;'>
                    Forgot Password?</a>
<?php
             }
?>

<!--	       </div> -->
	     </div>
<?php
    echo "
            <br> 
           </div>
          </div>
          </form>
        </div>
        </div>\n";

    if ($ISCLOUD || $ISPNET || $ISPOWDER) {
	echo "<script
                src='https://www.emulab.net/protogeni/speaks-for/geni-auth.js'>
              </script>\n";
    }
    echo "<div id='waitwait_div'></div>\n";
    echo "<script src='js/lib/jquery-2.0.3.min.js'></script>\n";

    REQUIRE_UNDERSCORE();
    REQUIRE_SUP();
    SPITREQUIRE("js/login.js");
    SPITFOOTER();
    return;
}
#
# If not clicked, then put up a form.
#
if (!$ajax_request && !isset($login)) {
    if ($this_user) {
	header("Location: $APTBASE/landing.php");
	return;
    }
    if (NOLOGINS() && !$adminmode) {
        SPITHEADER();
        SPITUSERERROR("Sorry, logins are temporarily disabled, ".
                      "please try again later.");
        return;
    }
    SPITFORM(REMEMBERED_ID(), $referrer, null);
    return;
}

#
# Login clicked.
#
$STATUS_LOGGEDIN  = 1;
$STATUS_LOGINFAIL = 2;
$login_status     = 0;
$adminmode        = (isset($adminmode) && $adminmode);
$cleanmode        = (isset($cleanmode) && $cleanmode);

if (!isset($uid) || $uid == "" || !isset($password) || $password == "") {
    $login_status = $STATUS_LOGINFAIL;
}
else {
    $dologin_status = DOLOGIN($uid, $password, $adminmode);

    if ($dologin_status == DOLOGIN_STATUS_WEBFREEZE) {
	# Short delay.
	sleep(1);

	SPITHEADER();
	echo "<h4>
              Your account has been frozen due to earlier login attempt
              failures. You must contact $SUPPORT to have your account
              restored. <br> <br>
              Please do not attempt to login again; it will not work!
              </h4>\n";
        echo "<script src='js/lib/jquery-2.0.3.min.js'></script>\n";
	SPITNULLREQUIRE();
	SPITFOOTER();
	return;
    }
    elseif ($dologin_status == DOLOGIN_STATUS_FROZEN) {
	# Short delay.
	sleep(1);

	SPITHEADER();
	echo "<h4>
              Your account has been frozen!
              You must contact $SUPPORT to have your account
              restored. <br> <br>
              Please do not attempt to login again; it will not work!
              </h4>\n";
        echo "<script src='js/lib/jquery-2.0.3.min.js'></script>\n";
	SPITNULLREQUIRE();
	SPITFOOTER();
	return;
    }
    elseif ($dologin_status == DOLOGIN_STATUS_PROJDISABLED) {
	# Short delay.
	sleep(1);

	SPITHEADER();
	echo "<h4>
              One of the projects in which you are a member has been
              disabled. You are not allowed to log in until this has
              been resolved. Please contact $SUPPORT if you have any
              further questions. <br> <br>
              Please do not attempt to login again; it will not work!
              </h4>\n";
        echo "<script src='js/lib/jquery-2.0.3.min.js'></script>\n";
	SPITNULLREQUIRE();
	SPITFOOTER();
	return;
    }
    else if ($dologin_status == DOLOGIN_STATUS_INACTIVE) {
	# Short delay.
	sleep(1);

	SPITHEADER();
	echo "<h4>
              Your account has gone <b>inactive</b> since it has been so
              long since your last login. Please contact $SUPPORT
              to have your account restored. <br> <br>
              Please do not attempt to login again; it will not work!
              </h4>\n";
        echo "<script src='js/lib/jquery-2.0.3.min.js'></script>\n";
	SPITNULLREQUIRE();
	SPITFOOTER();
	return;
    }
    else if ($dologin_status == DOLOGIN_STATUS_NOGENIUSER) {
	# Short delay.
	sleep(1);

	SPITHEADER();
	echo "<h4>
              This account was created by logging in via the <b>Geni Login</b>
              button. Please go back to the <a href=login.php>login page</a>
              and click on the <b>Geni Login</b> button. If you would like
              to change your account to <em>direct login</em> please
              contact $SUPPORT.</h4>\n";
        echo "<script src='js/lib/jquery-2.0.3.min.js'></script>\n";
	SPITNULLREQUIRE();
	SPITFOOTER();
	return;
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

header("Last-Modified: " . gmdate("D, d M Y H:i:s") . " GMT");
header("Expires: Mon, 26 Jul 1997 05:00:00 GMT");
header("Cache-Control: no-cache, must-revalidate");
header("Pragma: no-cache");

#
# Failed, then try again with an error message.
# 
if ($login_status == $STATUS_LOGINFAIL) {
    if ($ajax_request) {
	SPITAJAX_ERROR(1, "login failed");
	exit(0);
    }
    SPITFORM($uid, $referrer, "failed");
    return;
}
#
# Watch for a classic user logging in but without an encrypted certificate.
# We really want to generate one so stuff does not break.
#
if ($CHECKLOGIN_USER->IsActive() && $CHECKLOGIN_USER->isClassic() &&
    !$CHECKLOGIN_USER->HasEncryptedCert(1)) {
    $CHECKLOGIN_USER->GenEncryptedCert();
}

if ($ajax_request) {
    SPITAJAX_RESPONSE("login sucessful");
    exit();
}
# We want to clear this in case the previous login was using it, but lets
# not create a cookie for all users.
if ($cleanmode || isset($_COOKIE['cleanmode'])) {
    setcookie("cleanmode", ($cleanmode ? 1 : 0), 0, "/", $TBAUTHDOMAIN, 0);
}

if (isset($referrer) && $CHECKLOGIN_USER->IsActive()) {
    #
    # Zap back to page that started the login request.
    #
    header("Location: $referrer");
}
else {
    header("Location: $APTBASE/landing.php?redirect=yes");
}
?>
