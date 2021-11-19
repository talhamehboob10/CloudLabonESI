#!/usr/bin/perl -wT
#
# Copyright (c) 2008-2018 University of Utah and the Flux Group.
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
# General vnode setup routines and helpers (Linux)
#
package libvnode;
use Exporter;
@ISA    = "Exporter";
@EXPORT = qw( makeIfaceMaps makeBridgeMaps makeMacvlanMaps
	      findControlNet existsIface findIface findMac getIfaceInfo
	      getIfaceInfoNoCache existsBridge findBridge findBridgeIfaces
              existsMacvlanParent findMacvlanParent findMacvlanIfaces
              downloadImage getKernelVersion createExtraFS
              forwardPort removePortForward lvSize lvExists
              DoIPtables DoIPtablesNoFail
              restartDHCP reconfigDHCP computeStripeSize
            );

use Data::Dumper;
BEGIN { require "/etc/emulab/paths.pm"; import emulabpaths; }
use libutil;
use libgenvnode;
use libsetup;
use libtestbed;

#
# Magic control network config parameters.
#
my $PCNET_IP_FILE   = "/var/emulab/boot/myip";
my $PCNET_MASK_FILE = "/var/emulab/boot/mynetmask";
my $PCNET_GW_FILE   = "/var/emulab/boot/routerip";
my $VIFROUTING      = ((-e "$ETCDIR/xenvifrouting") ? 1 : 0);

# Other local constants
my $IPTABLES   = "/sbin/iptables";

my $debug = 0;
my $lockdebug = 0;

sub setDebug($) {
    $debug = shift;
    print "libvnode: debug=$debug\n"
	if ($debug);
}

#
# Setup (or teardown) a port forward according to input hash containing:
# * ext_ip:   External IP address traffic is destined to
# * ext_port: External port traffic is destined to
# * int_ip:   Internal IP address traffic is redirected to
# * int_port: Internal port traffic is redirected to
#
# 'protocol' - a string; either "tcp" or "udp"
# 'remove'   - a boolean indicating whether or not to do a teardown.
#
# Side effect: uses iptables command to manipulate NAT.
#
sub forwardPort($;$) {
    my ($ref, $remove) = @_;
    
    my $int_ip   = $ref->{'int_ip'};
    my $ext_ip   = $ref->{'ext_ip'};
    my $int_port = $ref->{'int_port'};
    my $ext_port = $ref->{'ext_port'};
    my $protocol = $ref->{'protocol'};

    if (!(defined($int_ip) && 
	  defined($ext_ip) && 
	  defined($int_port) &&
	  defined($ext_port) && 
	  defined($protocol))
	) {
	print STDERR "WARNING: forwardPort: parameters missing!";
	return -1;
    }

    if ($protocol !~ /^(tcp|udp)$/) {
	print STDERR "WARNING: forwardPort: Unknown protocol: $protocol\n";
	return -1;
    }
    
    # Are we removing or adding the rule?
    my $op = (defined($remove) && $remove) ? "D" : "A";

    return -1
	if (DoIPtables("-v -t nat -$op PREROUTING -p $protocol -d $ext_ip ".
		       "--dport $ext_port -j DNAT ".
		       "--to-destination $int_ip:$int_port"));
    return 0;
}

#
# Oh jeez, iptables is about the dumbest POS I've ever seen; it fails
# if you run two at the same time. So we have to serialize the calls.
# The problem is that XEN also manipulates things, and so it is hard
# to get a perfect lock. So, we do our best and if it fails sleep for
# a couple of seconds and try again. 
#
sub _DoIPtables($@)
{
    my ($nofail, @rules) = @_;
    my $rv = 0;

    TBDebugTimeStamp("DoIPtables: grabbing iptables lock")
	if ($lockdebug);
    if (TBScriptLock("iptables", 0, 900) != TBSCRIPTLOCK_OKAY()) {
	print STDERR "Could not get the iptables lock after a long time!\n";
	return -1;
    }
    TBDebugTimeStamp("  got iptables lock")
	if ($lockdebug);
    foreach my $rule (@rules) {
	my $retries = 10;
	my $status  = 0;
	while ($retries > 0) {
	    TBDebugTimeStamp("  doing 'iptables $rule'");
	    mysystem2("$IPTABLES $rule", 0);
	    $status = $?;
	    last
		if (!$status || $status >> 8 != 4);
	    print STDERR "will retry in one second ...\n";
	    sleep(1);
	    $retries--;
	}
	# Operation failed - either return error or do the rest
	if (!$retries || $status) {
	    if (!$nofail) {
		TBDebugTimeStamp("  releasing iptables lock on error")
		    if ($lockdebug);
		TBScriptUnlock();
		return -1;
	    }
	    # we still return an error code
	    $rv = -1;
	}
    }
    TBDebugTimeStamp("  releasing iptables lock")
	if ($lockdebug);
    TBScriptUnlock();
    return $rv;
}

sub DoIPtables(@)
{
    return _DoIPtables(0, @_);
}

sub DoIPtablesNoFail(@)
{
    return _DoIPtables(1, @_);
}

sub removePortForward($) {
    my $ref = shift;
    return forwardPort($ref,1);
}

# Is the given device an SSD?
sub isSSD($)
{
    my ($dev) = @_;
    my $isssd = 0;

    if (-e "/dev/$dev") {
	# hdparm doesn't seem to handle NVMe
	if ($dev =~ /^nvme\d+n\d+/) {
	    $isssd = 1;
	}
	elsif (-x "/sbin/hdparm" &&
	    open(HFD, "/sbin/hdparm -I /dev/$dev 2>/dev/null |")) {
	    while (my $line = <HFD>) {
		chomp($line);
		if ($line =~ /:\s+solid state device$/i) {
		    $isssd = 1;
		    last;
		}
	    }
	    close(HFD);
	}
    }

    return $isssd;
}

#
# A spare disk or disk partition is one whose partition ID is 0 and is not
# mounted and is not in /etc/fstab AND is >= the specified minsize (in MiB).
# Note that we do now check labels and UUIDs as well as names in fstab.
#
# This function returns a hash of:
#   device name => part number => {size,path}
# where size is in bytes and path is the full device name path to use
# (which may NOT just be a simple concatonation of device name and partition).
# Note that a device name => {size,fullpath} entry is filled IF the device
# has no partitions.
#
# If the optional $skipssds is set, we identify each disk as an SSD or not,
# skipping ones that are.
#
sub findSpareDisks($;$) {
    my ($minsize,$skipssds) = @_;

    my %retval = ();
    my %mounts = ();
    my %ftents = ();
    my %pvs = ();

    # /proc/partitions prints sizes in 1K phys blocks
    my $BLKSIZE = 1024;

    # convert minsize to 1K blocks
    $minsize *= 1024;

    # XXX figure out what command to give to sfdisk
    my $sfcmd = "--print-id";
    my $out = `sfdisk -v`;
    if (defined($out) && $out =~ /2\.(\d+)(\.\d+)$/) {
	if (int($1) >= 26) {
	    $sfcmd = "--part-type";
	}
    }
    
    open (MFD,"/proc/mounts") 
	or die "open(/proc/mounts): $!";
    while (my $line = <MFD>) {
	chomp($line);
	if ($line =~ /^([^\s]+)\s+([^\s]+)\s+([^\s]+)\s+([^\s]+)\s+/) {
	    $mounts{$1} = $2;
	}
    }
    close(MFD);

    open (FFD,"/etc/fstab") 
	or die "open(/etc/fstab): $!";
    while (my $line = <FFD>) {
	chomp($line);
	if ($line =~ /^([^\s]+)\s+([^\s]+)/) {
	    $ftents{$1} = $2;
	}
    }
    close(FFD);

    if (-x "/sbin/pvs" && open (PFD,"/sbin/pvs|")) {
	while (my $line = <PFD>) {
	    chomp($line);
	    if ($line =~ /^\s*\/dev\/(\S+)\s+\S+\s+\S+\s+\S+\s+\S+\s+\S+/) {
		$pvs{$1} = 1;
	    }
	}
	close(PFD);
    }

    open (PFD,"/proc/partitions") 
	or die "open(/proc/partitions): $!";

    while (my $line = <PFD>) {
	chomp($line);

	# ignore malformed lines
	my ($size,$devpart);
	if ($line =~ /^\s*\d+\s+\d+\s+(\d+)\s+(\S+)$/) {
	    $size = $1;
	    $devpart = $2;
	} else {
	    next;
	}

	#
	# XXX weed out special cases:
	#    SCSI CDROM (srN),
	#    RAM disks (ramN),
	#    device mapper files (dm-N),
	#    LVM PVs
	#
	if ($devpart =~ /^sr\d+$/ ||
	    $devpart =~ /^ram\d+$/ ||
	    $devpart =~ /^dm-\d+$/ ||
	    exists($pvs{$devpart})) {
	    next;
	}

	#
	# The old heuristic was: if it ends in a digit, it is a partition
	# device otherwise it is a disk device. But that got screwed up by,
	# e.g., the cciss device where "c0d0" is a disk while "c0d0p1" is a
	# partition. The new fallible heuristic is: if it ends in a digit
	# but is of the form cNdN then it is a disk! And now there is
	# "nvme0n1" and "nvme0n1p1" to consider!
	#
	if ($devpart =~ /^(\S+)(\d+)$/) {
	    my ($dev,$part) = ($1,$2);

	    # cNdN(pN) format
	    if ($devpart =~ /(.*c\d+d\d+)(p\d+)?$/) {
		if (!defined($2)) {
		    goto isdisk;
		}
		$dev = $1;
	    }

	    # nvmeNnN(pN) format
	    elsif ($devpart =~ /(.*nvme\d+n\d+)(p\d+)?$/) {
		if (!defined($2)) {
		    goto isdisk;
		}
		$dev = $1;
	    }

	    # This is a partition on an earlier discovered disk device,
	    # ignore the disk device. This is signalled by clearing the size.
	    if (exists($retval{$dev}{"size"})) {
		delete $retval{$dev}{"size"};
		delete $retval{$dev}{"path"};
		if (scalar(keys(%{$retval{$dev}})) == 0) {
		    delete $retval{$dev};
		}
	    }

	    # XXX don't include extended partitions (the reason is to filter
	    # out pseudo partitions that linux creates for bsd disklabel 
	    # slices -- we don't want to use those!
	    # 
	    # (of course, a much better approach would be to check if a 
	    # partition is contained within another and not use it.)
	    next 
		if ($part > 4);

	    # If asked to, ignore SSDs
	    next
		if ($skipssds && isSSD($dev));

	    if (!defined($mounts{"/dev/$devpart"}) 
		&& !defined($ftents{"/dev/$devpart"})) {

		# try checking its ext2 label
		my @outlines = `dumpe2fs -h /dev/$devpart 2>&1`;
		if (!$?) {
		    my ($uuid,$label);
		    foreach my $line (@outlines) {
			if ($line =~ /^Filesystem UUID:\s+([-\w\d]+)/) {
			    $uuid = $1;
			}
			elsif ($line =~ /^Filesystem volume name:\s+([-\/\w\d]+)/) {
			    $label = $1;
			}
		    }
		    if ((defined($uuid) && defined($ftents{"UUID=$uuid"}))
			|| (defined($label) && defined($ftents{"LABEL=$label"})
			    && $ftents{"LABEL=$label"} eq $label)) {
			next;
		    }
		}

		# one final check: partition id
		my $output = `sfdisk $sfcmd /dev/$dev $part 2>/dev/null`;
		chomp($output);
		$output =~ s/^\s+//;
		if ($?) {
		    print STDERR "WARNING: findSpareDisks: error running 'sfdisk $sfcmd /dev/$dev $part': $! ... ignoring /dev/$devpart\n";
		}
		elsif ($output eq "0" && $size >= $minsize) {
		    $retval{$dev}{$part}{"size"} = $BLKSIZE * $size;
		    $retval{$dev}{$part}{"path"} = "/dev/$devpart";
		}
	    }
	}
	else {
isdisk:
	    # If asked to, ignore SSDs
	    next
		if ($skipssds && isSSD($devpart));

	    if (!exists($mounts{"/dev/$devpart"}) &&
		!exists($ftents{"/dev/$devpart"}) &&
		$size >= $minsize) {
		$retval{$devpart}{"size"} = $BLKSIZE * $size;
		$retval{$devpart}{"path"} = "/dev/$devpart";
	    }
	}
    }
    close(PFD);

    foreach my $d (keys(%retval)) {
	if (scalar(keys(%{$retval{$d}})) == 0) {
	    delete $retval{$d};
	}
    }

    return %retval;
}

#
# Attempt to compute a stripe size, based on physical number of
# devices in the volume group.
#
sub computeStripeSize($)
{
    my ($vgname) = @_;
    my $command  = "vgdisplay -v $vgname 2>/dev/null | ".
	"awk '/PV Name/ {print \$3}'";
    my %devices = ();
    my $count   = 1;
    
    if (open(PFD, "$command |")) {
	while (my $line = <PFD>) {
	    if ($line =~ /\/dev\/(\w{2,3})/) {
		$devices{$1} = $1;
	    }
	}
	close(PFD);
	$count = scalar(keys(%devices));
    }
    return $count;
}

my %if2mac = ();
my %mac2if = ();
my %ip2if = ();
my %ip2mask = ();
my %ip2net = ();
my %ip2maskbits = ();
my %if2info = ();

#
# Grab iface, mac, IP info from /sys and /sbin/ip.
#
sub makeIfaceMaps()
{
    # clean out anything
    %if2mac = ();
    %mac2if = ();
    %ip2if = ();
    %ip2net = ();
    %ip2mask = ();
    %ip2maskbits = ();
    %if2info = ();

    my $devdir = '/sys/class/net';
    opendir(SD,$devdir) 
	or die "could not find $devdir!";
    my @ifs = grep { /^[^\.]/ && -f "$devdir/$_/address" } readdir(SD);
    closedir(SD);

    foreach my $iface (@ifs) {
	next
	    if ($iface =~ /^ifb/ || $iface =~ /^imq/);
	
	if ($iface =~ /^([\w\d\-_]+)$/) {
	    $iface = $1;
	}
	else {
	    next;
	}

	#
	# To ensure this can be run without a lock, don't die on a failed
	# open.  The only reason we'll fail to open here is if the device
	# has gone away after the initial dir listing.
	#
	my $ifinfo = getIfaceInfoNoCache($iface);
	next
	    if (!defined($ifinfo));
	my ($mac,$ip) = ($ifinfo->{'mac'},$ifinfo->{'ip'});
	$if2info{$iface} = $ifinfo;
	$if2mac{$iface} = $mac;
	$mac2if{$mac} = $iface;
	# If the 'ip' key isn't set, none of this stuff will be there;
	# for interfaces that have no IP.
	if (defined($ip)) {
	    $ip2net{$ip} = $ifinfo->{'network'};
	    $ip2mask{$ip} = $ifinfo->{'mask'};
	    $ip2maskbits{$ip} = $ifinfo->{'maskbits'};
	}
    }

    if ($debug > 1) {
	print STDERR "makeIfaceMaps:\n";
	print STDERR "if2mac:\n";
	print STDERR Dumper(%if2mac) . "\n";
	#print STDERR "mac2if:\n";
	#print STDERR Dumper(%mac2if) . "\n";
	print STDERR "ip2if:\n";
	print STDERR Dumper(%ip2if) . "\n";
	print STDERR "\n";
    }

    return 0;
}

#
# Find control net iface info.  Returns:
# (iface_name,IP,IPmask,IPmaskbits,IPnet,MAC,GW)
#
sub findControlNet()
{
    my $ip = (-r $PCNET_IP_FILE) ? `cat $PCNET_IP_FILE` : "0";
    chomp($ip);
    if ($ip =~ /^(\d+\.\d+\.\d+\.\d+)$/) {
	$ip = $1;
    } else {
	die "Could not find valid control net IP (no $PCNET_IP_FILE?)";
    }
    my $gw = (-r $PCNET_GW_FILE) ? `cat $PCNET_GW_FILE` : "0";
    chomp($gw);
    if ($gw =~ /^(\d+\.\d+\.\d+\.\d+)$/) {
	$gw = $1;
    } else {
	die "Could not find valid control net GW (no $PCNET_GW_FILE?)";
    }
    return ($ip2if{$ip}, $ip, $ip2mask{$ip}, $ip2maskbits{$ip}, $ip2net{$ip},
	    $if2mac{$ip2if{$ip}}, $gw);
}

sub existsIface($) {
    my $iface = shift;

    return 1
        if (exists($if2mac{$iface}));

    return 0;
}

sub findIface($) {
    my $mac = shift;

    $mac =~ s/://g;
    $mac = lc($mac);
    return $mac2if{$mac}
        if (exists($mac2if{$mac}));

    return undef;
}

sub getIfaceInfoNoCache($) {
    my ($iface) = @_;
    my $ret = {};

    open(FD,"/sys/class/net/$iface/address") 
	or return undef;
    my $mac = <FD>;
    close(FD);
    return undef
	if (!defined($mac) || $mac eq '');

    $mac =~ s/://g;
    chomp($mac);
    $mac = lc($mac);
    $ret = { 'mac' => $mac, 'iface' => $iface };

    # We do not care about any of the stuff below for our bridges, and
    # on a shared node this was taking 60 seconds every time we called
    # makeIfaceMaps(), which we do a lot, plus we now call it from
    # emulab-cnet when containers are booting or shutting down.
    return $ret
	if ($iface =~ /^br\d+$/);

    # Find IP info
    my $pip = `ip addr show dev $iface | grep 'inet '`;
    chomp($pip);
    if ($pip =~ /^\s+inet\s+(\d+\.\d+\.\d+\.\d+)\/(\d+)/) {
	my $ip = $1;
	$ip2if{$ip} = $iface;
	my @ip = split(/\./,$ip);
	my $bits = int($2);
	my @netmask = (0,0,0,0);
	my ($idx,$counter) = (0,8);
	for (my $i = $bits; $i > 0; --$i) {
	    --$counter;
	    $netmask[$idx] += 2 ** $counter;
	    if ($counter == 0) {
		$counter = 8;
		++$idx;
	    }
	}
	my @network = ($ip[0] & $netmask[0],$ip[1] & $netmask[1],
		       $ip[2] & $netmask[2],$ip[3] & $netmask[3]);
	$ret->{'network'} = join('.',@network);
	$ret->{'mask'} = join('.',@netmask);
	$ret->{'maskbits'} = $bits;
	$ret->{'ip'} = $ip;
    }

    return $ret;
}

#
# Returns a dict of iface, mac[, ip, network, mask, maskbits], if the
# supplied iface exists.  The IPv4 info is only included if it exists.
#
sub getIfaceInfo($) {
    my $iface = shift;

    return undef
	if (!exists($if2info{$iface}));

    return $if2info{$iface};
}

sub findMac($) {
    my $iface = shift;

    return $if2mac{$iface}
        if (exists($if2mac{$iface}));

    return undef;
}

my %bridges = ();
my %if2br = ();

sub makeBridgeMaps() {
    # clean out anything...
    %bridges = ();
    %if2br = ();

    my @lines = `brctl show`;
    # always get rid of the first line -- it's the column header 
    shift(@lines);
    my $curbr = '';
    foreach my $line (@lines) {
	if ($line =~ /^([\w\d\-\.]+)\s+/) {
	    $curbr = $1;
	    $bridges{$curbr} = [];
	}
	if ($line =~ /^[^\s]+\s+[^\s]+\s+[^\s]+\s+([\w\d\-\.]+)$/ 
	    || $line =~ /^\s+([\w\d\-\.]+)$/) {
	    push @{$bridges{$curbr}}, $1;
	    $if2br{$1} = $curbr;
	}
    }

    if ($debug > 1) {
	print STDERR "makeBridgeMaps:\n";
	print STDERR "bridges:\n";
	print STDERR Dumper(%bridges) . "\n";
	print STDERR "if2br:\n";
	print STDERR Dumper(%if2br) . "\n";
	print STDERR "\n";
    }

    return 0;
}

sub existsBridge($) {
    my $bname = shift;

    return 1
        if (exists($bridges{$bname}));

    return 0;
}

sub findBridge($) {
    my $iface = shift;

    return $if2br{$iface}
        if (exists($if2br{$iface}));

    return undef;
}

sub findBridgeIfaces($) {
    my $bname = shift;

    return @{$bridges{$bname}}
        if (exists($bridges{$bname}));

    return undef;
}

my %macvlans = ();
my %if2mv = ();

sub makeMacvlanMaps() {
    # clean out anything...
    %macvlans = ();
    %if2mv = ();

    my @lines = `ip link show type macvlan`;
    foreach my $line (@lines) {
	if ($line =~ /^\d+:\s+([^\@]+)\@([^:]+):/) {
	    if (!exists($macvlans{$2})) {
		$macvlans{$2} = [];
	    }
	    push(@{$macvlans{$2}},$1);
	}
    }

    if ($debug > 1) {
	print STDERR "makeMacvlanMaps:\n";
	print STDERR "macvlans:\n";
	print STDERR Dumper(%macvlans) . "\n";
	print STDERR "if2mv:\n";
	print STDERR Dumper(%if2mv) . "\n";
	print STDERR "\n";
    }

    return 0;
}

sub existsMacvlanParent($) {
    my $parent = shift;

    return 1
        if (exists($macvlans{$parent}));

    return 0;
}

sub findMacvlanParent($) {
    my $iface = shift;

    return $if2mv{$iface}
        if (exists($if2mv{$iface}));

    return undef;
}

sub findMacvlanIfaces($) {
    my $parent = shift;

    return @{$macvlans{$parent}}
        if (exists($macvlans{$parent}));

    return undef;
}

#
# Since (some) vnodes are imageable now, we provide an image fetch
# mechanism.  Caller provides an imagepath for frisbee, and a hash of
# args that comes directly from loadinfo.
#
sub downloadImage($$$$) {
    my ($imagepath,$todisk,$nodeid,$reload_args_ref) = @_;

    return -1 
	if (!defined($imagepath) || !defined($reload_args_ref));

    my $addr = $reload_args_ref->{"ADDR"};
    my $FRISBEE = "/usr/local/bin/frisbee";
    my $IMAGEUNZIP = "/usr/local/bin/imageunzip";
    my $command = "";
    # Backwards compat.
    if (! -e $FRISBEE) {
	$FRISBEE = "/usr/local/etc/emulab/frisbee";
    }

    if (!defined($addr) || $addr eq "") {
	# frisbee master server world
	my ($server, $imageid);
	my $proxyopt  = "";
	my $todiskopt = "";

	if ($reload_args_ref->{"SERVER"} =~ /^(\d+\.\d+\.\d+\.\d+)$/) {
	    $server = $1;
	}
	if ($reload_args_ref->{"IMAGEID"} =~
	    /^([-\d\w]+),([-\d\w]+),([-\d\w\.:]+)$/) {
	    $imageid = "$1/$3";
	}
	if (SHAREDHOST()) {
	    $proxyopt = "-P $nodeid";
	}
	if (!$todisk) {
	    $todiskopt = "-N";
	}
	if ($server && $imageid) {
	    # Allow the server to enable heartbeat reports in the client
	    my $heartbeat = "-H 0";

	    $command = "$FRISBEE -f -M 64 $proxyopt $heartbeat $todiskopt ".
		"-S $server -B 30 -F $imageid $imagepath";
	}
	else {
	    print STDERR "Could not parse frisbee loadinfo\n";
	    return -1;
	}
    }
    elsif ($addr =~/^(\d+\.\d+\.\d+\.\d+):(\d+)$/) {
	my $mcastaddr = $1;
	my $mcastport = $2;

	$command = "$FRISBEE -f -M 64 -m $mcastaddr -p $mcastport $imagepath";
    }
    elsif ($addr =~ /^http/) {
	if ($todisk) {
	    $command = "wget -nv -N -O - '$addr' | ".
		"$IMAGEUNZIP -f -W 32 - $imagepath";
	}
	else {
	    $command = "wget -nv -N -O $imagepath '$addr'";
	}
    }
    print STDERR $command . "\n";
    
    #
    # Run the command protected by an alarm to avoid trying forever,
    # as frisbee is prone to doing.
    #
    my $childpid = fork();
    if ($childpid) {
	local $SIG{ALRM} = sub { kill("TERM", $childpid); };
	alarm 60 * 30;
	waitpid($childpid, 0);
	my $stat = $?;
	alarm 0;

	if ($stat) {
	    print STDERR "  returned $stat ... \n";
	    return -1;
	}
	return 0;
    }
    else {
	#
	# We have blocked most signals in mkvnode, including TERM.
	#
	local $SIG{TERM} = 'DEFAULT';
	exec($command);
	exit(1);
    }
}

#
# Get kernel (major,minor,patchlevel) version tuple.
#
sub getKernelVersion()
{
    my $kernvers = `cat /proc/sys/kernel/osrelease`;
    chomp $kernvers;

    if ($kernvers =~ /^(\d+)\.(\d+)\.(\d+)/) {
	return ($1,$2,$3);
    }

    return undef;
}

#
# Create an extra FS using an LVM.
#
sub createExtraFS($$$)
{
    my ($path, $vgname, $size) = @_;
    
    if (! -e $path) {
	system("mkdir $path") == 0
	    or return -1;
    }
    return 0
	if (-e "$path/.mounted");
    
    my $lvname;
    if ($path =~ /\/(.*)$/) {
	$lvname = $1;
    }
    my $lvpath = "/dev/$vgname/$lvname";
    my $exists = `lvs --noheadings -o origin $lvpath > /dev/null 2>&1`;
    if ($?) {
	my $ns = computeStripeSize($vgname);
	system("lvcreate -n $lvname -L $size -i$ns $vgname") == 0
	    or return -1;

	system("mke2fs -j -q $lvpath") == 0
	    or return -1;
    }
    if (! -e "$path/.mounted") {
	system("mount $lvpath $path") == 0
	    or return -1;
    }
    system("touch $path/.mounted");

    if (system("egrep -q -s '^${lvpath}' /etc/fstab")) {
	system("echo '$lvpath $path ext3 defaults 0 0' >> /etc/fstab")
	    == 0 or return -1;
    }
    return 0;
}

#
# Check if the LV exists.
#
sub lvExists($$)
{
    my ($vgname,$lvname) = @_;

    my $lvpath = "/dev/$vgname/$lvname";
    my $exists = `lvs --noheadings -o origin $lvpath > /dev/null 2>&1`;
    if ($?) {
	return 0;
    }
    return 1;
}

#
# Figure out the size of the LVM.
#
sub lvSize($)
{
    my ($device) = @_;
    
    my $lv_size = `lvs -o lv_size --noheadings --units k --nosuffix $device`;
    return undef
	if ($?);
    
    chomp($lv_size);
    $lv_size =~ s/^\s+//;
    $lv_size =~ s/\s+$//;
    return $lv_size;
}

#
# Reset the list of interfaces that DHCPD should listen on.
#
sub reconfigDHCP()
{
    my @vifs = "";
    my $defaults = '/etc/default/isc-dhcp-server';

    if ($VIFROUTING) {
	#
	# We want to set the list of vifs that dhcpd listens on, since if
	# there are too many VMs coming and going, it can take a long time
	# for dhcpd to process all the virtual interfaces that exist
	# (like ifbs, veths, bridges, etc) that it does not care about
	# cause they are down or otherwise. So figure out the vif list
	# and write that into the /etc/defaults.
	#
	my $devdir = '/sys/class/net';
	if (!opendir(SD,$devdir)) {
	    print STDERR "Could not find $devdir!\n";
	    return -1;
	}
	@vifs = grep { /^vif.*/ && -f "$devdir/$_/address" } readdir(SD);
	closedir(SD);
    }

    #
    # Also need the control network bridge.
    #
    makeIfaceMaps();
    my ($cnet_iface) = findControlNet();
    my @ifaces = "$cnet_iface @vifs";

    if (! -e $defaults) {
	mysystem2("echo 'INTERFACES=\"@ifaces\"' > $defaults");
    }
    else {
	mysystem2("/bin/sed -i.bak -e ".
		 " 's,^INTERFACES=.*\$,INTERFACES=\"@ifaces\",i' $defaults");
    }
    return -1
	if ($?);

    return 0;
}

sub restartDHCP()
{
    my $dhcpd_service = 'dhcpd';
    if (-f '/etc/init/isc-dhcp-server.conf' ||
	-f '/lib/systemd/system/isc-dhcp-server.service') {
        $dhcpd_service = 'isc-dhcp-server';
    }
    if (reconfigDHCP()) {
	return;
    }

    # make sure dhcpd is running
    if (-x '/sbin/initctl') {
        # Upstart
        if (mysystem2("/sbin/initctl restart $dhcpd_service") != 0) {
            mysystem2("/sbin/initctl start $dhcpd_service");
        }
    } elsif (-x '/bin/systemctl') {
	# systemd
	mysystem2("/bin/systemctl restart $dhcpd_service.service");
    } elsif (-x '/etc/init.d/$dhcpd_service') {
        # sysvinit
        mysystem2("/etc/init.d/$dhcpd_service restart");
    } else {
	print STDERR "restartDHCP: could not restart dhcpd!\n";
    }
}

#
# Life's a rich picnic.  And all that.
1;
