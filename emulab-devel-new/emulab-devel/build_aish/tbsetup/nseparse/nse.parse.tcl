#!/usr/local/bin/otclsh

#
# Copyright (c) 2000-2003 University of Utah and the Flux Group.
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
# nse.parse.tcl
#
# This is the testbed nse parser.  It takes a project id and an experiment
# id. It will parse the code in the nseconfigs table to partition the
# global per experiment nseconfigs into code that needs to go on the
# different partitions
# It also displays warnings for unsupported functionality.
#
# See README for extensive discussion of the structure and 
# implementation.
#
# -n will cause the parser to output error/warning messages and exit
#    without updating the database.
######################################################################

###
# lpop <listname>
# This takes the *name* of a list variable and pops the first element
# off of it, returning that element.
###
proc lpop {lv} {
    upvar $lv l
    set ret [lindex $l 0]
    set l [lrange $l 1 end]
    return $ret
}

# Initial Procedures

###
# var_import <varspec>
# This procedure takes a fully qualified variable name (::x::y::z..) and
# creates a variable z which is the same as the variable specified.  This
# fills the lack of variable importing support in 'namespace import'.
#
# Example:
#  proc a {} {
#    var_import ::GLOBALS::verbose
#    if {$verbose == 1} {puts "verbose is on."}
#  }
# is functionally identical to:
#  proc a {} {
#    if {${::GLOBALS::verbose} == 1} {puts "verbose is on."}
#  }
###
proc var_import {varspec} {
    uplevel "upvar $varspec [namespace tail $varspec]"
}

proc tb_nseparse_cleanup_and_exit {} {
    
    close ${GLOBALS::WARN_FILE}    
    exit ${GLOBALS::errors}
}

# Parse Arguments

# We setup a few globals that we need for argument parsing.
namespace eval GLOBALS {
variable verbose 1
variable impotent 0
variable anonymous 0
}

while {$argv != {}} {
    set arg [lindex $argv 0]
    if {$arg == "-n"} {
	lpop argv
	set GLOBALS::impotent 1
    } elseif {$arg == "-q"} {
	lpop argv
	set GLOBALS::verbose 0
    } elseif {$arg == "-a"} {
	lpop argv
	set GLOBALS::anonymous 1
    } else {
	break
    }
}

if {${GLOBALS::anonymous} && ! ${GLOBALS::impotent}} {
    puts stderr "-a can only be used with -n."
    exit 1
}

if {${GLOBALS::anonymous} && ([llength $argv] != 0)} {
    puts stderr "Syntax: $argv0 \[-q\] -n -a"
    exit 1
} elseif {(! ${GLOBALS::anonymous}) && ([llength $argv] != 4)} {
    puts stderr "Syntax: $argv0 \[-q\] \[-n \[-a\]\] pid eid defsfile nsfile"
    exit 1
}

# Now we can set up the rest of our global variables.
namespace eval GLOBALS {
    # Remaining arguments
    if {$anonymous} {
	variable pid "PID"
	variable eid "EID"
	variable defsfile [lindex $argv 0]
	variable nsfile [lindex $argv 1]
    } else {
	variable pid [lindex $argv 0]
	variable eid [lindex $argv 1]
	variable defsfile [lindex $argv 2]
	variable nsfile [lindex $argv 3]
    }

    # This is used to name class instances by the variables they
    # are stored in.  It contains the initial id of the most
    # recently created class.  See README
    variable last_class {}

    # This is used to store the last tcl command that was evaluated
    # so that nseconfigs could be appropriately rebuilt
    variable last_cmd {}

    # Some settings taken from configure.
    variable tbroot /users/achauhan/Cloudlab/CloudLabonESI/emulab-devel-new/emulab-devel/build_aish
    variable libnsedir /users/achauhan/Cloudlab/CloudLabonESI/emulab-devel-new/emulab-devel/build_aish/lib/nseparse

    # Is 1 if any errors have occured so far.
    variable errors 0
    
    # This is a counter used by the 'new' procedure to create null
    # classes.
    variable new_counter 0

    # This is the file handler for the warnings file
    variable WARN_FILE [open "$eid.warnings" a]

    # This is indexed by pnode and contains duplex-link and make-lan
    # code for each pnode that will be appended to the nseconfigs
    # that will go into the DB
    variable nseconfiglanlinks

}

# We want NullClass to instantiate proxy objects for real nodes
# that were present outside make-simulated and
# thus won't be part of the global nseconfigs that
# gets evaluated. This ensures we can ignore code that references
# real nodes
source ${GLOBALS::libnsedir}/nse.null.tcl
source ${GLOBALS::defsfile}

namespace eval GLOBALS {
    # virtual to physical mapping
    variable v2pmap
    # n(0) -> n-0 and n-0 -> n(0) mappings
    variable v2vmap
    # physical to virtual mapping for nodes that support sim nodes
    variable p2vmapsim
    # virtual node to type
    variable v2type

    variable v2pmap

    variable vnodetoip
    variable iptovnode
    
    # The v2pmapinfo contains sim vnode names that are mapped to
    # the physical nodes having a generated vname in the
    # reserved table. For sim nodes, they correspond to
    # nsenode0, 1 and so on. v2pmapinfo came from the DB
    # via tcl code passed to us
    set searchid [array startsearch v2pmapinfo]
    set vnode [array nextelement v2pmapinfo $searchid]
    while { $vnode != {} } {

	set vtype [lindex $v2pmapinfo($vnode) 0]
	set ipports [lindex $v2pmapinfo($vnode) 1]
	# Note that pnode here is the vname from the reserved table
	# as opposed to physical pc. This is appropriate since
	# "tmcc nseconfigs" from a pnode will be based on the vname
	# from the reserved table
	set pnode [lindex $v2pmapinfo($vnode) 2]

	set v2pmap($vnode) $pnode

	if { $vtype == "sim" } {
	    lappend p2vmapsim($pnode) $vnode
	} else {
	    # For nodes not in nseconfigs (thus are non "sim" nodes),
	    # we create a set of dummy NullClass objects so that
	    # if they are references in code inside the make-simulated
	    # block, we just either ignore it or store useful information
	    # in case one of them is of "sim"
	    set $vnode [NullClass $vnode RealNode]
	}
	set v2type($vnode) $vtype

	set portiplist [split $ipports " "]
	foreach portip $portiplist {
	    scan $portip "%\[^:]:%s" port ip

	    # used later in breaking duplex links and lans
	    set ips("$vnode:$port") $ip
	    lappend vnodetoip($vnode) $ip
	    set iptovnode($ip) $vnode
	}
	set vnode [array nextelement v2pmapinfo $searchid]
    }
    array donesearch v2pmapinfo $searchid

    set searchid [array startsearch lanlinks]
    set lanlink [array nextelement lanlinks $searchid]
    while {  $lanlink != {} } {
	if { [llength $lanlinks($lanlink)] == 2 } {
	    scan [lindex $lanlinks($lanlink) 0] "%\[^:]:%s" node1 port1
	    scan [lindex $lanlinks($lanlink) 1] "%\[^:]:%s" node2 port2	    
	    set nodes12 [lsort [list $node1 $node2]]
	    set link_map($node1:$node2) $lanlink
	    set link_map($node2:$node1) $lanlink
	} else {
	    set nodelist {}
	    foreach member [lsort $lanlinks($lanlink)] {
		scan $member "%\[^:]:%s" node port
		lappend nodelist $node
	    }
	    set lanstring [join [lsort $nodelist] ":"]
	    set lan_map($lanstring) $lanlink
	}
	set lanlink [array nextelement lanlinks $searchid]
    }
    array donesearch lanlinks $searchid

    variable event_list
    variable virt_agents_list
}

###
# perror <msg>
# Print an error message and mark as failed run.
###
proc perror {msg} {
    var_import ::GLOBALS::errors 

    global argv0
    puts stderr "*** $argv0: "
    puts stderr "    $msg"
    set errors 1
}

###
# punsup {msg}
# Print an unsupported message.
###
proc punsup {msg} {
    var_import ::GLOBALS::verbose
    var_import ::GLOBALS::WARN_FILE

    # If this was a true error in specifying
    # the simulation, it would have been
    # caught when run with NSE
    if {$verbose == 1} {
	puts stderr "*** WARNING: Unsupported NSE Statement!"
	puts stderr "    $msg"
	puts $WARN_FILE "*** WARNING: Unsupported NSE Statement!"
	puts $WARN_FILE "    $msg"
    }
}	

# Load all our classes
source ${GLOBALS::libnsedir}/nse.sim.tcl
source ${GLOBALS::libnsedir}/nse.node.tcl
source ${GLOBALS::libnsedir}/nse.agent.tcl
source ${GLOBALS::libnsedir}/tb_compat.tcl

##################################################
# Redifing Assignment
#
# Here we rewrite the set command.  The global variable 'last_class'
# holds the name instance created just before set.  If last_class is set
# and the value of the set call is last_class then the value should be
# changed to the variable and the class renamed to the variable.  I.e.
# we are making it so that NS objects are named by the variable they
# are stored in.
#
# We only do this if the level above is the global level.  I.e. if
# class are created in subroutines they keep their internal names
# no matter what.
#
# We munge array references from ARRAY(INDEX) to ARRAY-INDEX.
#
# Whenever we rename a class we call the rename method.  This method
# should update all references that it may have set up to itself.
#
# See README
##################################################
rename set real_set
proc set {args} {
    var_import GLOBALS::last_class
    var_import GLOBALS::last_cmd
    var_import GLOBALS::v2vmap

    # There are a bunch of cases where we just pass through to real set.
    if {[llength $args] == 1} {
	return [uplevel real_set \{[lindex $args 0]\}]
    } elseif {($last_class == {})} {
	return [uplevel real_set \{[lindex $args 0]\} \{[lindex $args 1]\}]
    }

    real_set var [lindex $args 0]
    real_set val [lindex $args 1]

    # Run the set to make sure variables declared as global get registered
    # as global (does not happen until first set).
    real_set ret [uplevel real_set \{$var\} \{$val\}]

    $last_class set objname $var

    regsub -all {[\(]} $var {-} out
    real_set sub [regsub -all {[\)]} $out {} outname]
    if { $sub > 0 } {
	real_set v2vmap($var) $outname
	real_set v2vmap($outname) $var
    } else {
	real_set v2vmap($var) $var
    }
    
    # Reset last_class in all cases.
    real_set last_class {}
    real_set last_cmd {}
    
    return $ret
}

###
# new <class> ...
# NS defines the new command to create class instances.  If the call is
# for an object we know about we create and return an instance.  For 
# any classes we do not know about we create a null class and return it
# as well as display an unsupported message.
#
# new_classes is an array in globals that defines the classes
# new should support.  The index is the class name and the value
# is the argument list.
#
# TODO: Implement support for classes that take arguments.  None yet
# in supported NS subset.
###
namespace eval GLOBALS {
    variable new_classes
    real_set new_classes(Simulator) {}
    real_set new_classes(Node) {}
    real_set new_classes(Lan) {}
    real_set new_classes(Link) {}
    real_set new_classes(Agent) {}
    real_set new_classes(Application) {}
}

proc new {class args} {
    var_import GLOBALS::new_counter
    var_import GLOBALS::new_classes
    var_import GLOBALS::last_cmd

    real_set classlist [array names new_classes]

    foreach cls $classlist {
	real_set ret1 [string match "$cls" $class]
	real_set ret2 [string match "$cls/*" $class]

	if { $ret1 || $ret2 } {
	    real_set id $cls[incr new_counter]
	    real_set last_cmd "\[new $class $args]"
	    eval $cls $id $args
	    $id set classname $class
	    return $id
	}
    }

    real_set id null[incr new_counter]
    NullClass $id $class
    return $id
}

# We now have all our infrastructure in place.  We are ready to load
# the NSE file from what was passed to us

if { ${GLOBALS::errors} != 1 } {
    source ${GLOBALS::nsfile}
}

if { ${GLOBALS::impotent} == 1 } {
    # this will clean up and exit
    tb_nseparse_cleanup_and_exit
}

namespace eval GLOBALS {

    # global nseconfig one per pnode
    variable nseconfig 
    
    # now get nseconfig per pnode and put it into the db accordingly
    real_set sim [lindex [Simulator info instances] 0]
    foreach pnode [array names p2vmapsim] {
	real_set nseconfig($pnode) {}
	if { [$sim info vars rtslop] != {} } {
		append nseconfig($pnode) "Scheduler/RealTime set maxslop_ [$sim set rtslop]\n\n"
	}
	append nseconfig($pnode) "set [$sim set objname] [$sim set createcmd]\n"
	# Since we will be adding IP address based routes, any ns default
	# routing causes problems
	append nseconfig($pnode) "\$[$sim set objname] rtproto Manual\n"
	append nseconfig($pnode) \
		    "\$[$sim set objname] set tbname \{$v2vmap([$sim set objname])\}\n"
	append nseconfig($pnode) "[$sim set nseconfig]\n\n"
	
	# XXX temporary hack
	append nseconfig($pnode) "Agent/TCP set QOption_ 1\n\n"
    }
    
    real_set ignore_class_vars(id_counter) {}
    real_set ignore_class_vars(nseconfig) {}
    real_set ignore_class_vars(classname) {}
    real_set ignore_class_vars(objname) {}
    real_set ignore_class_vars(createcmd) {}
    real_set ignore_class_vars(agentlist) {}
    real_set ignore_class_vars(node) {}
    real_set ignore_class_vars(application) {}
    real_set ignore_class_vars(destination) {}
    real_set ignore_class_vars(next_portnumber) {}
    real_set ignore_class_vars(ip) {}
    real_set ignore_class_vars(port) {}
    real_set ignore_class_vars(agent) {}
   
    foreach node [Node info instances] {
	real_set pnode $v2pmap($v2vmap([$node set objname]))
	
	if { $pnode != {} } {
	    append nseconfig($pnode) "set [$node set objname] [$node set createcmd]\n"

	    #foreach ip $vnodetoip([$node set objname]) {
		#append nseconfig($pnode) "\$[$sim set objname] add-ip $ip \$[$node set objname]\n"
	    #}

	    append nseconfig($pnode) \
		    "\$[$node set objname] set tbname \{$v2vmap([$node set objname])\}\n"

	    foreach var [$node info vars] {
		if { [info exists ignore_class_vars($var)] } {
		    continue
		}
		
		real_set array_names [$node array name $var]
		if { $array_names != {} } {
		    foreach name $array_names {
			append nseconfig($pnode) \
				"\$[$node set objname] set $var($name) \{[$node set $var($name)]\}\n"
		    }
		} else {
		    append nseconfig($pnode) \
			    "\$[$node set objname] set $var \{[$node set $var]\}\n"
		}
	    }
	    append nseconfig($pnode) "[$node set nseconfig]\n\n"
	    
	}
    }

    foreach pnode [array names nseconfiglanlinks] {
	append nseconfig($pnode) $nseconfiglanlinks($pnode)
    }
    
    foreach pnode [array names nseconfigrlinks] {
	append nseconfig($pnode) "\n"
	append nseconfig($pnode) $nseconfigrlinks($pnode)
    }

    variable link_visited
    # links between sim and real nodes
    foreach nodes [array names link_map] {
	scan $nodes "%\[^:]:%s" node0 node1
	if { ($v2type($node0) != "sim" && $v2type($node1) != "sim") ||
  	     ($v2type($node0) == "sim" && $v2type($node1) == "sim") } {
	    # We only want links between sim and real nodes, not
	    # sim-to-sim or real-to-real
	    continue
	}
	if { [info exists link_visited($node0:$node1)] } {
	    continue
	}
	real_set link_visited($node0:$node1) 1
	real_set link_visited($node1:$node0) 1
	real_set lanlink $link_map($node0:$node1)
	scan [lindex $lanlinks($lanlink) 0] "%\[^:]:%s" node0 port0
	scan [lindex $lanlinks($lanlink) 1] "%\[^:]:%s" node1 port1
	if { $v2type($node0) == "sim" } {
	    real_set srcvnode $node0
	    real_set srcport $port0
	    real_set dstvnode $node1
	    real_set dstport $port1
	} else {
	    real_set srcvnode $node1
	    real_set srcport $port1
	    real_set dstvnode $node0
	    real_set dstport $port0
	}
	real_set pnode $v2pmap($srcvnode)
	real_set srcip $ips("$srcvnode:$srcport")
	real_set dstip $ips("$dstvnode:$dstport")
	real_set srcvnode_actual $v2vmap($srcvnode)
	append nseconfig($pnode) "set $lanlink \[\$[$sim set objname] rlink \$$srcvnode_actual $dstip]\n"
	append nseconfig($pnode) "\$\{$lanlink\} set-ip $srcip\n"
    }

    foreach pnode [array names p2vmapsim] {
	append nseconfig($pnode) "\n"
    }

    foreach agent [Agent info instances] {
	set node [$agent get_node]
	set vnode_actual $v2vmap([$node set objname])
	set pnode $v2pmap($vnode_actual)
	append nseconfig($pnode) "set [$agent set objname] [$agent set createcmd]\n"

	append nseconfig($pnode) \
		"\$[$agent set objname] set tbname \{$v2vmap([$agent set objname])\}\n"
	
	foreach var [$agent info vars] {
	    if { [info exists ignore_class_vars($var)] } {
		continue
	    }

	    real_set array_names [$agent array name $var]
	    if { $array_names != {} } {
		foreach name $array_names {
		    append nseconfig($pnode) \
			    "\$[$agent set objname] set $var($name) \{[$agent set $var($name)]\}\n"
		}
	    } else {
		append nseconfig($pnode) \
			"\$[$agent set objname] set $var \{[$agent set $var]\}\n"
	    }
	}
	
	if { [$agent set nseconfig] != {} } {
	    append nseconfig($pnode) [$agent set nseconfig]
	}
	set app [$agent set application]
	if { $app != {} } {
	    append nseconfig($pnode) "set [$app set objname] [$app set createcmd]\n"

	    append nseconfig($pnode) \
		    "\$[$app set objname] set tbname \{$v2vmap([$app set objname])\}\n"
	    
	    foreach var [$app info vars] {
		if { [info exists ignore_class_vars($var)] } {
		    continue
		}

		real_set array_names [$app array name $var]
		if { $array_names != {} } {
		    foreach name $array_names {
			append nseconfig($pnode) \
				"\$[$app set objname] set $var($name) \{[$app set $var($name)]\}\n"
		    }
		} else {
		    append nseconfig($pnode) \
			    "\$[$app set objname] set $var \{[$app set $var]\}\n"
		}
	    }
	    
	    if { [$app set nseconfig] != {} } {
		append nseconfig($pnode) [$app set nseconfig]
	    }
	}
    }


    # lans

    $sim spitxml_init
    foreach pnode [array names nseconfig] {
	
	append nseconfig($pnode) "set simcode_present 1\n\n"
	
	$sim spitxml_data "nseconfigs" [list "vname" "nseconfig"] [list $pnode $nseconfig($pnode)]
    }

    if { [array exists event_list] } {
	real_set searchid [array startsearch event_list]
	real_set vname [array nextelement event_list $searchid]
	while { $vname != {} } {

	    foreach event $event_list($vname) {
               if {[string equal [lindex $event 0] "swapout"]} {
                       set event [lreplace $event 0 0 0]
                       set triggertype "SWAPOUT"
               } else {
                       set triggertype "TIMER"
                }
               set fields [list "time" "vnode" "vname" "objecttype" "eventtype" "arguments" "atstring" "triggertype" ]

		real_set time [lindex $event 0]
		real_set otype [lindex $event 1]
		real_set etype [lindex $event 2]
		real_set args [lindex $event 3]
		real_set atstring [lindex $event 4]

		# We can directly do a switch on the class type of vname
		switch -- [$vname info class] {
		    Agent -
		    Application {
			real_set vnode $v2vmap([[$vname get_node] set objname])
		    }
		    Node {
			real_set vnode $v2vmap([$vname set objname])
		    }
		}

		# Here pnode is the same as what is in the
		# reserved table
		real_set pnode $v2pmap($vnode)

		if { ! [info exists virt_agents_list($vname)] } {
		    $sim spitxml_data "virt_agents" [list "vnode" "vname" "objecttype"] [list $pnode [$vname set objname] $otype]
		    # We don't want duplicate entries in the virt_agents
		    # table
		    real_set virt_agents_list($vname) {}

		    real_set agt [$vname set agent]
		    if { ! [info exists virt_agents_list($agt)] } {
		    	$sim spitxml_data "virt_agents" [list "vnode" "vname" "objecttype"] [list $pnode [$agt set objname] $otype]
			real_set virt_agents_list($agt) {}
		    }
		}
		$sim spitxml_data "eventlist" [list "time" "vnode" "vname" "objecttype" "eventtype" "triggertype" "arguments" "atstring" ] [list $time $pnode [$vname set objname] $otype $etype $triggertype $args $atstring]
	    }

	    real_set vname [array nextelement event_list $searchid]
	}
	array donesearch event_list $searchid
    }
    real_set otype $objtypes(NSE)
    foreach pnode [array names p2vmapsim] {
	$sim spitxml_data "virt_agents" [list "vnode" "vname" "objecttype"] [list $pnode $pnode $otype]
    }

    $sim spitxml_finish
}
    
tb_nseparse_cleanup_and_exit
