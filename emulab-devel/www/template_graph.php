<?php
#
# Copyright (c) 2006-2011 University of Utah and the Flux Group.
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
# This script generates the contents of an image. No headers or footers,
# just spit back an image. 
#

#
# Capture script errors and report back to user.
#
function SPITERROR($message = "", $death = 1)
{
    header("Content-type: image/gif");
    readfile("coming-soon-thumb.gif");
}
$session_interactive  = 0;
$session_errorhandler = 'SPITERROR';

#
# Verify page arguments.
#
$reqargs = RequiredPageArguments("template", PAGEARG_TEMPLATE);
$optargs = OptionalPageArguments("zoom",     PAGEARG_STRING);

if (isset($zoom)) {
    if ($zoom != "in" && $zoom != "out") {
	PAGEARGERROR("Invalid characters in zoom factor!");
    }
}

function SPITGRAPH($template)
{
    $data = NULL;

    if ($template->GraphImage($data) != 0 || $data == NULL || $data == "") {
	SPITERROR();
    }
    else {
	header("Content-type: image/png");
	echo "$data";
    }
}

#
# If the request did not specify a zoom, return whatever we have.
#
if (!isset($zoom)) {
    SPITGRAPH($template);
    return;
}

#
# Otherwise regen the picture, zooming in or out.
#
$optarg = "-z " . ($zoom == "in" ? "in" : "out");

$pid = $template->pid();
$gid = $template->gid();
$unix_gid = $template->UnixGID();
$project  = $template->GetProject();
$unix_pid = $project->unix_gid();

$retval = SUEXEC($uid, "$unix_pid,$unix_gid", "webtemplate_graph $optarg $guid",
		 SUEXEC_ACTION_CONTINUE);

if ($retval) {
    SPITERROR();
}
else {
    SPITGRAPH($template);
}

#
# No Footer!
# 
?>
