#!/bin/sh

#
# This simply drops a .network file for interface $1 into
# /run/systemd/network so that networkd can pick it up, unless it gets
# overridden.
#

iface=$1
if [ -z "$iface" ]; then
    echo "ERROR: must provide an interface as the sole argument"
    exit 1
fi

#
# If this is a management interface, ignore it.
#
((echo "$iface" | grep -qi idrac) || (echo "$iface" | grep -qi ilo)) && exit 0

#
# NB, if the user has overridden this by some file in
# /etc/systemd/network, that takes precedence, and this won't be run.
# We have specific code in emulab-networkd.sh that is run from
# emulab-networkd-online@.service that checks to see if this file was
# used or not; we only handle the iface there if this file got used.
# NB: CriticalConnection=yes is added later by emulab-networkd.sh to
# the config file for the control net iface before systemd-networkd
# is restarted; thus, it does not appear below.
#
mkdir -p /run/systemd/network
cat <<EOF > /run/systemd/network/${iface}.network
[Match]
Name=$iface

[Network]
Description=Emulab control net search on $iface
DHCP=yes

[DHCP]
UseNTP=yes
UseHostname=no
UseDomains=yes
EOF

exit 0
