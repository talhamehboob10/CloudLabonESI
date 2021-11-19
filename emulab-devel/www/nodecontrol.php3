<?php
#
# Copyright (c) 2000-2012 University of Utah and the Flux Group.
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
include_once("node_defs.php");

#
# Only known and logged in users can do this.
#
$this_user = CheckLoginOrDie();
$uid       = $this_user->uid();
$isadmin   = ISADMIN();

#
# Verify page arguments.
#
$reqargs = RequiredPageArguments("node",	      PAGEARG_NODE,
				 "def_boot_osid",     PAGEARG_STRING,
				 "def_boot_cmd_line", PAGEARG_STRING,
				 "startupcmd",        PAGEARG_ANYTHING,
				 "tarballs",          PAGEARG_STRING,
				 "rpms",              PAGEARG_STRING);
$optargs = OptionalPageArguments("next_boot_osid",     PAGEARG_STRING,
				 "next_boot_cmd_line", PAGEARG_STRING,
				 "temp_boot_osid",     PAGEARG_STRING);

# Need these below.
$node_id = $node->node_id();

#
# Admin users can control any node, but normal users can only control
# nodes in their own experiments.
#
if (!$isadmin &&
    !$node->AccessCheck($this_user, $TB_NODEACCESS_MODIFYINFO)) {
    USERERROR("You do not have permission to modify node parameters!", 1);
}

#
# Standard Testbed Header
#
PAGEHEADER("Node Control Form");

#
# Check each parameter. Also note that when setting/clearing values,
# send the argument to the backend script *only when changed*
#
$command_string = "";

if ($def_boot_osid != $node->def_boot_osid()) {
    $command_string .=
	"default_boot_osid=" . escapeshellarg($def_boot_osid) . " ";
}
if ($def_boot_cmd_line != $node->def_boot_cmd_line()) {
    $command_string .=
	"default_boot_cmdline=" . escapeshellarg($def_boot_cmd_line) . " ";
}
if ($startupcmd != $node->startupcmd()) {
    $command_string .= "startup_command=" . escapeshellarg($startupcmd) . " ";
}
if ($tarballs != $node->tarballs()) {
    $command_string .= "tarfiles=" . escapeshellarg($tarballs) . " ";
}
if ($rpms != $node->rpms()) {
    $command_string .= "rpms=" . escapeshellarg($rpms) . " ";
}

if ($isadmin) {
    if (isset($next_boot_osid) &&
	$next_boot_osid != $node->next_boot_osid()) {
	$command_string .=
	    "next_boot_osid=" . escapeshellarg($next_boot_osid) . " ";
    }
    if (isset($next_boot_cmd_line) &&
	$next_boot_cmd_line != $node->next_boot_cmd_line()) {
	$command_string .=
	    "next_boot_cmdline=" . escapeshellarg($next_boot_cmd_line) . " ";
    }
    if (isset($temp_boot_osid) &&
	$temp_boot_osid != $node->temp_boot_osid()) {
	$command_string .=
	    "temp_boot_osid=" . escapeshellarg($temp_boot_osid) . " ";
    }
}

STARTBUSY("Making changes to $node_id");
SUEXEC($uid, "nobody", "webnode_control $command_string $node_id",
       SUEXEC_ACTION_DIE);
STOPBUSY();

PAGEREPLACE(CreateURL("shownode", $node));

#
# Standard Testbed Footer
# 
PAGEFOOTER();
?>
