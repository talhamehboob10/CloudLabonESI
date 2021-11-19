#!/usr/bin/perl -w
#
# Copyright (c) 2008-2014, 2018 University of Utah and the Flux Group.
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
# Implements the libvnode API for OpenVZ support in Emulab.
#
package libvnode_openvz;
use Exporter;
@ISA    = "Exporter";
@EXPORT = qw( vz_init vz_setDebug
              vz_rootPreConfig vz_rootPreConfigNetwork vz_rootPostConfig 
              vz_vnodeCreate vz_vnodeDestroy vz_vnodeState 
              vz_vnodeBoot vz_vnodeHalt vz_vnodeReboot 
              vz_vnodePreConfig vz_vnodeUnmount vz_vnodeTearDown
              vz_vnodePreConfigControlNetwork vz_vnodePreConfigExpNetwork 
              vz_vnodeConfigResources vz_vnodeConfigDevices
              vz_vnodePostConfig vz_vnode vz_vnodeExec DOSNAP VGNAME
            );

%ops = ( 'init' => \&vz_init,
	 'setDebug' => \&vz_setDebug,
	 'rootPreConfig' => \&vz_rootPreConfig,
	 'rootPreConfigNetwork' => \&vz_rootPreConfigNetwork,
	 'rootPostConfig' => \&vz_rootPostConfig,
	 'vnodeCreate' => \&vz_vnodeCreate,
	 'vnodeDestroy' => \&vz_vnodeDestroy,
	 'vnodeTearDown' => \&vz_vnodeTearDown,
	 'vnodeState' => \&vz_vnodeState,
	 'vnodeBoot' => \&vz_vnodeBoot,
	 'vnodeHalt' => \&vz_vnodeHalt,
	 'vnodeUnmount' => \&vz_vnodeUnmount,
	 'vnodeReboot' => \&vz_vnodeReboot,
	 'vnodeExec' => \&vz_vnodeExec,
	 'vnodePreConfig' => \&vz_vnodePreConfig,
	 'vnodePreConfigControlNetwork' => \&vz_vnodePreConfigControlNetwork,
	 'vnodePreConfigExpNetwork' => \&vz_vnodePreConfigExpNetwork,
	 'vnodeConfigResources' => \&vz_vnodeConfigResources,
	 'vnodeConfigDevices' => \&vz_vnodeConfigDevices,
	 'vnodePostConfig' => \&vz_vnodePostConfig,
    );


use strict;
use English;
BEGIN { @AnyDBM_File::ISA = qw(DB_File GDBM_File NDBM_File) }
use AnyDBM_File;
use Data::Dumper;
use Socket;

# Pull in libvnode
require "/etc/emulab/paths.pm"; import emulabpaths;
use libgenvnode;
use libvnode;
use libutil;
use libtestbed;
use libsetup;

#
# Turn off line buffering on output
#
$| = 1;

#
# Load the OS independent support library. It will load the OS dependent
# library and initialize itself. 
# 

my $defaultImage = "emulab-default";
sub DefaultImage() { return $defaultImage; }

my $DOLVM        = 1;
my $DOSNAP       = 0;
my $DOLVMDEBUG   = 0;
my $LVMDEBUGOPTS = "-vvv -dddddd";

# So we can ask this from outside;
sub DOSNAP()	{ return $DOSNAP; }

my $DOVZDEBUG = 0;
my $VZDEBUGOPTS = "--verbose";

my $GLOBAL_CONF_LOCK = "vzconf";

sub VZSTAT_RUNNING() { return "running"; }
sub VZSTAT_STOPPED() { return "stopped"; }
sub VZSTAT_MOUNTED() { return "mounted"; }

my $VZCTL  = "/usr/sbin/vzctl";
my $VZLIST = "/usr/sbin/vzlist";
my $IFCONFIG = "/sbin/ifconfig";
my $ETHTOOL = "/sbin/ethtool";
my $NETSTAT  = "/bin/netstat";
my $ROUTE = "/sbin/route";
my $BRCTL = "/usr/sbin/brctl";
my $IPTABLES = "/sbin/iptables";
my $MODPROBE = "/sbin/modprobe";
my $RMMOD = "/sbin/rmmod";
my $VLANCONFIG = "/sbin/vconfig";
my $IP = "/sbin/ip";
my $TC = "/sbin/tc";

# where all our config files go
my $VMDIR = "/var/emulab/vms/vminfo";

my $VZRC   = "/etc/init.d/vz";
my $MKEXTRAFS = "/usr/local/etc/emulab/mkextrafs.pl";
my $BRIDGESETUP = "/usr/local/etc/emulab/xenbridge-setup";
# Extra space for images
my $EXTRAFS = "/vzscratch";
# LVM volume group name. 
my $VGNAME = "openvz";
# So we can ask this from outside;
sub VGNAME()  { return $VGNAME; }
sub EXTRAFS() { return $EXTRAFS; }
    
my $CTRLIPFILE = "/var/emulab/boot/myip";
my $IMQDB      = "/var/emulab/db/imqdb";
# The kernel will auto create up to 1024 IMQs
my $MAXIMQ     = 1024;

# IFBs
my $IFBDB      = "/var/emulab/db/ifbdb";
# Kernel auto-creates only two! Sheesh, why a fixed limit?
my $MAXIFB     = 512;

my $CONTROL_IFNUM  = 999;
my $CONTROL_IFDEV  = "eth${CONTROL_IFNUM}";
my $EXP_BASE_IFNUM = 0;

my $RTDB           = "/var/emulab/db/rtdb";
my $RTTABLES       = "/etc/iproute2/rt_tables";
# Temporary; later kernel version increases this.
my $MAXROUTETTABLE = 255;

# Track image usage for GC.
my $IMAGEDB           = "/var/emulab/db/imagedb";

my $debug = 0;

# XXX needs lifting up
my $JAILCTRLNET = "172.16.0.0";
my $JAILCTRLNETMASK = "255.240.0.0";

my $USE_NETEM   = 0;
my $USE_MACVLAN = 0;
# Use control network bridging for all containers. 
my $USE_CTRLBR  = 1;

# Switch to openvswitch
my $USE_OPENVSWITCH = 0;
my $OVSCTL   = "/usr/local/bin/ovs-vsctl";
my $OVSSTART = "/usr/local/share/openvswitch/scripts/ovs-ctl";

#
# If we are using a modern kernel, use netem instead of our own plr/delay
# qdiscs (which are no longer maintained as of 11/2011).
#
my ($kmaj,$kmin,$kpatch) = libvnode::getKernelVersion();
#print STDERR "Got Linux kernel version numbers $kmaj $kmin $kpatch\n";
if ($kmaj >= 2 && $kmin >= 6 && $kpatch >= 32) {
#    print STDERR "Using Linux netem instead of custom qdiscs.\n";
    $USE_NETEM = 1;
    # No longer using macvlan.
    if (0) {
        # print STDERR "Using Linux macvlan instead of OpenVZ veths.\n";
	$USE_MACVLAN = 1;
    }
}

#
# Helpers.
#
sub findControlNet();
sub makeIfaceMaps();
sub makeBridgeMaps();
sub findIface($);
sub findMac($);
sub editContainerConfigFile($$);
sub InitializeRouteTable();
sub AllocateRouteTable($);
sub LookupRouteTable($);
sub FreeRouteTable($);
sub vmexists($);
sub vmstatus($);
sub vmrunning($);
sub vmstopped($);
sub GClvm($);

#
# Bridge stuff
#
sub addbr($)
{
    my $br  = $_[0];
    my $cmd = ($USE_OPENVSWITCH ? "$OVSCTL add-br" : "$BRCTL addbr") . " $br";

    system($cmd);
}
sub delbr($)
{
    my $br  = $_[0];
    if ($USE_OPENVSWITCH) {
	mysystem2("$OVSCTL del-br $br");
    }
    else {
	mysystem2("$IFCONFIG $br down");
	mysystem2("$BRCTL delbr $br");
    }
}
sub addbrif($$)
{
    my $br  = $_[0];
    my $if  = $_[1];
    my $cmd = ($USE_OPENVSWITCH ? "$OVSCTL add-port" : "$BRCTL addif") .
	" $br $if";

    system($cmd);
}
sub delbrif($$)
{
    my $br  = $_[0];
    my $if  = $_[1];
    my $cmd = ($USE_OPENVSWITCH ? "$OVSCTL del-port" : "$BRCTL delif") .
	" $br $if";

    system($cmd);
}

#
# Initialize the lib (and don't use BEGIN so we can do reinit).
#
sub vz_init {
    makeIfaceMaps();
    if (!$USE_MACVLAN) {
	makeBridgeMaps();
    }

    #
    # Turn off LVM if already using a /vz mount.
    #
    if (-e "/vz/.nolvm" || -e "/vz.save/.nolvm" || -e "/.nolvm") {
	$DOLVM = 0;
	mysystem("/sbin/dmsetup remove_all");
    }

    #
    # Enable/disable LVM debug options.
    #
    if (-e "/vz/.lvmdebug" || -e "/vz.save/.lvmdebug" || -e "/.lvmdebug") {
	$DOLVMDEBUG = 1;
    }
    if (!$DOLVMDEBUG) {
	$LVMDEBUGOPTS = "";
    }

    #
    # Enable/disable VZ debug options.
    #
    if (-e "/vz/.vzdebug" || -e "/vz.save/.vzdebug" || -e "/.vzdebug") {
	$DOVZDEBUG = 1;
    }
    if (!$DOVZDEBUG) {
	$VZDEBUGOPTS = "";
    }

    return 0;
}

#
# Prepare the root context.  Run once at boot.
#
sub vz_rootPreConfig($;$)
{
    my ($bossip,$hostattributes) = @_;
    #
    # Only want to do this once, so use file in /var/run, which
    # is cleared at boot.
    #
    return 0
	if (-e "/var/run/openvz.ready");

    if ((my $locked = TBScriptLock($GLOBAL_CONF_LOCK,
				   TBSCRIPTLOCK_GLOBALWAIT(), 900)) 
	!= TBSCRIPTLOCK_OKAY()) {
	return 0
	    if ($locked == TBSCRIPTLOCK_IGNORE());
	print STDERR "Could not get the vzinit lock after a long time!\n";
	return -1;
    }
    # we must have the lock, so if we need to return right away, unlock
    if (-e "/var/run/openvz.ready") {
        TBScriptUnlock();
        return 0;
    }
    mysystem("$VZRC stop");
    
    # make sure filesystem is setup 
    if ($DOLVM) {
	# be ready to snapshot later on...
	open(FD, "gunzip -c /proc/config.gz |");
	my $snapshot = "n";
	while (my $line = <FD>) {
	    if ($line =~ /^CONFIG_DM_SNAPSHOT=([yYmM])/) {
		$snapshot = $1;
		last;
	    }
	}
	close(FD);
	if ($snapshot eq 'n' || $snapshot eq 'N') {
	    print STDERR "ERROR: this kernel does not support LVM snapshots!\n";
	    TBScriptUnlock();
	    return -1;
	}
	elsif ($snapshot eq 'm' || $snapshot eq 'M') {
	    mysystem("$MODPROBE dm-snapshot");
	}

	if (system("vgs $LVMDEBUGOPTS | grep -E -q '^[ ]+openvz.*\$'")) {
	    my $blockdevs = "";
	    my %devs = libvnode::findSpareDisks(1 * 1024);
	    my $totalSize = 0;
	    foreach my $dev (keys(%devs)) {
		if (defined($devs{$dev}{"size"})) {
		    $blockdevs .= " " . $devs{$dev}{"path"};
		    $totalSize += $devs{$dev}{"size"};
		}
		else {
		    foreach my $part (keys(%{$devs{$dev}})) {
			$blockdevs .= " " . $devs{$dev}{$part}{"path"};
			$totalSize += $devs{$dev}{$part}{"size"};
		    }
		}
	    }

	    if ($blockdevs eq '') {
		die "findSpareDisks found no disks, can't use LVM!\n";
	    }
		    
	    mysystem("pvcreate $LVMDEBUGOPTS $blockdevs");
	    mysystem("vgcreate $LVMDEBUGOPTS $VGNAME $blockdevs");
	}
	# make sure our volumes are active -- they seem to become inactive
	# across reboots
	mysystem("vgchange $LVMDEBUGOPTS -a y $VGNAME");

	#
	# If we reload the partition, the logical volumes will still
	# exist but /vz will be empty. We need to recreate /vz when
	# this happens.
	#
	# XXX eventually could move this into its own logical volume, but
	# we don't ever know how many images we'll have to store.
	#
	if (! -e "/vz/template") {
	    mysystem("rm -rf /vz/*")
		if (-e "/vz");
	    mysystem("mkdir /vz")
		if (! -e "/vz");
	    mysystem("cp -pR /vz.save/* /vz/");
	}
	if (createExtraFS($EXTRAFS, $VGNAME, "15G")) {
	    TBScriptUnlock();
	    return -1;
	}
    }
    else {
	#
	# We need to create a local filesystem.
	# First see if the "extra" filesystem has already been created,
	# Emulab often mounts it as /local for various purposes.
	#
	# about the funny quoting: don't ask... emacs perl mode foo.
	if (!system('grep -q '."'".'^/dev/.*/local.*\$'."'".' /etc/fstab')) {
	    # local filesystem already exists, just create a subdir
	    if (! -d "/local/vz") {
		mysystem("$VZRC stop");
		mysystem("mkdir /local/vz");
		mysystem("cp -pR /vz.save/* /local/vz/");
		mysystem("touch /local/vz/.nolvm");
	    }
	    if (-e "/vz") {
		mysystem("rm -rf /vz");
		mysystem("ln -s /local/vz /vz");
	    }
	}
	else {
	    # about the funny quoting: don't ask... emacs perl mode foo.
	    if (system('grep -q '."'".'^/dev/.*/vz.*\$'."'".' /etc/fstab')) {
		mysystem("$VZRC stop");
		mysystem("rm -rf /vz")
		    if (-e "/vz");
		mysystem("mkdir /vz");
		mysystem("$MKEXTRAFS -f /vz");
		mysystem("cp -pR /vz.save/* /vz/");
		mysystem("touch /vz/.nolvm");
	    }
	    if (system('mount | grep -q \'on /vz\'')) {
		mysystem("mount /vz");
	    }
	}
    }

    # We need to increase the size of the net.core.netdev_max_backlog 
    # sysctl var in the root context; not sure to what amount, or exactly 
    # why though.  Perhaps there is too much contention when handling enqueued
    # packets on the veths?
    mysystem("sysctl -w net.core.netdev_max_backlog=2048");

    # Turn off ipv6; some kind of leaking kernel thing.
    mysystem("sysctl -w net.ipv6.conf.all.disable_ipv6=1");
    mysystem("sysctl -w net.ipv6.conf.default.disable_ipv6=1");

    #
    # Ryan figured this one out. It was causing 75% packet loss on
    # gre tunnels. 
    #
    # According to Ryan: 'loose' mode just ensures that
    # the sender's IP is reachable by at least one interface, whereas
    # 'strict' mode requires that it be reachable via the interface
    # the packet was received on. This is why the ARP request from
    # the host was being dropped; the sending IP was only reachable
    # via veth999, not the internal greX interface where the request
    # was received.
    #
    mysystem("sysctl -w net.ipv4.conf.default.rp_filter=0");

    # make sure the initscript is going...
    if (system("$VZRC status 2&>1 > /dev/null")) {
	mysystem("$VZRC start");
    }

    # get rid of this simple container device support
    if (!system('lsmod | grep -q vznetdev')) {
	system("$RMMOD vznetdev");
    }

    if ($USE_MACVLAN) {
	#
	# If we build dummy shortbridge nets atop either a physical
	# device, or atop a dummy device, load these!
	#
	mysystem("$MODPROBE macvlan");
	mysystem("$MODPROBE dummy");
    }
    else {
	# this is what we need for veths
	mysystem("$MODPROBE vzethdev");
    }

    # For tunnels
    if ($USE_OPENVSWITCH) {
	mysystem("$MODPROBE openvswitch");
    }
    else {
	mysystem("$MODPROBE ip_gre");
    }

    # For VLANs
    mysystem("$MODPROBE 8021q");

    # we need this stuff for traffic shaping -- only root context can
    # modprobe, for now.
    if (!$USE_NETEM) {
	mysystem("$MODPROBE sch_plr");
	mysystem("$MODPROBE sch_delay");
    }
    else {
	mysystem("$MODPROBE sch_netem");
    }
    mysystem("$MODPROBE sch_htb");

    # make sure our network hooks are called
    if (system('grep -q -e EXTERNAL_SCRIPT /etc/vz/vznet.conf')) {
	if (! -e '/etc/vz/vznet.conf') {
	    open(FD,">/etc/vz/vznet.conf") 
		or die "could not open /etc/vz/vznet.conf: $!";
	    print FD "#!/bin/bash\n";
	    print FD "\n";
	    close(FD);
	}
	mysystem("echo 'EXTERNAL_SCRIPT=\"/usr/local/etc/emulab/vznetinit-elab.sh\"' >> /etc/vz/vznet.conf");
    }

    #
    # XXX all this network config stuff should be done in PreConfigNetwork,
    # but we can't rmmod the IMQ module to change the config, so no point.
    #
    mysystem("$MODPROBE imq");
    mysystem("$MODPROBE ipt_IMQ");

    # Switching to IFBs (eventually).
    mysystem("$MODPROBE ifb numifbs=$MAXIFB");

    # start up open vswitch stuff.
    if ($USE_OPENVSWITCH) {
	mysystem("$OVSSTART --delete-bridges start");
    }

    #
    # Need to create a control network bridge to accomodate routable
    # control network addresses.
    #
    if (! -e "/sys/class/net/vzbr0") {
	mysystem("$BRIDGESETUP " .
		 ($USE_OPENVSWITCH ? "-o" : "") . " -b vzbr0");
    }

    # Create a DB to manage IMQs
    my %MDB;
    if (!dbmopen(%MDB, $IMQDB, 0660)) {
	print STDERR "*** Could not create $IMQDB\n";
	TBScriptUnlock();
	return -1;
    }
    for (my $i = 0; $i < $MAXIMQ; $i++) {
	$MDB{"$i"} = ""
	    if (!defined($MDB{"$i"}));
    }
    dbmclose(%MDB);

    # Create a DB to manage IFBs
    if (!dbmopen(%MDB, $IFBDB, 0660)) {
	print STDERR "*** Could not create $IFBDB\n";
	TBScriptUnlock();
	return -1;
    }
    for (my $i = 0; $i < $MAXIFB; $i++) {
	$MDB{"$i"} = ""
	    if (!defined($MDB{"$i"}));
    }
    dbmclose(%MDB);

    if (InitializeRouteTables()) {
	print STDERR "*** Could not initialize routing table DB\n";
	TBScriptUnlock();
	return -1;
    }
    #
    # Need these to avoid overflowing the NAT tables.
    #
    mysystem("sysctl -w ".
	     "  net.netfilter.nf_conntrack_generic_timeout=120");
    mysystem("sysctl -w ".
	     "  net.netfilter.nf_conntrack_tcp_timeout_established=54000");
    mysystem("sysctl -w ".
	     "  net.netfilter.nf_conntrack_max=131071");
    mysystem("echo 16384 > /sys/module/nf_conntrack/parameters/hashsize");

    mysystem("touch /var/run/openvz.ready");
    TBScriptUnlock();
    return 0;
}

#
# Prepare any network stuff in the root context on a global basis.  Run once
# at boot, or at reconfigure.  For openvz, this consists of creating bridges
# and configuring them as necessary.
#
# NOTE: This function must clean up any side effects if it fails partway.
#
sub vz_rootPreConfigNetwork {
    my ($vnode_id, undef, $vnconfig, $private) = @_;
    
    if (TBScriptLock($GLOBAL_CONF_LOCK, 0, 900) != TBSCRIPTLOCK_OKAY()) {
	print STDERR "Could not get the vznetwork lock after a long time!\n";
	return -1;
    }

    # Do this again after lock.
    makeIfaceMaps();
    if (!$USE_MACVLAN) {
	makeBridgeMaps();
    }

    my $vmid;
    if ($vnode_id =~ /^[-\w]+\-(\d+)$/) {
	$vmid = $1;
    }
    else {
	fatal("vz_rootPreConfigNetwork: bad vnode_id $vnode_id!");
    }
    
    my @node_ifs = @{ $vnconfig->{'ifconfig'} };
    my @node_lds = @{ $vnconfig->{'ldconfig'} };

    # setup forwarding on ctrl net -- NOTE that iptables setup to do NAT
    # actually happens per vnode now.
    my ($iface,$ip,$netmask,$maskbits,$network,$mac) = findControlNet();
    mysystem("echo 1 > /proc/sys/net/ipv4/conf/$iface/forwarding");
    # XXX only needed for fake mac hack, which should go away someday
    mysystem("echo 1 > /proc/sys/net/ipv4/conf/$iface/proxy_arp");

    #
    # If we're using veths, figure out what bridges we need to make:
    # we need a bridge for each physical iface that is a multiplex pipe,
    # and one for each VTAG given PMAC=none (i.e., host containing both sides
    # of a link, or an entire lan).
    #
    my %brs = ();
    my $prefix = "br.";
    {
	foreach my $ifc (@node_ifs) {
	    next if (!$ifc->{ISVIRT});

	    my $brname;
	    my $physdev;

	    if ($ifc->{ITYPE} eq "loop") {
		my $vtag  = $ifc->{VTAG};

		#
		# No physical device. Its a loopback (trivial) link/lan
		# All we need is a common bridge to put the veth ifaces into.
		#
		$physdev = $brname = "${prefix}$vtag";
		$brs{$brname}{ENCAP} = 0;
		$brs{$brname}{SHORT} = 0;
	    }
	    elsif ($ifc->{ITYPE} eq "vlan") {
		my $iface = $ifc->{IFACE};
		my $vtag  = $ifc->{VTAG};
		my $vdev  = "${iface}.${vtag}";

		if (! -d "/sys/class/net/$vdev") {
		    mysystem2("$VLANCONFIG set_name_type DEV_PLUS_VID_NO_PAD");
		    mysystem2("$VLANCONFIG add $iface $vtag");
		    goto bad
			if ($?);
		    mysystem2("$VLANCONFIG set_name_type VLAN_PLUS_VID_NO_PAD");

		    #
		    # We do not want the vlan device to have the same
		    # mac as the physical device, since that will confuse
		    # findif later.
		    #
		    my $bmac = fixupMac(GenFakeMac());
		    mysystem2("$IP link set $vdev address $bmac");
		    goto bad
			if ($?);
		    
		    mysystem2("$IFCONFIG $vdev up");
		    mysystem2("$ETHTOOL -K $vdev tso off gso off");
		    makeIfaceMaps();

		    # Another thing that seems to screw up, causing the ciscos
		    # to drop packets with an undersize error.
		    mysystem2("$ETHTOOL -K $iface txvlan off");
		    
		    #
		    # We leave this behind in case of failure and at
		    # teardown since it is possibly a shared device, and
		    # it is difficult to tell if another vnode is using it.
		    # Leaving it behind is harmless, I think.
		    #
		}
		# Temporary, to get existing devices after upgrade.
		mysystem2("$ETHTOOL -K $vdev tso off gso off");

		$physdev =  $vdev;
		$brname  = "${prefix}${vdev}";
		$brs{$brname}{ENCAP} = 1;
		$brs{$brname}{SHORT} = 0;
		$brs{$brname}{PHYSDEV} = $vdev;
		$brs{$brname}{IFC}   = $ifc;
	    }
	    elsif ($ifc->{PMAC} eq "none") {
		$physdev = $brname = "${prefix}" . $ifc->{VTAG};
		# if no PMAC, we don't need encap on the bridge
		$brs{$brname}{ENCAP} = 0;
		# count members below so we can figure out if this is a shorty
		$brs{$brname}{MEMBERS} = 0;
	    }
	    else {
		my $iface = findIface($ifc->{PMAC});
		$physdev = $iface;
		$brname  = "${prefix}$iface";
		$brs{$brname}{ENCAP} = 1;
		$brs{$brname}{SHORT} = 0;
		$brs{$brname}{IFC}   = $ifc;
		$brs{$brname}{PHYSDEV} = $iface;
	    }
	    # Stash for later phase.
	    $ifc->{'PHYSDEV'} = $physdev
		if (defined($physdev));
	    $ifc->{'BRIDGE'} = $brname
		if (defined($brname));
	}
    }

    #
    # Make bridges and add phys ifaces.
    #
    # Or, in the macvlan case, create a dummy device if there is no
    # underlying physdev to "host" the macvlan.
    #
    foreach my $k (keys(%brs)) {
	if (!$USE_MACVLAN) {
	    #
	    # This bridge might be shared with other containers, so difficult
	    # to delete. This really only matters on shared nodes though, where
	    # bridges and vlans could stack up forever (or just a long time).
	    #
	    if (! -d "/sys/class/net/$k/bridge") {
		addbr($k);
		goto bad
		    if ($?);

		#
		# Bad feature of bridges; they take on the lowest numbered
		# mac of the added interfaces (and it changes as interfaces
		# are added and removed!). But the main point is that we end
		# up with a bridge that has the same mac as a physical device
		# and that screws up findIface(). But if we "assign" a mac
		# address, it does not change and we know it will be unique.
		#
		my $bmac = fixupMac(GenFakeMac());
		mysystem2("$IP link set $k address $bmac");
		goto bad
		    if ($?);
	    }
	    # record bridge used
	    $private->{'physbridges'}->{$k} = $k;

	    # repetitions of this should not hurt anything
	    mysystem2("$IFCONFIG $k 0 up");
	}

	if (exists($brs{$k}{PHYSDEV})) {
	    if (!$USE_MACVLAN) {
		my $physdev = $brs{$k}{PHYSDEV};
		my $ifc     = $brs{$k}{IFC};

		#
		# This interface should not be a member of another bridge.
		# If it is, it is an error.
		#
		# Continuing the comment above, this bridge and this interface
		# might be shared with other containers, so we cannot remove it
		# unless it is the only one left. 
		#
		my $obr = findBridge($physdev);
		if (defined($obr) && $obr ne $k) {
		    # Avoid removing the device from the bridge if it
		    # is in the correct bridge. 
		    delbrif($obr, $physdev);
		    goto bad
			if ($?);
		    $obr = undef;
		}
		if (!defined($obr)) {
		    addbrif($k, $physdev);
		    goto bad
			if ($?);
		    # rebuild hashes
		    makeBridgeMaps();
		}
	    }
	}
	elsif ($USE_MACVLAN
	       && ! -d "/sys/class/net/$k") {
	    # need to create a dummy device to "host" the macvlan ports
	    mysystem2("$IP link add name $k type dummy");
	    goto bad
		if ($?);
	    # record dummy created
	    $private->{'dummys'}->{$k} = $k;
	}
    }

    #
    # IMQs are a little tricky. Once they are mapped into a container,
    # we never get to see them again until the container is fully
    # destroyed or until we explicitly unmap them from the container.
    # We also want to hang onto them so we do not get into a situation
    # where we stopped to take a disk image, and then cannot start
    # again cause we ran out of resources (shared nodes). So, we have
    # to look for IMQs (and IFBs) that are already allocated to the
    # container. See the allocate routines, which make use of the tag.
    #
    if (@node_lds) {
	my $ifbs = AllocateIFBs($vmid, \@node_lds, $private);
	my $imqs = AllocateIMQs($vmid, \@node_lds, $private);

	goto bad
	    if (! (defined($ifbs) && defined($imqs)));

	foreach my $ldc (@node_lds) {
	    my $tag = "$vnode_id:" . $ldc->{'LINKNAME'};
	    my $ifb = pop(@$ifbs);
	    $private->{'ifbs'}->{$ifb} = $tag;
	    
	    # Stash for later.
	    $ldc->{'IFB'} = $ifb;

	    if ($ldc->{"TYPE"} eq 'duplex') {
		my $imq = pop(@$imqs);
		$private->{'imqs'}->{$imq} = $tag;
	    }
	}
    }
    TBScriptUnlock();
    return 0;

  bad:
    #
    # Unwind anything we did. 
    #
    # Remove interfaces we *added* to bridges.
    if (exists($private->{'bridgeifaces'})) {
	foreach my $brname (keys(%{ $private->{'bridgeifaces'} })) {
	    my $ref = $private->{'bridgeifaces'}->{$brname};

	    foreach my $iface (keys(%{ $ref })) {
		delbrif($brname, $iface);
		delete($ref->{$brname}->{$iface})
		    if (! $?);
	    }
	}
    }
    # Delete bridges we *created* 
    if (exists($private->{'bridges'})) {
	foreach my $brname (keys(%{ $private->{'bridges'} })) {
	    mysystem2("$IFCONFIG $brname down");
	    delbr($brname);		
	    delete($private->{'bridges'}->{$brname})
		if (! $?);
	}
    }
    if ($USE_MACVLAN) {
	# Delete the dummy macvlan thingies we created.
	if (exists($private->{'dummys'})) {
	    # We can delete this cause we have the lock and no one else got
	    # a chance to use the dummy.
	    foreach my $brname (keys(%{ $private->{'dummys'} })) {
		mysystem2("$IP link del dev $brname");
		delete($private->{'dummys'}->{$brname})
		    if ($?);
	    }
	}
    }
    # Delete the ip links
    if (exists($private->{'iplinks'})) {
	foreach my $iface (keys(%{ $private->{'iplinks'} })) {
            if (-e "/sys/class/net/$iface") {
	        mysystem2("$IP link del dev $iface");
	        goto badbad
		  if ($?);
            }
	    delete($private->{'iplinks'}->{$iface});
	}
    }
    # Undo the IMQs
    ReleaseIMQs($vmid, $private)
	if (exists($private->{'imqs'}));
		    
    # Release the IFBs
    ReleaseIFBs($vmid, $private)
	if (exists($private->{'ifbs'}));

  badbad:
    TBScriptUnlock();
    return -1;
}

sub vz_rootPostConfig {
    # Locking, if this ever does something?
    return 0;
}

#
# Create an OpenVZ container to host a vnode.  Should be called only once.
#
sub vz_vnodeCreate {
    my ($vnode_id, undef, $vnconfig, $private) = @_;
    my $image = $vnconfig->{'image'};
    my $raref = $vnconfig->{'reloadinfo'};
    my $inreload = 0;

    my $vmid;
    if ($vnode_id =~ /^[-\w]+\-(\d+)$/) {
	$vmid = $1;
    }
    else {
	fatal("vz_vnodeCreate: bad vnode_id $vnode_id!");
    }

    if (!defined($image) || $image eq '') {
	$image = $defaultImage;
    }
    my $imagelockname = "vzimage.$image";

    #
    # This LVM size stuff is needs to go away.
    #
    my $rootSize;
    my $snapSize;

    if ($DOLVM) {
	my $MIN_ROOT_LVM_VOL_SIZE = 2 * 2048;
	my $MAX_ROOT_LVM_VOL_SIZE = 8 * 1024;
	my $MIN_SNAPSHOT_VOL_SIZE = 512;
	my $MAX_SNAPSHOT_VOL_SIZE = 8 * 1024;

	# XXX size our snapshots to assume 50 VMs on the node.
	my $MAX_NUM_VMS = 50;

	# figure out how big our volumes should be based on the volume
	# group size
	my $vgSize;
	$rootSize = $MAX_ROOT_LVM_VOL_SIZE;
	$snapSize = $MAX_SNAPSHOT_VOL_SIZE;

	open (VFD,"vgdisplay openvz |")
	    or die "popen(vgdisplay openvz): $!";
	while (my $line = <VFD>) {
	    chomp($line);
	    if ($line =~ /^\s+VG Size\s+(\d+[\.\d]*)\s+(\w+)/) {
		# convert to MB
		if ($2 eq "GB") {    $vgSize = $1 * 1024; }
		elsif ($2 eq "TB") { $vgSize = $1 * 1024 * 1024; }
		elsif ($2 eq "PB") { $vgSize = $1 * 1024 * 1024 * 1024; }
		elsif ($2 eq "MB") { $vgSize = $1 + 0; }
		elsif ($2 eq "KB") { $vgSize = $1 / 1024; }
		last;
	    }
	}
	close(VFD);

	if (defined($vgSize)) {
	    $vgSize /= $MAX_NUM_VMS;

	    if ($vgSize < $MIN_ROOT_LVM_VOL_SIZE) {
		$rootSize = int($MIN_ROOT_LVM_VOL_SIZE);
	    }
	    elsif ($vgSize < $MAX_ROOT_LVM_VOL_SIZE) {
		$rootSize = int($vgSize);
	    }
	    if ($vgSize < $MIN_SNAPSHOT_VOL_SIZE) {
		$snapSize = int($MIN_SNAPSHOT_VOL_SIZE);
	    }
	    elsif ($vgSize < $MAX_SNAPSHOT_VOL_SIZE) {
		$snapSize = int($vgSize);
	    }
	}

	#
	# Lastly, allow the server to override the snapshot size,
	# although we enforce the minimum, and do not allow it to be
	# greater then the underlying size since that would break things.
	#
	if (exists($vnconfig->{'config'}->{'VDSIZE'})) {
	    #
	    # Value in MB.
	    #
	    my $vdsize = $vnconfig->{'config'}->{'VDSIZE'};

	    $snapSize = $vdsize
		if ($vdsize > $MIN_SNAPSHOT_VOL_SIZE &&
		    $vdsize <= $rootSize);
	}

	print STDERR "Using LVM with root size $rootSize MB, ".
	    "snapshot size $snapSize MB.\n";
    }

    # Plain old serial lock.
    if (TBScriptLock($imagelockname, 0, 1800)
	!= TBSCRIPTLOCK_OKAY()) {
	fatal("Could not get $imagelockname lock after a long time!");
    }

    #
    # We name the image lvms with a prefix so we know they are image
    # LVMs. Hard to tell otherwise.
    #
    my $imagelvmname = "image+" . $image;
    my $imagelvmpath = lvmVolumePath($imagelvmname);
    my $vnodelvmpath = lvmVolumePath($vnode_id);

    if ($image eq $defaultImage) {
	#
	# The default image might change, if the file in the template
	# directory is changed. 
	#
	my $imagepath  = "/vz/template/cache/${image}.tar.gz";

	my (undef,undef,undef,undef,undef,undef,undef,undef,undef,
	    $mtime,undef,undef,undef) = stat($imagepath);

	#
	# createImageDisk() knows to throw the old one away if it changed.
	# The only reason to go through this (instead of direct untar) is 
	# so that we are consistent with image downloads in the else clause.
	#
	my $reloadargs = {"IMAGEMTIME" => $mtime};

	if (createImageDisk($image, $vnode_id,
			    $reloadargs, $imagepath, $rootSize)) {
	    TBScriptUnlock();
	    fatal("vz_vnodeCreate: ".
		  "cannot create logical volume for $image");
	}
    }
    elsif (defined($raref)) {
	#
	# reloadinfo can be a list now, but we do no support that here.
	#
	$inreload = 1;
	
	# Tell stated via tmcd
	libutil::setState("RELOADSETUP");

	#
	# Immediately drop into RELOADING before calling createImageDisk as
	# that is the place where any image will be downloaded from the image
	# server and we want that download to take place in the longer timeout
	# period afforded by the RELOADING state.
	#
	sleep(1);
	libutil::setState("RELOADING");

	if (createImageDisk($image, $vnode_id, $raref, undef, $rootSize)) {
	    TBScriptUnlock();
	    fatal("vz_vnodeCreate: ".
		  "cannot create logical volume for $image");
	}
    }

    #
    # Now we can create the vnode disk from the base disk.
    #
    if ($DOSNAP) {
	#
	# So, we drop the lock so multiple snapshots can happen in
	# parallel, but that introduces a small race; the base can
	# get deleted before the lvcreate runs and the base has a
	# new child that prevents it from getting garbage collected.
	#
	TBScriptUnlock();
	
	#
	# Take a snapshot of this image's logical device
	#
	# As above, a partition reload will make it appear that the
	# container does not exist, when in fact the lvm really does
	# and we want to reuse it, not create another one. 
	#
	if (system("lvdisplay $vnodelvmpath >& /dev/null")) {
	    mysystem("lvcreate $LVMDEBUGOPTS ".
		     "  -s -L${snapSize}M -n $vnode_id $imagelvmpath");
	}
    }
    elsif (system("lvdisplay $vnodelvmpath >& /dev/null")) {
	#
	# Need to create a new disk for the container. But lets see
	# if we have a disk cached. We still have the imagelock at
	# this point.
	#
	if (my (@files) = glob("/dev/$VGNAME/_C_${image}_*")) {
	    #
	    # Grab the first file and rename it. It becomes ours.
	    # Then drop the lock.
	    #
	    my $file = $files[0];
	    mysystem("lvrename $file $vnodelvmpath");
	    TBScriptUnlock();
	}
	else {
	    #
	    # So, we really should not drop the lock here, cause if
	    # another vnode comes along using the same image, but the
	    # image was updated, it will get deleted right out from
	    # underneath us. But if we hold the lock, we serialize
	    # every create using this image, and the tar unpack takes
	    # a while. 
	    #
	    TBScriptUnlock();
	    
	    mysystem("lvcreate $LVMDEBUGOPTS ".
		     "  -L${rootSize}M -n $vnode_id $VGNAME");
	    mysystem("mkfs -t ext3 $vnodelvmpath");
	    mysystem("mkdir -p /mnt/$vnode_id")
		if (! -e "/mnt/$vnode_id");
	    mysystem("mount $vnodelvmpath /mnt/$vnode_id");
	    mysystem("mkdir -p /mnt/$vnode_id/root /mnt/$vnode_id/private");
	    TBDebugTimeStampWithDate("untaring to /mnt/$vnode_id");
	    mysystem("cd /mnt/$image/private; ".
		     "tar -b 64 -cf - . | ".
		     "tar -b 64 -xf - -C /mnt/$vnode_id/private");
	    TBDebugTimeStampWithDate("untar done");
	}
    }
    mysystem("mkdir -p /mnt/$vnode_id")
	if (! -e "/mnt/$vnode_id");
    mysystem("mount $vnodelvmpath /mnt/$vnode_id")
	if (! -e "/mnt/$vnode_id/private");

    my $createArg = "--private /mnt/$vnode_id/private" . 
	    " --root /mnt/$vnode_id/root --nofs yes";

    # For GC after teardown.
    $private->{'baseimage'} = $image;

    if ($inreload) {
	# Tell stated via tmcd
	libutil::setState("RELOADDONE");
	sleep(4);
	libutil::setState("SHUTDOWN");
    }

    # build the container
    mysystem("$VZCTL $VZDEBUGOPTS create $vmid --ostemplate $image $createArg");

    # make sure bootvnodes actually starts things up on boot, not openvz
    mysystem("$VZCTL $VZDEBUGOPTS set $vmid --onboot no --name $vnode_id --save");

    # set some resource limits:
    my %deflimits = ( "diskinodes" => "unlimited:unlimited",
		      "diskspace" => "unlimited:unlimited",
		      "numproc" => "unlimited:unlimited",
		      "numtcpsock" => "unlimited:unlimited",
		      "numothersock" => "unlimited:unlimited",
		      "vmguarpages" => "unlimited:unlimited",
		      "kmemsize" => "unlimited:unlimited",
		      "tcpsndbuf" => "unlimited:unlimited",
		      "tcprcvbuf" => "unlimited:unlimited",
		      "othersockbuf" => "unlimited:unlimited",
		      "dgramrcvbuf" => "unlimited:unlimited",
		      "oomguarpages" => "unlimited:unlimited",
		      "lockedpages" => "unlimited:unlimited",
		      "privvmpages" => "unlimited:unlimited",
		      "shmpages" => "unlimited:unlimited",
		      "numfile" => "unlimited:unlimited",
		      "numflock" => "unlimited:unlimited",
		      "numpty" => "unlimited:unlimited",
		      "numsiginfo" => "unlimited:unlimited",
		      #"dcachesize" => "unlimited:unlimited",
		      "numiptent" => "unlimited:unlimited",
		      "physpages" => "unlimited:unlimited",
		      #"cpuunits" => "unlimited",
		      "cpulimit" => "0",
		      "cpus" => "unlimited",
		      "meminfo" => "none",
	);
    my $savestr = "";
    foreach my $k (keys(%deflimits)) {
	$savestr .= " --$k $deflimits{$k}";
    }
    mysystem("$VZCTL $VZDEBUGOPTS set $vmid $savestr --save");

    # XXX give them cap_net_admin inside containers... necessary to set
    # txqueuelen on devices inside the container.  This may have other
    # undesireable side effects, but need it for now.
    mysystem("$VZCTL $VZDEBUGOPTS set $vmid --capability net_admin:on --save");

    #
    # Make some directories in case the guest doesn't have them -- the elab
    # mount and umount vz scripts need them to be there!
    #
    my $privroot = "/vz/private/$vnode_id";
    if ($DOLVM) {
	$privroot = "/mnt/$vnode_id/private";
    }
    mysystem("mkdir -p $privroot/var/emulab/boot/")
	if (! -e "$privroot/var/emulab/boot/");

    # NOTE: we can't ever umount the LVM logical device because vzlist can't
    # return status appropriately if a VM's root and private areas don't
    # exist.
    if (0 && $DOLVM) {
	mysystem("umount /mnt/$vnode_id");
    }

    return $vmid;
}

#
# Remove the transient state, but not the disk.
#
sub vz_vnodeTearDown {
    my ($vnode_id, $vmid, $vnconfig, $private) = @_;

    # Lots of shared resources 
    if (TBScriptLock($GLOBAL_CONF_LOCK, 0, 900) != TBSCRIPTLOCK_OKAY()) {
	print STDERR "Could not get the global vz lock after a long time!\n";
	return -1;
    }

    #
    # Unwind anything we did.
    #
    # Remove interfaces we *added* to bridges.
    if (exists($private->{'bridgeifaces'})) {
	foreach my $brname (keys(%{ $private->{'bridgeifaces'} })) {
	    my $ref = $private->{'bridgeifaces'}->{$brname};
	    
	    foreach my $iface (keys(%{ $ref })) {
		delbrif($brname, $iface);
		goto badbad
		    if ($?);
		delete($ref->{$brname}->{$iface});
	    }
	    delete($private->{'bridgeifaces'}->{$brname});
	}
    }
    # Delete bridges we created which have no current members.
    if (exists($private->{'bridges'})) {
	foreach my $brname (keys(%{ $private->{'bridges'} })) {
	    mysystem2("$IFCONFIG $brname down");	    
	    mysystem2("$BRCTL delbr $brname");
	    delete($private->{'bridges'}->{$brname});
	}
    }
    # Delete the tunnel devices.
    if (exists($private->{'tunnels'})) {
	foreach my $iface (keys(%{ $private->{'tunnels'} })) {
	    mysystem2("/sbin/ip tunnel del $iface");
	    goto badbad
		if ($?);
	    delete($private->{'tunnels'}->{$iface});
	}
    }
    # Delete the ip rules.
    if (exists($private->{'iprules'})) {
	foreach my $iface (keys(%{ $private->{'iprules'} })) {
	    mysystem2("$IP rule del iif $iface");
	    goto badbad
		if ($?);
	    delete($private->{'iprules'}->{$iface});
	}
    }
    # Delete the ip links
    if (exists($private->{'iplinks'})) {
	foreach my $iface (keys(%{ $private->{'iplinks'} })) {
            if (-e "/sys/class/net/$iface") {
	        mysystem2("$IP link del dev $iface");
	        goto badbad
		  if ($?);
            }
	    delete($private->{'iplinks'}->{$iface});
	}
    }
    # Delete the control veth from the bridge (USE_OPENVSWITCH=1).
    if ($USE_OPENVSWITCH && exists($private->{'controlveth'})) {
	my $cnet_veth = $private->{'controlveth'};
	
	mysystem2("$OVSCTL -- --if-exists del-port vzbr0 $cnet_veth");
	delete($private->{'controlveth'});
    }

    #
    # A word about these two. David sez that it is impossible to garbage
    # collect these dummy devices cause once they move into a container,
    # they are no longer listed with 'ip link show', and so it looks like
    # they are no longer in use. So, we will leak these, but we do not get
    # many of them, so it will be okay. 
    #
    if (exists($private->{'dummys'}) ||
	exists($private->{'dummyifaces'})) {
	# See comment above.
    }
  badbad:
    TBScriptUnlock();
    return 0;
}

sub vz_vnodeDestroy {
    my ($vnode_id, $vmid, $vnconfig, $private) = @_;

    # Always do this since there might be state left over. 
    return -1
	if (vz_vnodeTearDown($vnode_id, $vmid, $vnconfig, $private));

    if (TBScriptLock($GLOBAL_CONF_LOCK, 0, 900) != TBSCRIPTLOCK_OKAY()) {
	print STDERR "Could not get global vz lock after a long time!\n";
	return -1;
    }

    # Release the route tables. We keep these till now to prevent running 
    # out during a reboot. This route tble stuff is bogus anyway.
    if (exists($private->{'routetables'})) {
	foreach my $token (keys(%{ $private->{'routetables'} })) {
	    if (FreeRouteTable($token) < 0) {
		TBScriptUnlock();
		return -1;
	    }
	    delete($private->{'routetables'}->{$token});
	}
    }
    #
    # We keep the IMQs until complete destruction since the container
    # references them inside, and so they are not usable by anyone else
    # until the container is fully destroyed. We do this cause we do
    # want to get into a situation where we stopped a container to do
    # something like take a disk snapshot, and then not be able to
    # restart it cause there are no more resources available (as might
    # happen on a shared node). 
    #
    ReleaseIMQs($vmid, $private)
	if (exists($private->{'imqs'}));

    #
    # Ditto the IFBs, although they are not mapped into the container,
    # we just do not want to run out of them.
    #
    ReleaseIFBs($vmid, $private)
	if (exists($private->{'ifbs'}));

    if ($DOLVM) {
	my $vnodelvmpath = lvmVolumePath($vnode_id);
	
	mysystem2("umount /mnt/$vnode_id");
	if (system("lvdisplay $vnodelvmpath >& /dev/null") == 0) {
	    my $origin;

	    #
	    # Grab the origin before deletion, since the origin might have
	    # been renamed from the original base image name. If not doing
	    # snapshots, then it does not change (not really an origin).
	    #
	    if ($DOSNAP) {
		$origin = lvmOrigin($vnode_id);
	    }
	    mysystem2("lvremove $LVMDEBUGOPTS -f $vnodelvmpath");
	    if ($?) {
		TBScriptUnlock();
		return -1;
	    }
	    if ($DOSNAP) {
		my $baseimagelvmname = "image+" . $private->{'baseimage'};
		
		#
		# See if we can delete the image now, but only if its
		# a renamed origin; these will never be used again
		# so delete now if we can (no children). 
		#
		if (defined($origin) &&
		    $origin ne "" &&
		    $origin ne $baseimagelvmname &&
		    !lvmHasChildren($origin)) {
		    mysystem2("lvremove $LVMDEBUGOPTS -f /dev/$VGNAME/$origin");
		}
	    }
	}
    }
    TBScriptUnlock();
    mysystem2("$VZCTL $VZDEBUGOPTS destroy $vmid");
    return -1
	if ($?);

    return 0;
}

sub vz_vnodeExec {
    my ($vnode_id, $vmid, $vnconfig, $private, $command) = @_;

    # Note: do not use mysystem here since that exits.
    system("$VZCTL exec2 $vnode_id $command");

    return $?;
}

sub vz_vnodeState {
    my ($vnode_id, $vmid, $vnconfig, $private) = @_;

    # Sometimes if the underlying filesystems are not mounted, we might get 
    # no status even though the vnode has been created (currently, this will
    # only happen with LVM)... since the openvz utils seem to need to see the
    # vnode filesystem in order to work properly, which is sensible).
    if ($DOLVM) {
	my $lvmpath = lvmVolumePath($vnode_id);
	
	if (-e "/etc/vz/conf/$vmid.conf" && -e $lvmpath 
	    && ! -e "/mnt/$vnode_id/private") {
	    print "Trying to mount LVM logical device for vnode $vnode_id: ";
	    mysystem("mount $lvmpath /mnt/$vnode_id");
	    print "done.\n";
	}
    }

    my $status = vmstatus($vmid);
    return VNODE_STATUS_UNKNOWN()
	if (!defined($status));

    if ($status eq 'running') {
	return VNODE_STATUS_RUNNING();
    }
    elsif ($status eq 'stopped') {
	return VNODE_STATUS_STOPPED();
    }
    elsif ($status eq 'mounted') {
	return VNODE_STATUS_MOUNTED();
    }

    return VNODE_STATUS_UNKNOWN();
}

sub vz_vnodeBoot {
    my ($vnode_id, $vmid, $vnconfig, $private) = @_;

    if ($DOLVM) {
	my $lvmpath = lvmVolumePath($vnode_id);
	
	system("mount $lvmpath /mnt/$vnode_id");
    }

    mysystem("$VZCTL $VZDEBUGOPTS start $vnode_id");

    return 0;
}

sub vz_vnodeHalt {
    my ($vnode_id, $vmid, $vnconfig, $private) = @_;

    mysystem("$VZCTL $VZDEBUGOPTS stop $vnode_id");
    return 0;
}

sub vz_vnodeUnmount {
    my ($vnode_id, $vmid, $vnconfig, $private) = @_;

    #
    # This signal stuff is bogus, but vzctl calls the mount and unmount
    # scripts with the signals inherited from mkvnode, which is not correct.
    #
    local $SIG{TERM} = 'DEFAULT';
    
    mysystem("$VZCTL $VZDEBUGOPTS umount $vnode_id");

    return 0;
}

sub vz_vnodeMount {
    my ($vnode_id, $vmid, $vnconfig, $private) = @_;

    #
    # This signal stuff is bogus, but vzctl calls the mount and unmount
    # scripts with the signals inherited from mkvnode, which is not correct.
    #
    local $SIG{TERM} = 'DEFAULT';

    mysystem("$VZCTL $VZDEBUGOPTS mount $vnode_id");

    return 0;
}

sub vz_vnodeReboot {
    my ($vnode_id, $vmid, $vnconfig, $private) = @_;

    mysystem("$VZCTL $VZDEBUGOPTS restart $vnode_id");

    return 0;
}

sub vz_vnodePreConfig {
    my ($vnode_id, $vmid, $vnconfig, $private, $callback) = @_;

    # Make sure we're mounted so that vzlist and friends work; see NOTE about
    # mounting LVM logical devices above.
    if ($DOLVM) {
	my $lvmpath = lvmVolumePath($vnode_id);

	system("mount $lvmpath /mnt/$vnode_id");
    }

    #
    # Look and see if this node already has imq devs mapped into it.
    #
    my %devs = ();
    
    if (exists($private->{'imqs'})) {
	foreach my $i (keys(%{ $private->{'imqs'} })) {
	    $devs{"imq$i"} = 1;
	}
    }
    my $existing = `sed -n -r -e 's/NETDEV="(.*)"/\1/p' /etc/vz/conf/$vmid.conf`;
    chomp($existing);
    foreach my $dev (split(/,/,$existing)) {
	if (!($dev =~ /^imq/)) {
	    next;
	}

	if (!exists($devs{$dev})) {
	    # needs deleting
	    $devs{$dev} = 0;
	}
	else {
	    # was already mapped, leave alone
	    delete($devs{$dev});
	}
    }

    foreach my $dev (keys(%devs)) {
        if (! -d "/sys/class/net/$dev") {
	    mysystem("$IP link add name $dev type imq");
        }

	if ($devs{$dev} == 1) {
	    mysystem("$VZCTL $VZDEBUGOPTS set $vnode_id --netdev_add $dev --save");
	}
	elsif ($devs{$dev} == 0) {
	    mysystem("$VZCTL $VZDEBUGOPTS set $vnode_id --netdev_del $dev --save");
	}
    }
    #
    # Make sure container is mounted before calling the callback.
    #
    my $status = vmstatus($vmid);
    my $didmount = 0;
    if (!$DOLVM && ($status ne 'running' && $status ne 'mounted')) {
	vz_vnodeMount($vnode_id, $vmid, $vnconfig, $private);
	$didmount = 1;
    }
    my $privroot = "/vz/private/$vmid";
    if ($DOLVM) {
	$privroot = "/mnt/$vnode_id/private";
    }
    # Serialize the callback. Sucks. iptables.
    if (TBScriptLock($GLOBAL_CONF_LOCK, 0, 900) != TBSCRIPTLOCK_OKAY()) {
	print STDERR "Could not get callback lock after a long time!\n";
	return -1;
    }
    my $ret = &$callback("$privroot");
    TBScriptUnlock();
    if (!$DOLVM && $didmount) {
	vz_vnodeUnmount($vnode_id, $vmid, $vnconfig, $private);
    }
    return $ret;
}

#
# Preconfigure the control net interface; special case of vnodeConfigInterfaces.
#
sub vz_vnodePreConfigControlNetwork {
    my ($vnode_id, $vmid, $vnconfig, $private,
	$ip,$mask,$mac,$gw, $vname,$longdomain,$shortdomain,$bossip) = @_;

    # setup iptables on real ctrl net
    my ($ciface,$cip,$cnetmask,$cmaskbits,$cnetwork,$cmac) = findControlNet();

    my @ipa = map { int($_); } split(/\./,$ip);
    my @maska = map { int($_); } split(/\./,$mask);
    my @neta = ($ipa[0] & $maska[0],$ipa[1] & $maska[1],
		$ipa[2] & $maska[2],$ipa[3] & $maska[3]);
    my $net = join('.',@neta);

    # Now allow routable control network.
    my $isroutable = isRoutable($ip);

    print STDERR "jail network: $net/$mask\n";

    #
    # Have to serialize iptables access. Silly locking problem in the kernel.
    #
    if (TBScriptLock($GLOBAL_CONF_LOCK, 0, 900) != TBSCRIPTLOCK_OKAY()) {
	print STDERR "PreConfigControlNetwork: ".
	    "Could not get the lock after a long time!\n";
	return -1;
    }
    # 
    # First check and see if it looks like we've put the rules in place 
    # already. If the SNAT rule is there and it matches our control
    # net, probably we're good. Otherwise, setup NAT so that vnodes
    # can get to the outside world.
    # 
    if (!$isroutable && system('iptables -t nat -L POSTROUTING' . 
			       ' | grep -q -e \'^SNAT.* ' . $net . '\'')) {
	if (system("$MODPROBE ip_nat") ||
            # 
            # If the source is from the vnode, headed to the local control 
            # net, don't do any NAT; just let it through.
            # 
	    system("$IPTABLES -t nat -A POSTROUTING" . 
		   " -s $net/$mask" . 
		   " -d $cnetwork/$cnetmask -j ACCEPT") ||
	    #
	    # Same as above, but specific rule for boss which might be on
	    # a distinct segment, as it is in Utah. 
	    #
	    system("$IPTABLES -t nat -A POSTROUTING" . 
		   " -s $net/$mask" . 
		   " -d $bossip -j ACCEPT") ||
            # 
            # Then if the source is from one vnode to another vnode, also 
            # let that through without NAT'ing it. 
            # 
	    system("$IPTABLES -t nat -A POSTROUTING" . 
		   " -s $net/$mask" . 
		   " -d $net/$mask -j ACCEPT") ||
            # 
            # Otherwise, setup NAT so that traffic leaving the vnode on its 
            # control net IP, that has been routed out the phys host's
            # control net iface, is NAT'd to the phys host's control
            # net IP, using SNAT.
            # 
	    system("$IPTABLES -t nat -A POSTROUTING" . 
		   " -s $net/$mask" . 
		   " -o $ciface -j SNAT --to-source $cip")) {
	    print STDERR "Could not PreConfigControlNetwork iptables\n";
	    TBScriptUnlock();
	    return -1;
	}
    }
    #
    # Route the jail network over the control network so that we do
    # not go through the router. 
    #
    if (!$isroutable && system("$NETSTAT -r | grep -q $net")) {
	mysystem2("$ROUTE add -net $net netmask $mask dev $ciface");
	if ($?) {
	    TBScriptUnlock();
	    return -1;
	}
    }
    TBScriptUnlock();

    # Make sure we're mounted so that vzlist and friends work; see NOTE about
    # mounting LVM logical devices above.
    if ($DOLVM) {
	system("mount /dev/$VGNAME/$vnode_id /mnt/$vnode_id");
    }

    my $privroot = "/vz/private/$vmid";
    if ($DOLVM) {
	$privroot = "/mnt/$vnode_id/private";
    }

    # add the control net iface
    my $cnet_veth = "veth${vmid}.${CONTROL_IFNUM}";
    my ($cnet_mac,$ext_vethmac) = build_fake_macs($mac);
    if (!defined($cnet_mac)) {
	print STDERR "Could not construct veth/eth macs\n";
	return -1;
    }
    ($cnet_mac,$ext_vethmac) = (macAddSep($cnet_mac),macAddSep($ext_vethmac));
    if ($USE_CTRLBR || $isroutable) {
	# Must do this so that the bridge does not take on the
	# address. I do not know why it does this, but according
	# to the xen equivalent code, this is what ya do. 
	$ext_vethmac = "fe:ff:ff:ff:ff:ff";
    }
    # Record the name of the control network veth so it can be removed
    # from the bridge (USE_OPENVSWITCH=1).
    $private->{"controlveth"} = $cnet_veth;

    #
    # we have to hack the VEID.conf file BEFORE calling --netif_add ... --save
    # below so that when the custom script is run against our changes, it does
    # the right thing!
    #
    my %lines = ( 'ELABCTRLIP' => '"' . $ip . '"',
		  'ELABCTRLDEV' => '"' . $cnet_veth . '"' );

    #
    # When the ip is routable, we need to use a bridge. Must tell
    # vznetinit script to do this differently. 
    #
    if ($USE_CTRLBR || $isroutable) {
	$lines{"ELABCTRLBR"} = '"vzbr0"';
    }
    editContainerConfigFile($vmid,\%lines);

    # note that we don't assign a mac to the CT0 part of the veth pair -- 
    # openvz does that automagically
    mysystem("$VZCTL $VZDEBUGOPTS set $vnode_id" . 
	     " --netif_add ${CONTROL_IFDEV},$cnet_mac,$cnet_veth,$ext_vethmac --save");

    #
    # Make sure container is mounted
    #
    my $status = vmstatus($vmid);
    my $didmount = 0;
    if (!$DOLVM && ($status ne 'running' && $status ne 'mounted')) {
	vz_vnodeMount($vnode_id, $vmid, $vnconfig, $private);
	$didmount = 1;
    }

    #
    # Setup lo
    #
    open(FD,">$privroot/etc/sysconfig/network-scripts/ifcfg-lo") 
	or die "vz_vnodePreConfigControlNetwork: could not open ifcfg-lo for $vnode_id: $!";
    print FD "DEVICE=lo\n";
    print FD "IPADDR=127.0.0.1\n";
    print FD "NETMASK=255.0.0.0\n";
    print FD "NETWORK=127.0.0.0\n";
    print FD "BROADCAST=127.255.255.255\n";
    print FD "ONBOOT=yes\n";
    print FD "NAME=loopback\n";
    close(FD);

    # remove any regular control net junk
    unlink("$privroot/etc/sysconfig/network-scripts/ifcfg-eth99");

    #
    # setup the control net iface in the FS ...
    #
    open(FD,">$privroot/etc/sysconfig/network-scripts/ifcfg-${CONTROL_IFDEV}") 
	or die "vz_vnodePreConfigControlNetwork: could not open ifcfg-${CONTROL_IFDEV} for $vnode_id: $!";
    print FD "DEVICE=${CONTROL_IFDEV}\n";
    print FD "IPADDR=$ip\n";
    print FD "NETMASK=$mask\n";
    
    my @ip;
    my @mask;
    if ($ip =~ /^(\d+)\.(\d+)\.(\d+)\.(\d+)$/) {
	@ip = ($1,$2,$3,$4);
    }
    if ($mask =~ /^(\d+)\.(\d+)\.(\d+)\.(\d+)$/) {
	@mask = ($1+0,$2+0,$3+0,$4+0);
    }
    my $network = ($ip[0] & $mask[0]) . "." . ($ip[1] & $mask[1]) . 
	"." . ($ip[2] & $mask[2]) . "." . ($ip[3] & $mask[3]);
    my $bcast = ($ip[0] | (~$mask[0] & 0xff)) . 
	"." . ($ip[1] | (~$mask[1] & 0xff)) . 
	"." . ($ip[2] | (~$mask[2] & 0xff)) . 
	"." . ($ip[3] | (~$mask[3] & 0xff));
    # grab number of network bits too, sigh
    my $maskbits = 0;
    foreach my $m (@mask) {
	for (my $i = 0; $i < 8; ++$i) {
	    $maskbits += (0x01 & ($m >> $i));
	}
    }

    print FD "NETWORK=$network\n";
    print FD "BROADCAST=$bcast\n";
    print FD "ONBOOT=yes\n";
    close(FD);

    # setup routes:
    my ($ctrliface,$ctrlip,$ctrlmask,$ctrlmaskbits,$ctrlnet,$ctrlmac) 
	= findControlNet();
    open(FD,">$privroot/etc/sysconfig/network-scripts/route-${CONTROL_IFDEV}") 
	or die "vz_vnodePreConfigControlNetwork: could not open route-${CONTROL_IFDEV} for $vnode_id: $!";
    #
    # HUGE NOTE: we *have* to use the /<bits> form, not the /<netmask> form
    # for now, since our iproute version is old.
    #
    print FD "$ctrlnet/$ctrlmaskbits dev ${CONTROL_IFDEV}\n";
    if ($isroutable) {
	print FD "$JAILCTRLNET/$JAILCTRLNETMASK dev ${CONTROL_IFDEV}\n";
	# Switch to real router.
	$gw = `cat /var/emulab/boot/routerip`;
	chomp($gw);
	print FD "0.0.0.0/0 via $gw\n";
    }
    else {
	print FD "0.0.0.0/0 via $ctrlip\n";
    }
    close(FD);

    #
    # ... and make sure it gets brought up on boot:
    # XXX: yes, this would blow away anybody's changes, but don't care now.
    #
    open(FD,">$privroot/etc/sysconfig/network") 
	or die "vz_vnodePreConfigControlNetwork: could not open sysconfig/networkfor $vnode_id: $!";
    print FD "NETWORKING=yes\n";
    print FD "HOSTNAME=$vname.$longdomain\n";
    print FD "DOMAIN=$longdomain\n";
    print FD "NOZEROCONF=yes\n";
    close(FD);
    mysystem("$VZCTL $VZDEBUGOPTS set $vnode_id --hostname $vname.$longdomain --save");

    #
    # dhclient-exit-hooks normally writes this stuff on linux, so we'd better
    # do it here.
    #
    my $mybootdir = "$privroot/var/emulab/boot/";

    # and before the dhclient stuff, do this first to tell bootsetup that we 
    # are a GENVNODE...
    open(FD,">$mybootdir/vmname") 
	or die "vz_vnodePreConfigControlNetwork: could not open vmname for $vnode_id: $!";
    print FD "$vnode_id\n";
    close(FD);
    # ...and that our event server is the proxy in the phys host
    open(FD,">$mybootdir/localevserver") 
	or die "vz_vnodePreConfigControlNetwork: could not open localevserver for $vnode_id: $!";
    print FD "$ctrlip\n";
    close(FD);

    open(FD,">$mybootdir/myip") 
	or die "vz_vnodePreConfigControlNetwork: could not open myip for $vnode_id: $!";
    print FD "$ip\n";
    close(FD);
    open(FD,">$mybootdir/mynetmask") 
	or die "vz_vnodePreConfigControlNetwork: could not open mynetmask for $vnode_id: $!";
    print FD "$mask\n";
    close(FD);
    open(FD,">$mybootdir/routerip") 
	or die "vz_vnodePreConfigControlNetwork: could not open routerip for $vnode_id: $!";
    print FD "$gw\n";
    close(FD);
    open(FD,">$mybootdir/controlif") 
	or die "vz_vnodePreConfigControlNetwork: could not open controlif for $vnode_id: $!";
    print FD "${CONTROL_IFDEV}\n";
    close(FD);
    open(FD,">$mybootdir/realname") 
	or die "vz_vnodePreConfigControlNetwork: could not open realname for $vnode_id: $!";
    print FD "$vnode_id\n";
    close(FD);
    open(FD,">$mybootdir/bossip") 
	or die "vz_vnodePreConfigControlNetwork: could not open bossip for $vnode_id: $!";
    print FD "$bossip\n";
    close(FD);

    #
    # Let's not hang ourselves before we start
    #
    open(FD,">$privroot/etc/resolv.conf") 
	or die "vz_vnodePreConfigControlNetwork: could not open resolv.conf for $vnode_id: $!";

    print FD "nameserver $bossip\n";
    print FD "search $shortdomain\n";
    close(FD);

    #
    # XXX Ugh, this is icky, but it avoids a second mount in PreConfig().
    # Want to copy all the tmcd config info from root context into the 
    # container.
    #
    mysystem("cp -R /var/emulab/boot/tmcc.$vnode_id $mybootdir/");

    if (!$DOLVM && $didmount) {
	vz_vnodeUnmount($vnode_id, $vmid, $vnconfig, $private);
    }

    return 0;
}

#
# Preconfigures experimental interfaces in the vnode before its first boot.
#
sub vz_vnodePreConfigExpNetwork {
    my ($vnode_id, $vmid, $vnconfig, $private) = @_;
    my $ifs     = $vnconfig->{'ifconfig'};
    my $lds     = $vnconfig->{'ldconfig'};
    my $tunnels = $vnconfig->{'tunconfig'};
    
    # Make sure we're mounted so that vzlist and friends work; see NOTE about
    # mounting LVM logical devices above.
    if ($DOLVM) {
	system("mount /dev/$VGNAME/$vnode_id /mnt/$vnode_id");
    }

    my $basetable;
    my $elabifs = "";
    my $elabroutes = "";
    my %netif_strs = ();
    foreach my $ifc (@$ifs) {
	next if (!$ifc->{ISVIRT});

	my $br       = $ifc->{"BRIDGE"};
	my $physdev  = $ifc->{"PHYSDEV"};
	my $ldinfo;

	#
	# Find associated delay info
	#
	foreach my $ld (@$lds) {
	    if ($ld->{"IFACE"} eq $ifc->{"MAC"}) {
		$ldinfo = $ld;
	    }
	}

	#
	# The server gives us random/unique macs. Well, as unique as can
	# be expected, but that should be fine (this mostly matters on
	# shared nodes where duplicate macs would be bad). 
	#
	# One wrinkle; in the second case below, where there is a root context
	# device and a container context device, we need to distinguish
	# them, so set a bit on the root context side (since we want the
	# container mac to be what the user has been told elsewhere).
	#
	# XXX The server has also set the local admin flag (0x02), which
	# is required, but we set it anyway.
	#
	my $veth;
	#
	# A note about the inner device name; we used to use eth${vlan}
	# but then people started wanting multiple networks on the same
	# vlan via the shared network mechanism, and so we have to look
	# for that and use a different name. Its a special case; in the
	# normal case I want the names to be pretty.
	#
	my $eth = "eth" . $ifc->{VTAG};
	if (exists($netif_strs{$eth})) {
	    $eth = "${eth}." . $ifc->{ID};
	}
	my ($ethmac,$vethmac) = build_fake_macs($ifc->{VMAC});
	if (!defined($vethmac)) {
	    print STDERR "Could not construct veth/eth macs\n";
	    return -1;
	}
	($ethmac,$vethmac) = (macAddSep($ethmac),macAddSep($vethmac));
	print "DEBUG ethmac=$ethmac, vethmac=$vethmac\n";

	if ($USE_MACVLAN) {
	    #
	    # Add the macvlan device atop the dummy devices created earlier,
	    # or atop the physical or vlan device.
	    #
	    # BUG here. interface might be left behind from a previous
	    # failure. Broke during the tutorial.
	    #
	    $veth = "mv$vmid.$ifc->{ID}";
	    if (-e "/sys/class/net/$veth") {
	        mysystem2("$IP link del dev $veth");
	    }
	    mysystem("$IP link add link $physdev name $veth ".
		     "  address $ethmac type macvlan mode bridge ");
	    $private->{'iplinks'}->{$veth} = $physdev;
	    
	    #
	    # When the bridge is a dummy, record that we added an interface
	    # to it, so that we can garbage collect the dummy devices later.
	    #
	    if ($physdev eq $br) {
		$private->{'dummyifaces'}->{$br}->{$veth} = $br;
	    }
	    mysystem("$VZCTL $VZDEBUGOPTS set $vnode_id --netdev_add ".
		     "  $veth --save");
	}
	else {
	    #
	    # Add to ELABIFS for addition to conf file (for runtime config by 
	    # external custom script)
	    #
	    $veth = "veth$vmid.$ifc->{ID}";

	    #
	    # Generate a script to install the shaping, once the veth device
	    # is created. The nice thing is that since the caps are attached
	    # to a veth, we do not to clean up anything; it all goes away
	    # when the veth is destroyed by the container exit.
	    #
	    my $script = "";
	    if (defined($ldinfo)) {
		$script = "$VMDIR/$vnode_id/enet-$vethmac";		
		my $ifb = $ldinfo->{"IFB"};
	    
		CreateCapScript($vmid, $script, $ldinfo, $veth, "ifb$ifb")
		    == 0 or return -1;
	    }
	    if ($elabifs ne '') {
		$elabifs .= ';';
	    }
	    $elabifs .= "$veth,$br,$script";

	    #
	    # Save for later calling, since we need to hack the 
	    # config file BEFORE calling --netif_add so the custom postconfig 
	    # script does the right thing.
	    # Also store up the current set of netifs so we can delete any that
	    # might have been old!
	    #
	    $netif_strs{$eth} = "$eth,$ethmac,$veth,$vethmac";
	}
    }

    if (values(%{ $tunnels })) {
	#
	# gres and route tables are a global resource.
	#
	if (TBScriptLock($GLOBAL_CONF_LOCK, 0, 900) != TBSCRIPTLOCK_OKAY()) {
	    print STDERR "Could not get the global lock after a long time!\n";
	    return -1;
	}
	my %key2gre = ();
	my $maxgre  = 0;
	
	if (! $USE_OPENVSWITCH) {
	    $basetable = AllocateRouteTable("VZ$vmid");
	    if (!defined($basetable)) {
		print STDERR "Could not allocate a routing table!\n";
		TBScriptUnlock();
		return -1;
	    }
	    $private->{'routetables'}->{"VZ$vmid"} = $basetable;

	    #
	    # Get current gre list.
	    #
	    if (! open(IP, "/sbin/ip tunnel show|")) {
		print STDERR "Could not start /sbin/ip\n";
		TBScriptUnlock();
		return -1;
	    }
	    my $table   = $vmid + 100;

	    while (<IP>) {
		if ($_ =~ /^(gre\d*):.*key\s*([\d\.]*)/) {
		    $key2gre{$2} = $1;
		    if ($1 =~ /^gre(\d*)$/) {
			$maxgre = $1
			    if ($1 > $maxgre);
		    }
		}
		elsif ($_ =~ /^(gre\d*):.*remote\s*([\d\.]*)\s*local\s*([\d\.]*)/) {
		    #
		    # This is just a temp fixup; delete tunnels with no key
		    # since we no longer use non-keyed tunnels, and cause it
		    # will cause the kernel to throw an error in the tunnel add
		    # below. 
		    #
		    mysystem2("/sbin/ip tunnel del $1");
		    if ($?) {
			TBScriptUnlock();
			return -1;
		    }
		}
	    }
	    if (!close(IP)) {
		print STDERR "Could not get tunnel list\n";
		TBScriptUnlock();
		return -1;
	    }
	}

	foreach my $tunnel (values(%{ $tunnels })) {
	    my $style = $tunnel->{"tunnel_style"};
	    
	    next
		if (! ($style eq "gre" || $style eq "egre"));

	    my $name     = $tunnel->{"tunnel_lan"};
	    my $srchost  = $tunnel->{"tunnel_srcip"};
	    my $dsthost  = $tunnel->{"tunnel_dstip"};
	    my $inetip   = $tunnel->{"tunnel_ip"};
	    my $peerip   = $tunnel->{"tunnel_peerip"};
	    my $mask     = $tunnel->{"tunnel_ipmask"};
	    my $mac      = $tunnel->{"tunnel_mac"};
	    my $unit     = $tunnel->{"tunnel_unit"};
	    my $grekey   = $tunnel->{"tunnel_tag"};
	    my $gre;
	    my $br;

	    if ($style eq "egre" && !$USE_OPENVSWITCH) {
		print STDERR "Cannot create egre tunnel without OVS\n";
		TBScriptUnlock();
		return -1;
	    }
	    if ($style eq "gre" && $USE_OPENVSWITCH) {
		print STDERR "Cannot create gre tunnel with OVS\n";
		TBScriptUnlock();
		return -1;
	    }

	    if (!$USE_OPENVSWITCH) {
		if (exists($key2gre{$grekey})) {
		    $gre = $key2gre{$grekey};
		}
		else {
		    $grekey = inet_ntoa(pack("N", $grekey));
		    $gre    = "gre" . ++$maxgre;
		    mysystem2("/sbin/ip tunnel add $gre mode gre ".
			      "local $srchost remote $dsthost ttl 64 ".
			      (1 ? "key $grekey" : ""));
		    if ($?) {
			TBScriptUnlock();
			return -1;
		    }
		    mysystem2("/sbin/ifconfig $gre 0 up");
		    if ($?) {
			TBScriptUnlock();
			return -1;
		    }
		    # Must do this else routing lookup fails. 
		    mysystem2("echo 1 > /proc/sys/net/ipv4/conf/$gre/forwarding");
		    if ($?) {
			TBScriptUnlock();
			return -1;
		    }
		    $key2gre{$grekey} = $gre;
		    # Record gre creation.
		    $private->{'tunnels'}->{$gre} = $gre;
		}
		#
		# All packets arriving from gre devices will use the same table.
		# The route will be a network route to the root context device.
		# The route cannot be inserted until later, since the root 
		# context device does not exists until the VM is running.
		# See the route stuff in vznetinit-elab.sh.
		#
		mysystem2("/sbin/ip rule add unicast iif $gre table $basetable");
		if ($?) {
		    TBScriptUnlock();
		    return -1;
		}
		$private->{'iprules'}->{$gre} = $gre;
	    }
	    else {
		#
		# Need to create an openvswitch bridge and gre tunnel inside.
		# We can then put the veth device into the bridge. 
		#
		# These are the devices outside the container. 
		$gre = "gre$vmid.$unit";
		$br  = "br$vmid.$unit";
		mysystem2("$OVSCTL add-br $br");
		if ($?) {
		    TBScriptUnlock();
		    return -1;
		}
		# Record bridge created. 
		$private->{'bridges'}->{$br} = $br;

		mysystem2("$OVSCTL add-port $br $gre -- set interface $gre ".
			  "  type=gre options:remote_ip=$dsthost " .
			  "           options:local_ip=$srchost " .
			  (1 ? "      options:key=$grekey" : ""));
		if ($?) {
		    TBScriptUnlock();
		    return -1;
		}
		# Record iface added to bridge 
		$private->{'bridgeifaces'}->{$br}->{$gre} = $br;
	    }
	    
	    # device name outside the container
	    my $veth = "veth$vmid.tun$unit";
	    # device name inside the container
	    my $eth  = "gre$unit";
	    # mac inside the container.
	    my $ethmac = fixupMac($mac);
	    
	    $netif_strs{$eth} = "$eth,$ethmac,$veth";
	    if ($elabifs ne '') {
		$elabifs .= ';';
	    }
	    # Leave bridge blank; see vznetinit-elab.sh. It does stuff.
	    $elabifs .= "$veth,,";

	    if ($USE_OPENVSWITCH) {
		# Unless we are using openvswitch; gre can go into a bridge.
		$elabifs .= "$br";
		# Record for removal, even though this happens in vznetinit.
		$private->{'bridgeifaces'}->{$br}->{$veth} = $br;
	    }

	    # Route.
	    if (!$USE_OPENVSWITCH) {
		if ($elabroutes ne '') {
		    $elabroutes .= ';';
		}
		$elabroutes .= "$veth,$inetip,$gre";

		#
		# We need a routing table for each tunnel in the other
		# direction.  This makes sure that all packets coming out
		# of the root context device (leaving the VM) got shoved
		# into the real gre device.  Need to use a default route so
		# all packets are matched, which is why we need a table per
		# tunnel.
		#
		my $routetable = AllocateRouteTable($veth);
		if (!defined($routetable)) {
		    print STDERR "No free route tables for $veth\n";
		    TBScriptUnlock();
		    return -1;
		}
		$private->{'routetables'}->{"$veth"} = $routetable;

		#
		# Convenient, is that even though the root context device does
		# not exist, we can insert the ip *rule* for it that directs
		# the traffic through the iproute inserted below.
		#
		mysystem2("/sbin/ip rule add unicast iif $veth table $routetable");
		if ($?) {
		    TBScriptUnlock();
		    return -1;
		}
		$private->{'iprules'}->{$veth} = $veth;

		mysystem2("/sbin/ip route replace ".
			  "  default dev $gre table $routetable");
		if ($?) {
		    TBScriptUnlock();
		    return -1;
		}
	    }
	}
	TBScriptUnlock();
    }

    #
    # Wait until end to do a single edit for all ifs, since they're all 
    # smashed into a single config file var
    #
    my %lines = ( 'ELABIFS'    => '"' . $elabifs . '"',
		  'ELABROUTES' => '"' . $elabroutes . '"');
    if (defined($basetable)) {
	$lines{'ROUTETABLE'} = '"' . $basetable . '"';
    }
    editContainerConfigFile($vmid,\%lines);

    #
    # Ok, add (and delete stale) veth devices!
    # Grab current ones first.
    #
    my @current = ();
    open(CF,"/etc/vz/conf/$vmid.conf") 
	or die "could not open etc/vz/conf/$vmid.conf for read: $!";
    my @lines = grep { $_ =~ /^NETIF/ } <CF>;
    close(CF);
    if (@lines) {
	# always take the last one :-)
	my $netifs = $lines[@lines-1];
	if ($netifs =~ /NETIF="(.*)"/) {
	    $netifs = $1;
	}
	my @nifs = split(/;/,$netifs);
	foreach my $nif (@nifs) {
	    if ($nif =~ /ifname=([\w\d\-]+)/) {
		# don't delete the control net device!
		next if ($1 eq $CONTROL_IFDEV);

		push @current, $1;
	    }
	}
    }

    # delete
    foreach my $eth (@current) {
	if (!exists($netif_strs{$eth})) {
	    mysystem("$VZCTL $VZDEBUGOPTS set $vnode_id --netif_del $eth --save");
	}
    }
    # add/modify
    foreach my $eth (keys(%netif_strs)) {
	mysystem("$VZCTL $VZDEBUGOPTS set $vnode_id --netif_add $netif_strs{$eth} --save");
    }

    return 0;
}

sub vz_vnodeConfigResources {
    return 0;
}

sub vz_vnodeConfigDevices {
    return 0;
}

sub vz_vnodePostConfig {
    return 0;
}

sub vz_setDebug($) {
    $debug = shift;
    libvnode::setDebug($debug);
}

##
## Bunch of helper functions.
##

#
# Edit an openvz container config file -- add a little emulab header and some
# vars to signal customization.  After that, change/add any lines indicated by
# the key/val pairs in the hash (sensible since the config file is intended to
# be slurped up by shells or something).
#
sub editContainerConfigFile($$) {
    my ($vmid,$edlines) = @_;

    my $conffile = "/etc/vz/conf/$vmid.conf";

    open(FD,"$conffile") 
	or die "could not open $conffile: $!";
    my @lines = <FD>;
    close(FD);

    if (!grep(/^ELABCUSTOM/,@lines)) {
	$lines[@lines] = "\n";
	$lines[@lines] = "#\n";
	$lines[@lines] = "# Emulab hooks\n";
	$lines[@lines] = "#\n";
	$lines[@lines] = "CONFIG_CUSTOMIZED=\"yes\"\n";
	$lines[@lines] = "ELABCUSTOM=\"yes\"\n";
    }

    # make a copy so we can delete keys
    my %dedlines = ();
    foreach my $k (keys(%$edlines)) {
	$dedlines{$k} = $edlines->{$k};
    }

    for (my $i = 0; $i < @lines; ++$i) {
	# note that if the value is a string, the quotes have to be sent
	# in from caller!
	if ($lines[$i] =~ /^([^#][^=]+)=(.*)$/) {
	    my $k = $1;
	    if (exists($dedlines{$k}) && $2 ne $dedlines{$k}) {
		$lines[$i] = "$k=$dedlines{$k}\n";
		delete $dedlines{$k};
	    }
	}
    }
    foreach my $k (keys(%dedlines)) {
	$lines[@lines] = "$k=$dedlines{$k}\n";
    }

    open(FD,">$conffile") 
	or die "could not open $conffile for writing: $!";
    foreach my $line (@lines) {
	print FD $line;
    }
    close(FD);

    return 0;
}

sub vmexists($) {
    my $id = shift;

    return 1
	if (!system("$VZLIST $id"));
    return 0;
}

sub vmstatus($) {
    my $id = shift;

    open(PFD,"$VZLIST $id |") 
	or die "could not exec $VZLIST: $!";
    while (<PFD>) {
	if ($_ =~ /^\s+$id\s+[^\s]+\s+(\w+)/) {
	    close(PFD);
	    return $1;
	}
    }
    close(PFD);
    return undef;
}

sub vmrunning($) {
    my $id = shift;

    return 1 
	if (vmstatus($id) eq VZSTAT_RUNNING);
    return 0;
}

sub vmstopped($) {
    my $id = shift;

    return 1 
	if (vmstatus($id) eq VZSTAT_STOPPED);
    return 0;
}

#
# See if a route table already exists for the given tag, and if not,
# allocate it and return the table number.
#
sub AllocateRouteTable($)
{
    my ($token) = @_;
    my $rval = undef;

    if (! -e $RTDB && InitializeRouteTables()) {
	print STDERR "*** Could not initialize routing table DB\n";
	return undef;
    }
    my %RTDB;
    if (!dbmopen(%RTDB, $RTDB, 0660)) {
	print STDERR "*** Could not open $RTDB\n";
	return undef;
    }
    # Look for existing.
    for (my $i = 1; $i < $MAXROUTETTABLE; $i++) {
	if ($RTDB{"$i"} eq $token) {
	    $rval = $i;
	    print STDERR "Found routetable $i ($token)\n";
	    goto done;
	}
    }
    # Allocate a new one.
    for (my $i = 1; $i < $MAXROUTETTABLE; $i++) {
	if ($RTDB{"$i"} eq "") {
	    $RTDB{"$i"} = $token;
	    print STDERR "Allocate routetable $i ($token)\n";
	    $rval = $i;
	    goto done;
	}
    }
  done:
    dbmclose(%RTDB);
    return $rval;
}

sub LookupRouteTable($)
{
    my ($token) = @_;
    my $rval = undef;

    my %RTDB;
    if (!dbmopen(%RTDB, $RTDB, 0660)) {
	print STDERR "*** Could not open $RTDB\n";
	return undef;
    }
    # Look for existing.
    for (my $i = 1; $i < $MAXROUTETTABLE; $i++) {
	if ($RTDB{"$i"} eq $token) {
	    $rval = $i;
	    goto done;
	}
    }
  done:
    dbmclose(%RTDB);
    return $rval;
}

sub FreeRouteTable($)
{
    my ($token) = @_;
    
    my %RTDB;
    if (!dbmopen(%RTDB, $RTDB, 0660)) {
	print STDERR "*** Could not open $RTDB\n";
	return -1;
    }
    # Look for existing.
    for (my $i = 1; $i < $MAXROUTETTABLE; $i++) {
	if ($RTDB{"$i"} eq $token) {
	    $RTDB{"$i"} = "";
	    print STDERR "Free routetable $i ($token)\n";
	    last;
	}
    }
    dbmclose(%RTDB);
    return 0;
}

sub InitializeRouteTables()
{
    # Create clean route table DB and seed it with defaults.
    my %RTDB;
    if (!dbmopen(%RTDB, $RTDB, 0660)) {
	print STDERR "*** Could not create $RTDB\n";
	return -1;
    }
    # Clear all,
    for (my $i = 0; $i < $MAXROUTETTABLE; $i++) {
	$RTDB{"$i"} = ""
	    if (!exists($RTDB{"$i"}));
    }
    # Seed the reserved tables.
    if (! open(RT, $RTTABLES)) {
	print STDERR "*** Could not open $RTTABLES\n";
	return -1;
    }
    while (<RT>) {
	if ($_ =~ /^(\d*)\s*/) {
	    $RTDB{"$1"} = "$1";
	}
    }
    close(RT);
    dbmclose(%RTDB);
    return 0;
}

#
# Rename or GC an image lvm. We can collect the lvm if there are no
# other lvms based on it.
#
sub GClvm($)
{
    my ($lvmname)= @_;
    my $oldest   = 0;
    my $inuse    = 0;
    my $found    = 0;

    #
    # If this is an image, we have to unmount it.
    #
    if ($lvmname =~ /^image\+(.*)/) {
	my $image = $1;
	
	mysystem("umount /mnt/$image")
	    if (-e "/mnt/$image/private");
    }

    if (! open(LVS, "lvs --noheadings -o lv_name,origin openvz |")) {
	print STDERR "Could not start lvs\n";
	return -1;
    }
    while (<LVS>) {
	my $line = $_;
	my $imname;
	my $origin;
	
	if ($line =~ /^\s*([-\w\.\+]+)\s*$/) {
	    $imname = $1;
	}
	elsif ($line =~ /^\s*([-\w\.\+]+)\s+([-\w\.\+]+)$/) {
	    $imname = $1;
	    $origin = $2;
	}
	else {
	    print STDERR "Unknown line from lvs: $line\n";
	    return -1;
	}
	#print "$imname";
	#print " : $origin" if (defined($origin));
	#print "\n";

	# The exact image we are trying to GC.
	$found = 1
	    if ($imname eq $lvmname);

	# If the origin is the image we are looking for,
	# then we mark it as inuse.
	$inuse = 1
	    if (defined($origin) && $origin eq $lvmname);

	# We want to find the highest numbered backup for this image.
	# Might not be any of course.
	if ($imname =~ /^([-\w\+]+)\.(\d+)$/) {
	    $oldest = $2
		if ($1 eq $lvmname && $2 > $oldest);
	}
    }
    close(LVS);
    return -1
	if ($?);
    print "found:$found, inuse:$inuse, oldest:$oldest\n";
    if (!$found) {
	print STDERR "GClvm($lvmname): no such lvm found\n";
	return -1;
    }
    if (!$inuse) {
	print "GClvm($lvmname): not in use; deleting\n";
	system("lvremove $LVMDEBUGOPTS -f /dev/$VGNAME/$lvmname");
	return -1
	    if ($?);
	return 0;
    }
    $oldest++;
    # rename nicely works even when snapshots exist
    system("lvrename $LVMDEBUGOPTS /dev/$VGNAME/$lvmname" . 
	   " /dev/$VGNAME/$lvmname.$oldest");
    return -1
	if ($?);
    return 0;
}

#
# Create a logical volume for the image if it doesn't already exist.
#
sub createImageDisk($$$$$)
{
    my ($image,$vnode_id,$raref,$tarfile,$lvsize) = @_;
    my $tstamp = $raref->[0]->{'IMAGEMTIME'};
    my $lvname = "image+" . $image;
    my $imagepath;
    my $lvmpath = lvmVolumePath($lvname);
    my $imagedatepath = "/var/emulab/db/openvz.image.${image}.date";
 
    # We are locked by the caller.

    #
    # Do we have the right image file already? No need to download it
    # again if the timestamp matches.
    #
    if (findLVMLogicalVolume($lvname)) {
	# Watch for reload, the mnt dir will be gone.
	goto bad
	    if (! -e "/mnt/$image" && mysystem2("mkdir -p /mnt/$image"));
	
	if (! -e $imagedatepath) {
	    #
	    # See if we can figure out the date. Must be a reboot/reload.
	    #
	    if (! -e "/mnt/$image/private") {
		mysystem2("mount $lvmpath /mnt/$image");
		if ($? == 0 && -e "/mnt/$image/.created") {
		    mysystem2("/bin/cp -p /mnt/$image/.created $imagedatepath");
		}
	    }
	}
	
	if (-e $imagedatepath) {
	    my (undef,undef,undef,undef,undef,undef,undef,undef,undef,
		$mtime,undef,undef,undef) = stat($imagedatepath);
	    if ("$mtime" eq "$tstamp") {
		#
		# We want to update the access time to indicate a new
		# use of this image, for pruning unused images later.
		#
		utime(time(), $mtime, $imagedatepath);
		print "Found existing disk: $lvmpath.\n";
		
		#
		# Make sure still mounted; might have been a reboot.
		#
		if (! -e "/mnt/$image/private") {
		    mysystem2("mount $lvmpath /mnt/$image");
		    goto bad
			if ($?);
		}
		return 0;
	    }
	    print "mtime for $lvmpath differ: local $mtime, server $tstamp\n";
	}
	if (-e "/mnt/$image/private" && mysystem2("umount /mnt/$image")) {
	    print STDERR "Could not umount /mnt/$image\n";
	    return -1;
	}
	if (GClvm($lvname)) {
	    print STDERR "Could not GC or rename $image\n";
	    return -1;
	}
	unlink($imagedatepath)
	    if (-e $imagedatepath);
    }

    if (system("lvcreate -n $lvname -L ${lvsize}M $VGNAME")) {
	print STDERR "libvnode_openvz: could not create disk for $image\n";
	return -1;
    }

    #
    # Format the volume as a filesystem to dump the tar file into.
    #
    goto bad
	if (! -e "/mnt/$image" && mysystem2("mkdir -p /mnt/$image"));
    goto bad
	if (-e "/mnt/$image/private" && mysystem2("umount /mnt/$image"));
    mysystem2("mkfs -t ext3 $lvmpath");
    goto bad
	if ($?);
    mysystem2("mount $lvmpath /mnt/$image");
    goto bad
	if ($?);
    mysystem2("mkdir -p /mnt/$image/root /mnt/$image/private");
    goto bad
	if ($?);

    #
    # If we were passed a tarfile, use that directly, as for the default.
    #
    if (defined($tarfile)) {
	$imagepath = $tarfile;
    }
    else {
	$imagepath = "$EXTRAFS/${image}.tar.gz";

	# Now we just download the file, then let create do its normal thing
	if (libvnode::downloadImage($imagepath, 1, $vnode_id, $raref)) {
	    print STDERR "libvnode_openvz: could not download image $image\n";
	    return -1;
	}
    }
    # Now unpack the tar file, then remove it.
    mysystem2("tar zxf $imagepath -C /mnt/$image/private");
    goto bad
	if ($?);
    unlink($imagepath)
	if (!$tarfile);

    # reload has finished, file is written... so let's set its mtime
    mysystem2("touch $imagedatepath")
	if (! -e $imagedatepath);
    utime(time(), $tstamp, $imagedatepath);
    # Store inside so we can find out after reboot/reload.
    mysystem2("/bin/cp -p $imagedatepath /mnt/$image/.created");
    
    #
    # Need to unmount for snapshots.
    #
    if ($DOSNAP) {
	mysystem2("umount /mnt/$image");
	goto bad
	    if ($?);
    }

    #
    # XXX note that we don't declare RELOADDONE here since we haven't
    # actually created the vnode shadow disk yet.  That is the caller's
    # responsibility.
    #
    return 0;
  bad:
    return -1;
}

sub lvmVolumePath($)
{
    my ($name) = @_;
    return "/dev/$VGNAME/$name";
}

sub findLVMLogicalVolume($)
{
    my ($lvm)  = @_;
    my $lvpath = lvmVolumePath($lvm);
    my $exists = `lvs --noheadings -o origin $lvpath > /dev/null 2>&1`;
    return 0
	if ($?);

    return 1;
}

sub lvmHasChildren($)
{
    my ($lvname) = @_;

    foreach (`lvs --noheadings -o origin $VGNAME`) {
	if (/^\s*${lvname}\s*$/) {
	    return 1;
	}
    }
    return 0;
}

sub lvmOrigin($)
{
    my ($lvm)  = @_;
    my $lvpath = lvmVolumePath($lvm);
    my $origin = `lvs --noheadings -o origin $lvpath`;
    return undef
	if ($?);

    # Trim
    chomp($origin);
    $origin =~ s/^\s+//;
    $origin =~ s/\s+$//;
    return $origin;
}

#
# Create a file to run from vznet-init, to set up the caps for a link.
#
sub CreateCapScript($$$$$)
{
    my ($vmid, $script, $ldinfo, $iface, $ifb) = @_;
    my $bw    = $ldinfo->{"BW"};
    my $type  = $ldinfo->{'TYPE'};

    if (! open(FILE, ">$script")) {
	print STDERR "Error creating $script: $!\n";
	return -1;
    }
    print FILE "#!/bin/sh\n";

    my @cmds = ();
    
    push(@cmds, "$TC qdisc add dev $iface handle 1 root htb default 1");
    push(@cmds, "$TC class add dev $iface classid 1:1 ".
	        "parent 1 htb rate ${bw}kbit ceil ${bw}kbit");

    push(@cmds, "$IFCONFIG $ifb up");
    push(@cmds, "$TC qdisc del dev $ifb root");
    push(@cmds, "$TC qdisc add dev $iface handle ffff: ingress");
    push(@cmds, "$TC filter add dev $iface parent ffff: protocol ip ".
	        "u32 match u32 0 0 action mirred egress redirect dev $ifb");
    push(@cmds, "$TC qdisc add dev $ifb root handle 2: htb default 1");
    push(@cmds, "$TC class add dev $ifb parent 2: classid 2:1 ".
	        "htb rate ${bw}kbit ceil ${bw}kbit");

    foreach my $cmd (@cmds) {
	print FILE "echo \"$cmd\"\n";
	print FILE "$cmd\n\n";
    }
    print FILE "exit 0\n";

    close(FILE);
    chmod(0554, $script);
    return 0;
}

#
# Deal with IFBs.
#
sub AllocateIFBs($$$)
{
    my ($vmid, $node_lds, $private) = @_;
    my @ifbs = ();

    my %MDB;
    if (!dbmopen(%MDB, $IFBDB, 0660)) {
	print STDERR "*** Could not create $IFBDB\n";
	return undef;
    }

    #
    # We need an IFB for every ld, so just make sure we can get that many.
    #
    my $needed = scalar(@$node_lds);

    #
    # First pass, look for enough before actually allocating them.
    #
    my $i = 0;
    my $n = $needed;
    
    while ($n && $i < $MAXIFB) {
	if (!defined($MDB{"$i"}) || $MDB{"$i"} eq "" || $MDB{"$i"} eq "$vmid") {
	    $n--;
	}
	$i++;
    }
    if ($i == $MAXIFB || $n) {
	print STDERR "*** No more IFBs\n";
	dbmclose(%MDB);
	return undef;
    }
    #
    # Now allocate them.
    #
    $i = 0;
    $n = $needed;
    
    while ($n && $i < $MAXIFB) {
	if (!defined($MDB{"$i"}) || $MDB{"$i"} eq "" || $MDB{"$i"} eq "$vmid") {
	    $MDB{"$i"} = $vmid;
	    # Record ifb in use
	    $private->{'ifbs'}->{$i} = $i;
	    push(@ifbs, $i);
	    $n--;
	}
	$i++;
    }
    dbmclose(%MDB);
    return \@ifbs;
}

sub ReleaseIFBs($$)
{
    my ($vmid, $private) = @_;
    
    my %MDB;
    if (!dbmopen(%MDB, $IFBDB, 0660)) {
	print STDERR "*** Could not create $IFBDB\n";
	return -1;
    }
    #
    # Do not worry about what we think we have, just make sure we
    # have released everything assigned to this vmid. 
    #
    for (my $i = 0; $i < $MAXIFB; $i++) {
	if (defined($MDB{"$i"}) && $MDB{"$i"} eq "$vmid") {
	    $MDB{"$i"} = "";
	}
    }
    dbmclose(%MDB);
    delete($private->{'ifbs'});
    return 0;
}

sub AllocateIMQs($$$)
{
    my ($vmid, $node_lds, $private) = @_;
    my @imqs = ();
    
    #
    # We need an IMQ for every duplex ld.
    #
    my $needed = 0;

    foreach my $ldc (@$node_lds) {
	$needed++
	    if ($ldc->{"TYPE"} eq 'duplex');
    }
    return \@imqs
	if (!$needed);

    my %MDB;
    if (!dbmopen(%MDB, $IMQDB, 0660)) {
	print STDERR "*** Could not create $IMQDB\n";
	return undef;
    }

    #
    # First pass, look for enough before actually allocating them.
    #
    my $i = 0;
    my $n = $needed;
    
    while ($n && $i < $MAXIMQ) {
	if (!defined($MDB{"$i"}) || $MDB{"$i"} eq "" || $MDB{"$i"} eq "$vmid") {
	    $n--;
	}
	$i++;
    }
    if ($i == $MAXIMQ || $n) {
	print STDERR "*** No more IMQs\n";
	dbmclose(%MDB);
	return undef;
    }
    #
    # Now allocate them.
    #
    $i = 0;
    $n = $needed;
    
    while ($n && $i < $MAXIMQ) {
	if (!defined($MDB{"$i"}) || $MDB{"$i"} eq "" || $MDB{"$i"} eq "$vmid") {
	    $MDB{"$i"} = $vmid;
	    # Record imq in use
	    $private->{'imqs'}->{$i} = $i;
	    push(@imqs, $i);
	    $n--;
	}
	$i++;
    }
    dbmclose(%MDB);
    return \@imqs;
}

sub ReleaseIMQs($$)
{
    my ($vmid, $private) = @_;
    
    my %MDB;
    if (!dbmopen(%MDB, $IMQDB, 0660)) {
	print STDERR "*** Could not create $IMQDB\n";
	return -1;
    }
    #
    # Do not worry about what we think we have, just make sure we
    # have released everything assigned to this vmid. 
    #
    for (my $i = 0; $i < $MAXIMQ; $i++) {
	if (defined($MDB{"$i"}) && $MDB{"$i"} eq "$vmid") {
	    $MDB{"$i"} = "";
	}
    }
    dbmclose(%MDB);
    delete($private->{'imqs'});
    return 0;
}

# convert 123456 into 12:34:56
sub fixupMac($)
{
    my ($x) = @_;
    $x =~ s/(\w\w)/$1:/g;
    chop($x);
    return $x;
}

# what can I say?
1;
