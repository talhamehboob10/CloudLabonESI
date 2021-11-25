#!/usr/bin/perl -wT
#
# Copyright (c) 2013-2021 University of Utah and the Flux Group.
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

#
# Linux specific routines and constants for the client bootime setup stuff.
#
package liblocstorage;
use Exporter;
@ISA = "Exporter";
@EXPORT =
    qw (
	os_init_storage os_check_storage os_create_storage os_remove_storage
	os_show_storage os_get_diskinfo
       );

sub VERSION()	{ return 1.0; }

# Must come after package declaration!
use English;
use Cwd 'abs_path';
use libsetup;
use libtmcc;

my $VGNAME;

# Load up the paths. Its conditionalized to be compatabile with older images.
# Note this file has probably already been loaded by the caller.
BEGIN
{
    if (-e "/etc/emulab/paths.pm") {
	require "/etc/emulab/paths.pm";
	import emulabpaths;
    }
    else {
	$ETCDIR  = "/etc/rc.d/testbed";
	$BINDIR  = "/etc/rc.d/testbed";
	$VARDIR  = "/etc/rc.d/testbed";
	$BOOTDIR = "/etc/rc.d/testbed";
    }
    my $genvmtype = "";
    if (-e "$ETCDIR/genvmtype") {
	$genvmtype = `cat $ETCDIR/genvmtype`;
	chomp($genvmtype);
    }
    
    $VGNAME = "emulab";
    
    if (GENVNODEHOST() && GENVNODETYPE() eq 'docker') {
	$VGNAME = "docker";
    } elsif (GENVNODEHOST() && !SHAREDHOST()) {
	$VGNAME = "xen-vg";
    } elsif (INXENVM() && -r "$VARDIR/boot/vmname") {
	my $vname = `cat $VARDIR/boot/vmname`;
	chomp $vname;
	if ($vname =~ /^([-\w]+)$/) {
	    $VGNAME = "emulab-$1";
	}
    }
}

sub ISFORDOCKERVM() {
    if (defined(libsetup_getvnodeid())
	&& GENVNODEHOST() && GENVNODETYPE() eq 'docker') {
	return 1;
    }
    return 0;
}

my $MOUNT	= "/bin/mount";
my $UMOUNT	= "/bin/umount";
my $MKDIR	= "/bin/mkdir";
my $MKFS	= "/sbin/mke2fs";
my $FSCK	= "/sbin/e2fsck";
my $DUMPFS	= "/sbin/dumpe2fs";
my $DOSTYPE	= "$BINDIR/dostype";
my $ISCSI	= "/sbin/iscsiadm";
my $ISCSI_ALT	= "/usr/bin/iscsiadm";
my $ISCSINAME	= "/etc/iscsi/initiatorname.iscsi";
my $SMARTCTL	= "/usr/sbin/smartctl";
my $BLKID	= "/sbin/blkid";
my $SFDISK	= "/sbin/sfdisk";
my $SGDISK	= "/sbin/sgdisk";
my $GDISK	= "/sbin/gdisk";
my $PPROBE	= "/sbin/partprobe";
my $FRISBEE     = "/usr/local/bin/frisbee";
my $HDPARM	= "/sbin/hdparm";

my $FSTAB	= "/etc/fstab";

#
# Time to wait for a session to start.
#
# XXX it might take a long time for the target (blockstore server)
# to export our blockstore if a lot of blockstores are being
# setup at the same time. So we hang out for a long time.
#
# Note that the Linux iscsiadm default timeout is 2 minutes so this
# value should be a multiple of 120 seconds.
#
my $SESSION_TIMEOUT = (12 * 60);

#
#
# To find the block stores exported from a target portal:
#
#   iscsiadm -m discovery -t sendtargets -p <storage-host>
#
# Display all data for a given node record:
#
#   iscsiadm -m node -T <iqn> -p <storage-host>
#
# Here are the commands to add a remote iSCSI target, set it to NOT be
# mounted automatically at startup, and startup a session (login):
# 
#   iscsiadm -m node -T <iqn> -p <storage-host> -o new
#   iscsiadm -m node -T <iqn> -p <storage-host> -o update \
#              -n node.startup -v manual
#   iscsiadm -m node -T <iqn> -p <storage-host> -l
# 
# To show active sessions:
# 
#   iscsiadm -m session
# 
# To stop a specific session (logout) and kill its record:
#
#   iscsiadm -m node -T <iqn> -p <storage-host> -u
#   iscsiadm -m node -T <iqn> -p <storage-host> -o delete
#
# To stop all iscsi sessions and kill all records:
# 
#   iscsiadm -m node -U all
#   iscsiadm -m node -o delete
# 
# Once a blockstore is added, you have to use "fdisk -l" or possibly
# crap out in /proc to discover what the name of the disk is.  I've been
# looking for uniform way to query the set of disks on a machine, but
# haven't quite figured this out yet.  The closest thing I've found is
# "fdisk -l".  There are some libraries and such, but there are enough
# of them that I'm not sure which one is best / most standard.
# 

sub iscsi_to_dev($)
{
    my ($session) = @_;

    #
    # XXX this is a total hack and maybe distro dependent?
    #
    my @lines = `ls -l /sys/block/sd[a-z] /sys/block/sd[a-z][a-z] 2>&1`;
    foreach (@lines) {
	if (m#/sys/block/(sd[a-z][a-z]?) -> ../devices/platform/host\d+/session(\d+)#) {
	    if ($2 == $session) {
		return $1;
	    }
	}
    }

    return undef;
}

#
# Returns one if the indicated device is an iSCSI-provided one
# XXX another total hack
#
sub is_iscsi_dev($)
{
    my ($dev) = @_;

    if (-e "/sys/block/$dev") {
	my $line = `ls -l /sys/block/$dev 2>/dev/null`;
	if ($line =~ m#/sys/block/$dev -> ../devices/platform/host\d+/session\d+#) {
	    return 1;
	    }
    }
    return 0;
}

sub find_serial($)
{
    my ($dev) = @_;
    my @lines;

    #
    # Try using "smartctl -i" first
    #
    if (-x "$SMARTCTL") {
	my $opt = "";
      again:
	@lines = `$SMARTCTL -i /dev/$dev $opt 2>&1`;
	foreach (@lines) {
	    if (/^serial number:\s+(\S.*)/i) {
		return $1;
	    }
	    #
	    # XXX hack to get around Dell raid controllers.
	    # If smartctl suggests using "-d megaraid,N", do so but only once.
	    #
	    # XXX this will only work for the first 26 drives (a-z), sorry.
	    #
	    if (!$opt &&
		m#/dev/sd([a-z]) failed: DELL or MegaRaid controller#) {
		my $dn = ord($1) - ord('a');
		$opt = "-d megaraid,$dn";
		goto again;
	    }
	}
    }

    #
    # Try /dev/disk/by-id.
    # XXX this is a total hack and maybe distro dependent?
    #
    @lines = `ls -l /dev/disk/by-id/ 2>&1`;
    foreach (@lines) {
	if (m#.*_([^_\s]+) -> ../../(sd[a-z][a-z]?)$#) {
	    if ($2 eq $dev) {
		return $1;
	    }
	}
    }

    # XXX Parse dmesg output?

    return undef;
}

#
# Do a one-time initialization of a serial number -> /dev/sd? map.
#
sub init_serial_map()
{
    #
    # XXX this is a total hack and maybe distro dependent?
    #
    my %snmap = ();
    my @lines = `ls -l /sys/block/sd[a-z] /sys/block/sd[a-z][a-z] /sys/block/nvme[0-9]* 2>&1`;
    foreach (@lines) {
	# XXX if a pci device, assume a local disk
	# XXX for moonshots (arm64), it is different
	if (m#/sys/block/(sd[a-z][a-z]?) -> ../devices/pci\d+# ||
	    m#/sys/block/(nvme\d+n\d+) -> ../devices/pci\d+# ||
	    m#/sys/block/(sd[a-z][a-z]?) -> ../devices/soc.\d+#) {
	    my $dev = $1;
	    $sn = find_serial($dev);
	    if ($sn) {
		$snmap{$sn} = $dev;
	    }
	}
    }

    return \%snmap;
}

sub serial_to_dev($$)
{
    my ($so, $sn) = @_;

    if (defined($so->{'LOCAL_SNMAP'})) {
	my $snmap = $so->{'LOCAL_SNMAP'};
	if (exists($snmap->{$sn})) {
	    return $snmap->{$sn};
	}
    }
    return undef;
}

#
# Determine if a disk is "SSD" or "HDD"
#
sub get_disktype($)
{
    my ($dev) = @_;
    my @lines;

    #
    # Assume NVMe is SSSD.
    # Older hdparm and smartctl don't seem to handle NVMe
    #
    if ($dev =~ /^nvme\d+n\d+/) {
	return "SSD";
    }

    #
    # Try hdparm first since it is a standard utility
    #
    if (-x "$HDPARM") {
	if (open(HFD, "$HDPARM -I /dev/$dev 2>/dev/null |")) {
	    my $isssd = 0;

	    while (my $line = <HFD>) {
		chomp($line);
		if ($line =~ /:\s+solid state device$/i) {
		    $isssd = 1;
		    last;
		}
	    }
	    close(HFD);

	    return ($isssd ? "SSD" : "HDD");
	}
    }

    #
    # Try using "smartctl -i"
    #
    if (-x "$SMARTCTL") {
	if (open(HFD, "$SMARTCTL -i /dev/$dev 2>&1 |")) {
	    my $isssd = -1;
	    my $model ="";

	    while (my $line = <HFD>) {
		chomp($line);
		if ($line =~ /^rotation rate:\s+(\S.*)/i) {
		    if ($1 =~ /solid state device/i) {
			$isssd = 1;
		    } else {
			$isssd = 0;
		    }
		    last;
		}
		# XXX if we don't find rotation rate, we will fall back on this
		if ($line =~ /^device model:\s+(\S.*)/i) {
		    $model = $1;
		    next;
		}
	    }
	    close(HFD);

	    if ($isssd >= 0) {
		return ($isssd ? "SSD" : "HDD");
	    }
	    
	    #
	    # XXX older versions of smartctl (e.g., in CentOS 6-ish)
	    # don't return "Rotation Rate". This is a fall-back hack as
	    # we know that at least Intel SSDs have SSD in the model name.
	    #
	    if ($model =~ /SSD/) {
		return "SSD";
	    }
	}
    }

    # Assume it is a spinning disk.
    return "HDD";
}

#
# Return the name (e.g., "sda") of the boot disk, aka the "system volume".
#
sub get_bootdisk()
{
    my $disk = undef;
    my $line = `$MOUNT | grep ' on / '`;

    if ($line && $line =~ qr{^(/dev/\S+) on /}) {
	my $device = abs_path($1);
	if ($device &&
	    ($device =~ qr{^/dev/(nvme\S+)p\d+} ||
	     $device =~ qr{^/dev/(\S+)\d+})) {
	    $disk = $1;
	}
    }

    return $disk;
}

sub get_ptabtype($)
{
    my ($dev) = @_;

    # if device doesn't exist, assume unknown
    if (! -e "/dev/$dev") {
	return "unknown";
    }

    # if sfdisk fails, assume unknown
    my $pinfo = `$SFDISK -l /dev/$dev 2>&1`;
    if ($?) {
	return "unknown";
    }

    # if sfdisk doesn't recognize it, assume unknown
    if ($pinfo =~ /unrecognized partition table type/) {
	return "unknown";
    }

    # newer sfdisk recognizes GPT
    if ($pinfo =~ /Disklabel type: gpt/) {
	return "GPT";
    }

    # if sfdisk detects a GPT, go with it
    if ($pinfo =~ /WARNING: GPT \(GUID Partition Table\) detected/) {
	return "GPT";
    }

    # otherwise MBR
    return "MBR";
}

sub get_partsize($)
{
    my ($dev) = @_;
    my $size = 0;

    if (!open(FD, "/proc/partitions")) {
	warn("*** get_disksize: could not get disk info from /proc/partitions\n");
	return $size;
    }
    while (<FD>) {
	if (/^\s+\d+\s+\d+\s+(\d+)\s+((?:xvd|sd)[a-z][a-z]?(?:\d+)?)/ ||
	    /^\s+\d+\s+\d+\s+(\d+)\s+(nvme\d+n\d+(?:p\d+)?)/) {
	    my ($_size,$_dev) = ($1,$2);

	    if ($dev eq $_dev) {
		$size = int($_size / 1024);
		last;
	    }
	}
    }
    close(FD);

    return $size;
}

sub get_parttype($$$)
{
    my ($dev,$pnum,$pttype) = @_;

    if ($pttype eq "GPT") {
	my $looking = 0;
	my @lines = `$GDISK -l /dev/$dev 2>/dev/null`;
	chomp @lines;
	foreach my $line (@lines) {
	    if (!$looking && $line =~ /^Number\s+Start \(sector\)/) {
		$looking = 1;
		next;
	    }
	    #
	    # XXX I am afraid of ambiguity if I keep this RE too simple
	    # since we are looking for 4 hex digits for the type (code),
	    # but a simple RE could match the start or end sector or even
	    # possibly the size.
	    #
	    if ($looking &&
		$line =~ /^\s*(\d+)\s+\d+\s+\d+\s+[\d\.]+ \S+\s+([\dA-F]{4})\s/) {
		if ($1 == $pnum) {
		    return hex($2);
		}
	    }
	}

	return -1;
    }

    my $ptype = `$SFDISK /dev/$dev -c $pnum 2>/dev/null`;
    if ($? == 0 && $ptype ne "") {
	chomp($ptype);
	if ($ptype =~ /^\s*([\da-fA-F]+)$/) {
	    $ptype = hex($1);
	} else {
	    $ptype = -1;
	}
    } else {
	$ptype = -1;
    }

    return $ptype;
}

#
# Returns 1 if the volume manager has been initialized.
# For LVM this means that the "emulab" volume group exists.
# If an argument is provided, we return the number of PVs in the VG.
#
sub is_lvm_initialized($)
{
    my $pvsp = shift;

    my $vg = `vgs -o vg_name,pv_count --noheadings $VGNAME 2>/dev/null`;
    if ($vg) {
	if ($pvsp) {
	    if ($vg =~ /${VGNAME}\s+(\d+)/) {
		$$pvsp = $1;
	    } else {
		$$pvsp = 1;
	    }
	}
	return 1;
    }
    return 0;
}

#
# Get information about local disks.
#
# Ideally, this comes from the list of ELEMENTs passed in.
#
# But if that is not available, we figure it out outselves by using
# a simplified version of the libvnode findSpareDisks.
# XXX the various "get space on the local disk" mechanisms should be
# reconciled.
#
sub get_diskinfo()
{
    my %geominfo = ();

    #
    # Get the list of partitions.
    # XXX only care about xvd|sd[a-z] devices and their partitions.
    #
    if (!open(FD, "/proc/partitions")) {
	warn("*** get_diskinfo: could not get disk info from /proc/partitions\n");
	return undef;
    }
    while (<FD>) {
	if (/^\s+\d+\s+\d+\s+(\d+)\s+((?:xvd|sd)[a-z][a-z]?)(\d+)?/ ||
	    /^\s+\d+\s+\d+\s+(\d+)\s+(nvme\d+n\d+)(?:p(\d+))?/) {
	    my ($size,$dev,$part) = ($1,$2,$3);
	    # DOS partition
	    if (defined($part)) {
		my $pttype = "MBR";
		if (exists($geominfo{$dev}{'ptabtype'})) {
		    $pttype = $geominfo{$dev}{'ptabtype'};
		}

		# XXX avoid garbage and extended partitions
		next if ($pttype eq "MBR" && ($part < 1 || $part > 4));

		my $pdev = "$dev$part";
		if ($dev =~ /^nvme/) {
		    $pdev = "${dev}p${part}";
		}
		$geominfo{$pdev}{'level'} = 1;
		$geominfo{$pdev}{'type'} = "PART";
		$geominfo{$pdev}{'size'} = int($size / 1024);
		$geominfo{$pdev}{'inuse'} = get_parttype($dev, $part, $pttype);
	    }
	    # XXX iSCSI disk
	    elsif (is_iscsi_dev($dev)) {
		$geominfo{$dev}{'level'} = 0;
		$geominfo{$dev}{'type'} = "iSCSI";
		$geominfo{$dev}{'size'} = int($size / 1024);
		$geominfo{$dev}{'inuse'} = -1;
	    }
	    # raw local disk
	    else {
		$geominfo{$dev}{'level'} = 0;
		$geominfo{$dev}{'type'} = "DISK";
		$geominfo{$dev}{'size'} = int($size / 1024);
		$geominfo{$dev}{'inuse'} = 0;
		$geominfo{$dev}{'ptabtype'} = get_ptabtype($dev);
		$geominfo{$dev}{'disktype'} = get_disktype($dev);
	    }
	}
    }
    close(FD);

    # XXX watch out for mounted disks/partitions (DOS type may be 0)
    if (!open(FD, "$FSTAB")) {
	warn("*** get_diskinfo: could not get mount info from $FSTAB\n");
	return undef;
    }
    while (<FD>) {
	if (/^\/dev\/((?:xvd|sd|nvme)\S+)/) {
	    my $dev = $1;
	    if (exists($geominfo{$dev}) && $geominfo{$dev}{'inuse'} == 0) {
		$geominfo{$dev}{'inuse'} = -1;
	    }
	}
    }
    close(FD);

    #
    # Make a pass through and mark disks that are in use where "in use"
    # means "has a partition".
    #
    foreach my $dev (keys %geominfo) {
	if ($geominfo{$dev}{'type'} eq "PART" &&
	    $geominfo{$dev}{'level'} == 1 &&
	    ($dev =~ /^(nvme\d+n\d+)p\d+$/ || $dev =~ /^(.*)\d+$/)) {
	    if (exists($geominfo{$1}) && $geominfo{$1}{'inuse'} == 0) {
		$geominfo{$1}{'inuse'} = 1;
	    }
	}
    }

    #
    # Find disks/partitions in use by LVM and update the available size
    #
    if (open(FD, "pvs -o pv_name,pv_size --units m --noheadings|")) {
	while (<FD>) {
	    if (/^\s+\/dev\/(\S+)\s+(\d+)\.\d+m$/) {
		my $dev = $1;
		my $size = $2;
		$geominfo{$dev}{'size'} = $size;
		$geominfo{$dev}{'inuse'} = -1;
	    }
	}
	close(FD);
    }
    #
    # See if there are any volume groups.
    # We don't care about the specific output
    #
    my $gotvgs = 0;
    my $vgs = `vgs -o vg_name --noheadings 2>/dev/null`;
    if ($vgs) {
	$gotvgs = 1;
    }

    #
    # Record any LVs as well.
    # We only do this if we know there are volume groups, else lvs will fail.
    #
    if ($gotvgs &&
	open(FD, "lvs -o vg_name,lv_name,lv_size,lv_attr --units m --noheadings|")) {
	while (<FD>) {
	    if (/^\s+(\S+)\s+(\S+)\s+(\d+)\.\d+m\s+([-a-zA-Z]{9,})$/) {
		my $vg = $1;
		my $lv = $2;
		my $size = $3;
		my $attrs = $4;
		my $dev = "$vg/$lv";

		$geominfo{$dev}{'level'} = 2;
		$geominfo{$dev}{'type'} = "LVM";
		$geominfo{$dev}{'size'} = $size;
		$geominfo{$dev}{'inuse'} = 1;
		if ($attrs =~ /^....a/) {
		    $geominfo{$dev}{'active'} = 1;
		} else {
		    $geominfo{$dev}{'active'} = 0;
		}
	    }
	}
	close(FD);
    }

    return \%geominfo;
}

#
# See if this is a filesystem type we can deal with.
# If so, return the type suitable for use by fsck and mount.
#
sub get_fstype($$;$$)
{
    my ($href,$dev,$rwref,$silent) = @_;
    my $type = "";

    #
    # If there is an explicit type set, believe it.
    #
    if (exists($href->{'FSTYPE'})) {
	$type = $href->{'FSTYPE'};
    }

    #
    # No explicit type set, see if we can intuit what the FS is.
    #
    else {
	my $blkid = `$BLKID -s TYPE -o value $dev`;
	if ($? == 0) {
	    chomp($blkid);
	    $type = $blkid;
	}

	if ($type && !exists($href->{'FSTYPE'})) {
	    $href->{'FSTYPE'} = $type;
	}
    }

    # ext? is okay
    if ($type =~ /^ext[234]$/) {
	if ($rwref) {
	    $$rwref = 1;
	}
	return $type;
    }

    # UFS can be mounted RO
    if ($type eq "ufs") {
	if ($rwref) {
	    $$rwref = 0;
	}
	return "ufs";
    }

    if (!$silent) {
	my $lv = $href->{'VOLNAME'};
	if ($type) {
	    warn("*** $lv: unsupported FS ($type) on $dev\n");
	} else {
	    warn("*** $lv: unknown or no FS on $dev\n");
	}
    }
    if ($rwref) {
	$$rwref = 0;
    }
    return undef;
}

#
# Check that the device for a blockstore has a valid filesystem by
# fscking it. If $fixit is zero, run the fsck RO just to report if
# the filesystem is there and consistent, otherwise attempt to fix it.
# $redir is a redirect string for output of the fsck command.
#
# Returns 1 if all is well, 0 otherwise.
#
sub checkfs($$$)
{
    my ($href,$fixit,$redir) = @_;
    my $lv = $href->{'VOLNAME'};
    my $mdev = $href->{'LVDEV'};

    # determine the filesystem type
    my $fstype = get_fstype($href, $mdev);
    if (!$fstype) {
	return 0;
    }

    my $fopt = "-p";
    if (!$fixit || $href->{'PERMS'} eq "RO") {
	$fopt = "-n";
    }

    # XXX cannot fsck ufs, right now we just pretend everything is okay
    if ($fstype ne "ufs") {
	my $rv = mysystem("$FSCK $fopt $mdev $redir");

	# Linux e2fsck returns 1 on corrected errors
	if ($rv && $rv != (1 << 8)) {
	    warn("*** $lv: fsck of $mdev failed ($rv)\n");
	    return 0;
	}
    }

    return 1;
}

sub set_iname($$)
{
    my ($iqn,$redir) = @_;

    if (!defined($iqn)) {
	warn("*** storage: could not determine IQN prefix, initiator name is not unique!\n");
	return 0;
    }

    my $hname = `hostname 2>/dev/null`;
    chomp($hname);

    # See if the existing initiator name is correct
    my $iname = "$iqn:$hname";
    if (open(FD, "<$ISCSINAME")) {
	while (<FD>) {
	    if (/^InitiatorName=(.*)/) {
		# existing name is correct
		if ($1 eq $iname) {
		    close(FD);
		    return 1;
		}
	    }
	}
	close(FD);
    }

    # name is incorrect, try setting it
    if (!open(FD, ">$ISCSINAME")) {
	warn("*** storage: unable to set unique initiator name!\n");
	return 0;
    }

    print FD "# Created by Emulab liblocstorage.pm\n";
    print FD "InitiatorName=$iname\n";
    close(FD);

    #
    # XXX iscsid might already be running with the wrong initiator name.
    # So, we need to logout of all sessions:
    #   iscsiadm -m node -U all
    # restart services:
    #   systemctl restart iscsid open-iscsi
    # and login again:
    #   iscsiadm -m node -L all
    #
    # XXX we only do this for Ubuntu 16 and beyond where we know that iscsid
    # is enabled by default. Conveniently, we can use the existence of systemctl
    # as an indicator. Basically, we don't care about Ubuntu 14 and before
    # except to not break it.
    #
    if (-x "/bin/systemctl") {
	my $nsess = `$ISCSI -m session 2>/dev/null | grep -c ^`;
	chomp($nsess);
	if ($nsess != 0 && mysystem("$ISCSI -m node -U all $redir")) {
	    warn("*** storage: could not logout of iscsi sessions!\n");
	}
	if (mysystem("/bin/systemctl restart iscsid open-iscsi $redir")) {
	    warn("*** storage: could not restart iscsi daemons!\n");
	}
	if ($nsess != 0 && mysystem("$ISCSI -m node -L all $redir")) {
	    warn("*** storage: could not login to iscsi sessions!\n");
	}
    } else {
	# restart iscsid
	if (mysystem("service open-iscsi restart $redir")) {
	    warn("*** storage: could not restart iscsid!\n");
	}
    }
    return 1;
}

#
# Handle one-time operations.
# Return a cookie (object) with current state of storage subsystem.
#
sub os_init_storage($)
{
    my ($lref) = @_;
    my $redir = ">/dev/null 2>&1";

    my $gotlocal = 0;
    my $gotnonlocal = 0;
    my $gotelement = 0;
    my $gotslice = 0;
    my $gotiscsi = 0;
    my $needavol = 0;
    my $needall = 0;
    my $iqn;

    my %so = ();

    #
    # If we are running on the outside of a Docker container, but on its
    # behalf, we want to do some things differently.
    #
    if (ISFORDOCKERVM()) {
	$FSTAB = CONFDIR()."/fstab-storage";
	$MOUNT .= " --fstab $FSTAB";
	#$UMOUNT .= " --fstab $FSTAB";
	if (! -e $FSTAB) {
	    open(FD,">$FSTAB");
	    close(FD);
	}
    }

    foreach my $href (@{$lref}) {
	if ($href->{'CMD'} eq "ELEMENT") {
	    $gotelement++;
	} elsif ($href->{'CMD'} eq "SLICE") {
	    $gotslice++;
	    if ($href->{'BSID'} eq "SYSVOL" ||
		$href->{'BSID'} eq "NONSYSVOL") {
		$needavol = 1;
	    } elsif ($href->{'BSID'} eq "ANY") {
		$needall = 1;
	    }
	}
	if ($href->{'CLASS'} eq "local") {
	    $gotlocal++;
	} else {
	    $gotnonlocal++;
	    if ($href->{'PROTO'} eq "iSCSI") {
		$gotiscsi++;
		if (!defined($iqn) && defined($href->{'UUID'})) {
		    if ($href->{'UUID'} =~ /^([^:]+):/) {
			$iqn = $1;
		    }
		}
	    }
	}
    }

    if ($gotlocal) {
	# check for local storage incompatibility
	if ($needall && $needavol) {
	    warn("*** storage: Incompatible local volumes.\n");
	    return undef;
	}
	
	# initialize mapping of serial numbers to devices
	if ($gotelement) {
	    $so{'LOCAL_SNMAP'} = init_serial_map();
	}

	# initialize volume manage if needed for local slices
	if ($gotslice) {
	    #
	    # Allow for the volume group to exist.
	    #
	    my $pvs = 1;
	    if (is_lvm_initialized(\$pvs)) {
		$so{'LVM_VGCREATED'} = 1;
		$so{'LVM_VGDEVS'} = $pvs;
	    }

	    #
	    # Grab the bootdisk and current GEOM state
	    #
	    my $bdisk = get_bootdisk();
	    my $ginfo = get_diskinfo();
	    if (!exists($ginfo->{$bdisk}) || $ginfo->{$bdisk}->{'inuse'} == 0) {
		warn("*** storage: bootdisk '$bdisk' marked as not in use!?\n");
		return undef;
	    }

	    #
	    # Boot disk should have a partition table type
	    #
	    if (!exists($ginfo->{$bdisk}->{'ptabtype'})) {
		warn("*** storage: bootdisk '$bdisk' does not have partition table type!?\n");
		return undef;
	    }

	    $so{'BOOTDISK'} = $bdisk;
	    $so{'DISKINFO'} = $ginfo;
	}
    }

    if ($gotiscsi) {
	#
	# Make sure client has the correct initiator IQN, otherwise fix it.
	#
	set_iname($iqn, $redir);

	if (! -x "$ISCSI") {
	    if (! -x "$ISCSI_ALT") {
		warn("*** storage: $ISCSI does not exist, cannot continue\n");
		return undef;
	    }
	    $ISCSI = $ISCSI_ALT;
	}
	#
	# XXX don't grok the Ubuntu startup, so...
	# make sure automatic sessions are started
	#
	my $nsess = `$ISCSI -m session 2>/dev/null | grep -c ^`;
	chomp($nsess);
	if ($nsess == 0) {
	    mysystem("$ISCSI -m node --loginall=automatic $redir");
	}
    }

    $so{'INITIALIZED'} = 1;
    return \%so;
}

sub os_get_diskinfo($)
{
    my ($so) = @_;

    return get_diskinfo();
}

#
# XXX debug
#
sub os_show_storage($)
{
    my ($so) = @_;

    my $bdisk = $so->{'BOOTDISK'};
    print STDERR "OS Dep info:\n";
    print STDERR "  BOOTDISK=$bdisk\n" if ($bdisk);

    my $dinfo = get_diskinfo();
    if ($dinfo) {
	print STDERR "  DISKINFO:\n";
	foreach my $dev (sort keys %$dinfo) {
	    my $type = $dinfo->{$dev}->{'type'};
	    my $lev = $dinfo->{$dev}->{'level'};
	    my $size = $dinfo->{$dev}->{'size'};
	    my $inuse = sprintf("%X", $dinfo->{$dev}->{'inuse'});
	    print STDERR "    name=$dev, type=$type, level=$lev, size=$size, inuse=$inuse";
	    if ($type eq "DISK") {
		print STDERR ", disktype=", $dinfo->{$dev}->{'disktype'},
		    ", pttype=", $dinfo->{$dev}->{'ptabtype'};
	    }
	    elsif ($type eq "LVM") {
		print STDERR ", active=", $dinfo->{$dev}->{'active'};
	    }
	    print STDERR "\n";
	}
    }

    # LOCAL_SNMAP
    my $snmap = $so->{'LOCAL_SNMAP'};
    if ($so->{'LOCAL_SNMAP'}) {
	my $snmap = $so->{'LOCAL_SNMAP'};

	print STDERR "  LOCAL_SNMAP:\n";
	foreach my $sn (keys %$snmap) {
	    print STDERR "    $sn -> ", $snmap->{$sn}, "\n";
	}
    }
}

#
# os_check_storage(sobject,confighash)
#
#   Determines if the storage unit described by confighash exists and
#   is properly configured. Returns zero if it doesn't exist, 1 if it
#   exists and is correct, -1 otherwise.
#
#   Side-effect: Creates the hash member $href->{'LVDEV'} with the /dev
#   name of the storage unit.
#
sub os_check_storage($$)
{
    my ($so,$href) = @_;

    if ($href->{'CMD'} eq "ELEMENT") {
	return os_check_storage_element($so,$href);
    }
    if ($href->{'CMD'} eq "SLICE") {
	return os_check_storage_slice($so,$href);
    }
    return -1;
}

sub _docker_get_ext_trans_mountpoint($)
{
    my ($mpoint,) = @_;

    my $confdir = CONFDIR();
    my $tmpoint = `readlink -f $confdir/mountpoints`;
    chomp($tmpoint);
    if ($mpoint =~ /^$tmpoint/) {
	return $mpoint;
    }
    else {
	$mpoint = $tmpoint.$mpoint;
    }
    if (! -e $mpoint) {
	my @dirs = split(/\//,$mpoint);
	my $tpath = CONFDIR()."/mountpoints";
	foreach my $dir (@dirs) {
	    $tpath .= "/$dir";
	    mkdir($tpath);
	}
    }

    return $mpoint;
}

sub os_check_storage_element($$)
{
    my ($so,$href) = @_;
    my $CANDISCOVER = 0;
    my $redir = ">/dev/null 2>&1";

    #
    # iSCSI:
    #  make sure the IQN exists
    #  make sure a session exists
    #
    if ($href->{'CLASS'} eq "SAN" && $href->{'PROTO'} eq "iSCSI") {
	my $hostip = $href->{'HOSTIP'};
	my $uuid = $href->{'UUID'};
	my $bsid = $href->{'VOLNAME'};
	my @lines;

	#
	# See if the block store exists on the indicated server.
	# If not, something is very wrong, return -1.
	#
	# Note that the server may not support discovery. If not, we don't
	# do it since it is only a sanity check anyway.
	#
	if ($CANDISCOVER) {
	    @lines = `$ISCSI -m discovery -t sendtargets -p $hostip 2>&1`;
	    if ($? != 0) {
		warn("*** could not find exported iSCSI block stores\n");
		return -1;
	    }
	    if (!grep(/$uuid/, @lines)) {
		warn("*** could not find iSCSI block store '$uuid'\n");
		return -1;
	    }
	}

	#
	# It exists, are we connected to it?
	# If not, we have not done the one-time initialization, return 0.
	#
	my $session;
	@lines = `$ISCSI -m session 2>&1`;
	foreach (@lines) {
	    if (/^tcp: \[(\d+)\].*$uuid\b/) {
		$session = $1;
		last;
	    }
	}
	if (!defined($session)) {
	    return 0;
	}

	#
	# If there is no session, we have a problem.
	#
	my $dev = iscsi_to_dev($session);
	if (!defined($dev)) {
	    #
	    # XXX apparently the device may not show up immediately,
	    # so pause and try again.
	    #
	    sleep(1);
	    $dev = iscsi_to_dev($session);
	    if (!defined($dev)) {
		warn("*** $bsid: found iSCSI session but could not determine local device\n");
		return -1;
	    }
	}

	$href->{'LVDEV'} = "/dev/$dev";

	#
	# If there is a mount point, see if it is mounted.
	#
	# XXX because mounts in /etc/fstab happen before iSCSI and possibly
	# even the network are setup, we don't put our mounts there as we
	# do for local blockstores. Thus, if the blockstore device is not
	# mounted, we do it here.
	#
	# NB: also, for the Docker case where we setup blockstore access
	# outside the container, we make alternative $FSTAB entries!
	#
	my $mpoint = $href->{'MOUNTPOINT'};
	if ($mpoint) {
	    if (ISFORDOCKERVM()) {
		$mpoint = $href->{'MOUNTPOINT'} =
		    _docker_get_ext_trans_mountpoint($mpoint);
	    }

	    my $mdev = $href->{'LVDEV'};
	    my $mopt = "";

	    my $line = `$MOUNT | grep '^$mdev on '`;
	    if (!$line) {
		# determine the filesystem type
		my $rw = 0;
		my $fstype = get_fstype($href, $mdev, \$rw);
		if (!$fstype) {
		    return -1;
		}

		# check for RO export and adjust options accordingly
		if ($href->{'PERMS'} eq "RO") {
		    $mopt = "-o ro";
		    # XXX for ufs
		    if ($fstype eq "ufs") {
			$mopt .= ",ufstype=ufs2";
		    } elsif ($fstype eq "ext3" || $fstype eq "ext4") {
			$mopt .= ",noload";
		    }
		}
		# OS only supports RO mounting, right now we just fail
		elsif ($rw == 0) {
		    warn("*** $bsid: OS only supports RO mounting of ".
			 "$fstype FSes\n");
		    return -1;
		}

		# the mountpoint should exist
		if (! -d "$mpoint") {
		    warn("*** $bsid: no mount point $mpoint\n");
		    return -1;
		}

		# fsck the filesystem in case of an abrupt shutdown.
		if (!checkfs($href, 1, $redir)) {
		    return -1;
		}

		# and mount it
		if (mysystem("$MOUNT $mopt $mdev $mpoint $redir")) {
		    warn("*** $bsid: could not mount $mdev on $mpoint\n");
		    return -1;
		}
	    }
	    elsif ($line !~ /^${mdev} on (\S+) / || $1 ne $mpoint) {
		warn("*** $bsid: mounted on $1, should be on $mpoint\n");
		return -1;
	    }
	}

	# XXX set the fstype for reporting
	if (!exists($href->{'FSTYPE'})) {
	    get_fstype($href, "/dev/$dev");
	}

	return 1;
    }

    #
    # local disk:
    #  make sure disk exists
    #
    if ($href->{'CLASS'} eq "local") {
	my $bsid = $href->{'VOLNAME'};
	my $sn = $href->{'UUID'};

	my $dev = serial_to_dev($so, $sn);
	if (defined($dev)) {
	    $href->{'LVDEV'} = "/dev/$dev";
	    return 1;
	}

	# XXX not an error for now, until we can be sure that we can
	# get SN info for all disks
	$href->{'LVDEV'} = "<UNKNOWN>";
	return 1;

	# for physical disks, there is no way to "create" it so return error
	warn("*** $bsid: could not find HD with serial '$sn'\n");
	return -1;
    }

    warn("*** $bsid: unsupported class/proto '" .
	 $href->{'CLASS'} . "/" . $href->{'PROTO'} . "'\n");
    return -1;
}

#
# Return 0 if does not exist
# Return 1 if exists and correct
# Return -1 otherwise
#
sub os_check_storage_slice($$)
{
    my ($so,$href) = @_;
    my $bsid = $href->{'BSID'};

    #
    # local storage:
    #  if BSID==SYSVOL:
    #    see if 4th part of boot disk exists (eg: da0s4) and
    #    is of type linux
    #  else if BSID==NONSYSVOL:
    #    see if there is a logical volume with appropriate name
    #  else if BSID==ANY:
    #    see if there is a logical volume with appropriate name
    #  if there is a mountpoint, see if it exists in $FSTAB
    #
    if ($href->{'CLASS'} eq "local") {
	my $lv = $href->{'VOLNAME'};
	my ($dev, $devtype, $rdev);

	my $ginfo = $so->{'DISKINFO'};
	my $bdisk = $so->{'BOOTDISK'};
	my $pttype = "MBR";
	my $slop = 0;

	# figure out the device of interest
	if ($bsid eq "SYSVOL") {
	    my $pchr = "";
	    if ($bdisk =~ /^nvme/) {
		$pchr = "p";
	    }
	    $dev = $rdev = "${bdisk}${pchr}4";
	    $devtype = "PART";
	    $pttype = $ginfo->{$bdisk}->{'ptabtype'};
	} else {
	    $dev = "$VGNAME/$lv";
	    # XXX the real path is returned by mount
	    # XXX note that any '-'s in the mapper name are doubled
	    (my $rlv = $lv) =~ s/-/--/g;
	    $rdev = "mapper/${VGNAME}-$rlv";
	    $devtype = "LVM";
	    # XXX LVM rounds up to physical extent size (4 MiB)
	    # on every physical volume that is in the VG
	    if (exists($so->{'LVM_VGDEVS'}) && $so->{'LVM_VGDEVS'} > 1) {
		$slop = (4 * $so->{'LVM_VGDEVS'}) - 1;
	    } else {
		$slop = 3;
	    }
	}
	my $devsize = $href->{'VOLSIZE'};

	# if the device does not exist, return 0
	if (!exists($ginfo->{$dev})) {
	    return 0;
	}
	# if it exists but is of the wrong type, we have a problem!
	my $atype = $ginfo->{$dev}->{'type'};
	if ($atype ne $devtype) {
	    warn("*** $lv: actual type ($atype) != expected type ($devtype)\n");
	    return -1;
	}
	#
	# Ditto for size, unless this is the SYSVOL where we ignore user size
	# or if the size was not specified.
	#
	my $asize = $ginfo->{$dev}->{'size'};
	if ($bsid ne "SYSVOL" && $devsize &&
	    !($asize >= $devsize && $asize <= $devsize + $slop)) {
	    warn("*** $lv: actual size ($asize) != expected size ($devsize)\n");
	    return -1;
	}

	# for the system disk, ensure partition is not in use
	if ($bsid eq "SYSVOL") {
	    # XXX inuse for a partition is set to MBR/GPT type
	    my $ptype = $ginfo->{$dev}->{'inuse'};
	    my $linuxid = ($pttype eq "GPT") ? 0x8300 : 0x83;

	    # if type is 0, it is not setup
	    if ($ptype == 0) {
		return 0;
	    }
	    # ow, if not a Linux FS partition, there is a problem 
	    if ($ptype != $linuxid) {
		warn("*** $lv: $dev already in use (type $ptype)\n");
		return -1;
	    }
	}

	#
	# If it is an LVM, may sure it is active.
	#
	if ($devtype eq "LVM" && $ginfo->{$dev}->{'active'} == 0) {
	    if (mysystem("lvchange -ay $dev")) {
		warn("*** $lv: could not activate LV $dev\n");
		return -1;
	    }
	    sleep(1);
	}

	#
	# If there is a mountpoint, make sure it is mounted.
	#
	my $mpoint = $href->{'MOUNTPOINT'};
	if ($mpoint) {
	    if (ISFORDOCKERVM()) {
		$mpoint = $href->{'MOUNTPOINT'} =
		    _docker_get_ext_trans_mountpoint($mpoint);
	    }

	    my $line = `$MOUNT | grep '^/dev/$rdev on '`;
	    if (!$line) {
		#
		# See if the mount exists in $FSTAB.
		#
		# XXX Right now if it does not, it might be because we
		# removed it prior to creating an image. So we make some
		# additional sanity checks (right now fsck'ing the alleged FS)
		# and if it passes, re-add the mount line.
		#
		# XXX It might also be because we have re-loaded the OS
		# and not only the fstab line but the mountpoint might be
		# missing. We attempt to repair this case as well.
		#
		$line = `grep '^/dev/$dev\[\[:space:\]\]' $FSTAB`;
		if (!$line) {
		    warn("  $lv: mount of /dev/$dev missing from fstab; sanity checking and re-adding...\n");
		    my $fstype = get_fstype($href, "/dev/$dev");
		    if (!$fstype) {
			return -1;
		    }

		    # XXX sanity check, is there a recognized FS on the dev?
		    # XXX checkfs needs LVDEV set
		    $href->{'LVDEV'} = "/dev/$dev";
		    if (!checkfs($href, 0, "")) {
			undef $href->{'LVDEV'};
			return -1;
		    }
		    undef $href->{'LVDEV'};

		    # make sure the mount point exists (case of reloaded OS)
		    if (! -d "$mpoint" &&
			mysystem("$MKDIR -p $mpoint")) {
			warn("*** $lv: could not create mountpoint '$mpoint'\n");
			return -1;
		    }

		    if (!open(FD, ">>$FSTAB")) {
			warn("*** $lv: could not add mount to $FSTAB\n");
			return -1;
		    }
		    print FD "# /dev/$dev added by $BINDIR/rc/rc.storage\n";
		    print FD "/dev/$dev\t$mpoint\t$fstype\tdefaults\t0\t0\n";
		    close(FD);
		}

		if (mysystem("$MOUNT $mpoint")) {
		    warn("*** $lv: is not mounted, should be on $mpoint\n");
		    return -1;
		}
	    } else {
		if ($line !~ /^\/dev\/$rdev on (\S+) / || $1 ne $mpoint) {
		    warn("*** $lv: mounted on $1, should be on $mpoint\n");
		    return -1;
		}
	    }
	}

	# XXX set the fstype for reporting
	if (!exists($href->{'FSTYPE'})) {
	    get_fstype($href, "/dev/$dev");
	}
	$href->{'LVDEV'} = "/dev/$dev";
	return 1;
    }

    warn("*** $bsid: unsupported class '" . $href->{'CLASS'} . "'\n");
    return -1;
}

#
# os_create_storage(confighash)
#
#   Create the storage unit described by confighash. Unit must not exist
#   (os_check_storage should be called first to verify). Return one on
#   success, zero otherwise.
#
sub os_create_storage($$)
{
    my ($so,$href) = @_;
    my $fstype;
    my $rv = 0;

    # record all the output for debugging
    my $log = "/var/emulab/logs/" . $href->{'VOLNAME'} . ".out";
    mysystem("cp /dev/null $log");

    if ($href->{'CMD'} eq "ELEMENT") {
	$rv = os_create_storage_element($so, $href, $log);
    }
    elsif ($href->{'CMD'} eq "SLICE") {
	$rv = os_create_storage_slice($so, $href, $log);
    }
    if ($rv == 0) {
	return 0;
    }

    my $mopt = "";

    if (exists($href->{'MOUNTPOINT'})) {
	my $lv = $href->{'VOLNAME'};
	my $mdev = $href->{'LVDEV'};

	# record all the output for debugging
	my $redir = "";
	my $logmsg = "";
	if ($log) {
	    $redir = ">>$log 2>&1";
	    $logmsg = ", see $log";
	}

	#
	# If this is a persistent iSCSI disk, we never create the filesystem!
	# Instead, we fsck it in case it was not shutdown cleanly in its
	# previous existence.
	#
	if ($href->{'CLASS'} eq "SAN" && $href->{'PROTO'} eq "iSCSI" &&
	    $href->{'PERSIST'} != 0) {

	    # check for the easy errors first, before time consuming fsck
	    my $rw = 0;
	    $fstype = get_fstype($href, $mdev, \$rw);
	    if (!$fstype) {
		return 0;
	    }

	    # check for RO export and adjust mount options accordingly
	    if ($href->{'PERMS'} eq "RO") {
		$mopt = "-o ro";
		# XXX for ufs
		if ($fstype eq "ufs") {
		    $mopt .= ",ufstype=ufs2";
		} elsif ($fstype eq "ext3" || $fstype eq "ext4") {
		    $mopt .= ",noload";
		}
	    }
	    # OS only supports RO mounting, right now we just fail
	    elsif ($rw == 0) {
		warn("*** $lv: OS only supports RO mounting of ".
		     "$fstype FSes\n");
		return 0;
	    }

	    # finally do the fsck, fixing errors if possible
	    if (!checkfs($href, 1, $redir)) {
		return 0;
	    }
	}
	elsif (exists($href->{'DATASET'})) {
	    #
	    # Load with the dataset.
	    #
	    my $proxyopt   = "";
	    my $imageid    = $href->{'DATASET'};
	    my $imagepath  = $mdev;
	    my $server     = $href->{'SERVER'};

	    if (SHAREDHOST()) {
		my $TMNODEID  = TMNODEID();
		my $node_id   = `cat $TMNODEID`;
		chomp($node_id);
		$proxyopt = "-P $nodeid";
	    }

	    # Allow the server to enable heartbeat reports in the client
	    my $heartbeat = "-H 0";

	    my $command = "$FRISBEE -f -M 128 $proxyopt $heartbeat ".
		"-S $server -B 30 -F $imageid $imagepath";

	    print STDERR "$command\n";

	    if (mysystem("$command $redir")) {
		warn("*** $lv: frisbee of dataset to $mdev failed!\n");
		return 0;
	    }
	    $fstype = get_fstype($href, $mdev);
	    if (!$fstype) {
		return 0;
	    }
	}
	#
	# Otherwise, create the filesystem:
	#
	# Start by trying ext4 which is much faster when creating large FSes.
	# Otherwise fall back on ext3 and then ext2.
	#
	else {
	    my $failed = 1;
	    my $fsopts;
	    if ($failed) {
		$fstype = "ext4";
		$fsopts = "-F -q -E lazy_itable_init=1,nodiscard";
		#
		# XXX temporary hack for 32-bit only imagezip.
		# If the dataset size is less than 2TB, we make sure that
		# the 64bit feature is not set. Otherwise, we cannot take
		# a snapshot of the dataset (until imagezip is enhanced!)
		#
		my $vsize = $href->{'VOLSIZE'};
		if ($vsize < (2 * 1024 * 1024)) {
		    warn("  $lv: removing 64-bit feature from FS on $mdev\n");
		    $fsopts .= " -O ^64bit,^huge_file";
		}
		$failed = mysystem("$MKFS -t $fstype $fsopts $mdev $redir");
	    }
	    if ($failed) {
		$fstype = "ext3";
		$fsopts = "-F -q";
		$failed = mysystem("$MKFS -t $fstype $fsopts $mdev $redir");
	    }
	    if ($failed) {
		$fstype = "ext2";
		$fsopts = "-F -q";
		$failed = mysystem("$MKFS -t $fstype $fsopts $mdev $redir");
	    }
	    if ($failed) {
		warn("*** $lv: could not create FS\n");
		return 0;
	    }
	}

	#
	# Mount the filesystem
	#
	my $mpoint = $href->{'MOUNTPOINT'};
	if (defined($mpoint) && ISFORDOCKERVM()) {
	    $mpoint = $href->{'MOUNTPOINT'} =
		_docker_get_ext_trans_mountpoint($mpoint);
	}

	if (! -d "$mpoint" && mysystem("$MKDIR -p $mpoint $redir")) {
	    warn("*** $lv: could not create mountpoint '$mpoint'$logmsg\n");
	    return 0;
	}

	#
	# XXX because mounts in $FSTAB happen before iSCSI and possibly
	# even the network are setup, we don't put our mounts there as we
	# do for local blockstores. Instead, the check_storage call will
	# take care of these mounts.
	#
	if (!($href->{'CLASS'} eq "SAN" && $href->{'PROTO'} eq "iSCSI")) {
	    if (!open(FD, ">>$FSTAB")) {
		warn("*** $lv: could not add mount to $FSTAB\n");
		return 0;
	    }
	    print FD "# $mdev added by $BINDIR/rc/rc.storage\n";
	    print FD "$mdev\t$mpoint\t$fstype\tdefaults\t0\t0\n";
	    close(FD);
	    if (mysystem("$MOUNT $mpoint $redir")) {
		warn("*** $lv: could not mount on $mpoint$logmsg\n");
		return 0;
	    }
	} else {
	    if (mysystem("$MOUNT $mopt -t $fstype $mdev $mpoint $redir")) {
		warn("*** $lv: could not mount $mdev on $mpoint$logmsg\n");
		return 0;
	    }
	}
    }

    return 1;
}

sub os_create_storage_element($$$)
{
    my ($so,$href,$log) = @_;

    if ($href->{'CLASS'} eq "SAN" && $href->{'PROTO'} eq "iSCSI") {
	my $hostip = $href->{'HOSTIP'};
	my $uuid = $href->{'UUID'};
	my $bsid = $href->{'VOLNAME'};

	# record all the output for debugging
	my $redir = "";
	my $logmsg = "";
	if ($log) {
	    $redir = ">>$log 2>&1";
	    $logmsg = ", see $log";
	}

	#
	# Perform one time iSCSI operations
	#
	if (mysystem("$ISCSI -m node -T $uuid -p $hostip -o new $redir")) {
	    warn("*** $bsid: first-time init failed; Could not create DB record.\n");
	    return 0;
	}
	if (mysystem("$ISCSI -m node -T $uuid -p $hostip -o update -n node.startup -v manual $redir")) {
	    warn("*** $bsid: first-time init failed; Could not update DB record.\n");
	    return 0;
	}
	    
	#
	# XXX It may take some time for the server to respond on a first
	# boot as it may be setting up many blockstores. So we retry the
	# initial operation for awhile. The default iscsiadm timeout for
	# connecting is 120 seconds, which we will retry 10 times for a
	# total of 20 minutes. Note that the swapin node boot timeout will
	# probably trigger before that, but rebooting the node will be
	# okay here.
	#
	my $rv = 0;
	for (my $tries = 0; $tries < int($SESSION_TIMEOUT/120); $tries++) {
	    $rv = mysystem("$ISCSI -m node -T $uuid -p $hostip -l $redir");
	    # exit code 8 indicates timeout
	    last
		if ($rv != 0x800);
	    warn("*** $bsid: could not connect to portal $hostip, retrying...\n");
	}
	if ($rv) {
	    warn("*** $bsid: first-time init failed; Could not login session.\n");
	    return 0;
	}

	#
	# Make sure we are connected
	#
	my $session;
	@lines = `$ISCSI -m session 2>&1`;
	foreach (@lines) {
	    chomp;
	    if (/^tcp: \[(\d+)\].*$uuid\b/) {
		$session = $1;
		last;
	    }
	}
	if (!defined($session)) {
	    warn("*** Could not locate session for block store $bsid (uuid=$uuid)\n");
	    return 0;
	}

	#
	# Map to a local device.
	#
	my $dev = iscsi_to_dev($session);
	if (!defined($dev)) {
	    #
	    # XXX apparently the device may not show up immediately,
	    # so pause and try again.
	    #
	    sleep(1);
	    $dev = iscsi_to_dev($session);
	    if (!defined($dev)) {
		warn("*** $bsid: could not map iSCSI session to device\n");
		return 0;
	    }
	}

	$href->{'LVDEV'} = "/dev/$dev";
	return 1;
    }

    warn("*** Only support iSCSI now\n");
    return 0;
}

sub os_create_storage_slice($$$)
{
    my ($so,$href,$log) = @_;
    my $bsid = $href->{'BSID'};

    #
    # local storage:
    #  if BSID==SYSVOL:
    #     create the 4th part of boot disk with type Linux,
    #	  create a native filesystem (that imagezip would understand).
    #  else if BSID==NONSYSVOL:
    #	  create an LVM PV/VG from all available extra hard drives
    #	  (one-time), create LV with appropriate name from VG.
    #  else if BSID==ANY:
    #	  create an LVM PV/VG from all available space (part 4 on sysvol,
    #	  extra hard drives), create LV with appropriate name from VG.
    #  if there is a mountpoint:
    #     create a filesystem on device, mount it, add to $FSTAB
    #
    if ($href->{'CLASS'} eq "local") {
	my $lv = $href->{'VOLNAME'};
	my $lvsize = $href->{'VOLSIZE'};
	my $mdev = "";

	my $bdisk = $so->{'BOOTDISK'};
	my $ginfo = $so->{'DISKINFO'};

	# record all the output for debugging
	my $redir = "";
	my $logmsg = "";
	if ($log) {
	    $redir = ">>$log 2>&1";
	    $logmsg = ", see $log";
	}

	#
	# In GPT, there is no such thing as an "unused" partition.
	# If a partition exists, it has a non-zero type and we treat
	# it as in use. Hence, we have to create the partitions we
	# use. For SYSVOL, this is easy. We just tell sgdisk to create
	# parititon 4 using the biggest chunk of space available on
	# the boot disk. For NONSYSVOL or ANY, we may have to create
	# GPTs and find the available space. Or we may have a mix of
	# GPT and MBR disks.
	#
	# XXX For now we just implement the SYSVOL case since we only
	# use this on Moonshot boxes that have a single disk.
	#

	#
	# System volume:
	#
	# dostype -f /dev/sda 4 131
	#
	if ($bsid eq "SYSVOL") {
	    my $pchr = "";
	    if ($bdisk =~ /^nvme/) {
		$pchr = "p";
	    }
	    $mdev = "${bdisk}${pchr}4";

	    if ($ginfo->{$bdisk}->{'ptabtype'} eq "GPT") {
		if (exists($ginfo->{$mdev})) {
		    warn("*** $lv: ugh! $mdev already exists\n");
		    return 0;
		}
		if (mysystem("$SGDISK -n 4:0:0 -t 4:8300 ".
			     "/dev/$bdisk $redir") ||
		    mysystem("$PPROBE /dev/$bdisk $redir")) {
		    warn("*** $lv: could not create $mdev$logmsg\n");
		    return 0;
		}

		# XXX make sure there is enough space to be useful
		my $p4size = get_partsize($mdev);
		if ($p4size < 10) {
		    warn("*** less than 10MiB available on system volume!\n");
		    mysystem("$SGDISK -d 4 /dev/$bdisk $redir");
		    return 0;
		}

		# XXX create DISKINFO entry for partition
		$ginfo->{$mdev}->{'type'} = "PART";
		$ginfo->{$mdev}->{'level'} = 1;
		$ginfo->{$mdev}->{'size'} = $p4size;
		$ginfo->{$mdev}->{'inuse'} = hex("8300");
	    } else {
		if (mysystem("$DOSTYPE -f /dev/$bdisk 4 131")) {
		    warn("*** $lv: could not set /dev/$bdisk type$logmsg\n");
		    return 0;
		}
	    }
	}
	#
	# Non-system volume or all space.
	#
	else {
	    #
	    # If LVM has not yet been initialized handle that:
	    #
	    if (!exists($so->{'LVM_VGCREATED'})) {
		my @devs = ();
		my $dev;

		#
		# Deterimine if we should use SSDs in the construction
		# of the volume group.
		#
		my $disktype = "";
		if ($href->{'PROTO'} eq "SATA") {
		    $disktype = "HDD";
		} elsif ($href->{'PROTO'} eq "NVMe") {
		    $disktype = "SSD";
		}

		if ($bsid eq "ANY") {
		    my $pchr = "";
		    if ($bdisk =~ /^nvme/) {
			$pchr = "p";
		    }
		    $dev = "${bdisk}${pchr}4";

		    if ($ginfo->{$bdisk}->{'ptabtype'} eq "GPT") {
			if (exists($ginfo->{$dev})) {
			    goto skipp4;
			}

			# Create the partition with type LINUX_LVM
			if (mysystem("$SGDISK -n 4:0:0 -t 4:8E00 ".
				     "/dev/$bdisk $redir") ||
			    mysystem("$PPROBE /dev/$bdisk $redir")) {
			    goto skipp4;
			}

			# XXX make sure there is enough space to be useful
			my $p4size = get_partsize($dev);
			if ($p4size < 10) {
			    warn("*** less than 10MiB available on ".
				 "system volume, skipping.\n");
			    mysystem("$SGDISK -d 4 /dev/$bdisk $redir");
			    goto skipp4;
			}

			# XXX create DISKINFO entry for partition
			$ginfo->{$dev}->{'type'} = "PART";
			$ginfo->{$dev}->{'level'} = 1;
			$ginfo->{$dev}->{'size'} = get_partsize($mdev);
			$ginfo->{$dev}->{'inuse'} = hex("8E00");

			push(@devs, "/dev/$dev");
		    }
		    elsif (exists($ginfo->{$dev}) &&
			   $ginfo->{$dev}->{'inuse'} == 0 &&
			   (!$disktype ||
			    $ginfo->{$bdisk}->{'disktype'} eq $disktype)) {
			push(@devs, "/dev/$dev");
		    }
		}
	      skipp4:

		foreach $dev (keys %$ginfo) {
		    if ($ginfo->{$dev}->{'type'} eq "DISK" &&
			$ginfo->{$dev}->{'inuse'} == 0 &&
			(!$disktype ||
			 $ginfo->{$dev}->{'disktype'} eq $disktype)) {
			push(@devs, "/dev/$dev");
		    }
		}
		if (@devs == 0) {
		    warn("*** $lv: no space found\n");
		    return 0;
		}

		#
		# Create the volume group:
		#
		# pvcreate /dev/sdb /dev/sda4		(ANY)
		# vgcreate emulab /dev/sdb /dev/sda4	(ANY)
		#
		# pvcreate /dev/sdb			(NONSYSVOL)
		# vgcreate emulab /dev/sdb		(NONSYSVOL)
		#
		if (mysystem("pvcreate -f @devs $redir")) {
		    warn("*** $lv: could not create PVs '@devs'$logmsg\n");
		    return 0;
		}
		if (mysystem("vgcreate $VGNAME @devs $redir")) {
		    warn("*** $lv: could not create VG from '@devs'$logmsg\n");
		    return 0;
		}

		$so->{'LVM_VGDEVS'} = scalar(@devs);
		$so->{'LVM_VGCREATED'} = 1;
	    }

	    #
	    # Now create an LV for the volume:
	    #
	    # lvcreate -i 4 -n h2d2 -L 100m emulab
	    #   or
	    # lvcreate -n h2d2 -L 100m emulab
	    #
	    if ($lvsize == 0) {
		my $sz = `vgs -o vg_size --units m --noheadings $VGNAME`;
		if ($sz =~ /([\d\.]+)/) {
		    $lvsize = int($1);
		} else {
		    warn("*** $lv: could not find size of VG\n");
		}
	    }
	    # try a striped LV first
	    # XXX don't stripe over an excess number of devices
	    my $pvs = $so->{'LVM_VGDEVS'};
	    if (defined($pvs) && $pvs > 8) {
		warn("  $lv: limiting striping to 8 PV devices\n");
		$pvs = 8;
	    }
	    #
	    # XXX supposedly, using -Zy will wipe (zero) all signatures
	    # without prompting for confirmation, but that doesn't seem
	    # to be the case under Ubuntu18. So let's throw in the -y
	    # option as well!
	    #
	    my $wipeopts = "-Zy -y";
	    if (defined($pvs) && $pvs > 1 &&
		!mysystem("lvcreate $wipeopts -i $pvs -n $lv -L ${lvsize}m $VGNAME $redir")) {
		$href->{'LVDEV'} = "/dev/$VGNAME/$lv";
		return 1;
	    }
	    if (mysystem("lvcreate $wipeopts -n $lv -L ${lvsize}m $VGNAME $redir")) {
		warn("*** $lv: could not create LV$logmsg\n");
		return 0;
	    }
	    $mdev = "$VGNAME/$lv";
	}

	$href->{'LVDEV'} = "/dev/$mdev";
	return 1;
    }

    warn("*** $bsid: unsupported class '" . $href->{'CLASS'} . "'\n");
    return 0;
}

sub os_remove_storage($$$)
{
    my ($so,$href,$teardown) = @_;

    if ($href->{'CMD'} eq "ELEMENT") {
	return os_remove_storage_element($so, $href, $teardown);
    }
    if ($href->{'CMD'} eq "SLICE") {
	return os_remove_storage_slice($so, $href, $teardown);
    }
    return 0;
}

sub os_remove_storage_element($$$)
{
    my ($so,$href,$teardown) = @_;
    #my $redir = "";
    my $redir = ">/dev/null 2>&1";

    if ($href->{'CLASS'} eq "SAN" && $href->{'PROTO'} eq "iSCSI") {
	my $hostip = $href->{'HOSTIP'};
	my $uuid = $href->{'UUID'};
	my $bsid = $href->{'VOLNAME'};

	#
	# Unmount it
	#
	if (exists($href->{'MOUNTPOINT'})) {
	    my $mpoint = $href->{'MOUNTPOINT'};
	    if (ISFORDOCKERVM()) {
		$mpoint = $href->{'MOUNTPOINT'} =
		    _docker_get_ext_trans_mountpoint($mpoint);
	    }

	    if (mysystem("$UMOUNT $mpoint")) {
		warn("*** $bsid: could not unmount $mpoint\n");
	    }
	}

	#
	# Logout of the session.
	# XXX continue even if we could not logout.
	#
	if (mysystem("$ISCSI -m node -T $uuid -p $hostip -u $redir")) {
	    warn("*** $bsid: Could not logout iSCSI sesssion (uuid=$uuid)\n");
	}

	#
	# XXX Note that we do a delete even when just doing a "reset"
	# (teardown == 3). This operation will clear out the local DB
	# state in /etc/iscsi and does not affect the server side.
	#
	if ($teardown &&
	    mysystem("$ISCSI -m node -T $uuid -p $hostip -o delete $redir")) {
	    warn("*** $bsid: could not perform teardown of iSCSI block store (uuid=$uuid)\n");
	    return 0;
	}

	return 1;
    }

    #
    # Nothing to do (yet) for a local disk
    #
    if ($href->{'CLASS'} eq "local") {
	return 1;
    }

    warn("*** Only support iSCSI now\n");
    return 0;
}

#
# teardown==0 means we are rebooting: unmount and shutdown gvinum
# teardown==1 means we are reconfiguring and will be destroying everything
# teardown==2 means the same as 1 but we ignore errors and alway plow ahead
# teardown==3 means we are taking an image and we recoverably remove
#             blockstore state from the root filesystem.
#
sub os_remove_storage_slice($$$)
{
    my ($so,$href,$teardown) = @_;

    if ($href->{'CLASS'} eq "local") {
	my $bsid = $href->{'BSID'};
	my $lv = $href->{'VOLNAME'};

	my $ginfo = $so->{'DISKINFO'};
	my $bdisk = $so->{'BOOTDISK'};

	# figure out the device of interest
	my ($dev, $devtype, $mdev);
	if ($bsid eq "SYSVOL") {
	    my $pchr = "";
	    if ($bdisk =~ /^nvme/) {
		$pchr = "p";
	    }
	    $dev = $mdev = "${bdisk}${pchr}4";
	    $devtype = "PART";
	} else {
	    $dev = "$VGNAME/$lv";
	    # XXX note that any '-'s in the mapper name are doubled
	    (my $rlv = $lv) =~ s/-/--/g;
	    $mdev = "mapper/${VGNAME}-$rlv";
	    $devtype = "LVM";
	}

	# if the device does not exist, we have a problem!
	if (!exists($ginfo->{$dev})) {
	    warn("*** $lv: device '$dev' does not exist\n");
	    return 0;
	}
	# ditto if it exists but is of the wrong type
	my $atype = $ginfo->{$dev}->{'type'};
	if ($atype ne $devtype) {
	    warn("*** $lv: actual type ($atype) != expected type ($devtype)\n");
	    return 0;
	}

	# record all the output for debugging
	my $log = "/var/emulab/logs/$lv.out";
	my $redir = ">>$log 2>&1";
	my $logmsg = ", see $log";
	mysystem("cp /dev/null $log");

	#
	# Unmount and remove mount info from fstab.
	#
	# On errors, we warn but don't stop. We do everything in our
	# power to take things down.
	#
	if (exists($href->{'MOUNTPOINT'})) {
	    my $mpoint = $href->{'MOUNTPOINT'};
	    if (ISFORDOCKERVM()) {
		$mpoint = $href->{'MOUNTPOINT'} =
		    _docker_get_ext_trans_mountpoint($mpoint);
	    }

	    if (mysystem("$UMOUNT $mpoint")) {
		warn("*** $lv: could not unmount $mpoint\n");
	    }

	    #
	    # Even if we are doing a non-destructive teardown (3) it is
	    # okay to remove the mountpoint even if the unmount failed.
	    # We will be rebooting anyway.
	    #
	    if ($teardown) {
		my $tdev = "/dev/$dev";
		$tdev =~ s/\//\\\//g;
		if (mysystem("sed -E -i -e '/^(# )?$tdev/d' $FSTAB")) {
		    warn("*** $lv: could not remove mount from $FSTAB\n");
		}
	    }
	}

	#
	# Teardown for imaging (3).
	# Here we just want to clear blockstore related state from the
	# root filesystem so that we get a clean image:
	#
	# For SYSVOL, there is nothing further to do. If they are taking
	# a full disk image, then the blockstore will be included in the
	# image unless the imagezip called explicitly ignores the partition.
	# We can live with this as full images are discouraged now.
	#
	# For NONSYSVOL, aka an LVM VG on the extra disks, we try
	# deactivating the volume and, at the end, clearing out any state
	# in /etc/lvm/{backup,archive}. That info will get recreated on
	# reboot.
	#
	# For ANY, we treat it the same as NONSYSVOL. There is a potential
	# problem that a full disk image would include sda4 which would
	# appear as a valid PV in an otherwise incomplete VG when the
	# image is loaded elsewhere. This will cause lots of warnings,
	# but again, we don't care so much about full images.
	#
	if ($teardown == 3) {
	    if ($ginfo->{$dev}->{'type'} eq "LVM") {
		if (mysystem("lvchange -an $dev $redir")) {
		    warn("*** $lv: could not deactivate $dev\n");
		} else {
		    sleep(1);
		}
		# XXX mark it deactive in our state regardless
		$ginfo->{$dev}->{'active'} = 0;

		#
		# If there are no more active LVMs, clear out the
		# in-filesystem LVM state.
		#
		my $active = 0;
		foreach $dev (keys %$ginfo) {
		    if ($ginfo->{$dev}->{'type'} eq "LVM" &&
			$ginfo->{$dev}->{'active'} == 1) {
			$active++;
		    }
		}
		if ($active == 0 &&
		    mysystem("rm -rf /etc/lvm/backup/* /etc/lvm/archive/* $redir")) {
		    warn("*** $lv: could not remove /etc/lvm state\n");
		}
	    }
	    return 1;
	}
	
	#
	# Remove LV
	#
	if ($teardown) {
	    #
	    # System volume:
	    #
	    # dostype -f /dev/sda 4 0
	    #
	    if ($bsid eq "SYSVOL") {
		if ($ginfo->{$bdisk}->{'ptabtype'} eq "GPT") {
		    if (mysystem("$SGDISK -d 4 /dev/$bdisk $redir") ||
			mysystem("$PPROBE /dev/$bdisk $redir")) {
			warn("*** $lv: could not destroy $dev$logmsg\n");
			return 0;
		    }
		    delete $ginfo->{$dev};
		} else {
		    if (mysystem("$DOSTYPE -f /dev/$bdisk 4 0")) {
			warn("*** $lv: could not clear /dev/$bdisk type$logmsg\n");
			return 0;
		    }
		}
		return 1;
	    }

	    #
	    # Other, LVM volume:
	    #
	    # lvremove -f emulab/h2d2
	    #
	    my $rmopts = "";

	    #
	    # XXX this significantly speeds the lvremove, which otherwise will
	    # be causing erase operations on the device, but it also causes a
	    # lot of stale metadata to get left behind which can affect
	    # recreation of the device. For now we opt to slow the less common
	    # remove operation.
	    #
	    $rmopts .= "--config devices/issue_discards=0";

	    if (mysystem("lvremove $rmopts -f $VGNAME/$lv $redir")) {
		warn("*** $lv: could not destroy$logmsg\n");
	    }

	    #
	    # If no volumes left:
	    #
	    # Remove the VG:
	    #  vgremove -f emulab
	    # Remove the PVs:
	    #  pvremove -f /dev/sda4 /dev/sdb
	    #
	    my $gotlvs = 0;
	    my $lvs = `lvs -o vg_name --noheadings $VGNAME 2>/dev/null`;
	    if ($lvs) {
		return 1;
	    }

	    if (mysystem("vgremove -f $VGNAME $redir")) {
		warn("*** $lv: could not destroy VG$logmsg\n");
	    }

	    my @devs = `pvs -o pv_name --noheadings 2>/dev/null`;
	    chomp(@devs);
	    if (@devs > 0) {
		if (mysystem("pvremove -f @devs $redir")) {
		    warn("*** $lv: could not destroy PVs$logmsg\n");
		} else {
		    my $tdev = "/dev/${bdisk}4";
		    if (grep(/\s*$tdev\s*/, @devs) != 0) {
			if ($ginfo->{$bdisk}->{'ptabtype'} eq "GPT") {
			    if (mysystem("$SGDISK -d 4 /dev/$bdisk $redir") ||
				mysystem("$PPROBE /dev/$bdisk $redir")) {
				warn("*** $lv: could not destroy $tdev$logmsg\n");
			    } else {
				delete $ginfo->{"${bdisk}4"};
			    }
			}
		    }
		}
	    }
	}
	return 1;
    }

    return 0;
}

sub mysystem($)
{
    my ($cmd) = @_;
    if (0) {
	print STDERR "CMD: $cmd\n";
    }
    return system($cmd);
}

sub mybacktick($)
{
    my ($cmd) = @_;
    if (0) {
	print STDERR "CMD: $cmd\n";
    }
    return `$cmd`;
}

1;
