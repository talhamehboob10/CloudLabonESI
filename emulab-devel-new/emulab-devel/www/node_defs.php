<?php
#
# Copyright (c) 2006-2021 University of Utah and the Flux Group.
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
include_once("osinfo_defs.php");
include_once("nodetype_defs.php");

#
# A cache to avoid lookups. Indexed by node_id.
#
$node_cache = array();

# Constants for Show() method.
define("SHOWNODE_NOFLAGS",	0);
define("SHOWNODE_SHORT",	1);
define("SHOWNODE_NOPERM",	2);

class Node
{
    var	$node;

    #
    # Constructor by lookup on unique index.
    #
    function Node($node_id) {
	$safe_node_id = addslashes($node_id);

	$query_result =
	    DBQueryWarn("select * from nodes where node_id='$safe_node_id'");

	if (!$query_result || !mysql_num_rows($query_result)) {
	    $this->node = NULL;
	    return;
	}
	$this->node = mysql_fetch_array($query_result);
    }

    # Hmm, how does one cause an error in a php constructor?
    function IsValid() {
	return !is_null($this->node);
    }

    # Lookup by node_id
    function Lookup($node_id) {
	global $node_cache;

        if (!TBvalid_node_id($node_id)) {
	    return null;
        }
        # Look in cache first
	if (array_key_exists("$node_id", $node_cache))
	    return $node_cache["$node_id"];

	$foo = new Node($node_id);

	if (! $foo->IsValid())
	    return null;

	# Insert into cache.
	$node_cache["$node_id"] =& $foo;
	return $foo;
    }

    # Lookup by IP
    function LookupByIP($ip) {
	$safe_ip = addslashes($ip);
	
	$query_result =
	    DBQueryFatal("select i.node_id from interfaces as i ".
			 "where i.IP='$safe_ip' and ".
			 "      i.role='" . TBDB_IFACEROLE_CONTROL . "'");

	if (mysql_num_rows($query_result) == 0) {
	    return null;
	}
	$row = mysql_fetch_array($query_result);
	return Node::Lookup($row["node_id"]);
    }

    # Lookup by Mac
    function LookupByMac($mac) {
	$safe_mac = addslashes($mac);
	
	$query_result =
	    DBQueryFatal("select i.node_id from interfaces as i ".
			 "where i.mac='$safe_mac' and ".
			 "      i.role='" . TBDB_IFACEROLE_CONTROL . "'");

	if (mysql_num_rows($query_result) == 0) {
	    return null;
	}
	$row = mysql_fetch_array($query_result);
	return Node::Lookup($row["node_id"]);
    }

    #
    # Refresh an instance by reloading from the DB.
    #
    function Refresh() {
	if (! $this->IsValid())
	    return -1;

	$node_id = $this->node_id();

	$query_result =
	    DBQueryWarn("select * from nodes where node_id='$node_id'");
    
	if (!$query_result || !mysql_num_rows($query_result)) {
	    $this->node = NULL;
	    return -1;
	}
	$this->node = mysql_fetch_array($query_result);
	return 0;
    }

    #
    # Equality test.
    #
    function SameNode($node) {
	return $node->node_id() == $this->node_id();
    }

    # accessors
    function field($name) {
	return (is_null($this->node) ? -1 : $this->node[$name]);
    }
    function node_id()		{ return $this->field("node_id"); }
    function type() { return $this->field("type"); }
    function phys_nodeid() {return $this->field("phys_nodeid"); }
    function role() {return $this->field("role"); }
    function def_boot_osid() {return $this->field("def_boot_osid"); }
    function def_boot_osid_vers() {return $this->field("def_boot_osid_vers"); }
    function def_boot_path() {return $this->field("def_boot_path"); }
    function def_boot_cmd_line() {return $this->field("def_boot_cmd_line"); }
    function temp_boot_osid() {return $this->field("temp_boot_osid"); }
    function temp_boot_osid_vers() {return $this->field("temp_boot_osid_vers");}
    function next_boot_osid() {return $this->field("next_boot_osid"); }
    function next_boot_osid_vers() {return $this->field("next_boot_osid_vers");}
    function next_boot_path() {return $this->field("next_boot_path"); }
    function next_boot_cmd_line() {return $this->field("next_boot_cmd_line"); }
    function pxe_boot_path() {return $this->field("pxe_boot_path"); }
    function next_pxe_boot_path() {return $this->field("next_pxe_boot_path"); }
    function rpms() {return $this->field("rpms"); }
    function deltas() {return $this->field("deltas"); }
    function tarballs() {return $this->field("tarballs"); }
    function startupcmd() {return $this->field("startupcmd"); }
    function startstatus() {return $this->field("startstatus"); }
    function ready() {return $this->field("ready"); }
    function priority() {return $this->field("priority"); }
    function bootstatus() {return $this->field("bootstatus"); }
    function status() {return $this->field("status"); }
    function status_timestamp() {return $this->field("status_timestamp"); }
    function failureaction() {return $this->field("failureaction"); }
    function routertype() {return $this->field("routertype"); }
    function eventstate() {return $this->field("eventstate"); }
    function state_timestamp() {return $this->field("state_timestamp"); }
    function op_mode() {return $this->field("op_mode"); }
    function op_mode_timestamp() {return $this->field("op_mode_timestamp"); }
    function allocstate() {return $this->field("allocstate"); }
    function update_accounts() {return $this->field("update_accounts"); }
    function next_op_mode() {return $this->field("next_op_mode"); }
    function ipodhash() {return $this->field("ipodhash"); }
    function osid() {return $this->field("osid"); }
    function ntpdrift() {return $this->field("ntpdrift"); }
    function ipport_low() {return $this->field("ipport_low"); }
    function ipport_next() {return $this->field("ipport_next"); }
    function ipport_high() {return $this->field("ipport_high"); }
    function sshdport() {return $this->field("sshdport"); }
    function jailflag() {return $this->field("jailflag"); }
    function jailip() {return $this->field("jailip"); }
    function sfshostid() {return $this->field("sfshostid"); }
    function stated_tag() {return $this->field("stated_tag"); }
    function rtabid() {return $this->field("rtabid"); }
    function cd_version() {return $this->field("cd_version"); }
    function boot_errno() {return $this->field("boot_errno"); }
    function reserved_pid() {return $this->field("reserved_pid"); }
    function reservation_name() {return $this->field("reservation_name"); }
    function taint_states() {return $this->field("taint_states"); }
    function reservable() {return $this->field("reservable"); }

    function def_boot_image() {
	return Image::Lookup($this->def_boot_osid(),
			     $this->def_boot_osid_vers());
    }
    function def_boot_osinfo() {
	return OSinfo::Lookup($this->def_boot_osid(),
			      $this->def_boot_osid_vers());
    }

    #
    # Access Check, determines if $user can access $this record.
    # 
    function AccessCheck($user, $access_type) {
	global $TB_NODEACCESS_READINFO;
	global $TB_NODEACCESS_MODIFYINFO;
	global $TB_NODEACCESS_LOADIMAGE;
	global $TB_NODEACCESS_REBOOT;
	global $TB_NODEACCESS_POWERCYCLE;
	global $TB_NODEACCESS_MIN;
	global $TB_NODEACCESS_MAX;
	global $TBDB_TRUST_USER;
	global $TBDB_TRUST_GROUPROOT;
	global $TBDB_TRUST_LOCALROOT;
	global $TBOPSPID;
	global $CHECKLOGIN_USER;
	$mintrust = $TBDB_TRUST_USER;

	if ($access_type < $TB_NODEACCESS_MIN ||
	    $access_type > $TB_NODEACCESS_MAX) {
	    TBERROR("Invalid access type: $access_type!", 1);
	}

	$uid = $user->uid();

	if (! ($experiment = $this->Reservation())) {
            #
	    # If the current user is in the emulab-ops project and has 
	    # sufficient privs, then he can muck with free nodes as if he 
	    # were an admin type.
	    #
	    if ($uid == $CHECKLOGIN_USER->uid() && OPSGUY()) {
		return(TBMinTrust(TBGrpTrust($uid, $TBOPSPID, $TBOPSPID),
				  $TBDB_TRUST_LOCALROOT));
	    }
	    return 0;
	}
	$pid = $experiment->pid();
	$gid = $experiment->gid();
	$eid = $experiment->eid();

	if ($access_type == $TB_NODEACCESS_READINFO) {
	    $mintrust = $TBDB_TRUST_USER;
	}
	else {
	    $mintrust = $TBDB_TRUST_LOCALROOT;
	}
	return TBMinTrust(TBGrpTrust($uid, $pid, $gid), $mintrust) ||
	    TBMinTrust(TBGrpTrust($uid, $pid, $pid), $TBDB_TRUST_GROUPROOT);
    }

    #
    # Page header; spit back some html for the typical page header.
    #
    function PageHeader() {
	$node_id = $this->node_id();
	
	$html = "<font size=+2>Node <b>".
	    "<a href=shownode.php3?node_id=$node_id><b>$node_id</a>".
	    "</b></font>\n";

	return $html;
    }

    #
    # Get the bootlog for this node.
    #
    function BootLog(&$log, &$stamp) {
	$log     = null;
	$stamp   = null;
	$node_id = $this->node_id();
	
	$query_result =
	    DBQueryFatal("select * from node_bootlogs ".
			 "where node_id='$node_id'");

	if (mysql_num_rows($query_result) == 0)
	    return -1;

	$row = mysql_fetch_array($query_result);
	$log   = $row["bootlog"];
	$stamp = $row["bootlog_timestamp"];
	return 0;
    }

    function IsRemote() {
	$type = $this->type();

	$query_result =
	    DBQueryFatal("select isremotenode from node_types ".
			 "where type='$type'");
	
	if (mysql_num_rows($query_result) == 0) {
	    return 0;
	}
	$row = mysql_fetch_array($query_result);
	return $row["isremotenode"];
    }

    function IsVirtNode() {
	$type = $this->type();

	$query_result =
	    DBQueryFatal("select isvirtnode from node_types ".
			 "where type='$type'");
	
	if (mysql_num_rows($query_result) == 0) {
	    return 0;
	}
	$row = mysql_fetch_array($query_result);
	return $row["isvirtnode"];
    }

    function NodeStatus() {
	$node_id = $this->node_id();

	$query_result =
	    DBQueryFatal("select status from nodes where node_id='$node_id'");

	if (mysql_num_rows($query_result) == 0) {
	    return "";
	}
	$row = mysql_fetch_array($query_result);
	return $row["status"];
    }

    function RealNodeStatus() {
	$node_id = $this->node_id();

	$query_result =
	    DBQueryFatal("select status from node_status ".
			 "where node_id='$node_id'");

	if (mysql_num_rows($query_result) == 0) {
	    return "";
	}
	$row = mysql_fetch_array($query_result);
	return $row["status"];
    }

    #
    # Get the experiment this node is reserved too, or null.
    #
    function Reservation() {
	$node_id = $this->node_id();
	
	$query_result =
	    DBQueryFatal("select pid,eid from reserved ".
			 "where node_id='$node_id'");

	if (mysql_num_rows($query_result) == 0) {
	    return null;
	}
	$row = mysql_fetch_array($query_result);
	$pid = $row["pid"];
	$eid = $row["eid"];

	return Experiment::LookupByPidEid($pid, $eid);
    }

    #
    # Get the raw reserved table info and return it, or null if no reservation
    #
    function ReservedTableEntry() {
	$node_id = $this->node_id();
	
	$query_result =
	    DBQueryFatal("select * from reserved ".
			 "where node_id='$node_id'");

	if (mysql_num_rows($query_result) == 0) {
	    return null;
	}
	return mysql_fetch_array($query_result);
    }

    #
    # See if this node has a serial console.
    #
    function HasSerialConsole() {
	$node_id = $this->node_id();
	
	$query_result =
	    DBQueryFatal("select tipname from tiplines ".
			 "where node_id='$node_id' and disabled=0");
	
	return mysql_num_rows($query_result);
    }

    #
    # Return the class of the node.
    #
    function TypeClass() {
	$this_type = $this->type();
	
	$query_result =
	    DBQueryFatal("select class from node_types ".
			 "where type='$this_type'");

	if (mysql_num_rows($query_result) == 0) {
	    return "";
	}

	$row = mysql_fetch_array($query_result);
	return $row["class"];
    }

    #
    # Get subboss info.
    #
    function SubBossInfo()
    {
        $node_id = $this->node_id();

        $query_result =
            DBQueryFatal("select service,subboss_id from subbosses ".
                         "where node_id ='$node_id' and disabled=0");

	if (mysql_num_rows($query_result) == 0) {
	    return null;
	}
        $result = array();

        while ($row = mysql_fetch_array($query_result)) {
            $service = $row["service"];
            $subboss = $row["subboss_id"];

            $result[$service] = $subboss;
        }
        return $result;
    }        

    #
    # Return the virtual name of a reserved node.
    #
    function VirtName() {
	if (! ($row = $this->ReservedTableEntry())) {
	    return "";
	}
	if (! $row["vname"]) {
	    return "";
	}
	return $row["vname"];
    }

    var $lastact_query =
	"greatest(last_tty_act,last_net_act,last_cpu_act,last_ext_act)";

    #
    # Gets the time of idleness for a node, in hours by default (ie '2.75')
    #
    function IdleTime($format = 0) {
	$node_id = $this->node_id();
	$clause  = $this->lastact_query;
	
	$query_result =
	    DBQueryWarn("select (unix_timestamp(now()) - unix_timestamp( ".
			"        $clause)) as idle_time from node_activity ".
			"where node_id='$node_id' and ".
			"      UNIX_TIMESTAMP(last_report)!=0");

	if (mysql_num_rows($query_result) == 0) {
	    return -1;
	}
	$row   = mysql_fetch_array($query_result);
	$t = $row["idle_time"];
        # if it is less than 5 minutes, it is not idle at all...
	$t = ($t < 300 ? 0 : $t);
	if (!$format) {
	    $t = round($t/3600,2);
	}
	else {
	    $t = date($format,mktime(0,0,$t));
	}
	return $t;
    }

    #
    # Find out if a node idle reports are stale
    #
    function IdleStale() {
	$node_id = $this->node_id();

	#
        # We currently have a 5 minute interval for slothd between reports
        # So give some slack in case a node reboots without reporting for
	# a while
	#
	# In Minutes;
	$staletime = 10;
	$stalesec  = 60 * $staletime;
	
	$query_result =
	    DBQueryWarn("select (unix_timestamp(now()) - ".
			"    unix_timestamp(last_report )) as t ".
			"from node_activity where node_id='$node_id'");

	if (mysql_num_rows($query_result) == 0) {
	    return -1;
	}
	$row   = mysql_fetch_array($query_result);
	return ($row["t"]>$stalesec);
    }

    #
    # Get the last activity values.
    #
    function LastActivity() {
	$node_id = $this->node_id();

	$query_result =
	    DBQueryFatal("select * from node_activity ".
                         "where node_id='$node_id'");

	if (mysql_num_rows($query_result) == 0) {
	    return null;
	}
	return mysql_fetch_array($query_result);
    }

    #
    # Root password (when node is allocated).
    #
    function RootPassword() {
	$node_id = $this->node_id();

	$query_result =
	    DBQueryFatal("select attrvalue from node_attributes ".
			 "where node_id='$node_id' and ".
			 "      attrkey='root_password'");
        
	if (mysql_num_rows($query_result) == 0) {
	    return null;
	}
	$row = mysql_fetch_array($query_result);
        return $row[0];
    }

    #
    # Check to see if node is tainted.
    #
    function IsTainted($instate = "") {
        $tstates = $this->taint_states();
        # No taint states set on this node?
	if (!isset($tstates) || !$tstates) {
	    return 0;
	}
        # Any taint will do if nothing was passed in to check.
	if (!$instate) {
	    return 1;
	}
	foreach (explode(",", $tstates) as $taint) {
	    if (strcmp($instate, $taint) == 0) {
	        return 1;
	    }
	}
	return 0;
    }

    #
    # Control IP
    #
    function ControlIP() {
	$node_id = $this->node_id();

        $query_result =
            DBQueryFatal("select IP from interfaces ".
                         "where node_id='$node_id' and ".
                         "      role='" . TBDB_IFACEROLE_CONTROL . "'");

	if (mysql_num_rows($query_result) == 0) {
            return "";
	}
	$row = mysql_fetch_array($query_result);
        return $row[0];
    }
    # And the management IP
    function ManagementIP() {
	$node_id = $this->node_id();

        $query_result =
            DBQueryFatal("select IP from interfaces ".
                         "where node_id='$node_id' and ".
                         "      role='" . TBDB_IFACEROLE_MANAGEMENT . "'");

	if (mysql_num_rows($query_result) == 0) {
            return null;
	}
	$row = mysql_fetch_array($query_result);
        return $row[0];
    }

    #
    # Show node record.
    #
    function Show($flags = 0) {
	global $IPV6_ENABLED, $IPV6_SUBNET_PREFIX;
	
	$node_id = $this->node_id();
	$short   = ($flags & SHOWNODE_SHORT  ? 1 : 0);
	$noperm  = ($flags & SHOWNODE_NOPERM ? 1 : 0);
    
	$query_result =
	    DBQueryFatal("select n.*,na.*,r.vname,r.pid,r.eid,i.IP,i.mac, ".
			 "greatest(last_tty_act,last_net_act,last_cpu_act,".
			 "last_ext_act) as last_act, ".
			 "  t.isvirtnode,t.isremotenode,t.isplabdslice, ".
			 "  r.erole as rsrvrole, pi.IP as phys_IP, loc.*, ".
			 "  util.*,n.uuid as node_uuid, ".
			 "  mi.IP as mngmnt_IP ".
			 " from nodes as n ".
			 "left join reserved as r on n.node_id=r.node_id ".
			 "left join node_activity as na on ".
			 "     n.node_id=na.node_id ".
			 "left join node_types as t on t.type=n.type ".
			 "left join interfaces as i on ".
			 "     i.node_id=n.node_id and ".
			 "     i.role='" . TBDB_IFACEROLE_CONTROL . "' ".
			 "left join interfaces as pi on ".
			 "     pi.node_id=n.phys_nodeid and ".
			 "     pi.role='" . TBDB_IFACEROLE_CONTROL . "' ".
			 "left join interfaces as mi on ".
			 "     mi.node_id=n.node_id and ".
			 "     mi.role='" . TBDB_IFACEROLE_MANAGEMENT . "' ".
			 "left join location_info as loc on ".
			 "     loc.node_id=n.node_id ".
			 "left join node_utilization as util on ".
			 "     util.node_id=n.node_id ".
			 "where n.node_id='$node_id'");
	
	if (mysql_num_rows($query_result) == 0) {
	    TBERROR("The node $node_id is not a valid nodeid!", 1);
	}
		
	$row = mysql_fetch_array($query_result);

	$phys_nodeid        = $row["phys_nodeid"]; 
	$type               = $row["type"];
	$vname		    = $row["vname"];
	$pid 		    = $row["pid"];
	$eid		    = $row["eid"];
	$def_boot_osid      = $row["def_boot_osid"];
	$def_boot_osid_vers = $row["def_boot_osid_vers"];
	$def_boot_cmd_line  = $row["def_boot_cmd_line"];
	$next_boot_osid     = $row["next_boot_osid"];
	$next_boot_osid_vers= $row["next_boot_osid_vers"];
	$temp_boot_osid     = $row["temp_boot_osid"];
	$temp_boot_osid_vers= $row["temp_boot_osid_vers"];
	$next_boot_cmd_line = $row["next_boot_cmd_line"];
	$rpms               = $row["rpms"];
	$tarballs           = $row["tarballs"];
	$startupcmd         = $row["startupcmd"];
	$routertype         = $row["routertype"];
	$eventstate         = $row["eventstate"];
	$state_timestamp    = $row["state_timestamp"];
	$allocstate         = $row["allocstate"];
	$allocstate_timestamp= $row["allocstate_timestamp"];
	$op_mode            = $row["op_mode"];
	$op_mode_timestamp  = $row["op_mode_timestamp"];
	$IP                 = $row["IP"];
	$isvirtnode         = $row["isvirtnode"];
	$isremotenode       = $row["isremotenode"];
	$isplabdslice       = $row["isplabdslice"];
	$ipport_low	    = $row["ipport_low"];
	$ipport_next	    = $row["ipport_next"];
	$ipport_high	    = $row["ipport_high"];
	$sshdport	    = $row["sshdport"];
	$last_act           = $row["last_act"];
	$last_tty_act       = $row["last_tty_act"];
	$last_net_act       = $row["last_net_act"];
	$last_cpu_act       = $row["last_cpu_act"];
	$last_ext_act       = $row["last_ext_act"];
	$last_report        = $row["last_report"];
	$rsrvrole           = $row["rsrvrole"];
	$phys_IP	    = $row["phys_IP"];
	$mngmnt_IP	    = $row["mngmnt_IP"];
	$battery_voltage    = $row["battery_voltage"];
	$battery_percentage = $row["battery_percentage"];
	$battery_timestamp  = $row["battery_timestamp"];
	$boot_errno         = $row["boot_errno"];
	$reserved_pid       = $row["reserved_pid"];
	$inception          = $row["inception"];
	$alloctime          = $row["allocated"];
	$downtime           = $row["down"];
	$uuid               = $row["node_uuid"];
	$mac		    	= $row["mac"];
	$taint_states       = $row["taint_states"];

	if (!$def_boot_cmd_line)
	    $def_boot_cmd_line = "&nbsp;";
	if (!$next_boot_cmd_line)
	    $next_boot_cmd_line = "&nbsp;";
	if (!$rpms)
	    $rpms = "&nbsp;";
	if (!$tarballs)
	    $tarballs = "&nbsp;";
	if (!$startupcmd)
	    $startupcmd = "&nbsp;";
	else
	    $startupcmd = CleanString($startupcmd);

	if ($node_id != $phys_nodeid) {
	    if (! ($phys_this = Node::Lookup($phys_nodeid))) {
		TBERROR("Cannot map physical node $phys_nodeid to object", 1);
	    }
	}

	if (!$short) {
            #
            # Location info.
            # 
	    if (isset($row["loc_x"]) && isset($row["loc_y"]) &&
		isset($row["floor"]) && isset($row["building"])) {
		$floor    = $row["floor"];
		$building = $row["building"];
		$room     = $row["room"];
		$loc_x    = $row["loc_x"];
		$loc_y    = $row["loc_y"];
		$orient   = $row["orientation"];
		$contact  = $row["contact"];
		$email    = $row["email"];
		$phone    = $row["phone"];
	
		$query_result =
		    DBQueryFatal("select * from floorimages ".
				 "where scale=1 and ".
				 "      floor='$floor' and ".
				 "      building='$building'");

		if (mysql_num_rows($query_result)) {
		    $row = mysql_fetch_array($query_result);
	    
		    if (isset($row["pixels_per_meter"]) &&
			($pixels_per_meter = $row["pixels_per_meter"]) != 0.0){
		
			$meters_x = sprintf("%.3f",
					    $loc_x / $pixels_per_meter);
			$meters_y = sprintf("%.3f",
					    $loc_y / $pixels_per_meter);

			if (isset($orient)) {
			    $orientation = sprintf("%.3f", $orient);
			}
		    }
		}
	    }
	}

	echo "<table border=2 cellpadding=0 cellspacing=2
                 align=center>\n";

	echo "<tr>
              <td>Node ID:</td>
              <td class=left>$node_id</td>
          </tr>\n";

	if ($isvirtnode) {
	    if (strcmp($node_id, $phys_nodeid)) {
		echo "<tr>
                      <td>Phys ID:</td>
                      <td class=left>
	   	          <a href='shownode.php3?node_id=$phys_nodeid'>
                             $phys_nodeid</a></td>
                  </tr>\n";
	    }
	}

	if (!$short && !$noperm) {
	    if ($vname) {
		echo "<tr>
                      <td>Virtual Name:</td>
                      <td class=left>$vname</td>
                  </tr>\n";
	    }

	    if ($pid) {
		echo "<tr>
                      <td>Project: </td>
                      <td class=\"left\">
                          <a href='showproject.php3?pid=$pid'>$pid</a></td>
                  </tr>\n";

		echo "<tr>
                      <td>Experiment:</td>
                      <td><a href='showexp.php3?pid=$pid&eid=$eid'>
                             $eid</a></td>
                  </tr>\n";
	    }
	}

	echo "<tr>
              <td>Node Type:</td>
              <td class=left>
  	          <a href='shownodetype.php3?node_type=$type'>$type</td>
          </tr>\n";

	$feat_result =
	    DBQueryFatal("select * from node_features ".
			 "where node_id='$node_id'");

	if (mysql_num_rows($feat_result) > 0) {
	    $features = "";
	    $count = 0;
	    while ($row = mysql_fetch_array($feat_result)) {
		if (($count > 0) && ($count % 2) == 0) {
		    $features .= "<br>";
		}
		$features .= " " . $row["feature"];
		$count += 1;
	    }

	    echo "<tr><td>Features:</td><td class=left>$features</td></tr>";
	}

	if (!$short && !$noperm) {
	    echo "<tr>
                  <td>Def Boot OS:</td>
                  <td class=left>";
	    SpitOSIDLink($def_boot_osid, $def_boot_osid_vers);
	    echo "    </td>
              </tr>\n";

	    if ($eventstate) {
		$when = strftime("20%y-%m-%d %H:%M:%S", $state_timestamp);
		echo "<tr>
                     <td>EventState:</td>
                     <td class=left>$eventstate ($when)</td>
                  </tr>\n";
	    }

	    if ($op_mode) {
		$when = strftime("20%y-%m-%d %H:%M:%S", $op_mode_timestamp);
		echo "<tr>
                     <td>Operating Mode:</td>
                     <td class=left>$op_mode ($when)</td>
                  </tr>\n";
	    }

	    if ($allocstate) {
		$when = strftime("20%y-%m-%d %H:%M:%S", $allocstate_timestamp);
		echo "<tr>
                     <td>AllocState:</td>
                     <td class=left>$allocstate ($when)</td>
                  </tr>\n";
	    }
	}
	if (!$short) {
            #
            # Location info.
            # 
	    if (isset($building)) {
		echo "<tr>
                      <td>Location (bldg/floor/room):</td>
                      <td class=left>$building";
		if (isset($floor)) {
		    echo "/$floor";
		}
		if (isset($room)) {
		    echo "/$room";
		}
		echo "</td>
                      </tr>\n";
	    }
	    if (isset($meters_x) && isset($meters_y)) {
		echo "<tr>
                      <td>Location Coordinates:</td>
                      <td class=left>x=$meters_x, y=$meters_y meters";
		if (isset($orientation)) {
		    echo " (o=$orientation degrees)";
		}
		echo      "</td>
                  </tr>\n";
	    }
	    if (OPSGUY() && (isset($contact) || isset($email))) {
		$lcstr = "";
		if (isset($contact)) {
		    $lcstr .= "$contact:";
		}
		if (isset($email)) {
		    $lcstr .= " <a href='mailto:$email'>$email</a>";
		}
		if (isset($phone)) {
		    $lcstr .= " $phone";
		}
		echo "<tr>
                      <td>Location Contact:</td>
                      <td class=left>$lcstr
                      </td>
                  </tr>\n";
	    }
	}
	
	if (!$short && !$noperm) {
             #
             # We want the last login for this node, but only if its *after* 
             # the experiment was created (or swapped in).
             #
	    if ($lastnodeuidlogin = TBNodeUidLastLogin($node_id)) {
		$foo = $lastnodeuidlogin["date"] . " " .
		    $lastnodeuidlogin["time"] . " " .
		    "(" . $lastnodeuidlogin["uid"] . ")";
	
		echo "<tr>
                      <td>Last Login:</td>
                      <td class=left>$foo</td>
                 </tr>\n";
	    }

	    if ($last_act) {
		echo "<tr>
                      <td>Last Activity:</td>
                      <td class=left>$last_act</td>
                  </tr>\n";

		$idletime = $this->IdleTime();
		echo "<tr>
                      <td>Idle Time:</td>
                      <td class=left>$idletime hours</td>
                  </tr>\n";

		echo "<tr>
                      <td>Last Act. Report:</td>
                      <td class=left>$last_report</td>
                  </tr>\n";

		echo "<tr>
                      <td>Last TTY Act.:</td>
                      <td class=left>$last_tty_act</td>
                  </tr>\n";

		echo "<tr>
                      <td>Last Net. Act.:</td>
                      <td class=left>$last_net_act</td>
                  </tr>\n";

		echo "<tr>
                      <td>Last CPU Act.:</td>
                      <td class=left>$last_cpu_act</td>
                  </tr>\n";

		echo "<tr>
                      <td>Last Ext. Act.:</td>
                      <td class=left>$last_ext_act</td>
                  </tr>\n";
	    }
	}

	if (!$short && !$noperm) {
	    if (!$isvirtnode && !$isremotenode) {
		echo "<tr>
                      <td>Def Boot Command&nbsp;Line:</td>
                      <td class=left>$def_boot_cmd_line</td>
                  </tr>\n";

		echo "<tr>
                      <td>Next Boot OS:</td>
                      <td class=left>";
    
		if ($next_boot_osid)
		    SpitOSIDLink($next_boot_osid, $next_boot_osid_vers);
		else
		    echo "&nbsp;";

		echo "    </td>
                  </tr>\n";

		echo "<tr>
                      <td>Next Boot Command Line:</td>
                      <td class=left>$next_boot_cmd_line</td>
                  </tr>\n";

		echo "<tr>
                      <td>Temp Boot OS:</td>
                      <td class=left>";
    
		if ($temp_boot_osid)
		    SpitOSIDLink($temp_boot_osid, $temp_boot_osid_vers);
		else
		    echo "&nbsp;";

		echo "    </td>
                  </tr>\n";
	    }
	    elseif ($isvirtnode) {
		if (!$isplabdslice) {
		    echo "<tr>
                          <td>IP Port Low:</td>
                          <td class=left>$ipport_low</td>
                      </tr>\n";

		    echo "<tr>
                          <td>IP Port Next:</td>
                          <td class=left>$ipport_next</td>
                      </tr>\n";

		    echo "<tr>
                          <td>IP Port High:</td>
                          <td class=left>$ipport_high</td>
                      </tr>\n";
		}
		echo "<tr>
                      <td>SSHD Port:</td>
                     <td class=left>$sshdport</td>
                  </tr>\n";
	    }

	    echo "<tr>
                  <td>Startup Command:</td>
                  <td class=left>$startupcmd</td>
              </tr>\n";

	    echo "<tr>
                  <td>Tarballs:</td>
                  <td class=left>$tarballs</td>
              </tr>\n";

	    echo "<tr>
                  <td>RPMs:</td>
                  <td class=left>$rpms</td>
              </tr>\n";

	    echo "<tr>
                  <td>Boot Errno:</td>
                  <td class=left>$boot_errno</td>
              </tr>\n";

	    if (!$isvirtnode && !$isremotenode) {
		echo "<tr>
                      <td>Router Type:</td>
                      <td class=left>$routertype</td>
                  </tr>\n";
	    }

	    if ($IP) {
		echo "<tr>
                      <td>Control Net IP:</td>
                      <td class=left>$IP</td>
                  </tr>\n";

		if ($IPV6_ENABLED) {
		    $v = substr($mac, 1, 1);
		    $v = base_convert($v,16,2);
		    $v = str_pad($v, 4, '0', STR_PAD_LEFT);
		    if (substr($v,2,1) == '0')
			$v = substr_replace($v, '1', 2, 1);
		    else
			$v = substr_replace($v, '0', 2, 1);
		    $v = base_convert($v,2,16);
		    $IP6 = $IPV6_SUBNET_PREFIX . ':' . substr($mac,0,1) . $v .
			substr($mac,2,2) . ':' . substr($mac,4,2) . 'ff:fe' .
			substr($mac,6,2) . ':' . substr($mac,8,4) . "\n";

		    echo "<tr>
                           <td>Control Net IPv6:</td>
                           <td class=left>$IP6</td>
                          </tr>\n";
		}
		if ($mngmnt_IP) {
		    echo "<tr>
                          <td>Management IP:</td>
                          <td class=left>$mngmnt_IP</td>
                       </tr>\n";
		}
	    }
	    elseif ($phys_IP) {
		echo "<tr>
                      <td>Physical IP:</td>
                      <td class=left>$phys_IP</td>
                  </tr>\n";
	    }
	    if ($rsrvrole) {
		echo "<tr>
                      <td>Role:</td>
                      <td class=left>$rsrvrole</td>
                  </tr>\n";
	    }
	
	    if ($reserved_pid) {
		echo "<tr>
                      <td>Reserved Pid:</td>
                      <td class=left>
                          <a href='showproject.php3?pid=$reserved_pid'>
                               $reserved_pid</a></td>
                  </tr>\n";
	    }
	    if ($uuid) {
		echo "<tr>
                      <td>UUID:</td>
                      <td class=left>$uuid</td>
                  </tr>\n";
	    }
	    if ($taint_states) {
		echo "<tr>
                      <td>Taint States:</td>
                      <td class=left>$taint_states</td>
                  </tr>\n";
	    }
	
            #
            # Show battery stuff
            #
	    if (isset($battery_voltage) && isset($battery_percentage)) {
		echo "<tr>
    	              <td>Battery Volts/Percent</td>
		      <td class=left>";
		printf("%.2f/%.2f ", $battery_voltage, $battery_percentage);

		if (isset($battery_timestamp)) {
		    echo "(" . date("m/d/y H:i:s", $battery_timestamp) . ")";
		}

		echo "    </td>
		  </tr>\n";
	    }

	    if ($isplabdslice) {
		$query_result = 
		    DBQueryFatal("select leaseend from plab_slice_nodes ".
				 "where node_id='$node_id'");
          
		if (mysql_num_rows($query_result) != 0) {
		    $row = mysql_fetch_array($query_result);
		    $leaseend = $row["leaseend"];
		    echo"<tr>
                     <td>Lease Expiration:</td>
                     <td class=left>$leaseend</td>
                 </tr>\n";
		}
	    }

	    if ($isremotenode) {
		if ($isvirtnode) {
		    $phys_this->ShowWideAreaNode(1);
		}
		else {
		    $this->ShowWideAreaNode(1);
		}
	    }

            #
            # Show any auxtypes the node has
            #
	    $query_result =
		DBQueryFatal("select type, count from node_auxtypes ".
			     "where node_id='$node_id'");
    
	    if (mysql_num_rows($query_result) != 0) {
		echo "<tr>
                      <td align=center colspan=2>
                      Auxiliary Types
                      </td>
                  </tr>\n";

		echo "<tr><th>Type</th><th>Count</th>\n";

		while ($row = mysql_fetch_array($query_result)) {
		    $type  = $row["type"];
		    $count = $row["count"];
		    echo "<tr>
    	    	          <td>$type</td>
		          <td class=left>$count</td>
		      </td>\n";
		}
	    }
	}
    
	if (!$short) {
            #
            # Get interface info.
            #
	    echo "<tr>
                  <td align=center colspan=2>Interface Info</td>
              </tr>\n";
	    echo "<tr><th>Interface</th><th>Model; protocols</th>\n";
    
	    $query_result =
		DBQueryFatal("select i.*,it.*,c.*,s.capval as channel ".
			     "  from interfaces as i ".
			     "left join interface_types as it on ".
			     "     i.interface_type=it.type ".
			     "left join interface_capabilities as c on ".
			     "     i.interface_type=c.type and ".
			     "     c.capkey='protocols' ".
			     "left join interface_settings as s on ".
			     "     s.node_id=i.node_id and s.iface=i.iface and ".
			     "     s.capkey='channel' ".
			     "where i.node_id='$node_id' and ".
			     "      i.role='" . TBDB_IFACEROLE_EXPERIMENT . "'".
			     "order by iface");
    
	    while ($row = mysql_fetch_array($query_result)) {
		$iface     = $row["iface"];
		$type      = $row["type"];
		$man       = $row["manufacturer"];
		$model     = $row["model"];
		$protocols = $row["capval"];
		$channel   = $row["channel"];

		if (isset($channel)) {
		    $channel = " (channel $channel)";
		}
		else
		    $channel = "";

		echo "<tr>
                      <td>$iface:&nbsp; $channel</td>
                      <td class=left>$type ($man $model; $protocols)</td>
                  </tr>\n";
	    }

	    #
	    # Get subboss info.
	    #
	    echo "<tr>
              <td align=center colspan=2>Subboss Info</td>
            </tr>\n";
	    echo "<tr><th>Service</th><th>Subboss Node ID</th>\n";

	    $query_result =
	        DBQueryFatal("select service,subboss_id from subbosses ".
			     "where node_id ='$node_id' and disabled=0");

	    while ($row = mysql_fetch_array($query_result)) {
	        $service = $row["service"];
	        $subboss = $row["subboss_id"];

	        echo "<tr>
                  <td>$service</td>
                  <td class=left>$subboss</td>
                 </tr>\n";
	    }

            #
            # Switch info. Very useful for debugging.
            #
	    if (!$noperm) {
		$query_result =
		    DBQueryFatal("select i.*,w.* from interfaces as i ".
				 "left join wires as w on ".
                                 "     i.node_id=w.node_id1 and ".
				 "     i.iface=w.iface1 ".
				 "where i.node_id='$node_id' and ".
				 "      w.node_id1 is not null ".
				 "order by iface");

		echo "<tr></tr><tr>
                    <td align=center colspan=2>Switch Info</td>
                  </tr>\n";
		echo "<tr><th>Iface:role &nbsp; card,port</th>
                      <th>Switch &nbsp; card,port</th>\n";
		
		while ($row = mysql_fetch_array($query_result)) {
		    $iface       = $row["iface"];
		    $role        = $row["role"];
		    $card        = $row["card1"];
		    $port        = $row["port1"];
		    $switch      = $row["node_id2"];
		    $switch_card = $row["card2"];
		    $switch_port = $row["port2"];

		    echo "<tr>
                      <td>$iface:$role &nbsp; $card,$port</td>
                      <td class=left>".
			"$switch: &nbsp; $switch_card,$switch_port</td>
                  </tr>\n";
		}
	    }
	}

        #
        # Spit out node attributes
        #

	# Don't emit root password if node is tainted with "useronly" or
	# "blackbox".
	$noroot = $noperm || $this->IsTainted("useronly") || 
	    $this->IsTainted("blackbox");
	$query_result =
	    DBQueryFatal("select attrkey,attrvalue from node_attributes ".
			 "where node_id='$node_id' ".
			 (!ISADMIN() ? "and hidden=0 " : " ").
			 ($noroot ? "and attrkey!='root_password'" : ""));
			 
	if (!$short && mysql_num_rows($query_result)) {
	    echo "<tr>
                    <td align=center colspan=2>Node Attributes</td>
                  </tr>\n";
	    echo "<tr><th>Attribute</th><th>Value</th>\n";

	    while($row = mysql_fetch_array($query_result)) {
		$attrkey   = $row["attrkey"];
		$attrvalue = $row["attrvalue"];

		echo "<tr>
                        <td>$attrkey</td>
                        <td>$attrvalue</td>
                      </td>\n";
	    }
	}

	if (! ($short || $noperm || $isvirtnode)) {
	    $query_result =
		DBQueryFatal("select n.node_id,pid,eid,exptidx ".
			     " from nodes as n ".
			     "left join reserved as r on r.node_id=n.node_id ".
			     "where n.phys_nodeid='$node_id' and ".
			     "      n.node_id!=n.phys_nodeid");
	    if (mysql_num_rows($query_result)) {
		echo "<tr>
                       <td align=center colspan=2>Virtual/Sub Nodes</td>
                      </tr>\n";
		echo "<tr><th>Node ID</th><th>Experiment</th>\n";

		while($row = mysql_fetch_array($query_result)) {
		    $vnodeid = $row["node_id"];
		    $vpid    = $row["pid"];
		    $veid    = $row["eid"];
		    $vidx    = $row["exptidx"];
		    $url1    = CreateURL("shownode", URLARG_NODEID, $vnodeid);

		    echo "<tr>
                            <td><a href='$url1'>$vnodeid</a></td>\n";
		    
		    if (isset($veid)) {
			$url2 = CreateURL("showexp", URLARG_EID, $vidx);
			echo "<td><a href='$url2'>$vpid/$veid</a></td>\n";
		    }
		    else {
			echo "<td>No Experiment</a></td>\n";
		    }
		    echo "</td>\n";
		}
	    }
	}

	echo "</table>\n";
    }

    #
    # Show widearea node record. Just the widearea stuff, not the other.
    #
    function ShowWideAreaNode($embedded = 0) {
	$node_id = $this->node_id();
	
	$query_result =
	    DBQueryFatal("select * from widearea_nodeinfo ".
			 "where node_id='$node_id'");

	if (! mysql_num_rows($query_result)) {
	    return;
	}
	$row = mysql_fetch_array($query_result);
	$contact_uid	= $row["contact_uid"];
	$machine_type   = $row["machine_type"];
	$connect_type	= $row["connect_type"];
	$city		= $row["city"];
	$state		= $row["state"];
	$zip		= $row["zip"];
	$country	= $row["country"];
	$hostname	= $row["hostname"];
	$site		= $row["site"];
	$boot_method    = $row["boot_method"];
	$gateway        = $row["gateway"];
	$dns            = $row["dns"];

	if (! ($user = User::Lookup($contact_uid))) {
            # This is not an error since the field is set to "nobody" when
            # there is no contact info. Why is that?
	    $showuser_url = CreateURL("showuser", URLARG_UID, $contact_uid);
	}
	else {
	    $showuser_url = CreateURL("showuser", $user);
	}

	if (! $embedded) {
	    echo "<table border=2 cellpadding=0 cellspacing=2
                         align=center>\n";
	}
	else {
	    echo "<tr>
                   <td align=center colspan=2>
                       Widearea Info
                   </td>
                 </tr>\n";
	}

	echo "<tr>
                  <td>Contact UID:</td>
                  <td class=left>
                      <a href='$showuser_url'>$contact_uid</a></td>
              </tr>\n";

	echo "<tr>
                  <td>Machine Type:</td>
                  <td class=left>$machine_type</td>
              </tr>\n";

	echo "<tr>
                  <td>connect Type:</td>
                  <td class=left>$connect_type</td>
              </tr>\n";

	echo "<tr>
                  <td>City:</td>
                  <td class=left>$city</td>
              </tr>\n";

	echo "<tr>
                  <td>State:</td>
                  <td class=left>$state</td>
              </tr>\n";

	echo "<tr>
                  <td>ZIP:</td>
                  <td class=left>$zip</td>
              </tr>\n";

	echo "<tr>
                  <td>Country:</td>
                  <td class=left>$country</td>
              </tr>\n";

        echo "<tr>
                  <td>Hostname:</td>
                  <td class=left>$hostname</td>
              </tr>\n";

        echo "<tr>
                  <td>Boot Method:</td>
                  <td class=left>$boot_method</td>
              </tr>\n";

        echo "<tr>
                  <td>Gateway:</td>
                  <td class=left>$gateway</td>
              </tr>\n";

        echo "<tr>
                  <td>DNS:</td>
                  <td class=left>$dns</td>
              </tr>\n";

	echo "<tr>
                  <td>Site:</td>
                  <td class=left>$site</td>
              </tr>\n";

	if (! $embedded) {
	    echo "</table>\n";
	}
    }

    #
    # Show log.
    # 
    function ShowLog() {
	$node_id = $this->node_id();

	$query_result =
	    DBQueryFatal("select * from nodelog where node_id='$node_id'".
			 "order by reported");

	if (! mysql_num_rows($query_result)) {
	    echo "<br>
                      <center>
                       There are no entries in the log for node $node_id.
                      </center>\n";
	    return 0;
	}

	echo "<br>
                  <center>
                    Log for node $node_id.
                  </center><br>\n";

	echo "<table border=1 cellpadding=2 cellspacing=2 align='center'>\n";
	echo "<tr>
                 <th>Delete?</th>
                 <th>Date</th>
                 <th>ID</th>
                 <th>Type</th>
                 <th>Reporter</th>
                 <th>Entry</th>
              </tr>\n";

	while ($row = mysql_fetch_array($query_result)) {
	    $type       = $row["type"];
	    $log_id     = $row["log_id"];
	    $reporter   = $row["reporting_uid"];
	    $date       = $row["reported"];
	    $entry      = $row["entry"];
	    $url        = CreateURL("deletenodelog", $this, "log_id", $log_id);

	    echo "<tr>
 	             <td align=center>
                      <a href='$url'>
                         <img alt='Delete Log Entry' src='redball.gif'>
                      </a></td>
                     <td>$date</td>
                     <td>$log_id</td>
                     <td>$type</td>
                     <td>$reporter</td>
                     <td>$entry</td>
                  </tr>\n";
	}
	echo "</table>\n";
    }
    
    #
    # Show one log entry.
    # 
    function ShowLogEntry($log_id) {
	$node_id = $this->node_id();
	$safe_id = addslashes($log_id);
	
	$query_result =
	    DBQueryFatal("select * from nodelog where ".
			 "node_id='$node_id' and log_id=$safe_id");

	if (! mysql_num_rows($query_result)) {
	    return 0;
	}

	echo "<table border=1 cellpadding=2 cellspacing=2 align='center'>\n";

	$row = mysql_fetch_array($query_result);
        $type       = $row["type"];
	$log_id     = $row["log_id"];
	$reporter   = $row["reporting_uid"];
	$date       = $row["reported"];
	$entry      = $row["entry"];

	echo "<tr>
                 <td>$date</td>
                 <td>$log_id</td>
                 <td>$type</td>
                 <td>$reporter</td>
                 <td>$entry</td>
               </tr>\n";
	echo "</table>\n";

	return 0;
    }

    #
    # Delete a node log entry.
    #
    function DeleteNodeLog($log_id) {
	$node_id = $this->node_id();
	$safe_id = addslashes($log_id);
	
	DBQueryFatal("delete from nodelog where ".
		     "node_id='$node_id' and log_id=$safe_id");

	return 0;
    }

    function sshurl($uid) {
	global $OURDOMAIN;
	$node_id = $this->node_id();

	if ($this->IsVirtNode()) {
	    $pnode_id = $this->phys_nodeid();
	    $sshdport = $this->sshdport();

	    return "ssh://${uid}@${pnode_id}.${OURDOMAIN}:$sshdport";
	}
	else {
	    return "ssh://${uid}@${node_id}.${OURDOMAIN}";
	}
    }
    #
    # Generate an authentication object to pass to the browser that
    # is passed to the web server on ops. This is used to grant
    # permission to the user to invoke tip to the console. 
    #
    function ConsoleAuthObject($uid, $console)
    {
        global $USERNODE, $WWWHOST;
        global $BROWSER_CONSOLE_PROXIED, $BROWSER_CONSOLE_WEBSSH;
        $node_id = $this->node_id();
	
        $file = "/usr/testbed/etc/sshauth.key";
    
        #
        # We need the secret that is shared with ops.
        #
        $fp = fopen($file, "r");
        if (! $fp) {
            TBERROR("Error opening $file", 1);
            return null;
        }
        $key = fread($fp, 128);
        fclose($fp);
        if (!$key) {
            TBERROR("Could not get key from $file", 1);
            return null;
        }
        $key   = chop($key);
        $stuff = GENHASH();
        $now   = time();
        if ($BROWSER_CONSOLE_PROXIED) {
            $baseurl = "https://${WWWHOST}";
        }
        else {
            $baseurl = "https://${USERNODE}";
        }
        if ($BROWSER_CONSOLE_WEBSSH) {
            # See httpd.conf
            $baseurl .= "/webssh";
        }
        $authobj = array('uid'       => $uid,
                         'console'   => $console,
                         'stuff'     => $stuff,
                         'nodeid'    => $node_id,
                         'timestamp' => $now,
                         'webssh'    => $BROWSER_CONSOLE_WEBSSH,
                         'baseurl'   => $baseurl,
                         'signature_method' => 'HMAC-SHA1',
                         'api_version' => '1.0',
                         'signature' => hash_hmac('sha1',
                                           $uid . $stuff . $node_id . $now .
                                           " " . implode(",", $console),
                                           $key),
        );
        return json_encode($authobj);
    }

    #
    # Get interface/switch related info for the node. 
    #
    function GetInterfaceInfo($iface = null)
    {
        $node_id = $this->node_id();
        $blob = array();

        if (!($this->role() == "testswitch" || $this->role() == "ctrlswitch")) {
            $clause = ($iface ? "and i.iface='$iface'" : "");
            
            $query_result =
                DBQueryFatal("select i.*,w.*,c.capval as protocols ".
                             "  from interfaces as i ".
                             "left join wires as w on ".
                             " (i.node_id=w.node_id1 and i.iface=w.iface1) or ".
                             " (i.node_id=w.node_id2 and i.iface=w.iface2) ".
                             "left join interface_capabilities as c on ".
                             "     i.interface_type=c.type and ".
                             "     c.capkey='protocols' ".
                             "where node_id='$node_id' $clause".
                             "order by i.iface");

            if (!mysql_num_rows($query_result)) {
                if ($iface) {
                    return null;
                }
                else {
                    return $blob;
                }
            }
            while ($row = mysql_fetch_array($query_result)) {
                $info = array();
        
                $info["node_id"]      = $node_id;
                $info["iface"]        = $row["iface"];
                $info["type"]         = $row["interface_type"];
                $info["role"]         = $row["role"];
                $info["mac"]          = $row["mac"];
                $info["IP"]           = $row["IP"];
                $info["protocols"]    = $row["protocols"];
                if ($node_id == $row["node_id1"]) {
                    $info["switch_id"]    = $row["node_id2"];
                    $info["switch_iface"] = $row["iface2"];
                    $info["switch_card"]  = $row["card2"];
                    $info["switch_port"]  = $row["port2"];
                }
                else {
                    $info["switch_id"]    = $row["node_id1"];
                    $info["switch_iface"] = $row["iface1"];
                    $info["switch_card"]  = $row["card1"];
                    $info["switch_port"]  = $row["port1"];
                }
                $info["wire_type"] = $row["type"];
                // Speed is in Mbs.
                $info["current_speed"] = $row["current_speed"];

                $info["switch_isswitch"] = false;
                if ($switch = Node::Lookup($info["switch_id"])) {
                    if ($switch->TypeClass() == "switch") {
                        $info["switch_isswitch"] = true;
                    }
                }
                $blob[] = $info;
            }
            if ($iface) {
                return $blob[0];
            }
            return $blob;
        }
        $query_result =
            DBQueryFatal("select distinct w.*,".
                         "       i1.role as irole1,i1.interface_type as itype1,".
                         "       i2.role as irole2,i2.interface_type as itype2,".
                         "       t1.isswitch as isswitch1,".
                         "       t2.isswitch as isswitch2 ".
                         "  from wires as w ".
                         "left join interfaces as i1 on ".
                         "     i1.node_id=w.node_id1 and i1.iface=w.iface1 ".
                         "left join interfaces as i2 on ".
                         "     i2.node_id=w.node_id2 and i2.iface=w.iface2 ".
                         "left join nodes as n1 on n1.node_id=w.node_id1 ".
                         "left join node_types as t1 on t1.type=n1.type ".
                         "left join nodes as n2 on n2.node_id=w.node_id2 ".
                         "left join node_types as t2 on t2.type=n2.type ".
                         "where w.node_id1='$node_id' or w.node_id2='$node_id' ".
                         "order by w.iface1");
    
        while ($row = mysql_fetch_array($query_result)) {
            $info = array();

            $info["wire_type"]     = $row["type"];
            $info["wire_length"]   = $row["len"];
            $info["wire_id"]       = $row["cable"];
        
            $info["node_id1"]      = $row["node_id1"];
            $info["iface1"]        = $row["iface1"];
            $info["type1"]         = $row["itype1"];
            $info["role1"]         = $row["irole1"];
            $info["card1"]         = $row["card1"];
            $info["port1"]         = $row["port1"];
            $info["isswitch1"]     = $row["isswitch1"] == 1 ? true : false;
        
            $info["node_id2"]      = $row["node_id2"];
            $info["iface2"]        = $row["iface2"];
            $info["type2"]         = $row["itype2"];
            $info["role2"]         = $row["irole2"];
            $info["card2"]         = $row["card2"];
            $info["port2"]         = $row["port2"];
            $info["isswitch2"]     = $row["isswitch2"] == 1 ? true : false;
            $blob[] = $info;
        }
        return $blob;
    }

    #
    # Get list of vlans this node is a member of.
    #
    function GetVlans()
    {
        $node_id = $this->node_id();
        $blob = array();

        if (!($this->role() == "testswitch" || $this->role() == "ctrlswitch")) {
            $query_result =
                DBQueryFatal("select * from vlans ".
                             "where members like '%${node_id}:%'".
                             "order by id");

            if (!mysql_num_rows($query_result)) {
                return null;
            }
            while ($row = mysql_fetch_array($query_result)) {
                $members = $row["members"];
        
                foreach (preg_split("/\s/", $members) as $member) {
                    list ($node,$iface) = preg_split('/:/', $member);
                    if ($node == $node_id) {
                        if (!array_key_exists($iface, $blob)) {
                            $blob[$iface] = array();
                        }
                        $blob[$iface][] = $row;
                    }
                }
            }
            return $blob;
        }
        return null;
    }

    #
    # List of Vnodes on a Pnode.
    #
    function GetVnodes()
    {
        $node_id = $this->node_id();
        $result  = array();
        
        $query_result =
            DBQueryFatal("select n.node_id,pid,eid,exptidx ".
                         " from nodes as n ".
                         "left join reserved as r on r.node_id=n.node_id ".
                         "where n.phys_nodeid='$node_id' and ".
                         "      n.node_id!=n.phys_nodeid");
        
        if (!mysql_num_rows($query_result)) {
            return null;
        }
        while($row = mysql_fetch_array($query_result)) {
            $blob = array();
            $blob["node_id"] = $row["node_id"];
            $blob["pid"]     = $row["pid"];
            $blob["eid"]     = $row["eid"];
            $result[] = $blob;
        }
        return $result;
    }

    #
    # List of virtual (vlan) interfaces on a pnode or vnode.
    #
    function GetVinterfaces()
    {
        $node_id = $this->node_id();
        $result  = array();

        if ($this->IsVirtNode()) {
            $query_result =
                DBQueryFatal("select v.*,vlans.tag as vlantag,vll.vname ".
                             "  from vinterfaces as v ".
                             "left join vlans on vlans.id=v.vlanid ".
                             "left join virt_lan_lans as vll on ".
                             "     vll.exptidx=v.exptidx and ".
                             "     vll.idx=v.virtlanidx ".
                             "where v.vnode_id='$node_id'");
        }
        else {
            $query_result =
                DBQueryFatal("select v.*,vlans.tag as vlantag,vll.vname ".
                             "  from vinterfaces as v ".
                             "left join vlans on vlans.id=v.vlanid ".
                             "left join virt_lan_lans as vll on ".
                             "     vll.exptidx=v.exptidx and ".
                             "     vll.idx=v.virtlanidx ".
                             "where v.node_id='$node_id' and ".
                             "      v.vnode_id is null");
        }
        if (!mysql_num_rows($query_result)) {
            return null;
        }
        while($row = mysql_fetch_array($query_result)) {
            $result[] = $row;
        }
        return $result;
    }

    #
    # Is there hardware info for the node.
    #
    function HasHardwareInfo()
    {
        $node_id = $this->node_id();

        $query_result =
            DBQueryFatal("select updated from node_hardware ".
                         "where node_id='$node_id'");
        
        return mysql_num_rows($query_result);
    }
}

#
# Show history.
#
function ShowNodeHistory($node_id = null, $record = null,
			 $count = 200, $showall = 0, $reverse = 0,
			 $date = null, $IP = null, $mac = null,
			 $node_opt = "", $asdata = false) {
    global $TBSUEXEC_PATH;
    global $PROTOGENI;
    $shownodeid = $node_id ? false : true;
    $atime = 0;
    $ftime = 0;
    $rtime = 0;
    $dtime = 0;
    $nodestr = "";
    $arg = "";
    $opt = "-ls -n " . escapeshellarg($count);
    if (!$showall) {
	$opt .= " -a";
    }
    if ($reverse) {
	$opt .= " -r";
    }
    if ($date) {
        if (! is_int($date)) {
            $date = date("Y-m-d H:i:s", strtotime($date));
        }
	$opt .= " -d " . escapeshellarg($date);
    }
    elseif ($record) {
	$opt .= " -x " . escapeshellarg($record);
    }
    if ($node_id || $IP || $mac) {
	if ($IP) {
	    $opt .= " -i " . escapeshellarg($IP);
	    $nodestr = "<th>Node</th>";
	}
	if ($mac) {
	    $opt .= " -m " . escapeshellarg($mac);
	    $nodestr = "<th>Node</th>";
	}
	else {
	    $arg = escapeshellarg($node_id);
	}
    }
    else {
	$opt .= " -A";
	$nodestr = "<th>Node</th>";
	#
	# When supplying a date, we want a summary of all nodes at that
	# point in time, not a listing. 
	#
	if ($date) {
	    $opt .= " -c";
	}
    }
    if ($fp = popen("$TBSUEXEC_PATH nobody nobody ".
		    "  webnode_history $opt $arg", "r")) {
        if (!$asdata) {
            if (!$showall) {
                $str = "Allocation";
            } else {
                $str = "";
            }
            if (!$node_id) {
                echo "<center><b>
                  $str History for All Nodes.
                  </b></center>\n";
            } else {
                $node_url = CreateURL("shownode", URLARG_NODEID, $node_id);
                echo "<center><b>
                  $str History for Node <a href='$node_url'>$node_id</a>.
                  </b></center>\n";
            }
        }

	# Keep track of history record bounds, for paging through.
	$max_history_id = 0;
	$min_history_id = 1000000000;

	# Build up table contents
        if ($asdata) {
            $data_results = array();
        }
        else {
            ob_start();
        }

	$line = fgets($fp);
	while (!feof($fp)) {
            if ($asdata) {
                $blob = array();                
            }
	    #
	    # Formats:
	    # nodeid REC tstamp duration uid pid eid
	    # nodeid SUM alloctime freetime reloadtime downtime
	    #
	    $results = preg_split("/[\s]+/", $line, 9, PREG_SPLIT_NO_EMPTY);
	    $node_id = $results[0];
	    $type = $results[1];
	    if ($type == "SUM") {
		# Save summary info for later
		$atime = $results[2];
		$ftime = $results[3];
		$rtime = $results[4];
		$dtime = $results[5];
	    } elseif ($type == "REC") {
		$stamp = intval($results[2]);
		$datestr = date("Y-m-d H:i:s", $stamp);
		$duration = $tmp = $results[3];
		$durstr = "";
		if ($tmp >= (24*60*60)) {
		    $durstr = sprintf("%dd", $tmp / (24*60*60));
		    $tmp %= (24*60*60);
		}
		if ($tmp >= (60*60)) {
		    $durstr = sprintf("%s%dh", $durstr, $tmp / (60*60));
		    $tmp %= (60*60);
		}
		if ($tmp >= 60) {
		    $durstr = sprintf("%s%dm", $durstr, $tmp / 60);
		    $tmp %= 60;
		}
		$uid = $results[4];
		$pid = $results[5];
		$thisid = intval($results[8]);
		if ($thisid > $max_history_id) {
		    $max_history_id = $thisid;
		}
		if ($thisid < $min_history_id) {
		    $min_history_id = $thisid;
		}
                if ($asdata) {
                    $blob["history_id"] = $thisid;
                    $blob["node_id"]    = $node_id;
                }
		$slice = "--";
		$expurl = null;
		if ($pid == "<FREE>") {
                    if ($asdata) {
                        $blob["pid"] = null;
                        $blob["eid"] = null;
                        $blob["uid"] = null;
                    }
                    else {
                        $pid = "--";
                        $eid = "--";
                        $uid = "--";
                    }
		} else {
		    $eid = $results[6];
		    if ($results[7]) {
			$experiment = Experiment::Lookup($results[7]);
			$experiment_stats = ExperimentStats::Lookup($results[7]);
                        if ($asdata) {
                            $blob["pid"]     = $pid;
                            $blob["pid_idx"] = $experiment_stats->pid_idx();
                            $blob["eid"]     = $eid;
                            $blob["eid_idx"] = $results[7];
                            $blob["uid"]     = $uid;
                            if ($experiment_stats->slice_uuid()) {
                                $blob["slice_uuid"] =
                                    $experiment_stats->slice_uuid();
                            }
                            $blob["isrunning"] = ($experiment ? true : false);
                        }
                        else {
                            if ($experiment_stats &&
                                $experiment_stats->slice_uuid()) {
                                $url = CreateURL("genihistory",
                                                 "slice_uuid",
                                                 $experiment_stats->slice_uuid());
                                $slice = "<a href='$url'>" .
                                    "<img src=\"greenball.gif\" border=0></a>";
                            }
                            if ($experiment) {
                                $expurl = CreateURL("showexp",
						URLARG_EID, $experiment->idx());
                            }
                            else {
                                $expurl = CreateURL("showexpstats",
                                                    "record",
                                                    $experiment_stats->exptidx());
                            }
                        }
                    }
		}
                if ($asdata) {
                    $blob["allocated"] = gmdate("Y-m-d\TH:i:s\Z", $stamp);
                    $blob["released"]  = gmdate("Y-m-d\TH:i:s\Z",
                                                $stamp + intval($duration));
                    $blob["duration"]  = intval($duration);
                    $blob["duration_string"] = $durstr;
                }
                else {
                    if ($shownodeid) {
                        $nodeurl = CreateURL("shownodehistory",
                                             URLARG_NODEID, $nodeid);
                        echo "<tr>
                          <td><a href='$nodeurl'>$nodeid</a></td>
                          <td>$pid</td>";
                        if ($expurl) {
                            echo "<td><a href='$expurl'>$eid</a></td>";
                        }
                        else {
                            echo "<td>$eid</td>";
                        }
                        if ($PROTOGENI) {
                            echo "<td>$slice</td>";
                        }
                        echo "<td>$uid</td>
                          <td>$datestr</td>
                          <td>$durstr</td>
                          </tr>\n";
                    } else {
                        echo "<tr>
                          <td>$pid</td>";
                        if ($expurl) {
                            echo "<td><a href='$expurl'>$eid</a></td>";
                        }
                        else {
                            echo "<td>$eid</td>";
                        }
                        if ($PROTOGENI) {
                            echo "<td>$slice</td>";
                        }
                        echo "<td>$uid</td>
                          <td>$datestr</td>
                          <td>$durstr</td>
                          </tr>\n";
                    }
                }
                if ($asdata) {
                    $data_results[] = $blob;
                }
	    }
	    $line = fgets($fp, 1024);
	}
	pclose($fp);
        if ($asdata) {
            return array("min"     => $min_history_id,
                         "max"     => $max_history_id,
                         "entries" => $data_results);
        }
	$table_html = ob_get_contents();
	ob_end_clean();
	
	$hid = $max_history_id;
	if ($reverse) {
	    $hid = $min_history_id;
	}
	echo "<center><a href='shownodehistory.php3?record=$hid".
	    "&reverse=$reverse&count=$count&$node_opt'>Next $count records</a></center>\n";
	echo "<table border=1 cellpadding=2 cellspacing=2 align='center'>\n";
	echo "<tr>
	       $nodestr
               <th>Pid</th>
               <th>Eid</th>";
	if ($PROTOGENI) {
	    echo "<th>Slice</th>";
	}
        echo " <th>Allocated By</th>
               <th>Allocation Date</th>
	       <th>Duration</th>
              </tr>\n";

	echo $table_html;

	echo "</table>\n";
	echo "<center><a href='shownodehistory.php3?record=$hid".
	    "&reverse=$reverse&count=$count&$node_opt'>Next $count records</a></center>\n";

	$ttime = $atime + $ftime + $rtime + $dtime;
	if ($ttime) {
	    echo "<br>
                  <center><b>
                  Usage Summary
                  </b></center><br>\n";

	    echo "<table border=1 align=center>\n";

	    $str = "Allocated";
	    $pct = sprintf("%5.1f", $atime * 100.0 / $ttime);
	    echo "<tr><td>$str</td><td>$pct%</td></tr>\n";

	    $str = "Free";
	    $pct = sprintf("%5.1f", $ftime * 100.0 / $ttime);
	    echo "<tr><td>$str</td><td>$pct%</td></tr>\n";

	    $str = "Reloading";
	    $pct = sprintf("%5.1f", $rtime * 100.0 / $ttime);
	    echo "<tr><td>$str</td><td>$pct%</td></tr>\n";

	    $str = "Down";
	    $pct = sprintf("%5.1f", $dtime * 100.0 / $ttime);
	    echo "<tr><td>$str</td><td>$pct%</td></tr>\n";

	    echo "</table>\n";
	}
    }
}

#
# Logged in users, show free node counts.
#
function ShowFreeNodes($user, $group)
{
    $freecounts = array();
    $perms      = array();
    $pid_idx    = $group->pid_idx();
    $pid        = $group->pid();
    $uid_idx    = $user->uid_idx();

    # Get typelist and set freecounts to zero.
    $query_result =
	DBQueryFatal("select n.type from nodes as n ".
		     "left join node_types as nt on n.type=nt.type ".
                     "left join node_type_attributes as attr on ".
                     "     attr.type=n.type and ".
                     "     attr.attrkey='noshowfreenodes' ".
		     "where (role='testnode') and class='pc' and ".
                     "      attr.attrvalue is null");
    while ($row = mysql_fetch_array($query_result)) {
	$type              = $row[0];
	$freecounts[$type] = 0;
        $perms[$type]      = 1;
    }

    if (!count($freecounts)) {
	return "";
    }

    # Get free totals by type.
    $query_result =
	DBQueryFatal("select n.eventstate,n.type,count(*) from nodes as n ".
		     "left join node_types as nt on n.type=nt.type ".
		     "left join reserved as r on r.node_id=n.node_id ".
                     "left join node_type_attributes as attr on ".
                     "     attr.type=n.type and ".
                     "     attr.attrkey='noshowfreenodes' ".
		     "where (role='testnode') and class='pc' and ".
		     "      r.pid is null and ".
                     "      attr.attrvalue is null and ".
		     "      (n.reserved_pid is null or ".
		     "       n.reserved_pid='$pid') ".
		     "group BY n.eventstate,n.type");

    while ($row = mysql_fetch_array($query_result)) {
	$type  = $row[1];
	$count = $row[2];
        # XXX Yeah, I'm a doofus and can't figure out how to do this in SQL.
	if (($row[0] == TBDB_NODESTATE_ISUP) ||
	    ($row[0] == TBDB_NODESTATE_PXEWAIT) ||
	    ($row[0] == TBDB_NODESTATE_ALWAYSUP) ||
	    ($row[0] == TBDB_NODESTATE_POWEROFF)) {

            $policy_result =
                DBQueryFatal("select max(count) from group_policies as p ".
                             "where p.policy='type' and p.auxdata='$type' and ".
                             "      (p.pid='-' or p.pid='$pid')");
        
            if (mysql_num_rows($policy_result)) {
                $row = mysql_fetch_row($policy_result);
                if ($count > $row[0]) {
                    $count = $row[0];
                }
            }
	    $freecounts[$type] = $count;
	}
    }
    $output = "";

    #
    # Figure out how many node types are going to be printed out. These
    # are the nodes to which the user has access, no matter the count.
    #
    $pccount = 0;
    foreach($freecounts as $key => $value) {
	if ($perms[$key]) {
	    $pccount++;
	}
    }

    $freepcs   = TBFreePCs($group);
    $reloading = TBReloadingPCs();

    $output .= "<table valign=top align=center width=100% height=100% border=1
		 cellspacing=1 cellpadding=0>
                 <tr><td nowrap colspan=6 class=usagefreenodes align=center>
 	           <b>$freepcs Free PCs, $reloading reloading</b></td></tr>\n";

    $newrow  = 1;
    $maxcols = (int) ($pccount / 3);
    if ($pccount % 3)
	$maxcols++;
    $cols    = 0;
    foreach($freecounts as $key => $value) {
	$freecount = $freecounts[$key];
	if (!$perms[$key]) {
	    continue;
	}
	if ($newrow) {
	    $output .= "<tr>\n";
	}
	
	$output .= "<td class=usagefreenodes align=right>
                     <a target=_parent href=shownodetype.php3?node_type=$key>
                        $key</a></td>
                    <td class=usagefreenodes align=left>${freecount}</td>\n";

	$cols++;
	$newrow = 0;
	if ($cols == $maxcols || $pccount <= 3) {
	    $cols   = 0;
	    $newrow = 1;
	}

	if ($newrow) {
	    $output .= "</tr>\n";
	}
    }
    if (! $newrow) {
        # Fill out to $maxcols
	for ($i = $cols + 1; $i <= $maxcols; $i++) {
	    $output .= "<td class=usagefreenodes>&nbsp</td>";
	    $output .= "<td class=usagefreenodes>&nbsp</td>";
	}
	$output .= "</tr>\n";
    }
    # Fill in up to 3 rows.
    if ($pccount < 3) {
	for ($i = $pccount + 1; $i <= 3; $i++) {
	    $output .= "<tr><td class=usagefreenodes>&nbsp</td>
                            <td class=usagefreenodes>&nbsp</td></tr>\n";
	}
    }

    $output .= "</table>";
    return $output;
}
?>
