
# -*- tcl -*-
#
# Copyright (c) 2000-2012 University of Utah and the Flux Group.
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
# disk.tcl
#
# This defines the local disk agent.
#
######################################################################

Class Disk -superclass NSObject

namespace eval GLOBALS {
    set new_classes(Disk) {}
}

Disk instproc init {s} {
    global ::GLOBALS::last_class

    $self set sim $s
    $self set node {}
    $self set type {}
    $self set size 0
    $self set mountpoint {}
    $self set parameters {}
    $self set command {}

    # Link simulator to this new object.
    $s add_disk $self

    set ::GLOBALS::last_class $self
}

Disk instproc rename {old new} {
    $self instvar sim

    $sim rename_disk $old $new
}

# updatedb DB
# This adds rows to the virt_trafgens table corresponding to this agent.
Disk instproc updatedb {DB} {
    var_import ::GLOBALS::pid
    var_import ::GLOBALS::eid
    var_import ::TBCOMPAT::objtypes
    $self instvar node
    $self instvar type 
    $self instvar size
    $self instvar mountpoint 
    $self instvar parameters
    $self instvar sim
    $self instvar command

    if {$node == {}} {
	perror "\[updatedb] $self has no node."
	return
    }

    set fields [list "vname" "diskname" "disktype" "disksize" "mountpoint"]
    set values [list $node $self $type $size $mountpoint]

    if { $parameters != "" } {
	lappend fields "parameters"
	lappend values $parameters
    }
    if { $command != "" } {
	lappend fields "command"
	lappend values $command
    }

    # Update the DB
    spitxml_data "virt_node_disks" $fields $values

    $sim spitxml_data "virt_agents" [list "vnode" "vname" "objecttype" ] [list $node $self $objtypes(DISK) ]
}

