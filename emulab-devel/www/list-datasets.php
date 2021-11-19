<?php
#
# Copyright (c) 2000-2017 University of Utah and the Flux Group.
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
$optargs = OptionalPageArguments("target_user",   PAGEARG_STRING,
				 "all",           PAGEARG_BOOLEAN);

$url = 'apt/list-datasets.php?embedded=1';
if (isset($target_user)) {
    $url .= "&user=$target_user";
}
if (isset($all)) {
    $url .= "&all=$all";
}

#
# Standard Testbed Header
#
PAGEHEADER("List Datasets");

echo "<iframe src='$url' id='embedded' class='embedded'></iframe>";

$bodyclosestring =
    "<script type='text/javascript'>ShowEmbedded('embedded')</script>\n";

#
# Standard Testbed Footer
# 
PAGEFOOTER();
?>
