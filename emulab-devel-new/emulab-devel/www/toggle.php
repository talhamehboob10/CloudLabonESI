<?php
#
# Copyright (c) 2000-2018 University of Utah and the Flux Group.
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
include_once("defs.php3");

#
# This page is a generic toggle page, like adminmode.php3, but more
# generalized. There are a set of things you can toggle, and each of
# those items has a permission check and a set (pair) of valid values.
#
# Usage: toggle.php?type=swappable&value=1&pid=foo&eid=bar
# (type & value are required, others are optional and vary by type)
#
# No PAGEHEADER since we spit out a Location header later. See below.
#
# Only known and logged in users can do this.
#
$this_user = CheckLoginOrDie(CHECKLOGIN_USERSTATUS|CHECKLOGIN_WEBONLY);
$uid       = $this_user->uid();
$isadmin   = ISADMIN();

# List of valid toggles
$toggles = array("adminon", "webfreeze", "cvsweb", "lockdown", "stud",
		 "cvsrepo_public", "workbench", "hiderun", "widearearoot",
		 "imageglobal", "skipvlans", "adminflag", "imagedoesxen");

# list of valid values for each toggle
$values  = array("adminon"        => array(0,1),
		 "webfreeze"      => array(0,1),
		 "cvsweb"         => array(0,1),
		 "stud"           => array(0,1),
		 "lockdown"       => array(0,1),
		 "skipvlans"      => array(0,1),
		 "cvsrepo_public" => array(0,1),
		 "workbench"      => array(0,1),
		 "widearearoot"   => array(0,1),
		 "imageglobal"    => array(0,1),
		 "imagedoesxen"   => array(0,1),
		 "adminflag"      => array(0,1),
		 "hiderun"        => array(0,1),
		 "project_disable"=> array(0,1));

# list of valid extra variables for the each toggle, and mandatory flag.
$optargs = array("adminon"        => array(),
		 "webfreeze"      => array("user" => 1),
		 "cvsweb"         => array("user" => 1),
		 "stud"           => array("user" => 1),
		 "lockdown"       => array("pid" => 1, "eid" => 1),
		 "skipvlans"      => array("pid" => 1, "eid" => 1),
		 "cvsrepo_public" => array("pid" => 1),
		 "workbench"      => array("pid" => 1),
		 "widearearoot"   => array("user" => 1),
		 "imageglobal"    => array("imageid" => 1),
		 "imagedoesxen"   => array("imageid" => 1),
		 "adminflag"      => array("user" => 1),
		 "hiderun"        => array("instance" => 1, "runidx" => 1),
                 "project_disable"=> array("pid" => 1));


# Mandatory page arguments.
$reqargs = RequiredPageArguments("type",  PAGEARG_STRING,
				 "value", PAGEARG_STRING);

# Where we zap to.
$zapurl = null;

if (! in_array($type, $toggles)) {
    PAGEARGERROR("There is no toggle for $type!");
}
if (! in_array($value, $values[$type])) {
    PAGEARGERROR("The value '$value' is illegal for the $type toggle!");
}

# Check optional args and bind locally.
while (list ($arg, $required) = each ($optargs[$type])) {
    if (!isset($_GET[$arg])) {
	if ($required)
	    PAGEARGERROR("Toggle '$type' requires argument '$arg'");
	else
	    unset($$arg);
    }
    else {
	$$arg = addslashes($_GET[$arg]);
    }
}

#
# Permissions checks, and do the toggle...
#
if ($type == "adminon") {
    # must be admin
    # Do not check if they are admin mode (ISADMIN), check if they
    # have the power to change to admin mode!
    if (! ($CHECKLOGIN_STATUS & CHECKLOGIN_ISADMIN) ) {
	USERERROR("You do not have permission to toggle $type!", 1);
    }
    SETADMINMODE($value);
}
elseif ($type == "webfreeze") {
    # must be admin
    if (! $isadmin) {
	USERERROR("You do not have permission to toggle $type!", 1);
    }
    if (! ($target_user = User::Lookup($user))) {
	PAGEARGERROR("Target user '$user' is not a valid user!");
    }
    $zapurl = CreateURL("showuser", $target_user);
    $target_user->SetWebFreeze($value);
}
elseif ($type == "adminflag") {
    # must be admin
    if (! $isadmin) {
	USERERROR("You do not have permission to toggle $type!", 1);
    }
    if (! ($target_user = User::Lookup($user))) {
	PAGEARGERROR("Target user '$user' is not a valid user!");
    }
    if ($value && $target_user->status() != TBDB_USERSTATUS_ACTIVE) {
	PAGEARGERROR("Target user '$user' has not been activated yet!");
    }
    $zapurl = CreateURL("showuser", $target_user);
    $target_user->SetAdminFlag($value);
    $target_uid = $target_user->uid();
    $this_uid   = $this_user->uid();
    if ($value) {
	TBMAIL($TBMAIL_OPS,
	       "Admin Flag enabled for '$target_uid'",
	       "$this_uid has enabled the admin flag for '$target_uid'!\n\n",
	       "From: $TBMAIL_OPS\n".
	       "Bcc: $TBMAIL_AUDIT\n".
	       "Errors-To: $TBMAIL_WWW");
    }
    SUEXEC($uid, $TBADMINGROUP,
	   "webtbacct mod $target_uid", SUEXEC_ACTION_DIE);
    SUEXEC($uid, $TBADMINGROUP,
	   "webmodgroups $target_uid", SUEXEC_ACTION_DIE);
}
elseif ($type == "cvsweb") {
    # must be admin
    if (! $isadmin) {
	USERERROR("You do not have permission to toggle $type!", 1);
    }
    if (! ($target_user = User::Lookup($user))) {
	PAGEARGERROR("Target user '$user' is not a valid user!");
    }
    $zapurl = CreateURL("showuser", $target_user);
    $target_user->SetWebFreeze($value);
}
elseif ($type == "stud") {
    # must be admin
    if (! $isadmin) {
	USERERROR("You do not have permission to toggle $type!", 1);
    }
    if (! ($target_user = User::Lookup($user))) {
	PAGEARGERROR("Target user '$user' is not a valid user!");
    }
    $zapurl = CreateURL("showuser", $target_user);
    $target_user->SetStudly($value);
}
elseif ($type == "widearearoot") {
    # must be admin
    if (! $isadmin) {
	USERERROR("You do not have permission to toggle $type!", 1);
    }
    if (! ($target_user = User::Lookup($user))) {
	PAGEARGERROR("Target user '$user' is not a valid user!");
    }
    $zapurl = CreateURL("showuser", $target_user);
    $target_user->SetWideAreaRoot($value);
}
elseif ($type == "skipvlans") {
    # Must validate the pid,eid since we allow non-admins to do this.
    if (! TBvalid_pid($pid)) {
	PAGEARGERROR("Invalid characters in $pid");
    }
    if (! TBvalid_eid($eid)) {
	PAGEARGERROR("Invalid characters in $eid");
    }
    if (! ($isadmin || STUDLY() || OPSGUY())) {
	USERERROR("You do not have permission to toggle $type!", 1);
    }
    if (! ($experiment = Experiment::LookupByPidEid($pid, $eid))) {
	PAGEARGERROR("Experiment $pid/$eid is not a valid experiment!");
    }
    if (!$isadmin &&
	! TBMinTrust(TBGrpTrust($uid, $pid, $pid), $TBDB_TRUST_LOCALROOT)) {
	USERERROR("You do not have permission to toggle $type!", 1);
    }
    $zapurl = CreateURL("showexp", $experiment);
    $experiment->SetSkipVlans($value);
}
elseif ($type == "imageglobal" || $type == "imagedoesxen") {
    include("imageid_defs.php");
    
    # Must validate since we allow non-admins to do this.
    if (! TBvalid_imageid($imageid)) {
	PAGEARGERROR("Invalid characters in $imageid");
    }
    if (! ($image = Image::Lookup($imageid))) {
	PAGEARGERROR("Image $image is not a valid image!");
    }
    if (!$isadmin &&
	!$image->AccessCheck($this_user, $TB_IMAGEID_MODIFYINFO)) {
	USERERROR("You do not have permission to toggle $type!", 1);
    }
    $zapurl = CreateURL("showimageid", $image);
    if ($type == "imagedoesxen") {
	$image->DoesXen($value);
    }
    else {
	$image->SetGlobal($value);
    }
}
elseif ($type == "cvsrepo_public") {
    # Must validate the pid since we allow non-admins to do this.
    if (! TBvalid_pid($pid)) {
	PAGEARGERROR("Invalid characters in $pid");
    }
    if (! ($project = Project::Lookup($pid))) {
	PAGEARGERROR("Project $pid is not a valid project!");
    }
    # Must be admin or project/group root.
    if (!$isadmin &&
	! TBMinTrust(TBGrpTrust($uid, $pid, $pid), $TBDB_TRUST_GROUPROOT)) {
	USERERROR("You do not have permission to toggle $type!", 1);
    }
    $zapurl = CreateURL("showproject", $project);
    $project->SetCVSRepoPublic($value);
    $unix_pid = $project->unix_gid();
    SUEXEC($uid, $unix_pid, "webcvsrepo_ctrl $pid", SUEXEC_ACTION_DIE);
}
elseif ($type == "workbench") {
    # Must validate the pid since we allow non-admins to do this.
    if (! TBvalid_pid($pid)) {
	PAGEARGERROR("Invalid characters in $pid");
    }
    if (! ($project = Project::Lookup($pid))) {
	PAGEARGERROR("Project $pid is not a valid project!");
    }
    # Must be admin
    if (!$isadmin) {
	USERERROR("You do not have permission to toggle $type!", 1);
    }
    $zapurl = CreateURL("showproject", $project);
    $project->SetAllowWorkbench($value);
}
elseif ($type == "project_disable") {
    # Must be admin
    if (!$isadmin) {
	USERERROR("You do not have permission to toggle $type!", 1);
    }
    if (! ($project = Project::Lookup($pid))) {
	PAGEARGERROR("Project $pid is not a valid project!");
    }
    $project->SetDisabled($value);
}
elseif ($type == "hiderun") {
    RequiredPageArguments("instance",  PAGEARG_INSTANCE,
			  "runidx",    PAGEARG_INTEGER);

    if (! $instance->AccessCheck($this_user, $TB_EXPT_MODIFY)) {
	USERERROR("You do not have permission to modify this instance", 1);
    }
    $instance->SetRunHidden($runidx, $value);
}
else {
    USERERROR("Nobody has permission to toggle $type!", 1);
}
    
#
# Spit out a redirect 
#
if (isset($_SERVER["HTTP_REFERER"]) && $_SERVER["HTTP_REFERER"] != "" &&
    strpos($_SERVER["HTTP_REFERER"],$_SERVER["SCRIPT_NAME"])===false) {
    # Make sure the referer is not me!
    header("Location: " . $_SERVER["HTTP_REFERER"]);
}
elseif ($zapurl) {
    header("Location: $zapurl");
}
else {
    header("Location: $TBBASE/showuser.php3");
}

?>
