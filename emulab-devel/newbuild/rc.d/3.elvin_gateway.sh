#! /bin/sh
#
# PROVIDE: elvin_gateway
# REQUIRE: pubsub
#

case $1 in
start|faststart)
    if test -x /usr/local/libexec/elvin_gateway; then
	if [ -x /home/achauhan06/CLOUDLAB/SSHCLOUD/CloudLabonESI/emulab-devel/newbuild/sbin/daemon_wrapper ]; then
	    echo -n " elvin_gateway wrapper"
	    /home/achauhan06/CLOUDLAB/SSHCLOUD/CloudLabonESI/emulab-devel/newbuild/sbin/daemon_wrapper -l /home/achauhan06/CLOUDLAB/SSHCLOUD/CloudLabonESI/emulab-devel/newbuild/log/elvin_gateway.log \
		/usr/local/libexec/elvin_gateway -d
	else
	    echo -n " elvin_gateway"
	    /usr/local/libexec/elvin_gateway
	fi
    fi
    ;;
stop)
    if [ -r /var/run/elvin_gateway_wrapper.pid ]; then
	kill `cat /var/run/elvin_gateway_wrapper.pid`
    else
	killall elvin_gateway
    fi
    ;;
esac
