<?php
#
# Copyright (c) 2010 University of Utah and the Flux Group.
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
$RPCSERVER  = "";
$RPCPORT    = "3069";
$RPCCERT    = "/etc/outer_emulab.pem";

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

#
# This is the "structure" returned by the RPC server. It gets converted into
# a php hash by the unmarshaller, and we return that directly to the caller
# (as a reference).
#
# class EmulabResponse:
#    def __init__(self, code, value=0, output=""):
#        self.code     = code            # A RESPONSE code
#        self.value    = value           # A return value; any valid XML type.
#        self.output   = output          # Pithy output to print
#        return
#
function ParseResponse($xmlgoo)
{
    # The method is ignored.
    $decoded = xmlrpc_decode_request($xmlgoo, $meth);
    $rval    = array();

    if (array_key_exists("faultCode", $decoded) &&
	array_key_exists("faultString", $decoded)) {
	$code   = $decoded{"faultCode"};
	$value  = $code;
	$output = $decoded{"faultString"};
    }
    elseif (!(array_key_exists("code", $decoded) &&
	      array_key_exists("value", $decoded) &&
	      array_key_exists("output", $decoded))) {
	#
	# Malformed response; let caller do something reasonable.
	#
	return NULL;
    }
    else {
	$code   = $decoded{"code"};
	$value  = $decoded{"value"};
	$output = $decoded{"output"};
    }
    $rval{'code'}   = $code;
    $rval{'value'}  = $value;
    $rval{'output'} = $output;

    return $rval;
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
function XMLRPC($uid, $gid, $method, $arghash)
{
    global $TBSUEXEC_PATH, $TBADMINGROUP;
    global $RPCSERVER, $RPCPORT, $RPCCERT;

    $xmlcode = xmlrpc_encode_request($method,
				     array(XMLRPC_PACKAGE_VERSION, $arghash));

    $descriptorspec = array(0 => array("pipe", "r"),
			    1 => array("pipe", "w"));

    $process = proc_open("$TBSUEXEC_PATH $uid $TBADMINGROUP webxmlrpc -r ".
			 "-s $RPCSERVER -p $RPCPORT --cert=$RPCCERT ",
			 $descriptorspec, $pipes);

    if (! is_resource($process)) {
	TBERROR("Could not invoke XMLRPC backend!\n".
		"$uid $gid $method\n".
		print_r($arghash, true), 1);
    }
    # $pipes now looks like this:
    # 0 => writeable handle connected to child stdin
    # 1 => readable handle connected to child stdout

    #
    # Write the request to the process, and then close the pipe so that
    # the other side sees the EOF.
    #
    fwrite($pipes[0], "$xmlcode");
    fflush($pipes[0]);
    fclose($pipes[0]);

    #
    # Now read back the results into a string.
    $output = "";
    while(!feof($pipes[1])) {
	$output .= fgets($pipes[1], 1024);
    }
    fclose($pipes[1]);

    # It is important that you close any pipes before calling
    # proc_close in order to avoid a deadlock.
    $return_value = proc_close($process);

    if ($return_value || $output == "" ||
	(($decoded = ParseResponse($output)) == NULL) || $decoded{"code"}) {
	TBERROR("XMLRPC backend failure!\n".
		"$uid $gid $method returned $return_value\n".
		"Arg Hash:\n" .
		print_r($arghash, true) . "\n\n" .
		"XML:\n" .
		"$xmlcode\n\n" .
		"Output:\n" .
		"$output\n", 1);
    }
#    TBERROR(print_r($decoded, true), 0);
    return $decoded{'value'};
}
?>
