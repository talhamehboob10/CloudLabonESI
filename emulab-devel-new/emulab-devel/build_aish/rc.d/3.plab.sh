#!/bin/sh
#
# Utah Network Testbed plab startup
#
case "$1" in
	start)
		if [ -x /users/achauhan/Cloudlab/CloudLabonESI/emulab-devel-new/emulab-devel/build_aish/sbin/plabmonitord  ]; then
			echo -n " plabmonitord"
			/users/achauhan/Cloudlab/CloudLabonESI/emulab-devel-new/emulab-devel/build_aish/sbin/plabmonitord
		fi
		;;
	stop)
		# The plab daemons don't need to be killed explicitly, nothing
		# to do here yet.
		;;
	*)
		echo ""
		echo "Usage: `basename $0` { start | stop }"
		echo ""
		exit 64
		;;
esac

