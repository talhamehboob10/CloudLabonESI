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
# Load in the appropriate environment variables
#
. `dirname $0`/../monitor/instrument-env.sh

#
# Blank a couple out so that we don't try to talk to netmond
#
export -n LIBNETMON_SOCKPATH
export -n LIBNETMON_CONTROL_SOCKPATH

#
# Make sure we can get coredumps
#
ulimit -c unlimited

#
# Get a new version of the output
#
export LIBNETMON_OUTPUTVERSION=3
export LIBNETMON_MONITORUDP=1

echo "Instrumenting '$@' with libnetmon"
exec $@
