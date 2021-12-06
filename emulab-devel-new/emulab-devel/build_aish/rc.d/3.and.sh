#! /bin/sh

INSTALL_DIR="/users/achauhan/Cloudlab/CloudLabonESI/emulab-devel-new/emulab-devel/build_aish"
AND_INIT="${INSTALL_DIR}/etc/rc.d/and"

if test -x ${AND_INIT}; then
    ${AND_INIT} $1
fi
