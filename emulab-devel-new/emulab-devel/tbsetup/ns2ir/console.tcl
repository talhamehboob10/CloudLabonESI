# -*- tcl -*-
#
# Copyright (c) 2000-2005 University of Utah and the Flux Group.
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
# console.tcl
#
# This defines the console agent.
#
######################################################################

Class Console -superclass NSObject

namespace eval GLOBALS {
    set new_classes(Console) {}
}

Console instproc init {s n} {
    $self set sim $s
    $self set node $n
    $self set connected 0
}

Console instproc rename {old new} {
    $self instvar sim

    $sim rename_console $old $new
}

# updatedb DB
# This adds rows to the virt_trafgens table corresponding to this agent.
Console instproc updatedb {DB} {
    var_import ::GLOBALS::pid
    var_import ::GLOBALS::eid
    var_import ::TBCOMPAT::objtypes
    $self instvar node
    $self instvar sim

    if {$node == {}} {
	perror "\[updatedb] $self has no node."
	return
    }

    # Update the DB
    $sim spitxml_data "virt_agents" [list "vnode" "vname" "objecttype"] [list $node $self $objtypes(CONSOLE)]
}
