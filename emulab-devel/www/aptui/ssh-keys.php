<?php
#
# Copyright (c) 2000-2015 University of Utah and the Flux Group.
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
$page_title = "My SSH Keys";

#
# Get current user.
#
RedirectSecure();
$this_user = CheckLoginOrRedirect();
$this_idx  = $this_user->idx();

$optargs = OptionalPageArguments("target_user",   PAGEARG_USER);

SPITHEADER(1);

# Default to current user.
if (!isset($target_user)) {
    $target_user = $this_user;
}
$target_uid = $target_user->uid();
$target_idx = $target_user->idx();
$nonlocal   = ($target_user->IsNonLocal() ? "true" : "false");

if (! ($target_user->SameUser($this_user) ||
       $target_user->AccessCheck($this_user, $TB_USERINFO_READINFO))) {
    USERERROR("You do not have permission to view ${target_uid}' keys!", 1);
}

$query_result =
    DBQueryFatal("select idx,comment,pubkey from user_pubkeys ".
                 "where uid_idx='$target_idx' and internal=0");

$pubkeys = array();
while ($row = mysql_fetch_array($query_result)) {
    $pubkeys[] = array("index"   => $row["idx"],
                       "pubkey"  => $row["pubkey"],
                       "comment" => $row["comment"]);
}
echo "<script type='text/plain' id='sshkey-list'>\n";
echo htmlentities(json_encode($pubkeys));
echo "</script>\n";

# Place to hang the toplevel template.
echo "<div id='page-body'></div>\n";

echo "<script type='text/javascript'>\n";
echo "    window.AJAXURL     = 'server-ajax.php';\n";
echo "    window.TARGET_UID  = '$target_uid';\n";
echo "    window.NONLOCAL    = $nonlocal;\n";
echo "</script>\n";
echo "<script src='js/lib/jquery-2.0.3.min.js'></script>\n";

REQUIRE_UNDERSCORE();
REQUIRE_SUP();
REQUIRE_FILESTYLE();
SPITREQUIRE("js/ssh-keys.js");

AddTemplateList(array("ssh-keys", "oops-modal", "waitwait-modal"));
SPITFOOTER();
?>
