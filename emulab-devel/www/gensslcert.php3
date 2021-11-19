<?php
#
# Copyright (c) 2000-2013 University of Utah and the Flux Group.
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
# Only known and logged in users can do this.
#
$this_user = CheckLoginOrDie();
$uid       = $this_user->uid();
$isadmin   = ISADMIN();

#
# Verify page arguments
#
$optargs = OptionalPageArguments("target_user", PAGEARG_USER,
				 "submit",      PAGEARG_STRING,
				 "which",       PAGEARG_STRING,
				 "finished",    PAGEARG_BOOLEAN,
				 "formfields",  PAGEARG_ARRAY);

# Default to current user if not provided.
if (!isset($target_user)) {
     $target_user = $this_user;
}
if (!isset($which)) {
    $which = null;
}

# Need these below
$target_uid = $target_user->uid();

#
# The conclusion.
# 
if (isset($finished)) {
    PAGEHEADER("Download SSL Certificate for user: $target_uid");

    $sslurl = CreateURL("getsslcert", $target_user);
    $sshurl = CreateURL("getsslcert", $target_user, "ssh", 1);
    
    echo "<blockquote>
          <a href='$sslurl'>Download</a> your 
          certificate and private key in PEM format, and then save
          it to a file in your .ssl directory.
          <br>
          <br>
          You can also download it in <a href='$sslurl&p12=1'><em>pkc12</em></a>
          format for loading
          into your web browser (if you do not know what this means, or why
          you need to do this, then ignore this).
	  <br>
	  <br>
	  We have also created a SSH key pair for you, derived from your new 
          ssl certificate, using the same pass phrase.
          You can <a href='$sshurl'>Download</a> the private
          key and load it into your ssh agent. The private key is typically
	  placed in your .ssh directory on your desktop machine. If you are
          running an agent such as
	  <a href='http://www.chiark.greenend.org.uk/~sgtatham/putty/'>Putty</a>
          or
	  <a href='http://sshkeychain.sourceforge.net/'>SSHKeychain</a>,
	  please consult the
	  documentation for those programs.
          </blockquote>\n";
	    
    PAGEFOOTER();
    return;
}

#
# Standard Testbed Header, now that we know what we want to say.
#
PAGEHEADER("Generate SSL Certificate for user: $target_uid");

#
# Only admin people can create SSL certs for another user.
#
if (!$isadmin && !$target_user->SameUser($this_user)) {
    USERERROR("You do not have permission to create SSL certs ".
	      "for $target_uid!", 1);
}

function SPITFORM($target_user, $formfields, $errors)
{
    global $isadmin, $BOSSNODE;

    $target_uid    = $target_user->uid();
    $target_webid  = $target_user->webid();
    $url           = CreateURL("gensslcert", $target_user);

    echo "<blockquote>
          By creating an encrypted SSL certificate, you are able to use
          Emulab's XMLRPC server from your desktop or home machine. This
          certificate must be pass phrase protected, and allows you to issue
          any of the RPC requests documented in the <a href=xmlrpcapi.php3>
          Emulab XMLRPC Reference</a>.</blockquote>\n";
    
    if ($errors) {
	echo "<table class=nogrid
                     align=center border=0 cellpadding=6 cellspacing=0>
              <tr>
                 <th align=center colspan=2>
                   <font size=+1 color=red>
                      &nbsp;Oops, please fix the following errors!&nbsp;
                   </font>
                 </td>
              </tr>\n";

	while (list ($name, $message) = each ($errors)) {
            # XSS prevention.
	    $message = CleanString($message);
	    echo "<tr>
                     <td align=right>
                       <font color=red>$name:&nbsp;</font></td>
                     <td align=left>
                       <font color=red>$message</font></td>
                  </tr>\n";
	}
	echo "</table><br>\n";
    }
    # XSS prevention.
    while (list ($key, $val) = each ($formfields)) {
	$formfields[$key] = CleanString($val);
    }

    echo "<table align=center class=stealth>\n";
    echo "<tr>\n";
    echo "<td class=stealth>\n";
    
    echo "<center>
          Create an SSL Certificate[<b>1</b>]
          </center>\n";

    echo "<table align=center border=1> 
          <form enctype=multipart/form-data
                action='$url' method=post>\n";
    echo "<input type=hidden name=which value=create>\n";

    echo "<tr>
              <td>PassPhrase[<b>2</b>]:</td>
              <td class=left>
                  <input type=password
                         name=\"formfields[passphrase1]\"
                         value=\"" . $formfields["passphrase1"] . "\"
                         size=24></td>
          </tr>\n";

    echo "<tr>
              <td>Confirm PassPhrase:</td>
              <td class=left>
                  <input type=password
                         name=\"formfields[passphrase2]\"
                         value=\"" . $formfields["passphrase1"] . "\"
                         size=24></td>
          </tr>\n";

    if (1) {
	echo "<tr>
  	          <td>Reuse Private Key?[<b>3</b>]:</td>
		  <td class=left>
		      <input type=checkbox
			     name=\"formfields[reusekey]\"
			     value=Yep";

	if (isset($formfields["reusekey"]) &&
	    strcmp($formfields["reusekey"], "Yep") == 0)
	    echo "           checked";
	    
	echo "                       > Yes
		  </td>
	      </tr>\n";
    }
    
    #
    # Verify with password.
    #
    if (!$isadmin) {
	echo "<tr>
                  <td>Emulab Password[<b>4</b>]:</td>
                  <td class=left>
                      <input type=password
                             name=\"formfields[password]\"
                             size=12></td>
              </tr>\n";
    }

    echo "<tr>
              <td colspan=2 align=center>
                 <b><input type=submit name=submit value='Create SSL Cert'></b>
              </td>
          </tr>\n";

    echo "</form>
          </table>\n";

    echo "</td>\n";
    echo "<td class=stealth>\n";
    echo " OR ";
    echo "</td>\n";
    echo "<td valign=top class=stealth>\n";

    echo "<center>
          Change Passphrase
          </center>\n";
    
    echo "<table align=center border=1> 
          <form enctype=multipart/form-data
                action='$url' method=post>\n";
    echo "<input type=hidden name=which value=change>\n";

    echo "<tr>
              <td>New PassPhrase[<b>2</b>]:</td>
              <td class=left>
                  <input type=password
                         name=\"formfields[passphrase1]\"
                         value=\"" . $formfields["passphrase1"] . "\"
                         size=24></td>
          </tr>\n";
    echo "<tr>
              <td>Confirm PassPhrase:</td>
              <td class=left>
                  <input type=password
                         name=\"formfields[passphrase2]\"
                         value=\"" . $formfields["passphrase2"] . "\"
                         size=24></td>
          </tr>\n";
    
    if (!isset($formfields["oldpassphrase"])) {
	$formfields["oldpassphrase"] = "";
    }
    echo "<tr>
              <td>Old PassPhrase:</td>
              <td class=left>
                  <input type=password
                         name=\"formfields[oldpassphrase]\"
                         value=\"" . $formfields["oldpassphrase"] . "\"
                         size=24></td>
          </tr>\n";
    echo "<tr>
              <td colspan=2 align=center>
                 <b><input type=submit name=submit value='Change Passphrase'>
                 </b>
              </td>
          </tr>\n";

    echo "</form>
          </table>\n";

    echo "</td>\n";
    echo "</tr>\n";
    echo "</table>\n";

    echo "<blockquote><blockquote><blockquote>
          <ol>
            <li> This is an <b>encrypted key</b> and should <b>not</b> replace
                 <tt>emulab.pem</tt> in your <tt>.ssl</tt> directory.
            <li> You must supply a passphrase to use when encrypting the
                 private key for your SSL certificate. You will be prompted
                 for this passphrase whenever you attempt to use it. Pick
                 a good one!
            <li> Reuse your existing private key unless you think it has been
                 compromised. Must provide correct passphrase for your key.";
    if (!$isadmin) {
	echo "<li> As a security precaution, you must supply your Emulab user
                 password when creating new ssl certificates. ";
    }
    echo "</ol>
          </blockquote></blockquote></blockquote>\n";
}

#
# On first load, display a form of current values.
#
if (! isset($_POST['submit'])) {
    $defaults = array();
    $defaults["reusekey"]        = "Yep";
    $defaults["passphrase1"]     = "";
    $defaults["passphrase2"]     = "";
    $defaults["oldpassphrase"]   = "";
    
    SPITFORM($target_user, $defaults, 0);
    PAGEFOOTER();
    return;
}

# Must get formfields.
if (!isset($formfields)) {
    PAGEARGERROR("Invalid form arguments; no formfields array.");
}

#
# Otherwise, must validate and redisplay if errors
#
$errors = array();

#
# Need to get the which variable to tell us which form.
#
if (! ($which && ($which == "create" || $which == "change"))) {
    PAGEARGERROR("Invalid form arguments; which form?");
}

#
# Need this for checkpass.
#
$user_name  = $target_user->name();
$user_email = $target_user->email();

#TBERROR("$target_uid, $user_name, $user_email, " .
#	$formfields[passphrase1], 0); 

#
# Must supply a reasonable passphrase.
# 
if (!isset($formfields["passphrase1"]) ||
    strcmp($formfields["passphrase1"], "") == 0) {
    $errors["Passphrase"] = "Missing Field";
}
if (!isset($formfields["passphrase2"]) ||
    strcmp($formfields["passphrase2"], "") == 0) {
    $errors["Confirm Passphrase"] = "Missing Field";
}
elseif (strcmp($formfields["passphrase1"], $formfields["passphrase2"])) {
    $errors["Confirm Passphrase"] = "Does not match Passphrase";
}
elseif (! CHECKPASSWORD($target_uid,
			$formfields["passphrase1"],
			$user_name,
			$user_email, $checkerror)) {
    $errors["Passphrase"] = "$checkerror";
}

#
# Must verify passwd to create an SSL key.
#
if ($which == "create" && !$isadmin) {
    if (!isset($formfields["password"]) ||
	strcmp($formfields["password"], "") == 0) {
	$errors["Password"] = "Must supply a verification password";
    }
    elseif (VERIFYPASSWD($target_uid, $formfields["password"]) != 0) {
	$errors["Password"] = "Incorrect password";
    }
}

if ($which == "change") {
    $query_result =&
	$target_user->TableLookUp("user_sslcerts",
				  "cert,privkey,idx",
				  "encrypted=1 and revoked is null");

    if (!mysql_num_rows($query_result)) {
	$errors["Change Passphrase"] =
	    "You have not created an encrypted certificate yet";
    }

    if (!isset($formfields["oldpassphrase"]) ||
	strcmp($formfields["oldpassphrase"], "") == 0) {
	$errors["Old Passphrase"] = "Must supply current passphrase";
    }
    # Ascii only.
    elseif (! TBvalid_userdata($formfields["oldpassphrase"])) {
	$errors["Old Passphrase"] = "Invalid characters in old passphrase";
	return 0;
    }
}

# Spit the errors
if (count($errors)) {
    SPITFORM($target_user, $formfields, $errors);
    PAGEFOOTER();
    return;
}

$opt = "";
if ($which == "create") {
    if (isset($formfields["reusekey"]) &&
	strcmp($formfields["reusekey"], "Yep") == 0) {
	$opt = "-r";
    }
}
else {
    $opt = "-c " . escapeshellarg($formfields["oldpassphrase"]);
}

#
# Insert key, update authkeys files and nodes if appropriate.
#
STARTBUSY(($which == "create" ?
	   "Generating Certificate" : "Changing Passphrase"));

$retval = SUEXEC($target_uid, "nobody",
		 "webmkusercert $opt -p " .
		 escapeshellarg($formfields["passphrase1"]) . " $target_uid",
		 SUEXEC_ACTION_IGNORE);
HIDEBUSY();

#
# Fatal Error. Report to tbops.
# 
if ($retval < 0) {
    SUEXECERROR(SUEXEC_ACTION_DIE);
    #
    # Never returns ...
    #
    die("");
}

#
# User Error. Report to user.
#
if ($retval > 0) {
    $errors["PassPhrase"] = $suexec_output;
    
    SPITFORM($target_user, $formfields, $errors);
    PAGEFOOTER();
    return;
}

#
# Redirect back, avoiding a POST in the history.
#
PAGEREPLACE(CreateURL("gensslcert", $target_user, "finished", 1));

PAGEFOOTER();
?>
