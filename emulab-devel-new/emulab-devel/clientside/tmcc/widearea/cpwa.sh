#!/bin/sh
#
# Copyright (c) 2008-2010 University of Utah and the Flux Group.
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
# Simple script to copy widearea settings from the boot medium, or, if these
# settings are not present, remove them from the slice we're working on.
#

# little util function
checkAndMount() {
    if [ "$ELAB_UPD_MNT" != "" ]; then
	mount | grep -q "on ${ELAB_UPD_MNT}"
	if [ "$?" = "0" ]; then
	    return 0
	elif [ "$ELAB_UPD_DEV" != "" -a "$ELAB_UPD_MNTARGS" != "" ]; then
	    /bin/sh -c "mount ${ELAB_UPD_MNTARGS} ${ELAB_UPD_DEV} ${ELAB_UPD_MNT}"
	    if [ "$?" != "0" ]; then
		echo "mount of ${ELAB_UPD_DEV} at ${ELAB_UPD_MNT} failed!";
		return 1;
	    fi
	    return 0;
	else 
	    echo "not enough info to mount ${ELAB_UPD_MNT}!";
	    return 1;
	fi
    elif [ "$ELAB_UPD_DEV" != "" -a "$ELAB_UPD_MNTARGS" != "" ]; then
	/bin/sh -c "/sbin/mount ${ELAB_UPD_MNTARGS} ${ELAB_UPD_DEV} ${ELAB_UPD_MNT}"
	if [ "$?" != "0" ]; then
	    echo "mount of ${ELAB_UPD_DEV} at ${ELAB_UPD_MNT} failed!";
	    return 1;
	fi
	return 0;
    fi

    echo "total failure to mount a slice to work on!";
    return 1;
}

ETCDIR=/etc/emulab
mnt="$ELAB_UPD_MNT"
METCDIR="${mnt}${ETCDIR}"

if [ -e $ETCDIR/isrem ]; then
    checkAndMount
    if [ "$?" != "0" ]; then
	exit 5
    fi

    cp -p $ETCDIR/isrem $METCDIR/isrem
    cp -p $ETCDIR/bossnode $METCDIR/bossnode
#    cp -p $ETCDIR/emulab-privkey $METCDIR/emulab-privkey
    cp -p $ETCDIR/eventserver $METCDIR/eventserver
    cp -p $ETCDIR/waconfig $METCDIR/waconfig
    cp -p $ETCDIR/client.pem $METCDIR/client.pem
    cp -p $ETCDIR/emulab.pem $METCDIR/emulab.pem
fi

exit 0
