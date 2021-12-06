<?php
#
# Copyright (c) 2000-2017 University of Utah and the Flux Group.
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
# Only known and logged in users allowed.
#
$this_user = CheckLoginOrDie();
$uid       = $this_user->uid();
$isadmin   = ISADMIN();

#
# Verify page arguments.
#
$reqargs = RequiredPageArguments("target_user",     PAGEARG_USER);
$optargs = OptionalPageArguments("target_project",  PAGEARG_PROJECT,
				 "canceled",        PAGEARG_BOOLEAN,
				 "confirmed",       PAGEARG_BOOLEAN,
				 "confirmed_twice", PAGEARG_BOOLEAN,
				 "request",         PAGEARG_BOOLEAN);

# Need these below.
$target_dbuid = $target_user->uid();
$target_uid   = $target_user->uid();

#
# Standard Testbed Header
#
PAGEHEADER("Remove User");

#
# Requesting? Fire off email and we are done. 
# 
if (isset($request) && $request) {
    $uid_name  = $this_user->name();
    $uid_email = $this_user->email();

    TBMAIL($TBMAIL_OPS,
	   "Delete User Request: '$target_uid'",
	   "$uid is requesting that user account '$target_uid' be deleted\n".
	   "from the testbed since $target_uid is no longer a member of any ".
	   "projects.\n",
	   "From: $uid_name '$uid' <$uid_email>\n".
	   "Errors-To: $TBMAIL_WWW");

    echo "A request to remove user '$target_uid' has been sent to Testbed
          Operations. If you do not hear back within a reasonable amount
          of time, please contact $TBMAILADDR.\n";

    #
    # Standard Testbed Footer
    # 
    PAGEFOOTER();
    return;
}

#
# Must not be the head of the project being removed from, or any projects
# if being completely removed.
#
if (isset($target_project)) {
    $target_pid = $target_project->pid();
    
    if (! $isadmin) {
        if (! $target_project->CanDeleteUser($this_user, $target_user)) {
            USERERROR("You do not have permission to remove user ".
                      "$target_uid from project $target_pid!", 1);
        }
    }
    
    $leader = $target_project->GetLeader();

    if ($leader->SameUser($target_user)) {
	USERERROR("$target_uid is the leader of project $target_pid!", 1);
    }
}
else {
    $projlist = $target_user->ProjectMembershipList(TBDB_TRUSTSTRING_PROJROOT);

    if (count($projlist)) {
	USERERROR("$target_uid is still heading up projects!", 1);
    }
}

#
# Must not be the head of any groups in the project, or any groups if
# being deleted from the testbed.
#
if (isset($target_project)) {
    $query_result =
	DBQueryFatal("select pid,gid from groups ".
		     "where leader='$target_uid' and pid='$target_pid'");
    
    if (mysql_num_rows($query_result)) {
	USERERROR("$target_uid is still leading groups in ".
		  "project '$target_pid'", 1);
    }
}
else {
    $query_result =
	DBQueryFatal("select pid,gid from groups where leader='$target_uid'");

    if (mysql_num_rows($query_result)) {
	USERERROR("$target_uid is still heading up groups!", 1);
    }
}

#
# User must not be heading up any experiments at all. If deleting from
# just a specific project, must not be heading up experiments in that
# project. 
#
$experimentlist =
    $target_user->ExperimentList(1, ((isset($target_project)) ?
				     $target_project : null));

if (count($experimentlist)) {
    echo "<center><h3>
          User '$target_uid' is heading up the following experiments ".
	  (isset($target_project) ? "in project '$target_pid' " : "") .
	  ":</h3></center>\n";

    echo "<table align=center border=1 cellpadding=2 cellspacing=2>\n";

    echo "<tr>
              <th align=center>PID</td>
              <th align=center>EID</td>
              <th align=center>State</td>
              <th align=center>Description</td>
          </tr>\n";

    foreach ($experimentlist as $experiment) {
	$pid   = $experiment->pid();
	$eid   = $experiment->eid();
	$state = $experiment->state();
	$desc  = CleanString($experiment->description());
	
	if ($experiment->swap_requests() > 0) {
	    $state .= "&nbsp;(idle)";
	}

	$showproj_url = CreateURL("showproject", $experiment->Project());
	$showexp_url  = CreateURL("showexp", $experiment);
	
        echo "<tr>
                 <td><A href='showproject.php3?pid=$pid'>$pid</A></td>
                 <td><A href='showexp.php3?pid=$pid&eid=$eid'>$eid</A></td>
		 <td>$state</td>
                 <td>$desc</td>
             </tr>\n";
    }
    echo "</table>\n";

    USERERROR("They must be terminated before you can remove the user!", 1);
}

#
# We do a double confirmation, running this script multiple times. 
#
if (isset($canceled) && $canceled) {
    echo "<center><h2><br>
          User Removal Canceled!
          </h2></center>\n";
    
    PAGEFOOTER();
    return;
}

if (!isset($confirmed)) {
    echo "<center><br>\n";

    if (isset($target_project)) {
	echo "Are you <b>REALLY</b> sure you want to remove user
              '$target_uid' from project '$target_pid'?\n";
    }
    else {
	echo "Are you <b>REALLY</b> sure you want to delete user 
              '$target_uid' from the testbed?\n";
    }
    
    if (isset($target_project))
	$url = CreateURL("deleteuser", $target_user, $target_project);
    else
	$url = CreateURL("deleteuser", $target_user);
    
    echo "<form action='$url' method=post>";
    echo "<b><input type=submit name=confirmed value=Confirm></b>\n";
    echo "<b><input type=submit name=canceled value=Cancel></b>\n";
    echo "</form>\n";
    echo "</center>\n";

    PAGEFOOTER();
    return;
}

if (!isset($confirmed_twice)) {
    echo "<center><br>
	  Okay, let's be sure.<br>\n";

    if (isset($target_project)) {
	echo "Are you <b>REALLY REALLY</b> sure you want to remove user
              '$target_uid' from project '$target_pid'?\n";
    }
    else {
	echo "Are you <b>REALLY REALLY</b> sure you want to delete user 
              '$target_uid' from the testbed?\n";
    }

    if (isset($target_project))
	$url = CreateURL("deleteuser", $target_user, $target_project);
    else
	$url = CreateURL("deleteuser", $target_user);
    
    echo "<form action='$url' method=post>";
    echo "<input type=hidden name=confirmed value=Confirm>\n";
    echo "<b><input type=submit name=confirmed_twice value=Confirm></b>\n";
    echo "<b><input type=submit name=canceled value=Cancel></b>\n";
    echo "</form>\n";
    echo "</center>\n";

    PAGEFOOTER();
    return;
}

if (isset($target_project)) {
    STARTBUSY("User '$target_uid' is being removed from '$target_pid'!");
}
else {
    STARTBUSY("User '$target_uid' is being removed!");
    DOLOGOUT($target_user);
}

#
# All the real work is done in the script.
#
SUEXEC($uid, $TBADMINGROUP,
       "webrmuser " . (isset($target_project) ? "-p $target_pid " : " ") .
       "$target_uid",
       SUEXEC_ACTION_DIE);

STOPBUSY();

#
# If a user was removed from a project, and that user no longer has
# any project membership, ask if they want the user deleted. Admin
# people can act on it immediately of couse, but mere users, even
# project leaders, must send us a request for it.
#
if (isset($target_project)) {
    $projlist = $target_user->ProjectMembershipList();
    
    if (! count($projlist)) {
	echo "<b>User '$target_uid' is no longer a member of any projects.\n";

	$url = CreateURL("deleteuser", $target_user);
	    
	if ($isadmin) {
	    echo "Do you want to
                  <A href='$url'>delete this user from the testbed?</a>\n";
	}
	else {
	    echo "You can 
                  <A href='${url}&request=1'>request</a>
                     that we delete this user from the testbed</a></b>\n";
	}
    }
    else {
	if (isset($target_project)) {
	    PAGEREPLACE(CreateURL("showgroup",
				  $target_project->DefaultGroup()));
	}
    }
}

#
# Standard Testbed Footer
# 
PAGEFOOTER();
?>
