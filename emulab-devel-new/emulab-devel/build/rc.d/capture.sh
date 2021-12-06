#!/bin/sh

#
# capture needs the network (NETWORKING) for IPMI based captures.
# It also needs the capserver running (testbed) on a boss node.
# We start it up before apache so that we are capturing before
# users can use the web-based console.
#
# PROVIDE: capture
# REQUIRE: NETWORKING testbed
# BEFORE: apache24
# KEYWORD: shutdown

#
# Start up capture processes.
#
# XXX if you notice that each capture is being started up twice on reboot.
# then you need to make sure that the "local_startup" path in /etc/rc.conf
# (or /etc/defaults/rc.conf) does not include /usr/X11R6/etc/rc.d.
# In FreeBSD 6 and above, /usr/X11R6 is a symlink to /usr/local and the
# result is that scripts in /usr/local/etc/rc.d wind up being called twice.
# This is okay for scripts that fully use the FreeBSD rc system, but since
# this script is "not quite conforming" it causes captures to be started
# twice. You may need to override local_startup in /etc/rc.conf to avoid this.
#

. /etc/rc.subr

bindir=/users/mshobana/emulab-devel/build/sbin
if [ ! -x $bindir/capture ]; then
    echo "*** capture: $bindir/capture not installed"
    exit 1
fi

case "$1" in
start|faststart|quietstart|onestart|forcestart)
    echo -n ' capture'
    ;;
restart|fastrestart|quietrestart|onerestart|forcerestart)
    killall capture
    ;;
stop|faststop|quietstop|onestop|forcestop)
    killall capture && echo -n ' capture'
    exit 0
    ;;
*)
    echo "Usage: $0 {start|stop|restart}" >&2
    exit 1
    ;;
esac

#
# If this is the boss node, make sure capserver is running or you could be
# in for a lot of pain. If you have 500+ captures all (re)trying to contact
# the capserver periodically, you will be hating life during boot.
#
# XXX note that the dependency on "testbed" above is not enough.
# If `testbed-control` has been used to disable the system, then the testbed
# service will run, but not start up many of the daemons (including capture).
#
hname=`hostname`
if [ "$hname" = "boss.cloudlab.umass.edu" ]; then
    cspid=`pgrep capserver`
    if [ $? -ne 0 -o -z "$cspid" ]; then
	echo "*** capture: Capserver must be running first"
	exit 1
    fi
fi

#
# run_capture contains the actual capture start lines that look like:
#
#   $bindir/capture -T 15 -r -s [baudrate] [device] [ttyport] >/dev/null 2>&1 &
#
# The -T option gives the idle timestamp interval; i.e., if output on the
# device occurs, and it has been more than <interval> seconds since the last
# output, a timestamp is output to the log before the current output.
# This helps identify long gaps between output in the logfile and effectively
# time stamps "blocks" of output in the log.
#
# You should put a "sleep 1" in after every 1-20 lines to avoid overload
# (since these are all background startups).
#
# XXX run_capture should be auto-generated.
#
if [ -x $bindir/run_capture ]; then
    $bindir/run_capture $bindir/capture
fi

exit $?
