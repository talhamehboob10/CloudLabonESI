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
	        if [ -x /home/achauhan06/CLOUDLAB/SSHCLOUD/CloudLabonESI/emulab-devel/newbuild/sbin/setsitevar ]; then
		    disabled=`/home/achauhan06/CLOUDLAB/SSHCLOUD/CloudLabonESI/emulab-devel/newbuild/sbin/setsitevar -c general/testbed_shutdown`
		    if [ $? -ne 0 ]; then
			echo -n " mysqld not running, skipping testbed startup"
			exit 0
		    fi
		    if [ $disabled -gt 0 ]; then
			echo -n " testbed disabled"
			exit 0
		    fi
		fi
		if [ -x /home/achauhan06/CLOUDLAB/SSHCLOUD/CloudLabonESI/emulab-devel/newbuild/sbin/dbboot ]; then
		        # Delay a moment so that mysqld has started!
		        sleep 2
			echo -n " dbboot"
			/home/achauhan06/CLOUDLAB/SSHCLOUD/CloudLabonESI/emulab-devel/newbuild/sbin/dbboot
		fi

		if [ -x /home/achauhan06/CLOUDLAB/SSHCLOUD/CloudLabonESI/emulab-devel/newbuild/sbin/bootinfo.restart  ]; then
			echo -n " bootinfo"
			/home/achauhan06/CLOUDLAB/SSHCLOUD/CloudLabonESI/emulab-devel/newbuild/sbin/bootinfo.restart
		fi

		if [ -x /home/achauhan06/CLOUDLAB/SSHCLOUD/CloudLabonESI/emulab-devel/newbuild/sbin/tmcd.restart  ]; then
			echo -n " tmcd"
			/home/achauhan06/CLOUDLAB/SSHCLOUD/CloudLabonESI/emulab-devel/newbuild/sbin/tmcd.restart
		fi

		if [ -x /home/achauhan06/CLOUDLAB/SSHCLOUD/CloudLabonESI/emulab-devel/newbuild/sbin/capserver  ]; then
			echo -n " capd"
			/home/achauhan06/CLOUDLAB/SSHCLOUD/CloudLabonESI/emulab-devel/newbuild/sbin/capserver
		fi

		if [ -x /home/achauhan06/CLOUDLAB/SSHCLOUD/CloudLabonESI/emulab-devel/newbuild/sbin/lastlog_daemon  ]; then
			echo -n " lastlogd"
			/home/achauhan06/CLOUDLAB/SSHCLOUD/CloudLabonESI/emulab-devel/newbuild/sbin/lastlog_daemon
		fi

		if [ -x /home/achauhan06/CLOUDLAB/SSHCLOUD/CloudLabonESI/emulab-devel/newbuild/sbin/sdcollectd  ]; then
			echo -n " sdcollectd"
			/home/achauhan06/CLOUDLAB/SSHCLOUD/CloudLabonESI/emulab-devel/newbuild/sbin/sdcollectd
		fi

		if [ -x /home/achauhan06/CLOUDLAB/SSHCLOUD/CloudLabonESI/emulab-devel/newbuild/sbin/stated  ]; then
			echo -n " stated"
			/home/achauhan06/CLOUDLAB/SSHCLOUD/CloudLabonESI/emulab-devel/newbuild/sbin/stated
		fi

		if [ -e /home/achauhan06/CLOUDLAB/SSHCLOUD/CloudLabonESI/emulab-devel/newbuild/etc/inetd.conf  ]; then
			echo -n " testbed-inetd"
			inetd -a boss.cloudlab.umass.edu -p /var/run/testbed-inetd.pid /home/achauhan06/CLOUDLAB/SSHCLOUD/CloudLabonESI/emulab-devel/newbuild/etc/inetd.conf
		fi

		if [ -x /home/achauhan06/CLOUDLAB/SSHCLOUD/CloudLabonESI/emulab-devel/newbuild/sbin/sslxmlrpc_server.py ]; then
			echo -n " sslxmlrpc_server"
			if [ -x /home/achauhan06/CLOUDLAB/SSHCLOUD/CloudLabonESI/emulab-devel/newbuild/sbin/daemon_wrapper ]; then
			    /home/achauhan06/CLOUDLAB/SSHCLOUD/CloudLabonESI/emulab-devel/newbuild/sbin/daemon_wrapper -i 30 \
			          -l /home/achauhan06/CLOUDLAB/SSHCLOUD/CloudLabonESI/emulab-devel/newbuild/log/sslxmlrpc_server.log \
			          -p /var/run/sslxmlrpc_server.pid \
			          /home/achauhan06/CLOUDLAB/SSHCLOUD/CloudLabonESI/emulab-devel/newbuild/sbin/sslxmlrpc_server.py -f

			else
			        /home/achauhan06/CLOUDLAB/SSHCLOUD/CloudLabonESI/emulab-devel/newbuild/sbin/sslxmlrpc_server.py 2>/dev/null
			fi
		fi

		# mfrisbeed started with its own script

		if [ -x /home/achauhan06/CLOUDLAB/SSHCLOUD/CloudLabonESI/emulab-devel/newbuild/sbin/reload_daemon  ]; then
			echo -n " reloadd"
			/home/achauhan06/CLOUDLAB/SSHCLOUD/CloudLabonESI/emulab-devel/newbuild/sbin/reload_daemon
		fi

		if [ -x /home/achauhan06/CLOUDLAB/SSHCLOUD/CloudLabonESI/emulab-devel/newbuild/sbin/checkup_daemon  ]; then
			echo -n " checkupd"
			/home/achauhan06/CLOUDLAB/SSHCLOUD/CloudLabonESI/emulab-devel/newbuild/sbin/checkup_daemon
		fi

		if [ -x /home/achauhan06/CLOUDLAB/SSHCLOUD/CloudLabonESI/emulab-devel/newbuild/sbin/mysqld_watchdog  ]; then
			echo -n " mysqld_watchdog"
			/home/achauhan06/CLOUDLAB/SSHCLOUD/CloudLabonESI/emulab-devel/newbuild/sbin/mysqld_watchdog
		fi

		if [ -x /home/achauhan06/CLOUDLAB/SSHCLOUD/CloudLabonESI/emulab-devel/newbuild/sbin/lease_daemon  ]; then
			echo -n " lease_daemon"
			/home/achauhan06/CLOUDLAB/SSHCLOUD/CloudLabonESI/emulab-devel/newbuild/sbin/lease_daemon
		fi

		if [ -x /home/achauhan06/CLOUDLAB/SSHCLOUD/CloudLabonESI/emulab-devel/newbuild/sbin/protogeni/expire_daemon ]; then
			echo -n " expire_daemon"
			/home/achauhan06/CLOUDLAB/SSHCLOUD/CloudLabonESI/emulab-devel/newbuild/sbin/protogeni/expire_daemon
		fi

		if [ -x /home/achauhan06/CLOUDLAB/SSHCLOUD/CloudLabonESI/emulab-devel/newbuild/sbin/protogeni/sa_daemon ]; then
			echo -n " sa_daemon"
			/home/achauhan06/CLOUDLAB/SSHCLOUD/CloudLabonESI/emulab-devel/newbuild/sbin/protogeni/sa_daemon
		fi

		if [ -x /home/achauhan06/CLOUDLAB/SSHCLOUD/CloudLabonESI/emulab-devel/newbuild/sbin/protogeni/ch_daemon ]; then
			echo -n " ch_daemon"
			/home/achauhan06/CLOUDLAB/SSHCLOUD/CloudLabonESI/emulab-devel/newbuild/sbin/protogeni/ch_daemon
		fi

		if [ -x /home/achauhan06/CLOUDLAB/SSHCLOUD/CloudLabonESI/emulab-devel/newbuild/sbin/protogeni/ims_daemon ]; then
			echo -n " ims_daemon"
			/home/achauhan06/CLOUDLAB/SSHCLOUD/CloudLabonESI/emulab-devel/newbuild/sbin/protogeni/ims_daemon
		fi

		if [ -x /home/achauhan06/CLOUDLAB/SSHCLOUD/CloudLabonESI/emulab-devel/newbuild/sbin/protogeni/igevent_daemon ]; then
			echo -n " igevent_daemon"
			/home/achauhan06/CLOUDLAB/SSHCLOUD/CloudLabonESI/emulab-devel/newbuild/sbin/protogeni/igevent_daemon
		fi

		if [ -x /home/achauhan06/CLOUDLAB/SSHCLOUD/CloudLabonESI/emulab-devel/newbuild/sbin/checknodes_daemon  ]; then
			echo -n " checknodes_daemon"
			/home/achauhan06/CLOUDLAB/SSHCLOUD/CloudLabonESI/emulab-devel/newbuild/sbin/checknodes_daemon
		fi

		if [ -x /home/achauhan06/CLOUDLAB/SSHCLOUD/CloudLabonESI/emulab-devel/newbuild/sbin/peer_daemon  ]; then
			echo -n " peer_daemon"
			/home/achauhan06/CLOUDLAB/SSHCLOUD/CloudLabonESI/emulab-devel/newbuild/sbin/peer_daemon
		fi

		if [ -x /home/achauhan06/CLOUDLAB/SSHCLOUD/CloudLabonESI/emulab-devel/newbuild/sbin/poolmonitor ]; then
			echo -n " poolmonitor"
			/home/achauhan06/CLOUDLAB/SSHCLOUD/CloudLabonESI/emulab-devel/newbuild/sbin/poolmonitor
		fi

		if [ -x /home/achauhan06/CLOUDLAB/SSHCLOUD/CloudLabonESI/emulab-devel/newbuild/sbin/tcppd ]; then
		        echo -n " tcppd"
			/home/achauhan06/CLOUDLAB/SSHCLOUD/CloudLabonESI/emulab-devel/newbuild/sbin/tcppd &
		fi

		if [ -x /home/achauhan06/CLOUDLAB/SSHCLOUD/CloudLabonESI/emulab-devel/newbuild/sbin/event_watchdog ]; then
		        echo -n " event_watchdog"
			/home/achauhan06/CLOUDLAB/SSHCLOUD/CloudLabonESI/emulab-devel/newbuild/sbin/event_watchdog
		fi

		if [ -x /home/achauhan06/CLOUDLAB/SSHCLOUD/CloudLabonESI/emulab-devel/newbuild/sbin/apt_daemon ]; then
			echo -n " apt_daemon"
			/home/achauhan06/CLOUDLAB/SSHCLOUD/CloudLabonESI/emulab-devel/newbuild/sbin/apt_daemon
		fi
		
		if [ -x /home/achauhan06/CLOUDLAB/SSHCLOUD/CloudLabonESI/emulab-devel/newbuild/sbin/aptexpire_daemon ]; then
			echo -n " aptexpire_daemon"
			/home/achauhan06/CLOUDLAB/SSHCLOUD/CloudLabonESI/emulab-devel/newbuild/sbin/aptexpire_daemon
		fi
		
		if [ -x /home/achauhan06/CLOUDLAB/SSHCLOUD/CloudLabonESI/emulab-devel/newbuild/sbin/aptevent_daemon ]; then
			echo -n " aptevent_daemon"
			/home/achauhan06/CLOUDLAB/SSHCLOUD/CloudLabonESI/emulab-devel/newbuild/sbin/aptevent_daemon
		fi

		if [ -x /home/achauhan06/CLOUDLAB/SSHCLOUD/CloudLabonESI/emulab-devel/newbuild/sbin/aptresgroup_daemon ]; then
			echo -n " aptresgroup_daemon"
			/home/achauhan06/CLOUDLAB/SSHCLOUD/CloudLabonESI/emulab-devel/newbuild/sbin/aptresgroup_daemon
		fi

		if [ $MAINSITE == "1" -a -x /home/achauhan06/CLOUDLAB/SSHCLOUD/CloudLabonESI/emulab-devel/newbuild/sbin/aptbus_monitor ]; then
			echo -n " aptbus_monitor"
			/home/achauhan06/CLOUDLAB/SSHCLOUD/CloudLabonESI/emulab-devel/newbuild/sbin/aptbus_monitor
		fi

		if [ -x /home/achauhan06/CLOUDLAB/SSHCLOUD/CloudLabonESI/emulab-devel/newbuild/sbin/aptimage_daemon ]; then
			echo -n " aptimage_daemon"
			/home/achauhan06/CLOUDLAB/SSHCLOUD/CloudLabonESI/emulab-devel/newbuild/sbin/aptimage_daemon
		fi

		if [ -x /home/achauhan06/CLOUDLAB/SSHCLOUD/CloudLabonESI/emulab-devel/newbuild/sbin/apt_scheduler ]; then
			echo -n " apt_scheduler"
			/home/achauhan06/CLOUDLAB/SSHCLOUD/CloudLabonESI/emulab-devel/newbuild/sbin/apt_scheduler
		fi

		if [ -x /home/achauhan06/CLOUDLAB/SSHCLOUD/CloudLabonESI/emulab-devel/newbuild/sbin/cnetwatch ]; then
			echo -n " cnetwatch"
			/home/achauhan06/CLOUDLAB/SSHCLOUD/CloudLabonESI/emulab-devel/newbuild/sbin/cnetwatch
		fi

		if [ $MAINSITE == "1" -a -x /home/achauhan06/CLOUDLAB/SSHCLOUD/CloudLabonESI/emulab-devel/newbuild/sbin/portal_monitor ]; then
			echo -n " portal_monitor"
			/home/achauhan06/CLOUDLAB/SSHCLOUD/CloudLabonESI/emulab-devel/newbuild/sbin/portal_monitor
		fi

		if [ "0" == "1" -a -x /home/achauhan06/CLOUDLAB/SSHCLOUD/CloudLabonESI/emulab-devel/newbuild/sbin/rfmonitor_daemon ]; then
			echo -n " rfmonitor_daemon"
			/home/achauhan06/CLOUDLAB/SSHCLOUD/CloudLabonESI/emulab-devel/newbuild/sbin/rfmonitor_daemon
		fi

		if [ -x /home/achauhan06/CLOUDLAB/SSHCLOUD/CloudLabonESI/emulab-devel/newbuild/sbin/portal_resources ]; then
			echo -n " portal_resources"
			/home/achauhan06/CLOUDLAB/SSHCLOUD/CloudLabonESI/emulab-devel/newbuild/sbin/portal_resources
		fi
		#
		# Could trigger experiment creation, so make sure everything
		# else is setup first; i.e., run this last!
		#
		if [ \( 0 -eq 0 -o 0 -eq 1 \)\
			-a -x /home/achauhan06/CLOUDLAB/SSHCLOUD/CloudLabonESI/emulab-devel/newbuild/sbin/reportboot_daemon ]; then
			echo -n " reportboot daemon "
			if [ -x /home/achauhan06/CLOUDLAB/SSHCLOUD/CloudLabonESI/emulab-devel/newbuild/sbin/daemon_wrapper ]; then
			    /home/achauhan06/CLOUDLAB/SSHCLOUD/CloudLabonESI/emulab-devel/newbuild/sbin/daemon_wrapper -i 30 \
			          -l /home/achauhan06/CLOUDLAB/SSHCLOUD/CloudLabonESI/emulab-devel/newbuild/log/reportboot.log \
			          -p /var/run/reportboot_daemon.pid \
				  /home/achauhan06/CLOUDLAB/SSHCLOUD/CloudLabonESI/emulab-devel/newbuild/sbin/reportboot_daemon -f 
			else
				/home/achauhan06/CLOUDLAB/SSHCLOUD/CloudLabonESI/emulab-devel/newbuild/sbin/reportboot_daemon 
			fi
		fi

		if [ -n "" -a -x /home/achauhan06/CLOUDLAB/SSHCLOUD/CloudLabonESI/emulab-devel/newbuild/sbin/attend ]; then
			echo -n " attend"
			/home/achauhan06/CLOUDLAB/SSHCLOUD/CloudLabonESI/emulab-devel/newbuild/sbin/attend
		fi

		#
		# Could trigger experiment creation, so make sure everything
		# else is setup first; i.e., run this last!
		#
		if [ -x /home/achauhan06/CLOUDLAB/SSHCLOUD/CloudLabonESI/emulab-devel/newbuild/sbin/batch_daemon  ]; then
			echo -n " batchd wrapper "
			if [ -x /home/achauhan06/CLOUDLAB/SSHCLOUD/CloudLabonESI/emulab-devel/newbuild/sbin/daemon_wrapper ]; then
				/home/achauhan06/CLOUDLAB/SSHCLOUD/CloudLabonESI/emulab-devel/newbuild/sbin/daemon_wrapper \
				  -i 30 -l /home/achauhan06/CLOUDLAB/SSHCLOUD/CloudLabonESI/emulab-devel/newbuild/log/batchlog \
				  /home/achauhan06/CLOUDLAB/SSHCLOUD/CloudLabonESI/emulab-devel/newbuild/sbin/batch_daemon -d
			else
				/home/achauhan06/CLOUDLAB/SSHCLOUD/CloudLabonESI/emulab-devel/newbuild/sbin/batch_daemon
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
