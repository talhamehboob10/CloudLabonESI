# -*- tcl -*-
#
# Copyright (c) 2000-2003 University of Utah and the Flux Group.
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
# nse.null.tcl
#
# This defines the NullClass.  The NullClass is used for all classes
# created that we don't know about.  The NullClass will accept any
# method invocation with any arguments.  It will display an
# unsupported message in all such cases.
######################################################################

Class NullClass

NullClass instproc init {mtype} {
    $self set type $mtype
    $self set objname $self
}

NullClass instproc unknown {m args} {
    $self instvar type
    punsup "$type $m"
}
