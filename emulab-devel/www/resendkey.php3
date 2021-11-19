<?php
#
# Copyright (c) 2000-2003, 2006, 2007 University of Utah and the Flux Group.
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
# Verify form arguments.
#
$reqargs = RequiredPageArguments("target_user", PAGEARG_USER);

# Get email info and Key,
$target_uid = $target_user->uid();
$usr_name   = $target_user->name();
$usr_email  = $target_user->email();
$key        = $target_user->verify_key();

if (!$key || !strcmp($key, "")) {
    USERERROR("$target_uid does not have a valid verification key!", 1);
}

PAGEHEADER("Resend Verification Key");

# Send the email.
TBMAIL("$usr_name '$target_uid' <$usr_email>",
       "Your New User Key",
       "\n".
       "Dear $usr_name ($target_uid):\n\n".
       "This is your account verification key: $key\n\n".
       "Please use this link to verify your user account:\n".
       "\n".
       "    ${TBBASE}/login.php3?vuid=$target_uid&key=$key\n".
       "\n".
       "You will then be verified as a user.\n".
       "\n".
       "You MUST verify your account before any action can be taken on\n".
       "your application! After you have verified your account, and your\n".
       "application has been approved, you will be marked as an active\n".
       "user, and will be granted access to your user account.\n".
       "\n".
       "Thanks,\n".
       "Testbed Operations\n",
       "From: $TBMAIL_APPROVAL\n".
       "Bcc: $TBMAIL_AUDIT\n".
       "Errors-To: $TBMAIL_WWW");

echo "<center>
      <h2>Done!</h2>
      </center><br>\n";

#
# Standard Testbed Footer
# 
PAGEFOOTER();
?>
