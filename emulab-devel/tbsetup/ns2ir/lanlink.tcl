# -*- tcl -*-
#
# Copyright (c) 2000-2019 University of Utah and the Flux Group.
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
# lanlink.tcl
#
# This defines the LanLink class and its two children Lan and Link.  
# Lan and Link make no changes to the parent and exist purely to
# distinguish between the two in type checking of arguments.  A LanLink
# contains a number of node:port pairs as well as the characteristics
# bandwidth, delay, and loss rate.
######################################################################

Class LanLink -superclass NSObject
Class Link -superclass LanLink
Class Lan -superclass LanLink
Class Queue -superclass NSObject
# This class is a hack.  It's sole purpose is to associate to a Link
# and a direction for accessing the Queue class.
Class SimplexLink -superclass NSObject
# Ditto, another hack class.
Class LLink -superclass NSObject

SimplexLink instproc init {link dir} {
    $self set mylink $link
    $self set mydir $dir
}
SimplexLink instproc queue {} {
    $self instvar mylink
    $self instvar mydir

    set myqueue [$mylink set ${mydir}queue]
    return $myqueue
}
LLink instproc init {lan node} {
    $self set mylan  $lan
    $self set mynode $node
}
LLink instproc queue {} {
    $self instvar mylan
    $self instvar mynode

    set port [$mylan get_port $mynode]
    
    return [$mylan set linkq([list $mynode $port])]
}
# Don't need any rename procs since these never use their own name and
# can not be generated during Link creation.

Queue instproc init {link type node} {
    $self set mylink $link
    $self set mynode $node
    
    # These control whether the link was created RED or GRED. It
    # filters through the DB.
    $self set gentle_ 0
    $self set red_ 0

    $self set traced 0
    $self set trace_type "header"
    $self set trace_expr {}
    $self set trace_snaplen 0
    $self set trace_endnode 0
    $self set trace_mysql 0

    #
    # These are NS variables for queues (with NS defaults).
    #
    $self set limit_ 50
    $self set maxthresh_ 15
    $self set thresh_ 5
    $self set q_weight_ 0.002
    $self set linterm_ 10
    $self set queue-in-bytes_ 0
    $self set bytes_ 0
    $self set mean_pktsize_ 500
    $self set wait_ 1
    $self set setbit_ 0
    $self set drop-tail_ 1

    if {$type != {}} {
	$self instvar red_
	$self instvar gentle_
	
	if {$type == "RED"} {
	    set red_ 1
	    $link mustdelay
	} elseif {$type == "GRED"} {
	    set red_ 1
	    set gentle_ 1
	    $link mustdelay
	} elseif {$type != "DropTail"} {
	    punsup "Link type $type, using DropTail!"
	}
    }
}

Queue instproc rename {old new} {
    $self instvar mylink

    $mylink rename_queue $old $new
}

Queue instproc rename_lanlink {old new} {
    $self instvar mylink

    set mylink $new
}

Queue instproc get_link {} {
    $self instvar mylink

    return $mylink
}

Queue instproc agent_name {} {
    $self instvar mylink
    $self instvar mynode

    return "$mylink-$mynode"
}

# Turn on tracing.
Queue instproc trace {{ttype "header"} {texpr ""}} {
    $self instvar traced
    $self instvar trace_expr
    $self instvar trace_type
    
    if {$texpr == ""} {
	set texpr {}
    }

    set traced 1
    set trace_type $ttype
    set trace_expr $texpr
}

#
# A queue is associated with a node on a link. Return that node.
# 
Queue instproc get_node {} {
    $self instvar mynode

    return $mynode
}

Link instproc init {s nodes bw d type} {
    $self next $s $nodes $bw $d $type

    set src [lindex $nodes 0]
    set dst [lindex $nodes 1]

    $self set src_node $src
    $self set dst_node $dst

    # The default netmask, which the user may change (at his own peril).
    $self set netmask "255.255.255.0"

    var_import GLOBALS::new_counter
    set q1 q[incr new_counter]
    
    Queue to$q1 $self $type $src
    Queue from$q1 $self $type $dst

    $self set toqueue to$q1
    $self set fromqueue from$q1
}

LanLink instproc init {s nodes bw d type} {
    var_import GLOBALS::new_counter

    # This is a list of {node port} pairs.
    $self set nodelist {}

    # The simulator
    $self set sim $s

    # By default, a local link
    $self set widearea 0

    # Default type is a plain "ethernet". User can change this.
    $self set protocol "ethernet"

    # Default failure action.
    $self set failureaction "fatal"

    # Colocation is on by default, but this only applies to emulated links
    # between virtual nodes anyway.
    $self set trivial_ok 1

    # Allow user to control whether link gets a linkdelay, if link is shaped.
    # If not shaped, and user sets this variable, a link delay is inserted
    # anyway on the assumption that user wants later control over the link.
    # Both lans and links can get linkdelays.     
    $self set uselinkdelay 0

    # Allow user to control if link is emulated.
    $self set emulated 0

    # Allow user to turn off actual bw shaping on emulated links.
    $self set nobwshaping 0

    # mustdelay; force a delay (or linkdelay) to be inserted. assign_wrapper
    # is free to override this, but not sure why it want to! When used in
    # conjunction with nobwshaping, you get a delay node, but with no ipfw
    # limits on the bw part, and assign_wrapper ignores the bw when doing
    # assignment.
    $self set mustdelay 0

    # Allow user to specify encapsulation on emulated links.
    $self set encap "default"

    # XXX Allow user to set the accesspoint.
    $self set accesspoint {}

    # Optional layer and implemented-by relationship
    $self set layer {}
    $self set implemented_by {}

    # Is this a SAN?
    $self set sanlan 0

    # A simulated lanlink unless we find otherwise
    $self set simulated 1
    # Figure out if this is a lanlink that has at least
    # 1 non-simulated node in it. 
    foreach node $nodes {
	if { [$node set simulated] == 0 } {
	    $self set simulated 0
	    break
	}
    }

    # Arrays to store information about ip addresses used
    $self instvar used_ips
    array set used_ips {}
    $self instvar ipcounters
    array set ipcounters {}

    # The default netmask, which the user may change (at his own peril).
    $self set netmask "255.255.255.0"

    # Make sure BW is reasonable. 
    # XXX: Should come from DB instead of hardwired max.
    # Measured in kbps
    set maxbw 100000000

    # XXX skip this check for a simulated lanlink even if it
    # causes nse to not keep up with real time. The actual max
    # for simulated links will be added later
    if { [$self set simulated] != 1 && $bw > $maxbw } {
	perror "Bandwidth requested ($bw) exceeds maximum of $maxbw kbps!"
	return
    }

    # Virt lan settings, for the entire lan
    $self instvar settings

    # And a two-dimenional arrary for per-member settings.
    # TCL does not actually have multi-dimensional arrays though, so its faked.
    $self instvar member_settings

    # Now we need to fill out the nodelist
    $self instvar nodelist

    # r* indicates the switch->node chars, others are node->switch
    $self instvar bandwidth
    $self instvar rbandwidth
    $self instvar ebandwidth
    $self instvar rebandwidth
    $self instvar backfill
    $self instvar rbackfill
    $self instvar delay
    $self instvar rdelay
    $self instvar loss
    $self instvar rloss
    $self instvar cost
    $self instvar linkq
    $self instvar fixed_iface
    $self instvar bridge_links

    $self instvar iscloud
    $self set iscloud 0

    $self instvar ofenabled
    $self instvar ofcontroller
    #$self instvar oflistener   # this is not needed
    $self set ofenabled 0

    foreach node $nodes {
	# If the node is actually a blockstore object, then we need
	# to grab the parent host object and substitute it in here.
	if {[$node info class] == "Blockstore"} {
	    set bs $node
	    set node [$bs get_node]
	    $self set sanlan 1
	    # XXX: see comment in parse_bw() in parse.tcl
	    if {$bw != 10} {
		perror "Only '~' (indicating best-effort) is supported as the bandwidth for network links/lans containing storage members."
		return
	    }
	}
	set nodepair [list $node [$node add_lanlink $self]]
	set bandwidth($nodepair) $bw
	set rbandwidth($nodepair) $bw
	# Note - we don't set defaults for ebandwidth and rebandwidth - lack
	# of an entry for a nodepair indicates that they should be left NULL
	# in the output.
	set backfill($nodepair) 0
	set rbackfill($nodepair) 0
	set delay($nodepair) [expr $d / 2.0]
	set rdelay($nodepair) [expr $d / 2.0]
	set loss($nodepair) 0
	set rloss($nodepair) 0
	set cost($nodepair) 1
	set fixed_iface($nodepair) 0
	lappend nodelist $nodepair

	set lq q[incr new_counter]
	Queue lq$lq $self $type $node
	set linkq($nodepair) lq$lq

	#
	# Look for bridge connections, and cross link.
	#
	if {[$node info class] == "Bridge"} {
	    $node addbridgelink $self
	    set bridge_links($nodepair) $node
	}
    }
}

#
# Enable Openflow on lan/link and set controller
#
LanLink instproc enable_openflow {ofcontrollerstr} {
    $self instvar ofenabled
    $self instvar ofcontroller
    set ofenabled 1
    set ofcontroller $ofcontrollerstr
}

#
# Set the mustdelay flag.
#
LanLink instproc mustdelay {} {
    $self instvar mustdelay
    set mustdelay 1
}

#
# Set up tracing.
#
Lan instproc trace {{ttype "header"} {texpr ""}} {
    $self instvar nodelist
    $self instvar linkq

    foreach nodeport $nodelist {
	set linkqueue $linkq($nodeport)
	$linkqueue trace $ttype $texpr
    }
}

Link instproc trace {{ttype "header"} {texpr ""}} {
    $self instvar toqueue
    $self instvar fromqueue
    
    $toqueue trace $ttype $texpr
    $fromqueue trace $ttype $texpr
}

#
# A link can be implemented in terms of a path or
# a link at a lower level of the stack.
#
Link instproc implemented_by {impl} {
    $self instvar implemented_by
    $self instvar layer
    
    if {[$impl info class] == "Path"} {
	set implemented_by $impl
    } elseif {[$impl info class] == "Link"} {
	if {$layer == {}} {
	    perror "\[$self implemented_by] no layer set!"
	    return
	}
	set impl_layer [$impl set layer]
	if {$impl_layer == {}} {
	    perror "\[$self implemented_by] no layer set in $impl!"
	    return
	}
	# Special case.
	if {$impl_layer == $layer && $layer != 2} {
	    perror "\[$self implemented_by] $impl is at the same layer!"
	    return
	}
	if {$impl_layer > $layer} {
	    perror "\[$self implemented_by] $impl is not at a lower layer!"
	    return
	}
	set implemented_by $impl
    } else {
        perror "\[$self implemented_by] must be a link or a path!"
        return
    }
}

#
# A lan can be implemented in terms of a path only.
#
Lan instproc implemented_by {impl} {
    $self instvar implemented_by
    $self instvar layer
    
    if {[$impl info class] == "Path"} {
	set implemented_by $impl
    } else {
        perror "\[$self implemented_by] must be a path!"
        return
    }
}

Lan instproc trace_snaplen {len} {
    $self instvar nodelist
    $self instvar linkq

    foreach nodeport $nodelist {
	set linkqueue $linkq($nodeport)
	$linkqueue set trace_snaplen $len
    }
}

Link instproc trace_snaplen {len} {
    $self instvar toqueue
    $self instvar fromqueue
    
    $toqueue set trace_snaplen $len
    $fromqueue set trace_snaplen $len
}

Lan instproc trace_mysql {onoff} {
    var_import ::GLOBALS::dpdb
    $self instvar nodelist
    $self instvar linkq

    foreach nodeport $nodelist {
	set linkqueue $linkq($nodeport)
	$linkqueue set trace_mysql $onoff
    }

    if {$onoff} {
	set dpdb 1
    }
}

Link instproc trace_mysql {onoff} {
    var_import ::GLOBALS::dpdb

    $self instvar toqueue
    $self instvar fromqueue
    
    $toqueue set trace_mysql $onoff
    $fromqueue set trace_mysql $onoff

    if {$onoff} {
	set dpdb 1
    }
}

Lan instproc trace_endnode {onoff} {
    $self instvar nodelist
    $self instvar linkq

    foreach nodeport $nodelist {
	set linkqueue $linkq($nodeport)
	$linkqueue set trace_endnode $onoff
    }
}

Link instproc trace_endnode {onoff} {
    $self instvar toqueue
    $self instvar fromqueue
    
    $toqueue set trace_endnode $onoff
    $fromqueue set trace_endnode $onoff
}


# get_port <node>
# This takes a node and returns the port that the node is connected
# to the LAN with.  If a node is in a LAN multiple times for some
# reason then this only returns the first.
LanLink instproc get_port {node} {
    $self instvar nodelist
    foreach pair $nodelist {
	set n [lindex $pair 0]
	set p [lindex $pair 1]
	if {$n == $node} {return $p}
    }
    return {}
}

#
# Find the queue object for a node on a link. 
#
Link instproc Queue {node} {
    $self instvar toqueue
    $self instvar fromqueue

    if {$node == [$self set src_node]} {
	return $toqueue
    } elseif {$node == [$self set dst_node]} {
	return $fromqueue
    } else {
	perror "Queue: $node is not a member of $self"
	return {}
    }
}

#
# Ditto for a node in a lan.
#
LanLink instproc Queue {node} {
    $self instvar nodelist
    $self instvar linkq
    set vport [$self get_port $node]

    if {$vport == {}} {
	perror "SetDelayParams: $node is not a member of $self";
	return
    }
    set nodepair [list $node $vport]
    return $linkq($nodepair)
}

#
# Set the delay params for a node on a link. This should be used
# ONLY in conjunction with the bridge code since it completely violates
# all rules about how the delay params in the virt_lans table are used.
#
LanLink instproc SetDelayParams {node todelay tobw toloss} {
    $self instvar bandwidth
    $self instvar rbandwidth
    $self instvar nodelist
    set vport [$self get_port $node]
    set role [$node set role]

    # Node better be a bridge
    if {$role != "bridge"} {
	perror "SetDelayParams: $node is not a bridge!\n"
	return
    }
    if {$vport == {}} {
	perror "SetDelayParams: $node is not a member of $self";
	return
    }

    # This is the original bandwidth when the link is created.
    # Remember it, for the mapper. Needs more thought.
    foreach nodeport $nodelist {
	$self set ebandwidth($nodeport) $bandwidth($nodeport)
	$self set rebandwidth($nodeport) $rbandwidth($nodeport)
    }

    set realtodelay [parse_delay $todelay]
    set realtobw [parse_bw $tobw]

    $self set delay([list $node $vport]) $realtodelay
    $self set loss([list $node $vport]) $toloss
    $self set bandwidth([list $node $vport]) $realtobw
    # XXX To make gentopofile happy when generating ltmap.
    $self set rbandwidth([list $node $vport]) $realtobw
}

#
# Ditto for tracing.
#
Link instproc SetTraceParams {node {ttype "header"} {snaplen 0} {texpr ""}} {
    $self instvar toqueue
    $self instvar fromqueue

    if {$node == [$self set src_node]} {
	$toqueue trace $ttype $texpr
	if {$snaplen > 0} {
	    $toqueue set trace_snaplen $snaplen
	}
    } elseif {$node == [$self set dst_node]} {
	$fromqueue trace $ttype $texpr
	if {$snaplen > 0} {
	    $fromqueue set trace_snaplen $snaplen
	}
    } else {
	perror "SetTraceParams: $node is not a member of $self"
    }
}

Lan instproc SetTraceParams {node {ttype "header"} {snaplen 0} {texpr ""}} {
    $self instvar nodelist
    $self instvar linkq

    set vport [$self get_port $node]
    set nodepair [list $node $vport]

    set linkqueue $linkq($nodepair)
    $linkqueue trace $ttype $texpr
    if {$snaplen > 0} {
	$linkqueue set trace_snaplen $snaplen
    }
}

# fill_ips
# This fills out the IP addresses (see README).  It determines a
# subnet, either from already assigned IPs or by asking the Simulator
# for one, and then fills out unassigned node:port's with free IP
# addresses.
LanLink instproc fill_ips {} {
    $self instvar sim
    $self instvar widearea
    $self instvar netmask
    $self instvar used_ips
    set isremote 0
    set netmaskint [inet_atohl $netmask]

    #
    # Find the entire set of nodeports that are reachable because of
    # bridged links/lans.
    #
    set lanlist [list $self]
    while {$lanlist != {}} {
	set lan [lindex $lanlist 0]
	lpop lanlist
	set reachable($lan) 1
	$lan instvar bridge_links

	foreach nodeport [array names bridge_links] {
	    set bridge $bridge_links($nodeport)
	    set nextlanlist [$bridge set bridgelist]

	    foreach nextlan $nextlanlist {
		if {! [info exists reachable($nextlan)]} {
		    lappend lanlist $nextlan
		}
	    }
	}
    }

    # Determine a subnet (if possible) and any used IP addresses in it.
    # ips is a set which contains all used IP addresses in this LanLink.
    set subnet {}
    foreach {lan num} [array get reachable] {
	set nodelist [$lan set nodelist]
	
	foreach nodeport $nodelist {
	    set node [lindex $nodeport 0]
	    set port [lindex $nodeport 1]
	    set ip [$node ip $port]
	    set ipaliases [$node get_ipaliases_port $port]
	    set isremote [expr $isremote + [$node set isremote]]
	    if {$ip != {}} {
		if {$isremote} {
		    perror "Not allowed to specify IP subnet of a remote link!"
		}
		set ipint [inet_atohl $ip]
		set subnet [inet_hltoa [expr $ipint & $netmaskint]]
		set used_ips($ip) 1
		$sim use_subnet $subnet $netmask
	    }
	    if {$ipaliases != {}} {
		foreach ipalias $ipaliases {
		    set ipint [inet_atohl $ipalias]
		    set subnet [inet_hltoa [expr $ipint & $netmaskint]]
		    set used_ips($ipalias) 1
		    $sim use_subnet $subnet $netmask
		}
	    }
	}
    }
    if {$isremote && [$self info class] != "Link"} {
        puts stderr "Warning: Remote nodes used in LAN $self - no IPs assigned"
	#perror "Not allowed to use a remote node in lan $self!"
	return
    }
    if {$isremote} {
	# A boolean ... not a count.
	set widearea 1
    }

    # See parse-ns if you change this! 
    if {$isremote && ($netmask != "255.255.255.248")} {
	puts stderr "Ignoring netmask for remote link; forcing 255.255.255.248"
	set netmask "255.255.255.248"
	set netmaskint [inet_atohl $netmask]
    }

    # If we couldn't find a subnet we ask the Simulator for one.
    if {$subnet == {}} {
	if {$isremote} {
	    set subnet [$sim get_subnet_remote]
	} else {
	    set subnet [$sim get_subnet $netmask]
	}
    }

    # Now we assign IP addresses to any node:port's without them.
    set ip_counter 2
    set subnetint [inet_atohl $subnet]
    foreach {lan num} [array get reachable] {
	set nodelist [$lan set nodelist]
	foreach nodeport $nodelist {
	    set node [lindex $nodeport 0]
	    set port [lindex $nodeport 1]
	    if {[$node ip $port] == {}} {
		set ip [$self _get_next_ip $subnetint $netmaskint]
		$node ip $port $ip
	    }
	    set numaliases [$node get_wanted_ipaliases_port $port]
	    for {set i 0} {$i < $numaliases} {incr i} {
		set ip [$self _get_next_ip $subnetint $netmaskint]
		$node add_ipalias_port $port $ip
	    }
	}
    }
}

# Internal helper - tracks used ip addresses, and doles out the
# next address given the subnet and netmask (integer representations).
LanLink instproc _get_next_ip {subnetint netmaskint} {
    $self instvar used_ips
    $self instvar ipcounters
    set ip {}
    set ip_counter 2
    if {[info exists ipcounters($subnetint)]} {
	set ip_counter $ipcounters($subnetint)
    }
    set max [expr ~ $netmaskint]
    # XXX 64-bit hack
    set max [expr $max & 0xFFFFFFFF]
    for {set i $ip_counter} {$i < $max} {incr i} {
	set nextip [inet_hltoa [expr $subnetint | $i]]
	
	if {! [info exists used_ips($nextip)]} {
	    set ip $nextip
	    set used_ips($ip) 1
	    set ip_counter [expr $i + 1]
	    break
	}
    }
    if {$ip == {}} {
	perror "Ran out of IP addresses in subnet $subnet."
	set ip "255.255.255.255"
	set ip_counter $max
    }

    set ipcounters($subnetint) $ip_counter
    return $ip
}

#
# Return the subnet of a lan. Actually, just return one of the IPs.
#
LanLink instproc get_subnet {} {
    $self instvar nodelist

    set nodeport [lindex $nodelist 0]
    set node [lindex $nodeport 0]
    set port [lindex $nodeport 1]

    return [$node ip $port]
}

#
# XXX - Set the accesspoint for the lan to node. This is temporary.
#
LanLink instproc set_accesspoint {node} {
    $self instvar accesspoint
    $self instvar nodelist

    foreach pair $nodelist {
	set n [lindex $pair 0]
	set p [lindex $pair 1]
	if {$n == $node} {
	    set accesspoint $node
	    return {}
	}
    }
    perror "set_accesspoint: No such node $node in lan $self."
}

#
# Set a setting for the entire lan.
#
LanLink instproc set_setting {capkey capval} {
    $self instvar settings

    set settings($capkey) $capval
}

#
# Set a setting for just one member of a lan
#
LanLink instproc set_member_setting {node capkey capval} {
    $self instvar member_settings
    $self instvar nodelist

    foreach pair $nodelist {
	set n [lindex $pair 0]
	set p [lindex $pair 1]
	if {$n == $node} {
	    set member_settings($node,$capkey) $capval
	    return {}
	}
    }
    perror "set_member_setting: No such node $node in lan $self."
}

#
# Return the subnet of a lan. Actually, just return one of the IPs.
#
LanLink instproc get_netmask {} {
    $self instvar netmask

    return $netmask
}

#
# Set the routing cost for all interfaces on this LAN
#
LanLink instproc cost {c} {
    $self instvar nodelist
    $self instvar cost

    foreach nodeport $nodelist {
	set cost($nodeport) $c
    }
}

Link instproc rename {old new} {
    $self next $old $new

    $self instvar toqueue
    $self instvar fromqueue
    $toqueue rename_lanlink $old $new
    $fromqueue rename_lanlink $old $new
}

Link instproc rename_queue {old new} {
    $self next $old $new

    $self instvar toqueue
    $self instvar fromqueue

    if {$old == $toqueue} {
	set toqueue $new
    } elseif {$old == $fromqueue} {
	set fromqueue $new
    }
}

# The following methods are for renaming objects (see README).
LanLink instproc rename {old new} {
    $self instvar nodelist
    foreach nodeport $nodelist {
	set node [lindex $nodeport 0]
	$node rename_lanlink $old $new
    }
    
    [$self set sim] rename_lanlink $old $new
}
LanLink instproc rename_node {old new} {
    $self instvar nodelist
    $self instvar bandwidth
    $self instvar delay
    $self instvar loss
    $self instvar rbandwidth
    $self instvar rdelay
    $self instvar rloss
    $self instvar linkq
    $self instvar accesspoint

    # XXX Temporary
    if {$accesspoint == $old} {
	set accesspoint $new
    }
    
    set newnodelist {}
    foreach nodeport $nodelist {
	set node [lindex $nodeport 0]
	set port [lindex $nodeport 1]
	set newnodeport [list $new $port]
	if {$node == $old} {
	    lappend newnodelist $newnodeport
	} else {
	    lappend newnodelist $nodeport
	}
	set bandwidth($newnodeport) $bandwidth($nodeport)
	set delay($newnodeport) $delay($nodeport)
	set loss($newnodeport) $loss($nodeport)
	set rbandwidth($newnodeport) $rbandwidth($nodeport)
	set rdelay($newnodeport) $rdelay($nodeport)
	set rloss($newnodeport) $rloss($nodeport)
	set linkq($newnodepair) linkq($nodeport)
	
	unset bandwidth($nodeport)
	unset delay($nodeport)
	unset loss($nodeport)
	unset rbandwidth($nodeport)
	unset rdelay($nodeport)
	unset rloss($nodeport)
	unset linkq($nodeport)
    }
    set nodelist $newnodelist
}

LanLink instproc rename_queue {old new} {
    $self instvar nodelist
    $self instvar linkq

    foreach nodeport $nodelist {
	set foo linkq($nodeport)
	
	if {$foo == $old} {
	    set linkq($nodeport) $new
	}
    }
}

LanLink instproc set_fixed_iface {node iface} {
    $self instvar nodelist
    $self instvar fixed_iface

    # find this node
    set found 0
    foreach nodeport $nodelist {
	if {$node == [lindex $nodeport 0]} {
	    set fixed_iface($nodeport) $iface
	    set found 1
	    break
	}
    }

    if {!$found} {
	perror "\[set_fixed_iface] $node is not the specified link/lan!"
    }
}

# Check the IP address against its mask and ensure that the host
# portion of the IP address is not all '0's (reserved) or all '1's
# (broadcast).
LanLink instproc check-ip-mask {ip mask} {
    set ipint [inet_atohl $ip]
    set maskint [inet_atohl $mask]
    set maskinverse [expr (~ $maskint)]
    # XXX 64-bit hack
    set maskinverse [expr $maskinverse & 0xFFFFFFFF]
    set remainder [expr ($ipint & $maskinverse)]
    if {$remainder == 0 || $remainder == $maskinverse} {
	perror "\[check-ip-mask] IP address $ip with netmask $mask has either all '0's (reserved) or all '1's (broadcast) in the host portion of the address."
    }
}

Link instproc updatedb {DB} {
    $self instvar toqueue
    $self instvar fromqueue
    $self instvar nodelist
    $self instvar src_node
    $self instvar trivial_ok
    var_import ::GLOBALS::pid
    var_import ::GLOBALS::eid
    var_import ::GLOBALS::use_ipassign
    $self instvar bandwidth
    $self instvar rbandwidth
    $self instvar ebandwidth
    $self instvar rebandwidth
    $self instvar backfill
    $self instvar rbackfill
    $self instvar delay
    $self instvar rdelay
    $self instvar loss
    $self instvar rloss
    $self instvar cost
    $self instvar widearea
    $self instvar uselinkdelay
    $self instvar emulated
    $self instvar nobwshaping
    $self instvar encap
    $self instvar sim
    $self instvar netmask
    $self instvar protocol
    $self instvar failureaction
    $self instvar mustdelay
    $self instvar fixed_iface
    $self instvar layer
    $self instvar implemented_by
    $self instvar ofenabled
    $self instvar ofcontroller
    $self instvar bridge_links
    $self instvar settings
    $self instvar member_settings
    $self instvar sanlan
    set vindex 0

    $sim spitxml_data "virt_lan_lans" [list "vname" "failureaction"] [list $self $failureaction]

    #
    # Upload lan settings.
    #
    foreach setting [array names settings] {
	set fields [list "vname" "capkey" "capval"]
	set values [list $self $setting $settings($setting)]
	
	$sim spitxml_data "virt_lan_settings" $fields $values
    }

    #
    # If this is a SAN, then nullify shaping and set up vlan encapsulation.
    #
    if {$sanlan == 1} {
	set nobwshaping 1
	set encap "vlan"
    }

    foreach nodeport $nodelist {
	set node [lindex $nodeport 0]
	if {$node == $src_node} {
	    set linkqueue $toqueue
	} else {
	    set linkqueue $fromqueue
	}
	set limit_ [$linkqueue set limit_]
	set maxthresh_ [$linkqueue set maxthresh_]
	set thresh_ [$linkqueue set thresh_]
	set q_weight_ [$linkqueue set q_weight_]
	set linterm_ [$linkqueue set linterm_]
	set queue-in-bytes_ [$linkqueue set queue-in-bytes_]
	if {${queue-in-bytes_} == "true"} {
	    set queue-in-bytes_ 1
	} elseif {${queue-in-bytes_} == "false"} {
	    set queue-in-bytes_ 0
	}
	set bytes_ [$linkqueue set bytes_]
	if {$bytes_ == "true"} {
	    set bytes_ 1
	} elseif {$bytes_ == "false"} {
	    set bytes_ 0
	}
	set mean_pktsize_ [$linkqueue set mean_pktsize_]
	set red_ [$linkqueue set red_]
	if {$red_ == "true"} {
	    set red_ 1
	} elseif {$red_ == "false"} {
	    set red_ 0
	}
	set gentle_ [$linkqueue set gentle_]
	if {$gentle_ == "true"} {
	    set gentle_ 1
	} elseif {$gentle_ == "false"} {
	    set gentle_ 0
	}
	set wait_ [$linkqueue set wait_]
	set setbit_ [$linkqueue set setbit_]
	set droptail_ [$linkqueue set drop-tail_]

	#
	# Note; we are going to deprecate virt_lans:member and virt_nodes:ips
	# Instead, store vnode,vport,ip in the virt_lans table. To get list
	# of IPs for a node, join virt_nodes with virt_lans. port number is
	# no longer required, but we maintain it to provide a unique key that
	# does not depend on IP address.
	#
	set port [lindex $nodeport 1]
	set ip [$node ip $port]

	if {! $use_ipassign} {
	  $self check-ip-mask $ip $netmask
	}

	set nodeportraw [join $nodeport ":"]

	set fields [list "vname" "member" "mask" "delay" "rdelay" "bandwidth" "rbandwidth" "backfill" "rbackfill" "lossrate" "rlossrate" "cost" "widearea" "emulated" "uselinkdelay" "nobwshaping" "encap_style" "q_limit" "q_maxthresh" "q_minthresh" "q_weight" "q_linterm" "q_qinbytes" "q_bytes" "q_meanpsize" "q_wait" "q_setbit" "q_droptail" "q_red" "q_gentle" "trivial_ok" "protocol" "vnode" "vport" "ip" "mustdelay"]

	# Treat estimated bandwidths differently - leave them out of the lists
	# unless the user gave a value - this way, they get the defaults if not
	# specified
	if { [info exists ebandwidth($nodeport)] } {
	    lappend fields "est_bandwidth"
	}

	if { [info exists rebandwidth($nodeport)] } {
	    lappend fields "rest_bandwidth"
	}
	
	# Tracing.
	if {[$linkqueue set traced] == 1} {
	    lappend fields "traced"
	    lappend fields "trace_type"
 	    lappend fields "trace_expr"
 	    lappend fields "trace_snaplen"
 	    lappend fields "trace_endnode"
 	    lappend fields "trace_db"
	}

	# fixing ifaces
	if {$fixed_iface($nodeport) != 0} {
	    lappend fields "fixed_iface"
	}

	# Set the layer
	if { $layer != {} } {
	    lappend fields "layer"
	}
	if { $implemented_by != {} } {
	    if {[$implemented_by info class] == "Path"} {
		lappend fields "implemented_by_path"
	    } else {
		lappend fields "implemented_by_link"
	    }
	}

	# IP aliases
	set ipaliases [$node get_ipaliases_port $port]
	if {[llength $ipaliases] > 0} {
	    lappend fields "ip_aliases"
	}

	set values [list $self $nodeportraw $netmask $delay($nodeport) $rdelay($nodeport) $bandwidth($nodeport) $rbandwidth($nodeport) $backfill($nodeport) $rbackfill($nodeport)  $loss($nodeport) $rloss($nodeport) $cost($nodeport) $widearea $emulated $uselinkdelay $nobwshaping $encap $limit_  $maxthresh_ $thresh_ $q_weight_ $linterm_ ${queue-in-bytes_}  $bytes_ $mean_pktsize_ $wait_ $setbit_ $droptail_ $red_ $gentle_ $trivial_ok $protocol $node $port $ip $mustdelay]

	if { [info exists ebandwidth($nodeport)] } {
	    lappend values $ebandwidth($nodeport)
	}

	if { [info exists rebandwidth($nodeport)] } {
	    lappend values $rebandwidth($nodeport)
	}

	# Tracing.
	if {[$linkqueue set traced] == 1} {
	    lappend values [$linkqueue set traced]
	    lappend values [$linkqueue set trace_type]
	    lappend values [$linkqueue set trace_expr]
	    lappend values [$linkqueue set trace_snaplen]
	    lappend values [$linkqueue set trace_endnode]
	    lappend values [$linkqueue set trace_mysql]
	}

	# fixing ifaces
	if {$fixed_iface($nodeport) != 0} {
	    lappend values $fixed_iface($nodeport)
	}
	# Set the layer
	if { $layer != {} } {
	    lappend values $layer
	}
	if { $implemented_by != {} } {
	    lappend values $implemented_by
	}

	# IP aliases
	if {[llength $ipaliases] > 0} {
	    set ipaliasesraw [join $ipaliases ","]
	    lappend values $ipaliasesraw
	}
	
	# openflow
	#
	# table: virt_lans
	# columns: ofenabled = 0/1
	#          ofcontroller = ""/"controller connection string"
	#
	lappend fields "ofenabled"
	lappend fields "ofcontroller"
	
	lappend values $ofenabled
	if {$ofenabled == 1} {
	    lappend values $ofcontroller
	} else {
	    lappend values ""
	}

	#
	# Look for a bridge to a nodepair in another link or lan.
	#
	if { [info exists bridge_links($nodeport)] } {
	    set bridge_vname $bridge_links($nodeport)

	    lappend fields "bridge_vname"
	    lappend values $bridge_vname
	}

	lappend fields "vindex"
	lappend values $vindex
	set vindex [expr $vindex + 1]

	$sim spitxml_data "virt_lans" $fields $values

	foreach setting_key [array names member_settings] {
	    set foo      [split $setting_key ","]
	    set thisnode [lindex $foo 0]
	    set capkey   [lindex $foo 1]

	    if {$thisnode == $node} {
		set fields [list "vname" "member" "capkey" "capval"]
		set values [list $self $nodeportraw $capkey \
		                 $member_settings($setting_key)]
	
		$sim spitxml_data "virt_lan_member_settings" $fields $values
	    }
	}
    }
}

Lan instproc updatedb {DB} {
    $self instvar nodelist
    $self instvar linkq
    $self instvar trivial_ok
    var_import ::GLOBALS::pid
    var_import ::GLOBALS::eid
    var_import ::GLOBALS::use_ipassign
    var_import ::GLOBALS::modelnet_cores
    var_import ::GLOBALS::modelnet_edges
    $self instvar bandwidth
    $self instvar rbandwidth
    $self instvar ebandwidth
    $self instvar rebandwidth
    $self instvar backfill
    $self instvar rbackfill
    $self instvar delay
    $self instvar rdelay
    $self instvar loss
    $self instvar rloss
    $self instvar cost
    $self instvar widearea
    $self instvar uselinkdelay
    $self instvar emulated
    $self instvar nobwshaping
    $self instvar encap
    $self instvar sim
    $self instvar netmask
    $self instvar protocol
    $self instvar failureaction
    $self instvar accesspoint
    $self instvar settings
    $self instvar member_settings
    $self instvar mustdelay
    $self instvar fixed_iface
    $self instvar implemented_by
    $self instvar ofenabled
    $self instvar ofcontroller
    $self instvar bridge_links
    $self instvar sanlan
    set vindex 0

    if {$modelnet_cores > 0 || $modelnet_edges > 0} {
	perror "Lans are not allowed when using modelnet; just duplex links."
	return
    }

    $sim spitxml_data "virt_lan_lans" [list "vname" "failureaction"] [list $self $failureaction]

    #
    # Upload lan settings.
    #
    foreach setting [array names settings] {
	set fields [list "vname" "capkey" "capval"]
	set values [list $self $setting $settings($setting)]
	
	$sim spitxml_data "virt_lan_settings" $fields $values
    }

    #
    # If this is a SAN, then nullify shaping and setup vlan encapsulation.
    #
    if {$sanlan == 1} {
	set nobwshaping 1
	set encap "vlan"
    }

    foreach nodeport $nodelist {
	set node [lindex $nodeport 0]
	set isvirt [$node set isvirt]
	set linkqueue $linkq($nodeport)
	set limit_ [$linkqueue set limit_]
	set maxthresh_ [$linkqueue set maxthresh_]
	set thresh_ [$linkqueue set thresh_]
	set q_weight_ [$linkqueue set q_weight_]
	set linterm_ [$linkqueue set linterm_]
	set queue-in-bytes_ [$linkqueue set queue-in-bytes_]
	if {${queue-in-bytes_} == "true"} {
	    set queue-in-bytes_ 1
	} elseif {${queue-in-bytes_} == "false"} {
	    set queue-in-bytes_ 0
	}
	set bytes_ [$linkqueue set bytes_]
	if {$bytes_ == "true"} {
	    set bytes_ 1
	} elseif {$bytes_ == "false"} {
	    set bytes_ 0
	}
	set mean_pktsize_ [$linkqueue set mean_pktsize_]
	set red_ [$linkqueue set red_]
	if {$red_ == "true"} {
	    set red_ 1
	} elseif {$red_ == "false"} {
	    set red_ 0
	}
	set gentle_ [$linkqueue set gentle_]
	if {$gentle_ == "true"} {
	    set gentle_ 1
	} elseif {$gentle_ == "false"} {
	    set gentle_ 0
	}
	set wait_ [$linkqueue set wait_]
	set setbit_ [$linkqueue set setbit_]
	set droptail_ [$linkqueue set drop-tail_]
	
	#
	# Note; we are going to deprecate virt_lans:member and virt_nodes:ips
	# Instead, store vnode,vport,ip in the virt_lans table. To get list
	# of IPs for a node, join virt_nodes with virt_lans. port number is
	# no longer required, but we maintain it to provide a unique key that
	# does not depend on IP address.
	#
	set port [lindex $nodeport 1]
	set ip [$node ip $port]

	if {! $use_ipassign} {
	  $self check-ip-mask $ip $netmask
	}

	set nodeportraw [join $nodeport ":"]

	set is_accesspoint 0
	if {$node == $accesspoint} {
	    set is_accesspoint 1
	}

	set fields [list "vname" "member" "mask" "delay" "rdelay" "bandwidth" "rbandwidth" "backfill" "rbackfill" "lossrate" "rlossrate" "cost" "widearea" "emulated" "uselinkdelay" "nobwshaping" "encap_style" "q_limit" "q_maxthresh" "q_minthresh" "q_weight" "q_linterm" "q_qinbytes" "q_bytes" "q_meanpsize" "q_wait" "q_setbit" "q_droptail" "q_red" "q_gentle" "trivial_ok" "protocol" "is_accesspoint" "vnode" "vport" "ip" "mustdelay"]

	# Treat estimated bandwidths differently - leave them out of the lists
	# unless the user gave a value - this way, they get the defaults if not
	# specified
	if { [info exists ebandwidth($nodeport)] } {
	    lappend fields "est_bandwidth"
	}

	if { [info exists rebandwidth($nodeport)] } {
	    lappend fields "rest_bandwidth"
	}

	# Tracing.
	if {[$linkqueue set traced] == 1} {
	    lappend fields "traced"
	    lappend fields "trace_type"
 	    lappend fields "trace_expr"
 	    lappend fields "trace_snaplen"
 	    lappend fields "trace_endnode"
 	    lappend fields "trace_db"
	}

	# fixing ifaces
        if {$fixed_iface($nodeport) != 0} {
            lappend fields "fixed_iface"
        }

	if { $implemented_by != {} } {
	    lappend fields "implemented_by_path"
	}
	# IP aliases
	set ipaliases [$node get_ipaliases_port $port]
	if {[llength $ipaliases] > 0} {
	    lappend fields "ip_aliases"
	}

	set values [list $self $nodeportraw $netmask $delay($nodeport) $rdelay($nodeport) $bandwidth($nodeport) $rbandwidth($nodeport) $backfill($nodeport) $rbackfill($nodeport) $loss($nodeport) $rloss($nodeport) $cost($nodeport) $widearea $emulated $uselinkdelay $nobwshaping $encap $limit_  $maxthresh_ $thresh_ $q_weight_ $linterm_ ${queue-in-bytes_}  $bytes_ $mean_pktsize_ $wait_ $setbit_ $droptail_ $red_ $gentle_ $trivial_ok $protocol $is_accesspoint $node $port $ip $mustdelay]

	if { [info exists ebandwidth($nodeport)] } {
	    lappend values $ebandwidth($nodeport)
	}

	if { [info exists rebandwidth($nodeport)] } {
	    lappend values $rebandwidth($nodeport)
	}

	# Tracing.
	if {[$linkqueue set traced] == 1} {
	    lappend values [$linkqueue set traced]
	    lappend values [$linkqueue set trace_type]
	    lappend values [$linkqueue set trace_expr]
	    lappend values [$linkqueue set trace_snaplen]
	    lappend values [$linkqueue set trace_endnode]
	    lappend values [$linkqueue set trace_mysql]
	}

	# fixing ifaces
        if {$fixed_iface($nodeport) != 0} {
            lappend values $fixed_iface($nodeport)
        }
	if { $implemented_by != {} } {
	    lappend values $implemented_by
	}
	# IP aliases
	if {[llength $ipaliases] > 0} {
	    set ipaliasesraw [join $ipaliases ","]
	    lappend values $ipaliasesraw
	}

	# openflow
	#
	# table: virt_lans
	# columns: ofenabled = 0/1
	#          ofcontroller = ""/"controller connection string"
	#
	lappend fields "ofenabled"
	lappend fields "ofcontroller"
	
	lappend values $ofenabled
	if {$ofenabled == 1} {
	    lappend values $ofcontroller
	} else {
	    lappend values ""
	}

	#
	# Look for a bridge to a nodepair in another link or lan.
	#
	if { [info exists bridge_links($nodeport)] } {
	    set bridge_vname $bridge_links($nodeport)

	    lappend fields "bridge_vname"
	    lappend values $bridge_vname
	}

	lappend fields "vindex"
	lappend values $vindex
	set vindex [expr $vindex + 1]

	$sim spitxml_data "virt_lans" $fields $values

	foreach setting_key [array names member_settings] {
	    set foo      [split $setting_key ","]
	    set thisnode [lindex $foo 0]
	    set capkey   [lindex $foo 1]

	    if {$thisnode == $node} {
		set fields [list "vname" "member" "capkey" "capval"]
		set values [list $self $nodeportraw $capkey \
		                 $member_settings($setting_key)]
	
		$sim spitxml_data "virt_lan_member_settings" $fields $values
	    }
	}
    }
}

#
# Convert IP/Mask to an integer (host order)
#
proc inet_atohl {ip} {
    if {[scan $ip "%d.%d.%d.%d" a b c d] != 4} {
	perror "\[inet_atohl] Invalid ip $ip; cannot be converted!"
	return 0
    }
    return [expr ($a << 24) | ($b << 16) | ($c << 8) | $d]
}
proc inet_hltoa {ip} {
    set a [expr ($ip >> 24) & 0xff]
    set b [expr ($ip >> 16) & 0xff]
    set c [expr ($ip >> 8)  & 0xff]
    set d [expr ($ip >> 0)  & 0xff]

    return "$a.$b.$c.$d"
}
