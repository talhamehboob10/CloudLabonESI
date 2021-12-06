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

ARGS=$*

. `dirname $0`/../common-env.sh

#
# Start up our own stub
#
echo $SH ${STUB_DIR}/run-stub.sh $ARGS
$SH ${STUB_DIR}/run-stub.sh $ARGS &
STUBPID=$!
# Kill the stub if we get killed - TODO: harsher kill?
# Note that we assume that a kill of us is "normal" and just exit 0.
trap "{ $AS_ROOT kill $STUBPID; $AS_ROOT killall stubd; true; }" TERM

#
# Give it time to come up
#
sleep 1

#
# Wait for all of the stubs to start
#
echo "Waiting for stubs to become ready";
barrier_wait "stub"; _rval=$?
if [ $_rval -ne 0 ]; then
    echo "*** WARNING: not all stubs started ($_rval)"
fi

#
# Wait for all the monitors to come up
#
echo "Waiting for monitors to become ready";
barrier_wait "monitor"; _rval=$?
if [ $_rval -ne 0 ]; then
    echo "*** WARNING: not all monitors started ($_rval)"
fi

echo "Running!";

#
# Wait for our monitor to finish
# XXX ignores exit status of child
#
wait
status=$?
if [ $status -eq 15 ]; then
    status=0
fi
exit $status
