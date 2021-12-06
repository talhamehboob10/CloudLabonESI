#!/usr/bin/perl -w
#
# Copyright (c) 2000-2018 University of Utah and the Flux Group.
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
use POSIX qw(setsid);
use POSIX ":sys_wait_h";
use POSIX ":signal_h";
use Socket;

#
# Invoked by xmcreate script to configure the control network for a vnode.
#
# NOTE: vmid should be an integer ID.
#
sub usage()
{
    print "Usage: emulab-cnet ".
	"vmid host_ip vnode_name vnode_ip (online|offline)\n";
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

my $lockdebug = 0;

#
# Configure.
#
my $TMCD_PORT	= 7777;
my $SLOTHD_PORT = 8509;
my $EVPROXY_PORT= 16505;
# where all our config files go
my $VMS         = "/var/emulab/vms";
my $VMDIR       = "$VMS/vminfo";
my $IPTABLES	= "/sbin/iptables";
my $ARPING      = "/usr/bin/arping";
# For testing.
my $VIFROUTING  = ((-e "$ETCDIR/xenvifrouting") ? 1 : 0);

usage()
    if (@ARGV < 6);

my $vmid      = shift(@ARGV);
my $host_ip   = shift(@ARGV);
my $vnode_id  = shift(@ARGV);
my $vnode_ip  = shift(@ARGV);
my $vnode_mac = shift(@ARGV);
my $elabinelab= shift(@ARGV);
my $ipaliases = shift(@ARGV);

# The caller (xmcreate) puts this into the environment.
my $vif         = $ENV{'vif'};
my $XENBUS_PATH = $ENV{'XENBUS_PATH'};
my $bridge      = `xenstore-read "$XENBUS_PATH/bridge"`;

#
# Well, this is interesting; we are called with the XEN store
# gone and so not able to find the bridge. vif-bridge does the same
# thing and just ignores it! So if we cannot get it, default to what
# currently think is the control network bridge, so that vif-bridge
# does not leave a bunch of iptables rules behind. 
#
if ($?) {
    $bridge = "xenbr0";
    # For vif-bridge
    $ENV{"bridge"} = $bridge;
}
chomp($bridge);

#
# We need the domid below; we can figure that out from the XENBUS_PATH.
#
my $domid;
if ($XENBUS_PATH =~ /vif\/(\d*)\//) {
    $domid = $1;
}
else {
    die("Could not determine domid from $XENBUS_PATH\n");
}

my ($bossdomain) = tmccbossinfo();
die("Could not get bossname from tmcc!")
    if (!defined($bossdomain));
if ($bossdomain =~ /^[-\w]+\.(.*)$/) {
    $bossdomain = $1;
}

# We need these IP addresses.
my $boss_ip = `host boss.${bossdomain} | grep 'has address'`;
if ($boss_ip =~ /has address ([0-9\.]*)$/) {
    $boss_ip = $1;
}
my $ops_ip = `host ops.${bossdomain} | grep 'has address'`;
if ($ops_ip =~ /has address ([0-9\.]*)$/) {
    $ops_ip = $1;
}
my $fs_ip = `host fs.${bossdomain} | grep 'has address'`;
if ($fs_ip =~ /has address ([0-9\.]*)$/) {
    $fs_ip = $1;
}
my $PCNET_IP_FILE   = "$BOOTDIR/myip";
my $PCNET_MASK_FILE = "$BOOTDIR/mynetmask";
my $PCNET_GW_FILE   = "$BOOTDIR/routerip";

my $cnet_ip   = `cat $PCNET_IP_FILE`;
my $cnet_mask = `cat $PCNET_MASK_FILE`;
my $cnet_gw   = `cat $PCNET_GW_FILE`;
chomp($cnet_ip);
chomp($cnet_mask);
chomp($cnet_gw);
my $network   = inet_ntoa(inet_aton($cnet_ip) & inet_aton($cnet_mask));

my ($jail_network,$jail_netmask) = findVirtControlNet();
# XXX InstaGeni Rack Hack. Hack until I decide on a better way
my $fs_jailip = "172.17.253.254";

# Each container gets a tmcc proxy running on another port.
# If this changes, look at firewall handling in libvnode_xen.
my $local_tmcd_port = $TMCD_PORT + $vmid;

# Need this too.
my $outer_controlif = `cat $BOOTDIR/controlif`;
chomp($outer_controlif);

# Ick, iptables has a 28 character limit on chain names. But we have to
# be backwards compatible with existing chain names. See corresponding
# code in libvnode_xen.
my $INCOMING_CHAIN = "INCOMING_${vnode_id}";
my $OUTGOING_CHAIN = "OUTGOING_${vnode_id}";
if (length($INCOMING_CHAIN) > 28) {
    $INCOMING_CHAIN = "I_${vnode_id}";
    $OUTGOING_CHAIN = "O_${vnode_id}";
}

#
# We setup a bunch of iptables rules when a container goes online, and
# then clear them when it goes offline.
#
sub Online()
{
    my @rules;
    mysystem2("ifconfig $vif txqueuelen 256");

    if ($VIFROUTING) {
	my $lockref;
	
	#
	# When using routing instead of bridging, we have to restart
	# dhcp *after* the vif has been created so that dhcpd will
	# start listening on it. 
	#
	if (TBScriptLock("dhcpd", 0, 900, \$lockref) != TBSCRIPTLOCK_OKAY()) {
	    print STDERR "Could not get the dhcpd lock after a long time!\n";
	    return -1;
	}
	restartDHCP();
	TBScriptUnlock($lockref);

	#
	# And this clears the arp caches.
	#
	mysystem2("$ARPING -c 4 -A -I $bridge $vnode_ip");
    }

    @rules = ();

    # Prevent dhcp requests from leaving the physical host.
    push(@rules,
	 "-A FORWARD -o $bridge -m pkttype ".
	 "--pkt-type broadcast ".
	 "-m physdev --physdev-in $vif --physdev-is-bridged ".
	 "--physdev-out $outer_controlif -j DROP");

    #
    # We turn on antispoofing. In bridge mode, vif-bridge adds a rule
    # to allow outgoing traffic. But vif-route does this wrong, so we
    # do it here. We also need an incoming rule since in route mode,
    # incoming packets go throught the FORWARD table, which is set to
    # DROP for antispoofing.
    #
    # Everything goes through the per vnode INCOMING/OUTGOING tables
    # which are set up in libvnode_xen. If firewalling is not on, then
    # these chains just accept everything. 
    #
    if ($VIFROUTING) {
	push(@rules,
	     "-A FORWARD -i $vif -s $vnode_ip ".
	     "-m mac --mac-source $vnode_mac -j $OUTGOING_CHAIN");
	push(@rules,
	     "-A FORWARD -o $vif -d $vnode_ip -j $INCOMING_CHAIN");

	#
	# Another wrinkle. We have to think about packets coming from
	# the container and addressed to the physical host. Send them
	# through OUTGOING chain for filtering, rather then adding
	# another chain. We make sure there are appropriate rules in
	# the OUTGOING chain to protect the host.
	# 
	push(@rules,
	     "-A INPUT -i $vif -s $vnode_ip ".
	     "-m mac --mac-source $vnode_mac -j $OUTGOING_CHAIN");

	#
	# This rule effectively says that if the packet was not filtered 
	# by the INCOMING chain during forwarding, it must be okay to
	# output to the container; we do not want it to go through the
	# dom0 rules.
	#
	push(@rules,
	     "-A OUTPUT -o $vif -j ACCEPT");
    }
    else {
	#
	# Bridge mode. vif-bridge stuck some rules in that we do not
	# want, so insert some new rules ahead of them to capture the
	# packets we want to filter. But we still have to allow the
	# DHCP request packets through.
	#
	push(@rules,
	     "-I FORWARD -m physdev --physdev-is-bridged ".
	     "--physdev-in $vif -s $vnode_ip -j $OUTGOING_CHAIN");
	    
	if ($ipaliases ne "") {
	    foreach my $alias (split(",", $ipaliases)) {
		push(@rules,
		     "-I FORWARD -m physdev --physdev-is-bridged ".
		     "--physdev-in $vif -s $alias -j $OUTGOING_CHAIN");
	    }
	}
	    
	push(@rules,
	     "-I FORWARD -m physdev --physdev-is-bridged ".
	     "--physdev-out $vif -j $INCOMING_CHAIN");

	#
	# Another wrinkle. We have to think about packets coming from
	# the container and addressed to the physical host. Send them
	# through OUTGOING chain for filtering, rather then adding
	# another chain. We make sure there are appropriate rules in
	# the OUTGOING chain to protect the host.
	#
	# XXX: We cannot use the input interface or bridge options, cause
	# if the vnode_ip is unroutable, the packet appears to come from
	# eth0, according to iptables logging. WTF!
	# 
	push(@rules,
	     "-A INPUT -s $vnode_ip -j $OUTGOING_CHAIN");

	push(@rules,
	     "-A OUTPUT -d $vnode_ip -j ACCEPT");
    }

    # Apply the rules
    DoIPtables(@rules) == 0 or
	return -1;

    # Start a tmcc proxy (handles both TCP and UDP)
    my $tmccpid = fork();
    if ($tmccpid) {
	# Give child a chance to react.
	sleep(1);

	# Make sure it is alive.
	if (waitpid($tmccpid, &WNOHANG) == $tmccpid) {
	    print STDERR "$vnode_id: tmcc proxy failed to start\n";
	    return -1;
	}

	if (open(FD, ">/var/run/tmccproxy-$vnode_id.pid")) {
	    print FD "$tmccpid\n";
	    close(FD);
	}
    }
    else {
	POSIX::setsid();
	
	# XXX make sure we can kill the proxy when done
	local $SIG{TERM} = 'DEFAULT';

	exec("$BINDIR/tmcc.bin -d -t 15 -n $vnode_id ".
	       "  -X $host_ip:$local_tmcd_port -s $boss_ip -p $TMCD_PORT ".
	       "  -o $LOGDIR/tmccproxy.$vnode_id.log");
	die("Failed to exec tmcc proxy"); 
    }

    @rules = ();

    # Reroute tmcd calls to the proxy on the physical host
    push(@rules,
	 "-t nat -A PREROUTING -j DNAT -p tcp ".
	 "--dport $TMCD_PORT -d $boss_ip -s $vnode_ip ".
	 "--to-destination $host_ip:$local_tmcd_port");

    push(@rules,
	 "-t nat -A PREROUTING -j DNAT -p udp ".
	 "--dport $TMCD_PORT -d $boss_ip -s $vnode_ip ".
	 "--to-destination $host_ip:$local_tmcd_port");

    # Reroute evproxy to use the local daemon.
    push(@rules,
	 "-t nat -A PREROUTING -j DNAT -p tcp ".
	 "--dport $EVPROXY_PORT -d $ops_ip -s $vnode_ip ".
	 "--to-destination $host_ip:$EVPROXY_PORT");
    
    #
    # GROSS! source-nat all traffic destined the fs node, to come from the
    # vnode host, so that NFS mounts work. We do this for non-shared nodes.
    # Shared nodes do the mounts normally from inside the guest. The reason
    # for this distinction is that on a shared host, we ask vif-bridge to
    # turn on antispoofing so that the guest cannot use an IP address other
    # then what we assign. On a non-shared node, the user can log into the
    # physical host and pick any IP they want, but as long as the NFS server
    # is exporting only to the physical IP, they won't be able to mount
    # any directories outside their project. The NFS server *does* export
    # filesystems to the guest IPs if the guest is on a shared host.
    # 
    if (!SHAREDHOST()) {
	push(@rules,
	     "-t nat -A POSTROUTING -j SNAT ".
	     "--to-source $host_ip -s $vnode_ip -d $fs_ip,$fs_jailip ".
	     "-o $bridge");
    }

    #
    # rpcbind port restrictions. Probably need a better way to handle
    # these cases. Note the -I; these need to go at the beginning of
    # the chain (and note that the rules are reversed cause of that). 
    #
    if (isRoutable($vnode_ip) && !$elabinelab) {
	push(@rules,
	     "-I $INCOMING_CHAIN ".
	     "  -p udp --dport 111 -j DROP");
	push(@rules,
	     "-I $INCOMING_CHAIN ".
	     "  -p tcp --dport 111 -j DROP");
	push(@rules,
	     "-I $INCOMING_CHAIN -s $jail_network/$jail_netmask -p udp ".
	     "  --dport 111 -j ACCEPT");
	push(@rules,
	     "-I $INCOMING_CHAIN -s $jail_network/$jail_netmask -p tcp ".
	     "  --dport 111 -j ACCEPT");
	push(@rules,
	     "-I $INCOMING_CHAIN -s $network/$cnet_mask -p udp  ".
	     "  --dport 111 -j ACCEPT");
	push(@rules,
	     "-I $INCOMING_CHAIN -s $network/$cnet_mask -p tcp ".
	     "  --dport 111 -j ACCEPT");
    }
    # 
    # Watch for a vnode with a public IP, no need to nat. 
    #
    if (isRoutable($vnode_ip)) {
	goto skipnat;
    }

    # 
    # If the source is from the vnode, headed to the local control 
    # net, no need for any NAT; just let it through.
    #
    # On a remote node (pcpg) we are not bridged to the control
    # network, and so we route to the control network, and then
    # rely on the SNAT rule below. 
    #
    if (!REMOTEDED()) {
	push(@rules,
	     "-t nat -A POSTROUTING -j ACCEPT ".
	     "-s $vnode_ip -d $network/$cnet_mask");

	#
	# Do not rewrite multicast (frisbee) traffic. Client throws up.
	# 
	push(@rules,
	     "-t nat -A POSTROUTING -j ACCEPT ".
	     "-s $vnode_ip -d 224.0.0.0/4");

	#
	# Ditto the apod packet.
	#
	push(@rules,
	     "-t nat -A POSTROUTING -j ACCEPT ".
	     "-s $vnode_ip -m icmp --protocol icmp --icmp-type 6/6");

	#
	# Boss/ops/fs specific rules in case the control network is
	# segmented like it is in Utah.
	#
	push(@rules,
	     "-t nat -A POSTROUTING -j ACCEPT ".
	     "-s $vnode_ip -d $boss_ip,$ops_ip");
    }

    # 
    # Ditto for the jail network. On a remote node, the only
    # jail network in on our node, and all of them are bridged
    # togther anyway. 
    # 
    push(@rules,
	 "-t nat -A POSTROUTING -j ACCEPT ".
	 "-s $vnode_ip -d $jail_network/$jail_netmask");

    # 
    # Otherwise, setup NAT so that traffic leaving the vnode on its 
    # control net IP, that has been routed out the phys host's
    # control net iface, is NAT'd to the phys host's control
    # net IP, using SNAT.
    # 
    push(@rules,
	 "-t nat -A POSTROUTING ".
	 "-s $vnode_ip -o $outer_controlif ".
	 "-j SNAT --to-source $host_ip");

  skipnat:
    # Apply the rules
    DoIPtables(@rules) == 0 or
	return -1;

    return 0;
}

sub Offline()
{
    my @rules = ();

    if ($VIFROUTING) {
	my $lockref;
	#
	# When using routing instead of bridging, we have to clean
	# up the dhcp defaults file for the list of interfaces. 
	#
	if (TBScriptLock("dhcpd", 0, 900, \$lockref) != TBSCRIPTLOCK_OKAY()) {
	    print STDERR "Could not get the dhcpd lock after a long time!\n";
	    return -1;
	}
	reconfigDHCP();
	TBScriptUnlock($lockref);
    }

    # dhcp
    push(@rules,
	 "-D FORWARD -o $bridge -m pkttype ".
	 "--pkt-type broadcast ".
	 "-m physdev --physdev-in $vif --physdev-is-bridged ".
	 "--physdev-out $outer_controlif -j DROP");

    # See above. 
    if ($VIFROUTING) {
	push(@rules,
	     "-D FORWARD -i $vif -s $vnode_ip ".
	     "-m mac --mac-source $vnode_mac -j $OUTGOING_CHAIN");
	push(@rules,
	     "-D FORWARD -o $vif -d $vnode_ip -j $INCOMING_CHAIN");
	push(@rules,
	     "-D INPUT -i $vif -s $vnode_ip ".
	     "-m mac --mac-source $vnode_mac -j $OUTGOING_CHAIN");
	push(@rules,
	     "-D OUTPUT -o $vif -j ACCEPT");
	
    }
    else {
	push(@rules,
	     "-D FORWARD -m physdev --physdev-is-bridged ".
	     "--physdev-in $vif -s $vnode_ip -j $OUTGOING_CHAIN");
	if ($ipaliases ne "") {
	    foreach my $alias (split(",", $ipaliases)) {
		push(@rules,
		     "-D FORWARD -m physdev --physdev-is-bridged ".
		     "--physdev-in $vif -s $alias -j $OUTGOING_CHAIN");
	    }
	}
	push(@rules,
	     "-D FORWARD -m physdev --physdev-is-bridged ".
	     "--physdev-out $vif -j $INCOMING_CHAIN");
	push(@rules,
	     "-D INPUT -s $vnode_ip -j $OUTGOING_CHAIN");
	push(@rules,
	     "-D OUTPUT -d $vnode_ip -j ACCEPT");
    }

    # tmcc
    # Reroute tmcd calls to the proxy on the physical host
    push(@rules,
	 "-t nat -D PREROUTING -j DNAT -p tcp ".
	 "--dport $TMCD_PORT -d $boss_ip -s $vnode_ip ".
	 "--to-destination $host_ip:$local_tmcd_port");
    push(@rules,
	 "-t nat -D PREROUTING -j DNAT -p udp ".
	 "--dport $TMCD_PORT -d $boss_ip -s $vnode_ip ".
	 "--to-destination $host_ip:$local_tmcd_port");

    # Apply the rules
    if (DoIPtablesNoFail(@rules) != 0) {
	print STDERR "WARNING: could not remove iptables rules\n";
    }

    if (-e "/var/run/tmccproxy-$vnode_id.pid") {
	my $pid = `cat /var/run/tmccproxy-$vnode_id.pid`;
	chomp($pid);
	mysystem2("/bin/kill $pid");
    }

    @rules = ();

    if (!SHAREDHOST()) {
	push(@rules,
	     "-t nat -D POSTROUTING -j SNAT ".
	     "--to-source $host_ip -s $vnode_ip -d $fs_ip,$fs_jailip ".
	     "-o $bridge");
    }

    #
    # Remove rpcbind port restrictions
    #
    if (isRoutable($vnode_ip) && !$elabinelab) {
	push(@rules,
	     "-D $INCOMING_CHAIN -s $network/$cnet_mask -p tcp ".
	     "  --dport 111 -j ACCEPT");
	push(@rules,
	     "-D $INCOMING_CHAIN -s $network/$cnet_mask -p udp  ".
	     "  --dport 111 -j ACCEPT");
	push(@rules,
	     "-D $INCOMING_CHAIN -s $jail_network/$jail_netmask -p tcp ".
	     "  --dport 111 -j ACCEPT");
	push(@rules,
	     "-D $INCOMING_CHAIN -s $jail_network/$jail_netmask -p udp ".
	     "  --dport 111 -j ACCEPT");
	push(@rules,
	     "-D $INCOMING_CHAIN ".
	     "  -p tcp --dport 111 -j DROP");
	push(@rules,
	     "-D $INCOMING_CHAIN ".
	     "  -p udp --dport 111 -j DROP");
    }
    # 
    # Watch for a vnode with a public IP, no need to nat. 
    #
    if (isRoutable($vnode_ip)) {
	goto skipnat;
    }

    push(@rules,
	 "-t nat -D POSTROUTING -j ACCEPT ".
	 "-s $vnode_ip -d $jail_network/$jail_netmask");

    if (!REMOTEDED()) {
	push(@rules,
	     "-t nat -D POSTROUTING -j ACCEPT ".
	     "-s $vnode_ip -d $network/$cnet_mask");

	push(@rules,
	     "-t nat -D POSTROUTING -j ACCEPT ".
	     "-s $vnode_ip -d $boss_ip,$ops_ip");
	
	push(@rules,
	     "-t nat -D POSTROUTING -j ACCEPT ".
	     "-s $vnode_ip -d 224.0.0.0/4");
	
	push(@rules,
	     "-t nat -D POSTROUTING -j ACCEPT ".
	     "-s $vnode_ip -m icmp --protocol icmp --icmp-type 6/6");
    }

    push(@rules,
	 "-t nat -D POSTROUTING ".
	 "-s $vnode_ip -o $outer_controlif -j SNAT --to-source $host_ip");

  skipnat:
    # evproxy
    push(@rules,
	 "-t nat -D PREROUTING -j DNAT -p tcp ".
	 "--dport $EVPROXY_PORT -d $ops_ip -s $vnode_ip ".
	 "--to-destination $host_ip:$EVPROXY_PORT");

    # Apply the rules
    if (DoIPtablesNoFail(@rules) != 0) {
	print STDERR "WARNING: could not remove iptables rules\n";
    }
    return 0;
}

#
# Run the Xen vif-* script under our iptables lock.
#
sub Runscript($@)
{
    my ($vnode_ip, @args) = @_;
    my $rv = 0;

    #
    # Oh jeez, iptables is about the dumbest POS I've ever seen;
    # it fails if you run two at the same time. So we have to
    # serialize the calls. Rather then worry about each call, just
    # take a big lock here. 
    #
    TBDebugTimeStamp("$vnode_id emulab-cnet: grabbing iptables lock")
	if ($lockdebug);
    if (TBScriptLock("iptables", 0, 300) != TBSCRIPTLOCK_OKAY()) {
	print STDERR "Could not get the iptables lock after a long time!\n";
	return -1;
    }
    TBDebugTimeStamp("  got iptables lock")
	if ($lockdebug);

    #
    # First run the xen script to do the bridge interface. We do this
    # inside the lock since vif-bridge/vif-route do some iptables stuff.
    #
    # vif-bridge/vif-route has bugs that cause it to leave iptables
    # rules behind. If we put this stuff into the environment, they
    # will work properly.
    #
    $ENV{"ip"} = $vnode_ip;
    if ($VIFROUTING) {
	$ENV{"netdev"} = "xenbr0";
	$ENV{"gatewaydev"} = "xenbr0";
	mysystem2("/etc/xen/scripts/vif-route-emulab @args");
    }
    else {
	mysystem2("/etc/xen/scripts/vif-bridge @args");
    }
    $rv = $?;
    TBDebugTimeStamp("  releasing iptables lock")
	if ($lockdebug);
    TBScriptUnlock();

    return $rv;
}

my $rval = 0;
if (@ARGV) {
    my $op = $ARGV[0];

    TBDebugTimeStampsOn();
    TBDebugTimeStampWithDate("$vnode_ip emulab-cnet $op: called");

    # for online and add, run script at beginning
    if ($op ne "offline" && Runscript($vnode_ip, @ARGV)) {
	$rval = -1;
    }
    elsif ($op eq "online") {
	$rval = Online();
    }
    elsif ($op eq "offline") {
	$rval = Offline();
	# for offline, run script at the end
	if (!$rval) {
	    $rval = Runscript($vnode_ip, @ARGV);
	}
    }

    TBDebugTimeStampWithDate("$vnode_id: emulab-cnet $op: done, rval=$rval");
}
exit($rval);
