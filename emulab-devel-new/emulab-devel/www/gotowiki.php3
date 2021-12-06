<?php
#
# Copyright (c) 2000-2014 University of Utah and the Flux Group.
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

# No Pageheader since we spit out a redirection below.
$this_user = CheckLoginOrDie(CHECKLOGIN_USERSTATUS|
			     CHECKLOGIN_WEBONLY|CHECKLOGIN_WIKIONLY);
$uid       = $this_user->uid();

# No more WIKISUPPORT, but allow Utah admins to access old pages.
if (! ($TBMAINSITE && ISADMIN())) {
    if (!$WIKISUPPORT) {
	header("Location: index.php3");
	return;
    }
}

#
# Verify page arguments. project_title is the project to zap to.
#
$optargs = OptionalPageArguments("redurl", PAGEARG_STRING);

#
# Look for our wikicookie. If the browser has it, then there is nothing
# more to do; just redirect the user over to the wiki.
#
if (isset($_COOKIE[$WIKICOOKIENAME])) {
    $wikihash = $_COOKIE[$WIKICOOKIENAME];
    
    header("Location: ${WIKIURL}?username=${uid}&bosscred=${wikihash}" .
	   (isset($redurl) ? "&redurl=${redurl}" : ""));
    return;
}

#
# Generate a cookie. Send it over to the wiki server and stash it into
# the users browser for subsequent requests (until logout).
# 
$wikihash = GENHASH();

SUEXEC("nobody", "nobody", "wikixlogin $uid $wikihash", SUEXEC_ACTION_DIE);

setcookie($WIKICOOKIENAME, $wikihash, 0, "/", $TBAUTHDOMAIN, $TBSECURECOOKIES);
header("Location: ${WIKIURL}?username=${uid}&bosscred=${wikihash}" .
	   (isset($redurl) ? "&redurl=${redurl}" : ""));
?>
