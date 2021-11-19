# -*- tcl -*-
#
# Copyright (c) 2004-2010 University of Utah and the Flux Group.
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
# Timeline support.
#
######################################################################

Class EventTimeline

namespace eval GLOBALS {
    set new_classes(EventTimeline) {}
}

EventTimeline instproc init {s} {
    global ::GLOBALS::last_class

    $self set sim $s

    # event list is a list of {time vnode vname otype etype args atstring}
    $self set event_list {}
    $self set event_count 0

    set ::GLOBALS::last_class $self
}

EventTimeline instproc rename {old new} {
    $self instvar sim

    $sim rename_timeline $old $new
}

EventTimeline instproc dump {file} {
    $self instvar event_list

    foreach event $event_list {
	puts $file "$event"
    }
}

EventTimeline instproc at {time eventstring} {
    $self instvar sim
    $self instvar event_list
    $self instvar event_count
    
    set ptime [::GLOBALS::reltime-to-secs $time]
    if {$ptime == -1} {
	perror "Invalid time spec: $time"
	return
    }
    set time $ptime

    if {$event_count > 4000} {
	perror "Too many events in your NS file!"
	exit 1
    }
    set eventlist [split $eventstring ";"]
    
    foreach event $eventlist {
	set rc [$sim make_event "timeline" $event]

	if {$rc != {}} {
	    set event_count [expr $event_count + 1]
	    lappend event_list [linsert $rc 0 $time]
	}
    }
}

EventTimeline instproc updatedb {DB} {
    var_import ::GLOBALS::pid
    var_import ::GLOBALS::eid
    var_import ::TBCOMPAT::objtypes
    var_import ::TBCOMPAT::eventtypes
    var_import ::TBCOMPAT::triggertypes
    $self instvar sim
    $self instvar event_list
    
    foreach event $event_list {
        if {[string equal [lindex $event 0] "swapout"]} {
                set event [lreplace $event 0 0 0]
                set triggertype "SWAPOUT"
        } else {
                set triggertype "TIMER"
        }
       $sim spitxml_data "eventlist" [list "time" "vnode" "vname" "objecttype" "eventtype" "triggertype" "arguments" "atstring" "parent"] [list [lindex $event 0] [lindex $event 1] [lindex $event 2] $objtypes([lindex $event 3]) $eventtypes([lindex $event 4]) $triggertypes($triggertype) [lindex $event 5] [lindex $event 6] $self ]
    }

    $sim spitxml_data "virt_agents" [list "vnode" "vname" "objecttype" ] \
	    [list "*" $self $objtypes(TIMELINE)]
}
