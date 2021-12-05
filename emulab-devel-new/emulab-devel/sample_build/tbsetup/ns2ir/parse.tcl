#!/usr/local/bin/otclsh

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
# parse.tcl.in
#
# This is the testbed parser.  It takes a project id, an experiment
# id and a NS file.  It will parse the NS file and update the DB.
# It also displays warnings for unsupported functionality.
#
# See README for extensive discussion of the structure and 
# implementation.
#
# -q quiet mode: supress all the unsupported messages.
# -n impotent mode: parser will output error/warning messages and exit
#    without spitting out the actual parse results.
# -a anonymous mode: do not do project related checks. Turns on impotent
#    mode (-n).
# -p pass mode: Similar to anonymous mode, except that the parser *will*
#    spit out the parse results.
# -r rspecmode. 
######################################################################

proc usage {} {
    puts stderr "Syntax: $argv0 \[-q\] -a ns_file"    
    puts stderr "        $argv0 \[-q\] \[-p\] \[-n\] pid gid eid ns_file"
    exit 1
}

# Initial Procedures

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

###
# var_import <varspec>
# This procedure takes a fully qualified variable name (::x::y::z..) and
# creates a variable z which is the same as the variable specified.  This
# fills the lack of variable importing support in 'namespace import'.
#
# Example:
#  proc a {} {
#    var_import ::GLOBALS::verbose
#    if {$verbose == 1} {puts stderr "verbose is on."}
#  }
# is functionally identical to:
#  proc a {} {
#    if {${::GLOBALS::verbose} == 1} {puts stderr "verbose is on."}
#  }
###
proc var_import {varspec} {
    uplevel "upvar $varspec [namespace tail $varspec]"
}

###
# perror <msg>
# Print an error message and mark as failed run.
###
proc perror {msg} {
    var_import ::GLOBALS::errors 
    var_import ::GLOBALS::simulated

    # If this was a true error in specifying
    # the simulation, it would have been
    # caught when run with NSE
    if { $simulated == 1 } {
	return 0
    }

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
    var_import ::GLOBALS::simulated

    # If this was a true error in specifying
    # the simulation, it would have been
    # caught when run with NSE
    if {$simulated == 0 && $verbose == 1} {
	puts stderr "*** WARNING: Unsupported NS Statement!"
	puts stderr "    $msg"
    }
}	

#
# We ignore unsupported tcl commands if it is inside
# make-simulated else error is flagged i.e. we call 
# perror which does the right thing
#
proc unknown {args} {
    error "Unknown: $args"
}

# Parse Arguments

# We setup a few globals that we need for argument parsing.
namespace eval GLOBALS {
variable verbose 1
variable impotent 0
variable anonymous 0
variable passmode 0
variable rspecmode 0
variable vtype_list {}
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
	set GLOBALS::impotent 1
    } elseif {$arg == "-p"} {
	lpop argv
	set GLOBALS::passmode 1
    } elseif {$arg == "-r"} {
	lpop argv
	set GLOBALS::rspecmode 1
    } else {
	break
    }
}

if {${GLOBALS::anonymous} && ([llength $argv] != 1)} {
    usage();
} elseif {(! ${GLOBALS::anonymous}) && ([llength $argv] != 4)} {
    usage();
}

# Now we can set up the rest of our global variables.
namespace eval GLOBALS {
    # Remaining arguments
    if {$anonymous} {
	variable pid "PID"
	variable gid "GID"
	variable eid "EID"
	variable nsfile [lindex $argv 0]
    } else {
	variable pid [lindex $argv 0]
	variable gid [lindex $argv 1]
	variable eid [lindex $argv 2]
	variable nsfile [lindex $argv 3]
    }
    
    # This is used to name class instances by the variables they
    # are stored in.  It contains the initial id of the most
    # recently created class.  See README
    variable last_class {}

    # Some settings taken from configure.
    variable tbroot /users/mshobana/CloudLabonESI/emulab-devel-new/emulab-devel/sample_build
    variable libdir /users/mshobana/CloudLabonESI/emulab-devel-new/emulab-devel/sample_build/lib/ns2ir
    variable disablense {1}

    # This is the location of the tb_compat.tcl file.  It is copied
    # into the same directory is the ns file so that the initial
    # 'source tb_compat.tcl' statement succeeds.
    variable tbcompat "$libdir/tb_compat.tcl"

    # This is used in running the script through nse for syntax errors
    variable nstbcompat "$libdir/nstb_compat.tcl"

    # Is 1 if any errors have occured so far.
    variable errors 0
    
    # Is 1 after a 'Simulator run' command.
    variable ran 0

    # This is a counter used by the 'new' procedure to create null
    # classes.
    variable new_counter 0

    # These are going to be default values within the NS file.
    variable default_ip_routing_type "none"

    # For remote nodes. Use latest widearea data.
    variable uselatestwadata 1

    # For remote nodes. Use tunnels
    variable usewatunnels 0

    # Use link delays instead of delay nodes.
    variable uselinkdelays 0

    # Force link delays (where a delay would not otherwise be inserted)
    variable forcelinkdelays 0

    # Control multiplex_factor for the experiment. Crude.
    variable multiplex_factor {}

    # Control packing strategy for the experiment. pack or balance.
    variable packing_strategy {}

    # The name of the sync_server
    variable sync_server {}

    # Whether or not use use ipassign
    variable use_ipassign 0

    # Arguments to pass to ipassign
    variable ipassign_args {}

    # For remote nodes. The solver weights.
    variable wa_delay_solverweight 1
    variable wa_bw_solverweight	   7
    variable wa_plr_solverweight   500

    # This distinguishes whether the script that
    # is being parsed should go into a NSE simulation or not
    variable simulated 0

    # Hidden variable to relax some restrictions for debugging.
    variable enforce_user_restrictions 1

    # CPU and MEM usage values. Zero means ignore. For now, lets make
    # it an integer, 1 <= x <= 5.
    variable cpu_usage 3
    variable mem_usage 0

    # Flag to disable doing a fix-node
    variable fix_current_resources 1

    # Control virtual link encapsulation
    # XXX "default" is for backward compat so we can distinguish
    # specified vs. unspecified in assign_wrapper
    variable vlink_encapsulate "default"

    # Allow override of jail, delay, simnode osids.
    variable jail_osname {}
    variable delay_osname {}
    variable sim_osname "FBSD-STD"

    # Allow override of delay capacity.
    variable delay_capacity {}

    # Use phys naming
    variable use_physnaming 0

    # Modelnet support. Number of physical core and edge nodes that user
    # wants thrown at the problem.
    variable modelnet_cores 0
    variable modelnet_edges 0

    # Is an inner elab experiment.
    variable elab_in_elab 0
    variable elabinelab_topo ""
    variable elabinelab_eid {}
    variable elabinelab_cvstag {}
    variable elabinelab_singlenet 0
    variable elabinelab_fw_type "ipfw2-vlan"

    # Disable NFS mounts for experiment?
    variable nonfs 0

    # Does user want a per-experiment DB?
    variable dpdb 0

    # Security level. Defaults to 0 ("green")
    # If explicit_firewall is set, then you cannot also give a security level.
    # security_level_diskzap is the level at which we need to zap the disk
    #  at swapout time.  This value (2) is encoded in libdb.pm also.
    variable security_level 0
    variable explicit_firewall 0
    variable security_level_diskzap 2

    # List of source files.
    variable sourcefile_list {}

    variable optarray_order
    array set optarray_order {}
    variable optarray_count 0

    #
    # Named argument helper function.
    #
    # Example:
    #
    #  proc replace {s args} {
    #    named $args {-from 0 -to end -with ""}
    #    string replace $s $(-from) $(-to) $(-with)
    #  }
    #
    #  % replace suchenwirth -from 4 -to 6 -with xx
    #  suchxxirth
    #  % replace suchenwirth -from 4 -to 6 -witha xx
    #  bad option '-witha', should be one of: -from -to -with
    #
    # @param args The optional arguments the caller received.
    # @param defaults The option list with default values.
    #
    # @see http://wiki.tcl.tk/10702
    #
    proc named-args {args defaults} {
	upvar 1 "" ""
	array set "" $defaults
	foreach {key value} $args {
	    if {![info exists ($key)]} {
		error "bad option '$key', should be one of: [lsort [array names {}]]"
	    }
	    set ($key) $value
	}
    }

    #
    # Convert a string that represents a relative time into the corresponding
    # number of seconds.  The input string can simply be a number or it can
    # be in a more human readable format.  The only format supported at the
    # moment is "<hours>h<mins>m<secs>s".
    #
    # Examples:
    #
    #  % puts "[reltime-to-secs 20]"
    #  20
    #  % puts "[reltime-to-secs 2m]"
    #  120
    #  % puts "[reltime-to-secs 1h20m3s]"
    #  4803
    #
    # @param reltime A string representing a relative time value.
    # @return The relative time in seconds or -1 if the string could not be
    # parsed.
    #
    proc reltime-to-secs {reltime} {
	if {[regexp {(^[0-9]+(\.[0-9]+)?$)|(^\.[0-9]+$)} $reltime]} {
	    set retval $reltime
	} elseif {
	    [regexp {^([0-9]+h)?([0-9]+m)?([0-9]+s)?$} $reltime d hours mins secs]} {
		if {$hours == ""} {
		    set hours "0h"
		}
		if {$mins == ""} {
		    set mins "0m"
		}
		if {$secs == ""} {
		    set secs "0s"
		}
		set hours [string trim $hours h]
		set mins [string trim $mins m]
		set secs [string trim $secs s]
		set retval [expr ($hours * 60 * 60) + ($mins * 60) + $secs]
	} else {
	    set retval -1
	}
	return $retval
    }
}

# Load all our classes
source ${GLOBALS::libdir}/nsobject.tcl
source ${GLOBALS::libdir}/sim.tcl
source ${GLOBALS::libdir}/lanlink.tcl
source ${GLOBALS::libdir}/path.tcl
source ${GLOBALS::libdir}/node.tcl
source ${GLOBALS::libdir}/null.tcl
source ${GLOBALS::libdir}/traffic.tcl
source ${GLOBALS::libdir}/vtype.tcl
source ${GLOBALS::libdir}/program.tcl
source ${GLOBALS::libdir}/event.tcl
source ${GLOBALS::libdir}/firewall.tcl
source ${GLOBALS::libdir}/timeline.tcl
source ${GLOBALS::libdir}/sequence.tcl
source ${GLOBALS::libdir}/console.tcl
source ${GLOBALS::libdir}/topography.tcl
source ${GLOBALS::libdir}/disk.tcl
source ${GLOBALS::libdir}/blockstore.tcl
source ${GLOBALS::libdir}/custom.tcl

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
    var_import GLOBALS::optarray_order
    var_import GLOBALS::optarray_count

    # There are a bunch of cases where we just pass through to real set.
    if {[llength $args] == 1} {
	return [uplevel real_set \{[lindex $args 0]\}]
    } elseif {($last_class == {})} {
	real_set var [lindex $args 0]
	real_set val [lindex $args 1]

	#
	# This is the special OPT array, which we need to keep ordered
	# when inserting into the DB.
	#
	if {[regexp {^opt\(([-_0-9a-zA-Z]+)\)} $var d optname]} {
	    real_set optarray_order($optarray_count) $optname
	    incr optarray_count
	}
	return [uplevel real_set \{$var\} \{$val\}]
    }

    real_set var [lindex $args 0]
    real_set val [lindex $args 1]

    # Run the set to make sure variables declared as global get registered
    # as global (does not happen until first set).
    real_set ret [uplevel real_set \{$var\} \{$val\}]

    # Rename happens only when assigning to a global variable. Because of
    # array syntax, must strip parens and indices to get the base variable
    # name (has no effect if not an array access).
    real_set l [split $var \(]
    real_set base_var [lindex $l 0]

    # Now check to see if its a global. No renaming if not a global.
    if {[uplevel info globals $base_var] == {}} {
        return $ret
    }
    
    # At this point this is an assignment immediately after class creation.
    if {$val == $last_class} {
	# Here we change ARRAY(INDEX) to ARRAY-INDEX
	regsub -all {[\(]} $var {-} out
	regsub -all {[\)]} $out {} val

	# Sanity check
	if {! [catch "uplevel info args $val"]} {
	    error "Already have an object named $val."
	}
	# And now we rename the class.  After the class has been
	# renamed we call it its rename method.
	uplevel rename $last_class $val
	uplevel $val rename $last_class $val
    }
    
    # Reset last_class in all cases.
    real_set last_class {}
    
    # And finally we pass through to the actual assignment operator.
    return [uplevel real_set \{$var\} \{$val\}]
}

##################################################
# Redifing source
#
# Trap the "source" command so that we can tell the boss-side caller about
# any ns files it has to capture and archive.
#
##################################################
rename source real_source
proc source {args} {
    var_import GLOBALS::sourcefile_list

    #
    # Record the name for later.
    #
    # XXX Do not record the tb_compat file ...
    #
    if {[lindex $args 0] != "tb_compat.tcl"} {
	lappend sourcefile_list [lindex $args 0]
    }

    #
    # The run real command returning value.
    #
    return [uplevel real_source \{[lindex $args 0]\}]
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
    set new_classes(Simulator) {}
}
proc new {class args} {
    var_import GLOBALS::new_counter
    var_import GLOBALS::new_classes
    if {! [info exists new_classes($class)]} {
	punsup "Object: $class"
	set id null[incr new_counter]
	NullClass $id $class
	return $id
    }

    set id $class[incr new_counter]

    # XXX Hack!
    if {[llength $args] > 1} {
	punsup "arguments for $class"
    } elseif {[llength $args] == 1} {
	eval $class $id [lindex $args 0]
    } else {
	eval $class $id 
    }
    return $id
}

# Useful routines.

# parse_bw bspec 
# This takes a bandwidth specifier in the form of <amt><unit> where
# <unit> is any of b, bps, kb, kbps, Mb, Mbps, Gb, or Gbps.  If no
# unit is given then bytes (b) is assumed.  It returns the bandwidth
# in Kbps.
proc parse_bw {bspec {islink 1}} {
    #
    # Special cases 
    #
    # "*" means let assign pick the bandwidth. Make it zero.
    # "~" means "best effort" bandwidth - not conservatively allocated.
    #
    if {"$bspec" == "*"} {
	return 0
    } 
    if {"$bspec" == "~"} {
	# XXX: this is not the right way to handle this.  However, since
	# it's only supposed to be used for sanlans with no shaping
	# (enforced in lanlink.tcl), this is WAAAY easier than trying
	# to feed some new flag or sentinel value down into the guts
	# of the mapper.
	return 10
    }

    # Default to bytes
    if {[scan $bspec "%f%s" bw unit] == 1} {
	set unit b
    }

    # We could do better below with a regexp match. But it is better to keep it simple.
    switch -- $unit {
	b {set val [expr int($bw/1000)]} 
	bps {set val [expr int($bw/1000)]} 
	k {set val [expr int($bw)]}
	kb {set val [expr int($bw)]}
	kbps {set val [expr int($bw)]}
	K {set val [expr int($bw)]}
	Kb {set val [expr int($bw)]}
	Kbps {set val [expr int($bw)]}
	M {set val [expr int($bw*1000)]}
	Mb {set val [expr int($bw*1000)]}
	Mbps {set val [expr int($bw*1000)]}
	G {set val [expr int($bw*1000000)]}
	Gb {set val [expr int($bw*1000000)]}
	Gbps {set val [expr int($bw*1000000)]}
	default {
	    perror "Unknown bandwidth unit $unit."
	    set val 100000
	}
    }

    if {$val < 10 && $islink} {
	perror "Bandwidth of $val Kbs is too low."
	return 0
    }
    return $val
}

proc parse_backfill {bspec} {
    return [parse_bw $bspec 0]
}

# parse_delay dspec
# This takes a delay specifier in the form of <amt><unit> where <unit>
# is any of s, ms, ns.  If no unit is given then seconds (s) is
# assumed.  It returns the delay in ms.
proc parse_delay {dspec} {
    # Default to seconds
    if {[scan $dspec "%f%s" delay unit] == 1} {
	set unit s
    }
    switch $unit {
	s {set val [expr $delay*1000]}
	ms {set val $delay}
	ns {set val [expr $delay/1000]}
	default {
	    perror "Unknown delay unit $unit."
	    return 0
	}
    }
    if {$val != 0 && $val < 2} {
	perror "The delay of ${val}ms is invalid, it must be either 0 or at least 2ms."
	return 0
    }
    return [expr int($val)]
}

# convert_to_mebi
# This takes a data size specifier in the form of <amt><unit> where
# <unit> is any of [B, KB, KiB, MB, MiB, GB, GiB, TB, TiB].  If no
# unit is given then bytes (B) is assumed.  It returns the size
# in Mebibytes.  Data sizes in bits (lowercase b) are not handled (yet).
proc convert_to_mebi {size} {
    # Default to bytes
    if {[scan $size "%f%s" sz unit] == 1} {
	set unit B
    }

    switch -- $unit {
	B   {set val [expr int($sz / pow(2,20))}
	KB  {set val [expr int($sz * pow(10,3) / pow(2,20))]}
	KiB {set val [expr int($sz / pow(2,10))]}
	MB  {set val [expr int($sz * pow(10,6) / pow(2,20))]}
	MiB {set val [expr int($sz)]}
	GB  {set val [expr int($sz * pow(10,9) / pow(2,20))]}
	GiB {set val [expr int($sz * pow(2,10))]}
	TB  {set val [expr int($sz * pow(10,12) / pow(2,20))]}
	TiB {set val [expr int($sz * pow(2,20))]}
	default {
	    perror "Unknown size unit $unit."
	    set val 0
	}
    }

    return $val
}

# We now have all our infrastructure in place.  We are ready to load
# the NS file.

if { ${GLOBALS::errors} != 1 } {
    file copy -force ${GLOBALS::tbcompat} .
    real_source ${GLOBALS::nsfile}

    if {${GLOBALS::ran} == 0} {
	perror "No 'Simulator run' statement found."
    }

}

exit ${GLOBALS::errors}
