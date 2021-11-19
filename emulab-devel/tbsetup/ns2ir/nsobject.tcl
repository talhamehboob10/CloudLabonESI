# -*- tcl -*-
#
# Copyright (c) 2000-2002 University of Utah and the Flux Group.
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
# nsobject.tcl
#
# This defines the class NSObject which most other classes derive from.
# Base defines the unknown procedure which deals with unknown 
# method calls.
######################################################################
Class NSObject

# unknown 
# This is invoked whenever any method is called on the object that is
# not defined.  We display a warning message and otherwise ignore it.
NSObject instproc unknown {m args} {
    punsup "[$self info class] $m"
}
