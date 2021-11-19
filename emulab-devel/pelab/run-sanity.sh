#!/bin/sh
#
# Copyright (c) 2006, 2007 University of Utah and the Flux Group.
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

#
# This is really only needed in order to start/stop tcpdump as root...
#

if [ $# -lt 2 ]; then
    echo "usage: run-sanity iface node"
    exit 1
fi
iface=$1
node=$2
if [ $# -eq 4 ]; then
  tdexpr="( ( tcp and dst port $3 ) or ( udp and dst port $4 ) )"
else
  tdexpr="( tcp or udp )"
fi

ARGS="-i $iface -w /local/logs/SanityCheck.log dst host $node and $tdexpr"
echo "Running tcpdump $ARGS"
sudo tcpdump $ARGS &
PID=$!
trap "sudo kill $PID; sudo killall tcpdump" EXIT
wait
exit 0
