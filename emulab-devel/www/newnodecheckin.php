<?php
#
# Copyright (c) 2003-2016 University of Utah and the Flux Group.
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
require("defs.php3");
require("newnode-defs.php3");
include("xmlrpc.php3");

#
# Note - this script is not meant to be called by humans! It returns no useful
# information whatsoever, and expects the client to fill in all fields
# properly.
# Since this script does not cause any action to actually happen, so its save
# to leave 'in the open' - the worst someone can do is annoy the testbed admins
# with it!
#

$reqargs = RequiredPageArguments("cpuspeed",    PAGEARG_STRING,
				 "diskdev",     PAGEARG_STRING,
				 "disksize",    PAGEARG_STRING,
				 "role",        PAGEARG_STRING,
				 "messages",    PAGEARG_STRING);

$optargs = OptionalPageArguments("node_id",     PAGEARG_STRING,
				 "identifier",  PAGEARG_STRING,
				 "use_temp_IP", PAGEARG_STRING,
				 "type",        PAGEARG_STRING,
				 "cnetiface",	PAGEARG_STRING);

#
# Grab the IP address that this node has right now, so that we can contact it
# later if we need to, say, reboot it.
#
$tmpIP = getenv("REMOTE_ADDR");

#
# Find all interfaces
#
$interfaces = array();
foreach ($_GET as $key => $value) {
    if (preg_match("/iface(name|mac|driver)(\d+)/",$key,$matches)) {
        $vartype = $matches[1];
    	$ifacenum = $matches[2];
    	if ($vartype == "name") {
	    if (preg_match("/^([a-z]+)(\d+)$/i",$value,$matches)) {
		if (!isset($interfaces[$ifacenum]["type"])) {
		    $interfaces[$ifacenum]["type"] = $matches[1];
		}
	        $interfaces[$ifacenum]["card"] = $ifacenum;
		if (isset($cnetiface) && $cnetiface == $value) {
		    $cnetcard = $ifacenum;
		}
	    } else {
		echo "Bad interface name ". CleanString($value). ", ignored!";
	        $interfaces[$ifacenum]["bad"] = 1;
		continue;
	    }
	} else if ($vartype == "driver") {
	    if (preg_match("/^([a-z]+)$/i",$value,$matches)) {
		$interfaces[$ifacenum]["type"] = $matches[1];
	    } else {
		echo "Bad interface type ". CleanString($value). ", ignored!";
	        $interfaces[$ifacenum]["bad"] = 1;
		continue;
	    }
	} else {
	    if (preg_match("/^([0-9a-f]+)$/i",$value,$matches)) {
		$interfaces[$ifacenum]["mac"] = $matches[1];
	    } else {
		echo "Bad interface MAC ". CleanString($value). ", ignored!";
	        $interfaces[$ifacenum]["bad"] = 1;
		continue;
	    }
	}
    }
}
# weed out bad ones
foreach ($interfaces as $i => $interface) {
    if (isset($interface["bad"])) {
	if (isset($cnetcard) && $cnetcard == $interface["card"]) {
	    unset($cnetcard);
	}
	unset($interfaces[$i]);
    }
}

#
# Use one of the interfaces to see if this node seems to have already checked
# in once
#
if (count($interfaces)) {
    $testmac = $interfaces[0]["mac"];

    #
    # First, make sure it is not a 'real boy' - we should let the operators 
    # know about this, because there may be some problem.
    #
    $query_result = DBQueryFatal("select n.node_id from " .
	"nodes as n left join interfaces as i " .
	"on n.node_id=i.node_id " .
	"where i.mac='$testmac' or i.guid='$testmac'");
    if  (mysql_num_rows($query_result)) {
        $row = mysql_fetch_array($query_result);
	$node_id = $row["node_id"];
        echo "Node is already a real node, named $node_id\n";
	TBMAIL($TBMAIL_OPS,"Node Checkin Error","A node attempted to check " .
	    "in as a new node, but it is already\n in the database as " .
	    "$node_id!");
	exit;
    }


    #
    # Next, try the new nodes
    #
    $query_result = DBQueryFatal("select n.new_node_id, n.node_id from " .
	"new_nodes as n left join new_interfaces as i " .
	"on n.new_node_id=i.new_node_id " .
	"where i.mac='$testmac' or i.guid='$testmac'");
    if  (mysql_num_rows($query_result)) {
        $row = mysql_fetch_array($query_result);
	$id = $row["new_node_id"];
	$node_id = $row["node_id"];
        echo "Node has already checked in\n";
	echo "Node ID is $id\n";

	#
	# Keep the temp. IP address around in case its gotten a new one
	#
	DBQueryFatal("update new_nodes set temporary_IP='$tmpIP' " .
	    "where new_node_id=$id");

	exit;
    }
}


#
# Attempt to come up with a node_id and an IP address for it - unless one was
# provided by the client.
#
if (!isset($node_id)) {
    $name_info = find_free_id("pc");
    $node_prefix = $name_info[0];
    $node_num = $name_info[1];
    $hostname = $node_prefix . $node_num;
} else {
    $hostname = $node_id;
}

if (isset($use_temp_IP)) {
    $IP = $tmpIP;
} else {
    $IP = guess_IP($node_prefix,$node_num);
}

#
# Handle the node type
#
if (isset($type) && $type != "") {
    #
    # If they gave us a type, lets see if that type exists or not
    #
    if (!preg_match("/^[-\w]*$/", $type)) {
	echo "Illegal characters in type: '$type'\n";
	exit;
    }
    if (TBValidNodeType($type)) {
	#
	# Great, it already exists, nothin' else to do
	#
    } else {
	#
	# Okay, it doesn't exist. We'll create it.
	#
	make_node_type($type,$cpuspeed,$disksize);
    }
} else {
    #
    # Make an educated guess as to what type it belongs to
    #
    $type = guess_node_type($cpuspeed,$disksize);
}

#
# Default the role to 'testnode' if the node didn't supply a role
#
$role = (isset($role) ? addslashes($role) : "testnode");

#
# Stash this information in the database
#
if (isset($identifier) && $identifier != "") {
    $identifier = "'" . addslashes($identifier) . "'";
} else {
    $identifier = "NULL";
}
$messages = (isset($messages) ? addslashes($messages) : "");
$hostname = (isset($hostname) ? addslashes($hostname) : "");

DBQueryFatal("insert into new_nodes set node_id='$hostname', type='$type', " .
	"IP='$IP', temporary_IP='$tmpIP', dmesg='$messages', created=now(), " .
	"identifier=$identifier, role='$role'");

$query_result = DBQueryFatal("select last_insert_id()");
$row = mysql_fetch_array($query_result);
$new_node_id = $row[0];

echo "Node ID is $new_node_id\n";

foreach ($interfaces as $interface) {
    $card = $interface["card"];
    $mac = $interface["mac"];
    $type = $interface["type"];
    $clause = "";
    # see if they specified the cnet interface and this is it
    if (isset($cnetcard) && $cnetcard == $card) {
	$clause .= ", role='ctrl'";
    }
    # XXX not a 6 byte value, assume it is a guid
    # XXX probably should check interface_capabilities for the type
    if (strlen($mac) != 12) {
	$clause .= ", guid='$mac'";
	# XXX 16 bytes implies an Infiniband port GUID to us
	# cons up what would be the mac
	if (strlen($mac) == 16) {
	    $mac = substr($mac, 0, 6) . substr($mac, 10, 6);
	}
    }
    DBQueryFatal("insert into new_interfaces set " .
	"new_node_id=$new_node_id, card=$card, mac='$mac', " .
	"interface_type='$type'$clause");
}

#
# Send mail to testbed-ops about the new node
#
TBMAIL($TBMAIL_OPS,"New Node","A new node, $hostname, has checked in");

function check_node_exists($node_id) {
    $node_id = addslashes($node_id);
    
    #
    # Just check to see if this node already exists in one of the
    # two tables - return 1 if it does, 0 if not
    #
    $query_result = DBQueryFatal("select node_id from nodes " .
	    "where node_id='$node_id'");
    if (mysql_num_rows($query_result)) {
	return 1;
    }
    $query_result = DBQueryFatal("select node_id from new_nodes " .
	    "where node_id='$node_id'");
    if (mysql_num_rows($query_result)) {
	return 1;
    }

    return 0;
}

function find_free_id($prefix) {
    global $ELABINELAB, $TBADMINGROUP, $interfaces;

    #
    # When inside an inner emulab, we have to ask the outer emulab for
    # our nodeid; we cannot just pick one out of a hat, at least not yet.
    #
    if ($ELABINELAB) {
	$arghash = array();
	$arghash["mac"] = $interfaces[0]["mac"];

	$results = XMLRPC("nobody", $TBADMINGROUP,
			  "elabinelab.newnode_info", $arghash);

	if (!$results || ! isset($results{'nodeid'})) {
	    echo "Could not get nodeid from XMLRPC server; quitting.\n";
	    exit;
	}
	elseif (preg_match("/^(.*[^\d])(\d+)$/",
			   $results{'nodeid'}, $matches)) {
	    $base   = $matches[1];
	    $number = $matches[2];
	    return array($base, intval($number));
	}
	else {
	    $nodeid = $results{'nodeid'};
	    
	    echo "Improper nodeid ($nodeid) from XMLRPC server; quitting.\n";
	    exit;
	}
    }

    #
    # First, check to see if there's a recent entry in new_nodes we can name
    # this node after
    #
    $ndigits = 0;
    $query_result = DBQueryFatal("select node_id from new_nodes " .
        "order by created desc limit 1");
    if (mysql_num_rows($query_result)) {
        $row = mysql_fetch_array($query_result);
	$old_node_id = $row[0];
	#
	# Try to figure out if this is in some format we can increment
	#
	if (preg_match("/^(.*[^\d])(0\d+)$/",$old_node_id,$matches)) {
	    $base = $matches[1];
	    $number = $matches[2];
	    $ndigits = strlen($number);
	    echo "Matches $ndigits-digit pcXXX format";
	    $fmt = "%0" . $ndigits . "d";
	    $number = sprintf($fmt, $number + 1);
	    $potential_name = $base . $number;
	    if (!check_node_exists($potential_name)) {
		return array($base, $number);
	    }
	    $prefix = $base;
	} elseif (preg_match("/^(.*[^\d])(\d+)$/",$old_node_id,$matches)) {
	    echo "Matches pcXXX format";
	    # pcXXX format
	    $base = $matches[1];
	    $number = $matches[2];
	    $potential_name = $base . ($number + 1);
	    if (!check_node_exists($potential_name)) {
		return array($base,($number +1));
	    }
	    $prefix = $base;
	} elseif (preg_match("/^(.*)-([a-zA-Z])$/",$old_node_id,$matches)) {
	    # Something like WAIL's (type-rack-A) format
	    $base = $matches[1];
	    $lastchar = $matches[2];
	    $newchar = chr(ord($lastchar) + 1);
	    $potential_name = $base . '-' . $newchar;
	    if (!check_node_exists($potential_name)) {
		return array($base . '-', $newchar);
	    }
	    $prefix = $base;
	}
    }

    #
    # Okay, that didn't work.
    # Just go through the nodes and new_nodes tables looking for one that
    # hasn't been used yet - put in a silly little guard to prevent an
    # infinite loop in case of bugs.
    #
    if ($ndigits) {
	$fmt = "%0" . $ndigits . "d";
    }
    $node_number = 0;
    while ($node_number < 10000) {
	$number = ++$node_number;
	if ($ndigits) {
	    $number = sprintf($fmt, $number);
	}
    	$potential_name = $prefix . $number;
	if (!check_node_exists($potential_name)) {
	    break;
	}
    }

    return array($prefix, $node_number);

}

?>
