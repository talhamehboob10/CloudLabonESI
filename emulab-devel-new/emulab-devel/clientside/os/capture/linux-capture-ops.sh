#!/bin/sh
#
# capture-ops        Start and stop capture for ops VM
#
### BEGIN INIT INFO
# Provides: capture-ops
# Default-Start: 3 4 5
# Default-Stop: 0 1 6
# Should-Start: 
# Required-Start: $network
# Required-Stop: 
# Short-Description: Start and stop capture for ops VM
# Description: Start and stop capture for ops VM
### END INIT INFO
#
# The fields below are left around for legacy tools (will remove later).
#
# chkconfig: 345 89 11
# description: Start and stop capture for ops VM
#
# EMULAB-COPYRIGHT
# Copyright (c) 2007-2018 University of Utah and the Flux Group.
# All rights reserved.
#

# Source function library.
if [ -f /etc/rc.d/init.d/functions ]; then
    . /etc/rc.d/init.d/functions
fi

# Source networking configuration.
if [ -f /etc/sysconfig/network ]; then
    . /etc/sysconfig/network
elif [ -f /lib/lsb/init-functions ]; then
    . /lib/lsb/init-functions

    #
    # XXX Ubuntu/debian hackery for now
    #
    NETWORKING=yes
    if [ ! -d /var/lock/subsys ]; then
        mkdir /var/lock/subsys
    fi
    echo_success() {
        log_end_msg 0
    }
    echo_failure() {
        log_end_msg $?
    }
fi

# Check that networking is up.
[ ${NETWORKING} = "no" ] && exit 0

RETVAL=1
ARGS="-I -i -C -L -T 10 -R 2000 -l /var/log/tiplogs"

case "$1" in
start)
	if [ -x /usr/local/sbin/capture-nossl ]; then
		echo -n "Starting capture-ops: "
		/usr/local/sbin/capture-nossl $ARGS -X ops ops
		RETVAL=$?
		[ "$?" -eq 0 ] && echo_success || echo_failure
		echo
	fi
	[ $RETVAL -eq 0 ] && touch /var/lock/subsys/capture-ops
	;;
stop)
	echo -n "Shutting down capture-ops: "
	killproc -p /var/log/tiplogs/ops.pid
	RETVAL=$?
	echo
	[ $RETVAL -eq 0 ] && rm -f /var/lock/subsys/capture-ops
	;;
*)
	echo "Usage: `basename $0` {start|stop}" >&2
	;;
esac

exit $RETVAL
