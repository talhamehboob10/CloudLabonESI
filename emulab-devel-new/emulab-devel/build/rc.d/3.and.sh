#! /bin/sh

INSTALL_DIR="/users/mshobana/emulab-devel/build"
AND_INIT="${INSTALL_DIR}/etc/rc.d/and"

if test -x ${AND_INIT}; then
    ${AND_INIT} $1
fi
