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
include("imageid_defs.php");

#
# Only known and logged in users.
#
$this_user = CheckLoginOrDie();
$uid       = $this_user->uid();
$isadmin   = ISADMIN();
$showperms = 1;

# This will not return if its a sajax request.
include("showlogfile_sup.php3");

#
# Verify page arguments.
#
$reqargs = RequiredPageArguments("image",   PAGEARG_IMAGE);
$optargs = OptionalPageArguments("showlog", PAGEARG_BOOLEAN,
                                 "classic", PAGEARG_BOOLEAN);

# Need these below.
$imageid = $image->imageid();
$version = $image->version();

#
# Verify permission.
#
if (!$image->AccessCheck($this_user, $TB_IMAGEID_READINFO)) {
    PAGEHEADER("Image Descriptor");
    USERERROR("You do not have permission to access ImageID $imageid.", 1);
}

if (!$CLASSICWEB_OVERRIDE && $image->ezid() && !$classic) {
    header("Location: apt/show-image.php?imageid=$imageid&version=$version");
    return;
}

#
# Standard Testbed Header
#
PAGEHEADER("Image Descriptor");

if (isset($showlog)) {
    $logfile = $image->GetLogfile();
    if ($logfile) {
	echo $image->PageHeader();
	STARTLOG($logfile);
	PAGEFOOTER();
	return;
    }
}

SUBPAGESTART();
SUBMENUSTART("More Options");

WRITESUBMENUBUTTON("Edit this Image Descriptor",
		   "editimageid.php3?imageid=$imageid&version=$version");
if ($image->GetLogfile()) {
    WRITESUBMENUBUTTON("View Log File",
	       "showimageid.php3?imageid=$imageid&version=$version&showlog=1");
}
if ($image->AccessCheck($this_user, $TB_IMAGEID_MODIFYINFO )) {
    WRITESUBMENUBUTTON("Snapshot Node Disk into Image",
		       "loadimage.php3?imageid=$imageid");
}
WRITESUBMENUBUTTON("Clone this Image Descriptor",
		   "newimageid_ez.php3?baseimage=$imageid");
WRITESUBMENUBUTTON("Delete this Image Descriptor",
		   "deleteimageid.php3?imageid=$imageid");
WRITESUBMENUBUTTON("Image Descriptor list",
		   "showimageid_list.php3");
if ($isadmin) {
    WRITESUBMENUBUTTON("Create a New Image Descriptor",
		       "newimageid_ez.php3");
    WRITESUBMENUBUTTON("Create a new OS Descriptor",
		       "newosid.php3");
    WRITESUBMENUBUTTON("OS Descriptor list",
		       "showosid_list.php3");
}
SUBMENUEND();

#
# Dump record.
# 
$image->Show($showperms);

echo "<br>\n";

#
# Show experiments using this image - we have to handle all four partitions.
# Also we do not put OSIDs directly into the virt_nodes table, so we have to
# get the pid and osname for the image, and use that to look into the 
# virt_nodes table.
#
function SHOWIT($osid, $vers) {
    global $this_user;
    
    if (! ($osinfo = OSinfo::Lookup($osid, $vers))) {
	TBERROR("Could not map osid to its object: $osid", 1);
    }
    echo "<h3 align='center'>Experiments using OS ";
    $osinfo->SpitLink();
    echo "</h3>\n";

    $osinfo->ShowExperiments($this_user);
}

if ($image->part1_osid()) {
    SHOWIT($image->part1_osid(), $image->part1_vers());
}
if ($image->part2_osid()) {
    SHOWIT($image->part2_osid(), $image->part2_vers());
}
if ($image->part3_osid()) {
    SHOWIT($image->part3_osid(), $image->part3_vers());
}
if ($image->part4_osid()) {
    SHOWIT($image->part4_osid(), $image->part4_vers());
}
SUBPAGEEND();

#
# Standard Testbed Footer
# 
PAGEFOOTER();
?>
