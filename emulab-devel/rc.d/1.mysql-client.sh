#!/bin/sh

# PROVIDE: mysql-client
# REQUIRE: NETWORKING SERVERS ldconfig
# BEFORE: mysql-testbed apache24
# KEYWORD: shutdown

case "$1" in
	start|faststart|quietstart|onestart|forcestart)
		/sbin/ldconfig -m /usr/local/lib/mysql
		;;
	stop|faststop|quietstop|onestop|forcestop)
		;;
	*)
		echo ""
		echo "Usage: `basename $0` { start | stop }"
		echo ""
		exit 64
		;;
esac
