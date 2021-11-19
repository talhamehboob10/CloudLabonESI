#! /bin/sh

INSTALL_DIR="/home/achauhan06/CLOUDLAB/SSHCLOUD/CloudLabonESI/emulab-devel/newbuild"
AND_INIT="${INSTALL_DIR}/etc/rc.d/and"

if test -x ${AND_INIT}; then
    ${AND_INIT} $1
fi
