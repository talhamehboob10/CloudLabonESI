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
	        if [ -x /users/mshobana/CloudLabonESI/emulab-devel-new/emulab-devel/sample_build/sbin/setsitevar ]; then
		    disabled=`/users/mshobana/CloudLabonESI/emulab-devel-new/emulab-devel/sample_build/sbin/setsitevar -c general/testbed_shutdown`
		    if [ $? -ne 0 ]; then
			echo -n " mysqld not running, skipping testbed startup"
			exit 0
		    fi
		    if [ $disabled -gt 0 ]; then
			echo -n " testbed disabled"
			exit 0
		    fi
		fi
		if [ -x /users/mshobana/CloudLabonESI/emulab-devel-new/emulab-devel/sample_build/sbin/dbboot ]; then
		        # Delay a moment so that mysqld has started!
		        sleep 2
			echo -n " dbboot"
			/users/mshobana/CloudLabonESI/emulab-devel-new/emulab-devel/sample_build/sbin/dbboot
		fi

		if [ -x /users/mshobana/CloudLabonESI/emulab-devel-new/emulab-devel/sample_build/sbin/bootinfo.restart  ]; then
			echo -n " bootinfo"
			/users/mshobana/CloudLabonESI/emulab-devel-new/emulab-devel/sample_build/sbin/bootinfo.restart
		fi

		if [ -x /users/mshobana/CloudLabonESI/emulab-devel-new/emulab-devel/sample_build/sbin/tmcd.restart  ]; then
			echo -n " tmcd"
			/users/mshobana/CloudLabonESI/emulab-devel-new/emulab-devel/sample_build/sbin/tmcd.restart
		fi

		if [ -x /users/mshobana/CloudLabonESI/emulab-devel-new/emulab-devel/sample_build/sbin/capserver  ]; then
			echo -n " capd"
			/users/mshobana/CloudLabonESI/emulab-devel-new/emulab-devel/sample_build/sbin/capserver
		fi

		if [ -x /users/mshobana/CloudLabonESI/emulab-devel-new/emulab-devel/sample_build/sbin/lastlog_daemon  ]; then
			echo -n " lastlogd"
			/users/mshobana/CloudLabonESI/emulab-devel-new/emulab-devel/sample_build/sbin/lastlog_daemon
		fi

		if [ -x /users/mshobana/CloudLabonESI/emulab-devel-new/emulab-devel/sample_build/sbin/sdcollectd  ]; then
			echo -n " sdcollectd"
			/users/mshobana/CloudLabonESI/emulab-devel-new/emulab-devel/sample_build/sbin/sdcollectd
		fi

		if [ -x /users/mshobana/CloudLabonESI/emulab-devel-new/emulab-devel/sample_build/sbin/stated  ]; then
			echo -n " stated"
			/users/mshobana/CloudLabonESI/emulab-devel-new/emulab-devel/sample_build/sbin/stated
		fi

		if [ -e /users/mshobana/CloudLabonESI/emulab-devel-new/emulab-devel/sample_build/etc/inetd.conf  ]; then
			echo -n " testbed-inetd"
			inetd -a boss.cloudlab.umass.edu -p /var/run/testbed-inetd.pid /users/mshobana/CloudLabonESI/emulab-devel-new/emulab-devel/sample_build/etc/inetd.conf
		fi

		if [ -x /users/mshobana/CloudLabonESI/emulab-devel-new/emulab-devel/sample_build/sbin/sslxmlrpc_server.py ]; then
			echo -n " sslxmlrpc_server"
			if [ -x /users/mshobana/CloudLabonESI/emulab-devel-new/emulab-devel/sample_build/sbin/daemon_wrapper ]; then
			    /users/mshobana/CloudLabonESI/emulab-devel-new/emulab-devel/sample_build/sbin/daemon_wrapper -i 30 \
			          -l /users/mshobana/CloudLabonESI/emulab-devel-new/emulab-devel/sample_build/log/sslxmlrpc_server.log \
			          -p /var/run/sslxmlrpc_server.pid \
			          /users/mshobana/CloudLabonESI/emulab-devel-new/emulab-devel/sample_build/sbin/sslxmlrpc_server.py -f

			else
			        /users/mshobana/CloudLabonESI/emulab-devel-new/emulab-devel/sample_build/sbin/sslxmlrpc_server.py 2>/dev/null
			fi
		fi

		# mfrisbeed started with its own script

		if [ -x /users/mshobana/CloudLabonESI/emulab-devel-new/emulab-devel/sample_build/sbin/reload_daemon  ]; then
			echo -n " reloadd"
			/users/mshobana/CloudLabonESI/emulab-devel-new/emulab-devel/sample_build/sbin/reload_daemon
		fi

		if [ -x /users/mshobana/CloudLabonESI/emulab-devel-new/emulab-devel/sample_build/sbin/checkup_daemon  ]; then
			echo -n " checkupd"
			/users/mshobana/CloudLabonESI/emulab-devel-new/emulab-devel/sample_build/sbin/checkup_daemon
		fi

		if [ -x /users/mshobana/CloudLabonESI/emulab-devel-new/emulab-devel/sample_build/sbin/mysqld_watchdog  ]; then
			echo -n " mysqld_watchdog"
			/users/mshobana/CloudLabonESI/emulab-devel-new/emulab-devel/sample_build/sbin/mysqld_watchdog
		fi

		if [ -x /users/mshobana/CloudLabonESI/emulab-devel-new/emulab-devel/sample_build/sbin/lease_daemon  ]; then
			echo -n " lease_daemon"
			/users/mshobana/CloudLabonESI/emulab-devel-new/emulab-devel/sample_build/sbin/lease_daemon
		fi

		if [ -x /users/mshobana/CloudLabonESI/emulab-devel-new/emulab-devel/sample_build/sbin/protogeni/expire_daemon ]; then
			echo -n " expire_daemon"
			/users/mshobana/CloudLabonESI/emulab-devel-new/emulab-devel/sample_build/sbin/protogeni/expire_daemon
		fi

		if [ -x /users/mshobana/CloudLabonESI/emulab-devel-new/emulab-devel/sample_build/sbin/protogeni/sa_daemon ]; then
			echo -n " sa_daemon"
			/users/mshobana/CloudLabonESI/emulab-devel-new/emulab-devel/sample_build/sbin/protogeni/sa_daemon
		fi

		if [ -x /users/mshobana/CloudLabonESI/emulab-devel-new/emulab-devel/sample_build/sbin/protogeni/ch_daemon ]; then
			echo -n " ch_daemon"
			/users/mshobana/CloudLabonESI/emulab-devel-new/emulab-devel/sample_build/sbin/protogeni/ch_daemon
		fi

		if [ -x /users/mshobana/CloudLabonESI/emulab-devel-new/emulab-devel/sample_build/sbin/protogeni/ims_daemon ]; then
			echo -n " ims_daemon"
			/users/mshobana/CloudLabonESI/emulab-devel-new/emulab-devel/sample_build/sbin/protogeni/ims_daemon
		fi

		if [ -x /users/mshobana/CloudLabonESI/emulab-devel-new/emulab-devel/sample_build/sbin/protogeni/igevent_daemon ]; then
			echo -n " igevent_daemon"
			/users/mshobana/CloudLabonESI/emulab-devel-new/emulab-devel/sample_build/sbin/protogeni/igevent_daemon
		fi

		if [ -x /users/mshobana/CloudLabonESI/emulab-devel-new/emulab-devel/sample_build/sbin/checknodes_daemon  ]; then
			echo -n " checknodes_daemon"
			/users/mshobana/CloudLabonESI/emulab-devel-new/emulab-devel/sample_build/sbin/checknodes_daemon
		fi

		if [ -x /users/mshobana/CloudLabonESI/emulab-devel-new/emulab-devel/sample_build/sbin/peer_daemon  ]; then
			echo -n " peer_daemon"
			/users/mshobana/CloudLabonESI/emulab-devel-new/emulab-devel/sample_build/sbin/peer_daemon
		fi

		if [ -x /users/mshobana/CloudLabonESI/emulab-devel-new/emulab-devel/sample_build/sbin/poolmonitor ]; then
			echo -n " poolmonitor"
			/users/mshobana/CloudLabonESI/emulab-devel-new/emulab-devel/sample_build/sbin/poolmonitor
		fi

		if [ -x /users/mshobana/CloudLabonESI/emulab-devel-new/emulab-devel/sample_build/sbin/tcppd ]; then
		        echo -n " tcppd"
			/users/mshobana/CloudLabonESI/emulab-devel-new/emulab-devel/sample_build/sbin/tcppd &
		fi

		if [ -x /users/mshobana/CloudLabonESI/emulab-devel-new/emulab-devel/sample_build/sbin/event_watchdog ]; then
		        echo -n " event_watchdog"
			/users/mshobana/CloudLabonESI/emulab-devel-new/emulab-devel/sample_build/sbin/event_watchdog
		fi

		if [ -x /users/mshobana/CloudLabonESI/emulab-devel-new/emulab-devel/sample_build/sbin/apt_daemon ]; then
			echo -n " apt_daemon"
			/users/mshobana/CloudLabonESI/emulab-devel-new/emulab-devel/sample_build/sbin/apt_daemon
		fi
		
		if [ -x /users/mshobana/CloudLabonESI/emulab-devel-new/emulab-devel/sample_build/sbin/aptexpire_daemon ]; then
			echo -n " aptexpire_daemon"
			/users/mshobana/CloudLabonESI/emulab-devel-new/emulab-devel/sample_build/sbin/aptexpire_daemon
		fi
		
		if [ -x /users/mshobana/CloudLabonESI/emulab-devel-new/emulab-devel/sample_build/sbin/aptevent_daemon ]; then
			echo -n " aptevent_daemon"
			/users/mshobana/CloudLabonESI/emulab-devel-new/emulab-devel/sample_build/sbin/aptevent_daemon
		fi

		if [ -x /users/mshobana/CloudLabonESI/emulab-devel-new/emulab-devel/sample_build/sbin/aptresgroup_daemon ]; then
			echo -n " aptresgroup_daemon"
			/users/mshobana/CloudLabonESI/emulab-devel-new/emulab-devel/sample_build/sbin/aptresgroup_daemon
		fi

		if [ $MAINSITE == "1" -a -x /users/mshobana/CloudLabonESI/emulab-devel-new/emulab-devel/sample_build/sbin/aptbus_monitor ]; then
			echo -n " aptbus_monitor"
			/users/mshobana/CloudLabonESI/emulab-devel-new/emulab-devel/sample_build/sbin/aptbus_monitor
		fi

		if [ -x /users/mshobana/CloudLabonESI/emulab-devel-new/emulab-devel/sample_build/sbin/aptimage_daemon ]; then
			echo -n " aptimage_daemon"
			/users/mshobana/CloudLabonESI/emulab-devel-new/emulab-devel/sample_build/sbin/aptimage_daemon
		fi

		if [ -x /users/mshobana/CloudLabonESI/emulab-devel-new/emulab-devel/sample_build/sbin/apt_scheduler ]; then
			echo -n " apt_scheduler"
			/users/mshobana/CloudLabonESI/emulab-devel-new/emulab-devel/sample_build/sbin/apt_scheduler
		fi

		if [ -x /users/mshobana/CloudLabonESI/emulab-devel-new/emulab-devel/sample_build/sbin/cnetwatch ]; then
			echo -n " cnetwatch"
			/users/mshobana/CloudLabonESI/emulab-devel-new/emulab-devel/sample_build/sbin/cnetwatch
		fi

		if [ $MAINSITE == "1" -a -x /users/mshobana/CloudLabonESI/emulab-devel-new/emulab-devel/sample_build/sbin/portal_monitor ]; then
			echo -n " portal_monitor"
			/users/mshobana/CloudLabonESI/emulab-devel-new/emulab-devel/sample_build/sbin/portal_monitor
		fi

		if [ "0" == "1" -a -x /users/mshobana/CloudLabonESI/emulab-devel-new/emulab-devel/sample_build/sbin/rfmonitor_daemon ]; then
			echo -n " rfmonitor_daemon"
			/users/mshobana/CloudLabonESI/emulab-devel-new/emulab-devel/sample_build/sbin/rfmonitor_daemon
		fi

		if [ -x /users/mshobana/CloudLabonESI/emulab-devel-new/emulab-devel/sample_build/sbin/portal_resources ]; then
			echo -n " portal_resources"
			/users/mshobana/CloudLabonESI/emulab-devel-new/emulab-devel/sample_build/sbin/portal_resources
		fi
		#
		# Could trigger experiment creation, so make sure everything
		# else is setup first; i.e., run this last!
		#
		if [ \( 0 -eq 0 -o 0 -eq 1 \)\
			-a -x /users/mshobana/CloudLabonESI/emulab-devel-new/emulab-devel/sample_build/sbin/reportboot_daemon ]; then
			echo -n " reportboot daemon "
			if [ -x /users/mshobana/CloudLabonESI/emulab-devel-new/emulab-devel/sample_build/sbin/daemon_wrapper ]; then
			    /users/mshobana/CloudLabonESI/emulab-devel-new/emulab-devel/sample_build/sbin/daemon_wrapper -i 30 \
			          -l /users/mshobana/CloudLabonESI/emulab-devel-new/emulab-devel/sample_build/log/reportboot.log \
			          -p /var/run/reportboot_daemon.pid \
				  /users/mshobana/CloudLabonESI/emulab-devel-new/emulab-devel/sample_build/sbin/reportboot_daemon -f 
			else
				/users/mshobana/CloudLabonESI/emulab-devel-new/emulab-devel/sample_build/sbin/reportboot_daemon 
			fi
		fi

		if [ -n "" -a -x /users/mshobana/CloudLabonESI/emulab-devel-new/emulab-devel/sample_build/sbin/attend ]; then
			echo -n " attend"
			/users/mshobana/CloudLabonESI/emulab-devel-new/emulab-devel/sample_build/sbin/attend
		fi

		#
		# Could trigger experiment creation, so make sure everything
		# else is setup first; i.e., run this last!
		#
		if [ -x /users/mshobana/CloudLabonESI/emulab-devel-new/emulab-devel/sample_build/sbin/batch_daemon  ]; then
			echo -n " batchd wrapper "
			if [ -x /users/mshobana/CloudLabonESI/emulab-devel-new/emulab-devel/sample_build/sbin/daemon_wrapper ]; then
				/users/mshobana/CloudLabonESI/emulab-devel-new/emulab-devel/sample_build/sbin/daemon_wrapper \
				  -i 30 -l /users/mshobana/CloudLabonESI/emulab-devel-new/emulab-devel/sample_build/log/batchlog \
				  /users/mshobana/CloudLabonESI/emulab-devel-new/emulab-devel/sample_build/sbin/batch_daemon -d
			else
				/users/mshobana/CloudLabonESI/emulab-devel-new/emulab-devel/sample_build/sbin/batch_daemon
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
