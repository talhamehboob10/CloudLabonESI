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
# Verify page arguments
#
$optargs = OptionalPageArguments("target_user", PAGEARG_USER,
				 "pub",  PAGEARG_BOOLEAN);
if (!isset($pub)) {
    $pub = 0;
}

# Default to current user if not provided.
if (!isset($target_user)) {
     $target_user = $this_user;
}

# Need these below
$target_uid = $target_user->uid();
$target_idx = $target_user->uid_idx();

#
# Only admin people can create SSL certs for another user.
#
if (!$isadmin && !$target_user->SameUser($this_user)) {
    USERERROR("You do not have permission to download SSL cert ".
	      "for $user!", 1);
}

$query_result =& $target_user->TableLookUp("user_sslcerts",
					   "cert,privkey,idx",
					   "encrypted=1 and revoked is null");

if (!mysql_num_rows($query_result)) {
    PAGEHEADER("Download SSL Certificate for $target_uid");
    USERERROR("There is no SSL Certificate for $target_uid!", 1);
}
$row  = mysql_fetch_array($query_result);
$cert = $row["cert"];
$key  = $row["privkey"];


PAGEHEADER("Export SSL Certificate");
?>

<script src="geni-auth.js"></script>
<script type="text/plain" id="certificate">
<?php
    echo "-----BEGIN RSA PRIVATE KEY-----\n";
    echo $key;
    echo "-----END RSA PRIVATE KEY-----\n";
    echo "-----BEGIN CERTIFICATE-----\n";
    echo $cert;
    echo "-----END CERTIFICATE-----\n";
?>
</script>
<script>
  function sendCertificate()
  {
    var script = document.getElementById('certificate');
    genilib.sendCertificate(script.innerHTML);
  }
</script>

<center>
  <h2><br>
  A tool has requested your private certificate.
  </h2>
  <p>If you accept, the tool will be able to act on your behalf. Click confirm below if you wish to proceed or close this window to cancel.
  </p>

  <form onsubmit="sendCertificate(); return false;" >
    <b><input type=submit name=confirmed value=Confirm></b>
<!--    <b><input type=submit name=canceled value=Cancel></b> -->
  </form>
</center>

<?php
PAGEFOOTER();
?>
