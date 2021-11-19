#!/bin/sh
#
# vzinitnet-elab handles all the tasks associated with configuring runtime state
# of Emulab openvz containers.  We unfortunately can't do all this from 
# bootvnodes because the root context "half" of the veth device pair is not
# persistent across starts and stops of the container... so we have to use the
# openvz way to try to get the veths get configured in good time, and to make
# sure that if a user reboots the container, all this stuff still happens 
# even though bootvnodes is not in the path.
#

# first arg can be "init"
OP=$1
# second arg can be "veth"
DEVTYPE=$2
# third arg is the CT0 name of the veth
DEV=$3

CONFIGFILE=/etc/vz/conf/$VEID.conf
if [ ! -f $CONFIGFILE ]; then
    echo "Could not find $CONFIGFILE!"
    exit 1
fi
. $CONFIGFILE

IFCONFIG=/sbin/ifconfig
ROUTE=/sbin/route
IP=/sbin/ip
BRCTL=/usr/sbin/brctl
OVSCTL=/usr/local/bin/ovs-vsctl

# ELABIFS="veth100.1,br0;veth100.2,brp3"
# ELABBRS="br0:noencap,short;brp3:encap"
# ELABCTRLIP="172.16.1.10"
# ELABCTRLDEV="veth100.999"

if [ -z "$ELABCUSTOM" -o "$ELABCUSTOM" != "yes" ]; then
    exit 0
fi

#
# Control net is a special case:
#
if [ $ELABCTRLDEV = $DEV ]; then
    echo "Emulab configuring network for CT$VEID: control net ($ELABCTRLDEV)"
    if [ "x$ELABCTRLBR" != "x" ]; then
	if [ -e /usr/local/var/run/openvswitch/ovsdb-server.pid ]; then
	    $OVSCTL add-port $ELABCTRLBR $ELABCTRLDEV
	else
	    $BRCTL addif $ELABCTRLBR $ELABCTRLDEV
	fi
    fi
    $IFCONFIG $ELABCTRLDEV 2&>1 > /dev/null
    while [ $? -ne 0 ]; do
	echo "Waiting for $ELABCTRLDEV to appear"
	sleep 1
	$IFCONFIG $ELABCTRLDEV 2&>1 > /dev/null
    done
    $IFCONFIG $ELABCTRLDEV 0 up
    echo 1 > /proc/sys/net/ipv4/conf/$ELABCTRLDEV/forwarding
    if [ "x$ELABCTRLBR" = "x" ]; then
	echo 1 > /proc/sys/net/ipv4/conf/$ELABCTRLDEV/proxy_arp
	$ROUTE add -host $ELABCTRLIP dev $ELABCTRLDEV
    else
        $ROUTE add -host $ELABCTRLIP dev $ELABCTRLBR
    fi
    # Hmm, weird race. Sometimes the container starts with its
    # control network not working right. This seems to help. 
    sleep 2
    # no point continuing.
    exit 0
fi

#
# Make sure veths are in bridges, and up, fwding, etc
#
echo "$ELABIFS" | sed -e 's/;/\n/g' | \
    while read iface; \
    do \
        _if=`echo "$iface" | sed -r -e 's/([^,]*),[^,]*,[^,]*/\1/'`
        _br=`echo "$iface" | sed -r -e 's/[^,]*,([^,]*),[^,]*/\1/'`
        _sc=`echo "$iface" | sed -r -e 's/[^,]*,[^,]*,([^,]*)/\1/'`

	if [ $_if = $DEV ]; then
	    echo "Emulab configuring network for CT$VEID: exp net ($_if)"
    	    if [ "x$_br" != "x" ]; then
		if [ -e /usr/local/var/run/openvswitch/ovsdb-server.pid ]; then
		    $OVSCTL add-port $_br $_if
		else
	            $BRCTL addif $_br $_if
		fi
	    fi
	    $IFCONFIG $_if 2&>1 > /dev/null
	    while [ $? -ne 0 ]; do
		echo "Waiting for $_if to appear"
		sleep 1
		$IFCONFIG $_if 2&>1 > /dev/null
	    done

	    $IFCONFIG $_if 0 up
	    echo 1 > /proc/sys/net/ipv4/conf/$_if/forwarding
	    echo 1 > /proc/sys/net/ipv4/conf/$_if/proxy_arp
	    $_sc
	fi
    done

#
# Get the routes, as for tunnels. This is not a workable approach.
#
if [ "x$ELABROUTES" != "x" ]; then
    echo "$ELABROUTES" | sed -e 's/;/\n/g' | \
	while read route; \
	do \
            _if=`echo "$route" | sed -r -e 's/([^,]*),[^,]*,[^,]*/\1/'`
            _rt=`echo "$route" | sed -r -e 's/[^,]*,([^,]*),[^,]*/\1/'`

	    if [ $_if = $DEV ]; then
		echo "Emulab configuring route for CT$VEID: exp net ($_if)"
		$IP route replace default via $_rt dev $_if onlink table $ROUTETABLE
	    fi
    done
fi

exit 0
