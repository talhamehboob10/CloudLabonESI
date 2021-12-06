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
chdir("..");
include("defs.php3");
include_once("geni_defs.php");
chdir("apt");
include("quickvm_sup.php");
include_once("instance_defs.php");
include_once("profile_defs.php");

#
# Get current user but make sure coming in on SSL.
#
RedirectSecure();
$this_user = CheckLogin($check_status);

#
# Verify page arguments.
#
$optargs = OptionalPageArguments("login",    PAGEARG_BOOLEAN,
                                 "redirect", PAGEARG_BOOLEAN);

if (! ($CHECKLOGIN_STATUS & CHECKLOGIN_LOGGEDIN)) {
    if ($redirect) {
        header("Location: landing.php");
    }
    elseif ($ISEMULAB && !$login) {
        header("Location: frontpage.php");
    }
    else {
        header("Location: login.php");
    }
    return;
}

#
# Redirect logged in user.
#
if ($this_user) {
    if ($CHECKLOGIN_STATUS & CHECKLOGIN_UNAPPROVED) {
        # Take them to the myaccount page, they will see a banner
        # message there.
	header("Location: $APTBASE/myaccount.php");
    }
    elseif ($this_user->IsNonLocal() && $this_user->webonly()) {
	header("Location: $APTBASE/nomembership.php");
    }
    elseif (Instance::UserHasInstances($this_user)) {
	header("Location: $APTBASE/user-dashboard.php");
    }
    elseif (Profile::UserHasProfiles($this_user)) {
	header("Location: $APTBASE/user-dashboard.php#profiles");
    }
    elseif ($ISEMULAB && $this_user->PCsInUse()) {
	header("Location: $APTBASE/user-dashboard.php");
    }
    elseif ($ISEMULAB && $this_user->ExperimentList(0)) {
	header("Location: $APTBASE/user-dashboard.php#profiles");
    }
    else {
	header("Location: $APTBASE/user-dashboard.php#profiles");
    }
    return;
}

header("Location: $APTBASE/instantiate.php");
?>
