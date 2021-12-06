#!/bin/sh

# PROVIDE: mfrisbeed
# REQUIRE: DAEMON tbdbcheck
# BEFORE: testbed
# KEYWORD: nojail shutdown

#
# Set to run with debugging enabled.
#
#DEBUG=
DEBUG=yes

#
# Start up the frisbee master server on boss.
# It is expected that the boss mfrisbeed will use config_emulab which
# queries the database directly for configuration parameters.
#
# We run it under the daemon wrapper if available so that it will get
# automatically restarted.
#

. /etc/rc.subr

bindir=/users/mshobana/emulab-devel/build/sbin
if [ ! -x $bindir/mfrisbeed ]; then
    echo "*** mfrisbeed.sh: $bindir/mfrisbeed not installed"
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

#
# See if the testbed is "shutdown"; The variable has three values.
#  0  - Testbed is enabled.
#  1  - Testbed is disabled.
# -1  - Testbed is coming back online, so start up daemons.
#
if [ -x /users/mshobana/emulab-devel/build/sbin/setsitevar ]; then
    disabled=`/users/mshobana/emulab-devel/build/sbin/setsitevar -c general/testbed_shutdown`
    if [ $? -ne 0 ]; then
	echo -n " mysqld not running, skipping mfrisbeed startup"
	exit 0
    fi
    if [ $disabled -gt 0 ]; then
	echo -n " mfrisbeed disabled"
	exit 0
    fi
fi

echo -n " mfrisbeed"
rm -f /var/run/frisbeed-*.pid

args="-C emulab -i 198.22.255.3"
# to allow broadcast, uncomment the following line
#args="$args -x ucast,mcast,bcast"

# see if we need to be an IGMP querier
if [ "1" = "1" ]; then
    args="$args -Q 30"
    # XXX it is a v2 querier
    /sbin/sysctl net.inet.igmp.default_version=2
    /sbin/sysctl net.inet.igmp.legacysupp=1
    /sbin/sysctl net.inet.igmp.v2enable=1
fi
if [ -n "$DEBUG" ]; then
   args="-ddD $args"
fi

if [ -z "$DEBUG" -a -x /users/mshobana/emulab-devel/build/sbin/daemon_wrapper ]; then
    /users/mshobana/emulab-devel/build/sbin/daemon_wrapper -i 30 -l /users/mshobana/emulab-devel/build/log/mfrisbeed_wrapper.log \
	/users/mshobana/emulab-devel/build/sbin/mfrisbeed -d $args
else
    /users/mshobana/emulab-devel/build/sbin/mfrisbeed $args
fi

exit $?
