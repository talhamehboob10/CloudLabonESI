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
include("node_defs.php");
chdir("apt");
include("quickvm_sup.php");
# Must be after quickvm_sup.php since it changes the auth domain.
$page_title = "Node Console";

#
# Get current user.
#
RedirectSecure();
$this_user = CheckLoginOrRedirect();
$this_idx  = $this_user->uid_idx();
$isadmin   = (ISADMIN() ? "true" : "false");

#
# Verify page arguments.
#
$reqargs = RequiredPageArguments("node",  PAGEARG_NODE);

if (!$node) {
    SPITUSERERROR("No such node!");
}
$node_id = $node->node_id();

if (!($isadmin || $node->AccessCheck($this_user, $TB_NODEACCESS_LOADIMAGE))) {
    SPITUSERERROR("Not enough permission!");
}

SPITHEADER(1);

#
# Get the tipline auto stuff to generate the auth object.
#
$query_result =
    DBQueryFatal("SELECT server, portnum, keylen, keydata, disabled " . 
                 "FROM tiplines WHERE node_id='$node_id'" );

if (mysql_num_rows($query_result) == 0) {
    SPITUSERERROR("Node does not have a console line!");
}
$row = mysql_fetch_array($query_result);
$server  = $row["server"];
$portnum = $row["portnum"];
$keylen  = $row["keylen"];
$keydata = $row["keydata"];
$disabled= $row["disabled"];

if ($disabled) {
    SPITUSERERROR("The tipline is currently disabled!");
}

#
# Read in the fingerprint of the capture certificate
#
$capfile = "$TBETC_DIR/capture.fingerprint";
$lines = file($capfile);
if (!$lines) {
    TBERROR("Unable to open $capfile!", 1);
}

$fingerline = rtrim($lines[0]);
if (!preg_match("/Fingerprint=([\w:]+)$/",$fingerline,$matches)) {
    TBERROR("Unable to find fingerprint in string $fingerline!",1);
}
$certhash = str_replace(":","",strtolower($matches[1]));

#
# Array of stuff that we need to create the auth object
#
$console = array();
$console["server"]   = $server;
$console["portnum"]  = $portnum;
$console["keylen"]   = $keylen;
$console["keydata"]  = $keydata;
$console["certhash"] = $certhash;
$console_auth = $node->ConsoleAuthObject($this_user->uid(), $console);

echo "<center>
       <div id='console-div' ".
     "     style='width: 90%;'></div>";
echo " <button class='btn btn-danger btn-sm hidden'
              style='margin-top: 15px;'
              id='console-close'>
        Close</button>
      </center>
      <center class='stty hidden'>
          If you change the size of the window,
        you will need to use <b><em>stty</em></b> to tell your shell.
      </center>\n";

echo "<script type='text/javascript'>\n";
echo "    window.NODE_ID        = '$node_id';\n";
echo "    window.ISADMIN        = $isadmin;\n";
echo "    window.PROXIED        = $BROWSER_CONSOLE_PROXIED;\n";
echo "</script>\n";

echo "<script type='text/plain' id='auth-json'>\n";
echo $console_auth;
echo "</script>\n";

REQUIRE_UNDERSCORE();
REQUIRE_SUP();
SPITREQUIRE("js/console.js");
SPITFOOTER();

?>
