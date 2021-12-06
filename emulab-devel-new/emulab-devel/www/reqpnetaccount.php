<?php
#
# Copyright (c) 2000-2003 University of Utah and the Flux Group.
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

#
# Standard Testbed Header
#
PAGEHEADER("Request a New PhantomNet Account");

echo "<center><font size=+1>
       If you already have a PhantomNet account,
       <a href=login.php3>
       <font color=red>please log on first!</font></a>
       <br><br>
       <a href=joinproject.php3>Join an Existing Project</a>.
       <br>
       or
       <br>
       <a href=newproject.php3>Start a New Project</a>.
       <br>
       <font size=-1>
       If you are a <font color=red>student (undergrad or graduate)</font>,
       please do not try to start a project!<br> Your advisor must do it.
       </font>
      </font></center><br>\n";

#
# Standard Testbed Footer
# 
PAGEFOOTER();
?>
