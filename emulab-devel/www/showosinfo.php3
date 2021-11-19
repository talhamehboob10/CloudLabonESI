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
include("defs.php3");
include_once("osinfo_defs.php");

#
# Only known and logged in users.
#
$this_user = CheckLoginOrDie();
$uid       = $this_user->uid();
$isadmin   = ISADMIN();

#
# Verify page arguments.
#
$reqargs = RequiredPageArguments("osinfo",  PAGEARG_OSINFO);
$optargs = OptionalPageArguments("classic", PAGEARG_BOOLEAN);

#
# Verify permission.
#
if (!$osinfo->AccessCheck($this_user, $TB_OSID_READINFO)) {
    USERERROR("You do not have permission to access this OS Descriptor!", 1);
}
$osid = $osinfo->osid();
$osname = $osinfo->osname();
$version = $osinfo->vers();

if (!$CLASSICWEB_OVERRIDE && $osinfo->ezid() && !$classic) {
    header("Location: apt/show-image.php?imageid=$osid&version=$version");
    return;
}

#
# Standard Testbed Header
#
PAGEHEADER("OSID $osname");

SUBPAGESTART();
SUBMENUSTART("OSID Options");
#
# Delete from the image descriptor when its an EZ image.
#
if ($osinfo->ezid()) {
    $fooid = rawurlencode($osinfo->osid());
    WRITESUBMENUBUTTON("Clone this OS Descriptor",
		       "newimageid_ez.php3?baseimage=$fooid");
    WRITESUBMENUBUTTON("Delete this OS Descriptor",
		       "deleteimageid.php3?imageid=$fooid");
}
else {
    WRITESUBMENUBUTTON("Delete this OS Descriptor",
		       CreateURL("deleteosid", $osinfo));
}
WRITESUBMENUBUTTON("Image Descriptor list",
		   "showimageid_list.php3");
if ($isadmin) {
    WRITESUBMENUBUTTON("OS Descriptor list",
		       "showosid_list.php3");
    WRITESUBMENUBUTTON("Create a new Image Descriptor",
		       "newimageid_ez.php3");
    WRITESUBMENUBUTTON("Create a new OS Descriptor",
		       "newosid.php3");
}

SUBMENUEND();
echo "<br><br>\n";

#
# Dump os_info record.
# 
$osinfo->Show();
$osinfo->ShowExperiments($this_user);
SUBPAGEEND();

#
# Standard Testbed Footer
# 
PAGEFOOTER();
?>
