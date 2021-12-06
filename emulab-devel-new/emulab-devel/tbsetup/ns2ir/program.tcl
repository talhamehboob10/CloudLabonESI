# -*- tcl -*-
#
# Copyright (c) 2000-2006, 2017 University of Utah and the Flux Group.
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
# program.tcl
#
# This defines the local program agent.
#
######################################################################

Class Program -superclass NSObject

namespace eval GLOBALS {
    set new_classes(Program) {}
    variable all_programs {}
}

Program instproc init {s} {
    global ::GLOBALS::last_class
    global ::GLOBALS::all_programs

    if {$all_programs == {}} {
	# Create a default event group to hold all program agents.
	set foo [uplevel \#0 "set __all_programs [new EventGroup $s]"]
	set all_programs $foo
    }
    $all_programs add $self

    $self set sim $s
    $self set node {}
    $self set command {}
    $self set dir {}
    $self set timeout {}
    $self set expected-exit-code {}

    # Link simulator to this new object.
    $s add_program $self

    set ::GLOBALS::last_class $self
}

Program instproc rename {old new} {
    global ::GLOBALS::all_programs
    $self instvar sim

    $sim rename_program $old $new
    $all_programs rename-agent $old $new
}

# updatedb DB
# This adds rows to the virt_trafgens table corresponding to this agent.
Program instproc updatedb {DB} {
    var_import ::GLOBALS::pid
    var_import ::GLOBALS::eid
    var_import ::TBCOMPAT::objtypes
    $self instvar node
    $self instvar command
    $self instvar dir
    $self instvar timeout
    $self instvar expected-exit-code
    $self instvar sim

    if {$node == {}} {
	perror "\[updatedb] $self has no node."
	return
    }
    if { [string first \n $command] != -1 } {
	perror "\[updatedb] $self has disallowed newline in command: $command"
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
    set fields [list "vnode" "vname" "command" "dir"]
    set values [list $progvnode $self $command $dir]
    if {$timeout != {}} {
	lappend fields "timeout"
	lappend values $timeout
    }
    if {${expected-exit-code} != {}} {
	lappend fields "expected_exit_code"
	lappend values ${expected-exit-code}
    }
    $sim spitxml_data "virt_programs" $fields $values    

    $sim spitxml_data "virt_agents" [list "vnode" "vname" "objecttype" ] [list $progvnode $self $objtypes(PROGRAM) ]
}

