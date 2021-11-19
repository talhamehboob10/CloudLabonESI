<?php
#
# Copyright (c) 2014 University of Utah and the Flux Group.
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
require("defs.php3");

$optargs = OptionalPageArguments("stayhome", PAGEARG_BOOLEAN);

#
# The point of this is to redirect logged in users to their My Emulab
# page. 
#
CheckRedirect();

PAGEHEADER("PhantomNet - Mobility Testbed", NULL, $RSS_HEADER_PNNEWS);

#
# Show special banner message, if set.
#
$message = TBGetSiteVar("web/banner");
if ($message != "") {
    echo "<center><font color=Red size=+1>\n";
    echo "$message\n";
    echo "</font></center><br>\n";
}

#
# PhantomNet front page content.
#
readfile("index-phantomnet.html");

#
# Standard Testbed Footer
# 
PAGEFOOTER();
?>
