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
# sim.tcl
#
# Defines the Simulator class.  For our purpose a Simulator is a
# topology.  This contains a number nodes, lans, and links.  It
# provides methods for the creation of these objects as well as
# routines to locate the objects.  It also stores common state (such
# as IP subnet usage).  Finally it defines the import 'run' method
# which causes all remaining calculations to be done and updates the
# DB state.
#
# Note: Although NS distinguishs between LANs and Links, we do not.
# We merge both types of objects into a single one called LanLink.  
# See lanlink.tcl and README for more information.
######################################################################

Class Simulator
Class Program -superclass NSObject
Class Disk -superclass NSObject
Class Custom -superclass NSObject
Class EventGroup -superclass NSObject
Class Firewall -superclass NSObject

Simulator instproc init {args} {
    var_import ::GLOBALS::program_group
    
    # A counter for internal ids
    $self set id_counter 0

    # Counters for subnets. 
    $self set subnet_counter 1
    $self set wa_subnet_counter 1

    # This is the prefix used to fill any unassigned IP addresses.
    $self set subnet_base "10"

    # The following are sets.  I.e. they map to no value, all
    # we care about is membership.
    $self instvar node_list;		# Indexed by node id
    array set node_list {}
    $self instvar lanlink_list;		# Indexed by lanlink id
    array set lanlink_list {}
    $self instvar subnets;		# Indexed by IP subnet
    array set subnets {}
    $self instvar path_list;		# Indexed by path id
    array set path_list {}

    # link_map is indexed by <node1>:<node2> and contains the
    # id of the lanlink connecting them.  In the case of
    # multiple links between two nodes this contains
    # the last one created.
    $self instvar link_map
    array set link_map {}

    # event list is a list of {time vnode vname otype etype args atstring}
    $self set event_list {}
    $self set event_count 0

    # global nse config file. to be split later
    $self set nseconfig ""

    # Program list.
    $self instvar prog_list;
    array set prog_list {}
    
    # Disk list (shaped/emulated disk).
    $self instvar disk_list;
    array set disk_list {} 

    # Blockstore list - blockstore storage object.
    $self instvar blockstore_list;
    array set blockstore_list {}

    # Custom list.
	$self instvar custom_list;
	array set custom_list {}

    # EventGroup list.
    $self instvar eventgroup_list;
    array set eventgroup_list {}

    # Firewall.
    $self instvar firewall_list;
    array set firewall_list {}

    $self instvar timeline_list;
    array set timeline_list {}

    $self instvar sequence_list;
    array set sequence_list {}

    $self instvar console_list;
    array set console_list {}

    $self instvar tiptunnel_list;
    set tiptunnel_list {}

    $self instvar topography_list;
    array set topography_list {}

    $self instvar parameter_list;
    array set parameter_list {}
    $self instvar parameter_descriptions;
    array set parameter_descriptions {}

    var_import ::GLOBALS::last_class
    set last_class $self

    $self instvar new_node_config;
    array set new_node_config {}
    $self node-config

    $self set description ""
    $self set instructions ""
}

# renaming the simulator instance
# needed to find the name of the instance
# for use in NSE code
Simulator instproc rename {old new} {
}

Simulator instproc node-config {args} {
    ::GLOBALS::named-args $args {
	-topography ""
    }

    $self instvar new_node_config;
    foreach {key value} [array get ""] {
	set new_node_config($key) $value
    }
}

# node
# This method adds a new node to the topology and returns the id
# of the node.
Simulator instproc node {args} {
    var_import ::GLOBALS::last_class
    var_import ::GLOBALS::simulated
    $self instvar id_counter
    $self instvar node_list

    if {($args != {})} {
	punsup "Arguments for node: $args"
    }
    
    set curnode tbnode-n[incr id_counter]
    Node $curnode $self

    # simulated nodes have type 'sim'
    if { $simulated == 1 } {
        tb-set-hardware $curnode sim
	# This allows assign to prefer pnodes
	# that already have FBSD-NSE as the default
	# boot osid over others
	$curnode add-desire "FBSD-NSE" 0.9
    }
    set node_list($curnode) {}
    set last_class $curnode

    $self instvar new_node_config;
    $curnode topography $new_node_config(-topography)

    return $curnode
}

#
# A bridge is really a node.
#
Simulator instproc bridge {args} {
    var_import ::GLOBALS::last_class
    var_import ::GLOBALS::simulated
    $self instvar id_counter
    $self instvar node_list

    if {($args != {})} {
	punsup "Arguments for node: $args"
    }
    
    set curnode tbnode-n[incr id_counter]
    Bridge $curnode $self

    set node_list($curnode) {}
    set last_class $curnode

    $self instvar new_node_config;
    $curnode topography $new_node_config(-topography)

    return $curnode
}

# duplex-link <node1> <node2> <bandwidth> <delay> <type>
# This adds a new link to the topology.  <bandwidth> can be in any
# form accepted by parse_bw and <delay> in any form accepted by
# parse_delay.  Currently only the type 'DropTail' is supported.
Simulator instproc duplex-link {n1 n2 bw delay type args} {
    var_import ::GLOBALS::last_class
    var_import ::GLOBALS::simulated
    $self instvar id_counter
    $self instvar lanlink_list
    $self instvar link_map

    if {($args != {})} {
	punsup "Arguments for duplex-link: $args"
    }
    set error 0
    if {! [$n1 info class Node] && ! [$n1 info class Blockstore] } {
	perror "\[duplex-link] $n1 is not a node."
	set error 1
    }
    if {! [$n2 info class Node] && ! [$n2 info class Blockstore] } {
	perror "\[duplex-link] $n2 is not a node."
	set error 1
    }
#    if { [$n1 set isvirt] != [$n2 set isvirt] } {
#	perror "\[duplex-link] Bad link between real and virtual node!"
#	set error 1
#    }

    if { $simulated == 1 && ( [$n1 set simulated] == 0 || [$n2 set simulated] == 0 ) } {
	set simulated 0
	perror "\[duplex-link] Please define links between real and simulated nodes outside make-simulated"
	set simulated 1
	set error 1
    }

    if {$error} {return}

    # Convert bandwidth and delay
    set rbw [parse_bw $bw]
    set rdelay [parse_delay $delay]

    set curlink tblink-l[incr id_counter]

    Link $curlink $self "$n1 $n2" $rbw $rdelay $type	
    set lanlink_list($curlink) {}
    set link_map($n1:$n2) $curlink
    set link_map($n2:$n1) $curlink

    set last_class $curlink
    return $curlink
}

# make-lan <nodelist> <bw> <delay>
# This adds a new lan to the topology. <bandwidth> can be in any
# form accepted by parse_bw and <delay> in any form accepted by
# parse_delay.
Simulator instproc make-lan {nodelist bw delay args} {
    var_import ::GLOBALS::last_class
    var_import ::GLOBALS::simulated
    $self instvar id_counter
    $self instvar lanlink_list

    if {($args != {})} {
	punsup "Arguments for make-lan: $args"
    }

    #
    # The number of virtual nodes has to be zero, or equal to the number
    # of nodes (In other word, no mixing of real and virtual nodes).
    #
#    set acount 0
#    set vcount 0
#    foreach node $nodelist {
#	if { [$node set isvirt] } {
#	    incr vcount
#	}
#	incr acount
#    }
#    if { ($vcount != 0) && ($vcount != $acount) } {
#	perror "\[duplex-link] Bad lan between real and virtual nodes!"
#	set error 1
#	return ""
#    }

    # At this point we have one of the nodes of
    # the lan to be real. We need to make sure
    # that this is not being defined in make-simulated.
    # In other words links or lans from real nodes and
    # simulated nodes should happen outside make-simulated
    if { $simulated == 1 } {

	foreach node $nodelist {
	    if { [$node set simulated] == 0 } {	
		set simulated 0
		perror "Please define lans between real and simulated nodes outside make-simulated"
		set simulated 1
		return ""
	    }
	}
    }

    set curlan tblan-lan[incr id_counter]
    
    # Convert bandwidth and delay
    set rbw [parse_bw $bw]
    set rdelay [parse_delay $delay]

    # Warn about potential rounding of delay values due to implementation
    if { ($rdelay % 2) == 1 } {
	puts stderr "*** WARNING: due to delay implementation, odd delay value $rdelay for LAN may be rounded up"
    }
    
    Lan $curlan $self $nodelist $rbw $rdelay {}
    set lanlink_list($curlan) {}
    set last_class $curlan
    
    return $curlan
}

# A variant that creates a lan with a single member.
Simulator instproc make-portinvlan {node token} {
    var_import ::GLOBALS::last_class
    $self instvar id_counter
    $self instvar lanlink_list

    set curlan tblan-lan[incr id_counter]
    
    Lan $curlan $self $node 0 0 {}
    set lanlink_list($curlan) {}
    set last_class $curlan

    $curlan set_setting "portvlan" $token
    
    return $curlan
}

# make-path <linklist>
Simulator instproc make-path {linklist args} {
    var_import ::GLOBALS::last_class
    $self instvar id_counter
    $self instvar path_list

    set curpath tbpath-path[incr id_counter]
    
    Path $curpath $self $linklist
    set path_list($curpath) {}
    set last_class $curpath
    
    return $curpath
}

Simulator instproc make-cloud {nodelist bw delay args} {
    $self instvar event_list
    $self instvar event_count

    if {($args != {})} {
	punsup "Arguments for make-cloud: $args"
    }

    set retval [$self make-lan $nodelist $bw $delay]

    $retval set iscloud 1
    $retval mustdelay

    return $retval
}

# Storage sugar.
Simulator instproc make-san {nodelist} {
    return [$self make-lan $nodelist ~ 0ms]
}

Simulator instproc event-timeline {args} {
    $self instvar id_counter
    $self instvar timeline_list

    set curtl tbtl-tl[incr id_counter]

    EventTimeline $curtl $self
    set timeline_list($curtl) {}

    return $curtl
}

Simulator instproc event-sequence {{seq {}} {catch {}} {catch_seq {}}} {
    $self instvar id_counter
    $self instvar sequence_list

    if {$catch != {}} {
	set mainseq tbseq-seq[incr id_counter]
	set catchseq tbseq-seq[incr id_counter]
	set curseq tbseq-seq[incr id_counter]

	EventSequence $mainseq $self [uplevel 1 subst [list $seq]]
	EventSequence $catchseq $self [uplevel 1 subst [list $catch_seq]]
	EventSequence $curseq $self [subst {
	    $mainseq run
	    $catchseq run
	}] -errorseq 1
	set sequence_list($mainseq) {}
	set sequence_list($catchseq) {}
	set sequence_list($curseq) {}
    } else {
	set curseq tbseq-seq[incr id_counter]
	set lines {}

	foreach line [split $seq "\n"] {
	    lappend lines [uplevel 1 eval list [list $line]]
	}
	EventSequence $curseq $self $lines
	set sequence_list($curseq) {}
    }

    return $curseq
}

Simulator instproc event-group {{list {}}} {
    set curgrp [new EventGroup $self]
    if {$list != {}} {
	foreach obj $list {
	    $curgrp add $obj
	}
    }

    return $curgrp
}

# blockstore
# This method adds a new block storage object to the topology and returns 
# its id.
Simulator instproc blockstore {args} {
    var_import ::GLOBALS::last_class
    $self instvar id_counter
    $self instvar blockstore_list

    if {($args != {})} {
	punsup "Arguments for node: $args"
    }

    set curblock tbblk-n[incr id_counter]
    Blockstore $curblock $self

    set blockstore_list($curblock) {}
    set last_class $curblock

    $self instvar new_blockstore_config;

    return $curblock
}

# run
# This method causes the fill_ips method to be invoked on all 
# lanlinks and then, if not running in impotent mode, calls the
# updatedb method on all nodes and lanlinks.  Invocation of this
# method casues the 'ran' variable to be set to 1.
Simulator instproc run {} {
    $self instvar lanlink_list
    $self instvar path_list
    $self instvar node_list
    $self instvar event_list
    $self instvar prog_list
    $self instvar disk_list 
    $self instvar blockstore_list
	$self instvar custom_list
    $self instvar eventgroup_list
    $self instvar firewall_list
    $self instvar timeline_list
    $self instvar sequence_list
    $self instvar console_list
    $self instvar tiptunnel_list
    $self instvar topography_list
    $self instvar parameter_list
    $self instvar parameter_descriptions
    $self instvar simulated
    $self instvar nseconfig
    $self instvar description
    $self instvar instructions
    var_import ::GLOBALS::pid
    var_import ::GLOBALS::eid
    var_import ::GLOBALS::errors
    var_import ::GLOBALS::irfile
    var_import ::GLOBALS::ran
    var_import ::GLOBALS::impotent
    var_import ::GLOBALS::rspecmode
    var_import ::GLOBALS::passmode
    var_import ::GLOBALS::vtypes
    var_import ::GLOBALS::uselatestwadata
    var_import ::GLOBALS::usewatunnels
    var_import ::GLOBALS::wa_delay_solverweight
    var_import ::GLOBALS::wa_bw_solverweight
    var_import ::GLOBALS::wa_plr_solverweight
    var_import ::GLOBALS::uselinkdelays
    var_import ::GLOBALS::forcelinkdelays
    var_import ::GLOBALS::multiplex_factor
    var_import ::GLOBALS::packing_strategy
    var_import ::GLOBALS::sync_server
    var_import ::GLOBALS::use_ipassign
    var_import ::GLOBALS::ipassign_args
    var_import ::GLOBALS::cpu_usage
    var_import ::GLOBALS::mem_usage
    var_import ::GLOBALS::fix_current_resources
    var_import ::GLOBALS::vlink_encapsulate
    var_import ::GLOBALS::jail_osname
    var_import ::GLOBALS::delay_osname
    var_import ::GLOBALS::delay_capacity
    var_import ::TBCOMPAT::objtypes
    var_import ::TBCOMPAT::eventtypes
    var_import ::TBCOMPAT::triggertypes
    var_import ::GLOBALS::modelnet_cores
    var_import ::GLOBALS::modelnet_edges
    var_import ::GLOBALS::elab_in_elab
    var_import ::GLOBALS::elabinelab_topo
    var_import ::GLOBALS::elabinelab_eid
    var_import ::GLOBALS::elabinelab_cvstag
    var_import ::GLOBALS::elabinelab_singlenet
    var_import ::TBCOMPAT::elabinelab_attributes
    var_import ::GLOBALS::security_level
    var_import ::GLOBALS::explicit_firewall
    var_import ::GLOBALS::sourcefile_list
    var_import ::GLOBALS::optarray_order
    var_import ::GLOBALS::optarray_count
    var_import ::GLOBALS::dpdb
    var_import ::GLOBALS::nonfs
   
#for oml begin
    var_import ::TBCOMPAT::oml_use_control
    if { $oml_use_control == 0 } {
        set ::TBCOMPAT::nodelist [list]
        foreach node [lsort [array names node_list]] {
          lappend ::TBCOMPAT::nodelist $node
        }
        uplevel #0 { set omllan [$ns make-lan ${::TBCOMPAT::nodelist} 100Mb 0ms] }
    }

    begin_oml_code_generator
#for oml end
 
    if {$ran == 1} {
	perror "The Simulator 'run' statement can only be run once."
	return
    }

    if {$elab_in_elab && [llength [array names node_list]] == 0} {
	if {$elabinelab_topo == ""} {
	    set nsfilename "elabinelab.ns"
	} else {
	    set nsfilename "elabinelab-${elabinelab_topo}.ns"
	}
	uplevel 1 real_source "/users/mshobana/emulab-devel/build/lib/ns2ir/${nsfilename}"
    }
    if {$security_level || $explicit_firewall} {
	uplevel 1 real_source "/users/mshobana/emulab-devel/build/lib/ns2ir/fw.ns"
    }

    # Finalize the blockstore objects - last minute initialization and checks
    # before they are spit out to the db.
    foreach bstore [array names blockstore_list] {
	if {[$bstore finalize] != 0} {
	    break
	}
    }

    # Fill out IPs
    if {! $use_ipassign } {
	foreach obj [concat [array names lanlink_list]] {
	    $obj fill_ips
	}
    }

    # Go through the list of nodes, and find subnode hosts:
    # - If the subnode is of class Node, we have to add a
    #   desire to have the hosts-<type-of-child> feature.
    foreach node [lsort [array names node_list]] {
	if { [$node set subnodehost] == 1 } {
	    set child [$node set subnodechild]
	    if {[$child info class Node]} {
		set childtype [$child set type]
		$node add-desire "hosts-$childtype" 1.0
	    }
	}
    }

    # If the experiment is firewalled, make sure that all nodes in the
    # experiment have the "firewallable" feature.
    if {[array size firewall_list] > 0} {
	foreach node [lsort [array names node_list]] {
	    $node add-desire "firewallable" 1.0
	}
    }

    # Default sync server.
    set default_sync_server {}

    # Mark that a run statement exists
    set ran 1

    # Check node names.
    foreach node [lsort [array names node_list]] {
	if {! [regexp {^[-0-9A-Za-z]+$} $node]} {
	    perror "\[run] Invalid node name $node.  Can only contain \[-0-9A-Za-z\] due to DNS limitations."
	}
    }
    foreach lan [lsort [array names lanlink_list]] {
	if {! [regexp {^[-0-9A-Za-z]+$} $lan]} {
	    perror "\[run] Invalid lan/link name $lan.  Can only contain \[-0-9A-Za-z\] for symmetry with node DNS limitations."
	}
    }

    # If any errors occur stop here.
    if {$errors == 1} {return}

    # Write out the feedback "bootstrap" file.
    var_import ::TBCOMPAT::expdir;
    var_import ::TBCOMPAT::BootstrapReservations;

    if {! [file isdirectory $expdir]} {
	# Experiment directory does not exist, so we cannot write the file...
    } elseif {[array size BootstrapReservations] > 0} {
	set file [open "$expdir/tbdata/bootstrap_data.tcl" w]
	puts $file "# -*- TCL -*-"
	puts $file "# Automatically generated feedback bootstrap file."
	puts $file "#"
	puts $file "# Generated at: [clock format [clock seconds]]"
	puts $file "#"
	puts $file ""
	foreach res [array names BootstrapReservations] {
	    puts $file "set Reservations($res) $BootstrapReservations($res)"
	}
	close $file
    }

    # Write out the feedback "estimate" file.
    var_import ::TBCOMPAT::EstimatedReservations;

    if {! [file isdirectory $expdir]} {
	# Experiment directory does not exist, so we cannot write the file...
    } elseif {[array size EstimatedReservations] > 0} {
	set file [open "$expdir/tbdata/feedback_estimate.tcl" w]
	puts $file "# -*- TCL -*-"
	puts $file "# Automatically generated feedback estimated file."
	puts $file "#"
	puts $file "# Generated at: [clock format [clock seconds]]"
	puts $file "#"
	puts $file ""
	foreach res [array names EstimatedReservations] {
	    puts $file "set EstimatedReservations($res) $EstimatedReservations($res)"
	}
	close $file
    }

    # If we are running in impotent mode we stop here
    if {$impotent == 1 && $passmode == 0 && $rspecmode == 0} {return}
    
    $self spitxml_init

    if { $description != "" || $instructions != "" } {
	$self spitxml_data "portal" [list "description" "instructions" ] [list $description $instructions ]
    }

    # update the global nseconfigs using a bogus vname
    # i.e. instead of the node on which nse is gonna run
    # which was the original vname field, we just put $ns
    # for now. Once assign runs, the correct value will be
    # entered into the database
    if { $nseconfig != {} } {
 
 	set nsecfg_script ""
 	set simu [lindex [Simulator info instances] 0]
 	append nsecfg_script "set $simu \[new Simulator]\n"
 	append nsecfg_script "\$$simu use-scheduler RealTime\n\n"
 	append nsecfg_script $nseconfig

	$self spitxml_data "nseconfigs" [list "vname" "nseconfig" ] [list fullsim $nsecfg_script ]
    }
    
    # Update the DB
    foreach node [lsort [array names node_list]] {
	$node updatedb "sql"

	if { $default_sync_server == {} &&
	     ![$node set issubnode] && ![$node set isbridgenode] &&
	     [$node set type] != "blockstore" } {
	    set default_sync_server $node
	}
    }
    
    foreach lan [concat [array names lanlink_list]] {
	$lan updatedb "sql"
	if {[$lan set iscloud] != 0} {
	    lappend event_list [list "0" "*" $lan LINK CLEAR "" "" "__ns_sequence"]
	    lappend event_list [list "1" "*" $lan LINK CREATE "" "" "__ns_sequence"]
	}
    }
    foreach vtype [array names vtypes] {
	$vtype updatedb "sql"
    }
    foreach prog [array names prog_list] {
	$prog updatedb "sql"
    }
    foreach disk [array names disk_list] {
        $disk updatedb "sql"
    } 
    foreach blockstore [array names blockstore_list] {
        $blockstore updatedb "sql"
    }
    foreach custom [array names custom_list] {
        $custom updatedb "sql"
    }
    foreach egroup [array names eventgroup_list] {
	$egroup updatedb "sql"
    }
    foreach fw [array names firewall_list] {
	$fw updatedb "sql"
    }
    foreach tl [array names timeline_list] {
	$tl updatedb "sql"
    }
    foreach seq [array names sequence_list] {
	$seq updatedb "sql"
    }
    foreach con [array names console_list] {
	$con updatedb "sql"
    }
    foreach tt $tiptunnel_list {
	$self spitxml_data "virt_tiptunnels" [list "host" "vnode"] $tt
    }
    foreach tg [array names topography_list] {
	$tg updatedb "sql"
    }
    foreach path [array names path_list] {
	$path updatedb "sql"
    }

    set fields [list "mem_usage" "cpu_usage" "forcelinkdelays" "uselinkdelays" "usewatunnels" "uselatestwadata" "wa_delay_solverweight" "wa_bw_solverweight" "wa_plr_solverweight" "encap_style" "allowfixnode"]
    set values [list $mem_usage $cpu_usage $forcelinkdelays $uselinkdelays $usewatunnels $uselatestwadata $wa_delay_solverweight $wa_bw_solverweight $wa_plr_solverweight $vlink_encapsulate $fix_current_resources]

    if { $multiplex_factor != {} } {
	lappend fields "multiplex_factor"
	lappend values $multiplex_factor
    }
    if { $packing_strategy != {} } {
	lappend fields "packing_strategy"
	lappend values $packing_strategy
    }
    
    if { $sync_server != {} } {
	lappend fields "sync_server"
	lappend values $sync_server
    } elseif { $default_sync_server != {} } {
	lappend fields "sync_server"
	lappend values $default_sync_server
    }

    lappend fields "use_ipassign"
    lappend values $use_ipassign

    if { $ipassign_args != {} } {
	lappend fields "ipassign_args"
	lappend values $ipassign_args
    }

    if { $jail_osname != {} } {
	lappend fields "jail_osname"
	lappend values $jail_osname
    }
    if { $delay_osname != {} } {
	lappend fields "delay_osname"
	lappend values $delay_osname
    }
    if { $delay_capacity != {} } {
	lappend fields "delay_capacity"
	lappend values $delay_capacity
    }

    if {$modelnet_cores > 0 && $modelnet_edges > 0} {
	lappend fields "usemodelnet"
	lappend values 1
	lappend fields "modelnet_cores"
	lappend values $modelnet_cores
	lappend fields "modelnet_edges"
	lappend values $modelnet_edges
    }
    
    if {$elab_in_elab} {
	lappend fields "elab_in_elab"
	lappend values 1
	lappend fields "elabinelab_singlenet"
	lappend values $elabinelab_singlenet

	if { $elabinelab_eid != {} } {
	    lappend fields "elabinelab_eid"
	    lappend values $elabinelab_eid
	}
	
	if { $elabinelab_cvstag != {} } {
	    lappend fields "elabinelab_cvstag"
	    lappend values $elabinelab_cvstag
	}
    }
    
    if {$security_level} {
	lappend fields "security_level"
	lappend values $security_level
    }

    if {$nonfs} {
	lappend fields "nonfsmounts"
	lappend values $nonfs
	lappend fields "nfsmounts"
	lappend values "none"
    }

    if {$dpdb} {
	lappend fields "dpdb"
	lappend values $dpdb
    }
    
    $self spitxml_data "experiments" $fields $values

    # This could probably be elsewhere.
    $self spitxml_data "virt_agents" [list "vnode" "vname" "objecttype" ] [list "*" $self $objtypes(SIMULATOR) ]

    # This will eventually be under user control.
    $self spitxml_data "virt_agents" [list "vnode" "vname" "objecttype" ] [list "*" "linktest" $objtypes(LINKTEST) ]

    $self spitxml_data "virt_agents" [list "vnode" "vname" "objecttype" ] [list "*" "slothd" $objtypes(SLOTHD) ]
    
    # Per-experiment event to shutdown remote blockstores
    $self spitxml_data "virt_agents" [list "vnode" "vname" "objecttype" ] [list "*" "rem-bstore" $objtypes(BSTORE) ]

    if {[array exists ::opt]} {
	for {set i 0} {$i < $optarray_count} {incr i} {
	    set oname  $optarray_order($i)
	    set ovalue $::opt($oname)
	
	    $self spitxml_data "virt_user_environment" [list "name" "value" ] [list "$oname" "$ovalue" ]
	}
    }

    foreach event $event_list {
	if {[string equal [lindex $event 0] "swapout"]} {
               set event [lreplace $event 0 0 0]
	       set triggertype "SWAPOUT"
	} else {
	       set triggertype "TIMER"
	}
	set fields [list "time" "vnode" "vname" "objecttype" "eventtype" "arguments" "atstring" "triggertype" ]
	set values [list [lindex $event 0] [lindex $event 1] [lindex $event 2] $objtypes([lindex $event 3]) $eventtypes([lindex $event 4]) [lindex $event 5] [lindex $event 6] $triggertypes($triggertype)]
	if {[llength $event] > 8} {

	    lappend fields "parent"
	    lappend values [lindex $event 8]
	}
	$self spitxml_data "eventlist" $fields $values
    }

    foreach name [array names parameter_list] {
	set default_value $parameter_list($name)
	set description $parameter_descriptions($name)

	set p_fields [list "name" "value"]
	set p_values [list $name $default_value]

	if {$description != {}} {
	    lappend p_fields "description"
	    lappend p_values $description
	}

	$self spitxml_data "virt_parameters" $p_fields $p_values
    }
	
    foreach sourcefile $sourcefile_list {
	$self spitxml_data "external_sourcefiles" [list "pathname" ] [list $sourcefile ]
    }

    if {$elab_in_elab} {
	foreach attr $elabinelab_attributes {
	    set fields [list "role" "attrkey" "attrvalue" "ordering"]
	    set values [split $attr ";"]
	    $self spitxml_data "elabinelab_attributes" $fields $values
	}
    }

    if [info exists ::TBCOMPAT::tarfiles] {
	foreach tarfile $::TBCOMPAT::tarfiles {
	    set path [lindex $tarfile 1]
	    set dest [lindex $tarfile 0]
	    $self spitxml_data "experiment_blobs" [list "path" "action"] [list $path "unpack:$dest"]
	}
    }

    if [info exists ::TBCOMPAT::virt_blobs] {
	set fields [list "vblob_id" "filename"]
	foreach vallist $::TBCOMPAT::virt_blobs {
	    $self spitxml_data "virt_blobs" $fields $vallist
	}
    }

    if [info exists ::TBCOMPAT::virt_service_ctls] {
	set fields [list "vnode" "service_idx" "env" "whence" "alt_vblob_id" \
			"enable" "enable_hooks" "fatal"]
	foreach key [array names ::TBCOMPAT::virt_service_ctls] {
	    $self spitxml_data "virt_client_service_ctl" \
		$fields $::TBCOMPAT::virt_service_ctls($key)
	}
    }

    if [info exists ::TBCOMPAT::virt_service_hooks] {
	set fields [list "vnode" "service_idx" "env" "whence" "hook_vblob_id" \
			"hook_op" "hook_point" "argv" "fatal"]
	foreach key [array names ::TBCOMPAT::virt_service_hooks] {
	    foreach vallist $::TBCOMPAT::virt_service_hooks($key) {
		$self spitxml_data "virt_client_service_hooks" \
		    $fields $vallist
	    }
	}
    }

    if [info exists ::TBCOMPAT::virt_address_pools] {
	set fields [list "pool_id" "count"]
	foreach key [array names ::TBCOMPAT::virt_address_pools] {
	    $self spitxml_data "virt_address_allocation" \
		$fields [list $key $::TBCOMPAT::virt_address_pools($key)]
	}
    }

    $self spitxml_finish
}

# attach-agent <node> <agent>
# This creates an attachment between <node> and <agent>.
Simulator instproc attach-agent {node agent} {
    var_import ::GLOBALS::simulated

    if {! [$agent info class Agent]} {
	perror "\[attach-agent] $agent is not an Agent."
	return
    }
    if {! [$node info class Node]} {
	perror "\[attach-agent] $node is not a Node."
	return
    }

    # If the node is real and yet this code is in make-simulated
    # we don't allow it
    if { [$node set simulated] == 0 && $simulated == 1 } {
	set simulated 0
	perror "Please attach agents on to real nodes outside make-simulated"
	set simulated 1
	return ""
    }

    $node attach-agent $agent
}

Simulator instproc agentinit {agent} {
    var_import ::TBCOMPAT::objtypes
    var_import ::TBCOMPAT::eventtypes
    var_import ::TBCOMPAT::triggertypes

    if {[$agent info class Application/Traffic/CBR]} {
	$self spitxml_data "eventlist" [list "time" "vnode" "vname" "objecttype" "eventtype" "arguments" "atstring" "parent" ] [list "0" [$agent get_node] $agent $objtypes(TRAFGEN) $eventtypes(MODIFY) [$agent get_params] "" "__ns_sequence"]
    }
}

# connect <src> <dst>
# Connects two agents together.
Simulator instproc connect {src dst} {
    $self instvar tiptunnel_list

    if {([$src info class Node] && [$dst info class Console]) ||
	([$src info class Console] && [$dst info class Node])} {
	if {[$src info class Node] && [$dst info class Console]} {
	    set node $src
	    set con $dst
	} else {
	    set node $dst
	    set con $src
	}
	if {[$con set connected]} {
	    perror "\[connect] $con is already connected"
	    return
	}
	$con set connected 1
	lappend tiptunnel_list [list $node [$con set node]]
	return
    }
    set error 0
    if {! [$src info class Agent]} {
	perror "\[connect] $src is not an Agent."
	set error 1
    }
    if {! [$dst info class Agent]} {
	perror "\[connect] $dst is not an Agent."
	set error 1
    }
    if {$error} {return}
    $src connect $dst
    $dst connect $src
}

# at <time> <event>
# Known events:
#   <traffic> start
#   <traffic> stop
#   <link> up
#   <link> down
#   ...
Simulator instproc at {time eventstring} {
    var_import ::GLOBALS::simulated
    var_import ::TBCOMPAT::hwtype_class

    # ignore at statement for simulated case
    if { $simulated == 1 } {
	return
    }

    if {[string equal $time "swapout"]} {
# "swapout" will be preserved as the time until we're at a point
# where we can shunt it into a code path where it changes the
# trigger type.
    } else {
       set ptime [::GLOBALS::reltime-to-secs $time]
       if {$ptime == -1} {
	   perror "Invalid time spec: $time"
	   return
       }
       set time $ptime
    }

    $self instvar event_list
    $self instvar event_count

    if {$event_count > 14000} {
	perror "Too many events in your NS file!"
	exit 1
    }
    set eventlist [split $eventstring ";"]
    
    foreach event $eventlist {
	set rc [$self make_event "sim" $event]

	if {$rc != {}} {
	    set event_count [expr $event_count + 1]
	    lappend event_list [linsert $rc 0 $time]
	}
    }
}

#
# Routing control.
#
Simulator instproc rtproto {type args} {
    var_import ::GLOBALS::default_ip_routing_type
    var_import ::GLOBALS::simulated

    # ignore at statement for simulated case
    if { $simulated == 1 } {
	return
    }

    if {$args != {}} {
	punsup "rtproto: arguments ignored: $args"
    }

    if {($type == "Session") ||	($type == "ospf")} {
	set default_ip_routing_type "ospf"
    } elseif {($type == "Manual")} {
	set default_ip_routing_type "manual"
    } elseif {($type == "Static")} {
	set default_ip_routing_type "static"
    } elseif {($type == "Static-ddijk")} {
	set default_ip_routing_type "static-ddijk"
    } elseif {($type == "Static-old")} {
	set default_ip_routing_type "static-old"
    } else {
	punsup "rtproto: unsupported routing protocol ignored: $type"
	return
    }
}

# unknown 
# This is invoked whenever any method is called on the simulator
# object that is not defined.  We interpret such a call to be a
# request to create an object of that type.  We create display an
# unsupported message and create a NullClass to fulfill the request.
Simulator instproc unknown {m args} {
    $self instvar id_counter
    punsup "Object $m"
    NullClass tbnull-null[incr id_counter] $m
}

# rename_* <old> <new>
# The following two procedures handle when an object is being renamed.
# They update the internal datastructures to reflect the new name.
Simulator instproc rename_lanlink {old new} {
    $self instvar lanlink_list
    $self instvar link_map

    unset lanlink_list($old)
    set lanlink_list($new) {}

    # In the case of a link we need to update the link_map as well.
    if {[$new info class] == "Link"} {
	$new instvar nodelist
	set src [lindex [lindex $nodelist 0] 0]
	set dst [lindex [lindex $nodelist 1] 0]
	set link_map($src:$dst) $new
	set link_map($dst:$src) $new
    }
}
Simulator instproc rename_node {old new} {
    $self instvar node_list

    # simulated nodes won't exist in the node_list
    if { [info exists node_list($old)] } {
	unset node_list($old)
	set node_list($new) {}
    }
}

Simulator instproc rename_program {old new} {
    $self instvar prog_list
    unset prog_list($old)
    set prog_list($new) {}
}

Simulator instproc rename_disk {old new} {
    $self instvar disk_list
    unset disk_list($old)
    set disk_list($new) {}
}

Simulator instproc rename_blockstore {old new} {
    $self instvar blockstore_list
    unset blockstore_list($old)
    set blockstore_list($new) {}
}

Simulator instproc rename_custom {old new} {
    $self instvar custom_list
    unset custom_list($old)
    set custom_list($new) {}
}

Simulator instproc rename_eventgroup {old new} {
    $self instvar eventgroup_list
    unset eventgroup_list($old)
    set eventgroup_list($new) {}
}

Simulator instproc rename_firewall {old new} {
    $self instvar firewall_list
    unset firewall_list($old)
    set firewall_list($new) {}
}

Simulator instproc rename_timeline {old new} {
    $self instvar timeline_list
    unset timeline_list($old)
    set timeline_list($new) {}
}

Simulator instproc rename_sequence {old new} {
    $self instvar sequence_list
    unset sequence_list($old)
    set sequence_list($new) {}
}

Simulator instproc rename_console {old new} {
    $self instvar console_list
    unset console_list($old)
    set console_list($new) {}
}

Simulator instproc rename_topography {old new} {
    $self instvar topography_list
    unset topography_list($old)
    set topography_list($new) {}
}

Simulator instproc rename_path {old new} {
    $self instvar path_list
    unset path_list($old)
    set path_list($new) {}
}

# find_link <node1> <node2>
# This is just an accesor to the link_map datastructure.  If no
# link is known between <node1> and <node2> the empty list is returned.
Simulator instproc find_link {src dst} {
    $self instvar link_map
    if {[info exists link_map($src:$dst)]} {
	return $link_map($src:$dst)
    } else {
	return ""
    }
}

Simulator instproc link {src dst} {
    set reallink [$self find_link $src $dst]
	
    if {$src == [$reallink set src_node]} {
	set dir "to"
    } else {
	set dir "from"
    }
    
    var_import GLOBALS::new_counter
    set name sl[incr new_counter]
    
    return [SimplexLink $name $reallink $dir]
}

Simulator instproc lanlink {lan node} {
    if {[$node info class] != "Node"} {
	perror "\[lanlink] $node is not a node."
	return
    }
    if {[$lan info class] != "Lan"} {
	perror "\[lanlink] $lan is not a lan."
	return
    }
    set port [$lan get_port $node]
    if {$port == {}} {
	perror "\[lanlink] $node is not in $lan."
	return
    }
    var_import GLOBALS::new_counter
    set name ll[incr new_counter]
    
    return [LLink $name $lan $node]
}

# get_subnet
# This is called by lanlinks.  When called get_subnet will find an available
# IP subnet, mark it as used, and return it to the caller.
Simulator instproc get_subnet {netmask} {
    $self instvar subnet_base
    $self instvar subnets

    set netmaskint [inet_atohl $netmask]

    set A $subnet_base
    set C [expr ($netmaskint >> 8) & 0xff]
    set D [expr $netmaskint & 0xff]
    set minB 1
    set maxB 254
    set minC 0
    set maxC 1
    set incC 1
    set minD 0
    set maxD 1
    set incD 1

    # allow for 10. or 192.168. I know, could be more general.
    if {[expr [llength [split $subnet_base .]]] == 2} {
	# 192.168.
	set A    [expr [lindex [split $subnet_base .] 0]]
	set minB [expr [lindex [split $subnet_base .] 1]]
	set maxB [expr $minB + 1]
    }
    if {$C != 0} {	
	set minC [expr 256 - $C]
	set maxC 255
	set incC $minC
    } 
    if {$D != 0} {	
	set minD [expr 256 - $D]
	set maxD 255
	set incD $minD
    }

    # We never let the user change the second octet. See tb-set-netmask.
    for {set i $minB} {$i < $maxB} {incr i} {
	for {set j $minC} {$j < $maxC} {set j [expr $j + $incC]} {
	    for {set k $minD} {$k < $maxD} {set k [expr $k + $incD]} {
		set subnet "$A.$i.$j.$k"
		set subnetint [inet_atohl $subnet]

		# No such subnet exists?
		if {! [info exists subnets($subnetint)]} {
		    set okay 1

		    #
		    # See if this subnet violates any existing subnet masks
		    # Is this overly restrictive? Totally wrong?
		    #
		    foreach osubnetint [concat [array names subnets]] {
			set onetmaskint $subnets($osubnetint)

			if {[expr $subnetint & $onetmaskint] == $osubnetint ||
 			    [expr $osubnetint & $netmaskint] == $subnetint} {
			    set okay 0
			    break
			}
		    }
		    if {$okay} {
			$self use_subnet $subnet $netmask
			return $subnet
		    }
		}
	    }
	}
    }
    perror "Ran out of subnets."
}

# get_subnet_remote
# This is called by lanlinks.  When called get_subnet will find an available
# IP subnet, mark it as used, and return it to the caller.
Simulator instproc get_subnet_remote {} {
    $self instvar wa_subnet_counter

    if {$wa_subnet_counter > 255} {
	perror "Ran out of widearea subnets."
	return 0
    }
    set subnet $wa_subnet_counter
    incr wa_subnet_counter
    return "69.69.$subnet.0"
}

# use_subnet
# This is called by the ip method of nodes.  It marks the passed subnet
# as used and thus should never be returned by get_subnet.
Simulator instproc use_subnet {subnet netmask} {
    $self instvar subnets

    set subnetint [inet_atohl $subnet]
    set netmaskint [inet_atohl $netmask]
    
    set subnets($subnetint) $netmaskint
}

# add_program
# Link to a new program object.
Simulator instproc add_program {prog} {
    $self instvar prog_list
    set prog_list($prog) {}
}

# add_disk
# Link to a new disk object.
Simulator instproc add_disk {disk} {
    $self instvar disk_list
    set disk_list($disk) {}
}

# add_custom
# Link to a new custom object.
Simulator instproc add_custom {custom} {
    $self instvar custom_list
    set custom_list($custom) {}
}

# add_eventgroup
# Link to a EventGroup object.
Simulator instproc add_eventgroup {group} {
    $self instvar eventgroup_list
    set eventgroup_list($group) {}
}

# add_console
# Link to a Console object.
Simulator instproc add_console {console} {
    $self instvar console_list
    set console_list($console) {}
}

# add_firewall
# Link to a Firewall object.
Simulator instproc add_firewall {fw} {
    $self instvar firewall_list

    if {[array size firewall_list] > 0} {
	perror "\[add_firewall]: only one firewall per experiment right now"
	return -1
    }

    set firewall_list($fw) {}
    return 0
}

Simulator instproc add_topography {tg} {
    $self instvar topography_list

    set topography_list($tg) {}

    return 0
}

Simulator instproc define-template-parameter {name args} {
    $self instvar parameter_list
    $self instvar parameter_descriptions
    var_import ::TBCOMPAT::parameter_list_defaults

    if {$args == {}} {
	perror "\[define-template-parameter] not enough arguments!"
	return
    }
    if {[llength $args] > 2} {
	perror "\[define-template-parameter] too many arguments!"
	return
    }
    set value [lindex $args 0]
    set description {}
    
    if {[llength $args] == 2} {
	set description [lindex $args 1]
    }

    if {[info exists parameter_list_defaults($name)]} {
	set value $parameter_list_defaults($name)
    }
    set parameter_list($name) $value
    set parameter_descriptions($name) $description
    
    # And install the name/value in the outer environment.
    uplevel 1 real_set \{$name\} \{$value\}
    
    return 0
}

Simulator instproc make_event {outer event} {
    var_import ::GLOBALS::simulated
    var_import ::TBCOMPAT::osids
    var_import ::TBCOMPAT::hwtype_class

    set obj [lindex $event 0]
    set cmd [lindex $event 1]
    set evargs [lrange $event 2 end]
    set vnode "*"
    set vname ""
    set otype {}
    set etype {}
    set args {}
    set atstring ""

    if {[string index $obj 0] == "#"} {
	return {}
    }

    if {$cmd == {}} {
	perror "Missing event type for $obj"
	return
    }

    if {[$obj info class] == "EventGroup"} {
	set cl [$obj set mytype]
    } else {
	set cl [$obj info class]
    }

    switch -- $cl {
	"Application/Traffic/CBR" {
	    set otype TRAFGEN
	    switch -- $cmd {
		"start" {
		    set etype START
		}
		"stop" {
		    set etype STOP
		}
		"reset" {
		    set etype RESET
		}
		"set" {
		    if {[llength $event] < 4} {
			perror "Wrong number of arguments: at $time $event"
			return
		    }
		    set etype MODIFY
		    set arg [lindex $event 3]
		    switch -- [lindex $event 2] {
			"packetSize_" {
			    set args  "PACKETSIZE=$arg"
			}
			"rate_" {
			    set bw [parse_bw $arg]
			    set args  "RATE=$bw"
			}
			"interval_" {
			    set args  "INTERVAL=$arg"
			}
			"iptos_" {
			    set args  "IPTOS=$arg"
			}
			unknown {
			    punsup "at $time $event"
			    return
			}
		    }
		}
		unknown {
		    punsup "at $time $event"
		    return
		}
	    }
	    set vnode [$obj get_node]
	    set vname $obj
	}
	"Agent/TCP/FullTcp" -
	"Agent/TCP/FullTcp/Reno" -
	"Agent/TCP/FullTcp/Newreno" -
	"Agent/TCP/FullTcp/Tahoe" -
	"Agent/TCP/FullTcp/Sack" - 
	"Application/FTP" -
	"Application/Telnet" {
	    # For events sent to NSE, we don't distinguish
	    # between START, STOP and MODIFY coz the entire
	    # string passed to '$ns at' is sent for evaluation to the node
	    # on which NSE is running: fix needed for the
	    # case when the above string has syntax errors. Maybe
	    # just have a way reporting errors back to the
	    # the user from the NSE that finds the syntax errors
	    set otype NSE
	    set etype NSEEVENT
	    set args "\$$obj $cmd [lrange $event 2 end]"
	    set vnode [$obj get_node]
	    set vname $obj
	}
	"EventSequence" {
	    set otype SEQUENCE
	    switch -- $cmd {
		"start" {
		    set etype START
		}
		"run" {
		    set etype RUN
		}
		"reset" {
		    set etype RESET
		}
		unknown {
		    punsup "$obj $cmd $evargs"
		    return
		}
	    }
	    set vnode {}
	    set vname $obj
	}
	"EventTimeline" {
	    set otype TIMELINE
	    switch -- $cmd {
		"start" {
		    set etype START
		}
		"run" {
		    set etype RUN
		}
		"reset" {
		    set etype RESET
		}
		unknown {
		    punsup "$obj $cmd $evargs"
		    return
		}
	    }
	    set vnode {}
	    set vname $obj
	}
	"Link" -
	"Lan" {
	    set otype LINK
	    set vnode {}
	    set vname $obj
	    
	    switch -- $cmd {
		"create"    {set etype CREATE}
		"clear"     {set etype CLEAR}
		"reset"     {set etype RESET}
		"up"	    {set etype UP}
		"down"	    {set etype DOWN}
		"bandwidth" {
		    if {[llength $event] < 4} {
			perror "Wrong number of arguments: at $time $event"
			return
		    }
		    set arg   [lindex $event 2]
		    set bw [parse_bw $arg]
		    set args  "BANDWIDTH=$bw"
		    set etype MODIFY
		}
		"delay" {
		    if {[llength $event] < 3} {
			perror "Wrong number of arguments: at $time $event"
			return
		    }
		    set arg   [lindex $event 2]
		    set args  "DELAY=$arg"
		    set etype MODIFY
		}
		"plr" {
		    if {[llength $event] < 3} {
			perror "Wrong number of arguments: at $time $event"
			return
		    }
		    if {[scan [lindex $event 2] "%f" plr] != 1 ||
		    $plr < 0 || $plr > 1} {
			perror "Improper argument: at $time $event"
			return
		    }
		    set args  "PLR=$plr"
		    set etype MODIFY
		}
		"trace" {
		    set otype LINKTRACE
		    set vname "${obj}-tracemon"

		    if {[llength $event] < 3} {
			perror "Wrong number of arguments: at $time $event"
			return
		    }
		    set action [lindex $event 2]

		    switch -- $action {
			"stop"	    {set etype STOP}
			"start"     {set etype START}
			"kill"	    {set etype KILL}
			"snapshot"  {set etype SNAPSHOT}
			unknown {
			    punsup "at $time $event"
			    return
			}
		    }
		}
		unknown {
		    punsup "at $time $event"
		    return
		}
	    }
	    $obj mustdelay
	}
	"Node" {
	    set otype NODE
	    switch -- $cmd {
		"reboot" {
		    set etype REBOOT
		}
		"snapshot-to" {
		    set etype SNAPSHOT
		    if {[llength $evargs] < 1} {
			perror "Wrong number of arguments: $obj $cmd $evargs"
			return
		    }
		    set image [lindex $evargs 0]
		    if {! ${GLOBALS::anonymous} && ! ${GLOBALS::passmode}} {
			if {![info exists osids($image)]} {
			    perror "Unknown image in snapshot-to event: $image"
			    return
			}
		    }
		    set args "IMAGE=${image}"
		}
		"reload" {
		    set etype RELOAD
		    ::GLOBALS::named-args $evargs {
			-image {}
		    }
		    if {$(-image) != {}} {
			if {! ${GLOBALS::anonymous} && 
			    ! ${GLOBALS::passmode} &&
			    ! [info exists osids($(-image))]} {
			    perror "Unknown image in reload event: $(-image)"
			    return
			}
			set args "IMAGE=$(-image)"
		    }
		}
		"setdest" {
		    set etype SETDEST
		    set topo [$obj set topo]
		    if {$topo == ""} {
			perror "$obj is not located on a topography"
			return
		    }
		    if {[llength $evargs] < 3} {
			perror "Wrong number of arguments: $obj $cmd $evargs; expecting - <obj> setdest <x> <y> <speed>"
			return
		    }
		    set x [lindex $evargs 0]
		    set y [lindex $evargs 1]
		    if {! [$topo checkdest $self $x $y -showerror 1]} {
			return
		    }
		    set speed [lindex $evargs 2]
		    if {$speed != 0.0 && ($speed < 0.1) && ($speed > 0.4)} {
			perror "Speed is currently locked at 0.0 or 0.1-0.4"
			return
		    }
		    ::GLOBALS::named-args [lrange $evargs 3 end] {
			-orientation 0
		    }
		    set args "X=$x Y=$y SPEED=$speed ORIENTATION=$(-orientation)"
		}
		unknown {
		    punsup "$obj $cmd $evargs"
		    return
		}
	    }
	    set vnode {}
	    set vname $obj
	}
	"Queue" {
	    set otype LINK
	    set node [$obj get_node]
	    set lanlink [$obj get_link]
	    set vnode {}
	    set vname "$lanlink-$node"
	    $lanlink mustdelay
	    switch -- $cmd {
		"set" {
		    if {[llength $event] < 4} {
			perror "Wrong number of arguments: at $time $event"
			return
		    }
		    set etype MODIFY
		    set arg [lindex $event 3]
		    switch -- [lindex $event 2] {
			"queue-in-bytes_" {
			    set args  "QUEUE-IN-BYTES=$arg"
			}
			"limit_" {
			    set args  "LIMIT=$arg"
			}
			"maxthresh_" {
			    set args  "MAXTHRESH=$arg"
			}
			"thresh_" {
			    set args  "THRESH=$arg"
			}
			"linterm_" {
			    set args  "LINTERM=$arg"
			}
			"q_weight_" {
			    if {[scan $arg "%f" w] != 1} {
				perror "Improper argument: at $time $event"
				return
			    }
			    set args  "Q_WEIGHT=$w"
			}
			unknown {
			    punsup "at $time $event"
			    return
			}
		    }
		}
		"trace" {
		    set otype LINKTRACE
		    set vname "${vname}-tracemon"

		    if {[llength $event] < 3} {
			perror "Wrong number of arguments: at $time $event"
			return
		    }
		    set action [lindex $event 2]

		    switch -- $action {
			"stop"	    {set etype STOP}
			"start"     {set etype START}
			"kill"	    {set etype KILL}
			"snapshot"  {set etype SNAPSHOT}
			unknown {
			    punsup "at $time $event"
			    return
			}
		    }
		}
		unknown {
		    punsup "at $time $event"
		    return
		}
	    }
	}
	"Program" {
	    set otype PROGRAM
	    set vname $obj
	    if {[$obj info class] == "EventGroup"} {
		set vnode "*"
	    } else {
		set vnode [$obj set node]
	    }
	    
	    switch -- $cmd {
		"set" -
		"run" -
		"start" {
		    switch -- $cmd {
			"set" {
			    set etype MODIFY
			}
			"run" {
			    set etype RUN
			}
			"start" {
			    set etype START
			}
		    }
		    if {[$obj info class] == "EventGroup"} {
			set default_command {}
		    } else {
			set default_command [$obj set command]
		    }
		    ::GLOBALS::named-args $evargs [list \
			-command $default_command \
			-dir {} \
			-timeout {} \
			-expected-exit-code {} \
			-tag {} \
		    ]
		    if {$(-dir) != {}} {
			set args "DIR={$(-dir)} "
		    }
		    if {$(-expected-exit-code) != {}} {
			set args "${args}EXPECTED_EXIT_CODE=$(-expected-exit-code) "
		    }
		    if {$(-tag) != {}} {
			set args "${args}TAG=$(-tag) "
		    }
		    if {$(-timeout) != {}} {
			set to [::GLOBALS::reltime-to-secs $(-timeout)]
			if {$to == -1} {
			    perror "-timeout value is not a relative time: $(-timeout)"
			    return
			} else {
			    set args "${args}TIMEOUT={$to} "
			}
		    }
		    # Put the command last so the program-agent can assume everything
		    # up to the end of the string is part of the command and we don't
		    # have to deal with quoting...  XXX
		    if {$(-command) != {}} {
			set args "${args}COMMAND=$(-command)"
		    }
		}
		"stop" {
		    set etype STOP
		}
		"kill" {
		    set etype KILL
		    if {[llength $event] < 3} {
			perror "Wrong number of arguments: at $time $event"
			return
		    }
		    set arg [lindex $event 2]
		    set args "SIGNAL=$arg"
		}
		unknown {
		    punsup "$obj $cmd $args"
		    return
		}
	    }
	}
	"Disk" {
	    set otype DISK
		set vname $obj
		set vnode [$obj set node]
		switch -- $cmd {
	    "set" -
	    "run" -
        "start" {
            switch -- $cmd {
            "set" {
                set etype START
             }
		     "run" {
			    set etype RUN
             }
             "start" {
                set etype START
             }
             }
		   
		    #The initial arguments for disk-agent through NS
 
            set default_name $obj 
		    set default_type [$obj set type]
		    set default_size [$obj set size]
		    set default_mountpoint [$obj set mountpoint]
		    set default_params [$obj set parameters]

		
			::GLOBALS::named-args $evargs [list \
				-name $default_name \
				-type $default_type \
				-size $default_size \
				-mountpoint $default_mountpoint \
				-parameters $default_params \
			]

			if {$(-name) != {}} {
				set args "DISKNAME=$(-name) "
			}
			if {$(-type) != {}} {
				set args "${args}DISKTYPE=$(-type) "
			}
			if {$(-size) != {}} {
				set args "${args}DISKSIZE=$(-size) "
			}
			if {$(-mountpoint) != {}} {
				set args "${args}MOUNTPOINT=$(-mountpoint) "
			}
			if {$(-parameters) != {}} {
				set args "${args}PARAMETERS=$(-parameters)"
			}  
			#DEBUG
		    puts stdout "$args"
		} 
		"create" {

			set etype CREATE
            #The initial arguments for disk-agent through NS

            set default_name $obj

            set args "DISKNAME=$default_name "
			set args "${args}DISKTYPE=  "
			set args "${args}DISKSIZE=  "
			set args "${args}MOUNTPOINT=  "	
			set args "${args}PARAMETERS=  "
     		set default_cmd [$obj set command]

			::GLOBALS::named-args $evargs [list \
				-command $default_cmd
			]

			if {$(-command) != {}} {
                set args "${args}COMMAND=$(-command)"
            }
			#DEBUG
		    puts stdout "$args"
     	}
		"modify" {
			set etype MODIFY
			#The initial arguments for disk-agent through NS

            set default_name $obj

            set args "DISKNAME=$default_name "
            set args "${args}DISKTYPE=  "
            set args "${args}DISKSIZE=  "
            set args "${args}MOUNTPOINT=  "
            set args "${args}PARAMETERS=  "
            set default_cmd [$obj set command]

            ::GLOBALS::named-args $evargs [list \
                -command $default_cmd
            ]

            if {$(-command) != {}} {
                set args "${args}COMMAND=$(-command)"
            }

			#DEBUG
		    puts stdout "$args"
	    }
        unknown {
            punsup "$obj $cmd $args"
            return
        }
        }   
    }
	# Modify this as you need.
	"Custom" {
        set otype CUSTOM
        set vname $obj
        set vnode [$obj set node]
        switch -- $cmd {
        "start" {
			set etype START
            set default_cmd [$obj set name]
            set args $default_cmd
            #DEBUG
            puts stdout "START: $args"
		}		
        "create" {
			set etype CREATE
            set default_cmd [$obj set name]
            set args $default_cmd
            #DEBUG
            puts stdout "CREATE: $args"
        }
        "modify" {
			set etype MODIFY
            set default_cmd [$obj set name]
            set args $default_cmd
            #DEBUG
            puts stdout "MODIFY: $args"
        }
        unknown {
            punsup "$obj $cmd $args"
            return
        }
	    }
	}
	"Console" {
	    set otype CONSOLE
	    set vname $obj

	    switch -- $cmd {
		"start" {
		    set etype START
		}
		"stop" {
		    set etype STOP
		    if {[llength $event] < 3} {
			perror "Wrong number of arguments: $obj $cmd $evargs"
			return
		    }
		    set arg [lindex $event 2]
		    set args "FILE=$arg"
		}
	    }
	}
	"Simulator" {
	    set vnode "*"
	    set vname $self
	    
	    switch -- $cmd {
		"bandwidth" {
		    set otype LINK
		    set etype MODIFY
		    set vnode {}
		    set vname {}
		}
		"halt" {
		    set otype SIMULATOR
		    set etype HALT
		}
		"terminate" {
		    set otype SIMULATOR
		    set etype HALT
		}
		"swapout" {
		    set otype SIMULATOR
		    set etype SWAPOUT
		}
		"stoprun" {
		    set otype SIMULATOR
		    set etype STOPRUN
		}
		"trace-for" {
		    set vname "slothd"
		    set otype SLOTHD
		    set etype START
		    if {[llength $event] < 3} {
			perror "Wrong number of arguments: $obj $cmd $evargs"
			return
		    }
		    set arg [lindex $event 2]
		    set args "DURATION=$arg"
		}
		"stabilize" {
		    set otype SIMULATOR
		    set etype MODIFY
		    set args "mode=stabilize"
		}
		"msg" -
		"message" {
		    set otype SIMULATOR
		    set etype MESSAGE
		    set args "[join $evargs]"
		}
		"log" {
		    set otype SIMULATOR
		    set etype LOG
		    set args "[join $evargs]"
		}
		"report" {
		    set otype SIMULATOR
		    set etype REPORT
		    ::GLOBALS::named-args $evargs {
			-digester {}
			-archive {}
		    }
		    if {$(-digester) != {}} {
			set args "DIGESTER={$(-digester)}"
		    }
		    if {$(-archive) != {}} {
			set args "ARCHIVE={$(-archive)} ${args}"
		    }
		    
		}
		"snapshot" {
		    set otype SIMULATOR
		    set etype SNAPSHOT
		    set args "LOGHOLE_ARGS='-s'"
		}		
		"cleanlogs" {
		    set otype SIMULATOR
		    set etype RESET
		    set args "ASPECT=LOGHOLE"
		}
		"linktest" {
		    set otype LINKTEST
		    set etype START
		    set vname "linktest"
		    ::GLOBALS::named-args $evargs {
			-bw 0
			-stopat 3
		    }
		    if {$(-bw) != 0} {
			set stopat 4
		    }
		    set args "STARTAT=1 STOPAT=$(-stopat)"
		}
		"reset-lans" {
		    set otype LINK
		    set vname "__all_lans"
		    set etype RESET
		}
		unknown {
		    punsup "$obj $cmd $evargs"
		    return
		}
	    }
	}
	unknown {
	    punsup "Unknown object type: $obj $cmd $evargs"
	    return
	}
    }

    if { $otype == "" } {
	perror "\[make_event] otype was empty; event $event, class $cl"
    }

    return [list $vnode $vname $otype $etype $args $atstring]
}

# cost
# Set the cost for a link
Simulator instproc cost {src dst c} {
    set reallink [$self find_link $src $dst]
    $reallink set cost([list $src [$reallink get_port $src]]) $c
}

# Now we have an experiment wide 
# simulation specification. Virtual to physical
# mapping will be done in later stages
Simulator instproc make-simulated {args} {

    var_import ::GLOBALS::simulated
    $self instvar nseconfig
    $self instvar simcode_present

    set simulated 1
    global script
    set script [string trim $args "\{\}"]

    if { $script == {} } {
        set simulated 0
        return
    }

    set simcode_present 1

    # we ignore any type of errors coz they have
    # been caught when we ran the script through NSE
    uplevel 1 $script

    append nseconfig $script
    append nseconfig \n

    set simulated 0
}

#
# Portal Stuff
#
Simulator instproc description {text} {
    $self instvar description

    set description $text
}

Simulator instproc instructions {text} {
    $self instvar instructions

    set instructions $text
}

#
# Spit out XML
#
Simulator instproc spitxml_init {} {
    var_import ::GLOBALS::pid
    var_import ::GLOBALS::eid

    # Add a marker so xmlconvert can tell where user output stops and
    puts "#### BEGIN XML ####"
    # ... XML starts.
    puts "<?xml version=\"1.0\" encoding=\"ISO-8859-1\"?>"
    puts "<virtual_experiment pid='$pid' eid='$eid'>"
}

Simulator instproc spitxml_finish {} {
    puts "</virtual_experiment>"
}

Simulator instproc spitxml_data {tag fields values} {
    ::spitxml_data $tag $fields $values
}

#
# Global function, cause some objects do not hold a sim pointer.
# Should fix.
# 
proc spitxml_data {tag fields values} {
    puts "  <$tag>"
    puts "    <row>"
    foreach field $fields {
	set value  [lindex $values 0]
	set values [lrange $values 1 end]
	set value_esc [xmlencode $value]

	puts "      <$field>$value_esc</$field>"
    }
    puts "    </row>"
    puts "  </$tag>"
}

proc xmlencode {args} {
    set retval [eval append retval $args]
    regsub -all "&" $retval "\\&amp;" retval
    regsub -all "<" $retval "\\&lt;" retval
    regsub -all ">" $retval "\\&gt;" retval
    regsub -all "\"" $retval "\\&\#34;" retval
    regsub -all "]" $retval "\\&\#93;" retval
    
    return $retval
}
