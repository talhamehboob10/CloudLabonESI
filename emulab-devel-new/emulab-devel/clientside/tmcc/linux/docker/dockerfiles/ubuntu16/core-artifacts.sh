#!/bin/sh

#
# Builds the artifacts required for the core option (that is, the clientside).
#

if [ -n "$DESTDIR" ]; then
    export DESTDIR="$DESTDIR/emulab-client-install"
    mkdir -p $DESTDIR
fi

ubuntu/prepare.sh && ubuntu16/buildenv.sh && ubuntu/cleanup.sh

exit $?
