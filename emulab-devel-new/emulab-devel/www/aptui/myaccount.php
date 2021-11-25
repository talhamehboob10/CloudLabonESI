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
chdir("apt");
include("quickvm_sup.php");
$page_title = "My Account";

#
# Get current user.
#
RedirectSecure();
$this_user = CheckLogin($check_status);
if (isset($this_user)) {
    # Allow unapproved users to edit their profile ...
    CheckLoginOrDie(CHECKLOGIN_UNAPPROVED|CHECKLOGIN_NONLOCAL);
}
else {
    CheckLoginOrRedirect();
}

#
# Verify page arguments.
#
$optargs = OptionalPageArguments("target_user", PAGEARG_USER,
                                 "referrer",    PAGEARG_URL,
                                 "needupdate",  PAGEARG_BOOLEAN);

if (! isset($target_user)) {
    $target_user = $this_user;
}
$uid = $target_user->uid();

if ($target_user->uid() != $this_user->uid() && !ISADMIN()) {
    sleep(2);
    SPITUSERERROR("Not enough permission");
    return;
}
$isadmin = (ISADMIN() ? 1 : 0);
if (!isset($needupdate)) {
    $needupdate = 0;
}

# We use a session. in case we need to do verification
session_start();
session_unset();

$defaults = array();

# Default to start
$defaults["uid"]         = $target_user->uid();
$defaults["name"]        = $target_user->name();
$defaults["email"]       = $target_user->email();
$defaults["city"]        = $target_user->city();
$defaults["state"]       = $target_user->state();
$defaults["country"]     = $target_user->country();
$defaults["affiliation"] = $target_user->affil();
$defaults["address1"]    = $target_user->addr1();
$defaults["address2"]    = $target_user->addr2();
$defaults["zip"]         = $target_user->zip();
$defaults["phone"]       = $target_user->phone();
$defaults["shell"]       = $target_user->shell();


SPITHEADER(1);
echo "<script>\n";
echo "</script>\n";
echo "<link rel='stylesheet' href='css/bootstrap-formhelpers.min.css'>\n";
echo "<link rel='stylesheet' href='css/jquery-ui.min.css'>\n";
echo "<div id='page-body'></div>\n";
echo "<div id='oops_div'></div>\n";
echo "<div id='waitwait_div'></div>\n";
echo "<script type='text/plain' id='form-json'>\n";
echo htmlentities(json_encode($defaults)) . "\n";
echo "</script>\n";

echo "<script type='text/javascript'>\n";
if ($referrer) {
    #$referrer = CleanString($referrer);
    echo "    window.REFERRER = '$referrer';\n";
}
echo "    window.NEEDUPDATE  = $needupdate;\n";
echo "    window.ISADMIN     = $isadmin;\n";
if ($target_user->RequireAddress()) {
    echo "    window.UPDATE  = 'required';\n";
}
elseif ($target_user->RequireAffiliation()) {
    $matched = $target_user->affiliation_matched();
    echo "    window.UPDATE  = 'affiliation';\n";
    echo "    window.MATCHED = $matched;\n";
}
else {
    echo "    window.UPDATE  = null;\n";
}
echo "</script>\n";

REQUIRE_UNDERSCORE();
REQUIRE_SUP();
REQUIRE_APTFORMS();
REQUIRE_FORMHELPERS();
SPITREQUIRE("js/myaccount.js",
            "<script src='js/lib/jquery-ui.js'></script>");

AddTemplateList(array("myaccount", "verify-modal", "oops-modal", "waitwait-modal"));
SPITFOOTER();

?>
