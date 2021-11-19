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
# nse.agent.tcl
#
#
######################################################################

Class Agent

# Agent
Agent instproc init {args} {
    var_import GLOBALS::last_class
    var_import GLOBALS::last_cmd

    $self set nseconfig {}
    $self set classname "Agent"
    $self set objname $self
    $self set node {}
    $self set application {}
    $self set destination {}
    $self set ip {}
    $self set port {}

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
Agent instproc set_node {node} {
    $self set node $node
}
Agent instproc get_node {} {
    $self instvar node
    return $node
}
Agent instproc set_application {application} { 
    $self set application $application
}

Agent instproc connect {dst} {
    $self instvar destination
    $self instvar nseconfig
    $self instvar objname
    
    real_set destination $dst
    real_set sim [lindex [Simulator info instances] 0]
    append nseconfig "\$[$sim set objname] ip-connect \$$objname [$dst set ip] [$dst set port]\n"
}

Agent instproc unknown {m args} {

    $self instvar nseconfig
    $self instvar objname

    append nseconfig "\$$objname $m $args\n"
}

Class Application

# Application
Application instproc init {args} {
    var_import GLOBALS::last_class
    var_import GLOBALS::last_cmd

    $self set nseconfig {}
    $self set classname "Application"
    $self set objname $self

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

Application instproc attach-agent {agent} {
    $self set agent $agent
    $agent set_application $self
    $self instvar objname
    $self instvar createcmd
    $self instvar nseconfig

    append nseconfig "\$$objname attach-agent \$[$agent set objname]\n"
}

Application instproc get_node {} {
    $self instvar agent
    return [$agent get_node]
}

Application instproc unknown {m args} {

    $self instvar nseconfig
    $self instvar objname

    append nseconfig "\$$objname $m $args\n"
}
