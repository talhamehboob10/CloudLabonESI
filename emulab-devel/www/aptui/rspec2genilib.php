<?php
#
# Copyright (c) 2000-2016 University of Utah and the Flux Group.
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
$page_title = "Convert RSpec to GeniLib";

RedirectSecure();
$this_user = CheckLoginOrRedirect();

SPITHEADER(1);
# Place to hang the toplevel template.
echo "<div id='main-body'></div>\n";

REQUIRE_UNDERSCORE();
REQUIRE_SUP();
REQUIRE_FILESTYLE();
SPITREQUIRE("js/rspec2genilib.js");

AddTemplateList(array("rspec2genilib", "waitwait-modal", "oops-modal"));
SPITFOOTER();
?>
