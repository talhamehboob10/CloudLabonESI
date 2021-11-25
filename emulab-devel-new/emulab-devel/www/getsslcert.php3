<?php
#
# Copyright (c) 2000-2020 University of Utah and the Flux Group.
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
include_once("defs.php3");

#
# Only known and logged in users can do this.
# Geni Users need to be able to get their credentials too. 
#
$this_user = CheckLoginOrDie(CHECKLOGIN_NOLOGINS);
$uid       = $this_user->uid();
$isadmin   = ISADMIN();

#
# Verify page arguments
#
$optargs = OptionalPageArguments("target_user", PAGEARG_USER,
				 "p12",  PAGEARG_BOOLEAN,
				 "ssh",  PAGEARG_BOOLEAN,
				 "pub",  PAGEARG_BOOLEAN);
if (!isset($p12)) {
    $p12 = 0;
}
if (!isset($ssh)) {
    $ssh = 0;
}
if (!isset($pub)) {
    $pub = 0;
}
# We use this in the aptui directory, so watch for this already
# being set.
if (!isset($FILENAME)) {
    $FILENAME = "emulab";
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

if ($p12) {
    if ($fp = popen("$TBSUEXEC_PATH $target_uid nobody webspewcert", "r")) {
	header("Content-Type: application/octet-stream;".
	       "filename=\"${FILENAME}.p12\";");
        header("Content-Disposition: attachment; filename='${FILENAME}.p12'");
	header("Cache-Control: no-cache, must-revalidate");
	header("Pragma: no-cache");
#       header("Content-Type: application/x-x509-user-cert");
	while (!feof($fp) && connection_status() == 0) {
	    print(fread($fp, 1024));
	    flush();
	}
	$retval = pclose($fp);
	$fp = 0;
    }
    return;
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

if ($ssh) {
    $serial  = $row['idx'];
    $comment = "sslcert:${serial}";
    $pubkey_result =& $target_user->TableLookUp("user_pubkeys",
						"pubkey",
						"comment='$comment'");
    if (!mysql_num_rows($query_result)) {
	PAGEHEADER("Download SSL Certificate for $target_uid");
	USERERROR("There is no SSH pubkey for certificate!", 1);
    }
    $row  = mysql_fetch_array($pubkey_result);
    $pubkey = $row['pubkey'];
    
    header("Content-Type: text/plain");
    header("Content-Disposition: attachment; filename='${FILENAME}.pem'");
    echo "-----BEGIN RSA PRIVATE KEY-----\n";
    echo $key;
    echo "-----END RSA PRIVATE KEY-----\n";
    # The user does not generally need this and it causes confusion.
    if ($pub) {
	echo $pubkey;
	echo "\n";
    }
}
else {
    header("Content-Type: text/plain");
    header("Content-Disposition: attachment; filename='${FILENAME}.pem'");
    echo "-----BEGIN RSA PRIVATE KEY-----\n";
    echo $key;
    echo "-----END RSA PRIVATE KEY-----\n";
    echo "-----BEGIN CERTIFICATE-----\n";
    echo $cert;
    echo "-----END CERTIFICATE-----\n";
}

?>
