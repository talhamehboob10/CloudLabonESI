<?php
#
# Copyright (c) 2000-2012 University of Utah and the Flux Group.
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

if (!$TRACSUPPORT) {
    header("Location: index.php3");
    return;
}

# No Pageheader since we spit out a redirection below.
$this_user = CheckLoginOrDie();
$uid       = $this_user->uid();
$isadmin   = ISADMIN();

# The user has to be approved, real account.
if (!HASREALACCOUNT($uid)) {
    USERERROR("You may not login to the Emulab Wiki until your account ".
	      "has been approved and is active.", 1);
}

#
# Verify page arguments. project_title is the project to zap to.
#
$optargs = OptionalPageArguments("wiki",  PAGEARG_STRING,
				 "login", PAGEARG_BOOLEAN,
				 "do",    PAGEARG_STRING);
				 
if (!isset($wiki)) {
    $wiki = "emulab";
}
if (!isset($login)) {
    $login = 0;
}
$priv = 0;

if ($wiki == "protogeni-priv") {
    $wiki = "protogeni";
}
elseif ($wiki == "emulab-priv") {
    $wiki = "emulab";
}

if ($wiki == "geni" || $wiki == "protogeni") {
    $geniproject = Project::Lookup("geni");
    if (!$geniproject) {
	USERERROR("There is no such Trac wiki!", 1);
    }
    $approved    = 0;
    if (! ($isadmin ||
	   ($geniproject->IsMember($this_user, $approved) && $approved))) {
	USERERROR("You do not have permission to access the Trac wiki!", 1);
    }
    $priv       = 1;
    $wiki       = "protogeni";
    $TRACURL    = "https://users.emulab.net/trac/$wiki";
    $COOKIENAME = "trac_auth_protogeni";
}
elseif ($wiki != "emulab") {
    USERERROR("Unknown Trac wiki $wiki!", 1);
}
else {
    $TRACURL    = "https://${USERNODE}/trac/$wiki";
    $COOKIENAME = "trac_auth_${wiki}";
    if (ISADMINISTRATOR() || STUDLY()) {
	$priv = 1;
    }
}

#
# Look for our cookie. If the browser has it, then there is nothing
# more to do; just redirect the user over to the wiki.
#
if (!$login && isset($_COOKIE[$COOKIENAME])) {
    $url = $TRACURL;
    if (isset($do)) {
	$url .= "/" . $do;
    }
    header("Location: $url");
    return;
}

# Login to private part of wiki.
$privopt = ($priv ? "-p" : "");

#
# Do the xlogin, which gives us back a hash to stick in the cookie.
#
SUEXEC($uid, "nobody", "tracxlogin $privopt -w " . escapeshellarg($wiki) .
       " $uid " . $_SERVER['REMOTE_ADDR'], SUEXEC_ACTION_DIE);

if (!preg_match("/^(\w*)$/", $suexec_output, $matches)) {
    TBERROR($suexec_output, 1);
}
$hash = $matches[1];

setcookie($COOKIENAME, $hash, 0, "/", $TBAUTHDOMAIN, $TBSECURECOOKIES);
if ($priv) {
    setcookie($COOKIENAME . "_priv",
	      $hash, 0, "/", $TBAUTHDOMAIN, $TBSECURECOOKIES);
}
header("Location: ${TRACURL}/xlogin?user=$uid&hash=$hash" .
       (isset($do) ? "&goto=${do}" : ""));

