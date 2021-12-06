#!/bin/sh

iface=$1
if [ -z "$iface" ]; then
    echo "ERROR: must provide an interface as the sole argument"
    exit 1
fi

if [ -e /etc/emulab/paths.sh ]; then
    . /etc/emulab/paths.sh
else
    BOOTDIR=/var/emulab/boot
    LOGDIR=/var/emulab/logs
fi

mkdir -p $LOGDIR
LOGFILE=$LOGDIR/emulab-networkd-$iface.log
echo "`date`: ${iface}: starting" >>$LOGFILE 2>&1

found=0
while [ ! $found -eq 1 ]; do
    # If the control net iface was found, and it's not us, exit.
    if [ -e /run/cnet ]; then
	echo "`date`: ${iface}: control net is not us, removing ${iface}.network" >>$LOGFILE 2>&1
	rm -f /run/systemd/network/${iface}.network
	exit 0
    fi
    #
    # The man page promises this will wait for $iface, but it does not.
    # Once an interface comes up, it seems to return.  Go figure.  This
    # means we have to check *which* interface came up; this is how we
    # determine if it was our interface or not.
    #
    /lib/systemd/systemd-networkd-wait-online --ignore=lo -q -i "$iface" --timeout 20 > /dev/null 2>&1
    #networkctl status | grep -qi 'state: *routable'
    if [ $? -eq 0 ]; then
	networkctl status "$iface" | grep -qi configured
	if [ $? -eq 0 ]; then
	    echo "`date`: ${iface}: control net is us" >>$LOGFILE 2>&1
	    mkdir -p /run/emulab
	    echo "$iface" > /run/cnet
	    #
	    # We only add the CriticalConnection bit once we have the cnet
	    # iface detected, because newer systemd-networkd whines a lot
	    # when the other searched-but-not-found interfaces are taken down.
	    #
	    echo "CriticalConnection=yes" >> /run/systemd/network/${iface}.network
	    found=1
	    if [ -e $STATICRUNDIR/emulab-networkd/${iface}.network.tail ]; then
		cat $STATICRUNDIR/emulab-networkd/${iface}.network.tail \
		    >> /run/systemd/network/${iface}.network
	    fi
	fi
    fi
done

#
# If the control net iface was us, *and* if systemd-networkd tried to
# use the .network files our udev helper generated (we have to be
# careful that user did not override them with static configuration),
# remove the .network files other instances of us created, down those
# ifaces (systemd-networkd leaves them up), and restart
# systemd-networkd, so it properly shows that it is only managing the
# one control net interface.  We could kill it off, but may as well
# leave it running; running `networkctl` will bring it right back.  It
# is less invasive than networkmanager, so this should be fine.
#
if [ $found -eq 1 ]; then
    echo "emulab-networkd[$$]: found $iface as control net"
    controlif=`cat /run/cnet`
    for file in `ls -1 /run/systemd/network/*.network | grep -v $controlif.network`; do
	grep -q "Description=.*Emulab" $file
	if [ ! $? -eq 0 ]; then
	    echo "`date`: ${iface}: $file is not ours; ignoring" >>$LOGFILE 2>&1
	    continue
	fi
	ifa=`echo $file | sed -ne 's|^.*/network/\([^\.]*\)\.network$|\1|p'`
	rm -f $file
	# Check to see if our file was being used to manage this iface,
	# or if it got overridden.
	networkctl status $ifa | grep -q "Network File: $file"
	if [ $? -eq 0 ]; then
	    ip link set $ifa down
	    echo "`date`: ${iface}: downed $ifa" >>$LOGFILE 2>&1
	else
	    echo "`date`: ${iface}: our .network for $ifa was overridden; just removing our .network file" >>$LOGFILE 2>&1
	fi
    done
    #
    # Restart systemd-networkd so its management status as shown via
    # networkctl is correct; we manage the other ifaces.
    #
    echo "`date`: ${iface}: restarting systemd-networkd" >>$LOGFILE 2>&1
    systemctl restart systemd-networkd
    # Sadly, this does not get the network-online.target back into the
    # alive state, but we try; it was already hit, and restarting
    # systemd-networkd inactivates it.  But this seems to cause no
    # systemic harm.
    systemctl restart systemd-networkd-wait-online
fi

#
# Write some metadata in /var/emulab/boot.  The
# /run/systemd/netif/leases/<ifindex> file has what we need.
#
mkdir -p $BOOTDIR
mkdir -p /run/emulab
ifindex=`cat /sys/class/net/$iface/ifindex`
if [ -e /run/systemd/netif/leases/$ifindex ]; then
    echo "`date`: ${iface}: writing cnet metadata in $BOOTDIR" >>$LOGFILE 2>&1
    sed -re 's/^([^=]*)=(.*\s+.*)/\1="\2"/' /run/systemd/netif/leases/$ifindex \
	> /run/emulab/control-netif-lease
    . /run/emulab/control-netif-lease
elif [ -e /run/systemd/netif/leases/* ]; then
    echo "`date`: ${iface}: unexpected leases file with mismatched ifindex; attempting to use anyway to write cnet metadata in $BOOTDIR" >>$LOGFILE 2>&1
    for f in /run/systemd/netif/leases/* ; do
	sed -re 's/^([^=]*)=(.*\s+.*)/\1="\2"/' $f \
	    >> /run/emulab/control-netif-lease
    done
    . /run/emulab/control-netif-lease
else
    echo "`date`: ${iface}: no leases file in /run/systemd/netif/leases; cannot write cnet metadata in $BOOTDIR; failing!" >>$LOGFILE 2>&1
    exit 1
fi

# Actually do the metadata file writes.    
echo $SERVER_ADDRESS > $BOOTDIR/bossip
echo $HOSTNAME > $BOOTDIR/realname
echo $ROUTER > $BOOTDIR/routerip
echo $ADDRESS > $BOOTDIR/myip
echo $NETMASK > $BOOTDIR/mynetmask
echo $DOMAINNAME > $BOOTDIR/mydomain
echo $iface > $BOOTDIR/controlif
#
# For Xen-based vnodes we record the vnode name where the scripts expect it.
# XXX this works because only Xen-based vnodes DHCP.
#
case "$HOSTNAME" in
    pcvm*)
	echo $HOSTNAME > $BOOTDIR/vmname
	;;
esac

#
# Make sure the hostname is set to something sane.
#
if [ `hostname -s` != "$HOSTNAME" ]; then
    hostname $HOSTNAME
fi

#
# Ensure /etc/resolv.conf is set to something sane.  We are not using
# systemd-resolved, so all we want is for /etc/resolv.conf to point to
# /run/systemd/resolve/resolv.conf .  But if it doesn't, just update it
# in place.
#
if [ -L /etc/resolv.conf \
     -a ! -f `readlink -f /etc/resolv.conf` \
     -a -f /run/systemd/resolve/resolv.conf ]; then
    echo "`date`: fixing /etc/resolv.conf to point to /run/systemd/resolve/resolv.conf" >>$LOGFILE 2>&1
    ln -sf /run/systemd/resolve/resolv.conf /etc/resolv.conf
elif [ ! -L /etc/resolv.conf ]; then
    echo "`date`: updating static /etc/resolv.conf; should be symlink!" >>$LOGFILE 2>&1
    rm -f /etc/resolv.conf
    for ns in $DNS ; do
	echo nameserver $ns >> /etc/resolv.conf
    done
    echo search $DOMAINNAME >> /etc/resolv.conf
fi

#
# See if the Testbed configuration software wants to change the hostname.
#
if [ -x $BINDIR/sethostname.dhclient ]; then
    $BINDIR/sethostname.dhclient >>$LOGDIR/dhclient.log 2>&1
fi

echo "`date`: ${iface}: done!" >>$LOGFILE 2>&1

#
# Tell other scripts waiting on us that we are done.
#
touch /run/cnet-done

exit 0
