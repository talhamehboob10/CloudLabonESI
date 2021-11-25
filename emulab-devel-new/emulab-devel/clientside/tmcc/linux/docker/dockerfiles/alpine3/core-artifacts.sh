#!/bin/sh

#
# Builds the artifacts required for the core option (that is, the clientside).
#

if [ -n "$DESTDIR" ]; then
    export DESTDIR="$DESTDIR/emulab-client-install"
    mkdir -p $DESTDIR
fi

alpine/prepare.sh
alpine3/buildenv.sh
[ ! $? -eq 0 ] && alpine/cleanup.sh && exit 1
alpine/cleanup.sh

exit $?
