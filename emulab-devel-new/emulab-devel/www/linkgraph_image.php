<?php
#
# Copyright (c) 2006, 2007 University of Utah and the Flux Group.
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
include_once("template_defs.php");

#
# Only known and logged in users ...
#
$this_user = CheckLoginOrDie();
$uid       = $this_user->uid();
$isadmin   = ISADMIN();

#
# Verify page arguments.
#
$reqargs  = RequiredPageArguments("instance",  PAGEARG_INSTANCE);
$optargs  = OptionalPageArguments("runidx",    PAGEARG_INTEGER,
				  "srcvnode",  PAGEARG_STRING,
				  "dstvnode",  PAGEARG_STRING,
				  "graphtype", PAGEARG_STRING);
$template = $instance->template();

# Optional runidx for graphing just a specific run.
$runarg = "";
$vnodes = "";

if (isset($runidx) && $runidx != "") {
    if (!TBvalid_integer($runidx)) {
	PAGEARGERROR("Invalid characters in run index!");
    }
    else {
	$runarg = "-r $runidx";
    }
}

# Optional src and dst arguments.
if (isset($srcvnode) && $srcvnode != "") {
    if (! preg_match("/^[-\w\/]*$/", $srcvnode)) {
	PAGEARGERROR("Invalid characters in src vnode!");
    }
    else {
	$vnodes .= " -s " . escapeshellarg($srcvnode);
    }
}
if (isset($dstvnode) && $dstvnode != "") {
    if (! preg_match("/^[-\w\/]*$/", $dstvnode)) {
	PAGEARGERROR("Invalid characters in dst vnode!");
    }
    else {
	$vnodes .= " -t " . escapeshellarg($dstvnode);
    }
}

#
# Spit out the image with a content header.
#
$eid    = $instance->eid();
$pid    = $instance->pid();
$guid   = $instance->guid();
$vers   = $instance->vers();
$exptidx= $instance->exptidx();
$unix_gid = $template->UnixGID();
$which  = "pps";

#
# Default to pps if no graphtype.
#
if (isset($graphtype) && $graphtype != "") {
    if (! preg_match('/^[\w]*$/', $graphtype)) {
	PAGEARGERROR("Invalid characters in graphtype!");
    }
    $which = escapeshellarg($graphtype);
}

if ($fp = popen("$TBSUEXEC_PATH $uid $unix_gid webtemplate_linkgraph " .
		"-i $exptidx $runarg $vnodes $guid/$vers $which", "r")) {
    header("Content-type: image/gif");
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
