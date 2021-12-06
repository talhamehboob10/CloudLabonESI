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
chdir("..");
include("defs.php3");
chdir("apt");
include("quickvm_sup.php");
$page_title = "Licenses Pending";

#
# Get current user.
#
RedirectSecure();
$this_user = CheckLoginOrRedirect();

SPITHEADER(1);

echo "<div id='main-body'
           class='col-lg-10 col-lg-offset-1
	          col-md-10 col-md-offset-1
	          col-sm-12 col-sm-offset-0
	          col-xs-12 col-xs-offset-0'>
       <br>
       <p class=lead>
	Your request has been submitted. Please check your email for
	confirmation. You will receive additional email from Portal
	Operations when you can proceed. <b>There is no need to repeat
	this request.</b>
       </p>
     </div>\n";

REQUIRE_UNDERSCORE();
REQUIRE_MARKED();
REQUIRE_SUP();
SPITREQUIRE("js/main.js");

SPITFOOTER();
?>
