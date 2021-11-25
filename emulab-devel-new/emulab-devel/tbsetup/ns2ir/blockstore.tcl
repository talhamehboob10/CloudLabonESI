# -*- tcl -*-
#
# Copyright (c) 2012-2016 University of Utah and the Flux Group.
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
# blockstore.tcl
#
# This class defines the blockstore storage object.  Note: Each
# blockstore object's finalize() method MUST be called AFTER all of
# the set-* calls, but BEFORE the updatedb() method.  Generally,
# finalize() should be called once it is clear that no other set-*
# methods will be called; before the object is used.  E.g., the
# sim.tcl code calls finalize() for all blockstore object near the top
# of the run() method.
#
######################################################################

Class Blockstore -superclass NSObject

namespace eval GLOBALS {
    set new_classes(Blockstore) {}
}

Blockstore instproc init {s} {
    global ::GLOBALS::last_class

    $self set sim $s
    $self set node {}
    $self set type {}
    $self set size 0
    $self set role "unknown"
    $self set leasename {}
    # for compat with LanLink
    $self set simulated 0

    # storage attributes (class, protocol, etc.)
    $self instvar attributes
    array set attributes {}

    set ::GLOBALS::last_class $self
}

Blockstore instproc rename {old new} {
    $self instvar sim

    $sim rename_blockstore $old $new
}

Blockstore instproc set-class {newclass} {
    var_import ::TBCOMPAT::soclasses
    $self instvar attributes

    if {![info exists soclasses($newclass)]} {
	perror "\[set-class] Invalid storage class: $newclass"
	return
    }

    set attributes(class) $newclass
    return
}

Blockstore instproc set-protocol {newproto} {
    var_import ::TBCOMPAT::soprotocols
    $self instvar attributes

    if {![info exists soprotocols($newproto)]} {
	perror "\[set-protocol] Invalid storage protocol: $newproto"
	return
    }

    set attributes(protocol) $newproto
    return
}

Blockstore instproc set-type {newtype} {
    var_import ::TBCOMPAT::sotypes
    $self instvar type

    if {![info exists sotypes($newtype)]} {
	perror "\[set-type] Invalid storage object type: $newtype"
	return
    }

    set type $type
    return
}

Blockstore instproc set-lease {lname} {
    var_import ::TBCOMPAT::dataset_node
    var_import ::TBCOMPAT::dataset_index
    var_import ::GLOBALS::pid
    var_import ::GLOBALS::anonymous
    var_import ::GLOBALS::passmode
    $self instvar leasename
    $self instvar attributes

    set fullname $lname
    set index 0
    if {! ${GLOBALS::anonymous} && ! ${GLOBALS::passmode}} {
	if {[string first / $lname] == -1} {
	    set fullname "$pid/"
	    append fullname $lname
	}
	if {![info exists dataset_node($fullname)]} {
	    perror "\[set-lease] Invalid lease name $lname ($fullname)"
	    return
	}
	set index $dataset_index($fullname)
    }
    set leasename $fullname
    set attributes(lease) $index
    return
}

Blockstore instproc set-placement {newplace} {
    var_import ::TBCOMPAT::soplacementdesires
    $self instvar attributes

    set newplace [string toupper $newplace]
    if {![info exists soplacementdesires($newplace)]} {
	perror "Invalid placement specified: $newplace"
	return
    }

    set attributes(placement) $newplace
    return
}

Blockstore instproc set-mount-point {newmount} {
    var_import ::TBCOMPAT::sodisallowedmounts
    $self instvar attributes
    $self instvar node

    # Keep the mount point path rules simple but strict:
    #  * Must start with a forward slash (absolute path)
    #  * Directory names must only consist of characters in: [a-zA-Z0-9_]
    #  * Two forward slashes in a row not allowed
    #  * Optionally end with a forward slash
    if {![regexp {^(/\w+){1,}/?$} $newmount]} {
	perror "Bad mountpoint: $newmount"
	return
    }

    # Try to prevent user from shooting their own foot.
    if {[lsearch -exact $sodisallowedmounts $newmount] != -1} {
	perror "Cannot mount over important system directory: $newmount"
	return
    }

    set attributes(mountpoint) $newmount
    return
}

Blockstore instproc load-dataset {dataset} {
    $self instvar attributes
    $self instvar node
    $self instvar type

    set attributes(dataset) $dataset
    set type "imdataset"
    return
}

Blockstore instproc set-size {newsize} {
    $self instvar node
    $self instvar size

    set mindisksize 1; # 1 MiB

    # Convert various input size strings to mebibytes.
    set convsize [convert_to_mebi $newsize]

    # Do some boundary checks.
    if { $convsize < $mindisksize } {
	perror "\[set-size] $newsize is smaller than allowed minimum (1 MiB)"
	return
    }

    set size $convsize
    return
}

Blockstore instproc set-readonly {roflag} {
    $self instvar attributes

    if {$roflag != 0} {
	set roflag 1
    }

    if {$roflag &&
	[info exists attributes(rwclone)] && $attributes(rwclone) != 0} {
	perror "\[set-readonly] cannot set both readonly and rwclone"
	return
    }
    set attributes(readonly) $roflag
    return
}

Blockstore instproc set-rwclone {flag} {
    $self instvar attributes

    if {$flag != 0} {
	set flag 1
    }

    if {$flag &&
	[info exists attributes(readonly)] && $attributes(readonly) != 0} {
	perror "\[set-rwclone] cannot set both rwclone and readonly"
	return
    }
    set attributes(rwclone) $flag
    return
}

Blockstore instproc set-prereserve {flag} {
    $self instvar attributes

    if {$flag != 0} {
	set flag 1
    }

    set attributes(prereserve) $flag
    return
}

#
# Alias for procedure below
#
Blockstore instproc set-node {pnode} {
    return [$self set_fixed $pnode]
}

#
# Explicitly fix a blockstore to a node.
#
Blockstore instproc set_fixed {pnode} {
    $self instvar sim
    $self instvar node
    $self instvar attributes

    if { [$pnode info class] != "Node" } {
	perror "Can only fix blockstores to a node object!"
	return
    }

    set node $pnode

    return
}

# Create a "blockstore" pseudo-VM to represent the blockstore as a
# node object within the guts of Emulab.
Blockstore instproc alloc_pseudonode {} {
    $self instvar sim

    # Allocate blockstore pseudo-VM
    set hname "blockhost-${self}"
    uplevel "#0" "set $hname [$sim node]"
    $hname set_hwtype "blockstore" 0 1 0

    return $hname
}

# Create a node object to represent the host that contains this blockstore,
# or return it if it already exists.
Blockstore instproc get_node {} {
    $self instvar node

    if {$node == {}} {
	set node [$self alloc_pseudonode]
    }

    return $node
}

# Do final (AFTER set-*, but BEFORE updatedb) validations and
# initializations.
Blockstore instproc finalize {} {
    var_import ::TBCOMPAT::sodefaultplacement
    var_import ::TBCOMPAT::sopartialplacements
    var_import ::TBCOMPAT::sofullplacements
    var_import ::TBCOMPAT::soplacementdesires
    var_import ::TBCOMPAT::sonodemounts
    var_import ::TBCOMPAT::dataset_node
    var_import ::TBCOMPAT::dataset_size
    var_import ::TBCOMPAT::dataset_type
    var_import ::TBCOMPAT::dataset_bsid
    var_import ::TBCOMPAT::dataset_readonly
    $self instvar sim
    $self instvar node
    $self instvar size
    $self instvar type
    $self instvar attributes
    $self instvar leasename

    # Die if the user didn't attach the blockstore to anything.
    if { $node == {} } {
	perror "Blockstore is not attached to anything: $self"
	return -1
    }

    # Check RO status
    set ro 0
    if {[info exists attributes(readonly)]} {
	set ro $attributes(readonly)
	# RO anon blockstore is just dumb
	if {$leasename == {} && $ro} {
	    puts stderr "*** WARNING: marking ephemeral blockstore $self read-only is useless, ignoring RO setting"
	    set ro 0
	}
    }
    set attributes(readonly) $ro

    # Check RW clone status
    set rwclone 0
    if {[info exists attributes(rwclone)]} {
	set rwclone $attributes(rwclone)
	# RW clone of anon blockstore is equally dumb
	if {$leasename == {} && $rwclone} {
	    puts stderr "*** WARNING: marking ephemeral blockstore $self as RW-clone is useless, ignoring rwclone setting"
	    set rwclone 0
	}
    }
    set attributes(rwclone) $rwclone

    # Check prereserve
    set prereserve 0
    if {[info exists attributes(prereserve)]} {
	set prereserve $attributes(prereserve)
	# Prereserve only applies to RW clones
	if {$rwclone == 0 && $prereserve} {
	    puts stderr "*** WARNING: space pre-reservation only applies to RW-clones, ignoring setting on $self"
	    set prereserve 0
	}
    }
    set attributes(prereserve) $prereserve

    # If the blockstore is associated with a lease, disallow/override certain
    # explicitly-specified values
    if {$leasename != {}} {
	var_import ::GLOBALS::anonymous
	var_import ::GLOBALS::passmode
	var_import ::GLOBALS::pid

	if {$size != 0 || $type != {} ||
	    [info exists attributes(class)] ||
	    [info exists attributes(protocol)]} {
	    perror "Cannot explicitly set size/type/class/protocol of lease-associated blockstore $self"
	    return -1
	}
	if {$ro == 0 && $rwclone == 0 &&
	    [info exists dataset_readonly($leasename)] &&
	    $dataset_readonly($leasename) != 0} {
	    perror "Cannot RW access RO lease-associated blockstore $self"
	    return -1
	}

	if {! ${GLOBALS::anonymous} && ! ${GLOBALS::passmode}} {
	    set size $dataset_size($leasename)
	    set type $dataset_type($leasename)
	} else {
	    set size 1
	    set type "stdataset"
	}
	# XXX
	set attributes(class) "SAN"
	set attributes(protocol) "iSCSI"
	set attributes(leasename) $leasename
    }

    # Make sure the blockstore has class...
    if {![info exists attributes(class)]} {
	perror "Blockstore's class must be specified: $self"
	return -1
    }
    set myclass $attributes(class)

    # Remote blockstore validation/handling.
    if {$myclass == "SAN"} {
	# Size matters here.
	if {$size == 0} {
	    perror "Remote blockstores must have a size: $self"
	    return -1
	}
	# Placement directives are invalid for remote blockstores.
	if {[info exists attributes(placement)]} {
	    perror "Placement setting only makes sense with local blockstores: $self"
	    return -1
	}
	# Deal with some syntactic sugar for 1-to-1 bindings to nodes.
	if {[$node set type] != "blockstore"} {
	    set pnode $node
	    set node [$self alloc_pseudonode]
	    uplevel "#0" "set ${self}-link [$sim duplex-link $pnode $node ~ 0ms DropTail]"
	    ${self}-link set sanlan 1
	}
	# Die if the user has attempted to connect the blockstore via multiple
	# links.  We only support one.
	if {[llength [$node set portlist]] != 1} {
	    perror "A remote blockstore must be connected to one, and only one, link/lan: $self"
	    return -1
	}
    }

    #
    # Local node hacks and stuff.  For local blockstores, we simply add
    # a disk space 'desire' to the attached node.
    #
    # Also perform validation checks.
    #
    if {$myclass == "local"} {
	# Initialization for placement.
	if {![info exists attributes(placement)]} {
	    set attributes(placement) $sodefaultplacement
	} 
	set myplace $attributes(placement)
	set nodeplace "${node}:${myplace}"
	if {![info exists sopartialplacements($nodeplace)]} {
	    set sopartialplacements($nodeplace) 0
	}
	if {![info exists sofullplacements($nodeplace)]} {
	    set sofullplacements($nodeplace) 0
	}

	# Add a desire for space of the given placement type.
	set pldesire $soplacementdesires($myplace)
	if {$size != 0} {
	    set cursize [$node get-desire $pldesire]
	    if {$cursize == {}} {
		set cursize 0
	    }
	    $node add-desire $pldesire [expr $size + $cursize] 1
	    incr sopartialplacements($nodeplace) 1
	} else {
	    # In the case of a full-sized placement, add a token 1MiB
	    # desire just to make sure something is there.
	    $node add-desire $pldesire 1 1
	    incr sofullplacements($nodeplace) 1
	}

	# Check that there is only one sysvol placement per node
	set systotal [expr $sopartialplacements($nodeplace) + \
			   $sofullplacements($nodeplace)]
	if { $myplace == "SYSVOL" && $systotal > 1 } {
	    perror "Only one sysvol placement allowed per node: $node"
	    return -1
	}

	# Sanity check for full placements.  There can be only one per node
	# per placement type.
	if { $sofullplacements($nodeplace) > 1 ||
	     ($sofullplacements($nodeplace) == 1 &&
	      $sopartialplacements($nodeplace) > 0) } {
	    perror "Full placement collision found for $nodeplace"
	    return -1
	}

	# Look for an incompatible mix of "ANY" and other placements (per-node).
	set srchres 0
	set allplacements \
	    [concat \
		 [array names sopartialplacements -glob "${node}:*"] \
		 [array names sofullplacements -glob "${node}:*"]]
	if {$myplace == "ANY"} {
	    set srchres [lsearch -exact -not $allplacements "${node}:ANY"]
	} else {
	    set srchres [lsearch -exact $allplacements "${node}:ANY"]
	}
	if {$srchres != -1} {
	    perror "Incompatible mix of 'ANY' and other placements on $node"
	    return -1
	}
    }

    # Check for node mount collisions.
    if {[info exists attributes(mountpoint)]} {
	set mymount $attributes(mountpoint)
	set mynode $node

	# Dig up the other end of the link for remote blockstores since the
	# node there will be the one doing the mounting.
	if {$myclass == "SAN"} {
	    # We only support a single link/lan - checked above.
	    set link [lindex [$node set portlist] 0]
	    # Don't allow mount points for shared remote blockstores (i.e.,
	    # blockstores on a lan.
	    if {[$link info class] != "Link"} {
		perror "Cannot specify a mount point for blockstores connected to multiple nodes (i.e., on a lan): $self"
		return -1
	    }
	    set src [$link set src_node]
	    set dst [$link set dst_node]
	    set mynode [expr {$src == $node ? $dst : $src}]
	}

	# Bit of init.
	if {![info exists sonodemounts($mynode)]} {
	    set sonodemounts($mynode) {}
	}

	# Look through all mount points for other blockstores attached
	# to the same node as this blockstore.
	set mplist [lreplace [split $mymount   "/"] 0 0]
	foreach nodemount $sonodemounts($mynode) {
	    set nmlist [lreplace [split $nodemount "/"] 0 0]
	    set diff 0
	    # Look for any differences in path components.  If one is a 
	    # matching prefix of the other, then the mount is nested or
	    # identical.
	    foreach nmcomp $nmlist mpcomp $mplist {
		# Have we hit the end of the list for one or the other?
		if {$nmcomp == {} || $mpcomp == {}} {
		    break
		} elseif {$nmcomp != $mpcomp} {
		    set diff 1
		    break
		}
	    }
	    if {!$diff} {
		perror "Mount collision or nested mount detected on $node: $mymount, $nodemount"
		return -1
	    }
	}
	lappend sonodemounts($mynode) $mymount
    }
    
    return 0
}

# updatedb DB
# This adds rows to the virt_blockstores and virt_blockstore_attributes 
# tables, corresponding to this storage object.
Blockstore instproc updatedb {DB} {
    var_import ::GLOBALS::pid
    var_import ::GLOBALS::eid
    var_import ::TBCOMPAT::sodesires
    $self instvar sim
    $self instvar node
    $self instvar type
    $self instvar size
    $self instvar role
    $self instvar attributes

    # XXX: blockstore role needs more thought...
    #if { $role == "unknown" } {
    #    puts stderr "*** WARNING: blockstore role not set and unable to infer it."
    #}

    # Emit top-level storage object stuff.
    set vb_fields [list "vname" "type" "role" "size" "fixed"]
    set vb_values [list $self $type $role $size $node]
    $sim spitxml_data "virt_blockstores" $vb_fields $vb_values

    # Emit attributes.
    foreach key [lsort [array names attributes]] {
	set val $attributes($key)
	set vba_fields [list "vname" "attrkey" "attrvalue" "isdesire"] 
	set vba_values [list $self $key $val]
	
	set isdesire [expr [info exists sodesires($key)] ? 1 : 0]
	lappend vba_values $isdesire

	$sim spitxml_data "virt_blockstore_attributes" $vba_fields $vba_values

    }
}
