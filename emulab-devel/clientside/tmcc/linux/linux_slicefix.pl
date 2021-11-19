#! /usr/bin/perl
#
# Copyright (c) 2015-2021 University of Utah and the Flux Group.
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

my $VOL_ID = '/lib/udev/vol_id';
my $BLKID = '/sbin/blkid';
my $FDISK = '/sbin/fdisk';
my $MOUNT = '/bin/mount';
my $UMOUNT = '/bin/umount';
my $RM = '/bin/rm';
my $CP = '/bin/cp';
my $CPIO = 'cpio';
my $GZIP = 'gzip';
my $XZ = 'xz';
my $MKSWAP = '/sbin/mkswap';
my $UUIDGEN = 'uuidgen';
my $LOSETUP = 'losetup';
my $TUNE2FS = 'tune2fs';
my $LOCALIZED1 = '/.localized';
my $LOCALIZED2 = '/root/.localized';

use constant GZHDR1 => 0x1f8b0800;
use constant GZHDR2 => 0x1f8b0808;
use constant LARGEST_PAGE_SIZE => 0x4000;
use constant UUID_OFFSET => 1036;
use constant ELFHDR => 0x7f454c46;
use constant XZHDRSTART => 0xfd377a58;

#
# Turn off line buffering on output
#
$| = 1;

# Load up the paths. Done like this in case init code is needed.
BEGIN
{
    if (! -e "/etc/emulab/paths.pm") {
	die("Yikes! Could not require /etc/emulab/paths.pm!\n");
    }
    require "/etc/emulab/paths.pm";
    import emulabpaths;
}

use strict;

sub get_uuid
{
	my ($device) = @_;
	my $uuid;

	if (-x $VOL_ID) {
		open CMD, $VOL_ID . " --uuid $device |" || die
		     "Couldn't run vol_id: $!\n";

		$uuid = <CMD>;
		chomp $uuid;

		close CMD;
	}
	elsif (-x $BLKID) {
		open CMD, "$BLKID|" || die
			"Couldn't run blkid: $!\n";

		while (<CMD>) {
			next unless m#^$device:\s+#;
			chomp;
			next unless s/.*\s+UUID="([a-f0-9-]+)".*/\1/;
			$uuid = $_;
		}

		close CMD;
	}
	else {
		print STDERR "Can't find program to get FS UUID\n";
	}

	return $uuid;
}

sub get_label
{
	my ($device) = @_;
	my $label;

	if (-x $VOL_ID) {
		open CMD, $VOL_ID . " --label-raw $device|" || die
		     "Couldn't run vol_id: $!\n";

		$label = <CMD>;
		chomp $label;

		close CMD;
	}
	elsif (-x $BLKID) {
		open CMD, "$BLKID|" || die
			"Couldn't run blkid: $!\n";

		while (<CMD>) {
			next unless m#^$device:\s+#;
			chomp;
			next unless s/.*\s+LABEL="([^"]*)".*/\1/;
			$label = $_;
		}

		close CMD;
	}
	else {
		print STDERR "Can't find program to get FS label\n";
	}

	return $label;
}

sub set_random_rootfs_uuid
{
	my ($root) = @_;
	
	system("$TUNE2FS -U random $root");
}

sub disable_time_dependent_fsck
{
	my ($root) = @_;
	
	system("$TUNE2FS -i 0 $root >/dev/null 2>&1");
}

sub kernel_version_compare
{
	my ($v1, $v2) = @_;

	my $v1_code = sprintf "%x%02x%02x", (split /\./, $v1)[0 .. 2];
	my $v2_code = sprintf "%x%02x%02x", (split /\./, $v2)[0 .. 2];

	if ($v1_code < $v2_code) {
		return -1;
	}
	elsif ($v1_code == $v2_code) {
		return 0;
	}
	else {
		return 1;
	}
}

sub find_swap_partitions
{
	my ($device) = @_;
	my @swap_devices;

	open CMD, $FDISK . " -l $device|" ||
	     die "Couldn't run fdisk: $!\n";

	while (<CMD>) {
		next unless m#^$device#;
		split /\s+/;
		if ($_[4] eq '82') {
			push @swap_devices, $_[0];
		}
	}

	close CMD;

	return @swap_devices;
}

sub set_swap_uuid
{
	my ($device, $uuid) = @_;
	my $swap_header;
	
	if (!open DEVICE, "+<$device") {
		print STDERR "Couldn't open $device: $!\n";      
		return 1;
	}
	
	my $id;
	for (my $i = 0x1000; $i <= LARGEST_PAGE_SIZE; $i <<= 1) {
		seek DEVICE, 0, 0;
		read DEVICE, $swap_header, $i;
		$id = unpack('Z10', substr($swap_header, $i - 10));
		last if ($id eq 'SWAPSPACE2');
	}
	                              
	if ($id ne 'SWAPSPACE2') {
		print STDERR "Device $device does not contain a new-style swap header\n";
		close DEVICE;
		return 1;
	}
	
	my $new_uuid = pack('H8H4H4H4H12', split(/-/, $uuid));
	substr $swap_header, UUID_OFFSET, 16, $new_uuid;
	
	seek DEVICE, 0, 0;
	print DEVICE $swap_header;
	
	close DEVICE;
}

sub fix_grub_dom0mem
{
	my ($imageroot, $file) = @_;
	my $dom0mem = $ENV{"SLICEFIX_DOM0MEM"};

	if (!$dom0mem ||
	    system("grep -q 'dom0_mem=' $imageroot/$file 2>/dev/null")) {
		return;
	}

	print STDERR "Setting dom0 memory to $dom0mem\n";
	open FILE, "+<$imageroot/$file" ||
	     die "Couldn't open $imageroot/$file: $!\n";

	my @buffer = ();
	while (<FILE>) {
		s#dom0_mem=\w+#dom0_mem=$dom0mem#g;
		push @buffer, $_;
	}

	seek FILE, 0, 0;
	truncate FILE, 0;

	print FILE @buffer;

	close FILE;

	return;
}

sub get_linux_device_components
{
	my ($devpath) = @_;

	if ($devpath =~ m#/dev/nvme(\d+)(n\d+)p(\d+)$#) {
		return ("nvme$1$2","p$3",int($1),int($3));
	}
	elsif ($devpath =~ m#/dev/([hs]d)(.)(\d+)$#) {
		my $disk_num =~ y/[a-h]/[0-7]/;
		return ("$1$2","$3",int($disk_num),int($3));
	}
}

sub fix_swap_partitions
{
	my ($imageroot, $root, $old_root) = @_;
	my @swapdevs;

	return undef unless (-x $MKSWAP);

	my ($root_disk) = get_linux_device_components($root);
	my ($old_root_disk) = get_linux_device_components($old_root);
	my @swap_partitions = find_swap_partitions($root_disk);
	my ($l, $u) = binary_supports_blkid("$imageroot/sbin/swapon");

	for my $part (@swap_partitions) {
		my $swapdev = $part;
		next if system("$MKSWAP $part");
		my $uuid = get_uuid($part);
		if ($u) {
			if ($uuid) {
				$swapdev = "UUID=$uuid";
			}
			else {
				# BusyBox's mkswap doesn't support UUIDs, so
				# we'll need to generate it and write it out.
				$uuid = `$UUIDGEN`;
				chomp $uuid;
				set_swap_uuid($swapdev, $uuid);
				$swapdev="UUID=$uuid";
			}
		}
		elsif ($old_root) {
			$swapdev =~ s#^$root_disk#$old_root_disk#;
		}

		push @swapdevs, $swapdev;
	}

	return undef unless (@swapdevs);

	my @buffer;
	if (!open FSTAB, "+<$imageroot/etc/fstab") {
		print STDERR "Failed to open fstab: $!\n";
		return undef;
	}

	@buffer = grep {!/^[^#].*\bswap\b.*$/} <FSTAB>;
	if (@swapdevs > 0) {
		push @buffer, "# the following swap devices added by linux_slicefix\n";
		for (@swapdevs) {
			push @buffer, "$_\tnone\tswap\tsw\t0 0\n";
		}
	}
	seek FSTAB, 0, 0;
	print FSTAB @buffer;
	close FSTAB;
}

sub file_replace_string
{
	my ($imageroot, $file, $ostr, $nstr) = @_;
	my @buffer;

	if (!$ostr) {
		print STDERR "old string is empty\n";
		return 1;
	}

	open FILE, "+<$imageroot/$file" ||
	     die "Couldn't open $imageroot/$file: $!\n";

	while (<FILE>) {
		s#$ostr#$nstr#g;
		push @buffer, $_;
	}

	seek FILE, 0, 0;
	truncate FILE, 0;

	print FILE @buffer;

	close FILE;

	return 1;
}

sub rewrite_lilo_config
{
	my ($imageroot, $old_root, $new_root) = @_;
	my @buffer;

	open FILE, "+<$imageroot/etc/lilo.conf" ||
	     die "Couldn't open $imageroot/etc/lilo.conf: $!\n";

	while (<FILE>) {
		chomp;
		next if /^\s*root\s*=\s*/;
		s/^\s*boot\s*=\s*.*$/boot = $new_root/g;
		if (/append\s*=\s*/i) {
			s/\s*root=[^"'\s]*//g;
			s/(["'])\s*$/ root=$new_root$1/;
		}
		push @buffer, $_;
	}

	seek FILE, 0, 0;

	print FILE "$_\n" for (@buffer);

	close FILE;

	return 1;
}

sub set_runlilo_flag
{
	my ($imageroot, $default_entry, $new_root) = @_;
	my $cmdline;

	open FILE, ">$imageroot/var/emulab/boot/runlilo" ||
	     die "Couldn't write to runlilo file: $!\n";
	
	$cmdline = "$default_entry root=$new_root";

	print FILE "$cmdline\n";

	close FILE;

	return $cmdline;
}

sub find_default_grub_entry
{
	my ($imageroot, $conf) = @_;
	my @buffer;
	my $default = 0;
	my $current_entry = -1;
	my ($kernel, $cmdline, $initrd);

	open FILE, "$imageroot/$conf" || die "Couldn't read grub config: $!\n";
	while (<FILE>) {
		if (/^default\s+(\d+)$/) {
			$default = $1;
			next;
		}
		elsif (/^\s*(\S+)\s+(.*)$/) {
			if ($1 eq 'title') {
				$current_entry++;
			}

			next if ($current_entry < $default);
			last if ($current_entry > $default);

			if ($1 eq 'kernel') {
				$_ = $2;
				($kernel, $cmdline) = /^(\S+)\s+(.*)$/;
			}
			elsif ($1 eq 'initrd') {
				$initrd = $2;
			}
		}
	}
	close FILE;

	return ($kernel, $cmdline, $initrd);
}

sub find_default_grub2_entry
{
	my ($imageroot, $conf) = @_;
	my @buffer;
	my $default = 0;
	my $current_entry = -1;
	my ($kernel, $cmdline, $initrd);

	open FILE, "$imageroot/$conf" || die "Couldn't read grub config: $!\n";
	while (<FILE>) {
		if (/^set\s+default\s*=\s*["']?(\d+)["']?$/) {
			$default = $1;
			next;
		}
		elsif (/^\s*(\S+)\s+(.*)$/) {
			if ($1 eq 'menuentry') {
				$current_entry++;
			}

			next if ($current_entry < $default);
			last if ($current_entry > $default);

			if ($1 eq 'linux' || $1 eq 'linux16') {
				$_ = $2;
				($kernel, $cmdline) = /^(\S+)\s+(.*)$/;
			}
			elsif ($1 eq 'initrd' || $1 eq 'initrd16') {
				$initrd = $2;
			}
		}
	}
	close FILE;

	return ($kernel, $cmdline, $initrd);
}

sub set_grub_root_device
{
	my ($imageroot, $grub_config, $root) = @_;
	my ($root_disk, $root_part, $root_disk_num, $root_part_num) =
	    get_linux_device_components($root);
	my $grub_disk;

	if (-f $BOOTDIR . "/edd_map") {
		open FILE, $BOOTDIR . "/edd_map";
		while (<FILE>) {
			chomp;
			split /=/;
			if ($_[0] eq $root_disk) {
				$grub_disk = hex($_[1]) - 0x80;
				print "Found GRUB root device using EDD\n";
				last;
			}
		}
		close FILE;
	}

	if (not defined $grub_disk) {
		$grub_disk = $root_disk_num;
		print "Found GRUB root device by guessing\n";
	}

	printf "GRUB root device is (hd%d,%d)\n", $grub_disk, $root_part_num - 1;
	$root_part_num--;

	open FILE, "+<$imageroot/$grub_config" or
	     die "Couldn't open GRUB config: $!\n";
	my @buffer;
	while (<FILE>) {
		s/^(\s*)root \([^)]*\)/$1root (hd$grub_disk,${root_part_num})/;
		push @buffer, $_;
	}
	seek FILE, 0, 0;
	truncate FILE, 0;
	print FILE @buffer;
	close FILE;
}

sub set_grub2_root_device
{
	my ($imageroot, $grub_config, $root) = @_;
	my ($root_disk, $root_part, $root_disk_num, $root_part_num) =
	    get_linux_device_components($root);
	my $grub_disk;

	if (-f $BOOTDIR . "/edd_map") {
		open FILE, $BOOTDIR . "/edd_map";
		while (<FILE>) {
			chomp;
			split /=/;
			if ($_[0] eq $root_disk) {
				$grub_disk = hex($_[1]) - 0x80;
				print "Found GRUB root device using EDD\n";
				last;
			}
		}
		close FILE;
	}

	if (not defined $grub_disk) {
		$grub_disk = $root_disk_num;
		print "Found GRUB root device by guessing\n";
	}

	printf "GRUB root device is (hd%d,%d)\n", $grub_disk, $root_part_num;

	open FILE, "+<$imageroot/$grub_config" or
	     die "Couldn't open GRUB config: $!\n";
	my @buffer;
	while (<FILE>) {
		# XXX eat the newline so the RE does not!
		chomp;
		s/^(\s*set\s+root\s*=\s*["']?\(?)[^)'"]*(\)?["']?)/$1hd$grub_disk,${root_part_num}$2/;
		push @buffer, "$_\n";
	}
	seek FILE, 0, 0;
	truncate FILE, 0;
	print FILE @buffer;
	close FILE;
}

sub find_default_lilo_entry
{
	my ($imageroot, $conf) = @_;
	my %images;
	my %globals;
	my @image_list;
	my ($kernel, $cmdline, $initrd);
	my $default;

	open FILE, "$imageroot/$conf" || die "Couldn't read lilo config: $!\n";
	while (<FILE>) {
		chomp;

		my $command;
		my $args;
		s/\s*#.*$//; # Remove comments
		s/\s+$//; # Remove trailing whitespace
		next if (/^$/); # Skip blank lines
		if (/^\s*image\s*=\s*(.*)\s*$/i) {
			push @image_list, $1;
			$images{$1} = {'image' => $1};
		}
		elsif (/^\s*(?:label|alias)\s*=\s*(.*)\s*$/i) {
			$images{$1} = $images{$image_list[-1]};
		}
		elsif (/^\s*(\S+)\s*=\s*(.*)\s*$/) {
			($command, $args) = (lc $1, $2);
		}
		elsif (/^\s*(?:read-only|ro)$/) {
			($command, $args) = ('read-only', 'ro');
		}
		elsif (/^\s*(?:read-write|rw)$/) {
			($command, $args) = ('read-only', 'rw');
		}
		else {
			($command, $args) = ($_, 1);
		}

		if (@image_list) {
			${$images{$image_list[-1]}}{$command} = $args;
		}
		else {
			$globals{$command} = $args;
		}
	}
	close FILE;

	if (exists $globals{'default'}) {
		$default = $globals{'default'};
	}
	else {
		$default = $image_list[0];
	}

	my $root = $images{$default}{'root'};
	$initrd = $images{$default}{'initrd'};
	$cmdline = $images{$default}{'append'};
	$kernel = $images{$default}{'image'};
	my $ro = $images{$default}{'read-only'};
	if (not defined $root) {
		$root = $globals{'root'};
	}
	if (not defined $initrd) {
		$initrd = $globals{'initrd'};
	}
	if (not defined $cmdline) {
		$cmdline = $globals{'append'};
	}
	if (not defined $ro) {
		$ro = $globals{'read-only'};
	}

	$cmdline =~ s/^"(.*)"$/$1/;
	if ($root && $cmdline !~ /\broot=\S+\b/) {
		$cmdline .= " root=$root";
	}
	if ($ro && $cmdline !~ /\br[ow]\b/) {
		$cmdline .= " $ro";
	}

	return ($default, $kernel, $cmdline, $initrd);
}

sub guess_bootloader
{
	my ($device) = @_;
	my $buffer;
	my $bootloader;

	open DEVICE, $device || die "Couldn't open $device: $!\n";
	read DEVICE, $buffer, 512;
	close DEVICE;

	if ($buffer =~ /GRUB/) {
		$bootloader = 'grub';
	}
	elsif ($buffer =~ /LILO/) {
		$bootloader = 'lilo';
	}

	return $bootloader;
}

sub udev_supports_label
{
	my ($imageroot) = @_;
	my ($handles_label, $handles_uuid) = (0, 0);

	if (! -d "$imageroot/etc/udev/rules.d") {
		return (0, 0);
	}

	my @files = glob "$imageroot/etc/udev/rules.d/*";
	if (@files) {
		@files = glob "$imageroot/lib/udev/rules.d/*";
	}
	for my $file (@files) {
		open FILE, $file or next;
		my @buffer = <FILE>;
		close FILE;
		if (grep(/[^#]*ID_FS_UUID/, @buffer)) {
			$handles_uuid = 1;
		}

		if (grep(/[^#]*ID_FS_LABEL/, @buffer)) {
			$handles_label = 1;
		}
	}

	return ($handles_label, $handles_uuid);
}

sub binary_supports_blkid
{
	my ($file) = @_;
	my $handles_label = 0;
	my $handles_uuid = 0;

	if (-x $file) {
		local $/;
		my $buffer;
		open FILE, $file or
		     die "Couldn't grep $file: $!\n";
		$buffer = <FILE>;
		close FILE;

		if ($buffer =~ /libblkid\.so/) {
			$handles_label = 1;
			$handles_uuid = 1;
		}
		else{ 
			if ($buffer =~ /LABEL/) {
				$handles_label = 1;
			}
			if ($buffer =~ /UUID/) {
				$handles_uuid = 1;
			}
		}
	}

	return ($handles_label, $handles_uuid);
}

sub get_fstab_root
{
	my ($imageroot) = @_;
	my $root;

	open FSTAB, "$imageroot/etc/fstab" ||
	     die "Couldn't open fstab: $!\n";

	while (<FSTAB>) {
		split /\s+/;
		if ($_[1] eq '/') {
			$root = $_[0];
		}
	}

	close FSTAB;

	return $root;
}

sub check_kernel
{
	my ($kernel) = @_;
	my $offset = 0;;
	my $buffer;
	my $rc;
	my $kernel_tmpfile;
	my $kernel_file = $kernel;
	my $kernel_has_ide = 0;
	my $version_string;
	my $compression;

	open KERNEL, $kernel or die "Couldn't open $kernel: $!\n";
	read KERNEL, $buffer, 4;
	while ($rc = read KERNEL, $buffer, 1, length($buffer)) {
		my ($value) = unpack 'N', $buffer;
		if ($value == GZHDR1 || $value == GZHDR2) {
			$compression = 'gzip';
			last;
		}
		elsif ($value == ELFHDR) {
			last;
		}
		$buffer = substr $buffer, 1;
	}
	if ($rc == 0) {
		close KERNEL;
		return undef;
	}

	if ($compression) {
		$kernel_tmpfile = "/tmp/kernel.$$";
		$kernel_file = $kernel_tmpfile;
		#
		# XXX if gzip sees trailing garbage it exits non-zero causing a SIGPIPE in the
		# while loop and making perl terminate.
		# New Linux kernel compressions seem to cause this (on Ubuntu 18 at least).
		#
		$SIG{'PIPE'} = 'IGNORE';
		open GZIP, "|$GZIP -dc > $kernel_tmpfile 2> /dev/null";
		print GZIP $buffer;
		while (read KERNEL, $buffer, 4096) {
			print GZIP $buffer;
		}
		close KERNEL;
		close GZIP;
	}

	open KERNEL, $kernel_file or die "Couldn't open raw kernel: $!\n";
	while (<KERNEL>) {
		if (/ide[-_]disk/) {
			$kernel_has_ide = 1;
		}
		if (/Linux version (\S+)/) {
			$version_string = $1;
		}
	}
	close KERNEL;

	unlink "$kernel_tmpfile"
		if (defined($kernel_tmpfile));

	return ($version_string, $kernel_has_ide);
}

sub check_initrd
{
	my ($initrd) = @_;
	my $decompressed_initrd = "/tmp/initrd.$$";
	my $initrd_dir = "/tmp/initrd.dir.$$";
	my $handles_label = 0;
	my $handles_uuid = 0;
	my $has_early_cpio = 0;
	my $compression;

	return undef if (! -f $initrd);

	mkdir $initrd_dir;

	# Check to see if there's an uncompressed early cpio archive
	# prepended to the main gzip'd cpio hunk.  We have to parse the cpio
	# headers to find the correct next place to read, unfortunately.
	#
	# Assume that we won't find anything; in that case we will
	# decompress $initrd below.
	my $initrd_filename = $initrd;
	my $rc;
	my $buffer;
	my $offset = 0;
	open INITRD, $initrd or die "Couldn't open $initrd: $!\n";
	while ($rc = read INITRD, $buffer, 6) {
		# Basically, read any uncompressed newc-format CPIO
		# headers that we can.  If we find any, the compressed
		# CPIO blob follows the final uncompressed header.
		if ($buffer eq '070701' || $buffer eq '070702') {
			my $tbuf;
			$rc = read(INITRD,$tbuf,110-6);
			if ($rc != (110-6)) {
				die "Malformed early uncompressed initramfs!\n";
			}
			$buffer .= $tbuf;
			my $namesize = hex(substr($buffer,94,8));
			my $filesize = hex(substr($buffer,54,8));
			$offset += 110;
			$offset = (($offset + $namesize + 3) & ~3);
			$offset = (($offset + $filesize + 3) & ~3);
			seek(INITRD,$offset,0);
		}
		elsif ($offset > 0 && ord(substr($buffer,0,1)) == 0) {
			$offset += 4;
			seek(INITRD,$offset,0);
			next;
		}
		else {
			last;
		}
	}
	if ($offset > 0) {
		my $inner_initrd = "/tmp/initrd.inner.$$";
		seek(INITRD,$offset,0);
		open(INNERINITRD,">$inner_initrd")
			or die "Con't open $inner_initrd: $!\n";
		while ($rc = read(INITRD,$buffer,4096)) {
			print INNERINITRD $buffer;
		}
		close(INNERINITRD);
		# If we extracted an inner blob, change the filename we
		# will attempt to decompress.
		$initrd_filename = $inner_initrd;
		$has_early_cpio = 1;
	}
	close(INITRD);

	open INITRD, $initrd_filename or die "Couldn't open $initrd_filename: $!\n";
	read INITRD, $buffer, 4;
	my ($value) = unpack 'N', $buffer;
	if ($value == GZHDR1 || $value == GZHDR2) {
		$compression = 'gzip';
	}
	elsif ($value == XZHDRSTART) {
		$compression = 'lzma';
	}
	close INITRD;

	if (defined($compression) && $compression eq 'lzma') {
		`$XZ -dc < "$initrd_filename" > "$decompressed_initrd" 2> /dev/null`;
	}
	else {
		# Just bail to gzip no matter what.
		`$GZIP -dc < "$initrd_filename" > "$decompressed_initrd" 2> /dev/null`;
	}
	if ($? >> 8) {
		`$CP "$initrd_filename" "$decompressed_initrd"`;
		if ($? & 0xff) {
			return undef;
		}
	}

	`$MOUNT -o ro,loop -t ext3 "$decompressed_initrd" "$initrd_dir" 2> /dev/null`;
	if ($? >> 8) {
		`$MOUNT -o ro,loop -t ext2 "$decompressed_initrd" "$initrd_dir" 2> /dev/null`;
		if ($? >> 8) {
			`cd "$initrd_dir" && $CPIO -idu < "$decompressed_initrd" > /dev/null 2>/dev/null`;
			if ($? >> 8) {
				return undef;
			}
		}
	}

	for ('/bin/busybox', '/bin/nash', '/bin/mount') {
		next unless (-f "$initrd_dir/$_");
		($handles_label, $handles_uuid) =
		    binary_supports_blkid("$initrd_dir/$_");
		last;
	}

	if (!$handles_label && !$handles_uuid) {
		($handles_label, $handles_uuid) =
		    udev_supports_label($initrd_dir);
	}

	#
	# XXX we are going to wing it here and assume "yes" and "yes" if the
	# initrd is the Fedora/CentOS "early cpio" variety. Would take more
	# machinery to extract the real initrd CPIO archive that appears to
	# be appended to the initial small one. I'm just not that in to it.
	#
	if (!$handles_label && !$handles_uuid
	    && ($has_early_cpio || -f "$initrd_dir/early_cpio")) {
	    print "Found initrd early_cpio; assuming handles label/UUID\n";
	    $handles_label = $handles_uuid = 1;
	}

	`$UMOUNT "$initrd_dir" > /dev/null 2> /dev/null`;
	`$RM -rf "$initrd_dir" "$decompressed_initrd"`;
	
	my @loopdevs;
	open LOSETUP, "$LOSETUP -a |";
	while (<LOSETUP>) {
		chomp;
		split /:/;
		push @loopdevs, $_[0];
	}
	close LOSETUP;
	
	for my $dev (@loopdevs) {
		`$LOSETUP -d $dev`;
	}
		
	return ($handles_label, $handles_uuid);
}

sub mount_image
{
	my ($root, $imageroot) = @_;
	my $fstype;

	for my $type (qw/ext3 ext2/) {
		`mount -t $type $root $imageroot`;
		if (!($? >> 8)) {
			$fstype = $type;
			last;
		}
	}

	return $fstype;
}

sub update_random_seed
{
	my ($imageroot) = @_;
	my $seed;
	my $size;
	my $rc = 1;

	if (! -f "$imageroot/var/lib/random-seed") {
		return undef;
	}

	print "Updating /var/lib/random-seed\n";
	open URANDOM, '/dev/urandom';
	$size = 512;
	while ($rc && $size > 0) {
		my $rc = read URANDOM, $seed, $size, length($seed);
		$size -= $rc;
	}
	close URANDOM;

	open SEED, ">$imageroot/var/lib/random-seed";
	print SEED $seed;
	close SEED;
}

sub fix_console
{
    my ($imageroot, $bloader, $file) = @_;

    my $console = $ENV{"SLICEFIX_CONSOLE"};
    if (!$console) {
	print STDERR "no SLICEFIX_CONSOLE, leaving console as is\n";
	return;
    }

    # XXX BSDism
    if ($console eq "vid") {
	$console = "vga";
    }

    print STDERR "Setting console device to $console\n";

    # parse off speed if present
    my $sspeed = 115200;
    if ($console =~ /^([^,]+),(\d+)$/) {
	$console = $1;
	$sspeed = $2;
    }

    my $sunit = -1;
    my $sport = "";
    if ($console =~ /^sio(\d+)$/) {
	$sunit = ($1 > 1) ? $1 - 1 : 0;

	if ($bloader eq 'grub2' && $sunit < 4) {
	    my @smap = ("0x3F8", "0x2F8", "0x3E8", "0x2E8");
	    $sport = $smap[$sunit];
	}
    }

    fix_grub_console($imageroot, $file, $console, $sunit, $sspeed, $sport);
    fix_grub_defaults($imageroot, $console, $sunit, $sspeed, $sport);

    # XXX we don't bother with /etc/inittab, only RHLnn-STD used it

    # Fixup upstart console config
    my $getty = "$imageroot/etc/init/ttyS0.conf";
    if (-e "$getty") {
	# If we don't already have a backup, create one
	if (! -e "$getty.preemulab") {
	    if (system("cp -p $getty $getty.preemulab")) {
		print STDERR "WARNING: could not backup old $getty!\n";
	    }
	}

	if ($sunit < 0) {
	    # XXX cannot use .override as old version don't support it,
	    # so get rid of it
	    if (unlink($getty) == 0) {
		print STDERR "could not remove $getty\n";
	    }
	} else {
	    # XXX wtf, apparently port/baud can be in either order
	    #     helluva way to run a command line...
	    file_replace_string($imageroot, "/etc/init/ttyS0.conf",
				"ttyS. [0-9]+ ", "ttyS$sunit $sspeed ");
	    file_replace_string($imageroot, "/etc/init/ttyS0.conf",
				"[0-9]+ ttyS. ", "$sspeed ttyS$sunit ");
	}
    }
    # previously moved out of the way
    elsif (-e "$getty.preemulab") {
	if ($sunit >= 0) {
	    # copy it back
	    system("cp -p $getty.preemulab $getty");
	    
	    # tweak it as above
	    file_replace_string($imageroot, "/etc/init/ttyS0.conf",
				"ttyS. [0-9]+ ", "ttyS$sunit $sspeed ");
	    file_replace_string($imageroot, "/etc/init/ttyS0.conf",
				"[0-9]+ ttyS. ", "$sspeed ttyS$sunit ");
	}
    }
}

#
# Handle default settings file for grub since package installation
# might cause the grub.cfg file to get recreated.
#
# We just append variable definitions to the end of the file and
# override any existing settings. This would only adversely affect the
# GRUB_CMDLINE_LINUX param if it was being used for some other options.
# For vid or null we add:
#
# GRUB_CMDLINE_LINUX="console=tty0"
# GRUB_TERMINAL=console
# GRUB_SERIAL_COMMAND=""
#
# and for sio[1-3] we add:
#
# GRUB_CMDLINE_LINUX="console=ttySN,S"
# GRUB_TERMINAL=serial
# GRUB_SERIAL_COMMAND="serial --speed=S --unit=N"
#
sub fix_grub_defaults
{
    my ($imageroot, $console, $sunit, $sspeed, $sport) = @_;
    my $gdef = "$imageroot/etc/default/grub";

    if (! -e $gdef) {
	return;
    }
    if (! -e "$gdef.preemulab") {
	system("cp -p $gdef $gdef.preemulab");
    }

    if (!open(FILE, "+<$gdef")) {
	return;
    }

    my $esig = "# The remaining lines were added by Emulab slicefix";

    my @buffer = ();
    while (<FILE>) {
	if (/^$esig/) {
	    last;
	}
	push @buffer, $_;
    }

    # append our info
    push @buffer, "$esig\n";
    push @buffer, "# DO NOT ADD ANYTHING AFTER THIS POINT AS IT WILL GET REMOVED.\n";
    if ($sunit < 0 && $console =~ /^hvc/) {
	push @buffer, "GRUB_CMDLINE_LINUX=\"console=tty0 console=$console\"\n";
	push @buffer, "GRUB_TERMINAL=console\n";
	push @buffer, "GRUB_SERIAL_COMMAND=\"\"\n";
    } elsif ($sunit < 0) {
	push @buffer, "GRUB_CMDLINE_LINUX=\"console=tty0\"\n";
	push @buffer, "GRUB_TERMINAL=console\n";
	push @buffer, "GRUB_SERIAL_COMMAND=\"\"\n";
    } else {
	push @buffer, "GRUB_CMDLINE_LINUX=\"console=ttyS$sunit,$sspeed\"\n";
	push @buffer, "GRUB_TERMINAL=serial\n";
	if ($sport) {
	    push @buffer, "GRUB_SERIAL_COMMAND=\"serial --unit=$sunit --port=$sport --speed=$sspeed\"\n";
	} else {
	    push @buffer, "GRUB_SERIAL_COMMAND=\"serial --unit=$sunit --speed=$sspeed\"\n";
	}
    }

    seek FILE, 0, 0;
    truncate FILE, 0;

    print FILE @buffer;

    close FILE;
}

sub fix_grub_console
{
	my ($imageroot, $file, $console, $sunit, $sspeed, $sport) = @_;
	my $comunit = $sunit + 1;

	open FILE, "+<$imageroot/$file" ||
	     die "Couldn't open $imageroot/$file: $!\n";

	my @buffer = ();
	while (<FILE>) {
	    #
	    # Fix up serial --unit=N --speed=S line:
	    #  vga/null: comment out
	    #  sio*: uncomment and make sure N is correct (must exist!)
	    #
	    if (/^(#?)serial\s/) {
		my $com = $1;
		if ($sunit < 0) {
		    if ($com) {
			push @buffer, $_;
		    } else {
			push @buffer, "#$_";
		    }
		} elsif ($sport) {
		    push @buffer, "serial --unit=$sunit --port=$sport --speed=$sspeed\n";
		} else {
		    push @buffer, "serial --unit=$sunit --speed=$sspeed\n";
		}
		next;
	    }
	    #
	    # grub1 terminal lines
	    #
	    if (/^terminal\s/) {
		if ($sunit < 0) {
		    push @buffer, "terminal --timeout=5 console\n";
		} else {
		    push @buffer, "terminal --dumb --timeout=0 serial console\n";
		}
		next;
	    }
	    #
	    # grub2 terminal_{input,output} lines
	    #
	    if (/^terminal_(input|output)\s/) {
		my $dir = $1;
		if ($sunit < 0) {
		    push @buffer, "terminal_$dir console\n";
		} else {
		    push @buffer, "terminal_$dir serial\n";
		}
		next;
	    }
	    #
	    # Kernel and initrd command lines with VGA (tty0)
	    #
	    if (/console=tty0\s/) {
		# get rid of any existing serial console clauses
		s#console=ttyS\S+##g;
		if ($sunit >= 0) {
		    # change tty0 to appropriate serial device
		    s#console=tty0#console=ttyS$sunit,$sspeed#;
		}
		#
		# Virtual consoles (e.g. hvcX on POWER).  Not true
		# serial consoles, so must be handled specially.
		# Image grub.cfg must have console=tty0, or
		# console=$console, for this to work.
		#
		if ($console =~ /^hvc/) {
		    if (! /console=$console/) {
			s#console=tty0#console=tty0 console=$console#;
		    }
		}
		push @buffer, $_;
		next;
	    }
	    #
	    # Xen command lines with VGA (vga)
	    #
	    if (/console=vga\s/) {
		# get rid of any existing serial console clauses
		s#console=com\d\S*##g;
		s#com\d=\S+##g;
		if ($sunit >= 0) {
		    # change vga to appropriate serial device
		    s#console=vga#console=com$comunit com$comunit=$sspeed#;
		}
		push @buffer, $_;
		next;
	    }
	    #
	    # Kernel and initrd command lines with serial (ttyS*)
	    #
	    if (/console=ttyS(\d+)/) {
		# get rid of any existing VGA clause
		s#console=tty0##g;
		if ($sunit < 0) {
		    # replace serial with VGA
		    s#console=ttyS\S+#console=tty0#g;
		} else {
		    # fixup serial lines
		    s#console=ttyS\S+#console=ttyS$sunit,$sspeed#g;
		}
		push @buffer, $_;
		next;
	    }
	    #
	    # Xen command lines with serial (console=comN, comN=<speed>)
	    #
	    if (/console=com(\d)/) {
		# get rid of any existing VGA clause
		s#console=vga##g;
		if ($sunit < 0) {
		    # replace serial with VGA
		    s#console=com\d\S*#console=vga#g;
		    s#com\d=\S+##g;
		} else {
		    # fixup serial lines
		    s#console=com\d\S*#console=com$comunit#g;
		    s#com\d=\S+#com$comunit=$sspeed#g;
		}
		push @buffer, $_;
		next;
	    }
	    #
	    # Otherwise, just copy
	    #
	    push @buffer, $_;
	}

	seek FILE, 0, 0;
	truncate FILE, 0;

	print FILE @buffer;

	close FILE;

	return;
}

sub fix_sshd_config
{
	my ($imageroot) = @_;
	my $cfile = "$imageroot/etc/ssh/sshd_config";

	print STDERR "Adding security options to SSHD config\n";
	open FILE, "+<$cfile" ||
	    die "Couldn't open $cfile: $!\n";

	my @buffer = ();
	while (<FILE>) {
		s/^Protocol .*//;
		s/^PasswordAuthentication .*//;
		s/^ChallengeResponseAuthentication .*//;
		s/^PermitRootLogin .*//;
		s/^# Emulab.*//;
		push @buffer, $_;
	}
	push @buffer, "\n# Emulab config\n";
	push @buffer, "Protocol 2\n";
	push @buffer, "PasswordAuthentication no\n";
	push @buffer, "ChallengeResponseAuthentication no\n";
	push @buffer, "PermitRootLogin without-password\n";

	seek FILE, 0, 0;
	truncate FILE, 0;

	print FILE @buffer;

	close FILE;

	return;
}

#
# Localize the image. We only do this if the MFS we are running in
# has the necessary files.
#
sub localize
{
    my ($imageroot) = @_;

    if (! -e "$LOCALIZED1" && ! -e "$LOCALIZED2") {
	return;
    }

    # Check the certs.
    if (! -d "$imageroot/etc/emulab") {
	if (!mkdir("$imageroot/etc/emulab", 0755)) {
	    print STDERR "Failed to mkdir $imageroot/etc/emulab\n";
	    return;
	}
    }
    if (-e "$ETCDIR/emulab.pem") {
	system("cmp -s $ETCDIR/emulab.pem $imageroot/etc/emulab/emulab.pem >/dev/null 2>&1");
	if ($?) {
	    print "Updating $imageroot/etc/emulab/emulab.pem\n";
	    system("cp -pf $ETCDIR/emulab.pem $imageroot/etc/emulab/");
	    if ($?) {
		print STDERR "Failed to create $ETCDIR/emulab.pem\n";
		return;
	    }
	}
    }
    if (-e "$ETCDIR/client.pem") {
	system("cmp -s $ETCDIR/client.pem $imageroot/etc/emulab/client.pem >/dev/null 2>&1");
	if ($?) {
	    print "Updating $imageroot/etc/emulab/client.pem\n";
	    system("cp -pf $ETCDIR/client.pem $imageroot/etc/emulab/");
	    if ($?) {
		print STDERR "Failed to create $ETCDIR/client.pem\n";
		return;
	    }
	}
    }

    # Check the root keys
    if (-e "/root/.ssh/authorized_keys2") {
	system("cmp -s /root/.ssh/authorized_keys2 $imageroot/root/.ssh/authorized_keys >/dev/null 2>&1");
	if ($?) {
	    print "Updating /root/.ssh/authorized_keys\n";
	    if (! -d "$imageroot/root/.ssh") {
		if (!mkdir("$imageroot/root/.ssh", 0700)) {
		    print STDERR "Failed to mkdir /root/.ssh\n";
		    return;
		}
	    }
	    # copy authorized_keys
	    system("cp -pf /root/.ssh/authorized_keys2 $imageroot/root/.ssh/authorized_keys");
	    if ($?) {
		print STDERR "Failed to create /root/.ssh/authorized_keys\n";
		return;
	    }
	}
    }

    # Check the host keys.
    my $changehostkeys = 0;
    foreach my $kt ("", "dsa_", "ecdsa_", "ed25519_", "rsa_") {
	if (-e "/etc/ssh/ssh_host_${kt}key") {
	    system("cmp -s /etc/ssh/ssh_host_${kt}key $imageroot/etc/ssh/ssh_host_${kt}key >/dev/null 2>&1");
	    if ($?) {
		$changehostkeys = 1;
	    }
	}
    }
    if ($changehostkeys) {
	print "Updating /etc/ssh host keys\n";

	if (! -d "$imageroot/etc/ssh") {
	    if (!mkdir("$imageroot/etc/ssh", 0755)) {
		print STDERR "Failed to mkdir $imageroot/etc/ssh\n";
		return;
	    }
	}
	system("cp -pf /etc/ssh/ssh_host_* $imageroot/etc/ssh/");
	if ($?) {
	    print STDERR "Failed to create /etc/ssh/hostkeys\n";
	    return;
	}
    }

    #
    # XXX more host key processing. We have to do this regardless of
    # whether the keys have actually changed.
    #
    # On CentOS private keys must be readable by the group "ssh_keys".
    # So we look up that group in the group file. If it exists, we chgrp
    # the private key files and allow group readability.
    #
    my $_gr=`grep ssh_keys $imageroot/etc/group 2>/dev/null`;
    if ($_gr) {
	my (undef, undef, $_gid) = split(':', $_gr);
	if ($_gid && $_gid =~ /^(\d+)$/) {
	    print "Changing group of host keys to ssh_keys ($_gid)\n";
	    system("chown root:$_gid $imageroot/etc/ssh/*_key");
	    system("chmod g+r $imageroot/etc/ssh/*_key");
	} else {
	    print STDERR "Failed to parse $imageroot/etc/group ssh_keys entry, ignored\n";
	}
    }

    # Check the time zone.
    if (-e "/etc/localtime") {
	system("cmp -s /etc/localtime $imageroot/etc/localtime >/dev/null 2>&1");
	if ($?) {
	    print "Updating /etc/localtime\n";

	    system("cp -pf /etc/localtime $imageroot/etc/localtime");
	    if ($?) {
		print STDERR "Failed to create /etc/localtime\n";
		return;
	    }
	}
    }

    # Check the NTP configuration.
    if (-e "/etc/ntp.conf") {
	print "Updating /etc/ntp.conf\n";

	system("cp -pf /etc/ntp.conf $imageroot/etc/ntp.conf");
	if ($?) {
	    print STDERR "Failed to create /etc/ntp.conf\n";
	    return;
	}

	# XXX cannot use /etc/ntp.drift for Linux
	if (-d "$imageroot/var/lib/ntp") {
	    file_replace_string($imageroot, "/etc/ntp.conf",
				"/etc/ntp.drift",
				"/var/lib/ntp/ntp.drift");
	}
    }

    # Check the chrony configuration.
    if (-e "/etc/chrony.conf") {
	print "Updating /etc/chrony.conf\n";

	system("cp -pf /etc/chrony.conf $imageroot/etc/chrony.conf");
	if ($?) {
	    print STDERR "Failed to create /etc/chrony.conf\n";
	    return;
	}
    }
}

sub hardwire_boss_node
{
	my ($imageroot) = @_;
	my $bossnode;

	if (-r $ETCDIR . "/bossnode") {
		local $/;
		open BOSSNODE, $ETCDIR . "/bossnode";
		$bossnode = <BOSSNODE>;
		close BOSSNODE;

		chomp $bossnode;
	}
	else {
		return undef;
	}

	if (!-d "$imageroot/etc/emulab") {
		return undef;
	}

	print "Hardwiring boss to $bossnode\n";
	if (!open BOSSNODE, "$imageroot/etc/emulab/bossnode") {
		print STDERR "Failed to create /etc/emulab/bossnode\n";
		return undef;
	}

	print BOSSNODE "$bossnode\n";
	close BOSSNODE;

	return 1;
}

sub main
{
	my ($root, $old_root) = @_;
	my $imageroot = '/mnt';
	my $new_fstab_root;
	my $new_bootloader_root;
	my $old_bootloader_root;
	my $grub_config;
	my ($kernel, $cmdline, $initrd);
	my $lilo_default;
	my $lilo_commandline = 0;

	my $old_uuid = get_uuid($root);
	set_random_rootfs_uuid($root);
	disable_time_dependent_fsck($root);
	my $fstype = mount_image($root, $imageroot);
	my $uuid = get_uuid($root);
	my $label = get_label($root);
	my $bootloader = guess_bootloader($root);
	my $old_fstab_root = get_fstab_root($imageroot);
	my $arch = `uname -m`;
	chomp($arch);

	# HACK: there's no simple way to distinguish grub2 from grub
	# by the boot sector.
	if ($bootloader eq 'grub' &&
	    (-f "$imageroot/boot/grub2/grub.cfg" ||
	     -f "$imageroot/boot/grub/grub.cfg")) {
		$bootloader = 'grub2';
	}
	# ppc64le systems can boot via OPAL/petitboot kexec, so a
	# bootloader may not be installed in the partition.
	elsif (!$bootloader && $arch eq 'ppc64le'
	       && -f "$imageroot/boot/grub/grub.cfg") {
	    $bootloader = 'grub2';
	}

	if ($bootloader eq 'lilo') {
		($lilo_default, $kernel, $cmdline, $initrd) =
		    find_default_lilo_entry($imageroot, "/etc/lilo.conf");
	}
	elsif ($bootloader eq 'grub') {
		for (qw#/boot/grub/menu.lst#) {
			if (-f "$imageroot/$_") {
				$grub_config = $_;
				last;
			}
		}

		($kernel, $cmdline, $initrd) =
		    find_default_grub_entry($imageroot, $grub_config);

	}
	elsif ($bootloader eq 'grub2') {
		for (qw#/boot/grub2/grub.cfg /boot/grub/grub.cfg#) {
			if (-f "$imageroot/$_") {
				$grub_config = $_;
				last;
			}
		}

		($kernel, $cmdline, $initrd) =
		    find_default_grub2_entry($imageroot, $grub_config);

	}
	else {
		print STDERR "Couldn't guess bootloader\n";
		return 1;
	}

	for my $token (split /\s+/, $cmdline) {
		next unless ($token =~ /^root=/);
		$token =~ s/^root=//;
		$old_bootloader_root = $token;
		last;
	}

	my ($initrd_does_label, $initrd_does_uuid) = 
	    check_initrd("$imageroot/$initrd");
	my ($mount_does_label, $mount_does_uuid) = 
	    binary_supports_blkid("$imageroot/bin/mount");

	my ($kernel_version, $kernel_has_ide) = 
	    check_kernel("$imageroot/$kernel");

	print "Old root FS uuid: $old_uuid\n";
	print "Root FS UUID: $uuid\n";
	print "Root FS LABEL: $label\n";
	print "Installed bootloader: $bootloader\n";
	print "fstab root: $old_fstab_root\n";
	print "kernel: $kernel\n";
	print "kernel version: $kernel_version\n";
	print "kernel has IDE support: $kernel_has_ide\n";
	print "cmdline: $cmdline\n";
	print "initrd: $initrd\n";
	print "initrd blkid: $initrd_does_label $initrd_does_uuid\n";
	print "mount blkid: $mount_does_label $mount_does_uuid\n";
	print "old bootloader root: $old_bootloader_root\n";

	if ($uuid && $mount_does_uuid) {
		$new_fstab_root = "UUID=$uuid";
	}
	elsif ($label && $mount_does_label) {
		$new_fstab_root = "LABEL=$label";
	}
	elsif (kernel_version_compare($kernel_version, '2.6.21') < 0 ||
	       $kernel_has_ide) {
		$new_fstab_root = $old_root;
	}
	else {
		$new_fstab_root = $root;
	}

	if ($uuid && $initrd_does_uuid) {
		$new_bootloader_root = "UUID=$uuid";
	}
	elsif ($label && $initrd_does_label) {
		$new_bootloader_root = "LABEL=$label";
	}
	elsif (kernel_version_compare($kernel_version, '2.6.21') < 0 ||
	       $kernel_has_ide) {
		$new_bootloader_root = $old_root;
	}
	else {
		$new_bootloader_root = $root;
	}

	print "Rewriting /etc/fstab to use '$new_fstab_root' as root device\n";
 	file_replace_string($imageroot, '/etc/fstab', $old_fstab_root,
	                         $new_fstab_root);
	file_replace_string($imageroot, '/etc/fstab', $old_uuid,
	                         $uuid);

	print "Rewriting $bootloader config to use '$new_bootloader_root' as root device\n";
	if ($bootloader eq 'lilo') {
		rewrite_lilo_config($imageroot, $old_bootloader_root, $new_bootloader_root);
		$lilo_commandline = set_runlilo_flag($imageroot, $lilo_default, $new_bootloader_root);
	}
	elsif ($bootloader eq 'grub') {
		print "grub config is $grub_config\n";
		#file_replace_string($imageroot, $grub_config, $old_bootloader_root,
		 #                        $new_bootloader_root);
		file_replace_string($imageroot, $grub_config, $old_uuid, $uuid);
		set_grub_root_device($imageroot, $grub_config, $root);
	}
	elsif ($bootloader eq 'grub2') {
		file_replace_string($imageroot, $grub_config, $old_bootloader_root,
		                         $new_bootloader_root);
		file_replace_string($imageroot, $grub_config, $old_uuid, $uuid);
		file_replace_string($imageroot, $grub_config, $old_uuid, $uuid);
		set_grub2_root_device($imageroot, $grub_config, $root);
	}
	fix_grub_dom0mem($imageroot, $grub_config);
	fix_console($imageroot, $bootloader, $grub_config);

	fix_swap_partitions($imageroot, $root,
		$kernel_has_ide ? $old_root : undef );

	update_random_seed($imageroot);
	localize($imageroot);
	fix_sshd_config($imageroot);
	hardwire_boss_node($imageroot);

	# Handle one-off expired root certificate
	if (-x $BINDIR . '/removecert') {
	    print "Checking for expired CA root certificate";
	    system($BINDIR . "/removecert -M");
	}

	# Run any postconfig scripts
	if (-x $BINDIR . '/osconfig') {
		print "Checking for dynamic client-side updates to slice...\n";
		system($BINDIR . "/osconfig -m $imageroot -M \"-t $fstype\" -f $fstype " .
		       "-D $root -s Linux postload");
	}

	`umount $imageroot`;

	if ($lilo_commandline) {
		$root =~ m/^(.*)(\d+)$/;
		my $disk = $1;
		my $part = $2;

		system("$BINDIR/groklilo -c \"$lilo_commandline\" $part $disk");
		if ($?) {
			print STDERR "Failed to set LILO command line\n";
			return 1;
		}
	}

	return 0;
}

main(@ARGV);
