#!/bin/sh
#
# Wrapper for DHCPD which has a habit of dying. 
#

#
# These are the dependencies specified in the isc-dhcpd startup script.
#
# PROVIDE: dhcpd
# REQUIRE: DAEMON
# BEFORE: LOGIN
# KEYWORD: shutdown

elabinelab="0"
configfile="/usr/local/etc/dhcpd.conf"
extraifs="xn1"
case "$1" in
	start|faststart|quietstart|onestart|forcestart)
		# limit to control network
		cnetif=
		if [ $elabinelab != "1" -a -x /test/sbin/findif ]; then
		    cnetif=`/test/sbin/findif -i 198.22.255.3`
		fi
		if [ -x /test/sbin/daemon_wrapper ]; then
			echo -n " dhcpd wrapper"
			/test/sbin/daemon_wrapper \
			  /usr/local/sbin/dhcpd -f $cnetif $extraifs -cf $configfile
		fi
		;;
	stop|faststop|quietstop|onestop|forcestop)
		if [ -r /var/run/dhcpd_wrapper.pid ]; then
			kill `cat /var/run/dhcpd_wrapper.pid`
		fi
		;;
	*)
		echo ""
		echo "Usage: `basename $0` { start | stop }"
		echo ""
		exit 64
		;;
esac
