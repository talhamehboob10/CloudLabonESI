# -*- tcl -*-
#
# Copyright (c) 2005 University of Utah and the Flux Group.
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

Class Topography -superclass NSObject

namespace eval GLOBALS {
    set new_classes(Topography) {}
}

Topography instproc init {} {
    global ::GLOBALS::last_class

    $self set sim {}
    $self set area_name {}
    $self set width {}
    $self set height {}

    set ::GLOBALS::last_class $self
}

Topography instproc rename {old new} {
    $self instvar sim

    if {$sim != {}} {
	$sim rename_topography $old $new
    }
}

## Topography instproc load_flatgrid {width height} {
##    if {$width < 0} {
##	perror "\[load_flatgrid] negative width - $width"
##	return
##    }
##    if {$height < 0} {
##	perror "\[load_flatgrid] negative height - $height"
##	return
##    }
##
##    $self set width $width
##    $self set height $height
## }

Topography instproc load_area {area} {
    if {! [info exists ::TBCOMPAT::areas($area)]} {
	perror "\[load_area] Unknown area $area."
	return
    }

    $self set area_name $area
    # XXX Load the width/height of the floor in here.
    $self set width 50.0
    $self set height 50.0
}

Topography instproc initialized {} {
    $self instvar width
    $self instvar height

    if {$width != {} && $height != {}} {
	return 1
    } else {
	return 0
    }
}

Topography instproc checkdest {obj x y args} {
    var_import ::TBCOMPAT::obstacles
    var_import ::TBCOMPAT::cameras
    $self instvar area_name
    $self instvar width
    $self instvar height

    ::GLOBALS::named-args $args {
	-showerror 0
    }

    if {$x < 0 || $x >= $width} {
	if {$(-showerror)} {
	    perror "$x is out of bounds for node \"$obj\""
	}
	return 0
    }
    if {$y < 0 || $y >= $height} {
	if {$(-showerror)} {
	    perror "$y is out of bounds for node \"$obj\""
	}
	return 0
    }
    
    if {$area_name != {}} {
	set oblist [array get obstacles *,$area_name,description]
	foreach {key value} $oblist {
	    set id [lindex [split $key ,] 0]
	    
	    if {($x >= [expr $obstacles($id,$area_name,x1) - 0.25]) &&
	        ($x <= [expr $obstacles($id,$area_name,x2) + 0.25]) &&
	        ($y >= [expr $obstacles($id,$area_name,y1) - 0.25]) &&
	        ($y <= [expr $obstacles($id,$area_name,y2) + 0.25])} {
		    if {$(-showerror)} {
			perror "Destination $x,$y puts $obj in obstacle $value."
		    }
		    return 0
	    }
	}
	
	set camlist [array get cameras *,$area_name,x]
	set in_cam ""
	foreach {key value} $camlist {
	    set id [lindex [split $key ,] 0]

	    if {($x >= $cameras($id,$area_name,x)) &&
	        ($x < [expr $cameras($id,$area_name,x) + \
		       $cameras($id,$area_name,width)]) &&
	        ($y >= $cameras($id,$area_name,y)) &&
	        ($y < [expr $cameras($id,$area_name,y) + \
		       $cameras($id,$area_name,height)])} {
		set in_cam $id
	    }
	}

	if {$in_cam == ""} {
	    if {$(-showerror)} {
		perror "Destination $x,$y is out of view of the tracking cameras";
	    }
	    return 0
	}
    }
    return 1
}

Topography instproc updatedb {DB} {
    var_import ::TBCOMPAT::objtypes
    $self instvar sim

    if {$sim != {}} {
	$sim spitxml_data "virt_agents" [list "vnode" "vname" "objecttype" ] \
		[list "*" $self $objtypes(TOPOGRAPHY)]
    }
}
