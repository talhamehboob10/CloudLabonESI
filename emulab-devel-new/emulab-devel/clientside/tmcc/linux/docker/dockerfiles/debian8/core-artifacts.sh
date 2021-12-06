#!/bin/sh

#
# Builds the artifacts required for the core option (that is, the clientside).
#

if [ -n "$DESTDIR" ]; then
    export DESTDIR="$DESTDIR/emulab-client-install"
    mkdir -p $DESTDIR
fi

debian/prepare.sh && debian8/buildenv.sh && debian/cleanup.sh

exit $?
