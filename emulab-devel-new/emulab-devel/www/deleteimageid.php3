<?php
#
# Copyright (c) 2000-2014 University of Utah and the Flux Group.
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
include("imageid_defs.php");

#
# Only known and logged in users can end experiments.
#
$this_user = CheckLoginOrDie();
$uid       = $this_user->uid();
$isadmin   = ISADMIN();

#
# Verify page arguments.
#
$reqargs = RequiredPageArguments("image",     PAGEARG_IMAGE);
$optargs = OptionalPageArguments("canceled",  PAGEARG_BOOLEAN,
				 "confirmed", PAGEARG_BOOLEAN,
				 "purgefile", PAGEARG_BOOLEAN);

# Need these below
$imageid = $image->imageid();
$imagename = $image->imagename();
$pid = $image->pid();
$project = $image->Project();
$unix_pgid = $project->unix_gid();

#
# Verify permission.
#
if (! $image->AccessCheck($this_user, $TB_IMAGEID_DESTROY)) {
    USERERROR("You do not have permission to destroy ImageID $imageid!", 1);
}

#
# Standard Testbed Header
#
PAGEHEADER("Delete an Image Descriptor");

#
# Check to see if the imageid is being used in various places
#
if ($image->InUse()) {
    USERERROR("Image $imageid is still in use or busy!<br>".
	      "You must resolve these issues before is can be deleted!", 1);
}

#
# We run this twice. The first time we are checking for a confirmation
# by putting up a form. The next time through the confirmation will be
# set. Or, the user can hit the cancel button, in which case we should
# probably redirect the browser back up a level.
#
if (isset($canceled) && $canceled) {
    echo "<center><h2><br>
          Image Descriptor removal canceled!
          </h2></center>\n";
    
    PAGEFOOTER();
    return;
}

if (!isset($confirmed)) {
    echo "<center><h3><br>
          Are you <b>REALLY</b>
          sure you want to delete Image '$imagename' in project $pid?
          </h3>\n";

    $url = CreateURL("deleteimageid", $image);
    
    echo "<form action='$url' method=post>";
    echo "<b><input type=submit name=confirmed value=Confirm></b>\n";
    echo "<b><input type=submit name=canceled value=Cancel></b>\n";
    echo "<br><br>\n";
    echo "<input type=checkbox checked name=purgefile value=yes><br>";
    echo "Uncheck this box if you want your image file preserved.<br> ";
    echo "Typically, you want to leave the box checked.";
    echo "</form>\n";
    echo "</center>\n";

    echo "<br>
          <ul>
           <li> Please note that if you have any experiments (swapped in
                <b>or</b> out) using an OS in this image, that experiment
                cannot be swapped in or out properly. You should terminate
                those experiments first, or cancel the deletion of this
                image by clicking on the cancel button above.
          </ul>\n";
    
    PAGEFOOTER();
    return;
}
if (isset($purgefile) && $purgefile) {
    $purgeopt = "-p";
}
else {
    $purgeopt = "";
}

#
# Invoke the backend script.
#
STARTBUSY("Deleting Image Descriptor ");

$retval = SUEXEC($uid, $unix_pgid,
		 "webdelete_image -F $purgeopt $imageid", SUEXEC_ACTION_DIE);

STOPBUSY();

echo "<center>
      <h3>
      Image '$imagename' in project $pid has been deleted!\n
      </h3>\n";

echo "<br>
      <a href='showimageid_list.php3'>Back to Image Descriptor list</a>
      </center>
      <br><br>\n";

#
# Standard Testbed Footer
# 
PAGEFOOTER();
?>
