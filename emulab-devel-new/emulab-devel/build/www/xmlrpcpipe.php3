<?php
#
# Copyright (c) 2004-2010 University of Utah and the Flux Group.
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
# This is an included file. No headers or footers.
#
# Stuff to use the xmlrpc client/server. This is functionally equivalent
# to the perl stuff I wrote in xmlrpc/libxmlrpc.pm.in.
#
include("defs.php3");

$RPCSERVER  = "boss.cloudlab.umass.edu";
$RPCPORT    = "3069";
$FSDIR_USERS = "/users";

# So errors are sent back in short form.
$session_interactive = 0;

#
# Emulab XMLRPC defs.
#
# WARNING: If you change this stuff, also change defs in xmlrpc directory.
#
define("XMLRPC_RESPONSE_SUCCESS",	0);
define("XMLRPC_RESPONSE_BADARGS",	1);
define("XMLRPC_RESPONSE_ERROR",		2);
define("XMLRPC_RESPONSE_FORBIDDEN",	3);
define("XMLRPC_RESPONSE_BADVERSION",	4);
define("XMLRPC_RESPONSE_SERVERERROR",	5);
define("XMLRPC_RESPONSE_TOOBIG",	6);
define("XMLRPC_RESPONSE_REFUSED",	7);
define("XMLRPC_RESPONSE_TIMEDOUT",	8);

##
# The package version number
#
define("XMLRPC_PACKAGE_VERSION",	0.1);

$this_user = CheckLoginOrDie();
$uid       = $this_user->uid();
$isadmin   = ISADMIN();
#
# Check the XML to make sure it is well formed.
#
$all_data = file_get_contents("php://input");

if (!isset($all_data) || $all_data == "") {
    USERERROR("Where is the XML?", 1);
}
$mypipe = popen("/usr/local/bin/xmllint --noout - 2>&1", "w");
if ($mypipe == false) {
    TBERROR("Could not start xmllint", 1);
}
fwrite($mypipe, $all_data);
fflush($mypipe);
$return_value = pclose($mypipe);
if ($return_value) {
    USERERROR("Invalid XML", 1);
}

#
# Invoke the ssl xmlrpc client in raw mode, passing it an encoded XMLRPC
# string, reading back an XMLRPC encoded response, which is converted to
# a PHP datatype with the ParseResponse() function above. In other words,
# we invoke a method on a remote xmlrpc server, and get back a response.
# Invoked as the current user, but the actual uid of the caller is contained
# in the ssl certificate we use, which for now is the elabinelab certificate
# of the creator (since that is the only place this code is being used).
#

$descriptorspec = array(0 => array("pipe", "r"),
		        1 => array("pipe", "w"));

$process = proc_open("$TBSUEXEC_PATH $uid nobody webxmlrpc -r ".
		     "-s $RPCSERVER -p $RPCPORT ".
		     "--cert $FSDIR_USERS/$uid/.ssl/emulab.pem",
		     $descriptorspec, $pipes);

if (! is_resource($process)) {
    TBERROR("Could not invoke XMLRPC backend!\n".
	    "Invoked as $uid,nobody\n".
	    "XML:\n" .
	    "$all_data\n\n", 1);
}

# $pipes now looks like this:
# 0 => writeable handle connected to child stdin
# 1 => readable handle connected to child stdout

fwrite($pipes[0], $all_data);
fflush($pipes[0]);

fclose($pipes[0]);

$output = "";
#
# Now read back the results.
while(!feof($pipes[1])) {
    $output .= fread($pipes[1], 1024); # XXX do this better
}
fclose($pipes[1]);

# It is important that you close any pipes before calling
# proc_close in order to avoid a deadlock.
$return_value = proc_close($process);

if ($return_value || $output == "") {
    TBERROR("XMLRPC backend failure!\n".
	    "Invoked as $uid,nobody. Returned $return_value\n".
	    "XML:\n" .
	    "$all_data\n\n" .
	    "Output:\n" .
	    "$output\n", 1);
}

header("content-length: " . strlen($output));

echo $output;
