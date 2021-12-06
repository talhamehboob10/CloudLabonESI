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

#
# Only known and logged in users can do this.
#
$this_user = CheckLoginOrDie();
$uid       = $this_user->uid();
$isadmin   = ISADMIN();

#
# Of course verify that this uid has admin privs!
#
if (! $isadmin) {
    USERERROR("You do not have admin privileges to approve projects!", 1);
}

#
# Verify page arguments.
#
$reqargs = RequiredPageArguments("project", PAGEARG_PROJECT);
$optargs = OptionalPageArguments("head_uid", PAGEARG_STRING,
				 "user_interface", PAGEARG_STRING,
				 "message", PAGEARG_ANYTHING,
				 "silent", PAGEARG_BOOLEAN,
				 "pcplab_okay", PAGEARG_BOOLEAN,
				 "ron_okay", PAGEARG_BOOLEAN,
				 "back", PAGEARG_STRING);

#
# Check to make sure thats this is a valid PID.
#
if (! ($this_project = $reqargs["project"])) {
    USERERROR("Unknown project", 1);
}
$pid = $this_project->pid();
$projleader = $this_project->GetLeader();

#
# Standard Testbed Header
#
PAGEHEADER("New Project Approval");

echo "<center><h3>You have the following choices:</h3></center>
      <table class=stealth align=center border=0>
        <tr>
            <td class=stealth>Deny</td>
            <td class=stealth>-</td>
            <td class=stealth>Deny project application (kills project records)</td>
        </tr>

        <tr>
            <td class=stealth>Destroy</td>
            <td class=stealth>-</td>
            <td class=stealth>Deny project application, and kill the user account</td>
        </tr>

        <tr>
            <td class=stealth>Approve</td>
            <td class=stealth>-</td>
            <td class=stealth>Approve the project</td>
        </tr>

        <tr>
            <td class=stealth>More Info</td>
            <td class=stealth>-</td>
            <td class=stealth>Ask for more info</td>
        </tr>

        <tr>
            <td class=stealth>Postpone</td>
            <td class=stealth>-</td>
            <td class=stealth>Twiddle your thumbs some more</td>
        </tr>
      </table>\n";

#
# Show stuff
#
$this_project->Show();

$projleader = $this_project->GetLeader();

echo "<center>
      <h3>Project Leader Information</h3>
      </center>
      <table align=center border=0>\n";

$projleader->Show();

#
# Check to make sure that the head user is 'unapproved' or 'active'
#
$headstatus = $projleader->status();
if (!strcmp($headstatus,TBDB_USERSTATUS_UNAPPROVED) ||
	!strcmp($headstatus,TBDB_USERSTATUS_ACTIVE)) {
    $approvable = 1;
} else {
    $approvable = 0;
}

#
# Now put up the menu choice along with a text box for an email message.
#
echo "<center>
      <h3>What would you like to do?</h3>
      </center>
      <table align=center border=1>
      <form action='" . CreateURL("approveproject", $project) .
             "' method='post'>\n";

echo "<tr>
          <td align=center>
              <select name=approval>
                      <option value='postpone'>Postpone</option>";
if ($approvable) {
    echo "                  <option value='approve'>Approve</option>";
}
echo "
                      <option value='moreinfo'>More Info</option>
                      <option value='deny'>Deny</option>
                      <option value='destroy'>Destroy</option>
              </select>";
if (!$approvable) {
	echo "              <br><b>WARNING:</b> Project cannot be approved,";
	echo"               since head user has not been verified";
}
echo "
          </td>
       </tr>\n";

echo "<tr>
         <td align=center>
	    <input type=checkbox value=Yep ".
               ((isset($silent) && $silent == "Yep") ? "checked " : " ") .
                     "name=silent>Silent (no email sent for deny,destroy)
	 </td>
       </tr>\n";

#
# Allow the approver to change the projects head UID - gotta find everyone in
# the default group, first
#
echo "<tr>
          <td align=center>
	      Head UID:
              <select name=head_uid>
                      <option value=''>(Unchanged)</option>";

$allmembers = $this_project->MemberList();

foreach ($allmembers as $other_user) {
    $this_uid   = $other_user->uid();
    $this_webid = $other_user->webid();
    $sel = ((isset($head_uid) && $head_uid == $this_webid) ? "selected" : "");
    
    echo "             <option $sel value='$this_webid'>$this_uid</option>\n";
}
echo "        </select>
          </td>
       </tr>\n";

#
# Set the user interface.
#
echo "<tr>
          <td align=center>
              Default User Interface:
              <select name=user_interface>\n";

foreach ($TBDB_USER_INTERFACE_LIST as $interface) {
    $sel = ((isset($user_interface) &&
	     $user_interface == $interface) ? "selected" : "");
    
    echo "            <option $sel value='$interface'>$interface</option>\n";
}
echo "        </select>
          </td>
       </tr>\n";

#
# XXX
# Temporary Plab hack.
# See if remote nodes requested and put up checkboxes to allow override.
#
# These are now booleans, not actual counts.
$num_pcplab = $this_project->num_pcplab();
$num_ron    = $this_project->num_ron();

if ($num_ron || $num_pcplab) {
        # Default these on.
        if (!isset($back)) {
	    $pcplab_okay = "Yep";
	    $ron_okay = "Yep";
	}
    
	echo "<tr>
                 <td align=center>\n";
	if ($num_pcplab) {
		echo "<input type=checkbox value=Yep ".
		     ((isset($pcplab_okay) && $pcplab_okay == "Yep")
		      ? "checked " : " ") . 
		    " name=pcplab_okay>
                                 Allow Plab &nbsp\n";
	}
	if ($num_ron) {
		echo "<input type=checkbox value=Yep ".
		     ((isset($ron_okay) && $ron_okay == "Yep")
		      ? "checked " : " ") . 
                               " name=ron_okay>
                                 Allow RON (PCWA) &nbsp\n";
	}
	echo "   </td>
              </tr>\n";
}

echo "<tr>
          <td>Use the text box (70 columns wide) to add a message to the
              email notification. </td>
      </tr>\n";

echo "<tr>
         <td align=center class=left>
             <textarea name=message rows=15 cols=70>";
if (isset($message)) {
    echo str_replace("\r", "", CleanString($message));
}
echo "</textarea>
         </td>
      </tr>\n";

echo "<tr>
          <td align=center colspan=2>
              <b><input type='submit' value='Submit' name='OK'></td>
      </tr>
      </form>
      </table>\n";

#
# Standard Testbed Footer
# 
PAGEFOOTER();
?>
