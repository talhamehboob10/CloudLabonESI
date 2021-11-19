#!/bin/sh
### BEGIN INIT INFO
# Provides:        genirack
# Required-Start:  $network
# Required-Stop:   $network
# X-Start-Before:  xend isc-dhcp-server
# Default-Start:   2 3 4 5
# Default-Stop:    0 1 6
# Short-Description: Configure GeniRack Stuff
# Description:     Configure GeniRack Stuff
### END INIT INFO

PATH=/sbin:/bin:/usr/sbin:/usr/bin

. /lib/init/vars.sh
. /lib/lsb/init-functions
. /etc/emulab/paths.sh

do_start() {
    if [ -x $BINDIR/xenbridge-setup ]; then
        log_daemon_msg "Setting up Xen Bridges"
	$BINDIR/xenbridge-setup \
	    && 	$BINDIR/xenbridge-setup -b xenbr1 eth1 \
	    && 	$BINDIR/xenbridge-setup -b xenbr2 eth2 \
	    && 	$BINDIR/xenbridge-setup -b xenbr3 eth3
	ES=$?
	return $ES
    fi
}

case "$1" in
    start)
	do_start
        ;;
    restart|reload|force-reload)
        echo "Error: argument '$1' not supported" >&2
        exit 3
        ;;
    stop)
        ;;
    *)
        echo "Usage: $0 start|stop" >&2
        exit 3
        ;;
esac

