<?php
#
# Copyright (c) 2000-2016 University of Utah and the Flux Group.
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
chdir("..");
include("defs.php3");
chdir("apt");
include("quickvm_sup.php");
$page_title = "Invite a User";

#
# Get current user.
#
RedirectSecure();
$this_user = CheckLoginOrRedirect();
$this_idx  = $this_user->uid_idx();

#
# Verify page arguments.
#
$optargs = OptionalPageArguments("invite",       PAGEARG_STRING,
				 "formfields",   PAGEARG_ARRAY);

#
# Spit the form
#
function SPITFORM($formfields, $errors)
{
    global $projlist;
    
    SPITHEADER(1);

    echo "<div id='invite-body'></div>\n";
    echo "<script type='text/plain' id='form-json'>\n";
    echo htmlentities(json_encode($formfields)) . "\n";
    echo "</script>\n";
    echo "<script type='text/plain' id='error-json'>\n";
    echo htmlentities(json_encode($errors));
    echo "</script>\n";
    # Pass project list through. Need to convert to list without groups.
    # When editing, pass through a single value. The template treats a
    # a single value as a read-only field.
    $plist = array();
    while (list($project) = each($projlist)) {
	$plist[] = $project;
    }
    echo "<script type='text/plain' id='projects-json'>\n";
    echo htmlentities(json_encode($plist));
    echo "</script>\n";
    
    echo "<script src='js/lib/jquery-2.0.3.min.js'></script>\n";

    REQUIRE_UNDERSCORE();
    REQUIRE_SUP();
    REQUIRE_APTFORMS();
    SPITREQUIRE("js/invite.js");

    AddTemplate("invite");
    SPITFOOTER();
}

#
# See what projects the user can do this in.
#
$projlist = $this_user->ProjectAccessList($TB_PROJECT_MAKEGROUP);

#
# If not clicked, then put up a form.
#
if (! isset($invite)) {
    $defaults = array();
    $errors   = array();

    SPITFORM($defaults, $errors);
    return;
}

#
# Otherwise, must validate and redisplay if errors
#
$errors = array();

if (!isset($formfields["pid"]) ||
    strcmp($formfields["pid"], "") == 0) {
    $errors["pid"] = "Missing Field";
}
else {
    if (!TBvalid_newpid($formfields["pid"])) {
	$errors["pid"] = TBFieldErrorString();
    }
    $project = Project::LookupByPid($formfields["pid"]);
    if (!$project) {
	$errors["pid"] = "No such project.";
    }
}
if (!isset($formfields["email"]) ||
    strcmp($formfields["email"], "") == 0) {
    $errors["email"] = "Missing Field";
}
elseif (! TBvalid_email($formfields["email"])) {
    $errors["email"] = "Not a valid email address";
}
if (!isset($formfields["message"]) ||
    strcmp($formfields["message"], "") == 0) {
    $errors["message"] = "Missing Field";
}
elseif (! TBvalid_why($formfields["message"])) {
    $errors["message"] = TBFieldErrorString();
}

# Present these errors before we call out to do anything else.
if (count($errors)) {
    SPITFORM($formfields, $errors);
    return;
}

$url = "$APTBASE/signup.php?joinproject=1&pid=" . $formfields["pid"];
$user_name  = $this_user->name();
$user_email = $this_user->email(); 
    
mail($formfields["email"],
     "$user_name has sent you an invitation to join APT",
     "$user_name has sent you an invitation to join APT.\n".
     "Please follow this link to the APT signup page:\n\n".
     "\t$url\n\n",
     "From: $user_email");

SPITFORM($formfields, $errors);

?>
