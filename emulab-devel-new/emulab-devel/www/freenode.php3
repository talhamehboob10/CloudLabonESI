<?php
#
# Copyright (c) 2000-2007 University of Utah and the Flux Group.
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
$reqargs = RequiredPageArguments("node", PAGEARG_NODE);
$optargs = OptionalPageArguments("canceled", PAGEARG_BOOLEAN,
				 "confirmed", PAGEARG_BOOLEAN);

#
# Has to be reserved of course.
#
$experiment = $node->Reservation();

if (! $experiment) {
    USERERROR($node->node_id() . " is not currently reserved!", 1);
}

# Need these below.
$node_id = $node->node_id();
$pid     = $experiment->pid();
$eid     = $experiment->eid();

#
# Perm check.
#
if (! ($isadmin || (OPSGUY()) && $pid == $TBOPSPID)) {
    USERERROR("Not enough permission to free nodes!", 1);
}

#
# Standard Testbed Header
#
PAGEHEADER("Free Node");

#
# We run this twice. The first time we are checking for a confirmation
# by putting up a form. The next time through the confirmation will be
# set. Or, the user can hit the cancel button, in which case we should
# probably redirect the browser back up a level.
#
if (isset($canceled) && $canceled) {
    echo "<center><h3><br>
          Operation canceled!
          </h3></center>\n";
    
    PAGEFOOTER();
    return;
}

if (!isset($confirmed)) {
    echo "<center><h2><br>
          Are you <b>REALLY</b>
          sure you want to free node '$node_id?'
          </h2>\n";

    $node->Show(SHOWNODE_NOFLAGS);

    $url = CreateURL("freenode", $node);
    
    echo "<form action='$url' method=post>";
    echo "<b><input type=submit name=confirmed value=Confirm></b>\n";
    echo "<b><input type=submit name=canceled value=Cancel></b>\n";
    echo "</form>\n";
    echo "</center>\n";

    PAGEFOOTER();
    return;
}

#
# Pass it off to the script.
#
STARTBUSY("Releasing node $node_id");
SUEXEC($uid, "nobody", "webnfree $pid $eid $node_id", SUEXEC_ACTION_DIE);
STOPBUSY();

#
# And send an audit message.
#
$uid_name  = $this_user->name();
$uid_email = $this_user->email();

TBMAIL($TBMAIL_AUDIT,
       "Node Free: $node_id",
       "$node_id was deallocated via the web interface by $uid ($uid_name).\n",
       "From: $uid_name <$uid_email>\n".
       "Errors-To: $TBMAIL_WWW");

PAGEREPLACE(CreateUrl("shownode", $node));

#
# Standard Testbed Footer
# 
PAGEFOOTER();
?>
