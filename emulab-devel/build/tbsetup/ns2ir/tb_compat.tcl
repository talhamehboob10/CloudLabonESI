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

# This is the tb_compact.tcl that deals with all the TB specific commands.
# It should be loaded at the beginning of any ns script using the TB commands.

# We set up some helper stuff in a separate namespace to avoid any conflicts.
namespace eval TBCOMPAT {
    var_import ::GLOBALS::DB
    var_import ::GLOBALS::pid
    var_import ::GLOBALS::eid
    var_import ::GLOBALS::elabinelab_fw_type

    # This is regular expression that matches slightly more than valid
    # IP addresses.  The only thing it doesn't check is that IP 
    # addresses are in range (i.e. 0-255).
    variable IP {^([0-9]{1,3}\.){3,3}[0-9]{1,3}$}

    # This is an RE to match a floating point number.
    variable FLOAT {(^[0-9]+(\.[0-9]+)?$)|(^\.[0-9]+$)}

    # This is the default weight for a soft vtype.
    variable default_soft_vtype_weight 0.5

    # This is the default weight for a hard vtype.
    variable default_hard_vtype_weight 1.0

    variable prefix "/test"

    # Substitutions for "/proj",
    variable FSDIR_PROJ "/proj"
    variable PROJROOT	"/proj"

    # ... "/groups",
    variable FSDIR_GROUPS "/groups"
    variable GROUPROOT	  "/groups"

    # ... "/users",
    variable FSDIR_USERS "/users"
    variable USERROOT	 "/users"

    # ... "/share", and
    variable FSDIR_SHARE "/share"
    variable SHAREROOT	 "/share"

    # ... "/scratch".
    variable FSDIR_SCRATCH ""
    variable SCRATCHROOT   ""

    # This is a general procedure that takes a node, an object (lan or link)
    # it is connected to, and an IP address, and sets the IP address
    # for the node on that object.  It checks both the validity of the
    # IP addresses and the fact that the node is actually a member of the
    # lan/link.
    proc set-ip {node obj ip} {
	variable IP
	set caller [lindex [info level -1] 0]
	if {[regexp $IP $ip] == 0} {
	    perror "$caller - $ip is not a valid IP address."
	    return
	}
	set port [$node find_port $obj]
	if {$port == -1} {
	    perror "$caller - $node is not connected to $obj."
	    return
	}
	$node ip $port $ip
    }

    # Let's set up a hwtypes table that contains all valid hardware types.
    variable hwtypes
    variable isremote
    variable isvirt
    variable issubnode

    # Storage object tracking (types, resources, etc.)
    variable sotypes
    variable soclasses
    variable soprotocols

    variable sodesires 
    array set sodesires {
	"class" 1
	"protocol" 1
	"lease" 1
    }

    variable soplacementdesires
    array set soplacementdesires {
	"ANY"       "?+disk_any"
	"SYSVOL"    "?+disk_sysvol"
	"NONSYSVOL" "?+disk_nonsysvol"
    }
    variable sodefaultplacement "ANY"
    variable sopartialplacements
    array set sopartialplacements {}
    variable sofullplacements
    array set sofullplacements {}

    variable sodisallowedmounts {
	"/" "/bin" "/boot" "/dev" "/etc" "/lib" "/libexec" "/proc" 
	"/sbin" "/sys" "/usr" "/usr/bin" "/usr/local" "/usr/local/etc" 
	"/usr/local/bin" "/usr/local/sbin" "/usr/sbin" "/var"
	"/etc/emulab" "/group" "/proj" "/share" "/scratch" 
	"/users" "/usr/local/etc/emulab" "/var/emulab"
    }
    variable sonodemounts
    array set sonodemounts {}

    # NSE hack: sim type is not in DB. Just adding it now
    set hwtypes(sim) 1
    set isremote(sim) 0
    set isvirt(sim) 0
    set issubnode(sim) 0

    # The permissions table. Entries in this table indicate who is allowed
    # to use nodes of a particular type. No entries means anyone can use it.
    #
    # We omit this check in anonymous mode.
    #
    variable nodetypeXpid_permissions
    
    # And a os table with valid OS Descriptor names. While we still call
    # them "osids", we are using the user level name not the internal,
    # globally unique name. We leave it to a later phase to deal with it.
    #
    # We omit this check in anonymous mode.
    #
    variable osids

    # The default OSID for the node type. 
    variable default_osids

    # A mapping of event objects and types.
    variable objtypes
    variable eventtypes
    variable triggertypes

    # Existing (reserved nodes).
    variable reserved_list
    variable reserved_type
    variable reserved_node
    set reserved_list {}

    # Input parameters for Templates
    variable parameter_list_defaults
    array set parameter_list_defaults {}

    # Physical node names
    variable physnodes

    ## Feedback related stuff below:

    # Experiment directory name.
    variable expdir

    # ElabInElab stuff. Do not initialize.
    variable elabinelab_maxpcs
    variable elabinelab_hardware
    variable elabinelab_fixnodes
    variable elabinelab_nodeos
    variable elabinelab_source_tarfile ""
    variable elabinelab_tarfiles
    variable elabinelab_cnetspeed 0

    # Elabinelab attribute stuff.
    variable elabinelab_attributes
    set elabinelab_attributes {}
    variable EINEROLE  {^(all|boss|ops|fs|router|node)$}
    variable EINEKEY   {^([-\w\.]+)$}
    variable EINEVALUE {^([-\w\.\+\,\s\/:\@]*)$}
    variable EINEORDER {^\d+$}

    # Address Pool.
    variable virt_address_pools

    # virt blobs stuff
    variable vblob_id_count 0
    variable virt_blobs {}
    variable vblobmap
    array set vblobmap {}

    # client service/hook control stuff
    variable servicenames
    array set servicenames {}
    variable servicepoints
    array set servicepoints {}
    variable virt_service_ctls
    array set virt_service_ctls {}
    variable virt_service_hooks
    array set virt_service_hooks {}

    # OML measurement stuff.
    set oml_mps {}

    # OML-server listening port.
    set oml_server_port 8000

    # OML-server node.
    set omlserver omlserver

    # flag to identify which network is used to send measurement data
    # by default, use control network.
    set oml_use_control 1

    # Mapping of "resource classes" and "reservation types" to bootstrap
    # values, where a resource class is a symbolic string provided by the user
    # (e.g. Client, Server), and a reservation type is a resource name provided
    # by the system (e.g. cpupercent, kbps).  This array will be filled by the
    # tb-feedback methods and then written out to a "bootstrap_data.tcl" file
    # to be read in during future evaluations of the NS file.
    variable BootstrapReservations

    # Table of vnodes/vlinks that were locate on an overloaded pnode.
    variable Alerts

    # Table of "estimated" reservations.  Basically, its our memory of previous
    # guesses for vnodes that have 0% CPU usage on an overloaded pnode.
    variable EstimatedReservations

    # The experiment directory, this is where the feedback related files will
    # be read from and dumped to.  XXX Hacky
    # XXX Hacky II: we must use PROJROOT and not FSDIR_PROJ since these
    # sourced file paths get recorded and used on boss.
    set expdir "${PROJROOT}/${::GLOBALS::pid}/exp/${::GLOBALS::eid}/"

    # XXX Just for now...
    variable tbxlogfile
    if {[file exists "$expdir"]} {
	set logname "$expdir/logs/feedback.log"
	set tbxlogfile [open $logname w 0664];
	catch "exec chmod 0664 $logname"
	puts $tbxlogfile "BEGIN feedback log"
    }

    # Get any Emulab generated feedback data from the experiment directory.
    if {[file exists "${expdir}/tbdata/feedback_data.tcl"]} {
	source "${expdir}/tbdata/feedback_data.tcl"
    }
    # Get any bootstrap feedback data from a previous run.
    if {[file exists "${expdir}/tbdata/bootstrap_data.tcl"]} {
	source "${expdir}/tbdata/bootstrap_data.tcl"
    }
    # Get any estimated feedback data from a previous run.
    if {[file exists "${expdir}/tbdata/feedback_estimate.tcl"]} {
	source "${expdir}/tbdata/feedback_estimate.tcl"
    }

    #
    # Configure the default reservations for an object based on an optional
    # "resource class".  First, the function will check for a reservation
    # specifically made for the object, then it will try to initialize the
    # reservation from the resource class, otherwise it does nothing and
    # returns zero.
    #
    # @param object The object name for which to configure the feedback
    #   defaults.
    # @param rclass The "resource class" of the object or the empty string if
    #   it is not part of any class.  This is just a symbolic string, such as
    #   "Client" or "Server".
    # @return One, if there is an initialized slot in the "Reservations" array
    #   for the given object, or zero if it could not be initialized.
    #
    proc feedback-defaults {object rclass} {
	var_import ::TBCOMPAT::Reservations;  # The reservations to make

	if {[array get Reservations $object,*] == ""} {
	    # No node-specific values exist, try to initialize from the rclass.
	    if {[array get Reservations $rclass,*] != ""} {
		# Use bootstrap feedback from a previous topology,
		set rcdefaults [array get Reservations $rclass,*]
		# ... substitute the node name for the rclass, and
		regsub -all -- $rclass $rcdefaults $object rcdefaults
		# ... add all the reservations to the table.
		array set Reservations $rcdefaults
		set retval 1
	    } else {
		# No feedback exists yet, let the caller fill it in.
		set retval 0
	    }
	} else {
	    # Node-specific values exist, use those.
	    set retval 1
	}
	return $retval
    }

    #
    # Produce an estimate of a vnode's resource usage.  If a guess was already
    # made in the previous iteration, double that value.  Otherwise, we just
    # assume 10%.
    #
    # @param object The object for which to produce the estimate.
    # @param rtype The resource type: cpupercent, rampercent
    # @return The estimated resource usage.
    # 
    proc feedback-estimate {object rtype} {
	var_import ::TBCOMPAT::EstimatedReservations

	if {[array get EstimatedReservations $object,$rtype] != ""} {
	    set retval [expr [set EstimatedReservations($object,$rtype)] * 2]
	} else {
	    set retval 10.0; # XXX get from DB
	}
	set EstimatedReservations($object,$rtype) $retval
	return $retval
    }

    #
    # Record bootstrap feedback data for a resource class.  This function
    # should be called for every member of a resource class so that the one
    # with the highest reservation will be used to bootstrap.
    #
    # @param rclass The "resource class" for which to update the bootstrap
    #   feedback data.  This is just a symbolic string, such as "Client" or
    #   "Server".
    # @param rtype The type of reservation (e.g. cpupercent,kbps).
    # @param res The amount to reserve.
    #
    proc feedback-bootstrap {rclass rtype res} {
	# The bootstrap reservations
	var_import ::TBCOMPAT::BootstrapReservations

	if {$rclass == ""} {
	    # No class to operate on...
	} elseif {([array get BootstrapReservations($rclass,$rtype)] == "") ||
	    ($res > $BootstrapReservations($rclass,$rtype))} {
		# This is either the first time this function was called for
		# this rclass/rtype or the new value is greater than the old.
		set BootstrapReservations($rclass,$rtype) $res
	}
    }

    #
    # Verify that the argument is an http, https, or ftp URL.
    #
    # @param url The URL to check.
    # @return True if "url" looks like a URL.
    #
    # What is xxx:// you might ask? Its part of experimental template code.
    #
    proc verify-url {url} {
	if {[string match "http://*" $url] ||
	    [string match "https://*" $url] ||
	    [string match "ftp://*" $url] ||
	    [string match "xxx://*" $url]} {
	    set retval 1
	} else {
	    set retval 0
	}
	return $retval
    }

    # Add an IP alias for a node given a particular lan.
    proc add-ipalias {node obj ip} {
	variable IP
	set caller [lindex [info level -1] 0]
	if {[regexp $IP $ip] == 0} {
	    perror "$caller - $ip is not a valid IP address."
	    return
	}
	$node add_ipalias $obj $ip
    }

    # Request a number of IP aliases for a node on a particular lan.
    variable MAX_NODEPORT_IPALIASES 10
    proc request-ipaliases {node obj count} {
	variable MAX_NODEPORT_IPALIASES
	set caller [lindex [info level -1] 0]
	if {$count > $MAX_NODEPORT_IPALIASES} {
	    perror "$caller - Number of IP aliases requested ($count) is too large (max: $MAX_NODEPORT_IPALIASES)."
	    return
	}
	$node want_ipaliases $obj $count
    }

}

# IP addresses routines.  These all do some checks and convert into set-ip
# calls.
proc tb-set-ip {node ip} {
    $node instvar portlist
    if {[llength $portlist] != 1} {
	perror "\[tb-set-ip] $node does not have a single connection."
	return
    }
    ::TBCOMPAT::set-ip $node [lindex $portlist 0] $ip
}
proc tb-set-ip-interface {src dst ip} {
    set sim [$src set sim]
    set reallink [$sim find_link $src $dst]
    if {$reallink == {}} {
	perror \
	    "\[tb-set-ip-interface] No connection between $src and $dst."
	return
    }
    ::TBCOMPAT::set-ip $src $reallink $ip
}
proc tb-set-ip-lan {src lan ip} {
    if {[$lan info class] != "Lan"} {
	perror "\[tb-set-ip-lan] $lan is not a LAN."
	return
    }
    ::TBCOMPAT::set-ip $src $lan $ip
}
proc tb-set-ip-link {src link ip} {
    if {[$link info class] != "Link"} {
	perror "\[tb-set-ip-link] $link is not a link."
	return
    }
    ::TBCOMPAT::set-ip $src $link $ip
}

#
# Append an IP address alias for a node given a particular lan or link.
#
proc tb-add-ip-alias-lan {src lan ip} {
    if {[$lan info class] != "Lan"} {
	perror "\[tb-add-ip-alias-lan] $lan is not a LAN."
	return
    }
    ::TBCOMPAT::add-ipalias $src $lan $ip
}
proc tb-add-ip-alias-link {src link ip} {
    if {[$link info class] != "Link"} {
	perror "\[tb-add-ip-alias-link] $link is not a link."
	return
    }
    ::TBCOMPAT::add-ipalias $src $link $ip
}

# Request a number of automatically assigned ip aliases on a lan or link.
proc tb-request-ip-alias-lan {src lan count} {
    if {[$lan info class] != "Lan"} {
	perror "\[tb-add-ip-alias-lan] $lan is not a LAN."
	return
    }
    ::TBCOMPAT::request-ipaliases $src $lan $count
}
proc tb-request-ip-alias-link {src link count} {
    if {[$link info class] != "Link"} {
	perror "\[tb-add-ip-alias-link] $link is not a link."
	return
    }
    ::TBCOMPAT::request-ipaliases $src $link $count
}

#
# Set the netmask. To make it easier to compute subnets later, do
# allow the user to alter the netmask beyond the bottom 3 octets.
# This restricts the user to a lan of 4095 nodes, but that seems okay
# for now. 
# 
proc tb-set-netmask {lanlink netmask} {
    var_import ::TBCOMPAT::IP
    
    if {[$lanlink info class] != "Link" && [$lanlink info class] != "Lan"} {
	perror "\[tb-set-netmask] $lanlink is not a link or a lan."
	return
    }
    if {[regexp $IP $netmask] == 0} {
	perror "\[tb-set-netmask] - $netmask is not a valid IP mask"
	return
    }
    set netmaskint [inet_atohl $netmask]
    if {[expr ($netmaskint & 0xFFFF0000)] != 0xFFFF0000} {
	perror "\[tb-set-netmask] - $netmask is too big"
	return
    }
    $lanlink set netmask $netmask
}

proc tb-set-node-service {service args} {
    var_import ::TBCOMPAT::servicenames
    var_import ::TBCOMPAT::servicepoints
    var_import ::TBCOMPAT::virt_service_ctls
    var_import ::TBCOMPAT::vblob_id_count
    var_import ::TBCOMPAT::virt_blobs
    var_import ::TBCOMPAT::vblobmap

    set cmd "tb-set-node-service"

    # these defaults should match the default value for each DB field
    # in virt_client_service* tables
    ::GLOBALS::named-args $args {
	-node "" -env "boot" -whence "every" -script "" -scriptblob ""
	-enable 1 -enablehooks 1 -fatal 1
    }

    if { $(-script) != "" && $(-scriptblob) != "" } {
	perror "\[$cmd] you cannot define both a script ($(-script)) and a scriptblob ($(-scriptblob))!"
	return
    }

    if {![info exists servicenames("$service:$(-env):$(-whence)")]} {
	if {[info exists servicepoints($service)]} {
	    perror "\[$cmd] service $service can only be controlled for the following whence and env tuples: $servicepoints($service); $service:$(-env):$(-whence)."
	    return
	}
	perror "\[$cmd] Invalid service $service."
	return
    }

    set mykey "$(-node):$service:$(-env):$(-whence)"
    if {[info exists virt_service_ctls($mykey)]} {
	perror "\[$cmd] service $service has already been controlled once for node $(-node) at $(-whence):$(-env)"
	return
    } else {
	set vblobid $(-scriptblob)
	if { $(-script) != "" && [info exists vblobmap($(-script))]} {
	    # try to reuse virt blobs that already have been created
	    set vblobid $vblobmap($(-script))
	} elseif { $(-script) != "" } {
	    # if we need to make a virt blob, do so now

	    # Check the script to make sure it exists, is readable, etc...
	    if {[string match "*://*" $(-script)]} {
		perror "\[$cmd] '$(-script)' cannot be a URL!"
		return
		# It is a URL, check for a valid protocol.
		#if {![::TBCOMPAT::verify-url $(-script)]} {
		#    perror "\[$cmd] '$(-script)' is not an http, https, or ftp URL."
		#    return
		#}
	    } elseif {![string match "${::TBCOMPAT::PROJROOT}/*" $(-script)] &&
		      ![string match "${::TBCOMPAT::GROUPROOT}/*" $(-script)] &&
		      ![string match "${::TBCOMPAT::USERROOT}/*" $(-script)] &&
		      (${::TBCOMPAT::SCRATCHROOT} == "" ||
		       ![string match "${::TBCOMPAT::SCRATCHROOT}/*" $(-script)])} {
		perror "\[$cmd] '$(-script)' is not in an allowed directory"
		return
	    } elseif {![file exists $(-script)]} {
		perror "\[$cmd] '$(-script)' does not exist."
		return
	    } elseif {![file isfile $(-script)]} {
		perror "\[$cmd] '$(-script)' is not a file."
		return
	    } elseif {![file readable $(-script)]} {
		perror "\[$cmd] '$(-script)' is not readable."
		return
	    }

	    # finally, make the virt blob!
	    lappend virt_blobs [list $vblob_id_count $(-script)]
	    set vblobid $vblob_id_count
	    set vblobmap($(-script)) $vblob_id_count

	    incr vblob_id_count
	}

	set serviceidx $servicenames("$service:$(-env):$(-whence)")
	set virt_service_ctls($mykey) \
	    [list $(-node) $serviceidx $(-env) $(-whence) \
		 $vblobid $(-enable) $(-enablehooks) $(-fatal)]
    }
}

proc tb-add-address-pool {id count} {
    var_import ::TBCOMPAT::virt_address_pools

    set virt_address_pools($id) $count
}

proc tb-add-node-service-hook {service args} {
    var_import ::TBCOMPAT::servicenames
    var_import ::TBCOMPAT::servicepoints
    var_import ::TBCOMPAT::virt_service_hooks
    var_import ::TBCOMPAT::vblob_id_count
    var_import ::TBCOMPAT::virt_blobs
    var_import ::TBCOMPAT::vblobmap

    set cmd "tb-add-node-service-hook"

    # these defaults should match the default value for each DB field
    # in virt_client_service* tables
    ::GLOBALS::named-args $args {
	-node "" -env "boot" -whence "every" -script "" -scriptblob ""
	-op "boot" -point "post" -argv "" -fatal 1
    }

    if { $(-script) != "" && $(-scriptblob) != "" } {
	perror "\[$cmd] you cannot define both a script ($(-script)) and a scriptblob ($(-scriptblob))!"
	return
    } elseif { $(-script) == "" && $(-scriptblob) == "" } {
	perror "\[$cmd] you must define either a script or a scriptblob!"
	return
    }

    if {![info exists servicenames("$service:$(-env):$(-whence)")]} {
	if {[info exists servicepoints($service)]} {
	    perror "\[$cmd] service $service can only be controlled for the following whence and env tuples: $servicepoints($service); $service:$(-env):$(-whence)."
	    return
	}
	perror "\[$cmd] Invalid service $service."
	return
    }

    set mykey "$(-node):$service:$(-env):$(-whence)"
    if {![info exists virt_service_ctls($mykey)]} {
	set virt_service_ctls($mykey) {}
    }

    set vblobid $(-scriptblob)
    if { $(-script) != "" && [info exists vblobmap($(-script))]} {
	# try to reuse virt blobs that already have been created
	set vblobid $vblobmap($(-script))
    } elseif { $(-script) != "" } {
	# if we need to make a virt blob, do so now

	# Check the script to make sure it exists, is readable, etc...
	if {[string match "*://*" $(-script)]} {
	    perror "\[$cmd] '$(-script)' cannot be a URL!"
	    return
	    # It is a URL, check for a valid protocol.
	    #if {![::TBCOMPAT::verify-url $(-script)]} {
	    #    perror "\[$cmd] '$(-script)' is not an http, https, or ftp URL."
	    #    return
	    #}
	} elseif {![string match "${::TBCOMPAT::PROJROOT}/*" $(-script)] &&
		  ![string match "${::TBCOMPAT::GROUPROOT}/*" $(-script)] &&
		  ![string match "${::TBCOMPAT::USERROOT}/*" $(-script)] &&
		  (${::TBCOMPAT::SCRATCHROOT} == "" ||
		   ![string match "${::TBCOMPAT::SCRATCHROOT}/*" $(-script)])} {
	    perror "\[$cmd] '$(-script)' is not in an allowed directory"
	    return
	} elseif {![file exists $(-script)]} {
	    perror "\[$cmd] '$(-script)' does not exist."
	    return
	} elseif {![file isfile $(-script)]} {
	    perror "\[$cmd] '$(-script)' is not a file."
	    return
	} elseif {![file readable $(-script)]} {
	    perror "\[$cmd] '$(-script)' is not readable."
	    return
	}

	# finally, make the virt blob!
	lappend virt_blobs [list $vblob_id_count $(-script)]
	set vblobid $vblob_id_count
	set vblobmap($(-script)) $vblob_id_count

	incr vblob_id_count
    }

    # finally, add the hook!
    set serviceidx $servicenames("$service:$(-env):$(-whence)")
    lappend virt_service_hooks($mykey) \
	[list $(-node) $serviceidx $(-env) $(-whence) \
	     $vblobid $(-op) $(-point) $(-argv) $(-fatal)]
}

# Node state routines.
proc tb-set-hardware {node type args} {
    var_import ::TBCOMPAT::hwtypes
    var_import ::TBCOMPAT::isremote
    var_import ::TBCOMPAT::isvirt
    var_import ::TBCOMPAT::issubnode
    var_import ::GLOBALS::vtypes
    if {(! [info exists hwtypes($type)]) &&
	(! [info exists vtypes($type)])} {
	perror "\[tb-set-hardware] Invalid hardware type $type."
	return
    }
    if {! ${GLOBALS::anonymous} && ! ${GLOBALS::passmode}} {
	var_import ::TBCOMPAT::nodetypeXpid_permissions
	var_import ::GLOBALS::pid
	set allowed 1
	
	if {[info exists nodetypeXpid_permissions($type)]} {
	    set allowed 0
	    foreach allowedpid $nodetypeXpid_permissions($type) {
		if {$allowedpid == $pid} {
		    set allowed 1
		}
	    }
	}
	if {! $allowed} {
	    perror "\[tb-set-hardware] No permission to use type $type."
	    return
	}
    }
    set remote 0
    if {[info exists isremote($type)]} {
	set remote $isremote($type)
    }
    set isv 0
    if {[info exists isvirt($type)]} {
	set isv $isvirt($type)
    }
    set issub 0
    if {[info exists issubnode($type)]} {
	set issub $issubnode($type)
    }
    $node set_hwtype $type $remote $isv $issub
}

proc tb-set-node-os {node os {parentos 0}} {
    if {! ${GLOBALS::anonymous} && ! ${GLOBALS::passmode} &&
        ([regexp {^(ftp|http|https):} $os] == 0) } {
	var_import ::TBCOMPAT::osids
	var_import ::GLOBALS::pid

	# Do not allow RHL-STD or FBSD-STD anymore.
	if { $os == "RHL-STD" || $os == "FBSD-STD" } {
	    perror "\[tb-set-node-os] $os is no longer supported; remove this statement if you really do not care what OS you get."
	    return
	}

	# Look for :version in the name.
	set osid $os
        if { [regexp {:} $os] } {
	    set osid [lindex [split $os {:}] 0]
	}
	if {! [info exists osids($osid)]} {
	    perror "\[tb-set-node-os] Invalid osid $os."
	    return
	}
	#
	# Always qualify the name if there is one in the current project.
	#
	if { ${GLOBALS::rspecmode} } {
	    if { ! [regexp {/} $os] } {
		set pos = "$pid/$osid"
		if { [info exists osids($pos)]} {
		    $osid = $pos
		} else {
		    set pos = "emulab-ops/$osid"
		    if { [info exists osids($pos)]} {
			$osid = $pos
		    }
		}
	    }
	}
	if {$parentos != {} && $parentos != 0} {
	    # Look for :version in the name.
	    set posid $parentos
	    if { [regexp {:} $parentos] } {
		set posid [lindex [split $os {:}] 0]
	    }
	    if {! [info exists osids($posid)]} {
		perror "\[tb-set-node-os] Invalid parent osid $parentos."
		return
	    }
	}
    }
    $node set osid $os
    if {$parentos != {} && $parentos != 0} {
	$node set parent_osid $parentos
    }
}
proc tb-set-node-loadlist {node loadlist} {
    if {! ${GLOBALS::anonymous} && ! ${GLOBALS::passmode}} {
	var_import ::TBCOMPAT::osids
	set oslist [split $loadlist ","]
	foreach os $oslist {
	    if {! [info exists osids($os)]} {
		perror "\[tb-set-node-loadlist] Invalid osid $os."
		return
	    }
	}
    }
    $node set loadlist $loadlist
}
proc tb-set-node-cmdline {node cmdline} {
    $node set cmdline $cmdline
}
proc tb-set-node-rpms {node args} {
    if {$args == {}} {
	perror "\[tb-set-node-rpms] No rpms given."
	return
    }
    # Lets assume that a single argument is a string and break it up.
    if {[llength $args] == 1} {
	set args [split [lindex $args 0] " "]
    }
    $node set rpms [join $args ";"]
}
proc tb-set-node-startup {node cmd} {
    $node set startup $cmd
}
proc tb-proc-tarfiles {cmd args0} { ; # args has special meaning that we
				      # don't want here
    set SHAREDNFS [expr {! "0"}]
    set args $args0

    # Lets assume that a single argument is a string and break it up.
    if {[llength $args] == 1} {
	set args [split [lindex $args 0] " "]
    }

    if {[expr [llength $args] % 2] != 0} {
	perror "\[$cmd] Arguments should be node and series of pairs."
	return
    }
    set tarfiles {}
    while {$args != {}} {
	set dir [lindex $args 0]
	set tarfile [lindex $args 1]
	
	#
	# Check the install directory to make sure it is not an NFS mount.
	# This check can also act as an alert to the user that the arguments
	# are wrong.  For example, the following line will pass the above
	# checks, but fail this one:
	#
	#   tb-set-node-tarfiles $node /proj/foo/bar.tgz /proj/foo/baz.tgz
	#
	# XXX This is a hack check because they can specify '/' and have
	# "proj/foo/..." in the tarball and still clobber themselves.
	#
	if {$SHAREDNFS && 
	    ([string match "${::TBCOMPAT::PROJROOT}/*" $dir] ||
	     [string match "${::TBCOMPAT::GROUPROOT}/*" $dir] ||
	     [string match "${::TBCOMPAT::USERROOT}/*" $dir] ||
	     [string match "${::TBCOMPAT::SHAREROOT}/*" $dir] ||
	     (${::TBCOMPAT::SCRATCHROOT} != "" &&
	      [string match "${::TBCOMPAT::SCRATCHROOT}/*" $dir]))} {
	    perror "\[$cmd] '$dir' refers to an NFS directory instead of the node's local disk."
	    return
	} elseif {![string match "/*" $dir]} {
	    perror "\[$cmd] '$dir' is not an absolute path."
	    return
	}

	# Skip verification in passmode.
	if { !${GLOBALS::anonymous} && !${GLOBALS::passmode}} {
	    # Check the tar file to make sure it exists, is readable, etc...
	    if {[string match "*://*" $tarfile]} {
		# It is a URL, check for a valid protocol.
		if {![::TBCOMPAT::verify-url $tarfile]} {
		    perror "\[$cmd] '$tarfile' is not an http, https, or ftp URL."
		    return
		}
	    } elseif {![string match "${::TBCOMPAT::PROJROOT}/*" $tarfile] &&
		      ![string match "${::TBCOMPAT::GROUPROOT}/*" $tarfile] &&
		      ![string match "${::TBCOMPAT::USERROOT}/*" $tarfile] &&
		      (${::TBCOMPAT::SCRATCHROOT} == "" ||
		       ![string match "${::TBCOMPAT::SCRATCHROOT}/*" $tarfile])} {
		perror "\[$cmd] '$tarfile' is not in an allowed directory"
		return
	    } elseif {![file exists $tarfile]} {
		perror "\[$cmd] '$tarfile' does not exist."
		return
	    } elseif {![file isfile $tarfile]} {
		perror "\[$cmd] '$tarfile' is not a file."
		return
	    } elseif {![file readable $tarfile]} {
		perror "\[$cmd] '$tarfile' is not readable."
		return
	    }
	}

	# Make sure the tarfile has a valid extension.
	if {![string match "*.tar" $tarfile] &&
	    ![string match "*.tar.Z" $tarfile] &&
	    ![string match "*.tar.gz" $tarfile] &&
	    ![string match "*.tgz" $tarfile] &&
	    ![string match "*.tar.bz2" $tarfile]} {
	    perror "\[$cmd] '$tarfile' does not have a valid extension (e.g. *.tar, *.tar.Z, *.tar.gz, *.tgz)."
	    return
	}
	lappend tarfiles [list $dir $tarfile]
	set args [lrange $args 2 end]
    }
    return $tarfiles
}
proc tb-set-node-tarfiles {node args} {
    if {$args == {}} {
	perror "\[tb-set-node-tarfiles] tb-set-node-tarfiles <node> (<dir> <tar>)+"
	return
    }
    set tarfiles {}
    foreach el [tb-proc-tarfiles "tb-set-node-tarfiles" $args] {
	lappend tarfiles [join $el " "]
    }
    $node set tarfiles [join $tarfiles ";"]
}
proc tb-set-tarfiles {args} {
    if {$args == {}} {
	perror "\[tb-set-tarfiles] tb-set-tarfiles (<dir> <tar>)+"
	return
    }
    set tarfiles [tb-proc-tarfiles "tb-set-tarfiles" $args]
    if [info exists ::TBCOMPAT::tarfiles] {
	set ::TBCOMPAT::tarfiles [concat $::TBCOMPAT::tarfiles $tarfiles]
    } else {
	set ::TBCOMPAT::tarfiles $tarfiles
    }
}
proc tb-set-ip-routing {type} {
    var_import ::GLOBALS::default_ip_routing_type

    if {$type == {}} {
	perror "\[tb-set-ip-routing] No type given."
	return
    }
    if {($type != "none") &&
	($type != "ospf")} {
	perror "\[tb-set-ip-routing] Type is not one of none|ospf"
	return
    }
    set default_ip_routing_type $type
}
proc tb-set-node-usesharednode {node weight} {
    $node add-desire "pcshared" $weight
}
proc tb-set-node-sharingmode {node sharemode} {
    $node set sharing_mode $sharemode
}

# Lan/Link state routines.

# This takes two possible formats:
# tb-set-link-loss <link> <loss>
# tb-set-link-loss <src> <dst> <loss>
proc tb-set-link-loss {srclink args} {
    var_import ::TBCOMPAT::FLOAT
    if {[llength $args] == 2} {
	set dst [lindex $args 0]
	set lossrate [lindex $args 1]
	set sim [$srclink set sim]
	set reallink [$sim find_link $srclink $dst]
	if {$reallink == {}} {
	    perror "\[tb-set-link-loss] No link between $srclink and $dst."
	    return
	}
    } else {
	set reallink $srclink
	set lossrate [lindex $args 0]
    }
    if {([regexp $FLOAT $lossrate] == 0) ||
	(($lossrate != 0) && (($lossrate > 1.0) || ($lossrate < 0.000005)))} {
	perror "\[tb-set-link-loss] $lossrate is not a valid loss rate."
    }
    $reallink instvar loss
    $reallink instvar rloss
    set adjloss [expr 1-sqrt(1-$lossrate)]
    foreach pair [array names loss] {
	set loss($pair) $adjloss
	set rloss($pair) $adjloss
    }
}

# This takes two possible formats:
# tb-set-link-est-bandwidth <link> <bandwidth>
# tb-set-link-est-bandwidth <src> <dst> <bandwidth>
proc tb-set-link-est-bandwidth {srclink args} {
    if {[llength $args] == 2} {
	set dst [lindex $args 0]
	set bw [lindex $args 1]
	set sim [$srclink set sim]
	set reallink [$sim find_link $srclink $dst]
	if {$reallink == {}} {
	    perror "\[tb-set-link-est-bandwidth] No link between $srclink and $dst."
	    return
	}
    } else {
	set reallink $srclink
	set bw [lindex $args 0]
    }
    $reallink instvar bandwidth
    $reallink instvar ebandwidth 
    $reallink instvar rebandwidth
    foreach pair [array names bandwidth] {
	set ebandwidth($pair) [parse_bw $bw]
	set rebandwidth($pair) [parse_bw $bw]
    }
}

# This takes two possible formats:
# tb-set-link-backfill <link> <bw>
# tb-set-link-backfill <src> <dst> <bw>
proc tb-set-link-backfill {srclink args} {
    if {[llength $args] == 2} {
	set dst [lindex $args 0]
	set bw [lindex $args 1]
	set sim [$srclink set sim]
	set reallink [$sim find_link $srclink $dst]
	if {$reallink == {}} {
	    perror "\[tb-set-link-backfill] No link between $srclink and $dst."
	    return
	}
    } else {
	if {[$srclink info class] != "Link"} {
	    perror "\[tb-set-link-backfill] $srclink is not a link."
	    return
	}
	set reallink $srclink
	set bw [lindex $args 0]
    }
    $reallink instvar bandwidth
    $reallink instvar backfill
    $reallink instvar rbackfill
    foreach pair [array names bandwidth] {
	set backfill($pair) [parse_bw $bw]
	set rbackfill($pair) [parse_bw $bw]
    }
}

# This takes two possible formats:
# tb-set-link-backfill <link> <src> <bw>
proc tb-set-link-simplex-backfill {link src bw} {
    var_import ::TBCOMPAT::FLOAT
    if {[$link info class] != "Link"} {
	perror "\[tb-set-link-simplex-backfill] $link is not a link."
	return
    }
    if {[$src info class] != "Node"} {
	perror "\[tb-set-link-simplex-backfill] $src is not a node."
	return
    }
    set port [$link get_port $src]
    if {$port == {}} {
	perror "\[tb-set-link-simplex-backfill] $src is not in $link."
	return
    }
    set np [list $src $port]
    foreach nodeport [$link set nodelist] {
	if {$nodeport != $np} {
	    set onp $nodeport
	}
    }
    set realbw [parse_bw $bw]
    $link set backfill($np) $realbw
    $link set rbackfill($onp) $realbw
}

proc tb-set-lan-loss {lan lossrate} {
    var_import ::TBCOMPAT::FLOAT
    if {[$lan info class] != "Lan"} {
	perror "\[tb-set-lan-loss] $lan is not a lan."
	return
    }
    if {([regexp $FLOAT $lossrate] == 0) ||
	(($lossrate != 0) && (($lossrate > 1.0) || ($lossrate < 0.000005)))} {
	perror "\[tb-set-lan-loss] $lossrate is not a valid loss rate."
    }
    $lan instvar loss
    $lan instvar rloss
    set adjloss [expr 1-sqrt(1-$lossrate)]
    foreach pair [array names loss] {
	set loss($pair) $adjloss
	set rloss($pair) $adjloss
    }
}

proc tb-set-lan-est-bandwidth {lan bw} {
    if {[$lan info class] != "Lan"} {
	perror "\[tb-set-lan-est-bandwidth] $lan is not a lan."
	return
    }

    $lan instvar bandwidth
    $lan instvar ebandwidth 
    $lan instvar rebandwidth
    foreach pair [array names bandwidth] {
	set ebandwidth($pair) [parse_bw $bw]
	set rebandwidth($pair) [parse_bw $bw]
    }
}

proc tb-set-lan-backfill {lan bw} {
    if {[$lan info class] != "Lan"} {
	perror "\[tb-set-lan-backfill] $lan is not a lan."
	return
    }

    $lan instvar bandwidth
    $lan instvar backfill
    $lan instvar rbackfill
    foreach pair [array names bandwidth] {
	set backfill($pair) [parse_bw $bw]
	set rbackfill($pair) [parse_bw $bw]
    }
}

proc tb-set-node-lan-delay {node lan delay} {
    if {[$node info class] != "Node"} {
	perror "\[tb-set-node-lan-delay] $node is not a node."
	return
    }
    if {[$lan info class] != "Lan"} {
	perror "\[tb-set-node-lan-delay] $lan is not a lan."
	return
    }
    set port [$lan get_port $node]
    if {$port == {}} {
	perror "\[tb-set-node-lan-delay] $node is not in $lan."
	return
    }

    set rdelay [parse_delay $delay]
    $lan set delay([list $node $port]) $rdelay
    $lan set rdelay([list $node $port]) $rdelay
}


proc tb-set-node-lan-bandwidth {node lan bw} {
    if {[$node info class] != "Node"} {
	perror "\[tb-set-node-lan-bandwidth] $node is not a node."
	return
    }
    if {[$lan info class] != "Lan"} {
	perror "\[tb-set-node-lan-bandwidth] $lan is not a lan."
	return
    }
    set port [$lan get_port $node]
    if {$port == {}} {
	perror "\[tb-set-node-lan-bandwidth] $node is not in $lan."
	return
    }
    $lan set bandwidth([list $node $port]) [parse_bw $bw]
    $lan set rbandwidth([list $node $port]) [parse_bw $bw]
}
proc tb-set-node-lan-est-bandwidth {node lan bw} {
    if {[$node info class] != "Node"} {
	perror "\[tb-set-node-lan-est-bandwidth] $node is not a node."
	return
    }
    if {[$lan info class] != "Lan"} {
	perror "\[tb-set-node-lan-est-bandwidth] $lan is not a lan."
	return
    }
    set port [$lan get_port $node]
    if {$port == {}} {
	perror "\[tb-set-node-lan-est-bandwidth] $node is not in $lan."
	return
    }
    $lan set ebandwidth([list $node $port]) [parse_bw $bw]
    $lan set rebandwidth([list $node $port]) [parse_bw $bw]
}
proc tb-set-node-lan-backfill {node lan bw} {
    if {[$node info class] != "Node"} {
	perror "\[tb-set-node-lan-backfill] $node is not a node."
	return
    }
    if {[$lan info class] != "Lan"} {
	perror "\[tb-set-node-lan-backfill] $lan is not a lan."
	return
    }
    set port [$lan get_port $node]
    if {$port == {}} {
	perror "\[tb-set-node-lan-backfill] $node is not in $lan."
	return
    }
    $lan set backfill([list $node $port]) [parse_bw $bw]
    $lan set rbackfill([list $node $port]) [parse_bw $bw]
}
proc tb-set-node-lan-loss {node lan loss} {
    var_import ::TBCOMPAT::FLOAT
    if {[$node info class] != "Node"} {
	perror "\[tb-set-node-lan-loss] $node is not a node."
	return
    }
    if {[$lan info class] != "Lan"} {
	perror "\[tb-set-node-lan-loss] $lan is not a lan."
	return
    }
    set port [$lan get_port $node]
    if {$port == {}} {
	perror "\[tb-set-node-lan-loss] $node is not in $lan."
	return
    }
    if {([regexp $FLOAT $loss] == 0) ||
	(($loss != 0) && (($loss > 1.0) || ($loss < 0.000005)))} {
	perror "\[tb-set-link-loss] $loss is not a valid loss rate."
    }
    $lan set loss([list $node $port]) $loss
    $lan set rloss([list $node $port]) $loss
}
proc tb-set-node-lan-params {node lan delay bw loss} {
    tb-set-node-lan-delay $node $lan $delay
    tb-set-node-lan-bandwidth $node $lan $bw
    tb-set-node-lan-loss $node $lan $loss
}

proc tb-set-node-failure-action {node type} {
    if {[$node info class] != "Node" && [$node info class] != "Bridge"} {
	perror "\[tb-set-node-failure-action] $node is not a node."
	return
    }
    if {[lsearch -exact {fatal nonfatal ignore} $type] == -1} {
	perror "\[tb-set-node-failure-action] type must be one of fatal|nonfatal|ignore."
	return
    }
    $node set failureaction $type
}

proc tb-set-link-failure-action {lanlink type} {
    if {[$lanlink info class] != "Link" && [$lanlink info class] != "Lan"} {
	perror "\[tb-set-link-failure-action] $lanlink is not a link or a lan."
	return
    }
    if {[lsearch -exact {fatal nonfatal} $type] == -1} {
	perror "\[tb-set-link-failure-action] must be one of fatal|nonfatal"
	return
    }
    $lanlink set failureaction $type
}

proc tb-fix-node {vnode pnode} {
    if {[$vnode info class] != "Node" && 
	[$vnode info class] != "Blockstore"} {
	perror "\[tb-fix-node] $vnode is not a node."
	return
    }
    $vnode set_fixed $pnode
}

proc tb-make-soft-vtype {name types} {
    var_import ::TBCOMPAT::hwtypes
    var_import ::TBCOMPAT::isremote
    var_import ::GLOBALS::vtypes
    var_import ::TBCOMPAT::default_soft_vtype_weight

    foreach type $types {
	if {! [info exists hwtypes($type)]} {
	    perror "\[tb-make-soft-vtype] Invalid hardware type $type."
	}
    }
    set vtypes($name) [Vtype $name $default_soft_vtype_weight $types]
}

proc tb-make-hard-vtype {name types} {
    var_import ::TBCOMPAT::hwtypes
    var_import ::TBCOMPAT::isremote
    var_import ::GLOBALS::vtypes
    var_import ::TBCOMPAT::default_hard_vtype_weight

    foreach type $types {
	if {! [info exists hwtypes($type)]} {
	    perror "\[tb-make-hard-vtype] Invalid hardware type $type."
	}
    }
    set vtypes($name) [Vtype $name $default_hard_vtype_weight $types]
}

proc tb-make-weighted-vtype {name weight types} {
    var_import ::TBCOMPAT::hwtypes
    var_import ::TBCOMPAT::isremote
    var_import ::GLOBALS::vtypes
    var_import ::TBCOMPAT::FLOAT

    foreach type $types {
	if {! [info exists hwtypes($type)]} {
	    perror "\[tb-make-weighted-vtype] Invalid hardware type $type."
	}
	if {$isremote($type)} {
	    perror "\[tb-make-weighted-vtype] Remote type $type not allowed."
	}
    }
    if {([regexp $FLOAT $weight] == 0) ||
	($weight <= 0) || ($weight >= 1.0)} {
	perror "\[tb-make-weighted-vtype] $weight is not a valid weight. (0 < weight < 1)."
    }
    set vtypes($name) [Vtype $name $weight $types]
}

proc tb-set-link-simplex-params {link src delay bw loss} {
    var_import ::TBCOMPAT::FLOAT
    if {[$link info class] != "Link"} {
	perror "\[tb-set-link-simplex-params] $link is not a link."
	return
    }
    if {[$src info class] != "Node"} {
	perror "\[tb-set-link-simplex-params] $src is not a node."
	return
    }
    set port [$link get_port $src]
    if {$port == {}} {
	perror "\[tb-set-link-simplex-params] $src is not in $link."
	return
    }
    if {([regexp $FLOAT $loss] == 0) ||
	(($loss != 0) && (($loss > 1.0) || ($loss < 0.000005)))} {
	perror "\[tb-set-link-simplex-params] $loss is not a valid loss rate."
	return
    }
    set adjloss [expr 1-sqrt(1-$loss)]
    set np [list $src $port]
    foreach nodeport [$link set nodelist] {
	if {$nodeport != $np} {
	    set onp $nodeport
	}
    }

    set realdelay [parse_delay $delay]
    set realbw [parse_bw $bw]
    $link set delay($np) [expr $realdelay / 2.0]
    $link set rdelay($onp) [expr $realdelay / 2.0]
    $link set bandwidth($np) $realbw
    $link set rbandwidth($onp) $realbw
    $link set loss($np) [expr $adjloss]
    $link set rloss($onp) [expr $adjloss]
}

proc tb-set-lan-simplex-backfill {lan node tobw frombw} {
    var_import ::TBCOMPAT::FLOAT
    if {[$node info class] != "Node"} {
	perror "\[tb-set-lan-simplex-params] $node is not a node."
	return
    }
    if {[$lan info class] != "Lan"} {
	perror "\[tb-set-lan-simplex-params] $lan is not a lan."
	return
    }
    set port [$lan get_port $node]
    if {$port == {}} {
	perror "\[tb-set-lan-simplex-params] $node is not in $lan."
	return
    }
    set realtobw [parse_backfill $tobw]
    set realfrombw [parse_backfill $frombw]

    $lan set backfill([list $node $port]) $realtobw
    $lan set rbackfill([list $node $port]) $realfrombw
}

proc tb-set-lan-simplex-params {lan node todelay tobw toloss fromdelay frombw fromloss} {
    var_import ::TBCOMPAT::FLOAT
    if {[$node info class] != "Node"} {
	perror "\[tb-set-lan-simplex-params] $node is not a node."
	return
    }
    if {[$lan info class] != "Lan"} {
	perror "\[tb-set-lan-simplex-params] $lan is not a lan."
	return
    }
    set port [$lan get_port $node]
    if {$port == {}} {
	perror "\[tb-set-lan-simplex-params] $node is not in $lan."
	return
    }
    if {([regexp $FLOAT $toloss] == 0) ||
	(($toloss != 0) && (($toloss > 1.0) || ($toloss < 0.000005)))} {
	perror "\[tb-set-link-loss] $toloss is not a valid loss rate."
    }
    if {([regexp $FLOAT $fromloss] == 0) ||
	(($fromloss != 0) && (($fromloss > 1.0) || ($fromloss < 0.000005)))} {
	perror "\[tb-set-link-loss] $fromloss is not a valid loss rate."
    }

    set realtodelay [parse_delay $todelay]
    set realfromdelay [parse_delay $fromdelay]
    set realtobw [parse_bw $tobw]
    set realfrombw [parse_bw $frombw]

    $lan set delay([list $node $port]) $realtodelay
    $lan set rdelay([list $node $port]) $realfromdelay
    $lan set loss([list $node $port]) $toloss
    $lan set rloss([list $node $port]) $fromloss
    $lan set bandwidth([list $node $port]) $realtobw
    $lan set rbandwidth([list $node $port]) $realfrombw
}

proc tb-set-uselatestwadata {onoff} {
    var_import ::GLOBALS::uselatestwadata

    if {$onoff != 0 && $onoff != 1} {
	perror "\[tb-set-uselatestwadata] $onoff must be 0/1"
	return
    }

    set uselatestwadata $onoff
}

proc tb-set-usewatunnels {onoff} {
    var_import ::GLOBALS::usewatunnels

    if {$onoff != 0 && $onoff != 1} {
	perror "\[tb-set-usewatunnels] $onoff must be 0/1"
	return
    }

    set usewatunnels $onoff
}

proc tb-use-endnodeshaping {onoff} {
    var_import ::GLOBALS::uselinkdelays

    if {$onoff != 0 && $onoff != 1} {
	perror "\[tb-use-endnodeshaping] $onoff must be 0/1"
	return
    }

    set uselinkdelays $onoff
}

proc tb-force-endnodeshaping {onoff} {
    var_import ::GLOBALS::forcelinkdelays

    if {$onoff != 0 && $onoff != 1} {
	perror "\[tb-force-endnodeshaping] $onoff must be 0/1"
	return
    }

    set forcelinkdelays $onoff
}

proc tb-set-wasolver-weights {delay bw plr} {
    var_import ::GLOBALS::wa_delay_solverweight
    var_import ::GLOBALS::wa_bw_solverweight
    var_import ::GLOBALS::wa_plr_solverweight

    if {($delay < 0) || ($bw < 0) || ($plr < 0)} {
	perror "\[tb-set-wasolver-weights] Weights must be postive integers."
	return
    }
    if {($delay == {}) || ($bw == {}) || ($plr == {})} {
	perror "\[tb-set-wasolver-weights] Must provide delay, bw, and plr."
	return
    }

    set wa_delay_solverweight $delay
    set wa_bw_solverweight $bw
    set wa_plr_solverweight $plr
}

#
# Control emulated for a link
# 
proc tb-set-multiplexed {lanlink onoff} {
    if {[$lanlink info class] != "Link" && [$lanlink info class] != "Lan" } {
	perror "\[tb-set-multiplexed] $link is not a link or a lan."
	return
    }

    # looks like our GUI will spit out non-zero values other than 1 so...
    if {$onoff != 0} {
	set onoff 1
    }

    $lanlink set emulated $onoff
}

#
# For emulated links, allow bw shaping to be turned off
# 
proc tb-set-noshaping {lanlink onoff} {
    if {[$lanlink info class] != "Link" && [$lanlink info class] != "Lan" } {
	perror "\[tb-set-noshaping] $link is not a link or a lan."
	return
    }
    if {$onoff != 0 && $onoff != 1} {
	perror "\[tb-set-noshaping] $onoff must be 0/1"
	return
    }

    $lanlink set nobwshaping $onoff
}

#
# For emulated links, allow veth device to be used. Not a user option.
# XXX backward compat, use tb-set-link-encap now.
# 
proc tb-set-useveth {lanlink onoff} {
    if {[$lanlink info class] != "Link" && [$lanlink info class] != "Lan"} {
	perror "\[tb-set-useveth] $link is not a link or a lan."
	return
    }
    if {$onoff == 0} {
	$lanlink set encap "default"
    } else {
	$lanlink set encap "veth"
    }
}

#
# For emulated links, allow specifying encapsulation style.
# Generalizes tb-set-useveth.
# 
proc tb-set-link-encap {lanlink style} {
    if {[$lanlink info class] != "Link" && [$lanlink info class] != "Lan"} {
	perror "\[tb-set-link-encap] $link is not a link or a lan."
	return
    }

    switch -- $style {
	"gre" {
	    set style "gre"
	}
	"egre" {
	    set style "egre"
	}
	"vtun" {
	    set style "vtun"
	}
	"veth-ne" {
	    set style "veth-ne"
	}
	"vlan" {
	    set style "vlan"
	}
	default {
	    perror "\[tb-set-link-encap] one of: 'veth-ne', 'vlan'"
	    return
	}
    }

    $lanlink set encap $style
}


#
# Control linkdelays for lans and links
# 
proc tb-set-endnodeshaping {lanlink onoff} {
    if {[$lanlink info class] != "Link" && [$lanlink info class] != "Lan"} {
	perror "\[tb-set-endnodeshaping] $lanlink is not a link or a lan."
	return
    }
    if {$onoff != 0 && $onoff != 1} {
	perror "\[tb-set-endnodeshaping] $onoff must be 0/1"
	return
    }

    $lanlink set uselinkdelay $onoff
}

#
# Crude control of colocation of virt nodes. Will be flushed when we have
# a real story. Sets it for the entire link or lan. Maybe set it on a
# per node basis?
#
proc tb-set-allowcolocate {lanlink onoff} {
    if {[$lanlink info class] != "Link" && [$lanlink info class] != "Lan"} {
	perror "\[tb-set-allowcolocate] $lanlink is not a link or a lan."
	return
    }
    if {$onoff != 0 && $onoff != 1} {
	perror "\[tb-set-allowcolocate] $onoff must be 0/1"
	return
    }

    $lanlink set trivial_ok $onoff
}

#
# Another crude control. Allow override of multiplex factor that is listed
# in the node_types table. 
#
proc tb-set-colocate-factor {factor} {
    var_import ::GLOBALS::multiplex_factor

    if {$factor < 1 || $factor > 100} {
	perror "\[tb-set-colocate-factor] factor must be 1 <= factor <= 100"
	return
    }

    set multiplex_factor $factor
}

#
# Set the packing strategy assign uses.
#
proc tb-set-packing-strategy {strategy} {
    var_import ::GLOBALS::packing_strategy

    if {$strategy != "pack" && $strategy != "balance"} {
	perror "\[tb-set-packing-strategy] strategy must be pack|balance"
	return
    }

    set packing_strategy $strategy
}

#
# Set the sync server for the experiment. Must a vnode name that has been
# allocated.
#
proc tb-set-sync-server {node} {
    var_import ::GLOBALS::sync_server

    if {[$node info class] != "Node"} {
	perror "\[tb-set-sync-server] $node is not a node."
	return
    }
    set sync_server $node
}

#
# Turn on or of the ipassign program for IP address assignment and route
# calculation
#
proc tb-use-ipassign {onoff} {
    var_import ::GLOBALS::use_ipassign

    if {$onoff != 0 && $onoff != 1} {
	perror "\[tb-use-ipassign] $onoff must be 0/1"
	return
    }

    set use_ipassign $onoff
}

#
# Give arguments for ipassign
#
proc tb-set-ipassign-args {stuff} {
    var_import ::GLOBALS::ipassign_args

    set ipassign_args $stuff
}

#
# Set the startup command for a node. Replaces the tb-set-node-startup
# command above, but we have to keep that one around for a while. This
# new version dispatched to the node object, which uses a program object.
# 
proc tb-set-node-startcmd {node command} {
    if {[$node info class] != "Node"} {
	perror "\[tb-set-node-startcmd] $node is not a node."
	return
    }
    set command "($command ; /usr/local/etc/emulab/startcmddone \$?)"
    set newprog [$node start-command $command]

    return $newprog
}

#
# More crude controls.
#
proc tb-set-mem-usage {usage} {
    var_import ::GLOBALS::mem_usage

    if {$usage < 1 || $usage > 5} {
	perror "\[tb-set-mem-usage] usage must be 1 <= factor <= 5"
	return
    }

    set mem_usage $usage
}
proc tb-set-cpu-usage {usage} {
    var_import ::GLOBALS::cpu_usage

    if {$usage < 1 || $usage > 5} {
	perror "\[tb-set-cpu-usage] usage must be 1 <= factor <= 5"
	return
    }

    set cpu_usage $usage
}

#
# This is nicer syntax for subnodes.
#
proc tb-bind-parent {sub phys} {
    tb-fix-node $sub $phys
}

proc tb-fix-current-resources {onoff} {
    var_import ::GLOBALS::fix_current_resources

    if {$onoff != 0 && $onoff != 1} {
	perror "\[tb-fix-current-resources] $onoff must be 0/1"
	return
    }

    set fix_current_resources $onoff
}

#
# Control veth encapsulation. 
# 
proc tb-set-encapsulate {onoff} {
    var_import ::GLOBALS::vlink_encapsulate

    if {$onoff == 0} {
	set vlink_encapsulate "veth-ne"
    } elseif {$onoff == 1} {
	set vlink_encapsulate "default"
    } else {
	perror "\[tb-set-encapsulate] $onoff must be 0/1"
    }
}

#
# Control virtual link emulation style.
# 
proc tb-set-vlink-emulation {style} {
    var_import ::GLOBALS::vlink_encapsulate

    switch -- $style {
	"gre" {
	    set style "gre"
	}
	"egre" {
	    set style "egre"
	}
	"vtun" {
	    set style "vtun"
	}
	"veth-ne" {
	    set style "veth-ne"
	}
	"vlan" {
	    set style "vlan"
	}
	"alias" {
	    set style "alias"
	}
	default {
	    perror "\[tb-set-encapsulate] one of: 'veth-ne', 'vlan'"
	    return
	}
    }
    set vlink_encapsulate $style
}

#
# Control jail and delay nodes osnames. 
# 
proc tb-set-jail-os {os} {
    var_import ::GLOBALS::jail_osname
    
    if {! ${GLOBALS::anonymous} && ! ${GLOBALS::passmode}} {
	var_import ::TBCOMPAT::osids
	if {! [info exists osids($os)]} {
	    perror "\[tb-set-jail-os] Invalid osid $os."
	    return
	}
    }
    set jail_osname $os
}
proc tb-set-delay-os {os} {
    var_import ::GLOBALS::delay_osname
    
    if {! ${GLOBALS::anonymous} && ! ${GLOBALS::passmode}} {
	var_import ::TBCOMPAT::osids
	if {! [info exists osids($os)]} {
	    perror "\[tb-set-delay-os] Invalid osid $os."
	    return
	}
    }
    set delay_osname $os
}

#
# Set the delay capacity override. This is not documented cause we
# do not want people to do this!
#
proc tb-set-delay-capacity {cap} {
    var_import ::GLOBALS::delay_capacity

    if { $cap <= 0 || $cap > 1 } {
	perror "\[tb-set-delay-capacity] Must be 0 < X <= 1"
	return
    }
    set delay_capacity $cap
}

#
# Allow type of lans (but not links) to be changed.
#
proc tb-set-lan-protocol {lanlink protocol} {
    if {[$lanlink info class] != "Lan"} {
	perror "\[tb-set-lan-protocol] $lanlink is not a lan."
	return
    }
    $lanlink set protocol $protocol
}

#
# Allow type of links (but not LANs) to be changed.
#
proc tb-set-link-protocol {lanlink protocol} {
    if {[$lanlink info class] != "Link"} {
	perror "\[tb-set-lan-protocol] $lanlink is not a link."
	return
    }
    $lanlink set protocol $protocol
}

#
# Set the fabric. We change the protocol as well.
#
proc tb-set-switch-fabric {lanlink fabric} {
    if {[$lanlink info class] != "Link" && [$lanlink info class] != "Lan"} {
	perror "\[tb-set-lan-protocol] $lanlink is not a link or lan."
	return
    }
    $lanlink set protocol $fabric
    $lanlink set_setting "switch_fabric" $fabric
}

#
# XXX - We need to set the accesspoint for a wireless lan. I have no
# idea how this will eventually be done, but for now just do it manually.
# 
proc tb-set-lan-accesspoint {lanlink node} {
    if {[$lanlink info class] != "Lan"} {
	perror "\[tb-set-lan-accesspoint] $lanlink is not a lan."
	return
    }
    if {[$node info class] != "Node"} {
	perror "\[tb-set-lan-accesspoint] $node is not a node."
	return
    }
    $lanlink set_accesspoint $node
}

#
# Set capabilities for lans and members of lans.
#
proc tb-set-lan-setting {lanlink capkey capval} {
    if {[$lanlink info class] != "Lan"} {
	perror "\[tb-set-lan-setting] $lanlink is not a lan."
	return
    }
    $lanlink set_setting $capkey $capval
}
proc tb-set-node-lan-setting {lanlink node capkey capval} {
    if {[$lanlink info class] != "Lan"} {
	perror "\[tb-set-node-lan-setting] $lanlink is not a lan."
	return
    }
    if {[$node info class] != "Node"} {
	perror "\[tb-set-node-lan-setting] $node is not a node."
	return
    }
    $lanlink set_member_setting $node $capkey $capval
}

#
# Turn on or of the use of phys naming; if the user name for the node
# matches a real node in the testbed, do an implicit fix-node to it.
#
proc tb-use-physnaming {onoff} {
    var_import ::GLOBALS::use_physnaming

    if {$onoff != 0 && $onoff != 1} {
	perror "\[tb-use-physnaming] $onoff must be 0/1"
	return
    }

    set use_physnaming $onoff
}

#
# Write to the tb-experimental log file, as defined by the tbxlogfile global
# variable.  If the tbxlogfile variable is not set, the message is sent to
# /dev/null.
#
# @param msg The message to write to the log file.
#
# @global tbxlogfile The path to the log file, if defined.
#
proc tbx-log {msg} {
    var_import ::TBCOMPAT::tbxlogfile;

    if {[info exists tbxlogfile]} {
	puts $tbxlogfile $msg
    }
}

#
# XXX quick hack.
# Enable use of jumbo frames (9K) for 10Gb and beyond links. Assumes that the
# experiment switches involved all have jumbo frames enabled.
#
proc tb-use-jumbo-frames {onoff} {
    perror "\[tb-use-jumbo-frames] no longer supported, ignoring."
    return
}

##
## BEGIN Feedback
##

proc tb-feedback-vnode {vnode hardware args} {
    var_import ::TBCOMPAT::isvirt;        # Make sure $hardware is a vnode.
    var_import ::TBCOMPAT::Reservations;  # The reservations to make for nodes.
    var_import ::TBCOMPAT::BootstrapReservations;  # Bootstrap file.
    var_import ::TBCOMPAT::Alerts;        # Alert indicators
    var_import ::GLOBALS::fix_current_resources

    ::GLOBALS::named-args $args {
	-scale 1.2 -rclass "" -alertscale 2.0 -initscale 0.01
    }

    set fix_current_resources 0

    # Check our inputs,
    if {[$vnode info class] != "Node"} {
	perror "\[tb-feedback-vnode] $vnode is not a node."
	return
    }
    if {(! [info exists isvirt($hardware)]) || (! $isvirt($hardware))} {
	perror "\[tb-feedback-vnode] Unknown hardware type: $hardware"
	return
    }
    if {$(-scale) <= 0.0} {
	perror "\[tb-feedback-vnode] Feedback scale is not greater than zero: $(-scale)"
	return
    }

    tbx-log "BEGIN feedback for $vnode"

    # ... set computed default values, and
    if {[::TBCOMPAT::feedback-defaults $vnode $(-rclass)] == 0} {
	# No feedback exists yet, so we assume 100%.
	set Reservations($vnode,cpupercent) [expr 92.0 * $(-initscale)]
	set Reservations($vnode,rampercent) [expr 80.0 * $(-initscale)]
	tbx-log "  Initializing node, $vnode, to one-to-one."
    }

    # ... make the reservations.
    foreach name [array names Reservations $vnode,*] {
	# Get the type of reservation and
	set reservation_type [lindex [split $name {,}] 1]
	# ... the amount consumed.
	set raw_reservation [set Reservations($name)]

	::TBCOMPAT::feedback-bootstrap \
		$(-rclass) $reservation_type $raw_reservation

	# Then scale the reservation
	set desired_reservation [expr $raw_reservation * $(-scale)]
	# ... making sure it is still within the range of the hardware.
	if {$desired_reservation < 0.0} {
	    # XXX Not allowing negative values might be too restrictive...
	    perror "\[tb-feedback-vnode] Bad reservation value: $name = $raw_reservation"
	    return
	}
	if {([array get Alerts $vnode] != "") && [set Alerts($vnode)] > 0} {
	    # The pnode was overloaded, need to adjust the reservation in a
	    # more radical fashion.
	    tbx-log "Alert for $vnode $desired_reservation"
	    if {$desired_reservation < 0.1} {
		# No good data to work with, make an estimate.
		set desired_reservation [::TBCOMPAT::feedback-estimate \
			$vnode $reservation_type]
	    } else {
		# Some data, try applying the alert scale value.
		set desired_reservation \
			[expr $desired_reservation * $(-alertscale)]; # XXX
	    }
	}
	if {$reservation_type == "cpupercent"} {
	    if {$desired_reservation > 92.0} {
		set desired_reservation 92.0
	    }
	} else {
	    if {$desired_reservation > 80.0} {
		set desired_reservation 80.0
	    }
	}
	tbx-log "  $reservation_type: ${desired_reservation}"
	# Finally, tell assign about our desire.
	$vnode add-desire ?+${reservation_type} ${desired_reservation}
    }

    tb-set-hardware $vnode $hardware

    tbx-log "END feedback for $vnode"
}

proc tb-feedback-vlan {vnode lan args} {
    var_import ::TBCOMPAT::Reservations;   # The reservations to make for lans
    var_import ::TBCOMPAT::Alerts;         # Alert indicators

    ::GLOBALS::named-args $args {-scale 1.0 -rclass "" -alertscale 3.0}

    if {[$vnode info class] != "Node"} {
	perror "\[tb-feedback-vlan] $vnode is not a node."
	return
    }
    if {[$lan info class] != "Lan"} {
	perror "\[tb-feedback-vlan] $lan is not a LAN."
	return
    }
    if {$(-scale) <= 0.0} {
	perror "\[tb-feedback-vlan] Feedback scale is not greater than zero: $(-scale)"
	return
    }

    tbx-log "BEGIN feedback for node $vnode on lan $lan"

    if {[::TBCOMPAT::feedback-defaults "$vnode,$lan" $(-rclass)] == 0} {
	# No feedback exists yet, so we assume 100%.  Fortunately, everything
	# already assumes 100%, so we do not have to do anything extra.
	tbx-log "  Initializing vlan, $vnode $lan, to one-to-one."
    }

    foreach name [array names Reservations ${vnode},${lan},kbps] {
	# Get the type of reservation and
	set reservation_type [lindex [split $name {,}] 1]
	# ... its value.
	set raw_reservation [set Reservations($name)]
	tbx-log "  raw: $raw_reservation"
	# Get the maximum allowed value and
	set max_reservation 0
	foreach pair [$lan array names bandwidth "${vnode} *"] {
	    tbx-log "  pair: $pair - [$lan set bandwidth($pair)]"
	    if {[$lan set bandwidth($pair)] > $max_reservation} {
		set max_reservation [$lan set bandwidth($pair)]
	    }
	}
	tbx-log "  max: $max_reservation"
	# ... fix any measuring/shaping error.
	if {$raw_reservation > $max_reservation} {
	    tbx-log "  request > max: $raw_reservation $max_reservation"
	    set raw_reservation $max_reservation
	}

	::TBCOMPAT::feedback-bootstrap \
		$(-rclass) $reservation_type $raw_reservation

	# Then scale the reservation
	set desired_reservation \
		[expr int(sqrt($raw_reservation * $max_reservation) * $(-scale))]
	# ... making sure it is still within the range of the hardware.
	if {$desired_reservation < 0.0} {
	    # XXX Not allowing negative values might be too restrictive...
	    perror "\[tb-feedback-vlan] Bad reservation value: $name = $raw_reservation"
	} elseif {$desired_reservation < 10.0} {
	    set desired_reservation 10; # XXX see parse.tcl.in
	}
	if {([array get Alerts $lan,$vnode] != "") &&
	    [set Alerts($lan,$vnode)] > 0} {
	    # The pnode was overloaded, need to adjust the reservation in a
	    # more radical fashion.
	    tbx-log "Alert for $lan, $vnode"
	    set desired_reservation \
		    [expr $desired_reservation * $(-alertscale)]; # XXX
	}
	if {$desired_reservation > $max_reservation} {
	    set desired_reservation $max_reservation
	}

	tbx-log "  $reservation_type: ${desired_reservation}"

	# Finally, adjust the cap.
	tb-set-node-lan-est-bandwidth $vnode $lan ${desired_reservation}kb
    }
    
    tbx-log "END feedback for node $vnode on lan $lan"
}

proc tb-feedback-vlink {link args} {
    var_import ::TBCOMPAT::Reservations;   # The reservations to make for links
    var_import ::TBCOMPAT::Alerts;         # Alert indicators

    ::GLOBALS::named-args $args {-scale 1.2 -rclass "" -alertscale 3.0}

    if {[$link info class] != "Link"} {
	perror "\[tb-feedback-vlink] $link is not a link."
	return
    }
    if {$(-scale) <= 0.0} {
	perror "\[tb-feedback-vlink] Feedback scale is not greater than zero: $(-scale)"
	return
    }

    tbx-log "BEGIN feedback for link $link"

    if {[::TBCOMPAT::feedback-defaults $link $(-rclass)] == 0} {
	# No feedback exists yet, so we assume 100%.  Fortunately, not
	# specifying anything implies 100%, so we do not have to do anything
	# extra.
	tbx-log "  Initializing vlink, $link, to one-to-one."
    }

    foreach name [array names Reservations $link,kbps] {
	# Get the type of reservation and
	set reservation_type [lindex [split $name {,}] 1]
	# ... its value.
	set raw_reservation [set Reservations($name)]
	# Get the maximum allowed value and
	set max_reservation 0
	foreach pair [$link array names bandwidth] {
	    if {[$link set bandwidth($pair)] > $max_reservation} {
		set max_reservation [$link set bandwidth($pair)]
	    }
	}
	# ... fix any measuring/shaping error.
	if {$raw_reservation > $max_reservation} {
	    tbx-log "  request > max: $raw_reservation $max_reservation"
	    set raw_reservation $max_reservation
	}

	::TBCOMPAT::feedback-bootstrap \
		$(-rclass) $reservation_type $raw_reservation

	# Then scale the reservation
	set desired_reservation \
		[expr int(sqrt($raw_reservation * $max_reservation))]
	# ... making sure it is still within the range of the hardware.
	if {$desired_reservation < 0.0} {
	    # XXX Not allowing negative values might be too restrictive...
	    perror "\[tb-feedback-vlink] Bad reservation value: $name = $raw_reservation"
	    return
	} elseif {$desired_reservation < 10.0} {
	    set desired_reservation 10; # XXX see parse.tcl.in
	}
	if {([array get Alerts $link] != "") && [set Alerts($link)] > 0} {
	    tbx-log "Alert for $link"
	    set desired_reservation \
		    [expr $desired_reservation * $(-alertscale)]; # XXX
	}
	if {$desired_reservation > $max_reservation} {
	    set desired_reservation $max_reservation
	}

	tbx-log "  $reservation_type: ${desired_reservation}"

	# Finally, adjust the cap.
	tb-set-link-est-bandwidth $link ${desired_reservation}kb
    }
    
    tbx-log "END feedback for link $link"
}

##
## END Feedback
##

#
# User indicates that this is a modelnet experiment. Be default, the number
# of core and edge nodes is set to one each. The user must increase those
# if desired.
# 
proc tb-use-modelnet {onoff} {
    var_import ::GLOBALS::modelnet_cores
    var_import ::GLOBALS::modelnet_edges

    if {$onoff} {
	set modelnet_cores 1
	set modelnet_edges 1
    } else {
	set modelnet_cores 0
	set modelnet_edges 0
    }
}
proc tb-set-modelnet-physnodes {cores edges} {
    var_import ::GLOBALS::modelnet_cores
    var_import ::GLOBALS::modelnet_edges

    if {$cores == 0 || $edges == 0} {
	perror "\[tb-set-modelnet-physnodes] cores and edges must be > 0"
	return
    }

    set modelnet_cores $cores
    set modelnet_edges $edges
}

#
# Mark this experiment as an elab in elab.
#
proc tb-elab-in-elab {onoff} {
    var_import ::GLOBALS::elab_in_elab

    if {$onoff} {
	set elab_in_elab 1
    } else {
	set elab_in_elab 0
    }
}

#
# Mark this experiment as not needing/wanting/allowed NFS mounts.
#
proc tb-set-nonfs {onoff} {
    var_import ::GLOBALS::nonfs

    if {$onoff} {
	set nonfs 1
    } else {
	set nonfs 0
    }
}

#
# Mark this experiment as needing a per-experiment DB on ops.
#
proc tb-set-dpdb {onoff} {
    var_import ::GLOBALS::dpdb

    if {$onoff} {
	set dpdb 1
    } else {
	set dpdb 0
    }
}
#
# Change the default topology.
#
proc tb-elab-in-elab-topology {topo} {
    var_import ::GLOBALS::elabinelab_topo

    set elabinelab_topo $topo
}
proc tb-set-inner-elab-eid {eid} {
    var_import ::GLOBALS::elabinelab_eid

    set elabinelab_eid $eid
}
proc tb-set-elabinelab-cvstag {cvstag} {
    var_import ::GLOBALS::elabinelab_cvstag

    set elabinelab_cvstag $cvstag
}
proc tb-elabinelab-singlenet {args} {
    var_import ::GLOBALS::elabinelab_singlenet
    set onoff 1

    if {$args != {}} {
	set onoff [lindex $args 0]
    }
    set elabinelab_singlenet $onoff
}

#
# Set/clear elabinelab attributes:
#    tb-set-elabinelab-attribute <key> <value> [<order>]
#    tb-unset-elabinelab-attribute <key>
#    tb-set-elabinelab-role-attribute <role> <key> <value> [<order>]
#    tb-unset-elabinelab-role-attribute <role> <key>
#
proc tb-set-elabinelab-attribute {key value {order 0}} {
    tb-set-elabinelab-role-attribute "all" $key $value $order
}

proc tb-unset-elabinelab-attribute {key} {
    tb-unset-elabinelab-role-attribute "all" $key
}

proc tb-set-elabinelab-role-attribute {role key value {order 0}} {
    var_import ::TBCOMPAT::EINEROLE;
    var_import ::TBCOMPAT::EINEKEY;
    var_import ::TBCOMPAT::EINEVALUE;
    var_import ::TBCOMPAT::EINEORDER;
    var_import ::TBCOMPAT::elabinelab_attributes;

    if {[regexp $EINEROLE $role] == 0} {
	perror "\[tb-set-elabinelab-attribute] - \"$role\" is not a valid elabinelab role"
	return
    }
    if {[regexp $EINEKEY $key] == 0} {
	perror "\[tb-set-elabinelab-attribute] - \"$key\" is not a valid elabinelab key"
	return
    }
    if {[regexp $EINEVALUE $value] == 0} {
	perror "\[tb-set-elabinelab-attribute] - \"$value\" is not a valid elabinelab value"
	return
    }
    if {[regexp $EINEORDER $order] == 0} {
	perror "\[tb-set-elabinelab-attribute] - \"$order\" is not a valid elabinelab order"
	return
    }

    if {$role == "all"} {
	set roles {"boss" "ops" "fs" "router" "node"}
    } else {
	set roles $role
    }

    foreach r $roles {
	#
	# If role/key/ordering exactly matches an existing value,
	# replace it to preserve uniqueness, otherwise just add it.
	#
	set i [lsearch -glob $elabinelab_attributes "$r;$key;*;$order"]
	if {$i > -1} {
	    set elabinelab_attributes [lreplace $elabinelab_attributes $i $i]
	}
	lappend elabinelab_attributes "$r;$key;$value;$order"
    }
}

proc tb-get-elabinelab-role-attribute {role key} {
    var_import ::TBCOMPAT::EINEROLE;
    var_import ::TBCOMPAT::EINEKEY;
    var_import ::TBCOMPAT::EINEVALUE;
    var_import ::TBCOMPAT::EINEORDER;
    var_import ::TBCOMPAT::elabinelab_attributes;

    set ret {}
    set i [lsearch -glob $elabinelab_attributes "$role;$key;*;0"]
    if {$i > -1} {
	set values [split [lindex $elabinelab_attributes $i] ";"]
	set ret [lindex $values 2]
    }
    return $ret
}

proc tb-unset-elabinelab-role-attribute {role key} {
    var_import ::TBCOMPAT::EINEROLE;
    var_import ::TBCOMPAT::EINEKEY;
    var_import ::TBCOMPAT::elabinelab_attributes;

    if {[regexp $EINEROLE $role] == 0} {
	perror "\[tb-unset-elabinelab-attribute] - \"$role\" is not a valid elabinelab role"
	return
    }
    if {[regexp $EINEKEY $key] == 0} {
	perror "\[tb-unset-elabinelab-attribute] - \"$key\" is not a valid elabinelab key"
	return
    }
    if {$role == "all"} {
	set roles {"boss" "ops" "fs" "router" "node"}
    } else {
	set roles $role
    }

    foreach r $roles {
	while {[lsearch -glob $elabinelab_attributes "$r;$key;*"] > -1} {
	    set i [lsearch -glob $elabinelab_attributes "$r;$key;*"]
	    set elabinelab_attributes [lreplace $elabinelab_attributes $i $i]
	}
    }
}

#
# Set the inner elab role for a node.
#
proc tb-set-node-inner-elab-role {node role} {
    if {[$node info class] != "Node"} {
	perror "\[tb-set-node-inner-elab-role] $node is not a node."
	return
    }
    if {[lsearch -exact {boss boss+router boss+fs+router router ops ops+fs fs node} $role] == -1} {
	perror "\[tb-set-node-inner-elab-role] type must be one of boss|boss+router|boss+fs+router|router|ops|ops+fs|fs|node"
	return
    }
    $node set inner_elab_role $role
}

#
# Set a plab role for a node.
#
proc tb-set-node-plab-role {node role} {
    if {[$node info class] != "Node"} {
	perror "\[tb-set-node-plab-role] $node is not a node."
	return
    }
    if {[lsearch -exact {plc node none} $role] == -1} {
	perror "\[tb-set-node-plab-role] type must be one of plc|node|none"
	return
    }
    $node set plab_role $role
}

#
# Set the default inner plab network.  Can be a linklan, "CONTROL", or
# "EXPERIMENTAL".  If user sets CONTROL
#

#
# Set the interface on which a node will be/access PLC.
# Both a plc and a normal planetlab node can call this.
#
proc tb-set-node-plab-plcnet {node lanlink} {
    if {[$node info class] != "Node"} {
        perror "\[tb-set-node-plab-plcnet] $node is not a node."
        return
    }
    if {$lanlink != "control" && $lanlink != "exp" &&
        ([$lanlink info class] != "Link" && [$lanlink info class] != "Lan")} {
	perror "\[tb-set-node-plab-plcnet] $lanlink must be a link, lan, \"control\", or \"exp\"."
	return
    }
    # don't do checking here, wait til we have Total Information Awareness.
    $node set plab_plcnet $lanlink
}

#
# Set security level.
#
proc tb-set-security-level {level} {
    var_import ::GLOBALS::security_level
    var_import ::GLOBALS::explicit_firewall

    if {$explicit_firewall} {
	perror "\[tb-set-security-level] cannot combine with explicit firewall"
    }

    switch -- $level {
	"Green" {
	    set level 0
	}
	"Blue" {
	    set level 1
	}
	"Yellow" {
	    set level 2
	}
	"Orange" {
	    set level 3
	}
	"Red" {
	    perror "\[tb-set-security-level] Red security not implemented yet"
	    return
	}
	unknown {
	    perror "\[tb-set-security-level] $level is not a valid level"
	    return
	}
    }
    set security_level $level
}

#
# Set firewall type for firewalled elabinelab experiments
#
proc tb-set-elabinelab-fw-type {type} {
    var_import ::GLOBALS::elabinelab_fw_type

    switch -- $type {
        "ipfw2-vlan" {
            set type "ipfw2-vlan"
        }
        "iptables-vlan" {
            set type "iptables-vlan"
        }
        unknown  {
            perror "\[tb-set-elabinelab-fw-type] $type is not a valid type"
            return
        }
    }
    set elabinelab_fw_type $type
}

#
# Set numeric ID (this is a mote thing)
#
proc tb-set-node-id {vnode myid} {
    if {[$vnode info class] != "Node"} {
	perror "\[tb-set-node-id] $vnode is not a node."
	return
    }
    $vnode set_numeric_id $myid
}

#
# Fix a particular node interface to a lanlink
#
proc tb-fix-interface {vnode lanlink iface} {
    if {[$vnode info class] != "Node"} {
        perror "\[tb-fix-interface] $vnode is not a node."
        return
    }
    if {[$lanlink info class] != "Link" && [$lanlink info class] != "Lan"} {
        perror "\[tb-fix-interface] $lanlink must be a link or lan!"
        return
    }

    $lanlink set_fixed_iface $vnode $iface
}

#
# Set the layer.
#
proc tb-set-link-layer {link mylayer} {
    if {[$link info class] != "Link"} {
	perror "\[tb-set-link-layer] $link is not a link."
	return
    }
    $link instvar layer
    $link set layer $mylayer
}

#
# Force allocation of a routable IP address for a control interface.
#
proc tb-set-node-routable-ip {node onoff} {
    if {[$node info class] != "Node"} {
	perror "\[tb-set-node-routable-ip] $node is not a node."
	return
    }

    if {$onoff == 0} {
	$node add-attribute "routable_control_ip" "false"
    } elseif {$onoff == 1} {
	$node add-attribute "routable_control_ip" "true"
    } else {
	perror "\[tb-set-node-routable-ip] $onoff must be 0/1"
    }
}

# This number is MBs.
proc tb-set-node-memory-size {node mem} {
    if {[$node info class] != "Node"} {
	perror "\[tb-set-node-memory-size] $node is not a node."
	return
    }
    $node add-attribute "MEMORY_SIZE" "$mem"
    $node add-desire "?+ram" "$mem"
}

# The following codes are written, in order to use OML to send data to a server
# in an Emulab experiment. It will define a node to run OML server and create
# two files (MP.c and MP.h) for users. (mp represents measurement point in
# context of OML.)

# This procedure is to define a node to run omlserver.
# It will allocate an additional machine from Emulab and configure it
# (OS and set a start-command to start a oml2-server process).
# The name for this server will always be omlserver.
proc tb-set-use-oml {args} {
    var_import ::TBCOMPAT::omlserver
    var_import ::TBCOMPAT::oml_server_port

    uplevel #0 {set omlserver [$ns node]}
    uplevel #0 {set oml_server_port ${::TBCOMPAT::oml_server_port} }
    uplevel #0 {tb-set-node-os $omlserver UBUNTU10-OML}
    uplevel #0 {set omlserverstartcmd "/usr/bin/oml2-server -l $oml_server_port --logfile=/local/logs/oml-server.log --data-dir=/local/logs"}
    uplevel #0 {tb-set-node-startcmd $omlserver $omlserverstartcmd}
}


# This procedure will assign a user-defined node to be omlserver.
# Configure OS and start-command for this machine.
proc tb-set-oml-server {node} {
    var_import ::TBCOMPAT::oml_server_port
    var_import ::TBCOMPAT::omlserver
    if { $node == {} } {
        perror "\[tb-set-oml-serve\] tb-set-oml-server <server_node>"
        perror "No parameters are provided"
        return
    }

    if { [$node info class] != "Node" } {
        perror "\[tb-set-oml-serve\] tb-set-oml-server <server_node>"
        perror "The parameter is not a node"
        return
    }

    #puts "oml server name: $node\n"
    $node set osid UBUNTU10-OML

    set command "/usr/bin/oml2-server -l $oml_server_port --logfile=/local/logs/oml-server.log --data-dir=/local/logs"
    set omlcommand "($command ; /usr/local/etc/emulab/startcmddone \$?)"
    $node start-command $omlcommand

    set omlserver $node
}

# set the flag. New lan will be constructed at sim.run()
proc tb-set-oml-use-control {flag} {
        var_import ::TBCOMPAT::oml_use_control
        set oml_use_control $flag
}

# add a mp to the global variable
proc tb-set-oml-mp {args} {
    var_import ::TBCOMPAT::oml_mps

    if { $args == {} } {
        perror "\[tb-set-oml-mp\] please specify parameters."
        return
    }

    set mp $args

    # check the parameters
    set metrics [split $mp " "]
    set count [llength $metrics]
    set metrics_c [expr (($count-1)/2)]

    #check format
    if { $count ==0 || $count ==1 ||$count%2==0 || $metrics_c == 0 } {
        perror "\[tb-set-oml-mp\] tb-set-oml-mp <mp_name> (<metric_id> <metric_type>)+"
        return
    }

    set oml_mps [linsert $oml_mps [llength $oml_mps] $mp]
}

# write "#include <>" into files
proc oml_write_include {h_fd s_fd} {
    set h_include "#include <oml2/omlc.h>\n#include <ocomm/o_log.h>\n#include <stdio.h>\n\n"
    puts $h_fd $h_include
    set s_include "#include \"MP.h\"\n"
    puts $s_fd $s_include
}

# analyze one mp and write into files
# tb-analyze-store-mp mp_name <metric_id metric_type>...
proc tb-analyze-store-mp {mp h_fd s_fd} {
    var_import ::TBCOMPAT::expdir

    puts "tb-analyze-store-mp is called"
    puts $mp
    puts stderr $mp
    #set mp [string range $arg1 1 [expr [string length $arg1] - 2 ] ]
    #puts $mp

    set metrics [split $mp " "]
    set count [llength $metrics]
    set metrics_c [expr (($count-1)/2)]

    # get the name of this mp.
    set mp_name [lindex $metrics 0]
    set struct_def [format "static OmlMP* oml_%s_mp = NULL;\n" $mp_name]
    set fun_def [format "void oml_%s(" $mp_name]
    set fun_body [format "\tOmlValueU v\[%d\];\n" $metrics_c]
    append struct_def \
        [format "static OmlMPDef oml_%s_def \[\] = \{\n" $mp_name]

    # get metrics in this mp
    set i 0
    while { $i < $metrics_c } {
        set metric_name [lindex $metrics [expr $i*2+1]]
        set type [lindex $metrics [expr $i*2+2]]
        if { [string compare $type "STRING"] == 0
            || [string compare $type "string"] == 0 } {
                set oml_type "OML_STRING_VALUE"
                append fun_def [format "char* %s, " $metric_name]
                append fun_body \
                        [format "\tomlc_set_const_string(v\[%d\], %s);\n" $i $metric_name]
        } elseif { [string compare $type "INT"] == 0
            || [string compare $type "int"] == 0 } {
                set oml_type "OML_LONG_VALUE"
                append fun_def [format "int %s, " $metric_name]
                append fun_body \
                        [format "\tomlc_set_long(v\[%d\], %s);\n" $i $metric_name]
        } elseif { [string compare $type "DOUBLE"] == 0
            || [string compare $type "double"] == 0 } {
                set oml_type "OML_DOUBLE_VALUE"
                append fun_def [format "double %s, " $metric_name]
                append fun_body \
                        [format "\tomlc_set_double(v\[%d\], %s);\n" $i $metric_name]
        } else {
                set struct_def [format "type \"%s\" not support\n" $type]
                perror "\[tb-analyze-store-mp\] ${struct_def}"
                return
        }
        append struct_def [format "\t\{\"%s\", %s\},\n" $metric_name $oml_type]

        incr i 1
    };#end of while
    append struct_def "\t\{NULL, (OmlValueT)0\},\n\};\n\n"


    puts $s_fd $struct_def
    set fun_def [string trimright $fun_def ", "]

    # write declaration into the header file
    set fun_dec [format "%s);\n" $fun_def]
    puts $h_fd $fun_dec

 # write definition and body into the source file
    append fun_def ") \{"
    puts $s_fd $fun_def
    append fun_body \
        [format "\tomlc_inject(oml_%s_mp, v);\n\}\n\n" $mp_name]
    puts $s_fd $fun_body
}

# write oml initialization into MP.c and MP.h
proc oml_write_init {h_fd s_fd} {
    var_import ::GLOBALS::pid
    var_import ::GLOBALS::eid
    var_import ::TBCOMPAT::oml_mps
    var_import ::TBCOMPAT::omlserver
    var_import ::TBCOMPAT::oml_server_port
    var_import ::TBCOMPAT::oml_use_control

    set init_def "void initialize_oml()"
    set init_dec [format "%s;" $init_def]
    puts $h_fd $init_dec

    append init_def " {\n\tint argc = 7;\n"
    append init_def "\tconst char *argv\[\] = \{\"emulab_oml\", \"--oml-id\", \"emulab_oml\","

    set oml_server "${omlserver}"
    if {$oml_use_control == 1} {
        # if use control network, then use long name
        set oml_server "${omlserver}.${eid}.${pid}"
    }
    append init_def "\"--oml-exp-id\", \"$eid\", \"--oml-server\", \"tcp:$oml_server:$oml_server_port\"\};\n"
    append init_def "\tomlc_init(argv\[0\], &argc, argv, o_log);\n"
    set i 0
    while { $i < [llength $oml_mps] } {
        set mp [lindex $oml_mps $i]
        #puts $mp
        set mp_name [lindex [split $mp " "] 0]
        set cmd [format "\toml_%s_mp = omlc_add_mp(\"%s\", oml_%s_def);\n" $mp_name $mp_name $mp_name ]
        append init_def $cmd
        incr i 1
    }
    append init_def "\tomlc_start();\n}\n"
    puts $s_fd $init_def
}


# called by sim.run()
# create MP.c and MP.h and analyze measurement points and write definitions to
# these two files. The location for these two files is /proj/pid/exp/eid/.

proc begin_oml_code_generator {} {
    var_import ::TBCOMPAT::oml_mps

    # If users do not define any measurement points. Just return
    # It will not create MP.c and MP.h
    if { $oml_mps == {} } {
        return
    }

    # puts "begin oml code generator\n"
    # create and open MP.c and MP.h at /proj/pid/exp/eid/
    if { [string compare ${::TBCOMPAT::expdir} "/proj/PID/exp/EID/"] == 0 } {
        puts stderr "\[oml_code_generator\] expdir is not initialized"
        return
    }

    if { ![file isdirectory ${::TBCOMPAT::expdir}] } {
        perror "\[oml_code_generator\] ${::TBCOMPAT::expdir} is not a directory"
        return
    }

    if { [catch {open "${::TBCOMPAT::expdir}MP.c" w} s_fd] } {
        perror "\[oml_code_generator\] could not open MP.c\n$s_fd"
        return
    }
    if { [catch {open "${::TBCOMPAT::expdir}MP.h" w} h_fd] } {
        perror  "\[oml_code_generator\] could not open MP.h\n$h_fd"
        return
    }

    # Make header C++ compatible
    puts $h_fd "#ifdef __cplusplus\nextern \"C\" {\n#endif\n\n"

    # write "#includes" into MP.c and MP.h
    oml_write_include $h_fd $s_fd

    # write definitions of measurement points.
    set i 0
    while { $i < [llength $oml_mps] } {
        set mp [lindex $oml_mps $i]
        #puts $mp
        tb-analyze-store-mp $mp $h_fd $s_fd
        incr i 1
    }

    # write initialization
    oml_write_init $h_fd $s_fd

    puts $h_fd "\n#ifdef __cplusplus\n}\n#endif\n"

    close $h_fd
    close $s_fd
}

