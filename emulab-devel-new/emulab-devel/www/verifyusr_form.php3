<?php
#
# Copyright (c) 2000-2002, 2005, 2006 University of Utah and the Flux Group.
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
# Only known and logged in users can be verified.
#
$this_user = CheckLoginOrDie(CHECKLOGIN_UNVERIFIED|CHECKLOGIN_NEWUSER|
			     CHECKLOGIN_WEBONLY|CHECKLOGIN_WIKIONLY);
$uid       = $this_user->uid();

#
# Standard Testbed Header
#
PAGEHEADER("New User Verification");

echo "<p>
      The purpose of this page is to verify, for security purposes, that
      information given in your application is authentic. If you never
      received a key at the email address given on your application, please
      contact $TBMAILADDR for further assistance.
      <p>\n";

echo "<table align=\"center\" border=\"1\">
      <form action=\"verifyusr.php3\" method=\"post\">\n";

echo "<tr>
          <td>Key:</td>
          <td><input type=\"text\" name=\"key\" size=20></td>
      </tr>\n";

echo "<tr>
         <td colspan=\"2\" align=\"center\">
             <b><input type=\"submit\" value=\"Submit\"></b></td>
      </tr>\n";

echo "</form>\n";
echo "</table>\n";

#
# Standard Testbed Footer
# 
PAGEFOOTER();
?>




