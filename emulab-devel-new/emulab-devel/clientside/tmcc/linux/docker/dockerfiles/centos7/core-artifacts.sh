#!/bin/sh

#
# Builds the artifacts required for the core option (that is, the clientside).
#

if [ -n "$DESTDIR" ]; then
    export DESTDIR="$DESTDIR/emulab-client-install"
    mkdir -p $DESTDIR
fi

centos/prepare.sh
centos7/buildenv.sh
centos/cleanup.sh

exit $?
