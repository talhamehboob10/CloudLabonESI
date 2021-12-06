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
# Login support: Beware empty spaces (cookies)!
#

# These global are to prevent repeated calls to the DB. 
#
$CHECKLOGIN_STATUS		= -1;
$CHECKLOGIN_UID			= 0;
$CHECKLOGIN_IDX			= null;
$CHECKLOGIN_NOLOGINS		= -1;
$CHECKLOGIN_WIKINAME            = "";
$CHECKLOGIN_HASHKEY             = null;
$CHECKLOGIN_HASHHASH            = null;
$CHECKLOGIN_USER                = null;

#
# New Mapping. 
#
define("CHECKLOGIN_NOSTATUS",		-1);
define("CHECKLOGIN_NOTLOGGEDIN",	0);
define("CHECKLOGIN_LOGGEDIN",		1);
define("CHECKLOGIN_TIMEDOUT",		2);
define("CHECKLOGIN_MAYBEVALID",		4);
define("CHECKLOGIN_STATUSMASK",		0x00000ff);
define("CHECKLOGIN_MODMASK",		0xfffff00);
#
# These are modifiers of the above status fields. They are stored
# as a bit field in the top part. This is intended to localize as
# many queries related to login as possible. 
#
define("CHECKLOGIN_NEWUSER",		0x0000100);
define("CHECKLOGIN_UNVERIFIED",		0x0000200);
define("CHECKLOGIN_UNAPPROVED",		0x0000400);
define("CHECKLOGIN_ACTIVE",		0x0000800);
define("CHECKLOGIN_USERSTATUS",		0x0000f00);
define("CHECKLOGIN_PSWDEXPIRED",	0x0001000);
define("CHECKLOGIN_FROZEN",		0x0002000);
define("CHECKLOGIN_ISADMIN",		0x0004000);
define("CHECKLOGIN_TRUSTED",		0x0008000);
define("CHECKLOGIN_CVSWEB",		0x0010000);
define("CHECKLOGIN_ADMINON",		0x0020000);
define("CHECKLOGIN_WEBONLY",		0x0040000);
define("CHECKLOGIN_PLABUSER",		0x0080000);
define("CHECKLOGIN_STUDLY",		0x0100000);
define("CHECKLOGIN_WIKIONLY",		0x0200000);
define("CHECKLOGIN_OPSGUY",		0x0400000);  # Member of emulab-ops.
define("CHECKLOGIN_ISFOREIGN_ADMIN",	0x0800000);  # Admin of another Emulab.
define("CHECKLOGIN_NONLOCAL",		0x1000000);
define("CHECKLOGIN_INACTIVE",		0x2000000);
define("CHECKLOGIN_NOPROJECTS",		0x4000000);
define("CHECKLOGIN_PROJDISABLED",	0x8000000);  # Member of disabled proj

#
# Constants for tracking possible login attacks.
#
define("DOLOGIN_MAXUSERATTEMPTS",	10);
define("DOLOGIN_MAXIPATTEMPTS",		15);

# Return codes for DOLOGIN so that the caller can say something helpful.
#
define("DOLOGIN_STATUS_OKAY",		0);
define("DOLOGIN_STATUS_ERROR",		-1);
define("DOLOGIN_STATUS_IPFREEZE",	-2);
define("DOLOGIN_STATUS_WEBFREEZE",	-3);
define("DOLOGIN_STATUS_INACTIVE",	-4);
define("DOLOGIN_STATUS_FROZEN", 	-5);
define("DOLOGIN_STATUS_PROJDISABLED", 	-6);
define("DOLOGIN_STATUS_NOGENIUSER", 	-7);

# So we can redefine this in the APT pages.
$CHANGEPSWD_PAGE = "moduserinfo.php3";

$HAVE_MHASH = 1;
$version = explode('.', PHP_VERSION);
if ($version[0] > 7 || ($version[0] == 7 && $version[1] >= 4)) {
   $HAVE_MHASH = 0;
}

#
# Generate a hash value suitable for authorization. We use the results of
# microtime, combined with a random number.
# 
function GENHASH() {
    $fp = fopen("/dev/urandom", "r");
    if (! $fp) {
        TBERROR("Error opening /dev/urandom", 1);
    }
    $random_bytes = fread($fp, 128);
    fclose($fp);

    if ($HAVE_MHASH) {
	$hash = mhash(MHASH_MD5, bin2hex($random_bytes) . " " . microtime());
	return bin2hex($hash);
    }
    return hash('md5', bin2hex($random_bytes) . " " . microtime(), false);
}

#
# Return the value of what we told the browser to remember for the login.
# Currently, this is an email address, stored in a long term cookie.
#
function REMEMBERED_ID() {
    global $TBEMAILCOOKIE;

    if (isset($_COOKIE[$TBEMAILCOOKIE])) {
	return $_COOKIE[$TBEMAILCOOKIE];
    }
    return null;
}
function ClearRememberedID()
{
    global $TBEMAILCOOKIE, $WWWHOST;
    
    setcookie($TBEMAILCOOKIE, '', 1, "/", $WWWHOST, 0);
}

#
# Return the value of the currently logged in uid, or null if not
# logged in. This interface is deprecated and being replaced.
# 
function GETLOGIN() {
    global $CHECKLOGIN_USER;
    
    if (CheckLogin($status))
	return $CHECKLOGIN_USER->uid();

    return FALSE;
}

#
# Return the value of the UID cookie. This does not check to see if
# this person is currently logged in. We just want to know what the
# browser thinks, if anything.
# 
function GETUID() {
    global $TBNAMECOOKIE;
    $status_archived = TBDB_USERSTATUS_ARCHIVED;
    $status_nonlocal = TBDB_USERSTATUS_NONLOCAL;

    if (isset($_GET['nocookieuid'])) {
	$uid = $_GET['nocookieuid'];
	
	#
	# XXX - nocookieuid is sent by netbuild applet in URL. A few other java
        # apps as well, and we retain this for backwards compatability.
	#
        # Pedantic check
	if (! preg_match("/^[-\w]+$/", $uid)) {
	    return FALSE;
	}
	$safe_uid = addslashes($uid);

	#
	# Map this to an index (from a uid).
	#
	$query_result =
	    DBQueryFatal("select uid_idx from users ".
			 "where uid='$safe_uid' and ".
			 "      status!='$status_archived' and ".
			 "      status!='$status_nonlocal'");
    
	if (! mysql_num_rows($query_result))
	    return FALSE;
	
	$row = mysql_fetch_array($query_result);
	return $row[0];
    }
    elseif (isset($_COOKIE[$TBNAMECOOKIE])) {
	$idx = $_COOKIE[$TBNAMECOOKIE];

        # Pedantic check
	if (! preg_match("/^[-\w]+$/", $idx)) {
	    return FALSE;
	}

	return $idx;
    }
    return FALSE;
}

#
# Verify a login by sucking UIDs current hash value out of the database.
# If the login has expired, or of the hashkey in the database does not
# match what came back in the cookie, then the UID is no longer logged in.
#
# Returns a combination of the CHECKLOGIN values above.
#
function LoginStatus() {
    global $TBAUTHCOOKIE, $TBLOGINCOOKIE, $TBAUTHTIMEOUT;
    global $CHECKLOGIN_STATUS, $CHECKLOGIN_UID, $CHECKLOGIN_NODETYPES;
    global $CHECKLOGIN_WIKINAME, $TBOPSPID;
    global $EXPOSEARCHIVE, $EXPOSETEMPLATES;
    global $CHECKLOGIN_HASHKEY, $CHECKLOGIN_HASHHASH;
    global $CHECKLOGIN_IDX, $CHECKLOGIN_USER;
    
    #
    # If we already figured this out, do not duplicate work!
    #
    if ($CHECKLOGIN_STATUS != CHECKLOGIN_NOSTATUS) {
	return $CHECKLOGIN_STATUS;
    }

    # No UID in the browser? Obviously not logged in!
    if (($uid_idx = GETUID()) == FALSE) {
	$CHECKLOGIN_STATUS = CHECKLOGIN_NOTLOGGEDIN;
	return $CHECKLOGIN_STATUS;
    }
    $CHECKLOGIN_IDX = $uid_idx;

    # for java applet, we can send the key in the $auth variable,
    # rather than passing it is a cookie.
    if (isset($_GET['nocookieauth'])) {
	$curhash = $_GET['nocookieauth'];
    }
    elseif (array_key_exists($TBAUTHCOOKIE, $_COOKIE)) {
	$curhash = $_COOKIE[$TBAUTHCOOKIE];
    }
    if (array_key_exists($TBLOGINCOOKIE, $_COOKIE)) {
	$hashhash = $_COOKIE[$TBLOGINCOOKIE];
    }

    #
    # We have to get at least one of the hashes. The Java applets do not
    # send it, but web browsers will.
    #
    if (!isset($curhash) && !isset($hashhash)) {
	$CHECKLOGIN_STATUS = CHECKLOGIN_NOTLOGGEDIN;
	return $CHECKLOGIN_STATUS;
    }
    if (isset($curhash) &&
	! preg_match("/^[\w]+$/", $curhash)) {
	$CHECKLOGIN_STATUS = CHECKLOGIN_NOTLOGGEDIN;
	return $CHECKLOGIN_STATUS;
    }
    if (isset($hashhash) &&
	! preg_match("/^[\w]+$/", $hashhash)) {
	$CHECKLOGIN_STATUS = CHECKLOGIN_NOTLOGGEDIN;
	return $CHECKLOGIN_STATUS;
    }

    if (isset($curhash)) {
	$CHECKLOGIN_HASHKEY = $safe_curhash = addslashes($curhash);
    }
    if (isset($hashhash)) {
	$CHECKLOGIN_HASHHASH = $safe_hashhash = addslashes($hashhash);
    }
    $safe_idx = addslashes($uid_idx);
    
    #
    # Note that we get multiple rows back because of the group_membership
    # join. No big deal.
    # 
    $query_result =
	DBQueryFatal("select NOW()>=u.pswd_expires,l.hashkey,l.timeout, ".
		     "       status,admin,cvsweb,g.trust,l.adminon,webonly, " .
		     "       user_interface,n.type,u.stud,u.wikiname, ".
		     "       u.wikionly,g.pid,u.foreign_admin,u.uid_idx, " .
		     "       p.allow_workbench,u.weblogin_frozen, ".
                     "       u.nonlocal_id,p.disabled ".
		     " from users as u ".
		     "left join login as l on l.uid_idx=u.uid_idx ".
		     "left join group_membership as g on g.uid_idx=u.uid_idx ".
		     "left join projects as p on p.pid_idx=g.pid_idx ".
		     "left join nodetypeXpid_permissions as n on g.pid=n.pid ".
		     "where u.uid_idx='$safe_idx' and ".
		     (isset($curhash) ?
		      "l.hashkey='$safe_curhash'" :
		      "l.hashhash='$safe_hashhash'"));

    # No such user.
    if (! mysql_num_rows($query_result)) { 
	$CHECKLOGIN_STATUS = CHECKLOGIN_NOTLOGGEDIN;
	return $CHECKLOGIN_STATUS;
    }
    
    #
    # Scan the rows. All the info is duplicate, except for the trust
    # values and the pid. pid is a hack.
    #
    $trusted   = 0;
    $opsguy    = 0;
    $workbench = 0;
    $frozen    = 0;
    $nonlocal  = 0;
    $pcount    = 0;
    $pdisabled = 0;
    
    while ($row = mysql_fetch_array($query_result)) {
	$expired = $row[0];
	$hashkey = $row[1];
	$timeout = $row[2];
	$status  = $row[3];
	$admin   = $row[4];
	$cvsweb  = $row[5];
        $trust   = $row[6];

        #
        # Count up number of projects where user has local_root or better.
        # These are projects where user has viable permission to do things,
        # like create experiments.
        #
        if ($trust != "none" && $trust != "user") {
            $pcount++;
        }
	if ($trust == "project_root" || $trust == "group_root") {
	    $trusted = 1;
	}
	$adminon  = $row[7];
	$webonly  = $row[8];
	$interface= $row[9];

	$type     = $row[10];
	$stud     = $row[11];
	$wikiname = $row[12];
	$wikionly = $row[13];

	# Check for an ops guy.
	$pid = $row[14];
	if ($pid == $TBOPSPID) {
	    $opsguy = 1;
	}

	# Set foreign_admin=1 for admins of another Emulab.
	$foreign_admin   = $row[15];
	$uid_idx         = $row[16];
	$workbench      += $row[17];
	$frozen          = $row[18];
	$nonlocal        = $row[19] ? 1 : 0;
        $disable         = $row[20];
        if ($disable) {
            $pdisabled++;
        }

	$CHECKLOGIN_NODETYPES[$type] = 1;
    }

    #
    # If user exists, but login has no entry, quit now.
    #
    if (!$hashkey) {
	$CHECKLOGIN_STATUS = CHECKLOGIN_NOTLOGGEDIN;
	return $CHECKLOGIN_STATUS;
    }

    #
    # Check for frozen account. Might do something interesting later.
    #
    if ($pdisabled || $frozen ||
	$status == TBDB_USERSTATUS_FROZEN) {
	DBQueryFatal("DELETE FROM login WHERE uid_idx='$uid_idx'");
	$CHECKLOGIN_STATUS = CHECKLOGIN_NOTLOGGEDIN;
	return $CHECKLOGIN_STATUS;
    }
    if ($status == TBDB_USERSTATUS_INACTIVE) {
	DBQueryFatal("DELETE FROM login WHERE uid_idx='$uid_idx'");
	$CHECKLOGIN_STATUS = CHECKLOGIN_NOTLOGGEDIN;
	return $CHECKLOGIN_STATUS;
    }

    #
    # Check for expired login. Remove this entry from the logins table to
    # keep it from getting cluttered.
    #
    if (time() > $timeout) {
	DBQueryFatal("delete from login where ".
		     "uid_idx='$uid_idx' and hashkey='$hashkey'");
	$CHECKLOGIN_STATUS = CHECKLOGIN_TIMEDOUT;
	return $CHECKLOGIN_STATUS;
    }

    #
    # We know the login has not expired. The problem is that we might not
    # have received a cookie since that is set to transfer only when using
    # https. However, we do not want the menu to be flipping back and forth
    # each time the user uses http (say, for documentation), and so the lack
    # of a cookie does not provide enough info to determine if the user is
    # logged in or not from the current browser. Also, we want to allow for
    # a user to switch browsers, and not get confused by getting a uid but
    # no valid cookie from the new browser. In that case the user should just
    # be able to login from the new browser; gets a standard not-logged-in
    # front page. In order to accomplish this, we need another cookie that is
    # set on login, cleared on logout.
    #
    if (isset($curhash)) {
	#
	# Got a cookie (https).
	#
	if ($curhash != $hashkey) {
	    #
	    # User is not logged in from this browser. Must be stale.
	    # 
	    $CHECKLOGIN_STATUS = CHECKLOGIN_NOTLOGGEDIN;
	    return $CHECKLOGIN_STATUS;
	}
	else {
            #
	    # User is logged in.
	    #
	    $CHECKLOGIN_STATUS = CHECKLOGIN_LOGGEDIN;
	}
    }
    else {
	#
	# No cookie. Might be because its http, so there is no way to tell
	# if user is not logged in from the current browser without more
	# information. We use another cookie for this, which is a crc of
	# of the real hash, and simply tells us what menu to draw, but does
	# not impart any privs!
	#
	if (isset($hashhash)) {
	    if ($HAVE_MHASH) {
		$newhash = bin2hex(mhash(MHASH_CRC32, $hashkey));
	    }
	    else {
		$newhash = hash('crc32', $hashkey, false);
	    }
	    if ($hashhash == $newhash) {
		#
		# The login is probably valid, but we have no proof yet. 
		#
		$CHECKLOGIN_STATUS = CHECKLOGIN_MAYBEVALID;
	    }
	    else {
		#
	    	# Hash of hash is invalid, so assume no real cookie either. 
	    	# 
		$CHECKLOGIN_STATUS = CHECKLOGIN_NOTLOGGEDIN;
	    }
	}
	else {
	    #
	    # No hash of the hash, so assume no real cookie either. 
	    # 
	    $CHECKLOGIN_STATUS = CHECKLOGIN_NOTLOGGEDIN;
	}
	return $CHECKLOGIN_STATUS;
    }

    # Cache this now; someone will eventually want it.
    $CHECKLOGIN_USER = User::Lookup($uid_idx);
    if (! $CHECKLOGIN_USER) {
	$CHECKLOGIN_STATUS = CHECKLOGIN_NOTLOGGEDIN;
	return $CHECKLOGIN_STATUS;
    }
    $ga_userid = $CHECKLOGIN_USER->ga_userid();
    if (!$ga_userid) {
        $ga_userid = substr(GENHASH(), 0, 32);
        $CHECKLOGIN_USER->SetGaUserid($ga_userid);
    }
    
    #
    # Now add in the modifiers.
    #
    # Do not expire passwords for admin users.
    if (!is_null($expired) && $expired && !$admin &&
        !$CHECKLOGIN_USER->nonlocal_id())
	$CHECKLOGIN_STATUS |= CHECKLOGIN_PSWDEXPIRED;
    if ($admin)
	$CHECKLOGIN_STATUS |= CHECKLOGIN_ISADMIN;
    if ($adminon)
	$CHECKLOGIN_STATUS |= CHECKLOGIN_ADMINON;
    if ($webonly)
	$CHECKLOGIN_STATUS |= CHECKLOGIN_WEBONLY;
    if ($wikionly)
	$CHECKLOGIN_STATUS |= CHECKLOGIN_WIKIONLY;
    if ($trusted)
	$CHECKLOGIN_STATUS |= CHECKLOGIN_TRUSTED;
    if ($stud)
	$CHECKLOGIN_STATUS |= CHECKLOGIN_STUDLY;
    if ($cvsweb)
	$CHECKLOGIN_STATUS |= CHECKLOGIN_CVSWEB;
    if ($interface == TBDB_USER_INTERFACE_PLAB)
	$CHECKLOGIN_STATUS |= CHECKLOGIN_PLABUSER;
    if (strcmp($status, TBDB_USERSTATUS_NEWUSER) == 0)
	$CHECKLOGIN_STATUS |= CHECKLOGIN_NEWUSER;
    if (strcmp($status, TBDB_USERSTATUS_UNAPPROVED) == 0)
	$CHECKLOGIN_STATUS |= CHECKLOGIN_UNAPPROVED;
    if (strcmp($status, TBDB_USERSTATUS_UNVERIFIED) == 0)
	$CHECKLOGIN_STATUS |= CHECKLOGIN_UNVERIFIED;
    if (strcmp($status, TBDB_USERSTATUS_ACTIVE) == 0)
	$CHECKLOGIN_STATUS |= CHECKLOGIN_ACTIVE;
    if (strcmp($status, TBDB_USERSTATUS_INACTIVE) == 0)
	$CHECKLOGIN_STATUS |= CHECKLOGIN_INACTIVE;
    if (isset($wikiname) && $wikiname != "")
	$CHECKLOGIN_WIKINAME = $wikiname;
    if ($opsguy)
	$CHECKLOGIN_STATUS |= CHECKLOGIN_OPSGUY;
    if ($foreign_admin)
	$CHECKLOGIN_STATUS |= CHECKLOGIN_ISFOREIGN_ADMIN;
    if ($nonlocal)
	$CHECKLOGIN_STATUS |= CHECKLOGIN_NONLOCAL;
    #
    # A local user that has no privs in at least one project, or a nonlocal
    # user where webonly=1 (which means they have project membership at
    # their home portal). 
    #
    if ($nonlocal) {
        if ($webonly) {
            $CHECKLOGIN_STATUS |= CHECKLOGIN_NOPROJECTS;
        }
    }
    else {
        if (!$pcount) {
            $CHECKLOGIN_STATUS |= CHECKLOGIN_NOPROJECTS;
        }
    }

    #
    # Set the magic enviroment variable, if appropriate, for the sake of
    # any processes we might spawn. We prepend an HTTP_ on the front of
    # the variable name, so that it will get through suexec.
    #
    if ($admin && $adminon) {
    	putenv("HTTP_WITH_TB_ADMIN_PRIVS=1");
    }
    #
    # This environment variable is likely to become the new method for
    # specifying the credentials of the invoking user. Still thinking
    # about this, but the short story is that the web interface should
    # not invoke so much stuff as the user, but rather as a neutral user
    # with implied credentials. 
    #
    putenv("HTTP_INVOKING_USER=" . $CHECKLOGIN_USER->webid());
    
    # XXX Temporary.
    if ($stud) {
	$EXPOSEARCHIVE = 1;
    }
    if ($workbench) {
	$EXPOSETEMPLATES = $EXPOSEARCHIVE = 1;
    }
    return $CHECKLOGIN_STATUS;
}

#
# This one checks for login, but then dies with an appropriate error
# message. The modifier allows you to turn off checks for specified
# conditions. 
#
function LOGGEDINORDIE($uid, $modifier = 0) {
    global $TBBASE, $BASEPATH;
    global $TBAUTHTIMEOUT, $CHECKLOGIN_HASHKEY, $CHECKLOGIN_IDX;
    global $drewheader;

    if ($drewheader) {
	trigger_error(
	    "PAGEHEADER called before LOGGEDINORDIE ".
	    "(called by CheckLoginOrDie). ".
	    "Won't be able to redirect to the login page or ".
            "return proper HTTP status code on Error ".
	    "in ". $_SERVER['SCRIPT_FILENAME'] . ",",
	    E_USER_WARNING);
    }

    $redirect_url = null;
    $login_url = "$TBBASE/login.php3";
    if ($uid || REMEMBERED_ID()) {
        # HTTP_REFERER will not work reliably when redirecting so
        # pass in the URI for this page as an argument
        $redirect_url = "$TBBASE/login.php3?referrer=".
            urlencode($_SERVER['REQUEST_URI']);
    }

    $link = "\n<a href=\"$login_url\">Please ".
	"log in again.</a>\n";

    $status = LoginStatus();

    switch ($status & CHECKLOGIN_STATUSMASK) {
    case CHECKLOGIN_NOTLOGGEDIN:
	if ($redirect_url) {
	    header("Location: $redirect_url&error=notloggedin");
	    exit;
        } else {
            USERERROR("You do not appear to be logged in! $link",
		      1, HTTP_403_FORBIDDEN);
        }
        break;
    case CHECKLOGIN_TIMEDOUT:
	if ($redirect_url) {
	    header("Location: $redirect_url&error=timedout");
	    exit;
        } else {
            USERERROR("Your login has timed out! $link",
		      1, HTTP_403_FORBIDDEN);
        }
        break;
    case CHECKLOGIN_MAYBEVALID:
	# This error can happen if a user tries to access a page with
	# via http instead of https, so try to redirect to https first
	RedirectHTTPS(); # will not return if accesses via http
	USERERROR("Your login cannot be verified. Are cookies turned on? ".
		  "Are you using https? Are you logged in using another ".
		  "browser or another machine? $link", 1, HTTP_403_FORBIDDEN);
        break;
    case CHECKLOGIN_LOGGEDIN:
	BumpLogoutTime();
	break;
    default:
	TBERROR("LOGGEDINORDIE failed mysteriously", 1);
    }

    CheckLoginConditions($status & ~$modifier);

    # No one should ever look at the return value of this function.
    return null;
}

#
# Check other conditions.
#
function CheckLoginConditions($status)
{
    global $CHANGEPSWD_PAGE, $TBMAILADDR;
    
    if ($status & CHECKLOGIN_PSWDEXPIRED)
        USERERROR("Your password has expired. ".
		  "<a href='$CHANGEPSWD_PAGE'>Please change it now.</a>",
		  1, HTTP_403_FORBIDDEN);
    if ($status & CHECKLOGIN_FROZEN)
        USERERROR("Your account has been frozen!",
		  1, HTTP_403_FORBIDDEN);
    if ($status & CHECKLOGIN_INACTIVE)
        USERERROR("Your account has gone inactive since your last login was ".
                  "so long ago. Please contact $TBMAILADDR to restore it.",
		  1, HTTP_403_FORBIDDEN);
    if ($status & (CHECKLOGIN_UNVERIFIED|CHECKLOGIN_NEWUSER))
        USERERROR("You have not verified your account yet!",
		  1, HTTP_403_FORBIDDEN);
    if ($status & CHECKLOGIN_UNAPPROVED)
        USERERROR("Your account has not been approved yet! ".
                  "<br>Please wait till ".
                  "your account is approved (you will receive email) and then ".
                  "reload this page.",
		  1, HTTP_403_FORBIDDEN);
    if (($status & CHECKLOGIN_WEBONLY) && ! ISADMIN())
        USERERROR("Your account does not permit you to access this page!",
		  1, HTTP_403_FORBIDDEN);
    if ($status & CHECKLOGIN_NONLOCAL)
        USERERROR("Your account does not permit you to access this page!",
		  1, HTTP_403_FORBIDDEN);
    if (($status & CHECKLOGIN_WIKIONLY) && ! ISADMIN())
        USERERROR("Your account does not permit you to access this page!",
		  1, HTTP_403_FORBIDDEN);

    #
    # Lastly, check for nologins here. This heads off a bunch of other
    # problems and checks we would need.
    #
    if (NOLOGINS() && !ISADMIN())
        USERERROR("Sorry. The Web Interface is ".
		  "temporarily unavailable. Please check back later.", 1);
}

#
# This is the new interface to the above function. 
#
function CheckLoginOrDie($modifier = 0)
{
    global $CHECKLOGIN_USER;
    
    LOGGEDINORDIE(GETUID(), $modifier, $login_url);

    #
    # If this returns, login is valid. Return the user object to caller.
    #
    return $CHECKLOGIN_USER;
}

#
# This interface allows the return of the actual status. I know, its a
# global variable, but this interface is cleaner. 
#
function CheckLogin(&$status)
{
    global $CHECKLOGIN_USER, $CHECKLOGIN_STATUS;

    $status = LoginStatus();

    # If login looks valid, return the user. 
    if ($status & (CHECKLOGIN_LOGGEDIN|CHECKLOGIN_MAYBEVALID)) {
	#
        # Check for NOLOGINS. 
        # We want to allow admin types to continue using the web interface,
        # and logout anyone else that is currently logged in!
	#
	if (NOLOGINS() && !ISADMIN()) {
	    DOLOGOUT($CHECKLOGIN_USER);
	    $status = $CHECKLOGIN_STATUS;
	    return null;
	}
	if ($status & CHECKLOGIN_LOGGEDIN) {
	    BumpLogoutTime();
	}
	return $CHECKLOGIN_USER;
    }
    return null;
}

#
# Is this user an admin type, and is his admin bit turned on.
# Its actually incorrect to look at the $uid. Its the currently logged
# in user that has to be admin. So ignore the uid and make sure
# there is a login status.
#
function ISADMIN() {
    global $CHECKLOGIN_STATUS;
    
    if ($CHECKLOGIN_STATUS == CHECKLOGIN_NOSTATUS) {
	return 0;
    }

    return (($CHECKLOGIN_STATUS &
	     (CHECKLOGIN_LOGGEDIN|CHECKLOGIN_ISADMIN|CHECKLOGIN_ADMINON)) ==
	    (CHECKLOGIN_LOGGEDIN|CHECKLOGIN_ISADMIN|CHECKLOGIN_ADMINON));
}


# Is this user an admin of another Emulab.
function ISFOREIGN_ADMIN($uid = 1) {
    global $CHECKLOGIN_STATUS;

    # Definitely not, if not logged in.
    if ($CHECKLOGIN_STATUS == CHECKLOGIN_NOSTATUS) {
	return 0;
    }

    return (($CHECKLOGIN_STATUS &
	     (CHECKLOGIN_LOGGEDIN|CHECKLOGIN_ISFOREIGN_ADMIN)) ==
	    (CHECKLOGIN_LOGGEDIN|CHECKLOGIN_ISFOREIGN_ADMIN));
}

function STUDLY() {
    global $CHECKLOGIN_STATUS;
    
    if ($CHECKLOGIN_STATUS == CHECKLOGIN_NOSTATUS) {
	TBERROR("STUDLY: user is not logged in!", 1);
    }

    return (($CHECKLOGIN_STATUS &
	     (CHECKLOGIN_LOGGEDIN|CHECKLOGIN_STUDLY)) ==
	    (CHECKLOGIN_LOGGEDIN|CHECKLOGIN_STUDLY));
}

function OPSGUY() {
    global $CHECKLOGIN_STATUS;
    
    if ($CHECKLOGIN_STATUS == CHECKLOGIN_NOSTATUS) {
	TBERROR("OPSGUY: user is not logged in!", 1);
    }

    return (($CHECKLOGIN_STATUS &
	     (CHECKLOGIN_LOGGEDIN|CHECKLOGIN_OPSGUY)) ==
	    (CHECKLOGIN_LOGGEDIN|CHECKLOGIN_OPSGUY));
}

function WIKIONLY() {
    global $CHECKLOGIN_STATUS;
    
    if ($CHECKLOGIN_STATUS == CHECKLOGIN_NOSTATUS) {
	TBERROR("WIKIONLY: user is not logged in!", 1);
    }

    return (($CHECKLOGIN_STATUS &
	     (CHECKLOGIN_LOGGEDIN|CHECKLOGIN_WIKIONLY)) ==
	    (CHECKLOGIN_LOGGEDIN|CHECKLOGIN_WIKIONLY));
}

function NOPROJECTMEMBERSHIP() {
    global $CHECKLOGIN_STATUS;

    return (($CHECKLOGIN_STATUS &
	     (CHECKLOGIN_LOGGEDIN|CHECKLOGIN_NOPROJECTS)) ==
	    (CHECKLOGIN_LOGGEDIN|CHECKLOGIN_NOPROJECTS));
}

# Is this user a real administrator (ignore onoff bit).
function ISADMINISTRATOR() {
    global $CHECKLOGIN_STATUS;
    
    if ($CHECKLOGIN_STATUS == CHECKLOGIN_NOSTATUS)
	TBERROR("ISADMINISTRATOR: $uid is not logged in!", 1);

    return (($CHECKLOGIN_STATUS &
	     (CHECKLOGIN_LOGGEDIN|CHECKLOGIN_ISADMIN)) ==
	    (CHECKLOGIN_LOGGEDIN|CHECKLOGIN_ISADMIN));
}

#
# Toggle current login admin bit. Must be an administrator of course!
#
function SETADMINMODE($onoff) {
    global $CHECKLOGIN_HASHKEY, $CHECKLOGIN_IDX;
    
    # This makes sure the user is actually logged in secure (https).
    if (! ISADMINISTRATOR())
	return;

    # Be pedantic.
    if (! ($CHECKLOGIN_HASHKEY && $CHECKLOGIN_IDX))
	return;

    $onoff   = addslashes($onoff);
    $curhash = addslashes($CHECKLOGIN_HASHKEY);
    $uid_idx = $CHECKLOGIN_IDX;
    
    DBQueryFatal("update login set adminon='$onoff' ".
		 "where uid_idx='$uid_idx' and hashkey='$curhash'");
}

# Is this user a planetlab user? Returns 1 if they are, 0 if not.
function ISPLABUSER() {
    global $CHECKLOGIN_STATUS;

    if ($CHECKLOGIN_STATUS == CHECKLOGIN_NOSTATUS) {
	#
	# For users who are not logged in, we need to check the database
	#
	$uid = GETUID();
	if (!$uid) {
	    return 0;
	}
	# Lookup sanitizes argument.
	if (! ($user = User::Lookup($uid)))
	    return 0;

	if ($user->user_interface()) {
	    return ($user->user_interface() == TBDB_USER_INTERFACE_PLAB);
	}
	else {
	    return 0;
	}
    } else {
	#
	# For logged-in users, we recorded it in the the login status
	#
	return (($CHECKLOGIN_STATUS &
		 (CHECKLOGIN_PLABUSER)) ==
		(CHECKLOGIN_PLABUSER));
    }
}

#
# Check to see if a user is allowed, in some project, to use the given node
# type. Returns 1 if allowed, 0 if not.
#
# NOTE: This is NOT intended as a real permissions check. It is intended only
# for display purposes (ie. deciding whether or not to give the user a link to
# the plab_ez page.) It does not require the user to be actually logged in, so
# that it still works for pages fetched through http. Thus, it may be possible
# for a clever user to fake it out.
#
function NODETYPE_ALLOWED($type) {
    global $CHECKLOGIN_NODETYPES;

    if (! GETUID())
	return 0;

    if (isset($CHECKLOGIN_NODETYPES[$type])) {
	return 1;
    } else {
	return 0;
    }
}

#
# Attempt a login.
# 
function DOLOGIN($token, $password, $adminmode = 0, $nopassword = 0) {
    global $TBAUTHCOOKIE, $TBAUTHDOMAIN, $TBAUTHTIMEOUT;
    global $TBNAMECOOKIE, $TBLOGINCOOKIE, $TBSECURECOOKIES;
    global $TBMAIL_OPS, $TBMAIL_AUDIT, $TBMAIL_WWW;
    global $WIKISUPPORT, $WIKICOOKIENAME;
    global $BUGDBSUPPORT, $BUGDBCOOKIENAME, $CHECKLOGIN_USER;
    global $TB_PROJECT_READINFO;
    
    # Caller makes these checks too.
    if ((!TBvalid_uid($token) && !TBvalid_email($token)) ||
	((!isset($password) || $password == "") && !$nopassword)) {
	return DOLOGIN_STATUS_ERROR;
    }
    $now = time();

    if (0) {
        TBMAIL("stoller@flux.utah.edu", "password $token: ", "'$password'");
    }

    #
    # Check for a frozen IP address; too many failures.
    #
    unset($iprow);
    unset($IP);
    if (isset($_SERVER['REMOTE_ADDR'])) {
	$IP = $_SERVER['REMOTE_ADDR'];
	
	$ip_result =
	    DBQueryFatal("select * from login_failures ".
			 "where IP='$IP'");

	if ($iprow = mysql_fetch_array($ip_result)) {
	    $ipfrozen = $iprow['frozen'];

	    if ($ipfrozen) {
                #TBMAIL('stoller', "Login Debug", "Disabled IP $token $IP");
                
		DBQueryFatal("update login_failures set ".
			     "       failcount=failcount+1, ".
			     "       failstamp='$now' ".
			     "where IP='$IP'");
		return DOLOGIN_STATUS_IPFREEZE;
	    }
	}
    }

    if (TBvalid_email($token)) {
	$user = User::LookupByEmail($token);
    }
    else {
	$user = User::Lookup($token);
    }
	    
    #
    # Check password in the database against provided. 
    #
    do {
      if ($user) {
	$uid         = $user->uid();
        $db_encoding = $user->pswd();
	$isadmin     = $user->admin();
	$frozen      = $user->weblogin_frozen();
	$failcount   = $user->weblogin_failcount();
	$failstamp   = $user->weblogin_failstamp();
	$usr_email   = $user->email();
	$usr_name    = $user->name();
	$uid_idx     = $user->uid_idx();
	$usr_email   = $user->email();
        $ga_userid   = $user->ga_userid();
        $lastlogin   = $user->weblogin_last();

        #
        # Yuck.
        #
        if (preg_match("/impscet\.net$/", $usr_email) ||
            preg_match("/ril\.com$/", $usr_email) ||
            preg_match("/gavilan\.edu$/", $usr_email)) {
            break;
        }

	# Check for frozen accounts. We do not update the IP record when
	# an account is frozen.
	if ($frozen) {
	    $user->UpdateWebLoginFail();
	    return DOLOGIN_STATUS_WEBFREEZE;
	}
        # Check for membership in disabled project.
        $plist = $user->DisabledProjects();
        if (count($plist)) {
            return DOLOGIN_STATUS_PROJDISABLED;
        }
        # Check for a geni user trying to login with a password.
        if (!$nopassword && $user->nonlocal_id()) {
            return DOLOGIN_STATUS_NOGENIUSER;
        }
        
	if (!$nopassword) {
	    $encoding = crypt("$password", $db_encoding);
	    if (strcmp($encoding, $db_encoding)) {
		#
                # Bump count and check for too many consecutive failures.
	        #
		$failcount++;
		if ($failcount > DOLOGIN_MAXUSERATTEMPTS) {
		    $user->SetWebFreeze(1);
		
		    TBMAIL("$usr_name '$uid' <$usr_email>",
			   "Web Login Freeze: '$uid'",
			   "Your login has been frozen because there were too many\n".
			   "login failures from " . $_SERVER['REMOTE_ADDR'] . ".\n\n".
			   "Testbed Operations has been notified.\n".
                           (isset($PORTAL_GENESIS) ?
                            "Portal: $PORTAL_GENESIS" :
                            "Classic Interface") . "\n",
                           
			   "From: $TBMAIL_OPS\n".
			   "Cc: $TBMAIL_OPS\n".
			   "Bcc: $TBMAIL_AUDIT\n".
			   "Errors-To: $TBMAIL_WWW");
		}
		$user->UpdateWebLoginFail();
		break;
	    }
	}
	#
	# Pass!
	#
        if (!$ga_userid) {
            $ga_userid = substr(GENHASH(), 0, 32);
            $user->SetGaUserid($ga_userid);
        }
        
        # But inactive/frozen users need special handling.
	if ($user->status() == TBDB_USERSTATUS_FROZEN) {
          return DOLOGIN_STATUS_FROZEN;
        }
	elseif ($user->status() == TBDB_USERSTATUS_INACTIVE) {
            if (1) {
                TBMAIL($user->email(),
                       "Web Login Inactivity Alert: '$uid'",
                       "Login attempt by $uid ($uid_idx) after extended ".
                       "period of inactivity!\n".
                       "Login was denied, last activity was $lastlogin\n",
                       "From: $TBMAIL_OPS\n".
                       "Bcc: $TBMAIL_AUDIT\n".
                       "CC: $TBMAIL_OPS\n".
                       "Errors-To: $TBMAIL_WWW");
                
                return DOLOGIN_STATUS_INACTIVE;
            }
            # Try to reactivate the user. If we fail for some reason, fall
            # back to just telling them they are inactive. Otherwise we can
            # proceed with login.
            if (ReactivateUser($user)) {
                return DOLOGIN_STATUS_INACTIVE;
            }
	}

	#
	# Set adminmode off on new logins, unless user requested to be
	# logged in as admin (and is an admin of course!). This is
	# primarily to bypass the nologins directive which makes it
	# impossible for an admin to login when the web interface is
	# turned off. 
	#
	$adminon = 0;
	if ($adminmode && $isadmin) {
	    $adminon = 1;
	}

        #
        # Insert a record in the login table for this uid.
	#
	if (DOLOGIN_MAGIC($uid, $uid_idx, $usr_email, $adminon) < 0) {
	    return DOLOGIN_STATUS_ERROR;
	}
	$CHECKLOGIN_USER = $user;

	# Clear IP record since we have a sucessful login from the IP.
	if (isset($IP)) {
	    DBQueryFatal("delete from login_failures where IP='$IP'");
	}
	return DOLOGIN_STATUS_OKAY;
      }
    } while (0);
    #
    # No such user
    #
    if (!isset($IP)) {
	return DOLOGIN_STATUS_ERROR;
    }

    $ipfrozen = 0;
    if (isset($iprow)) {
	$ipfailcount = $iprow['failcount'];

        #
        # Bump count.
        #
	$ipfailcount++;
    }
    else {
	#
	# First failure.
	# 
	$ipfailcount = 1;
    }

    #
    # Check for too many consecutive failures.
    #
    if ($ipfailcount > DOLOGIN_MAXIPATTEMPTS) {
	$ipfrozen = 1;
	    
	TBMAIL($TBMAIL_OPS,
	       "Web Login Freeze: '$IP'",
	       "Logins has been frozen because there were too many login\n".
	       "failures from $IP. Last attempted uid was '$token'.\n".
               (isset($PORTAL_GENESIS) ?
                "Portal: $PORTAL_GENESIS" : "Classic Interface") . "\n\n",
	       "From: $TBMAIL_OPS\n".
	       "Bcc: $TBMAIL_AUDIT\n".
	       "Errors-To: $TBMAIL_WWW");
    }
    DBQueryFatal("replace into login_failures set ".
		 "       IP='$IP', ".
		 "       frozen='$ipfrozen', ".
		 "       failcount='$ipfailcount', ".
		 "       failstamp='$now'");
    return DOLOGIN_STATUS_ERROR;
}

function DOLOGIN_MAGIC($uid, $uid_idx, $email = null,
		       $adminon = 0, $nosetcookies = 0)
{
    global $TBAUTHCOOKIE, $TBAUTHDOMAIN, $TBAUTHTIMEOUT, $WWWHOST;
    global $TBNAMECOOKIE, $TBLOGINCOOKIE, $TBSECURECOOKIES, $TBEMAILCOOKIE;
    global $TBMAIL_OPS, $TBMAIL_AUDIT, $TBMAIL_WWW;
    global $WIKISUPPORT, $WIKICOOKIENAME;
    global $BUGDBSUPPORT, $BUGDBCOOKIENAME, $TRACSUPPORT, $TRACCOOKIENAME;
    global $TBLIBEXEC_DIR, $EXP_VIS, $TBMAINSITE;
    global $WITHZFS, $ZFS_NOEXPORT;
    global $PORTAL_GENESIS;

    $flushtime = time() - 1000000;
    
    # Caller makes these checks too.
    if (!TBvalid_uid($uid)) {
	return -1;
    }
    if (!TBvalid_uididx($uid_idx)) {
	return -1;
    }
    $now = time();

    if (isset($_SERVER['REMOTE_ADDR'])) {
	$IP = $_SERVER['REMOTE_ADDR'];
    }
        
    #
    # Insert a record in the login table for this uid with
    # the new hash value. If the user is already logged in, thats
    # okay; just update it in place with a new hash and timeout. 
    #
    # One hour initially, it will get bumped as soon as they hit another page.
    $timeout = $now + 3600;
    $hashkey = GENHASH();
    # See note in CrossLogin() in db/User.pm.in. Do not change this.
    if ($HAVE_MHASH) {
	$crc = bin2hex(mhash(MHASH_CRC32, $hashkey));
    } else {
	$crc = hash('crc32', $hashkey, false);
    }
    $opskey  = GENHASH();

    #
    # Ug. When using ZFS in NOEXPORT mode, we have to call exports_setup
    # to get the mounts exported to back to boss. We do not want to do this
    # every time the user logs in of course, and since exports_setup is 
    # using one week as its threshold, we can use that as the limit.
    #
    $exports_active = TBGetSiteVar("general/export_active");

    # We get the email at the same time for inactivity warning.
    $query_result =
        DBQueryFatal("select UNIX_TIMESTAMP(last_activity),last_activity, ".
                     "       UNIX_TIMESTAMP(weblogin_last),weblogin_last, ".
                     "       usr_email ".
                     "  from users as u ".
                     "left join user_stats as s on s.uid_idx=u.uid_idx ".
                     "where u.uid_idx='$uid_idx'");
    
    if (!mysql_num_rows($query_result)) {
        return -1;
    }
    $lastrow       = mysql_fetch_row($query_result);
    $lastactive    = $lastrow[0];
    $lastactivestr = $lastrow[1];
    $lastlogin     = $lastrow[2];
    $lastloginstr  = $lastrow[3];
    $usr_email     = $lastrow[4];
    
    if ($WITHZFS && $ZFS_NOEXPORT && $exports_active) {
        $limit = (($exports_active * 24) - 12) * 3600;
        
        # Update last_activity first so exports_setup will do something
        # and to mark activity to keep the mount active.
        DBQueryFatal("update user_stats set last_activity=now() ".
                     "where uid_idx='$uid_idx'");

        $history = "insert into login_history set ".
            "   idx=null,uid='$uid',uid_idx='$uid_idx',tstamp=now()";
        
        if (isset($IP)) {
            $history .= ",IP='$IP'";
        }
        if (isset($PORTAL_GENESIS)) {
            $history .= ",portal='$PORTAL_GENESIS'";
        }
        DBQueryFatal($history);
        
        if (time() - $lastactive > $limit) {
            $rv = SUEXEC("nobody", "nobody", "webexports_setup",
                         SUEXEC_ACTION_IGNORE);
            
            # failed, reset the timestamp
            if ($rv) {
                if ($lastactivestr != '') {                
                    DBQueryFatal("update user_stats set ".
                                 " last_activity='$lastactivestr' ".
                                 "where uid_idx='$uid_idx'");
                }
                SUEXECERROR(SUEXEC_ACTION_DIE);
                return;
            }
        }
    }
    if ($lastlogin && 
        time() - $lastlogin > (3600 * 24 * 365)) {
        TBMAIL($usr_email,
               "Web Login Inactivity Alert: '$uid'",
               "Login by $uid ($uid_idx) after extended period ".
               "of inactivity!\n".
               "Last activity was $lastloginstr\n",
               "From: $TBMAIL_OPS\n".
               "Bcc: $TBMAIL_AUDIT\n".
               "CC: $TBMAIL_OPS\n".
               "Errors-To: $TBMAIL_WWW");
    }
    DBQueryFatal("replace into login ".
		 "  (uid,uid_idx,hashkey,hashhash,timeout,adminon,opskey) ".
                 " values ".
		 "  ('$uid', $uid_idx, '$hashkey', '$crc', '$timeout', ".
                 "    $adminon, '$opskey')");
    if (isset($PORTAL_GENESIS)) {
        DBQueryFatal("update login set portal='$PORTAL_GENESIS' ".
                     "where uid_idx='$uid_idx' and hashkey='$hashkey'");
    }

    DBQueryFatal("update users set ".
		 "       weblogin_failcount=0,weblogin_failstamp=0 ".
		 "where uid_idx='$uid_idx'");
    
    #
    # Usage stats. 
    #
    DBQueryFatal("update user_stats set ".
		 " weblogin_count=weblogin_count+1, ".
		 " weblogin_last=now() ".
		 "where uid_idx='$uid_idx'");

    # Does the caller just want the cookies for itself.
    if ($nosetcookies) {
	return array($hashkey, $crc);
    }

    #
    # Issue the cookie requests so that subsequent pages come back
    # with the hash value and auth usr embedded.

    #
    # Since we changed the domain of the cookies make sure that the cookies 
    # from the old domain no longer exist.
    #
    setcookie($TBAUTHCOOKIE, '', 1, "/", $TBAUTHDOMAIN, $TBSECURECOOKIES);
    setcookie($TBLOGINCOOKIE, '', 1, "/", $TBAUTHDOMAIN, 0);
    setcookie($TBNAMECOOKIE, '', 1, "/", $TBAUTHDOMAIN, 0);
    if ($email)
      setcookie($TBEMAILCOOKIE, '', 1, "/", $TBAUTHDOMAIN, 0);

    #
    # For the hashkey, we use a zero timeout so that the cookie is
    # a session cookie; killed when the browser is exited. Hopefully this
    # keeps the key from going to disk on the client machine. The cookie
    # lives as long as the browser is active, but we age the cookie here
    # at the server so it will become invalid at some point.
    #
    setcookie($TBAUTHCOOKIE, $hashkey, 0, "/",
	      $WWWHOST, $TBSECURECOOKIES);

    #
    # Another cookie, to help in menu generation. See above in
    # checklogin. This cookie is a simple hash of the real hash,
    # intended to indicate if the current browser holds a real hash.
    # All this does is change the menu options presented, imparting
    # no actual privs. 
    #
    setcookie($TBLOGINCOOKIE, $crc, 0, "/", $WWWHOST, 0);

    #
    # We want to remember who the user was each time they load a page
    # NOTE: This cookie is integral to authorization, since we do not pass
    # around the UID anymore, but look for it in the cookie.
    #
    setcookie($TBNAMECOOKIE, $uid_idx, 0, "/", $WWWHOST, 0);

    #
    # This is a long term cookie so we can remember who the user was, and
    # and stick that in the login box.
    #
    if ($email) {
	$timeout = $now + (60 * 60 * 24 * 365);
	setcookie($TBEMAILCOOKIE, $email, $timeout, "/", $WWWHOST, 0);
    }

    #
    # Clear the existing Wiki cookie so that there is not an old one
    # for a different user, sitting in the brower. 
    # 
    if ($WIKISUPPORT || $TBMAINSITE) {
	setcookie($WIKICOOKIENAME, "", $flushtime, "/",
		  $TBAUTHDOMAIN, $TBSECURECOOKIES);
    }
    if (0) {
	#
	# Some incomplete code for auto login to new (plone based) wiki.
	#
	setcookie("emulab_wiki",
		  "user=$uid&hash=Fooey", time() + 5000, "/", $TBAUTHDOMAIN, 0);
    }
    
    #
    # Ditto for bugdb
    # 
    if ($BUGDBSUPPORT) {
	setcookie($BUGDBCOOKIENAME, "", $flushtime, "/",
		  $TBAUTHDOMAIN, $TBSECURECOOKIES);
    }
    # These cookie names are still in flux. 
    if ($TRACSUPPORT) {
	setcookie("trac_auth_emulab", "", $flushtime, "/",
		  $TBAUTHDOMAIN, $TBSECURECOOKIES);
	setcookie("trac_auth_emulab_priv", "", $flushtime, "/",
		  $TBAUTHDOMAIN, $TBSECURECOOKIES);
	setcookie("trac_auth_protogeni", "", $flushtime, "/",
		  $TBAUTHDOMAIN, $TBSECURECOOKIES);
	setcookie("trac_auth_protogeni_priv", "", $flushtime, "/",
		  $TBAUTHDOMAIN, $TBSECURECOOKIES);
    }
    # Clear the PHP session cookie, in case someone is using sessions.
    setcookie(session_name(), "", $flushtime, "/",
	      $TBAUTHDOMAIN, $TBSECURECOOKIES);
	
    # Proj-vis cookies
    if ($EXP_VIS) {
	setcookie("exp_vis_session", $opskey, 0, "/", $TBAUTHDOMAIN, 0);
        SUEXEC($uid,"nobody", "write-vis-auth &", SUEXEC_ACTION_CONTINUE);
    }

    return 0;
}

#
# Verify a password
# 
function VERIFYPASSWD($uid, $password) {
    if (! isset($password) || $password == "") {
	return -1;
    }

    if (! ($user = User::Lookup($uid)))
	return -1;

    #
    # Check password in the database against provided. 
    #
    $encoding = crypt("$password", $user->pswd());
	
    if ($encoding == $user->pswd()) {
	return 0;
    }
    return -1;
}

#
# Log out a UID.
#
function DOLOGOUT($user) {
    global $CHECKLOGIN_STATUS, $CHECKLOGIN_USER;
    global $TBAUTHCOOKIE, $TBLOGINCOOKIE, $TBAUTHDOMAIN, $WWWHOST;
    global $WIKISUPPORT, $WIKICOOKIENAME, $TBMAINSITE;
    global $BUGDBSUPPORT, $BUGDBCOOKIENAME, $TRACSUPPORT, $TRACCOOKIENAME;
    global $TBLIBEXEC_DIR, $EXP_VIS;

    if (! $CHECKLOGIN_USER)
	return 1;

    $uid_idx = $user->uid_idx();
    $uid = $user->uid();

    #
    # An admin logging out another user. Nothing else to do.
    #
    if (! $user->SameUser($CHECKLOGIN_USER)) {
	DBQueryFatal("delete from login where uid_idx='$uid_idx'");
	return 0;
    }

    $CHECKLOGIN_STATUS = CHECKLOGIN_NOTLOGGEDIN;

    $curhash  = "";
    $hashhash = "";

    if (isset($_COOKIE[$TBAUTHCOOKIE])) {
	$curhash = $_COOKIE[$TBAUTHCOOKIE];
    }
    if (isset($_COOKIE[$TBLOGINCOOKIE])) {
	$hashhash = $_COOKIE[$TBLOGINCOOKIE];
    }
    
    #
    # We have to get at least one of the hashes. 
    #
    if ($curhash == "" && $hashhash == "") {
	return 1;
    }
    if ($curhash != "" &&
	! preg_match("/^[\w]+$/", $curhash)) {
	return 1;
    }
    if ($hashhash != "" &&
	! preg_match("/^[\w]+$/", $hashhash)) {
	return 1;
    }

    DBQueryFatal("delete from login ".
		 " where uid_idx='$uid_idx' and ".
		 ($curhash != "" ?
		  "hashkey='$curhash'" :
		  "hashhash='$hashhash'"));

    # Delete by giving timeout in the past
    $timeout = time() - 3600;

    #
    # Issue a cookie request to delete the cookies. Delete with timeout in past
    #
    $timeout = time() - 3600;
    
    setcookie($TBAUTHCOOKIE, "", $timeout, "/", $WWWHOST, 0);
    setcookie($TBLOGINCOOKIE, "", $timeout, "/", $WWWHOST, 0);

    if ($TRACSUPPORT) {
	setcookie("trac_auth_emulab", "", $timeout, "/",
		  $TBAUTHDOMAIN, 0);
	setcookie("trac_auth_emulab_priv", "", $timeout, "/",
		  $TBAUTHDOMAIN, 0);
	setcookie("trac_auth_protogeni", "", $timeout, "/",
		  $TBAUTHDOMAIN, 0);
	setcookie("trac_auth_protogeni_priv", "", $timeout, "/",
		  $TBAUTHDOMAIN, 0);
    }
    if ($WIKISUPPORT || $TBMAINSITE) {
	setcookie($WIKICOOKIENAME, "", $timeout, "/", $TBAUTHDOMAIN, 0);
    }
    if ($BUGDBSUPPORT) {
	setcookie($BUGDBCOOKIENAME, "", $timeout, "/", $TBAUTHDOMAIN, 0);
    }

    #
    if ($EXP_VIS) {
	setcookie("exp_vis_session", "", $timeout, "/", $TBAUTHDOMAIN, 0);
        SUEXEC($uid, "nobody", "write-vis-auth &", SUEXEC_ACTION_CONTINUE);
    }

    return 0;
}

#
# Simple "nologins" support.
#
function NOLOGINS() {
    global $CHECKLOGIN_NOLOGINS;

    if ($CHECKLOGIN_NOLOGINS == -1) {
	$CHECKLOGIN_NOLOGINS = TBGetSiteVar("web/nologins");
    }
	
    return $CHECKLOGIN_NOLOGINS;
}

function LASTWEBLOGIN($uid_idx) {
    $query_result =
        DBQueryFatal("select weblogin_last from users as u ".
		     "left join user_stats as s on s.uid_idx=u.uid_idx ".
		     "where u.uid_idx='$uid_idx'");
    
    if (mysql_num_rows($query_result)) {
	$lastrow      = mysql_fetch_array($query_result);
	return $lastrow["weblogin_last"];
    }
    return 0;
}

function HASREALACCOUNT($uid) {
    if (! ($user = User::Lookup($uid)))
	return 0;

    $status   = $user->status();
    $webonly  = $user->webonly();
    $wikionly = $user->wikionly();

    if ($webonly || $wikionly ||
	(strcmp($status, TBDB_USERSTATUS_ACTIVE) &&
	 strcmp($status, TBDB_USERSTATUS_FROZEN))) {
	return 0;
    }
    return 1;
}

#
# Update the time in the database.
# Basically, each time the user does something, we bump the
# logout further into the future. This avoids timing them
# out just when they are doing useful work.
#
function BumpLogoutTime()
{
    global $TBAUTHTIMEOUT, $CHECKLOGIN_HASHKEY, $CHECKLOGIN_IDX;

    if (! is_null($CHECKLOGIN_HASHKEY)) {
	$timeout = time() + (ISADMINISTRATOR() ? 3600 * 24 : $TBAUTHTIMEOUT);

            $TBAUTHTIMEOUT;

	DBQueryFatal("UPDATE login set timeout='$timeout' ".
		     "where uid_idx='$CHECKLOGIN_IDX' and ".
		     "      hashkey='$CHECKLOGIN_HASHKEY'");
    }
    return 0;
}

#
# Reactivate user.
#
function ReactivateUser($user)
{
    $user->SetStatus(TBDB_USERSTATUS_ACTIVE);
    $uid = $user->uid();

    if (SUEXEC($uid, "nobody",
               "webtbacct reactivate $uid", SUEXEC_ACTION_CONTINUE)) {
        $user->SetStatus(TBDB_USERSTATUS_INACTIVE);
        return -1;
    }
    return 0;
}

#
# Beware empty spaces (cookies)!
# 
?>
