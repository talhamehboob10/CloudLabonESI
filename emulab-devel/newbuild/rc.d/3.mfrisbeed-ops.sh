#!/bin/sh

# PROVIDE: mfrisbeed
# REQUIRE: DAEMON
# BEFORE: testbed
# KEYWORD: shutdown

#
# Start up the frisbee upload-only master server on ops (fs).
#
# We run it under the daemon wrapper if available so that it will get
# automatically restarted.
#

#
# Default values for configuration variables.
# XXX Not synchronized with sitevars right now.
#
# BASEPORT: base multicast port number.
#     Zero means any ephemeral port.
#     Unset to use mfrisbeed default.
# NUMPORT: number of ports to allow.
#     Range will be BASEPORT to BASEPORT+NUMPORT.
#     Zero means any ephemeral port above the base.
#     Unset to use mfrisbeed default.
# MAXSIZE: maximum size of an uploaded image in GB.
#     Unset to use mfrisbeed default.
# MAXWAIT: maximum time to allow for an upload to finish in minutes.
#     Zero means wait forever.
#     Unset to use mfrisbeed default.
# MAXIDLE: maximum idle time to allow during an active upload in minutes
#     Zero means wait forever.
#     Constrainted by the MAXWAIT timeout.
#     Unset to use mfrisbeed default.
# DEBUG: set to run with debugging enabled.
#
BASEPORT="6000"
NUMPORT="0"
MAXSIZE=20
MAXWAIT=60
MAXIDLE=5
DEBUG=true

. /etc/rc.subr

if [ "0" != "1" ]; then
    exit 0
fi

bindir=/home/achauhan06/CLOUDLAB/SSHCLOUD/CloudLabonESI/emulab-devel/newbuild/sbin
if [ ! -x $bindir/mfrisbeed -o ! -x $bindir/frisuploadd ]; then
    echo "*** mfrisbeed.sh: $bindir/mfrisbeed or frisuploadd not installed"
    exit 1
fi

case "$1" in
start|faststart|quietstart|onestart|forcestart)
    ;;
restart|fastrestart|quietrestart|onerestart|forcerestart)
    if [ -f /var/run/mfrisbeed_wrapper.pid ]; then
	kill `cat /var/run/mfrisbeed_wrapper.pid` >/dev/null 2>&1
	rm -f /var/run/mfrisbeed_wrapper.pid
    fi
    if [ -f /var/run/mfrisbeed.pid ]; then
	kill `cat /var/run/mfrisbeed.pid` >/dev/null 2>&1
	rm -f /var/run/mfrisbeed.pid
    fi
    ;;
stop|faststop|quietstop|onestop|forcestop)
    echo -n ' mfrisbeed'
    if [ -f /var/run/mfrisbeed_wrapper.pid ]; then
	kill `cat /var/run/mfrisbeed_wrapper.pid` >/dev/null 2>&1
	rm -f /var/run/mfrisbeed_wrapper.pid
    fi
    if [ -f /var/run/mfrisbeed.pid ]; then
	kill `cat /var/run/mfrisbeed.pid` >/dev/null 2>&1
	rm -f /var/run/mfrisbeed.pid
    fi
    rm -f /var/run/frisbeed-*.pid
    exit 0
    ;;
*)
    echo "Usage: $0 {start|stop|restart}" >&2
    exit 1
    ;;
esac

echo -n " mfrisbeed"
rm -f /var/run/frisbeed-*.pid

args="-C upload-only -r put -S 198.22.255.3 -A -M"
if [ "$DEBUG" = "true" ]; then
   args="-ddD $args"
fi

opts=""
if [ -n "$BASEPORT" ]; then
    if [ -z "$opts" ]; then
	opts="-O portbase=$BASEPORT"
    else
	opts="$opts,mcportbase=$BASEPORT"
    fi
fi
if [ -n "$NUMPORT" ]; then
    if [ -z "$opts" ]; then
	opts="-O portnum=$NUMPORT"
    else
	opts="$opts,portnum=$NUMPORT"
    fi
fi
if [ -n "$MAXSIZE" ]; then
    if [ -z "$opts" ]; then
	opts="-O maxsize=$MAXSIZE"
    else
	opts="$opts,maxsize=$MAXSIZE"
    fi
fi
if [ -n "$MAXWAIT" ]; then
    if [ -z "$opts" ]; then
	opts="-O maxwait=$MAXWAIT"
    else
	opts="$opts,maxwait=$MAXWAIT"
    fi
fi
if [ -n "$MAXIDLE" ]; then
    if [ -z "$opts" ]; then
	opts="-O maxidle=$MAXIDLE"
    else
	opts="$opts,maxidle=$MAXIDLE"
    fi
fi

if [ "$DEBUG" != "true" -a -x /home/achauhan06/CLOUDLAB/SSHCLOUD/CloudLabonESI/emulab-devel/newbuild/sbin/daemon_wrapper ]; then
    /home/achauhan06/CLOUDLAB/SSHCLOUD/CloudLabonESI/emulab-devel/newbuild/sbin/daemon_wrapper -i 30 -l /home/achauhan06/CLOUDLAB/SSHCLOUD/CloudLabonESI/emulab-devel/newbuild/log/mfrisbeed_wrapper.log \
	/home/achauhan06/CLOUDLAB/SSHCLOUD/CloudLabonESI/emulab-devel/newbuild/sbin/mfrisbeed -d $args $opts
else
    /home/achauhan06/CLOUDLAB/SSHCLOUD/CloudLabonESI/emulab-devel/newbuild/sbin/mfrisbeed $args $opts
fi

exit $?
