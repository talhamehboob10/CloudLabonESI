#!/usr/bin/perl -w
#
# Copyright (c) 2000-2017 University of Utah and the Flux Group.
# 
# {{{EMULAB-LICENSE
# 
# This file is part of the Emulab network testbed software.
# 
# This file is free software: you can redistribute it and/or modify it
# under the terms of the GNU Affero General Public License as published by
# the Free Software Foundation, either version 3 of the License, or (at
# your option) any later version.
# 
# This file is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
# FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Affero General Public
# License for more details.
# 
# You should have received a copy of the GNU Affero General Public License
# along with this file.  If not, see <http://www.gnu.org/licenses/>.
# 
# }}}
#
use strict;
use Getopt::Std;
use English;
use Data::Dumper;

#
# Invoked by xmcreate script to configure a tunnel interface.
#
# NOTE: vmid should be an integer ID.
#
sub usage()
{
    print "Usage: emulab-tun ".
	"vmid inetip basetable routetable (online|offline)\n";
    exit(1);
}

#
# Turn off line buffering on output
#
$| = 1;

# Drag in path stuff so we can find emulab stuff.
BEGIN { require "/etc/emulab/paths.pm"; import emulabpaths; }

#
# Load the OS independent support library. It will load the OS dependent
# library and initialize itself. 
# 
use libsetup;
use libtmcc;
use libutil;
use libtestbed;
use libgenvnode;
use libvnode;

#
# Configure.
#
my $IPTABLES	= "/sbin/iptables";
my $IPBIN	= "/sbin/ip";
my $IFCONFIG    = "/sbin/ifconfig";
my $OVSCTL      = "/usr/local/bin/ovs-vsctl";
if (! -x "$OVSCTL") {
    $OVSCTL   = "/usr/bin/ovs-vsctl";
}
usage()
    if (@ARGV  < 4);

my $vmid       = shift(@ARGV);
my $mac        = shift(@ARGV);
my $bridge     = shift(@ARGV);
my $vifname    = shift(@ARGV);

# The caller (xmcreate) puts this into the environment.
my $vif         = $ENV{'vif'};
my $XENBUS_PATH = $ENV{'XENBUS_PATH'};

#
# Set up ip rules and routes for tunnels.
#
sub Online()
{
    # Rename so we can find it more easily.
    mysystem2("$IPBIN link set $vif name $vifname");
    if ($?) {
	return -1;
    }
    $vif = $vifname;
    mysystem2("$IFCONFIG $vif 0 up");
    mysystem2("echo 1 > /proc/sys/net/ipv4/conf/$vif/forwarding");
    mysystem2("echo 1 > /proc/sys/net/ipv4/conf/$vif/proxy_arp");
    mysystem2("$IPBIN link set $vif mtu 1450");

    #
    # We need to allow fowarding. vif-bridge does this, but since
    # we are doing our own bridge setup, we have to do this here. 
    #
    DoIPtables("-A FORWARD -m physdev --physdev-is-bridged --physdev-in ".
	       " $vif -j ACCEPT")
	== 0 or return -1;
    DoIPtables("-A FORWARD -m physdev --physdev-is-bridged --physdev-out ".
	       " $vif -j ACCEPT")
	== 0 or return -1;
	       
    #
    # Add the veth to the OVS bridge. 
    #
    mysystem2("$OVSCTL add-port $bridge $vif") == 0
	or return -1;

    # Ug, tell xen hotplug that we really did what was needed.
    mysystem2("xenstore-write '$XENBUS_PATH/hotplug-status' connected");
    return 0;
}

sub Offline()
{
    DoIPtables("-D FORWARD -m physdev --physdev-is-bridged --physdev-in ".
	       " $vif -j ACCEPT");
    DoIPtables("-D FORWARD -m physdev --physdev-is-bridged --physdev-out ".
	       " $vif -j ACCEPT");
	       
    mysystem2("$OVSCTL del-port $bridge $vifname") == 0
	or return -1;
    
    return 0;
}

if (@ARGV) {
    my $rval = 0;
    my $op   = shift(@ARGV);
    if ($op eq "online") {
	$rval = Online();
    }
    elsif ($op eq "offline") {
	$rval = Offline();
    }
    exit($rval);
}
exit(0);
