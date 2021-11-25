#!/bin/sh
#
# Utah Network Testbed local startup
#

# PROVIDE: testbed
# REQUIRE: tbdbcheck pubsub mfrisbeed
# BEFORE: apache24
# KEYWORD: shutdown

MAINSITE="0"

case "$1" in
	start|faststart|quietstart|onestart|forcestart)
		#
		# See if the testbed is "shutdown"; The variable has three values.
	        #  0  - Testbed is enabled.
	        #  1  - Testbed is disabled.
		# -1  - Testbed is coming back online, so start up daemons.
		#
	        if [ -x /users/achauhan/Cloudlab/CloudLabonESI/emulab-devel-new/emulab-devel/build_aish/sbin/setsitevar ]; then
		    disabled=`/users/achauhan/Cloudlab/CloudLabonESI/emulab-devel-new/emulab-devel/build_aish/sbin/setsitevar -c general/testbed_shutdown`
		    if [ $? -ne 0 ]; then
			echo -n " mysqld not running, skipping testbed startup"
			exit 0
		    fi
		    if [ $disabled -gt 0 ]; then
			echo -n " testbed disabled"
			exit 0
		    fi
		fi
		if [ -x /users/achauhan/Cloudlab/CloudLabonESI/emulab-devel-new/emulab-devel/build_aish/sbin/dbboot ]; then
		        # Delay a moment so that mysqld has started!
		        sleep 2
			echo -n " dbboot"
			/users/achauhan/Cloudlab/CloudLabonESI/emulab-devel-new/emulab-devel/build_aish/sbin/dbboot
		fi

		if [ -x /users/achauhan/Cloudlab/CloudLabonESI/emulab-devel-new/emulab-devel/build_aish/sbin/bootinfo.restart  ]; then
			echo -n " bootinfo"
			/users/achauhan/Cloudlab/CloudLabonESI/emulab-devel-new/emulab-devel/build_aish/sbin/bootinfo.restart
		fi

		if [ -x /users/achauhan/Cloudlab/CloudLabonESI/emulab-devel-new/emulab-devel/build_aish/sbin/tmcd.restart  ]; then
			echo -n " tmcd"
			/users/achauhan/Cloudlab/CloudLabonESI/emulab-devel-new/emulab-devel/build_aish/sbin/tmcd.restart
		fi

		if [ -x /users/achauhan/Cloudlab/CloudLabonESI/emulab-devel-new/emulab-devel/build_aish/sbin/capserver  ]; then
			echo -n " capd"
			/users/achauhan/Cloudlab/CloudLabonESI/emulab-devel-new/emulab-devel/build_aish/sbin/capserver
		fi

		if [ -x /users/achauhan/Cloudlab/CloudLabonESI/emulab-devel-new/emulab-devel/build_aish/sbin/lastlog_daemon  ]; then
			echo -n " lastlogd"
			/users/achauhan/Cloudlab/CloudLabonESI/emulab-devel-new/emulab-devel/build_aish/sbin/lastlog_daemon
		fi

		if [ -x /users/achauhan/Cloudlab/CloudLabonESI/emulab-devel-new/emulab-devel/build_aish/sbin/sdcollectd  ]; then
			echo -n " sdcollectd"
			/users/achauhan/Cloudlab/CloudLabonESI/emulab-devel-new/emulab-devel/build_aish/sbin/sdcollectd
		fi

		if [ -x /users/achauhan/Cloudlab/CloudLabonESI/emulab-devel-new/emulab-devel/build_aish/sbin/stated  ]; then
			echo -n " stated"
			/users/achauhan/Cloudlab/CloudLabonESI/emulab-devel-new/emulab-devel/build_aish/sbin/stated
		fi

		if [ -e /users/achauhan/Cloudlab/CloudLabonESI/emulab-devel-new/emulab-devel/build_aish/etc/inetd.conf  ]; then
			echo -n " testbed-inetd"
			inetd -a boss.cloudlab.umass.edu -p /var/run/testbed-inetd.pid /users/achauhan/Cloudlab/CloudLabonESI/emulab-devel-new/emulab-devel/build_aish/etc/inetd.conf
		fi

		if [ -x /users/achauhan/Cloudlab/CloudLabonESI/emulab-devel-new/emulab-devel/build_aish/sbin/sslxmlrpc_server.py ]; then
			echo -n " sslxmlrpc_server"
			if [ -x /users/achauhan/Cloudlab/CloudLabonESI/emulab-devel-new/emulab-devel/build_aish/sbin/daemon_wrapper ]; then
			    /users/achauhan/Cloudlab/CloudLabonESI/emulab-devel-new/emulab-devel/build_aish/sbin/daemon_wrapper -i 30 \
			          -l /users/achauhan/Cloudlab/CloudLabonESI/emulab-devel-new/emulab-devel/build_aish/log/sslxmlrpc_server.log \
			          -p /var/run/sslxmlrpc_server.pid \
			          /users/achauhan/Cloudlab/CloudLabonESI/emulab-devel-new/emulab-devel/build_aish/sbin/sslxmlrpc_server.py -f

			else
			        /users/achauhan/Cloudlab/CloudLabonESI/emulab-devel-new/emulab-devel/build_aish/sbin/sslxmlrpc_server.py 2>/dev/null
			fi
		fi

		# mfrisbeed started with its own script

		if [ -x /users/achauhan/Cloudlab/CloudLabonESI/emulab-devel-new/emulab-devel/build_aish/sbin/reload_daemon  ]; then
			echo -n " reloadd"
			/users/achauhan/Cloudlab/CloudLabonESI/emulab-devel-new/emulab-devel/build_aish/sbin/reload_daemon
		fi

		if [ -x /users/achauhan/Cloudlab/CloudLabonESI/emulab-devel-new/emulab-devel/build_aish/sbin/checkup_daemon  ]; then
			echo -n " checkupd"
			/users/achauhan/Cloudlab/CloudLabonESI/emulab-devel-new/emulab-devel/build_aish/sbin/checkup_daemon
		fi

		if [ -x /users/achauhan/Cloudlab/CloudLabonESI/emulab-devel-new/emulab-devel/build_aish/sbin/mysqld_watchdog  ]; then
			echo -n " mysqld_watchdog"
			/users/achauhan/Cloudlab/CloudLabonESI/emulab-devel-new/emulab-devel/build_aish/sbin/mysqld_watchdog
		fi

		if [ -x /users/achauhan/Cloudlab/CloudLabonESI/emulab-devel-new/emulab-devel/build_aish/sbin/lease_daemon  ]; then
			echo -n " lease_daemon"
			/users/achauhan/Cloudlab/CloudLabonESI/emulab-devel-new/emulab-devel/build_aish/sbin/lease_daemon
		fi

		if [ -x /users/achauhan/Cloudlab/CloudLabonESI/emulab-devel-new/emulab-devel/build_aish/sbin/protogeni/expire_daemon ]; then
			echo -n " expire_daemon"
			/users/achauhan/Cloudlab/CloudLabonESI/emulab-devel-new/emulab-devel/build_aish/sbin/protogeni/expire_daemon
		fi

		if [ -x /users/achauhan/Cloudlab/CloudLabonESI/emulab-devel-new/emulab-devel/build_aish/sbin/protogeni/sa_daemon ]; then
			echo -n " sa_daemon"
			/users/achauhan/Cloudlab/CloudLabonESI/emulab-devel-new/emulab-devel/build_aish/sbin/protogeni/sa_daemon
		fi

		if [ -x /users/achauhan/Cloudlab/CloudLabonESI/emulab-devel-new/emulab-devel/build_aish/sbin/protogeni/ch_daemon ]; then
			echo -n " ch_daemon"
			/users/achauhan/Cloudlab/CloudLabonESI/emulab-devel-new/emulab-devel/build_aish/sbin/protogeni/ch_daemon
		fi

		if [ -x /users/achauhan/Cloudlab/CloudLabonESI/emulab-devel-new/emulab-devel/build_aish/sbin/protogeni/ims_daemon ]; then
			echo -n " ims_daemon"
			/users/achauhan/Cloudlab/CloudLabonESI/emulab-devel-new/emulab-devel/build_aish/sbin/protogeni/ims_daemon
		fi

		if [ -x /users/achauhan/Cloudlab/CloudLabonESI/emulab-devel-new/emulab-devel/build_aish/sbin/protogeni/igevent_daemon ]; then
			echo -n " igevent_daemon"
			/users/achauhan/Cloudlab/CloudLabonESI/emulab-devel-new/emulab-devel/build_aish/sbin/protogeni/igevent_daemon
		fi

		if [ -x /users/achauhan/Cloudlab/CloudLabonESI/emulab-devel-new/emulab-devel/build_aish/sbin/checknodes_daemon  ]; then
			echo -n " checknodes_daemon"
			/users/achauhan/Cloudlab/CloudLabonESI/emulab-devel-new/emulab-devel/build_aish/sbin/checknodes_daemon
		fi

		if [ -x /users/achauhan/Cloudlab/CloudLabonESI/emulab-devel-new/emulab-devel/build_aish/sbin/peer_daemon  ]; then
			echo -n " peer_daemon"
			/users/achauhan/Cloudlab/CloudLabonESI/emulab-devel-new/emulab-devel/build_aish/sbin/peer_daemon
		fi

		if [ -x /users/achauhan/Cloudlab/CloudLabonESI/emulab-devel-new/emulab-devel/build_aish/sbin/poolmonitor ]; then
			echo -n " poolmonitor"
			/users/achauhan/Cloudlab/CloudLabonESI/emulab-devel-new/emulab-devel/build_aish/sbin/poolmonitor
		fi

		if [ -x /users/achauhan/Cloudlab/CloudLabonESI/emulab-devel-new/emulab-devel/build_aish/sbin/tcppd ]; then
		        echo -n " tcppd"
			/users/achauhan/Cloudlab/CloudLabonESI/emulab-devel-new/emulab-devel/build_aish/sbin/tcppd &
		fi

		if [ -x /users/achauhan/Cloudlab/CloudLabonESI/emulab-devel-new/emulab-devel/build_aish/sbin/event_watchdog ]; then
		        echo -n " event_watchdog"
			/users/achauhan/Cloudlab/CloudLabonESI/emulab-devel-new/emulab-devel/build_aish/sbin/event_watchdog
		fi

		if [ -x /users/achauhan/Cloudlab/CloudLabonESI/emulab-devel-new/emulab-devel/build_aish/sbin/apt_daemon ]; then
			echo -n " apt_daemon"
			/users/achauhan/Cloudlab/CloudLabonESI/emulab-devel-new/emulab-devel/build_aish/sbin/apt_daemon
		fi
		
		if [ -x /users/achauhan/Cloudlab/CloudLabonESI/emulab-devel-new/emulab-devel/build_aish/sbin/aptexpire_daemon ]; then
			echo -n " aptexpire_daemon"
			/users/achauhan/Cloudlab/CloudLabonESI/emulab-devel-new/emulab-devel/build_aish/sbin/aptexpire_daemon
		fi
		
		if [ -x /users/achauhan/Cloudlab/CloudLabonESI/emulab-devel-new/emulab-devel/build_aish/sbin/aptevent_daemon ]; then
			echo -n " aptevent_daemon"
			/users/achauhan/Cloudlab/CloudLabonESI/emulab-devel-new/emulab-devel/build_aish/sbin/aptevent_daemon
		fi

		if [ -x /users/achauhan/Cloudlab/CloudLabonESI/emulab-devel-new/emulab-devel/build_aish/sbin/aptresgroup_daemon ]; then
			echo -n " aptresgroup_daemon"
			/users/achauhan/Cloudlab/CloudLabonESI/emulab-devel-new/emulab-devel/build_aish/sbin/aptresgroup_daemon
		fi

		if [ $MAINSITE == "1" -a -x /users/achauhan/Cloudlab/CloudLabonESI/emulab-devel-new/emulab-devel/build_aish/sbin/aptbus_monitor ]; then
			echo -n " aptbus_monitor"
			/users/achauhan/Cloudlab/CloudLabonESI/emulab-devel-new/emulab-devel/build_aish/sbin/aptbus_monitor
		fi

		if [ -x /users/achauhan/Cloudlab/CloudLabonESI/emulab-devel-new/emulab-devel/build_aish/sbin/aptimage_daemon ]; then
			echo -n " aptimage_daemon"
			/users/achauhan/Cloudlab/CloudLabonESI/emulab-devel-new/emulab-devel/build_aish/sbin/aptimage_daemon
		fi

		if [ -x /users/achauhan/Cloudlab/CloudLabonESI/emulab-devel-new/emulab-devel/build_aish/sbin/apt_scheduler ]; then
			echo -n " apt_scheduler"
			/users/achauhan/Cloudlab/CloudLabonESI/emulab-devel-new/emulab-devel/build_aish/sbin/apt_scheduler
		fi

		if [ -x /users/achauhan/Cloudlab/CloudLabonESI/emulab-devel-new/emulab-devel/build_aish/sbin/cnetwatch ]; then
			echo -n " cnetwatch"
			/users/achauhan/Cloudlab/CloudLabonESI/emulab-devel-new/emulab-devel/build_aish/sbin/cnetwatch
		fi

		if [ $MAINSITE == "1" -a -x /users/achauhan/Cloudlab/CloudLabonESI/emulab-devel-new/emulab-devel/build_aish/sbin/portal_monitor ]; then
			echo -n " portal_monitor"
			/users/achauhan/Cloudlab/CloudLabonESI/emulab-devel-new/emulab-devel/build_aish/sbin/portal_monitor
		fi

		if [ "0" == "1" -a -x /users/achauhan/Cloudlab/CloudLabonESI/emulab-devel-new/emulab-devel/build_aish/sbin/rfmonitor_daemon ]; then
			echo -n " rfmonitor_daemon"
			/users/achauhan/Cloudlab/CloudLabonESI/emulab-devel-new/emulab-devel/build_aish/sbin/rfmonitor_daemon
		fi

		if [ -x /users/achauhan/Cloudlab/CloudLabonESI/emulab-devel-new/emulab-devel/build_aish/sbin/portal_resources ]; then
			echo -n " portal_resources"
			/users/achauhan/Cloudlab/CloudLabonESI/emulab-devel-new/emulab-devel/build_aish/sbin/portal_resources
		fi
		#
		# Could trigger experiment creation, so make sure everything
		# else is setup first; i.e., run this last!
		#
		if [ \( 0 -eq 0 -o 0 -eq 1 \)\
			-a -x /users/achauhan/Cloudlab/CloudLabonESI/emulab-devel-new/emulab-devel/build_aish/sbin/reportboot_daemon ]; then
			echo -n " reportboot daemon "
			if [ -x /users/achauhan/Cloudlab/CloudLabonESI/emulab-devel-new/emulab-devel/build_aish/sbin/daemon_wrapper ]; then
			    /users/achauhan/Cloudlab/CloudLabonESI/emulab-devel-new/emulab-devel/build_aish/sbin/daemon_wrapper -i 30 \
			          -l /users/achauhan/Cloudlab/CloudLabonESI/emulab-devel-new/emulab-devel/build_aish/log/reportboot.log \
			          -p /var/run/reportboot_daemon.pid \
				  /users/achauhan/Cloudlab/CloudLabonESI/emulab-devel-new/emulab-devel/build_aish/sbin/reportboot_daemon -f 
			else
				/users/achauhan/Cloudlab/CloudLabonESI/emulab-devel-new/emulab-devel/build_aish/sbin/reportboot_daemon 
			fi
		fi

		if [ -n "" -a -x /users/achauhan/Cloudlab/CloudLabonESI/emulab-devel-new/emulab-devel/build_aish/sbin/attend ]; then
			echo -n " attend"
			/users/achauhan/Cloudlab/CloudLabonESI/emulab-devel-new/emulab-devel/build_aish/sbin/attend
		fi

		#
		# Could trigger experiment creation, so make sure everything
		# else is setup first; i.e., run this last!
		#
		if [ -x /users/achauhan/Cloudlab/CloudLabonESI/emulab-devel-new/emulab-devel/build_aish/sbin/batch_daemon  ]; then
			echo -n " batchd wrapper "
			if [ -x /users/achauhan/Cloudlab/CloudLabonESI/emulab-devel-new/emulab-devel/build_aish/sbin/daemon_wrapper ]; then
				/users/achauhan/Cloudlab/CloudLabonESI/emulab-devel-new/emulab-devel/build_aish/sbin/daemon_wrapper \
				  -i 30 -l /users/achauhan/Cloudlab/CloudLabonESI/emulab-devel-new/emulab-devel/build_aish/log/batchlog \
				  /users/achauhan/Cloudlab/CloudLabonESI/emulab-devel-new/emulab-devel/build_aish/sbin/batch_daemon -d
			else
				/users/achauhan/Cloudlab/CloudLabonESI/emulab-devel-new/emulab-devel/build_aish/sbin/batch_daemon
			fi
		fi
		;;
	stop|faststop|quietstop|onestop|forcestop)
		if [ -r /var/run/bootinfo.pid ]; then
			kill `cat /var/run/bootinfo.pid`
		fi
		if [ -r /var/run/tmcd.pid ]; then
			kill `cat /var/run/tmcd.pid`
		fi
		if [ -r /var/run/capserver.pid ]; then
			kill `cat /var/run/capserver.pid`
		fi
		if [ -r /var/run/lastlog_daemon.pid ]; then
			kill `cat /var/run/lastlog_daemon.pid`
		fi
		if [ -r /var/run/sdcollectd.pid ]; then
			kill `cat /var/run/sdcollectd.pid`
		fi
		if [ -r /var/run/stated.pid ]; then
			kill `cat /var/run/stated.pid`
		fi
		if [ -r /var/run/testbed-inetd.pid ]; then
			kill `cat /var/run/testbed-inetd.pid`
		fi
		if [ -r /var/run/sslxmlrpc_server.pid ]; then
			kill `cat /var/run/sslxmlrpc_server.pid`
		fi
		if [ -r /var/run/reload_daemon.pid ]; then
			kill `cat /var/run/reload_daemon.pid`
		fi
		if [ -r /var/run/checkup_daemon.pid ]; then
			kill `cat /var/run/checkup_daemon.pid`
		fi
		if [ -r /var/run/pool_daemon.pid ]; then
			kill `cat /var/run/pool_daemon.pid`
		fi
		if [ -r /var/run/mysqld_watchdog.pid ]; then
			kill `cat /var/run/mysqld_watchdog.pid`
		fi
		if [ -r /var/run/lease_daemon.pid ]; then
			kill `cat /var/run/lease_daemon.pid`
		fi
		if [ -r /var/run/expire_daemon.pid ]; then
			kill `cat /var/run/expire_daemon.pid`
		fi
		if [ -r /var/run/sa_daemon.pid ]; then
			kill `cat /var/run/sa_daemon.pid`
		fi
		if [ -r /var/run/ch_daemon.pid ]; then
			kill `cat /var/run/ch_daemon.pid`
		fi
		if [ -r /var/run/ims_daemon.pid ]; then
			kill `cat /var/run/ims_daemon.pid`
		fi
		if [ -r /var/run/igevent_daemon.pid ]; then
			kill `cat /var/run/igevent_daemon.pid`
		fi
		if [ -r /var/run/checknodes.pid ]; then
			kill `cat /var/run/checknodes.pid`
		fi
		if [ -r /var/run/checknodes_daemon.pid ]; then
			kill `cat /var/run/checknodes_daemon.pid`
		fi
		if [ -r /var/run/batch_daemon_wrapper.pid ]; then
			kill `cat /var/run/batch_daemon_wrapper.pid`
		fi
		if [ -r /var/run/peer_daemon.pid ]; then
			kill `cat /var/run/peer_daemon.pid`
		fi
		if [ -r /var/run/poolmonitor.pid ]; then
			kill `cat /var/run/poolmonitor.pid`
		fi
		if [ -r /var/run/tcppd.pid ]; then
			kill `cat /var/run/tcppd.pid`
		fi
		if [ -r /var/run/event_watchdog.pid ]; then
			kill `cat /var/run/event_watchdog.pid`
		fi
		if [ -r /var/run/apt_daemon.pid ]; then
			kill `cat /var/run/apt_daemon.pid`
		fi
		if [ -r /var/run/aptexpire_daemon.pid ]; then
			kill `cat /var/run/aptexpire_daemon.pid`
		fi
		if [ -r /var/run/apt_scheduler.pid ]; then
			kill `cat /var/run/apt_scheduler.pid`
		fi
		if [ -r /var/run/aptevent_daemon.pid ]; then
			kill `cat /var/run/aptevent_daemon.pid`
		fi
		if [ -r /var/run/aptresgroup_daemon.pid ]; then
			kill `cat /var/run/aptresgroup_daemon.pid`
		fi
		if [ -r /var/run/aptbus_monitor.pid ]; then
			kill `cat /var/run/aptbus_monitor.pid`
		fi
		if [ -r /var/run/aptimage_daemon.pid ]; then
			kill `cat /var/run/aptimage_daemon.pid`
		fi
		if [ -r /var/run/cnetwatch.pid ]; then
			kill `cat /var/run/cnetwatch.pid`
		fi
		if [ -r /var/run/apt_checkup.pid ]; then
			kill `cat /var/run/apt_checkup.pid`
		fi
		if [ -r /var/run/portal_monitor.pid ]; then
			kill `cat /var/run/portal_monitor.pid`
		fi
		if [ -r /var/run/rfmonitor_daemon.pid ]; then
			kill `cat /var/run/rfmonitor_daemon.pid`
		fi
		if [ -r /var/run/portal_resources.pid ]; then
			kill `cat /var/run/portal_resources.pid`
		fi
		if [ -r /var/run/attend.pid ]; then
			kill `cat /var/run/attend.pid`
		fi
		if [ -r /var/run/mondbd.pid ]; then
			kill `cat /var/run/mondbd.pid`			
		fi
		if [ -r /var/run/shared-node-listener.pid ]; then
			kill `cat /var/run/shared-node-listener.pid`
		fi
		if [ -r /var/run/reportboot_daemon.pid ]; then
			kill `cat /var/run/reportboot_daemon.pid`
		fi

		;;
	*)
		echo ""
		echo "Usage: `basename $0` { start | stop }"
		echo ""
		exit 64
		;;
esac
exit 0
