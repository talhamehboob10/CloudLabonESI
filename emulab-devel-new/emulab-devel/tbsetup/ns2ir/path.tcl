# -*- tcl -*-
#
# Copyright (c) 2000-2010 University of Utah and the Flux Group.
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
# path.tcl
#
# A path is comprised of a set of links.
######################################################################

Class Path -superclass NSObject

namespace eval GLOBALS {
    set new_classes(Path) {}
}

Path instproc init {s links} {
    # This is a list of the links
    $self set mylinklist $links

    # The simulator
    $self set sim $s
}

Path instproc rename {old new} {
    $self instvar sim
    $self instvar mylinklist

    $sim rename_path $old $new
}

Path instproc updatedb {DB} {
    $self instvar mylinklist
    var_import ::GLOBALS::pid
    var_import ::GLOBALS::eid
    $self instvar sim
    
    set idx 0
    set layer 0

    foreach link $mylinklist {
	set layer  [$link set layer]
	set fields [list "pathname" "segmentname" "segmentindex" "layer"]
	set values [list $self $link $idx $layer]

	$sim spitxml_data "virt_paths" $fields $values	

	incr idx
    }
}
