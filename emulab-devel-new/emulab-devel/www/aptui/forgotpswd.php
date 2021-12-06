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
$page_title = "Forgot Your Password";

RedirectSecure();
$this_user = CheckLogin($check_status);
if ($CHECKLOGIN_STATUS & CHECKLOGIN_LOGGEDIN) {
    SPITUSERERROR("You are already logged in!");
}

#
# see if UI change password is disabled (e.g. passwords externally managed)
#
if ($UI_EXTERNAL_ACCOUNTS) {
    SPITUSERERROR("Password change disabled on this system");
    return;
}

#
# Verify page arguments.
#
$optargs = OptionalPageArguments("reset",         PAGEARG_STRING,
				 "username",      PAGEARG_STRING,
				 "email",         PAGEARG_STRING,
				 "formfields",    PAGEARG_ARRAY);

function SPITFORM($username, $email, $errors)
{
    # XSS prevention.
    $username = CleanString($username);
    $email    = CleanString($email);
    # XSS prevention.
    if ($errors) {
	while (list ($key, $val) = each ($errors)) {
	    # Skip internal error, we want the html in those errors
	    # and we know it is safe.
	    if ($key == "error") {
		continue;
	    }
	    $errors[$key] = CleanString($val);
	}
    }

    $formatter = function($field, $html) use ($errors) {
	$class = "form-group";
	if ($errors && array_key_exists($field, $errors)) {
	    $class .= " has-error";
	}
	echo "<div class='$class'>\n";
	echo "     $html\n";
	if ($errors && array_key_exists($field, $errors)) {
	    echo "<label class='control-label' for='inputError'>" .
		$errors[$field] . "</label>\n";
	}
	echo "</div>\n";
    };

    SPITHEADER(1);

    echo "<div class='row'>
          <div class='col-lg-4  col-lg-offset-4
                      col-md-4  col-md-offset-4
                      col-sm-6  col-sm-offset-3
                      col-xs-10 col-xs-offset-1'>\n";

    echo "<form id='quickvm_form' role='form'
            method='post' action='forgotpswd.php'>\n";
    echo "<div class='panel panel-default'>
            <div class='panel-heading'>
              <h3 class='panel-title'>
                <center>Forgot Your Password?</center></h3>
	    </div>
	    <div class='panel-body'>\n";

    $formatter("username", 
	       "<input name='username'
		       value='$username'
                       class='form-control'
                       placeholder='What is your username?'
                       autofocus type='text'>");
   
    $formatter("email", 
	       "<input name='email'
                       type='text'
                       value='$email'
                       class='form-control'
                       placeholder='What is your email address?' type='text'>");

    echo "<center>
           <button class='btn btn-primary'
              type='submit' name='reset'>Email Reset Link</button><center>\n";

    echo "  </div>\n";
    echo "</div>\n";
    echo "</form>\n";
    echo "</div>\n";
    echo "</div>\n";
    SPITNULLREQUIRE();
    SPITFOOTER();
}

#
# If not clicked, then put up a form.
#
if (!isset($reset)) {
    SPITFORM("", "", null);
    return;
}

$errors = array();

#
# Reset clicked. See if we find a user with the given email/phone. If not
# zap back to the form. 
#
if (!isset($email) || $email == "" || !TBvalid_email($email)) {
    $errors["email"] = "Missing or invalid email";
}
if (!isset($username) || $username == "" || !TBvalid_uid($username)) {
    $errors["username"] = "Missing or invalid username";
}
if (count($errors)) {
    SPITFORM($username, $email, $errors);
    return;
}
if ($user = User::Lookup($username)) {
    if ($user->weblogin_frozen()) {
	$errors["username"] = "This account is frozen";
    }
    elseif (strtolower($user->email()) != strtolower($email)) {
	$errors["email"] = "Wrong email address for user";
    }
    # Safety
    elseif ($user->nonlocal_id()) {
	$errors["email"] = "This account is not allowed to do this";
    }
}
else {
    $errors["username"] = "Invalid username";
}
if (count($errors)) {
    SPITFORM($username, $email, $errors);
    return;
}
$uid       = $user->uid();
$uid_name  = $user->name();
$uid_email = $user->email();

#
# Yep. Generate a random key and send the user an email message with a URL
# that will allow them to change their password. 
#
$key  = md5(uniqid(rand(),1));
$keyA = substr($key, 0, 16);
$keyB = substr($key, 16);
$user->SetChangePassword($key, "UNIX_TIMESTAMP(now())+(60*30)");

# Send half of the key to the browser and half in the email message.
setcookie($TBAUTHCOOKIE, $keyA, 0, "/", $WWWHOST, $TBSECURECOOKIES);

# It is okay to spit this now that we have sent the cookie.
SPITHEADER();

TBMAIL("$uid_name <$uid_email>",
       "Password Reset requested by '$uid'",
       "\n".
       "Here is your password reset authorization URL. Click on this link\n".
       "within the next 30 minutes, and you will be allowed to reset your\n".
       "password. If the link expires, you can request a new one from the\n".
       "web interface.\n".
       "\n".
       "    ${APTBASE}/changepswd.php?user=$uid&key=$keyB\n".
       "\n".
       "The request originated from IP: " . $_SERVER['REMOTE_ADDR'] . "\n".
       "\n".
       "Thanks!\n",
       "From: $APTMAIL\n".
       "Bcc: $TBMAIL_AUDIT\n".
       "Errors-To: $TBMAIL_WWW");

echo "<br>
      An email message has been sent to your account. In it you will find a
      URL that will allow you to change your password. The link will <b>expire 
      in 30 minutes</b>. If the link does expire before you have a chance to
      use it, simply come back and request a <a href='password.php3'>new one</a>.
      \n";

SPITNULLREQUIRE();
SPITFOOTER();

?>
