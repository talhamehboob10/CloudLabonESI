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
include("defs.php3");

#
# Only known and logged in users can do this.
#
$this_user = CheckLoginOrDie();
$uid       = $this_user->uid();
$uid_idx   = $this_user->uid_idx();
$isadmin   = ISADMIN();

#
# Verify page arguments.
#
$optargs = RequiredPageArguments("uuid",        PAGEARG_UUID);

#
# Standard Testbed Header
#
PAGEHEADER("Edit Dataset");

echo "<iframe src='apt/edit-dataset.php?embedded=1&uuid=$uuid'
              id='embedded' class='embedded'></iframe>";

$bodyclosestring =
    "<script type='text/javascript'>ShowEmbedded('embedded')</script>\n";

#
# Standard Testbed Footer
# 
PAGEFOOTER();
?>
