#!/bin/sh
#
# Copyright (c) 2005-2015 University of Utah and the Flux Group.
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
# Hack script to extract the latest temp/power/current values from the RPC
# power controller logs.  Used to generate data for the cricket grapher.
# Uses the ancient Utah "reverse cat" tac program.
#

tac="tail -r"

if [ $# -eq 0 ]; then exit 1; fi
host=$1
line=`$tac /usr/testbed/log/powermon.log | grep $host: | head -1`
temp=`echo "$line" | sed -n -e 's/.*, \([0-9][0-9]*\.*[0-9]*\)F$/\1/p'`
temp=${temp:-'0.0'}
power=`echo "$line" | sed -n -e 's/.*, \([0-9][0-9]*\.*[0-9]*\)W, .*/\1/p'`
power=${power:-'0.0'}
current=`echo "$line" | sed -n -e 's/.*: \([0-9][0-9]*\.*[0-9]*\)A, .*/\1/p'`
current=${current:-'0.0'}

echo $temp degrees F
echo $power Watts
echo $current Amps

exit 0
