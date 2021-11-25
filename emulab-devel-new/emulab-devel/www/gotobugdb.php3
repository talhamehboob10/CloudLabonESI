<?php
#
# Copyright (c) 2000-2007 University of Utah and the Flux Group.
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

if (!$BUGDBSUPPORT) {
    header("Location: index.php3");
    return;
}

# No Pageheader since we spit out a redirection below.
$this_user = CheckLoginOrDie(CHECKLOGIN_USERSTATUS|
		     CHECKLOGIN_WEBONLY|CHECKLOGIN_WIKIONLY); # XXX BUGDBONLY ?
$uid       = $this_user->uid();
$isadmin   = ISADMIN();

#
# Verify page arguments. project_title is the project to zap to.
#
$optargs = OptionalPageArguments("project_title", PAGEARG_STRING,
				 "do",            PAGEARG_STRING);

#
# Look for our cookie. If the browser has it, then there is nothing
# more to do; just redirect the user over to the bugdb.
#
if (isset($_COOKIE[$BUGDBCOOKIENAME])) {
    $myhash = $_COOKIE[$BUGDBCOOKIENAME];
    
    header("Location: ${BUGDBURL}?username=${uid}&bosscred=${myhash}" .
	   (isset($do) ? "&do=${do}" : "") .
	   (isset($project_title) ? "&project_title=${project_title}" : ""));
    return;
}

#
# Generate a cookie. Send it over to the bugdb server and stash it into
# the users browser for subsequent requests (until logout).
# 
$myhash = GENHASH();

SUEXEC("nobody", "nobody", "bugdbxlogin $uid $myhash", SUEXEC_ACTION_DIE);

$pp_args = "${BUGDBURL}?";
$pp_args .= (isset($do) ? "&do=${do}" : "");
$pp_args .= (isset($project_title) ? "&project_title=${project_title}" : "");

$pp_args = rawurlencode($pp_args);

setcookie($BUGDBCOOKIENAME, $myhash, 0, "/", $TBAUTHDOMAIN, $TBSECURECOOKIES);
header("Location: ${BUGDBURL}?do=authenticate&username=${uid}&bosscred=${myhash}&prev_page=" . $pp_args);
?>
