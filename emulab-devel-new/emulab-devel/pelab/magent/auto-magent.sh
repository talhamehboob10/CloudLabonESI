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

ARGS=$*

. `dirname $0`/../common-env.sh

#
# cd to the log directory so that any files that get written - cores, gprof
# files, etc. get put in a place where loghole will see them
#
cd $LOGDIR

TARGETS=$MAGENT

#
# Start up our own measurement agent
#
if [ ${MAGENT_NORECV:-0} -ne 0 ]; then
    port=`echo $ARGS | sed -e 's/.*--peerserverport=\([0-9][0-9]*\).*/\1/'`
    ARGS="$ARGS --nopeerserver"
    echo "${IPERFD_DIR}/$IPERFD -p $port"
    ${IPERFD_DIR}/$IPERFD -p $port &
    TARGETS="$TARGETS $IPERFD"
fi

#
# Start up the UDP receiver
#
if [ -x ${MAGENT_DIR}/UDP/UdpServerDir/UdpServer ]; then
    port=3492
    args="vnet $port"
    echo "${MAGENT_DIR}/UDP/UdpServerDir/UdpServer $args"
    $AS_ROOT ${MAGENT_DIR}/UDP/UdpServerDir/UdpServer $args &
    TARGETS="$TARGETS UdpServer"
fi

echo $SH ${MAGENT_DIR}/run-magent.sh $ARGS
$SH ${MAGENT_DIR}/run-magent.sh --daemonize $ARGS 
# Kill the agent if we get killed - TODO: harsher kill?
# Because the magent backgrounds itself, it's harder to figure out
# what its pid is, just just do a killall
# Note that we assume that a kill of us is "normal" and just exit 0.
trap "$AS_ROOT killall $TARGETS; exit 0" TERM

#
# Wait for all of the agents to start
#
echo "Waiting for measurement agents to become ready";
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
# We just sleep forever here as the stub has detached itself and
# we cannot exit without screwing up the program agent.  The program
# agent will kill us (and the magent by virtue of the trap) when it
# is good and ready.
#
while true; do sleep 1000; done
exit 0
