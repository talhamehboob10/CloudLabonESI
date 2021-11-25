<?php
#
# Copyright (c) 2000-2014, 2019 University of Utah and the Flux Group.
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
include_once("imageid_defs.php");
include_once("node_defs.php");

#
# Only known and logged in users.
#
$this_user = CheckLoginOrDie();
$uid       = $this_user->uid();
$isadmin   = ISADMIN();

# This will not return if its a sajax request.
include("showlogfile_sup.php3");

#
# Verify page arguments.
#
$reqargs = RequiredPageArguments("image",     PAGEARG_IMAGE);
$optargs = OptionalPageArguments("target",    PAGEARG_STRING,
				 "canceled",  PAGEARG_STRING,
				 "confirmed", PAGEARG_STRING,
                                 "classic",   PAGEARG_BOOLEAN);

# Need these below.
$imageid    = $image->imageid();
$version    = $image->version();
$image_pid  = $image->pid();
$image_gid  = $image->gid();
$image_name = $image->imagename();
$image_path = $image->path();

if (!$CLASSICWEB_OVERRIDE && !$classic) {
    $url = "apt/snapshot-image.php?imageid=$imageid&version=$version";
    if (isset($target)) {
        $url .= "&node=$target";
    }
    header("Location: $url");
    return;
}

#
# Standard Testbed Header
#
PAGEHEADER("Snapshot Node Disk into New or Existing Image");


if (!$image->AccessCheck($this_user, $TB_IMAGEID_MODIFYINFO )) {
    USERERROR("You do not have permission to modify image '$imageid'.", 1);
}

if (! isset($target) || isset($canceled)) {
    echo "<center>";

    if (isset($canceled)) {
	echo "<h3>Operation canceled.</h3>";
    }
    else {
	$target = "";
    }
    echo "<br />";

    $url = CreateURL("loadimage", $image);
    $url .= "&classic=1";

    echo "<form action='$url' method='post'>\n".
	 "<font size=+1>Node to snapshot into image '$image_name':</font> ".
	 "<input type='text'   name='target' value='$target' size=32></input>\n".
	 "<input type='submit' name='submit'  value='Go!'></input>\n".
	 "</form><br>";
    echo "<font size=+1>Information for Image Descriptor '$image_name':</font>\n";
    
    $image->Show();

    echo "</center>";
    PAGEFOOTER();
    return;
}

#
# A node to pass through?
#
if (preg_match("/^[-\w]+$/", "$target")) {
    $node = Node::Lookup($target);
    if (!$node) {
	USERERROR("No such node $node_id!", 1);

    }
    if (!$node->AccessCheck($this_user, $TB_NODEACCESS_LOADIMAGE)) {
	USERERROR("You do not have permission to ".
		  "snapshot an image from node '$node_id'.", 1);
    }
    $experiment = $node->Reservation();
    if (!$experiment) {
	USERERROR("$node_id is not currently reserved to an experiment!", 1);
    }
    $node_pid = $experiment->pid();
    $unix_gid = $experiment->UnixGID();
    $project  = $experiment->Project();
    $unix_groups = $project->unix_gid() . "," . $unix_gid;
    if ($project->pid() != $node_pid) {
	$unix_groups = "$unix_groups,$node_pid";
    }
}
elseif (preg_match("/^[-\w\@\.\+]+$/", "$target")) {
    $unix_groups = "$image_pid,$image_gid";
}
else {
    USERERROR("Illegal characters in '$target'.", 1);
}

# Should check for file file_exists($image_path),
# but too messy.

if (! isset($confirmed)) {
    $url = CreateURL("loadimage", $image);
    $url .= "&classic=1";
    $newurl = CreateURL("newimageid_ez", "node_id", $target);
    
    echo "<br><center><form action='$url' method='post'>\n".
	 "<b>Doing a snapshot of '$target' into image '$image_name' ".
	 "will overwrite any previous snapshot for that image.<br><br> ".
	 "Are you sure you want to continue?</b><br>".
         "<input type='hidden' name='target'    value='$target'></input>".
         "<input type='submit' name='confirmed' value='Confirm'></input>".
         "&nbsp;".
         "<input type='submit' name='canceled' value='Cancel'></input>\n".    
         "</form>".
         "<br>".
	 "If you do not want to overwrite this image, then ".
	 "<a href='$newurl'>create a new image</a> based on the image ".
	 "that is currently loaded on $target. ".
	 "</center>";

    PAGEFOOTER();
    return;
}

echo "<br>
      Taking a snapshot of '$target' into image '$image_name' ...
      <br><br>\n";
flush();

SUEXEC($uid,
       $unix_groups,
       "webclone_image $image_name " . escapeshellarg($target),
       SUEXEC_ACTION_DUPDIE);

echo "This will take as little as 10 minutes or as much as an hour;
      you will receive email
      notification when the image is complete. In the meantime,
      <b>PLEASE DO NOT</b> delete the imageid or mess with
      the node at all!<br>\n";

flush();

#
# When doing image provenance the most recent unreleased version is
# is what we are really working on. 
#
$image = $image->LookupUnreleased();
$logfile = $image->GetLogfile();
if ($logfile) {
    STARTLOG($logfile);
}

#
# Standard Testbed Footer
# 
PAGEFOOTER();
?>
