# -*- tcl -*-
#
# Copyright (c) 2000-2017 University of Utah and the Flux Group.
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

######################################################################
# node.tcl
#
# This defines the Node class.  Instances of this class are created by
# the 'node' method of Simulator.  A Node is connected to a number of
# LanLinks.  Each such connection is associated with a virtual port,
# an integer.  Each virtual port also has an IP address.  Virtual
# ports start at 0 and go up continuously.  Besides the port
# information each node also has a variety of strings.  These strings
# are set by tb-* commands and dumped to the DB but are otherwise
# uninterpreted.
######################################################################

Class Node -superclass NSObject
Class Bridge -superclass Node

Node instproc init {s} {
    $self set sim $s

    # portlist is a list of connections for the node.  It is sorted
    # by portnumber.  I.e. the ith element of portlist is the connection
    # on port i.
    $self set portlist {}

    # A list of agents attached to this node.
    $self set agentlist {}

    # A counter for udp/tcp portnumbers. Assign them in an increasing
    # fashion as agents are assigned to the node.
    $self set next_portnumber_ 5000

    # iplist, like portlist, is supported by portnumber.  An entry of
    # {} indicates an unassigned IP address for that port.
    $self set iplist {}

    # ipaliaslist will contain a list of lists.  Each list contains the
    # IP aliases for that particular port.  The second list contains
    # the number of IP aliases requested for that port (for automatic
    # assignment).
    $self set ipaliaslist {}
    $self set wantipaliaslist {}

    # A route list. 
    $self instvar routelist
    array set routelist {}

    # The type of the node.
    $self set type "pc" 

    # Is remote flag. Used when we do IP assignment later.
    $self set isremote 0

    # Sorta ditto for virt.
    $self set isvirt 0

    # If hosting a virtual node (or nodes).
    $self set virthost 0

    # Sorta ditto for subnode stuff.
    $self set issubnode    0
    $self set subnodehost  0
    $self set subnodechild ""

    # If osid remains blank when updatedb is called it is changed
    # to the default OS based on it's type (taken from node_types
    # table).
    $self set osid ""

    # And an alternate load list.
    $self set loadlist ""

    # We have this for a bad, bad reason.  We can't expose $vhost variables
    # in ns files because assign can't yet handle fixing vnodes to vhosts (or
    # any other mapping constraints, since that would imply multiple levels 
    # of mapping)... so when you set the parent_osid for vnodes, you are 
    # setting the os for the vhost itself; the osid is the os for the vnode.
    #
    # If the osid gets set to a subosid, we set parent_osid to the default
    # parent_osid for that osid in updatedb.
    $self set parent_osid ""

    # Start with an empty set of desires
    $self instvar desirelist
    array set desirelist {}

    # If this is a bridge, list of the link members that connect to it.
    $self set bridgelist {}
    $self set isbridgenode 0

    # These are just various strings that we pass through to the DB.
    $self set cmdline ""
    $self set rpms ""
    $self set startup ""
    $self set tarfiles ""
    $self set failureaction "fatal"
    $self set inner_elab_role ""
    $self set plab_role "none"
    $self set plab_plcnet "none"
    $self set fixed ""
    $self set nseconfig ""
    $self set sharing_mode ""
    $self set role ""

    # Arbitrary key/value pairs to pass through to physical nodes.
    $self instvar attributes
    array set attributes {}

    $self set topo ""

    $self set X_ ""
    $self set Y_ ""
    $self set Z_ 0.0
    $self set orientation_ 0.0

    set cname "${self}-console"
    Console $cname $s $self
    $s add_console $cname
    $self set console_ $cname

    if { ${::GLOBALS::simulated} == 1 } {
	$self set simulated 1
    } else {
	$self set simulated 0
    }
    $self set nsenode_vportlist {}

    # This is a mote thing.
    $self set numeric_id {}

    # This is a blockstore thing.
    $self set bstore_agent 0

    # Per node firewall thing.
    $self set fw_style ""
    $self set next_rule 100
    $self instvar fw_rules
    array set fw_rules {}

    # Distribution of per-experiment root keypair
    $self set rootkey_private -1
    $self set rootkey_public -1
}

Bridge instproc init {s} {
    $self next $s
    $self instvar role
    $self instvar isbridgenode

    set role "bridge"
    set isbridgenode 1
}

# The following procs support renaming (see README)
Node instproc rename {old new} {
    $self instvar portlist
    $self instvar console_

    foreach object $portlist {
	$object rename_node $old $new
    }
    [$self set sim] rename_node $old $new
    $console_ set node $new
    $console_ rename "${old}-console" "${new}-console"
    uplevel "#0" rename "${old}-console" "${new}-console"
    set console_ ${new}-console
}

Node instproc rename_lanlink {old new} {
    $self instvar portlist
    $self instvar bridgelist
    
    set newportlist {}
    foreach node $portlist {
	if {$node == $old} {
	    lappend newportlist $new
	} else {
	    lappend newportlist $node
	}
    }
    set portlist $newportlist

    set newbridgelist {}
    foreach link $bridgelist {
	if {$link == $old} {
	    lappend newbridgelist $new
	} else {
	    lappend newbridgelist $link
	}
    }
    set bridgelist $newbridgelist
}

# updatedb DB
# This adds a row to the virt_nodes table corresponding to this node.
Node instproc updatedb {DB} {
    $self instvar portlist
    $self instvar type
    $self instvar osid
    $self instvar parent_osid
    $self instvar loadlist
    $self instvar cmdline
    $self instvar rpms
    $self instvar startup
    $self instvar iplist
    $self instvar tarfiles
    $self instvar failureaction
    $self instvar inner_elab_role
    $self instvar plab_role
    $self instvar role
    $self instvar plab_plcnet
    $self instvar routertype
    $self instvar fixed
    $self instvar agentlist
    $self instvar routelist
    $self instvar sim
    $self instvar isvirt
    $self instvar virthost
    $self instvar issubnode
    $self instvar desirelist
    $self instvar attributes
    $self instvar nseconfig
    $self instvar simulated
    $self instvar sharing_mode
    $self instvar topo
    $self instvar fw_style
    $self instvar fw_rules
    $self instvar rootkey_private
    $self instvar rootkey_public
    $self instvar X_
    $self instvar Y_
    $self instvar orientation_
    $self instvar numeric_id
    var_import ::TBCOMPAT::default_osids
    var_import ::TBCOMPAT::subosids
    var_import ::GLOBALS::use_physnaming
    var_import ::TBCOMPAT::physnodes
    var_import ::TBCOMPAT::objtypes
    var_import ::GLOBALS::pid
    var_import ::GLOBALS::eid
    var_import ::GLOBALS::default_ip_routing_type
    var_import ::GLOBALS::enforce_user_restrictions
    var_import ::TBCOMPAT::hwtype_class

    #
    # Reserved name; conflicts with kludgy manner in which a program
    # agent can used on ops.
    #
    if {"$self" == "ops"} {
	perror "You may not use the name for 'ops' for a node!"
	return
    }
    
    # If we haven't specified a osid so far then we should fill it
    # with the id from the node_types table now.
    if {$osid == {}} {
	if {$virthost == 0 && $role != "bridge" } {
	    if {[info exists default_osids($type)]} {
		set osid $default_osids($type)
	    }
	}
    } else {
	# Do not allow user to set os for virt nodes at this time.
	#if {$enforce_user_restrictions && $isvirt} {
	#    perror "You may not specify an OS for virtual nodes ($self)!"
	#    return
	#}
	# Do not allow user to set os for host running virt nodes.
	if {$enforce_user_restrictions && $virthost} {
	    perror "You may not specify an OS for hosting virtnodes ($self)!"
	    return
	}
    }

    #
    # If the osid is a subosid and there is no parent, choose the default
    # one now.
    # XXX don't do this for now -- an OS can be both a subOS and a regular OS
    # (i.e., windows), and we don't want to imply to Emulab that there should
    # be a subOS if the user doesn't force it.
    #
    #if {[info exists $subosids($osid)] && $parent_osid == ""} {
    #    set parent_osid [lindex $subosids($osid) 0]
    #}

    #
    # If the osid won't run on the specified parent, die.
    #
    if {$parent_osid != "" && $osid != ""} {
	# Look for :version in the names.
	set os $osid
        if { [regexp {:} $osid] } {
	    set os [lindex [split $osid {:}] 0]
	}
	set pos $parent_osid
        if { [regexp {:} $parent_osid] } {
	    set pos [lindex [split $parent_osid {:}] 0]
	}
	if {![info exists subosids($os)] ||
	    [lsearch -exact $subosids($os) $pos] == -1} {
	    perror "subOSID $osid does not run on parent OSID $parent_osid!"
	    return
	}
    }

    #
    # If a subnode, then it must be fixed to a pnode, or we have to
    # create one on the fly and set the type properly. 
    # 
    if {$issubnode && $fixed == ""} {
        # XXX - hack for motes, to make Jay happy
        set hosttype "pc"
        if {$type == "mica2" || $type == "mica"} {
            set hosttype "mote-host"
        }
	$sim spitxml_data "virt_nodes" [list "vname" "type" "ips" "osname" "cmd_line" "rpms" "startupcmd" "tarfiles" "fixed" ] [list "host-$self" "$hosttype" "" "" "" "" "" "" "" ]
	$sim spitxml_data "virt_node_desires" [list "vname" "desire" "weight"] [list "host-$self" "hosts-$type" 1.0]
	set fixed "host-$self"
    }

    # Implicitly fix node if not already fixed.
    if { $issubnode == 0 && $use_physnaming == 1 && $fixed == "" } {
	if {[info exists physnodes($self)]} {
		set fixed $self
	}
    }

    # We need to generate the IP column from our iplist.
    set ipraw {}
    set i 0
    foreach ip $iplist {
	if { $ip == {} } {
	    # Give a dummy IP address if none has been set
	    set ip "0.0.0.0"
	}
	lappend ipraw $i:$ip
	incr i
    }

    foreach agent $agentlist {
	$agent updatedb $DB

	if {[$agent set application] != {}} {
	    $sim agentinit [$agent set application]
	}

	# The following is for NSE traffic generation
	# Simulated nodes in make-simulated should not be doing this
	if { $simulated != 1 } { 
	    append nseconfig [$agent get_nseconfig]
	}
    }

     if {$nseconfig != {}} {

       set nsecfg_script ""
       set simu [lindex [Simulator info instances] 0]
       append nsecfg_script "set $simu \[new Simulator]\n"
       append nsecfg_script "\$$simu set tbname \{$simu\}\n"
       append nsecfg_script "\$$simu use-scheduler RealTime\n\n"
       append nseconfig "set nsetrafgen_present 1\n\n"
       append nsecfg_script $nseconfig

        # update the per-node nseconfigs table in the DB
	$sim spitxml_data "nseconfigs" [list "vname" "nseconfig"] [list "$self" "$nsecfg_script"]
    }

    $self add_routes_to_DB $DB

    # Update the DB
    set fields [list "vname" "type" "ips" "osname" "cmd_line" "rpms" "startupcmd" "tarfiles" "failureaction" "routertype" "fixed" ]
    set values [list $self $type $ipraw $osid $cmdline $rpms $startup $tarfiles $failureaction $default_ip_routing_type $fixed ]

    if { $inner_elab_role != "" } {
	lappend fields "inner_elab_role"
	lappend values $inner_elab_role
    }

    if { $role != "" } {
	lappend fields "role"
	lappend values $role
    }

    if { $plab_role != "none" } {
	lappend fields "plab_role"
	lappend values $plab_role
    }

    if { $plab_plcnet != "" } {
	lappend fields "plab_plcnet"
	lappend values $plab_plcnet
    }

    if { $sharing_mode != "" } {
	lappend fields "sharing_mode"
	lappend values $sharing_mode
    }

    if { $loadlist != "" } {
	lappend fields "loadlist"
	lappend values $loadlist
    }

    if { $numeric_id != {} } {
	lappend fields "numeric_id"
	lappend values $numeric_id
    }

    if { $parent_osid != {} && $parent_osid != 0} {
	lappend fields "parent_osname"
	lappend values $parent_osid
    }

    if { $fw_style != "" } {
	lappend fields "firewall_style"
	lappend values $fw_style
    }

    lappend fields "rootkey_private"
    lappend values $rootkey_private
    lappend fields "rootkey_public"
    lappend values $rootkey_public
    
    $sim spitxml_data "virt_nodes" $fields $values

    if {$topo != "" && ($type == "robot" || $hwtype_class($type) == "robot")} {
	if {$X_ == "" || $Y_ == ""} {
	    perror "node \"$self\" has no initial position"
	    return
	}

	if {! [$topo checkdest $self $X_ $Y_ -showerror 1]} {
	    return
	}

	$sim spitxml_data "virt_node_startloc" \
		[list "vname" "building" "floor" "loc_x" "loc_y" "orientation"] \
		[list $self [$topo set area_name] "" $X_ $Y_ $orientation_]
    }
    
    # Put in the desires, too
    foreach desire [lsort [array names desirelist]] {
	set weight $desirelist($desire)
	$sim spitxml_data "virt_node_desires" [list "vname" "desire" "weight"] [list $self $desire $weight]
    }

    # Put in the attributes, too
    foreach key [lsort [array names attributes]] {
	set val $attributes($key)
	$sim spitxml_data "virt_node_attributes" [list "vname" "attrkey" "attrvalue"] [list $self $key $val]
    }

    set agentname "$self"
    if { $role == "bridge" } {
	# XXX Gack. We cannot have two virt_agents with the same name
	# and there will be a network agent by this name. I do not have
	# a solution yet, so just bypass for now.
	set agentname "_${self}"
    }
    
    $sim spitxml_data "virt_agents" [list "vnode" "vname" "objecttype"] [list $self $agentname $objtypes(NODE)]

    foreach rule [array names fw_rules] {
	set names [list "fwname" "ruleno" "rule"]
	set vals  [list $self $rule $fw_rules($rule)]
	$sim spitxml_data "firewall_rules" $names $vals
    }
    
}

# add_lanlink lanlink
# This creates a new virtual port and connects the specified LanLink to it.
# The port number is returned.
Node instproc add_lanlink {lanlink} {
    $self instvar portlist
    $self instvar iplist
    $self instvar ipaliaslist
    $self instvar wantipaliaslist
    $self instvar simulated

    # Check if we're making too many lanlinks to this node
    # XXX Could come from db from node_types if necessary
    # For now, no more than 4 links or interfaces per node
    # XXX Ignore if the lanlink is simulated i.e. one that
    # has all simulated nodes in it. 
#    set maxlanlinks 4
#    if { [$lanlink set simulated] != 1 && $maxlanlinks == [llength $portlist] } {
#	# adding this one would put us over
#	perror "Too many links/LANs to node $self! Maximum is $maxlanlinks."
#    }

    lappend portlist $lanlink
    lappend iplist ""
    lappend ipaliaslist ""
    lappend wantipaliaslist ""
    return [expr [llength $portlist] - 1]
}

#
# Find the lan that both nodes are attached to. Very bad. If more than
# comman lan, returns the first.
#
Node instproc find_commonlan {node} {
    $self instvar portlist
    set match -1

    foreach ll $portlist {
	set match [$node find_port $ll]
	if {$match != -1} {
	    return $ll
	}
    }
    return {}
}

# ip port
# ip port ip
# In the first form this returns the IP address associated with the port.
# In the second from this sets the IP address of a port.
Node instproc ip {port args} {
    $self instvar iplist
    $self instvar sim
    if {$args == {}} {
	return [lindex $iplist $port]
    } else {
	set ip [lindex $args 0]
	set iplist [lreplace $iplist $port $port $ip]
    }    
}

# Add an ip alias for a port (append as list)
Node instproc add_ipalias_port {port ipaddr} {
    $self instvar ipaliaslist
    set curlist [lindex $ipaliaslist $port]
    lappend curlist $ipaddr
    set ipaliaslist [lreplace $ipaliaslist $port $port $curlist]
}

# Append ip alias given a lanlink
Node instproc add_ipalias {lan ipaddr} {
    set targetport [$self find_port $lan]
    if {$targetport == -1} {
	perror "$self does not belong to link/lan: $lan"
    }
    $self add_ipalias_port $targetport $ipaddr
}

# Get the alias list for a port
Node instproc get_ipaliases_port {port} {
    $self instvar ipaliaslist
    return [lindex $ipaliaslist $port]
}

# Get the alias list for a node on a given lan/link
Node instproc get_ipaliases {lan} {
    $self instvar ipaliaslist
    set targetport [$self find_port $lan]
    if {$targetport == -1} {
	perror "$self does not belong to link/lan: $lan"
    }
    return [$self get_ipaliases_port $targetport]
}

# Mark down the number of IP aliases wanted on a particular port
Node instproc want_ipaliases_port {port count} {
    $self instvar wantipaliaslist
    set wantipaliaslist [lreplace $wantipaliaslist $port $port $count]
}

# Mark that aliases are wanted on a given lanlink
Node instproc want_ipaliases {lan count} {
    set targetport [$self find_port $lan]
    if {$targetport == -1} {
	perror "$self does not belong to link/lan: $lan"
    }
    $self want_ipaliases_port $targetport $count
}

# Return the number of ip aliases desired for a given port
Node instproc get_wanted_ipaliases_port {port} {
    $self instvar wantipaliaslist
    set wanted 0
    if {[lindex $wantipaliaslist $port] != {}} {
	set wanted [lindex $wantipaliaslist $port]
    }
    return $wanted
}

# Return the number of ip aliases desired for a node on a given lan
Node instproc get_wanted_ipaliases {lan} {
    set targetport [$self find_port $lan]
    if {$targetport == -1} {
	perror "$self does not belong to link/lan: $lan"
    }
    return [$self get_wanted_ipaliases_port $targetport]
}

# find_port lanlink
# This takes a lanlink and returns the port it is connected to or 
# -1 if there is no connection.
Node instproc find_port {lanlink} {
    return [lsearch [$self set portlist] $lanlink]
}

# Attach an agent to a node. This mainly a bookkeeping device so
# that the we can update the DB at the end.
Node instproc attach-agent {agent} {
    $self instvar agentlist

    lappend agentlist $agent
    $agent set_node $self
}

#
# Return and bump next agent portnumber,
Node instproc next_portnumber {} {
    $self instvar next_portnumber_
    
    set next_port [incr next_portnumber_]
    return $next_port
}

#
# Add a route.
# The nexthop to <dst> from this node is <target>.
#
Node instproc add-route {dst nexthop} {
    $self instvar routelist

    if {[info exists routelist($dst)]} {
	perror "\[add-route] route from $self to $dst already exists!"
    }
    set routelist($dst) $nexthop
}

#
# Set the type/isremote/isvirt for a node. Called from tb_compat.
#
Node instproc set_hwtype {hwtype isrem isv issub} {
    $self instvar type
    $self instvar isremote
    $self instvar isvirt
    $self instvar issubnode

    set type $hwtype
    set isremote $isrem
    set isvirt $isv
    set issubnode $issub
}

#
# Fix a node. Watch for fixing a node to another node.
#
Node instproc set_fixed {pnode} {
    var_import ::TBCOMPAT::location_info
    var_import ::TBCOMPAT::physnodes
    $self instvar type
    $self instvar topo
    $self instvar fixed
    $self instvar issubnode
    $self instvar isvirt

    if { [Node info instances $pnode] != {} } {
        # $pnode is an object instance of class Node
	if {$issubnode} {
	    $pnode set subnodehost 1
	    $pnode set subnodechild $self
	} elseif ($isvirt) {
	    # Need to check anything?
	} else {
	    perror "\[set-fixed] Improper fix-node $self to $pnode!"
	    return
	}
    }
    set fixed $pnode

    if {$isvirt == 0 && [info exists physnodes($pnode)]} {
	set type $physnodes($pnode)
	
	if {$topo != ""} {
	    set building [$topo set area_name]
	    if {$building != {} && 
	    [info exists location_info($fixed,$building,x)]} {
		$self set X_ $location_info($fixed,$building,x)
		$self set Y_ $location_info($fixed,$building,y)
		$self set Z_ $location_info($fixed,$building,z)
	    }
	}
    }
}

#
# Update DB with routes
#
Node instproc add_routes_to_DB {DB} {
    var_import ::GLOBALS::pid
    var_import ::GLOBALS::eid
    $self instvar routelist
    $self instvar sim

    foreach dst [lsort [array names routelist]] {
	set hop $routelist($dst)
	set port -1

	#
	# Convert hop to IP address. Need to find the link between the
	# this node and the hop. This is easy if its a link. If its
	# a lan, then its ugly.
	#
	set hoplink [$sim find_link $self $hop]
	if {$hoplink == {}} {
	    set hoplan [$self find_commonlan $hop]
	    set port [$hop find_port $hoplan]
	    set srcip [$self ip [$self find_port $hoplan]]
	} else {
	    set port [$hop find_port $hoplink]
	    set srcip [$self ip [$self find_port $hoplink]]
	}
	if {$port == -1} {
	    perror "\[add-route] Cannot find a link from $self to $hop!"
	    return
	}
	set hopip [$hop ip $port]
	
	#
	# Convert dst to IP address.
	#
	switch -- [$dst info class] {
	    "Node" {
		if {[llength [$dst set portlist]] != 1} {
		    perror "\[add-route] $dst must have only one link."
		}
		set link  [lindex [$dst set portlist] 0]
		set mask  [$link get_netmask]
		set dstip [$dst ip 0]
		set type  "host"
	    }
	    "SimplexLink" {
		set link  [$dst set mylink]
		set mask  [$link get_netmask]
		set src   [$link set src_node]
		set dstip [$src ip [$src find_port $link]]
		set type  "net"
	    }
	    "Link" {
		set dstip [$dst get_subnet]
		set mask  [$dst get_netmask]
		set type  "net"
	    }
	    "Lan" {
		set dstip [$dst get_subnet]
		set mask  [$dst get_netmask]
		set type  "net"
	    }
	    unknown {
		perror "\[add-route] Bad argument. Must be a node or a link."
		return
	    }
	}
	$sim spitxml_data "virt_routes" [list "vname" "src" "dst" "nexthop" "dst_type" "dst_mask"] [list $self $srcip $dstip $hopip $type $mask]
    }
}

#
# Create a program object to run on the node when the experiment starts.
#
Node instproc start-command {command} {
    $self instvar sim
    set newname "${self}_startcmd"

    set newprog [uplevel 2 "set $newname [new Program $sim]"]
    $newprog set node $self
    $newprog set command $command

    # Starts at time 0
    $sim at 0  "$newprog start"

    return $newprog
}

#
# Add a desire to the node, with the given weight
# Fails if the desire already exists unless the override parameter is
# set.
#
Node instproc add-desire {desire weight {override 0}} {
    $self instvar desirelist
    if {[info exists desirelist($desire)] && !$override} {
	perror "\[add-desire] Desire $desire on $self already exists!"
    }
    set desirelist($desire) $weight
}

#
# Grab a desire that was already set.  return empty string if it is not set.
#
Node instproc get-desire {desire} {
    $self instvar desirelist

    # desire exists.
    if {[info exists desirelist($desire)]} {
	return [set desirelist($desire)]
    }

    # desire does not exist.
    return {}
}

#
# Add a key/value pair to the node.
#
Node instproc add-attribute {key val} {
    $self instvar attributes
    set attributes($key) $val
}

Node instproc program-agent {args} {
    
    ::GLOBALS::named-args $args { 
	-command {} -dir {} -timeout {} -expected-exit-code {}
    }

    set curprog [new Program [$self set sim]]
    $curprog set node $self
    $curprog set command $(-command)
    $curprog set dir "{$(-dir)}"
    $curprog set expected-exit-code $(-expected-exit-code)
    if {$(-timeout) != {}} {
	set to [::GLOBALS::reltime-to-secs $(-timeout)]
	if {$to == -1} {
	    perror "-timeout value is not a relative time: $(-timeout)"
	    return
	} else {
	    $curprog set timeout $to
	}
    }

    return $curprog
}

Node instproc disk-agent {args} {

    ::GLOBALS::named-args $args {
    	-type {} -size 0 -mountpoint {} -parameters {} -command {}
    }

    set curdisk [new Disk [$self set sim]]
    $curdisk set node $self
    $curdisk set type $(-type)
    $curdisk set size $(-size)
    $curdisk set mountpoint $(-mountpoint)
    $curdisk set parameters $(-parameters)
    $curdisk set command $(-command)

    return $curdisk
}

Node instproc custom-agent {args} {
	::GLOBALS::named-args $args {
		-name {}
	}
	
	set customagent [new Custom [$self set sim]]
	$customagent set node $self
	$customagent set name $(-name)

	return $customagent
}

Node instproc topography {topo} {
    var_import ::TBCOMPAT::location_info
    $self instvar sim
    $self instvar fixed

    if {$topo == ""} {
	$self set topo ""
	return
    } elseif {$topo != "" && ! [$topo info class Topography]} {
	perror "\[topography] $topo is not a Topography."
	return
    } elseif {! [$topo initialized]} {
	perror "\[topography] $topo is not initialized."
	return
    }

    $self set topo $topo

    $topo set sim $sim; # Need to link the topography to the simulator here.
    $sim add_topography $topo

    if {$fixed != ""} {
	set building [$topo set area_name]
	if {$building != {} && 
	    [info exists location_info($fixed,$building,x)]} {
	    $self set X_ $location_info($fixed,$building,x)
	    $self set Y_ $location_info($fixed,$building,y)
	    $self set Z_ $location_info($fixed,$building,z)
	}
    } elseif {[$self set type] == "pc"} {
	$self set type "robot"
    }
}

Node instproc console {} {
    $self instvar console_
    
    return $console_
}

#
# Set numeric ID (a mote thing)
#
Node instproc set_numeric_id {myid} {
    $self instvar numeric_id

    set numeric_id $myid
}

#
# Set firewall style for an individual node. Really only makes sense
# for linux nodes with iptables. Might need to add an os_feature.
#
Node instproc set-fw-style {style} {
    $self instvar fw_style

    if {$style != "basic" && $style != "closed" &&
	$style != "open" && $style != "elabinelab"} {
	perror "\[set-fw-style] $style is not a valid type"
	return
    }
    set fw_style $style
}

#
# Add rules to the per-vnode firewall.
# 
Node instproc add-rule {rule} {
    $self instvar next_rule
    $self instvar fw_rules

    set fw_rules($next_rule) $rule
    incr next_rule
}

Node instproc rootkey {key onoff} {
    $self instvar rootkey_public
    $self instvar rootkey_private

    if {$key != "public" && $key != "private"} {
	perror "\[rootkey] key must be public or private"
	return
    }
    if {$onoff != 0 && $onoff != 1} {
	perror "\[rootkey] value must be 0/1"
	return
    }
    if {$key == "public"} {
	set rootkey_public $onoff
    } elseif {$key == "private"} {
	set rootkey_private $onoff
    }
}

#
# Add a link to this bridge.
#
Bridge instproc addbridgelink {link} {
    $self instvar bridgelist

    lappend bridgelist $link
}

Bridge instproc updatedb {DB} {
    $self next $DB

    $self instvar bridgelist
    $self instvar sim
    
    foreach link $bridgelist {
	set port [$self find_port $link]

	if {$port == {}} {
	    perror "Bridge $self is not a member of $link";
	    return
	}
	set fields [list "vname" "vlink" "vport"]
	set values [list $self $link $port]

	$sim spitxml_data "virt_bridges" $fields $values	
    }
}
