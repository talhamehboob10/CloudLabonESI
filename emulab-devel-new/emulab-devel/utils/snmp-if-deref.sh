#!/bin/sh
#
# Copyright (c) 2006-2015 University of Utah and the Flux Group.
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

community="public"

SNMPGET="/usr/local/bin/snmpget -v 2c -c $community -m CISCO-STACK-MIB:CISCO-PAGP-MIB -Ovq"

if [ $# -lt 4 ]
then
    echo "usage: $0 <address> <module> <port> <ifEntry-attribute> [trunk]"
    exit 1
fi

addr=$1
module=$2
port=$3
attr=$4
trunk=$5
    

index=`$SNMPGET $addr portIfIndex.$module.$port 2> /dev/null`
if [ $? -eq 0 -a "x$index" != "x" ]
then
    if [ "x$trunk" = "xtrunk" ]
    then
        index=`$SNMPGET $addr pagpGroupIfIndex.$index 2> /dev/null`
    fi

    retval=`$SNMPGET $addr ifEntry.$attr.$index 2> /dev/null`
    if [ $? -eq 0 -a "x$retval" != "x" ]
    then
	echo $retval
	exit 0
    else
	echo "Error getting ifEntry attribute value: $attr" 1>&2
	exit 1
    fi
else
    echo "Error looking up index for module: $module, port: $port" 1>&2
    exit 1
fi
