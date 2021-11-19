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

. `dirname $0`/../common-env.sh

LIB_SO="libnetmon.so"
SOCK="${TMPDIR}/netmon.sock";
CSOCK="${SOCK}.control";

#
# Number of times (1 second apart) to try connecting to netmond.
# (0 means try forever, unset means just one try).
#
TIMO=5

#
# Try once to build the library
#
if ! [ -e $NETMON_DIR/$LIB_SO ]; then
    echo "Building $LIB_SO";
    gmake -C $NETMON_DIR $LIB_SO
fi

#
# Okay, let the user take care of it
#
if ! [ -e $NETMON_DIR/$LIB_SO ]; then
    echo "$NETMON_DIR/$LIB_SO missing - run 'gmake' in $NETMON_DIR to build it"
    exit 1;
fi

#
# Export the magic juice that will make programs use libnetmon
#
export LD_LIBRARY_PATH=$NETMON_DIR
export LD_PRELOAD=$LIB_SO
export LIBNETMON_SOCKPATH=$SOCK
export LIBNETMON_CONTROL_SOCKPATH=$CSOCK

# Allow this to be overridden from the environment
LIBNETMON_CONNECTTIMO=${LIBNETMON_CONNECTTIMO:=$TIMO}
export LIBNETMON_CONNECTTIMO
