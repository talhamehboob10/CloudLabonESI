# -*- tcl -*-
#
# Copyright (c) 2004-2006 University of Utah and the Flux Group.
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
#
# Event group support.
#
######################################################################

Class EventGroup -superclass NSObject

namespace eval GLOBALS {
    set new_classes(EventGroup) {}
}

EventGroup instproc init {s} {
    global ::GLOBALS::last_class

    $self set sim $s
    $self set mytype {}
    
    $self instvar members
    array set members {}

    # Link simulator to this new object.
    $s add_eventgroup $self

    set ::GLOBALS::last_class $self
}

EventGroup instproc rename {old new} {
    $self instvar sim

    $sim rename_eventgroup $old $new
}

EventGroup instproc rename-agent {old new} {
    $self instvar members

    if { [info exists members($old)] } {
	unset members($old)
	set members($new) {}
    }
}

#
# Add members to the event group. 
# 
EventGroup instproc add {args} {
    $self instvar members
    $self instvar mytype

    foreach obj $args {
	if {[$obj info class] == "Lan" || [$obj info class] == "Link"} {
	    set thisclass "LanLink"
	} else {
	    set thisclass [$obj info class]
	}
	
	if {$mytype == {}} {
	    set mytype $thisclass
	}
	
	if {$thisclass != $mytype} {
	    perror "\[$self add $obj] All members must be of the same type!"
	    return
	}
	set members($obj) {}
    }
}

#
# Return list of member objects
# 
EventGroup instproc members {} {
    $self instvar members

    return [array names members]
}

# updatedb DB
EventGroup instproc updatedb {DB} {
    var_import ::GLOBALS::pid
    var_import ::GLOBALS::eid
    $self instvar members
    $self instvar sim

    if {[array size members] == 0} {
	return
    }

    foreach member [array names members] {
	if {[$member info class] == "Queue"} {
	    set agent_name [$member agent_name]
	} else {
	    set agent_name $member
	}
	
	set names [list "group_name" "agent_name"]
	set vals  [list $self $agent_name]
	$sim spitxml_data "event_groups" $names $vals
    }
}

