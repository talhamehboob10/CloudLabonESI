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
include_once("node_defs.php");

#
# Only known and logged in users can watch LEDs
#
$this_user = CheckLoginOrDie();
$uid       = $this_user->uid();
$isadmin   = ISADMIN();

# Verify page arguments.
$reqargs = RequiredPageArguments("node", PAGEARG_STRING);

if (!TBvalid_node_id($node)) {
    USERERROR("Invalid node ID.", 1);
}

if (! ($target_node = Node::Lookup($node))) {
    USERERROR("Invalid node ID.", 1);
}

if (!$target_node->AccessCheck($this_user, $TB_NODEACCESS_READINFO)) {
    USERERROR("Not enough permission.", 1);
}

header("Content-Type: text/plain");
header("Expires: Mon, 26 Jul 1997 05:00:00 GMT");
header("Cache-Control: no-cache, must-revalidate");
header("Pragma: no-cache");
flush();

#for ($lpc = 0; $lpc < 30; $lpc++) {
    #	sleep(1);
    #	$on_off = $lpc % 2;
    #	echo "$on_off";
    #	flush();
    #}

#
# Silly, I can't get php to get the buffering behavior I want with a socket, so
# we'll open a pipe to a perl process
#
$socket = fsockopen("$node", 1812);
if (!$socket) {
    USERERROR("Error opening $node - $errstr",1);
}

#
# Clean up when the remote user disconnects
#
function SPEWCLEANUP()
{
    global $socket;

    if (!$socket || !connection_aborted()) {
	exit();
    }
    fclose($socket);
    exit();
}
# ignore_user_abort(1);
register_shutdown_function("SPEWCLEANUP");

#
# Just loop forver reading from the socket
#
do {
    # Bad rob! No biscuit!
    $onoff = fread($socket,6);
    echo "$onoff";
    flush();
} while ($onoff != "");
fclose($socket);

?>
