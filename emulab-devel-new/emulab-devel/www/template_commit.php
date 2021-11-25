<?php
#
# Copyright (c) 2000-2011 University of Utah and the Flux Group.
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
# Only known and logged in users.
#
$this_user = CheckLoginOrDie();
$uid       = $this_user->uid();
$isadmin   = ISADMIN();

#
# Verify page arguments.
#
$reqargs = RequiredPageArguments("instance",  PAGEARG_INSTANCE);
$optargs = OptionalPageArguments("canceled",  PAGEARG_BOOLEAN,
				 "confirmed", PAGEARG_BOOLEAN);
$template = $instance->GetTemplate();

# Canceled operation redirects back to template page.
if (isset($canceled) && $canceled) {
    header("Location: ". CreateURL("template_show", $template));
    return;
}

# Need these below.
$guid = $template->guid();
$vers = $template->vers();
$pid  = $template->pid();
$eid  = $instance->eid();
$unix_gid = $template->UnixGID();
$project  = $template->GetProject();
$unix_pid = $project->unix_gid();

#
# Check permission.
#
if (! $template->AccessCheck($this_user, $TB_EXPT_MODIFY)) {
    USERERROR("You do not have permission to commit experiment template ".
	      "$guid/$vers!", 1);
}

#
# Confirm
#
if (!isset($confirmed)) {
    PAGEHEADER("Create Template from Instance");
    echo $instance->ExpPageHeader();
    
    echo "<center><br><font size=+1>
          Create new Template from instance $eid 
             in Template $guid/$vers?</font>\n";
    
    $template->Show();
    echo "<br>";
    $instance->Show(0);

    $url = CreateURL("template_commit", $instance);
    echo "<form action='$url' method=post>\n";
    echo "<br>\n";
    echo "<br>\n";
    echo "<b><input type=submit name=confirmed value=Confirm></b>\n";
    echo "<b><input type=submit name=canceled value=Cancel></b>\n";
    echo "</form>\n";
    echo "</center>\n";
    
    PAGEFOOTER();
    return;
}

#
# Avoid SIGPROF in child.
#
set_time_limit(0);

PAGEHEADER("Create Template from Instance");

echo $instance->ExpPageHeader();
echo "<br><br>\n";

echo "<script type='text/javascript' language='javascript' ".
	"        src='template_sup.js'>\n";
echo "</script>\n";

STARTBUSY("Starting commit");
$retval = SUEXEC($uid, "$unix_pid,$unix_gid",
		 "webtemplate_commit -e $eid $guid/$vers",
		 SUEXEC_ACTION_IGNORE);

/* Clear the 'loading' indicators above */
if ($retval) {
    CLEARBUSY();
}
else {
    STOPBUSY();
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
    SUEXECERROR(SUEXEC_ACTION_USERERROR);
    return;
}

# Zap to the newly created template page.
$template->Refresh();

PAGEREPLACE("template_show.php?guid=$guid&version=". $template->child_vers());

#
# In case the above fails.
#
echo "<center><b>Done!</b></center>";
echo "<br><br>\n";

#
# Standard Testbed Footer
# 
PAGEFOOTER();
?>
