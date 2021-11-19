<?php
#
# Copyright (c) 2000-2013 University of Utah and the Flux Group.
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
# This script generates the contents of an image. No headers or footers,
# just spit back an image. 
#

#
# Only known and logged in users.
#
$this_user = CheckLoginOrDie();
$uid       = $this_user->uid();
$isadmin   = ISADMIN();

#
# Verify page arguments.
#
$reqargs = RequiredPageArguments("experiment",   PAGEARG_EXPERIMENT);
$optargs = OptionalPageArguments("zoom",         PAGEARG_NUMERIC,
				 "detail",       PAGEARG_BOOLEAN,
				 "svg",          PAGEARG_BOOLEAN,
				 "thumb",        PAGEARG_INTEGER);

#
# Need these below
#
$pid = $experiment->pid();
$eid = $experiment->eid();
$unix_gid = $experiment->UnixGID();

# if they dont exist, or are non-numeric, use defaults.
if (!isset($zoom))       { $zoom   = 1; }
if (!isset($detail))     { $detail = 0; }
if (!isset($svg))        { $svg    = 0; }
if (!isset($thumb))      { $thumb  = 0; }
if ($zoom > 8.0)   { $zoom = 8.0; }
if ($zoom <= 0.0)  { $zoom = 1.0; }
if ($thumb > 1024) { $thumb = 1024; }

#
# Verify Permission.
#
if (!$experiment->AccessCheck($this_user, $TB_EXPT_READINFO)) {
    USERERROR("You do not have permission to view experiment $eid!", 1);
}

#
# See if any vis data. If not, then the renderer has not finished yet.
#
$query_result =
    DBQueryFatal("select vname from vis_nodes ".
		 "where pid='$pid' and eid='$eid' limit 1");

if (!$query_result || !mysql_num_rows($query_result)) {
    # No Data. Spit back a stub image.
    header("Content-type: image/gif");
    readfile("coming-soon-thumb.gif");
    return;
}

#
# See if we have a copy of the image in the desired zoom/detail level
# cached in the DB. If so, that is what we return.
#
$query_result =
    DBQueryFatal("select image from vis_graphs ".
		 "where pid='$pid' and eid='$eid' and ".
		 "      zoom='$zoom' and detail='$detail'");

if (mysql_num_rows($query_result)) {
    $row   = mysql_fetch_array($query_result);
    $image = $row['image'];
    
    if (strncmp($image, "<svg", 4) == 0) {
	header("Content-type: image/svg+xml");
    }
    else {   
	header("Content-type: image/png");
    }
    echo $image;
    return;
}

#
# Run in the project group.
#
$gid = $pid;
$arguments = "";

# note that we already ensured that $detail and $thumb are numeric above.
if ($detail != 0) { $arguments .= " -d $detail"; }
if ($thumb != 0)  { $arguments .= " -t $thumb";  }
if ($svg != 0 || $TBMAINSITE)    { $arguments .= " -x "; }

#
# Spit out the image with a content header.
#

if ($fp = popen("$TBSUEXEC_PATH $uid $unix_gid webvistopology " .
		"$arguments -z $zoom $pid $eid", "r")) {
    header("Content-type: image/svg+xml");
    fpassthru($fp);
}
else {
    # No Data. Spit back a stub image.
    header("Content-type: image/gif");
    readfile("coming-soon-thumb.gif");
}

#
# No Footer!
# 
?>



