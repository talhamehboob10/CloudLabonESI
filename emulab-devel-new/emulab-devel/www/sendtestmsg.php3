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

#
# Only known and logged in users can do this.
#
$this_user = CheckLoginOrDie();
$uid       = $this_user->uid();
$isadmin   = ISADMIN();

if (!$isadmin) {
    USERERROR("You do not have permission to view this page!", 1);
}

#
# Verify page arguments.
#
$reqargs = RequiredPageArguments("target_user",  PAGEARG_USER);

# Need these below
$target_uid = $target_user->uid();
$usr_name   = $target_user->name();
$usr_email  = $target_user->email();

PAGEHEADER("Send a Test Message");

# Send the email.
TBMAIL("$usr_name '$target_uid' <$usr_email>",
       "This is a test",
       "\n".
       "Dear $usr_name ($target_uid):\n".
       "\n".
       "This is a test message to validate the email address that we\n".
       "(Emulab) have in our database. Please respond to this message\n".
       "as soon as you receive it. If we do not hear back from you, we\n".
       "may be forced to freeze your account!\n".
       "\n".
       "Thank you very much!\n".
       "\n".
       "Testbed Operations\n",
       "From: $TBMAIL_OPS\n".
       "Bcc: $TBMAIL_OPS\n".
       "Errors-To: $TBMAIL_WWW");

echo "<center>
      <h2>Done!</h2>
      </center><br>\n";

#
# Standard Testbed Footer
# 
PAGEFOOTER();
?>
