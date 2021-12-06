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
# Script to run the monitor, collecting data from libnetmon
#

#
# Let common-env know what role we're playing
#
export HOST_ROLE="monitor"

#
# Grab common environment variables
#
. `dirname $0`/../common-env.sh

#
# Just run it!
#
echo "Running PID $$"
echo "Starting dbmonitor, Extra arguments: $*"

# XXX cd is temporary until libtbdb.pm is in all images
cd $DBMONITOR_DIR
exec $AS_ROOT ./$DBMONITOR $* $PID $EID
