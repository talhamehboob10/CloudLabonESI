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
# nse.node.tcl
#
# This defines the Node class.  Instances of this class are created by
# the 'node' method of Simulator.  A Node is connected to a number of
# LanLinks.  Each such connection is associated with a virtual port,
# an integer.  Each virtual port also has an IP address.  Virtual
# ports start at 0 and go up continuously.  Besides the port
# information each node also has a variety of strings.  These strings
# are set by tb-* commands and dumped to the DB but are otherwise
# uninterpreted.
######################################################################

Class Node

Node instproc init {args} {
    var_import GLOBALS::last_class
    var_import GLOBALS::last_cmd

    $self set nseconfig {}
    $self set classname "Node"
    $self set objname $self
    $self set next_portnumber 5000

    $self instvar classname

    if { $last_cmd == {} } {
	if { $args == {} } {
	    $self set createcmd "\[new $classname]"
	} else {
	    $self set createcmd "\[new $classname $args]"
	}
    } else {
	$self set createcmd $last_cmd
    }

    real_set last_class $self
}

# Attach an agent to a node. This mainly a bookkeeping device so
# that the we can update the DB at the end.
Node instproc attach-agent {agent} {
    $self instvar agentlist
    $self instvar nseconfig
    $self instvar objname
    var_import GLOBALS::last_cmd

    lappend agentlist $agent
#    $agent set_node $self

#    append nseconfig "\$$objname attach-agent \$[$agent set objname]\n"
}

Node instproc unknown {m args} {

    $self instvar nseconfig
    $self instvar objname

    append nseconfig "\$$objname $m $args\n"
}

Node instproc nextportnumber {} {
    $self instvar next_portnumber
    
    set next_port [incr next_portnumber]
    return $next_port    
}