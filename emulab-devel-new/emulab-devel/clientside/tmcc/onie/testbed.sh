#!/bin/sh

cmd="$1"

daemon="testbed"
ARGS=

. /lib/onie/functions

case $cmd in
    start)
        log_begin_msg "Starting: $daemon"
        /etc/testbed/rc.testbed &
        log_end_msg
        ;;

    stop)
        ;;
    *)

esac
