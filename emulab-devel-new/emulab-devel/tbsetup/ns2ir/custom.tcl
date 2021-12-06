# -*- tcl -*-
#
# Copyright (c) 2000-2006 University of Utah and the Flux Group.
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
# Custom.tcl
#
# This defines the local custom agent. Modify this as you need.
#
######################################################################

Class Custom -superclass NSObject

namespace eval GLOBALS {
    set new_classes(Custom) {}
}

Custom instproc init {s} {
    global ::GLOBALS::last_class

    $self set sim $s
    $self set node {}
    $self set name {}

    # Link simulator to this new object.
    $s add_custom $self

    set ::GLOBALS::last_class $self
}

Custom instproc rename {old new} {
    $self instvar sim

    $sim rename_custom $old $new
}

# updatedb DB
# This adds rows to the virt_trafgens table corresponding to this agent.
Custom instproc updatedb {DB} {
    var_import ::GLOBALS::pid
    var_import ::GLOBALS::eid
    var_import ::TBCOMPAT::objtypes
    $self instvar node
    $self instvar name 
    $self instvar sim

    if {$node == {}} {
	perror "\[updatedb] $self has no node."
	return
    }
    set progvnode $node

    #
    # if the attached node is a simulated one, we attach the
    # program to the physical node on which the simulation runs
    #
    if {$progvnode != "ops"} {
	if { [$node set simulated] == 1 } {
	    set progvnode [$node set nsenode]
	}
    }

    # Update the DB
    $sim spitxml_data "virt_agents" [list "vnode" "vname" "objecttype" ] [list $progvnode $self $objtypes(CUSTOM) ]
}

