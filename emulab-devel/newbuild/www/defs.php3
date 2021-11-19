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

#
# Standard definitions.
#
$TBDIR          = "/home/achauhan06/CLOUDLAB/SSHCLOUD/CloudLabonESI/emulab-devel/newbuild/";
$OURDOMAIN      = "cloudlab.umass.edu";
$BOSSNODE       = "boss.cloudlab.umass.edu";
$USERNODE       = "ops.cloudlab.umass.edu";
$CVSNODE	= "cvs.${OURDOMAIN}";
$WIKINODE	= $USERNODE;
$TBADMINGROUP   = "tbadmin";
$WWWHOST	= "www.cloudlab.umass.edu";
$WWW		= "www.cloudlab.umass.edu";
$TBAUTHDOMAIN	= ".cloudlab.umass.edu";
$TBBASE		= "https://www.cloudlab.umass.edu";
$TBDOCBASE	= "http://www.cloudlab.umass.edu";
$TBWWW		= "<https://www.cloudlab.umass.edu/>";
$THISHOMEBASE	= "UMASS";
$ELABINELAB     = 0;
$PLABSUPPORT    = 0;
$PUBSUPPORT     = 0;
$WIKISUPPORT    = 0;
$TRACSUPPORT    = 0;
$BUGDBSUPPORT   = 0;
$CVSSUPPORT     = 0;
$MAILMANSUPPORT = 0;
$DOPROVENANCE   = 1;
$CHATSUPPORT    = 0;
$PROTOGENI      = 1;
$GENIRACK       = 0;
$PROTOGENI_GENIWEBLOGIN = 0;
$PROTOGENI_HOLDINGPROJECT = "";
$ISCLRHOUSE     = 0;
$PROTOGENI_LOCALUSER = 1;
$EXP_VIS        = 0;
$ISOLATEADMINS  = 0;
$CONTROL_NETWORK= "198.22.255.0";
$CONTROL_NETMASK= "255.255.255.0";
$WIKIHOME       = "https://${USERNODE}/twiki";
$WIKIURL        = "${WIKIHOME}/bin/newlogon";
$WIKICOOKIENAME = "WikiCookie";
$BUGDBURL       = "https://${USERNODE}/flyspray";
$BUGDBCOOKIENAME= "FlysprayCookie";
$TRACCOOKIENAME = "TracCookie";
$MAILMANURL     = "http://${USERNODE}/mailman";
$OPSCVSURL      = "http://${USERNODE}/cvsweb/cvsweb.cgi";
$OPSJETIURL     = "http://${USERNODE}/jabber/jeti.php";
$WIKIDOCURL     = "http://${WIKINODE}/wikidocs/wiki";
$FORUMURL       = "http://groups.google.com/group/emulab-users";
$MIN_UNIX_UID   = 2000;
$MIN_UNIX_GID   = 2000;
$EXPOSELINKTEST = 1;
$EXPOSESTATESAVE= 0;
$EXPOSEARCHIVE  = 0;
$EXPOSETEMPLATES= 0;
$USERSELECTUIDS = 1;
$REMOTEWIKIDOCS = 1;
$FLAVOR         = "Emulab";
$GMAP_API_KEY   = "";
$NONAMEDSETUP	= 0;
$OPS_VM		= 0;
$PORTAL_ENABLE  = 1;
$CLUSTER_PORTAL = "boss.emulab.net";
$PEER_ENABLE    = 0;
$PEER_ISPRIMARY = 0;
$SPEWFROMOPS    = 0;
$BROWSER_CONSOLE_ENABLE = 1;
$BROWSER_CONSOLE_PROXIED = 0;
$BROWSER_CONSOLE_WEBSSH = 1;
$IPV6_ENABLED       = 0;
$IPV6_SUBNET_PREFIX = "";
$TBMAILTAG      = $THISHOMEBASE;
$WITHZFS        = 1;
$ZFS_NOEXPORT   = 1;
$UI_DISABLE_DATASETS  = 0;
$UI_DISABLE_RESERVATIONS = 0;
$UI_EXTERNAL_ACCOUNTS = 0;
$CLASSICWEB_OVERRIDE = 0;
$OURTIMEZONE = "America/New_York";

$TBMAILADDR_OPS		= "testbed-ops@ops.cloudlab.umass.edu";
$TBMAILADDR_WWW		= "testbed-www@ops.cloudlab.umass.edu";
$TBMAILADDR_APPROVAL	= "testbed-approval@ops.cloudlab.umass.edu";
$TBMAILADDR_LOGS	= "testbed-logs@ops.cloudlab.umass.edu";
$TBMAILADDR_AUDIT	= "testbed-audit@ops.cloudlab.umass.edu";

# Can override this in the defs file. 
$TBAUTHTIMEOUT  = "86400";
$TBMAINSITE     = "0";
$TBSECURECOOKIES= "1";
$TBCOOKIESUFFIX = "UMASS";
$FANCYBANNER    = "1";

$TBWWW_DIR	= "$TBDIR"."www/";
$TBBIN_DIR	= "$TBDIR"."bin/";
$TBETC_DIR	= "$TBDIR"."etc/";
$TBLIBEXEC_DIR	= "$TBDIR"."libexec/";
$TBSUEXEC_PATH  = "$TBLIBEXEC_DIR/suexec";
$TBCHKPASS_PATH = "$TBLIBEXEC_DIR/checkpass";
$TBSENDMAIL_PATH= "$TBLIBEXEC_DIR/tbsendmail";
$TBCSLOGINS     = "$TBETC_DIR/cslogins";
$UUIDGEN_PATH   = "/usr/bin/uuidgen";

#
# Hardcoded check against $WWWHOST, to prevent anyone from accidentally setting
# $TBMAINSITE when it should not be
#
if ($WWWHOST != "www.emulab.net") {
    $TBMAINSITE = 0;
}

#
# The wiki docs either come from the local node, or in most cases
# they are redirected back to Utah's emulab.
#
if ($TBMAINSITE) {
    $WIKIDOCURL  = "https://${WIKINODE}/wikidocs/wiki";
}
elseif ($REMOTEWIKIDOCS) {
    $WIKIDOCURL  = "https://wiki.emulab.net/wikidocs/wiki";
}
else {
    $WIKIDOCURL  = "/wikidocs/wiki";
}

$TBPROJ_DIR     = "/proj";
$TBUSER_DIR	= "/users";
$TBGROUP_DIR	= "/groups";
$TBSCRATCH_DIR	= "";
$TBCVSREPO_DIR  = "$TBPROJ_DIR/cvsrepos";
$TBNSSUBDIR     = "nsdir";

$TBVALIDDIRS	  = "$TBPROJ_DIR, $TBUSER_DIR, $TBGROUP_DIR";
$TBVALIDDIRS_HTML = "<code>$TBPROJ_DIR</code>, <code>$TBUSER_DIR</code>, <code>$TBGROUP_DIR</code>";
if ($TBSCRATCH_DIR) {
    $TBVALIDDIRS .= ", $TBSCRATCH_DIR";
    $TBVALIDDIRS_HTML .= ", <code>$TBSCRATCH_DIR</code>";
}

$TBAUTHCOOKIE   = "NewHashCookie" . $TBCOOKIESUFFIX;
$TBNAMECOOKIE   = "NewMyUidCookie" . $TBCOOKIESUFFIX;
$TBEMAILCOOKIE  = "MyEmailCookie" . $TBCOOKIESUFFIX;
$TBLOGINCOOKIE  = "NewLoginCookie" . $TBCOOKIESUFFIX;

$HTTPTAG        = "http://";
$HTTPSTAG       = "https://";

$TBMAIL_OPS		= "Testbed Ops <$TBMAILADDR_OPS>";
$TBMAIL_WWW		= "Testbed WWW <$TBMAILADDR_WWW>";
$TBMAIL_APPROVAL	= "Testbed Approval <$TBMAILADDR_APPROVAL>";
$TBMAIL_LOGS		= "Testbed Logs <$TBMAILADDR_LOGS>";
$TBMAIL_AUDIT		= "Testbed Audit <$TBMAILADDR_AUDIT>";
$TBMAIL_NOREPLY		= "no-reply@$OURDOMAIN";

#
# This just spits out an email address in a page, so it does not need
# to be configured per development tree. It could be though ...
# 
$TBMAILADDR     = "<a href=\"mailto:$TBMAILADDR_OPS\">
                      Testbed Operations ($TBMAILADDR_OPS)</a>";

# So subscripts always know ...
putenv("HTTP_SCRIPT=1");

#
# Special headers alterting browsers to the fact that there's an RSS feed
# available for the page. Intended to be passed as an $extra_headers argument
# to PAGEHEADER
#
$RSS_HEADER_NEWS = "<link rel=\"alternate\" type=\"application/rss+xml\" " .
           "title=\"Emulab News\" href=\"$TBDOCBASE/news-rss.php3?protogeni=0\" />";

$RSS_HEADER_PGENINEWS =
   "<link rel=\"alternate\" type=\"application/rss+xml\" " .
   "title=\"ProtoGeni News\" href=\"$TBDOCBASE/news-rss.php3?protogeni=1\"/>";

$RSS_HEADER_PNNEWS =
   "<link rel=\"alternate\" type=\"application/rss+xml\" " .
   "title=\"PhantomNet News\" href=\"$TBDOCBASE/news-rss.php3?phantomnet=1\"/>";

#
# See if we should override any of the global web variables based on the
# virtual domain.  We include a site-dependent definitions file.
#
$ALTERNATE_DOMAINS = array();
$ISALTDOMAIN       = 0;
$DOMVIEW           = NULL;
$altdomfile = strtolower("alternate_domains_${OURDOMAIN}.php");
if (file_exists($altdomfile)) {
    include($altdomfile);
}
SetDomainDefs();

#
# Database constants and the like.
#
include("dbdefs.php3");
include("url_defs.php");
include("user_defs.php");
include("group_defs.php");
include("project_defs.php");
include("experiment_defs.php");

#
# Control how error messages are returned to the user. If the session is
# not actually "interactive" then do not send any output to the browser.
# Just save it up and let the page deal with it. 
#
$session_interactive  = 1;
$session_errorhandler = 0;

#
# Wrap up the mail function so we can prepend a tag to the subject
# line that indicates what testbed. Useful when multiple testbed
# email to the same list.
#
# In order to make the email look less spammy, we want the envelope
# sender to match the From address domain. We do this by letting an
# external script send the mail, adding the root only -f option to
# sendmail. 
# 
function TBMAIL($to, $subject, $message, $headers = 0)
{
    global $TBMAILTAG, $TBSENDMAIL_PATH;

    $subject = strtoupper($TBMAILTAG) . ": $subject";

    $tag = "X-NetBed: " . basename($_SERVER["SCRIPT_NAME"]);
    
    if ($headers) {
	$headers = "$headers\n" . $tag;
    }
    else {
	$headers = $tag;
    }
    $fd = popen("$TBSENDMAIL_PATH", "w");
    fwrite($fd, "To: " . $to . "\n");
    fwrite($fd, $headers . "\n");
    fwrite($fd, "Subject: " . $subject . "\n");
    fwrite($fd, "\n");
    fwrite($fd, $message . "\n");
    if (pclose($fd)) {
        error_log("TBMAIL: Failed to send email message to $to");
        error_log("TBMAIL: Subject: $subject");
    }
}

#
#
# Identical to perl function of the same name
#
#
function SendProjAdminMail($project, $from, $to,
			   $subject, $message, $headers = "")
{
    global $MAILMANSUPPORT, $TBMAIL_APPROVAL, $TBMAIL_AUDIT;
    global $OURDOMAIN, $TBMAIL_WWW, $TBMAILTAG;
    $pid = $project->pid();
    
    $projadminmail =
	($project->isAPT() ? "aptlab-approval@aptlab.net" :
	 ($project->isCloud() ? "cloudlab-approval@cloudlab.us" :
	  ($project->isPNet() ? "phantomnet-approval@phantomnet.org" :
           ($project->isPowder() ? "powder-approval@powderwireless.net" :
            $TBMAIL_APPROVAL))));
    $TBMAILTAG =
	($project->isAPT() ? "aptlab.net" :
	 ($project->isCloud() ? "cloudlab.us" : 
	  ($project->isPNet() ? "phantomnet.org" :
           ($project->isPowder() ? "powderwireless.net" :
            $TBMAILTAG))));
    if ($headers) {
        $headers .= "\n";
    }
    if ($from == 'ADMIN') {
	$from = $projadminmail;
	$headers .= "Bcc: $projadminmail\n";
    } elseif ($to == 'ADMIN') {
	$to = $projadminmail;
	$headers .= "Reply-To: $projadminmail\n";
    } else {
	$headers .= "Bcc: $projadminmail\n";
    }
    $headers .= "From: $from\n";
    if ($from == 'AUDIT') {
	$from = $TBMAIL_AUDIT;
	$headers .= "Bcc: $TBMAIL_AUDIT\n";
    } elseif ($to == "AUDIT") {
	$to = $TBMAIL_AUDIT;
    } else {
	$headers .= "Bcc: $TBMAIL_AUDIT\n";
    }
    $headers .= "Errors-To: $TBMAIL_WWW\n"; # FIXME: Why?
    $headers = substr($headers, 0, -1);
    TBMAIL($to, $subject, $message, $headers);
}

#
# Internal errors should be reported back to the user simply. The actual 
# error information should be emailed to the list for action. The script
# should then terminate if required to do so.
#
function TBERROR ($message, $death, $xmp = 0) {
    global $TBMAIL_WWW, $TBMAIL_OPS, $TBMAILADDR, $TBMAILADDR_OPS;
    global $session_interactive, $session_errorhandler;
    $script = urldecode($_SERVER['REQUEST_URI']);

    # print backtrace
    $e = new Exception();
    $trace = $e->getTraceAsString();

    if (function_exists("CLEARBUSY")) {
        CLEARBUSY();
    }
    TBMAIL($TBMAIL_OPS,
         "WEB ERROR REPORT",
         "\n".
	 "In $script\n\n".
         "$message\n\n".
         "$trace\n\n".
         "Thanks,\n".
         "Testbed WWW\n",
         "From: $TBMAIL_OPS\n".
         "Errors-To: $TBMAIL_WWW");

    if ($death) {
	if ($session_interactive)
	    PAGEERROR("Could not continue. Please contact $TBMAILADDR");
	elseif ($session_errorhandler) {
	    $session_errorhandler("Could not continue. ".
				  "Please contact $TBMAILADDR_OPS", $death);
	}
	exit(1);
    }
    return 0;
}

#
# General user errors should print something warm and fuzzy.  If a
# header is not already printed and the dealth paramater is true, then
# assume the error is a precheck error and send an appropriate HTTP
# response to prevent robots from indexing the page.  This currently
# defaults to a "400 Bad Request", but that may change in the future.
#
function USERERROR($message, $death = 1, 
	           $status_code = HTTP_400_BAD_REQUEST) {
    global $TBMAILADDR;
    global $session_interactive, $session_errorhandler;

    CLEARBUSY();

    if (! $session_interactive) {
	if ($session_errorhandler)
	    $session_errorhandler($message, $death);
	else
	    echo "$message";

	if ($death)
	    exit(1);
	return;
    }

    $msg = "<font size=+1><br>
            $message
      	    </font>
            <br><br><br>
            <font size=-1>
            Please contact $TBMAILADDR if you feel this message is an error.
            </font>\n";

    if ($death) {
	PAGEERROR($msg, $status_code);
    }
    else
        echo "$msg\n";
}

#
# A form error.
#
function FORMERROR($field) {
    USERERROR("Missing field; ".
              "Please go back and fill out the \"$field\" field!", 1);
}

#
# A page argument error. 
# 
function PAGEARGERROR($msg = 0) {
    $default = "Invalid page arguments: " .
          	htmlspecialchars($_SERVER['REQUEST_URI']);

    if ($msg) {
	$default = "$default<br><br>$msg";
    }
    USERERROR($default, 1, HTTP_400_BAD_REQUEST);
}

#
# SUEXEC stuff.
#
# Save this stuff so we can generate better error messages and such.
# 
$suexec_cmdandargs   = "";
$suexec_retval       = 0;
$suexec_output       = "";
$suexec_output_array = null;

#
# Actions for suexec. 
#
define("SUEXEC_ACTION_CONTINUE",	0);
define("SUEXEC_ACTION_DIE",		1);
define("SUEXEC_ACTION_USERERROR",	2);
define("SUEXEC_ACTION_IGNORE",		3);
define("SUEXEC_ACTION_DUPDIE",		4);
define("SUEXEC_ACTION_DEBUG",		5);
# SUEXEC_ACTION_MAIL_TBLOGS to be ored with one of the above actions
define("SUEXEC_ACTION_MAIL_TBLOGS",     64);

#
# An suexec error.
#
function SUEXECERROR($action)
{
    global $suexec_cmdandargs, $suexec_retval;
    global $suexec_output, $TBMAIL_OPS;

    $foo  = "Shell program exit status: $suexec_retval\n";
    $foo .= "  '$suexec_cmdandargs'\n";
    $foo .= "\n";
    $foo .= $suexec_output;

    switch ($action) {
    case SUEXEC_ACTION_CONTINUE:
	TBERROR($foo, 0, 1);
        break;
    case SUEXEC_ACTION_DIE:
	TBERROR($foo, 1, 1);
        break;
    case SUEXEC_ACTION_USERERROR:
	USERERROR("<XMP>$foo</XMP>", 1);
        break;
    case SUEXEC_ACTION_IGNORE:
	break;
    case SUEXEC_ACTION_DUPDIE:
	TBERROR($foo, 0, 1);
	USERERROR("<XMP>$foo</XMP>", 1);
        break;
    case SUEXEC_ACTION_DEBUG:
        TBMAIL($TBMAIL_OPS, "WEB DEBUG REPORT", $foo, "From: $TBMAIL_OPS");
        break;
    default:
	TBERROR($foo, 1, 1);
    }
}

#
# Run a program as a user.
#
function SUEXEC($uid, $gid, $cmdandargs, $action) {
    global $TBSUEXEC_PATH;
    global $suexec_cmdandargs, $suexec_retval;
    global $suexec_output, $suexec_output_array;
    global $TBMAIL_LOGS;

    #
    # Allow for uid/gid to be user/group/project objects.
    #
    if (is_object($uid)) {
        $object = $gid;
        if (is_a($object, "User")) {
            $uid = $object->uid();
        }
        else {
            error_log("SUEXEC: Bad uid argument");
            return -1;
        }
    }
    if (is_object($gid)) {
        $object = $gid;
        if (is_a($object, "Project")) {
            $gid = $object->pid();
            # For debugging, better if we use name if we can, but if the
            # name is longer then 16 chars, need to use unix gid.
            if (strlen($gid) > 16) {
                $gid = $object->unix_gid();
            }
        }
        elseif (is_a($object, "Group")) {
            $gid = $object->gid();
            # For debugging, better if we use name if we can, but if the
            # name is longer then 16 chars, need to use unix gid.
            if (strlen($gid) > 16) {
                $gid = $object->unix_gid();
            }
        }
        else {
            error_log("SUEXEC: Bad gid argument");
            return -1;
        }
    }

    $mail_tblog = 0;
    if ($action & SUEXEC_ACTION_MAIL_TBLOGS) {
	$action &= ~SUEXEC_ACTION_MAIL_TBLOGS;
	$mail_tblog = 1;
    }

    ignore_user_abort(1);

    $suexec_cmdandargs   = "$uid $gid $cmdandargs";
    $suexec_output_array = array();
    $suexec_output       = "";
    $suexec_retval       = 0;
    
    exec("$TBSUEXEC_PATH $suexec_cmdandargs",
	 $suexec_output_array, $suexec_retval);

    # Yikes! Something is not doing integer conversion properly!
    if ($suexec_retval == 255) {
	$suexec_retval = -1;
    }
    #
    # suexec.c puts its error message between 101 and 125. Convert that
    # to an internal error and generate an error that says something useful.
    #
    # XXX Ignore 101, something in the geni-lib path uses it.
    #
    if (0 && $suexec_retval > 101 && $suexec_retval <= 125 &&
        !count($suexec_output_array)) {
        $suexec_output_array[0] =
            "Internal suexec error $suexec_retval. See the suexec log";
        $suexec_retval = -1;
    }

    if (count($suexec_output_array)) {
	for ($i = 0; $i < count($suexec_output_array); $i++) {
	    $suexec_output .= "$suexec_output_array[$i]\n";
	}
    }

    if ($mail_tblog) {
	$mesg  = "$TBSUEXEC_PATH $suexec_cmdandargs\n";
	$mesg .= "Return Value: $suexec_retval\n\n";
	$mesg .= "--------- OUTPUT ---------\n";
	$mesg .= $suexec_output;
	
	TBMAIL($TBMAIL_LOGS, "suexec: $cmdandargs", $mesg);
    }

    #
    # The output is still available of course, via $suexec_output.
    # 
    if ($suexec_retval == 0 || $action == SUEXEC_ACTION_IGNORE) {
	return $suexec_retval;
    }
    SUEXECERROR($action);
    # Must return the shell value!
    return $suexec_retval;
}

#
# We invoke addpubkey as user nobody all the time. The implied user is passed
# along in an HTTP_ variable (see tbauth). This avoids a bunch of confusion
# that results from new users who do not have a context yet. 
#
function ADDPUBKEY($cmdandargs) {
    global $TBSUEXEC_PATH;

    return SUEXEC("nobody", "nobody", "webaddpubkey $cmdandargs",
		  SUEXEC_ACTION_CONTINUE);
}

#
# Verify a URL.
#
function CHECKURL($url, &$error) {
    global $HTTPTAG, $HTTPSTAG;

    if (strlen($url)) {
	if (strstr($url, " ")) {
	    $error = "URL is malformed; spaces are not allowed!";
	    return 0;
	}
        #
        # We no longer fopen the url ... 
        #
    }
    return 1;
}

#
# Check a password.
#
function CHECKPASSWORD($uid, $password, $name, $email, &$error)
{
    global $TBCHKPASS_PATH;

    # Watch for caller errors since this calls to the shell.
    if (empty($uid) || empty($password) || empty($name) || empty($email)) {
	$error = "Internal Error";
	return 0;
    }
    # Ascii only.
    if (! TBvalid_userdata($password)) {
	$error = "Invalid characters; ascii only please";
	return 0;
    }

    $uid      = escapeshellarg($uid);
    $password = escapeshellarg($password);
    $stuff    = escapeshellarg("$name:$email");
    
    $mypipe = popen("$TBCHKPASS_PATH $password $uid $stuff", "w+");
    
    if ($mypipe) { 
        $retval=fgets($mypipe, 1024);
        if (strcmp($retval,"ok\n") != 0) {
	    $error = "$retval";
	    return 0;
	}
	return 1;
    }
    TBERROR("Checkpass Failure! Returned '$mypipe'.\n\n".
	    "$TBCHKPASS_PATH $password $uid '$name:$email'", 1);
}

#
# Grab a UUID (universally unique identifier).
#
function NewUUID()
{
    global $UUIDGEN_PATH;

    $uuid = shell_exec($UUIDGEN_PATH);
    
    if (isset($uuid) && $uuid != "") {
	return rtrim($uuid);
    }
    TBERROR("$UUIDGEN_PATH Failure", 1);
}

# Check pattern.
function IsValidUUID($token)
{
    if (preg_match("/^\w+\-\w+\-\w+\-\w+\-\w+$/", $token)) {
	return 1;
    }
    return 0;
}
function IsValidHash($token)
{
    if (strlen("$token") >= 32 && preg_match("/^\w+$/", $token)) {
	return 1;
    }
    return 0;
}

function LASTNODELOGIN($node)
{
}

function VALIDUSERPATH($path, $uid="", $pid="", $gid="", $eid="")
{
    global $TBPROJ_DIR, $TBUSER_DIR, $TBGROUP_DIR, $TBSCRATCH_DIR;

    #
    # No ids specified, just make sure it starts with an appropriate prefix.
    #
    if (!$uid && !$pid && !$gid && !$eid) {
	if (preg_match("#^$TBPROJ_DIR/.*#", $path) ||
	    preg_match("#^$TBUSER_DIR/.*#", $path) ||
	    preg_match("#^$TBGROUP_DIR/.*#", $path)) {
	    return 1;
	}
	if ($TBSCRATCH_DIR && preg_match("#^$TBSCRATCH_DIR/.*#", $path)) {
	    return 1;
	}
	return 0;
    }

    # XXX for now, see tbsetup/libtestbed.pm for what should happen
    return 0;
}

#
# A function to print the contents of an array (recursively).
# Mostly useful for debugging.
#
function ARRAY_PRINT($arr) {
  if (!is_array($arr)) { echo "non-array '$arr'\n"; }
  foreach ($arr as $i => $val) {
    echo("'$i' - '$val'\n");
    if (is_array($val)) {
      echo "Sub-array $i:\n";
      array_print($val);
      echo "End Sub-array $i.\n";
    }
  }
}

#
# Return Yes or No given boolean
#
function YesNo($bool) {
    return ($bool ? "Yes" : "No");
}

#
# See if someone is logged in, and if they need to be redirected.
#
function CheckRedirect() {
    global $stayhome;

    if (($this_user = CheckLogin($check_status))) {
	$check_status = $check_status & CHECKLOGIN_STATUSMASK;
	if ($check_status == CHECKLOGIN_MAYBEVALID) {
            # Maybe the reason was because they where not using HTTPS ...
	    RedirectHTTPS();
	}
	
	if (($firstinitstate = TBGetFirstInitState())) {
	    unset($stayhome);
	}
	if (!isset($stayhome)) {
	    if ($check_status == CHECKLOGIN_LOGGEDIN) {
		if ($firstinitstate == "createproject") {
                    # Zap to NewProject Page,
		    header("Location: $TBBASE/newproject.php3");
		}
		else {
                    # Zap to My Emulab page.
		    header("Location: $TBBASE/".
			   CreateURL("showuser", $this_user));
		}
		exit;
	    }
	}
    }
}

#
# Loop over the $ALTERNATE_DOMAINS global array and see if the incoming
# request asked for a virtual domain for which we have an alternate set
# of definitions and/or view.
#
# Return 1 if a domain in the array matched, 0 otherwise.  Has MAJOR
# side effects: updates/overrides many top-level variables.
#
function SetDomainDefs()
{
    global $WWWHOST, $OURDOMAIN, $WWW, $THISHOMEBASE, $TBAUTHDOMAIN, $TBBASE;
    global $TBDOCBASE, $TBWWW, $WIKINODE, $WIKIDOCURL, $TBMAINSITE, $FORUMURL;
    global $ALTERNATE_DOMAINS, $FLAVOR, $DOMVIEW, $ISALTDOMAIN;

    foreach ($ALTERNATE_DOMAINS as $altdom) {
	list($dpat, $ovr) = $altdom;
	if (preg_match($dpat, $_SERVER['SERVER_NAME']) == 1) {
	    $ISALTDOMAIN  = 1;
	    # Replacement defs derived from the virtual domain itself.
	    $WWWHOST	  = $_SERVER['SERVER_NAME'];
	    $OURDOMAIN    = implode(".", array_slice(explode(".",$WWWHOST),1));
            # For devel trees
	    if (preg_match("/\/([\w\/]+)$/", $WWW, $matches)) {
	        $WWW      = $WWWHOST . "/" . $matches[1];
	    } else {
	        $WWW	  = $WWWHOST;
	    }
	    $TBAUTHDOMAIN = ".$OURDOMAIN";
	    $TBBASE	  = "https://$WWWHOST";
	    $TBDOCBASE	  = "http://$WWWHOST";
	    $TBWWW	  = "<$TBBASE/>";

	    # Defs that may be overriden in the domain's configuration array
	    if (isset($ovr['THISHOMEBASE'])) {
		$THISHOMEBASE = $ovr['THISHOMEBASE'];
		$FLAVOR       = $THISHOMEBASE;
	    }
	    if (isset($ovr['WIKINODE'])) {
		$WIKINODE     = $ovr['WIKINODE'];
	    } else {
		$WIKINODE     = "wiki.$OURDOMAIN";
	    }
	    if (isset($ovr['WIKIDOCURL'])) {
		$WIKIDOCURL   = $ovr['WIKIDOCURL'];
	    } else {
		$WIKIDOCURL   = "http://${WIKINODE}/wikidocs/wiki";
	    }
	    if (isset($ovr['FORUMURL'])) {
	        $FORUMURL     = $ovr['FORUMURL'];
	    }
	    if (isset($ovr['DOMVIEW'])) {
		$DOMVIEW      = $ovr['DOMVIEW'];
	    }

	    # Given that this is an alternate domain, clear TBMAINSITE
	    #$TBMAINSITE = 0;
	    
	    # Bail after the first domain match.
	    return 1;
	}
    }
    return 0;
}

#
# If the page was accessed via http redirect to https and exit
# otherwise do nothing
#
function RedirectHTTPS() {
    global $WWWHOST,$drewheader;
    if ($drewheader) {
	trigger_error(
	    "PAGEHEADER called before RedirectHTTPS ".
	    "Won't be able to redirect to HTTPS if necessary ".
	    "in ". $_SERVER['SCRIPT_FILENAME'] . ",",
	    E_USER_WARNING);
    } else if (!@$_SERVER['HTTPS'] && $_SERVER['REQUEST_METHOD'] == 'GET') {
	header("Location: https://$WWWHOST". $_SERVER['REQUEST_URI']);
	exit;
    }
}

#
# Clean out going string to be html safe.
#
function CleanString($string)
{
    return htmlspecialchars($string, ENT_QUOTES);
}

#
# Generate an authentication object to pass to the browser that
# is passed to the web server on boss. This is used to grant
# permission to the user to invoke ssh to a local node using their
# emulab generated (no passphrase) key. This is basically a clone
# of what GateOne does, but that code was a mess. 
#
function UnusedSSHAuthObject($uid)
{
    $file = "/usr/testbed/etc/sshauth.key";
    
    #
    # We need the secret that is shared with ops.
    #
    $fp = fopen($file, "r");
    if (! $fp) {
	TBERROR("Error opening $file", 0);
	return null;
    }
    list($api_key,$secret) = preg_split('/:/', fread($fp, 128));
    fclose($fp);
    if (!($secret && $api_key)) {
	TBERROR("Could not get key from $file", 0);
	return null;
    }
    $secret = chop($secret);

    $authobj = array(
	'api_key' => $api_key,
	'upn' => $uid,
	'timestamp' => time() . '000',
	'signature_method' => 'HMAC-SHA1',
	'api_version' => '1.0'
    );
    $authobj['signature'] = hash_hmac('sha1',
				      $authobj['api_key'] . $authobj['upn'] .
				      $authobj['timestamp'], $secret);
    $valid_json_auth_object = json_encode($authobj);

    return $valid_json_auth_object;
}

#
# Beware empty spaces (cookies)!
# 
require("tbauth.php3");

#
# Okay, this is what checks the login and spits out the menu.
#
require("Sajax.php");
require("menu.php3");
?>
