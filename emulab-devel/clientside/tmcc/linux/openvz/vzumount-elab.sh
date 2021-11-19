#!/bin/sh

if [ -z $VEID ]; then
    echo "Must set VEID env var!"
    exit 33
fi

if [ -z $VE_CONFFILE ]; then
    echo "Must set VE_CONFFILE env var!"
    exit 34
fi

. $VE_CONFFILE

MYROOT=${VE_ROOT}
if [ ! -e $MYROOT ]; then
    echo "root dir $MYROOT doesn't seem to be mounted!"
    exit 1
fi

RETVAL=0

#
# This is an utter disgrace.  OpenVZ does not called a prestart or start script
# in the root context before booting a container, so this is the only place we
# can perform such actions.
#
# Find our vnode_id:
vnodeid=`cat /var/emulab/vms/vminfo/vnode.${VEID}`
if [ -z $vnodeid ]; then
    echo "No vnodeid found for $VEID in $MYROOT/var/emulab/boot/realname;"
    echo "  cannot kill tmcc proxy!"
    exit 44
fi

#
echo "Undoing Emulab mounts."
/usr/local/etc/emulab/rc/rc.mounts -j $vnodeid $MYROOT 0 shutdown
if [ $? = 0 ]; then
    echo "ok."
else
    echo "FAILED with exit code $?"
    echo "Current mounts:\n"
    cat /proc/mounts
    echo "\n"
    exit 44
fi

PROXYPID="/var/run/tmccproxy.$vnodeid.pid"
if [ -e $PROXYPID ]; then
    kill `cat $PROXYPID`
    rm -f $PROXYPID
fi

exit $RETVAL
