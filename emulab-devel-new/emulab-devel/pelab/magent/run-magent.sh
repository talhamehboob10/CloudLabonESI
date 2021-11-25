#!/bin/sh
#
# Copyright (c) 2006 University of Utah and the Flux Group.
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
# Script to run the monitoring agent
#

#
# Let common-env know what role we're playing
#
export HOST_ROLE="stub"

#
# Grab common environment variables
#
. `dirname $0`/../common-env.sh

#
# Have libnetmon export to a seperate file
#
export LIBNETMON_OUTPUTFILE="/local/logs/libnetmon.out"

#
# Just run the stub!
#
uptime
echo "Running PID $$"
echo "Starting magent on $PLAB_IFACE ($PLAB_IP) Extra arguments: $*"
#exec $AS_ROOT strace $MAGENT_DIR/$MAGENT --interface=$PLAB_IFACE --replay-save=/local/logs/stub.replay $*
exec $AS_ROOT $NETMON_DIR/instrument-standalone.sh $MAGENT_DIR/$MAGENT --interface=$PLAB_IFACE --replay-save=/local/logs/stub.replay $*
