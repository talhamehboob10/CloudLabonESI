<?php
#
# Copyright (c) 2003-2014 University of Utah and the Flux Group.
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

if (!$isadmin) {
    USERERROR("You do not have permission to access this page!", 1);
}

#
# Verify form arguments.
#
$reqargs = RequiredPageArguments("project", PAGEARG_PROJECT);
$optargs = OptionalPageArguments("submit",  PAGEARG_STRING,
				 "message", PAGEARG_ANYTHING);
$pid = $project->pid();

PAGEHEADER("Resend Project Approval Message");

#
# Form to allow text input.
#
function SPITFORM($project, $message, $errors)
{
    global $this_user;
    $message = CleanString($message);
    
    if ($errors) {
	echo "<table class=nogrid
                     align=center border=0 cellpadding=6 cellspacing=0>
              <tr>
                 <th align=center colspan=2>
                   <font size=+1 color=red>
                      &nbsp;Oops, please fix the following errors!&nbsp;
                   </font>
                 </td>
              </tr>\n";

	while (list ($name, $message) = each ($errors)) {
            # XSS prevention.
	    $message = CleanString($message);
	    echo "<tr>
                     <td align=right>
                       <font color=red>$name:&nbsp;</font></td>
                     <td align=left>
                       <font color=red>$message</font></td>
                  </tr>\n";
	}
	echo "</table><br>\n";
    }

    #
    # Show stuff
    #
    $project->Show();

    $url = CreateURL("resendapproval", $project);

    echo "<br>";
    echo "<table align=center border=1>\n";
    echo "<form action='$url' method='post'>\n";

    echo "<tr>
              <td>Use the text box (70 columns wide) to add a message to the
                  email notification. </td>
          </tr>\n";

    echo "<tr>
             <td align=center class=left>
                 <textarea name=message rows=15 cols=70></textarea>
             </td>
          </tr>\n";

    echo "<tr>
              <td align=center>
                  <b><input type='submit' value='Submit' name='submit'></td>
          </tr>
          </form>
          </table>\n";
}

#
# On first load, display a virgin form and exit.
#
if (! isset($submit)) {
    SPITFORM($project, "", null);
    PAGEFOOTER();
    return;
}

# If there is a message in the text box, it is appended below.
if (! isset($message)) {
    $message = "";
}

if (! ($leader = $project->GetLeader())) {
    TBERROR("Error getting leader for $pid", 1);
}
$headuid       = $leader->uid();
$headuid_email = $leader->email();
$headname      = $leader->name();

SendProjAdminMail(
       $project,
       "ADMIN",
       "$headname '$headuid' <$headuid_email>",
       "Project '$pid' Approval",
       "\n".
       "This message is to notify you that your project '$pid'\n".
       "has been approved.  We recommend that you save this link so that\n".
       "you can send it to people you wish to have join your project.\n".
       "Otherwise, tell them to go to ${TBBASE} and join it.\n".
       "\n".
       "    ${TBBASE}/joinproject.php3?target_pid=$pid\n".
       "\n".
       ($message != "" ? "${message}\n\n" : "") .
       "Thanks,\n".
       "Testbed Operations\n");

echo "<center>
      <h2>Done!</h2>
      </center><br>\n";

sleep(1);

PAGEREPLACE(CreateURL("showproject", $project));

#
# Standard Testbed Footer
# 
PAGEFOOTER();
?>
