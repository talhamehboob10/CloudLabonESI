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

ARGS=$*

#
# Let common-env know what role we're playing
#
export HOST_ROLE="monitor"

#
# Grab common environment variables
#
. `dirname $0`/../common-env.sh

REAL_PLAB=0
if [ $# != 0 ]; then
    if [ $# -ge 3 ]; then
      echo "Usage: $0 [stub-ip]"
      exit 1;
    fi
    if [ $1 = "-p" ]; then
        REAL_PLAB=1
        SIP=$2
    else
        SIP=$1
    fi

fi

# XXX can we possibly get any more lame than this?
if [ -e /proj/$PROJECT/exp/$EXPERIMENT/tmp/real_plab ]; then
    REAL_PLAB=1
fi

if ! [ -x "$NETMON_DIR/$NETMOND" ]; then
    gmake -C $NETMON_DIR $NETMOND
fi

if ! [ -x "$NETMON_DIR/$NETMOND" ]; then
    echo "$NETMON_DIR/$NETMOND missing - run 'gmake' in $NETMOND_DIR to build it"
    exit 1;
fi

if [ $REAL_PLAB -eq 1 ]; then
    echo "Generating IP mapping file for the real PlanetLab into $IPMAP";
    $PERL ${MONITOR_DIR}/$GENIPMAP -p > $IPMAP
else
    echo "Generating IP mapping file for fake PlanetLab into $IPMAP";
    $PERL ${MONITOR_DIR}/$GENIPMAP > $IPMAP
fi

INITARG=""
if [ -r "/proj/$PROJECT/exp/$EXPERIMENT/tmp/initial-conditions.txt" ]; then
    echo "Copy over initial conditions file for the real PlanetLab nodes";
    cp -p /proj/$PROJECT/exp/$EXPERIMENT/tmp/initial-conditions.txt $INITCOND
    INITARG="--initial=$INITCOND"
fi


#echo "Starting up monitor for $PROJECT/$EXPERIMENT $PELAB_IP $SIP";
echo "Starting up monitor with options --mapping=$IPMAP --experiment=$PROJECT/$EXPERIMENT --ip=$PELAB_IP $INITARG $ARGS";
exec $NETMON_DIR/$NETMOND -v 3 -u -f 262144 | tee $LOGDIR/libnetmon.out | $PYTHON $MONITOR_DIR/$MONITOR --mapping=$IPMAP --experiment=$PROJECT/$EXPERIMENT --ip=$PELAB_IP $INITARG $ARGS
