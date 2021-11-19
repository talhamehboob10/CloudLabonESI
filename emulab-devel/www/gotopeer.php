<?php
#
# Copyright (c) 2000-2019 University of Utah and the Flux Group.
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
$this_user = CheckLoginOrDie();
$uid       = $this_user->uid();
$isadmin   = ISADMIN();

PAGEHEADER("Portal Login");

if (! ($PEER_ENABLE && $PEER_ISPRIMARY)) {
    USERERROR("Not a Peer Portal", 1);
}

#
# Verify page arguments. project_title is the project to zap to.
#
$reqargs = RequiredPageArguments("peer",  PAGEARG_STRING);
$optargs = OptionalPageArguments("user",  PAGEARG_USER);

$safe_peer = addslashes($peer);
$query_result =
    DBQueryFatal("select * from emulab_peers ".
		 "where name='$safe_peer' or urn='$safe_peer'");
if (!mysql_num_rows($query_result)) {
    USERERROR("Unknown peer: $peer", 1);
}
$row = mysql_fetch_array($query_result);
$urn = $row['urn'];
$url = $row['weburl'];

#
# Allow admin to xlogin as another user.
#
if (isset($user) && !$this_user->SameUser($user)) {
    if ($isadmin) {
	$uid = $user->uid();
    }
    else {
	USERERROR("Not allowed to login as another user", 1);
    }
}

STARTBUSY("Contacting peer");
#
# Do the xlogin, which gives us back a hash to stick in the redirect URL.
#
SUEXEC($uid, "nobody",
       "webmanageremote xlogin " . escapeshellarg($urn) . " $uid",
       SUEXEC_ACTION_DIE);
STOPBUSY();

if (!preg_match("/^(\w*)$/", $suexec_output, $matches)) {
    TBERROR($suexec_output, 1);
}
$hash = $matches[1];
PAGEREPLACE("$url/peer_login.php?user=$uid&key=$hash");
