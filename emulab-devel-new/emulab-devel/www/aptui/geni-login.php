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
# Must be after quickvm_sup.php since it changes the auth domain.
include_once("../session.php");
$page_title = "Login";

#
# Get current user but make sure coming in on SSL.
#
RedirectSecure();
$this_user = CheckLogin($check_status);
if ($CHECKLOGIN_STATUS & CHECKLOGIN_LOGGEDIN) {
    SPITUSERERROR("You are already logged in!");
}
$hash = GENHASH();

SPITHEADER(1);

# Place to hang the toplevel template.
echo "<div id='page-body'></div>\n";
echo "<div id='waitwait_div'></div>\n";
echo "<script src='https://www.emulab.net/protogeni/speaks-for/geni-auth.js'>
      </script>\n";
echo "<script src='js/lib/jquery-2.0.3.min.js'></script>\n";

REQUIRE_UNDERSCORE();
REQUIRE_SUP();
SPITREQUIRE("js/geni-login.js");

AddTemplateList(array("geni-login", "waitwait-modal"));
SPITFOOTER();
?>
