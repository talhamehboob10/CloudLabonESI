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
include_once("profile_defs.php");
include_once("instance_defs.php");

#
# Get current user.
#
RedirectSecure();
$this_user = CheckLoginOrRedirect();
$this_uid  = $this_user->uid();

#
# Verify page arguments.
#
$reqargs = RequiredPageArguments("uuid",        PAGEARG_UUID);
$optargs = OptionalPageArguments("create",      PAGEARG_STRING,
				 "formfields",  PAGEARG_ARRAY);

$profile = Profile::Lookup($uuid);
if (!$profile) {
    PAGEERROR("No such profile");
}
if (!$profile->CanInstantiate($this_user)) {
    PAGEERROR("Not enough permission to instantiate profile");
}
$am_array = Instance::DefaultAggregateList();

#
# Spit the form
#
function SPITFORM($formfrag, $formfields, $errors)
{
    global $am_array, $DEFAULT_AGGREGATE, $profile;
    $profile_uuid = $profile->uuid();
    
    SPITHEADER(1);

    # Place to hang the toplevel template.
    echo "<div id='main-body'></div>\n";
    # For the editor.
    echo "<div id='ppviewmodal_div'></div>\n";

    # I think this will take care of XSS prevention?
    echo "<script type='text/plain' id='form-json'>\n";
    echo htmlentities(json_encode($formfields)) . "\n";
    echo "</script>\n";
    echo "<script type='text/plain' id='error-json'>\n";
    echo htmlentities(json_encode($errors));
    echo "</script>\n";

    $amlist = array();
    $amdefault = "";
    if ($ISCLOUD || ISADMIN() || STUDLY()) {
        while (list($index, $aggregate) = each($am_array)) {
            $urn = $aggregate->urn();
            $am  = $aggregate->name();
	    $amlist[] = $am;
	}
	$amdefault = $DEFAULT_AGGREGATE;
    }
    echo "<script type='text/plain' id='amlist-json'>\n";
    echo htmlentities(json_encode($amlist));
    echo "</script>\n";

    echo "<script type='text/javascript'>\n";
    echo "    window.UUID      = '$profile_uuid';\n";
    echo "    window.AMDEFAULT = '$amdefault';\n";
    echo "    window.FORMFRAG  = \"" . htmlentities($formfrag) . "\";\n";
    echo "</script>\n";

    SpitOopsModal("oops");
    SpitWaitModal("waitwait");
    SPITREQUIRE("foo");
    SPITFOOTER();
}

if (! isset($create)) {
    $errors   = array();
    $defaults = array();
    $formfrag = $profile->GenerateFormFragment();

    SPITFORM($formfrag, $defaults, $errors);
    return;
}

?>
