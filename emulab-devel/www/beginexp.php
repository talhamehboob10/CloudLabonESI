<?php
#
# Copyright (c) 2000-2007, 2012 University of Utah and the Flux Group.
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
# No PAGEHEADER since we spit out a Location header later. See below.
#
$errors = array();

#
# Helper function to send back errors.
#
function EXPERROR()
{
    global $formfields, $errors;

    SPITFORM($formfields, $errors);
    PAGEFOOTER();
    die("");
}

#
# Only known and logged in users can begin experiments.
#
$this_user = CheckLoginOrDie();
$uid       = $this_user->uid();
$isadmin   = ISADMIN();

# Does not return if this a request.
include("showlogfile_sup.php3");

#
# Verify page arguments.
#
$optargs = OptionalPageArguments("view_style", PAGEARG_STRING,
				 "beginexp", PAGEARG_STRING,
				 "formfields", PAGEARG_ARRAY,
				 "nsref", PAGEARG_INTEGER,
				 "guid", PAGEARG_INTEGER,
				 "copyid", PAGEARG_INTEGER);

#
# Handle pre-defined view styles
#
unset($view);
if (isset($view_style) && $view_style == "plab") {
    $view['hide_proj'] = $view['hide_group'] = $view['hide_swap'] =
	$view['hide_preload'] = $view['hide_batch'] = $view['hide_linktest'] =
        $view['quiet'] = $view['plab_ns_message'] = $view['plab_descr'] = 1;
}
include("beginexp_form.php3");

# Need this below;
$idleswaptimeout = TBGetSiteVar("idle/threshold");
$autoswap_max    = TBGetSiteVar("general/autoswap_max");

#
# See what projects the uid can create experiments in. Must be at least one.
#
$projlist = $this_user->ProjectAccessList($TB_PROJECT_CREATEEXPT);

if (! count($projlist)) {
    USERERROR("You do not appear to be a member of any Projects in which ".
	      "you have permission to create new experiments.", 1);
}

#
# On first load, display virgin form and exit.
#
if (!isset($beginexp)) {
    # Allow initial formfields data.
    if (isset($formfields))
	$defaults = $formfields;
    else
	$defaults = array();
    INITFORM($defaults, $projlist);
    PAGEFOOTER();
    return;
}
elseif (! isset($formfields)) {
    PAGEHEADER("Begin a Testbed Experiment");
    PAGEARGERROR();
}

#
# For the benefit of the form. Remember to pass back actual filename, not
# the php temporary file name. Note that there appears to be some kind
# of breakage, at least in opera; filename has no path.
#
if (isset($_FILES['exp_nsfile'])) {
    $formfields['exp_nsfile'] = $_FILES['exp_nsfile']['name'];
}

# Some local variables.
$nsfilelocale    = "";
$thensfile       = 0;
$deletensfile    = 0;
$nonsfile        = 0;
$project         = null;
$group           = null;

#
# Project:
#
if (!isset($formfields["exp_pid"]) || $formfields["exp_pid"] == "") {
    $errors["Project"] = "Not Selected";
}
elseif (!TBvalid_pid($formfields["exp_pid"])) {
    $errors["Project"] = TBFieldErrorString();
}
elseif (! ($project = Project::Lookup($formfields["exp_pid"]))) {
    $errors["Project"] = "No such project";
}
else {
    #
    # Group: If none specified, then use default group (see below).
    # Project must be valid to do this.
    #
    if (isset($formfields["exp_gid"]) && $formfields["exp_gid"] != "") {
	if (!TBvalid_gid($formfields["exp_gid"])) {
	    $errors["Group"] = TBFieldErrorString();
	}
	elseif (! ($group = Group::LookupByPidGid($formfields["exp_pid"],
						  $formfields["exp_gid"]))) {
	    $errors["Group"] = "Group '" . $formfields["exp_gid"] .
		"' is not in project '" . $formfields["exp_pid"]. "'";
	}
    }
    else {
	$group = $project->DefaultGroup();
    }
}
if (count($errors)) {
    EXPERROR();
}

#
# EID:
#
if (!isset($formfields["exp_id"]) || $formfields["exp_id"] == "") {
    $errors["Experiment Name"] = "Missing Field";
}
elseif (!TBvalid_eid($formfields["exp_id"])) {
    $errors["Experiment Name"] = TBFieldErrorString();
}
elseif ($project && $project->LookupExperiment($formfields["exp_id"])) {
    $errors["Experiment Name"] = "Already in use";
}

#
# Description:
# 
if (!isset($formfields["exp_description"]) ||
    $formfields["exp_description"] == "") {
    $errors["Description"] = "Missing Field";
}
elseif (!TBvalid_description($formfields["exp_description"])) {
    $errors["Description"] = TBFieldErrorString();
}

#
# NS File. There is a bunch of stuff here for Netbuild, which uses the
# beginexp form as a backend. Switch to XML interface someday ...
#
if (isset($formfields["guid"])) {
    if ($formfields["guid"] == "" ||
	!preg_match("/^\d+$/", $formfields["guid"])) {
	$errors["NS File GUID"] = "Invalid characters";
    }
}
if (isset($formfields['copyid'])) {
    if ($formfields["copyid"] == "" ||
	!preg_match("/^[-\w,:]*$/", $formfields['copyid'])) {
	$errors["Copy ID"] = "Invalid characters";
    }
    $nsfilelocale = "copyid";
}
elseif (isset($formfields["nsref"])) {
    if ($formfields["nsref"] == "" ||
	!preg_match("/^\d+$/", $formfields["nsref"])) {
	$errors["NS File Reference"] = "Invalid characters";
    }
    $nsfilelocale = "nsref";
}
elseif (isset($formfields["exp_localnsfile"]) &&
	$formfields["exp_localnsfile"] != "") {
    if (!preg_match("/^([-\@\w\.\/]+)$/", $formfields["exp_localnsfile"])) {
	$errors["Server NS File"] = "Pathname includes illegal characters";
    }
    elseif (! VALIDUSERPATH($formfields["exp_localnsfile"])) {
	$errors["Server NS File"] =
		"Must reside in one of: $TBVALIDDIRS";
    }
    $nsfilelocale = "local";
}
elseif (isset($_FILES['exp_nsfile']) && $_FILES['exp_nsfile']['size'] != 0) {
    if ($_FILES['exp_nsfile']['size'] > (1024 * 500)) {
	$errors["Local NS File"] = "Too big!";
    }
    elseif ($_FILES['exp_nsfile']['name'] == "") {
	$errors["Local NS File"] =
	    "Local filename does not appear to be valid";
    }
    elseif ($_FILES['exp_nsfile']['tmp_name'] == "") {
	$errors["Local NS File"] =
	    "Temp filename does not appear to be valid";
    }
    elseif (!preg_match("/^([-\@\w\.\/]+)$/",
			$_FILES['exp_nsfile']['tmp_name'])) {
	$errors["Local NS File"] = "Temp path includes illegal characters";
    }
    $nsfilelocale = "upload";
}
elseif (isset($formfields["exp_nsfile_contents"]) &&
	$formfields["exp_nsfile_contents"] != "") {
    #
    # The NS file is encoded inline. We will write it to a tempfile below
    # once all other checks passed.
    #
    $nsfilelocale = "inline";
}
else {
    #
    # I am going to allow shell experiments to be created (No NS file),
    # but only by admin types.
    #
    if (! ISADMIN()) {
	$errors["NS File"] = "You must provide an NS file";
    }
}

#
# Swappable
# Any of these which are not "1" become "0".
#
if (!isset($formfields["exp_swappable"]) ||
    strcmp($formfields["exp_swappable"], "1")) {
    $formfields["exp_swappable"] = 0;

    if (!isset($formfields["exp_noswap_reason"]) ||
        !strcmp($formfields["exp_noswap_reason"], "")) {

        if (! ISADMIN()) {
	    $errors["Not Swappable"] = "No justification provided";
        }
	else {
	    $formfields["exp_noswap_reason"] = "ADMIN";
        }
    }
    elseif (!TBvalid_description($formfields["exp_noswap_reason"])) {
	$errors["Not Swappable"] = TBFieldErrorString();
    }
}
else {
    $formfields["exp_swappable"]     = 1;
    $formfields["exp_noswap_reason"] = "";
}

if (!isset($formfields["exp_idleswap"]) ||
    strcmp($formfields["exp_idleswap"], "1")) {
    $formfields["exp_idleswap"] = 0;

    if (!isset($formfields["exp_noidleswap_reason"]) ||
	!strcmp($formfields["exp_noidleswap_reason"], "")) {
	if (! ISADMIN()) {
	    $errors["Not Idle-Swappable"] = "No justification provided";
	}
	else {
	    $formfields["exp_noidleswap_reason"] = "ADMIN";
	}
    }
    elseif (!TBvalid_description($formfields["exp_noidleswap_reason"])) {
	$errors["Not Idle-Swappable"] = TBFieldErrorString();
    }
}
else {
    $formfields["exp_idleswap"]          = 1;
    $formfields["exp_noidleswap_reason"] = "";
}

# Proper idleswap timeout must be provided.
if (!isset($formfields["exp_idleswap_timeout"]) ||
    !preg_match("/^[\d]+$/", $formfields["exp_idleswap_timeout"]) ||
    ($formfields["exp_idleswap_timeout"] + 0) <= 0 ||
    ($formfields["exp_idleswap_timeout"] + 0) > $idleswaptimeout) {
    $errors["Idleswap"] = "Invalid time provided - ".
	"must be non-zero and less than $idleswaptimeout";
}


if (!isset($formfields["exp_autoswap"]) ||
    strcmp($formfields["exp_autoswap"], "1")) {
    if (!ISADMIN()) {
	$errors["Max. Duration"] =
	    "You must ask testbed operations to disable this";
    }
    $formfields["exp_autoswap"] = 0;
}
else {
    $formfields["exp_autoswap"] = 1;
    
    if (!isset($formfields["exp_autoswap_timeout"]) ||
	!preg_match("/^[\d]+$/", $formfields["exp_idleswap_timeout"]) ||
	($formfields["exp_autoswap_timeout"] + 0) <= 0) {
	$errors["Max. Duration"] = "No or invalid time provided";
    }
    # The user can override autoswap timeout, but limit unless an admin.
    if ($formfields["exp_autoswap_timeout"] > $autoswap_max && !ISADMIN()) {
	$errors["Max. Duration"] = "$autoswap_max hours maximum - ".
	    "you must ask testbed operations for more";
    }
}

#
# Linktest option
# 
if (isset($formfields["exp_linktest"]) && $formfields["exp_linktest"] != "") {
    if (!preg_match("/^[\d]+$/", $formfields["exp_linktest"]) ||
	$formfields["exp_linktest"] < 0 || $formfields["exp_linktest"] > 4) {
	$errors["Linktest Option"] = "Invalid level selection";
    }
}

#
# If any errors, stop now. pid/eid/gid must be okay before continuing.
#
if (count($errors)) {
    EXPERROR();
}

$exp_desc    = escapeshellarg($formfields["exp_description"]);
$exp_pid     = $formfields["exp_pid"];
$exp_gid     = ((isset($formfields["exp_gid"]) &&
		 $formfields["exp_gid"] != "") ?
		$formfields["exp_gid"] : $exp_pid);
$exp_id      = $formfields["exp_id"];
$extragroups = "";

#
# Verify permissions. We do this here since pid/eid/gid could be bogus above.
#
if (! $group->AccessCheck($this_user, $TB_PROJECT_CREATEEXPT)) {
    $errors["Project/Group"] = "Not enough permission to create experiment";
    EXPERROR();
}

#
# Figure out the NS file to give to the script. Eventually we will allow
# it to come inline as an XML argument.
#
if ($nsfilelocale == "copyid") {
    if (preg_match("/^([-\w]+),([-\w]+)$/", $formfields['copyid'], $matches)) {
	$copypid = $matches[1];
	$copyeid = $matches[2];
	$okay    = 0;

	#
	# Project level check if not a current experiment.
	#
	if (($experiment = Experiment::LookupByPidEid($copypid, $copyeid))) {
	    $okay = $experiment->AccessCheck($this_user, $TB_EXPT_READINFO);
	}
	elseif (($project = Project::Lookup($copypid))) {
	    $okay = $project->AccessCheck($this_user, $TB_PROJECT_READINFO);
	}

	if (! $okay) {
	    $errors["Project/Group"] =
		"Not enough permission to copy experiment $copypid/$copyeid";
	    EXPERROR();
	}
	if ($copypid != $exp_pid)
	    $extragroups = ",$copypid";
    }
    
    $thensfile = "-c " . escapeshellarg($formfields['copyid']);
}
elseif ($nsfilelocale == "local") {
    #
    # No way to tell from here if this file actually exists, since
    # the web server runs as user nobody. The startexp script checks
    # for the file so the user will get immediate feedback if the filename
    # is bogus.
    #
    $thensfile = $formfields["exp_localnsfile"];
}
elseif ($nsfilelocale == "nsref") {
    $nsref = $formfields["nsref"];
    
    if (isset($formfields["guid"])) {
	$guid      = $formfields["guid"];
	$thensfile = "/tmp/$guid-$nsref.nsfile";
    }
    else {
	$thensfile = "/tmp/$uid-$nsref.nsfile";
    }
    if (! file_exists($thensfile)) {
	$errors["NS File"] = "Temp file no longer exists on server";
	EXPERROR();
    }
    $deletensfile = 1;
}
elseif ($nsfilelocale == "upload") {
    $thensfile = $_FILES['exp_nsfile']['tmp_name'];
    chmod($thensfile, 0666);
}
else {
    $nonsfile = 1;
}

# Okay, we can spit back a header now that there is no worry of redirect.
PAGEHEADER("Begin a Testbed Experiment");

#
# Convert other arguments to script parameters.
#
$exp_swappable = "";

# Experiments are swappable by default; supply reason if noswap requested.
if ($formfields["exp_swappable"] == "0") {
    $exp_swappable .= " -S " .
	escapeshellarg($formfields["exp_noswap_reason"]);
}

if ($formfields["exp_autoswap"] == "1") {
    $exp_swappable .= " -a " . (60 * $formfields["exp_autoswap_timeout"]);
}

# Experiments are idle swapped by default; supply reason if noidleswap requested.
if ($formfields["exp_idleswap"] == "1") {
    $exp_swappable .= " -l " . (60 * $formfields["exp_idleswap_timeout"]);
}
else {
    $exp_swappable .= " -L " .
	escapeshellarg($formfields["exp_noidleswap_reason"]);
}

$exp_batched   = 0;
$exp_preload   = 0;
$batcharg      = "-i";
$linktestarg   = "";

if (isset($formfields["exp_batched"]) &&
    strcmp($formfields["exp_batched"], "Yep") == 0) {
    $exp_batched   = 1;
    $batcharg      = "";
}
if (isset($formfields["exp_preload"]) &&
    strcmp($formfields["exp_preload"], "Yep") == 0) {
    $exp_preload   = 1;
    $batcharg     .= " -f";
}
if (isset($formfields["exp_savedisk"]) &&
    strcmp($formfields["exp_savedisk"], "Yep") == 0) {
    $batcharg     .= " -s";
}
if (isset($formfields["exp_linktest"]) && $formfields["exp_linktest"] != "") {
    $linktestarg   = "-t " . $formfields["exp_linktest"];
}

#
# Grab the unix GID for running scripts.
#
$unix_pgid = $project->unix_gid();
$unix_ggid = $group->unix_gid();

#
# Run the backend script.
#
# Avoid SIGPROF in child.
#
set_time_limit(0);

STARTBUSY("Starting Experiment");

$retval = SUEXEC($uid, "$unix_pgid,$unix_ggid" . $extragroups ,
		 "webbatchexp $batcharg -E $exp_desc $exp_swappable ".
		 "$linktestarg -p $exp_pid -g $exp_gid -e $exp_id ".
		 ($nonsfile ? "" : "$thensfile"),
		 SUEXEC_ACTION_IGNORE);
HIDEBUSY();

if ($deletensfile) {
    unlink($thensfile);
}

#
# Fatal Error. Report to the user, even though there is not much he can
# do with the error. Also reports to tbops.
# 
if ($retval < 0) {
    SUEXECERROR(SUEXEC_ACTION_CONTINUE);
}

# User error. Tell user and exit.
if ($retval) {
    echo "<br>";
    echo "<blockquote><pre>$suexec_output<pre></blockquote>";

    PAGEFOOTER();
    exit();
}

# Display a useful message.
$message = "";
if ($nonsfile) {
    $message =
         "Since you did not provide an NS script, no nodes have been
          allocated. You will not be able to modify or swap this experiment,
          nor do most other neat things you can do with a real experiment.";
}
elseif ($exp_preload) {
    $message = 
         "Since you are only pre-loading the experiment, this will typically
          take less than one minute. If you do not receive email notification
          within a reasonable amount of time, please contact $TBMAILADDR.";
}
elseif ($exp_batched) {
    $message = 
         "Batch Mode experiments will be run when enough resources become
          available. This might happen immediately, or it may take hours
	  or days. You will be notified via email when the experiment has
          been run. If you do not receive email notification within a
          reasonable amount of time, please contact $TBMAILADDR.";
}
else {
    $message = 
         "You will be notified via email when the experiment has been fully
	  configured and you are able to proceed. This typically takes less
          than 10 minutes, depending on the number of nodes you have requested.
          If you do not receive email notification within a reasonable amount
          of time, please contact $TBMAILADDR.";
}

# Map to the actual experiment and show the log.
if (($experiment = Experiment::LookupByPidEid($formfields["exp_pid"],
					      $formfields["exp_id"]))) {
    echo $experiment->PageHeader();
    echo "<br>\n";
    echo "<b>Starting experiment configuration!</b> " . $message;
    echo "<br><br>\n";
    STARTLOG($experiment);
}
else {
    echo "<br>\n";
    echo "<b>Starting experiment configuration!</b> " . $message;
    echo "<br>\n";
}
						
#
# Standard Testbed Footer
#
PAGEFOOTER();
?>
