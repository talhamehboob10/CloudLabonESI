#!/usr/bin/perl -w
#
# Copyright (c) 2009-2017 University of Utah and the Flux Group.
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
use Errno;
use Data::Dumper;
use File::Basename;

sub usage()
{
    print "Usage: capturevm.pl [-d] [-r role] vnodeid\n" . 
	  "  -d   Debug mode.\n".
	  "  -r   role (like boss or ops) to use instead of vnodeid.\n".
	  "  -i   Info mode only\n";
    exit(-1);
}
my $optlist     = "dix:r:";
my $debug       = 1;
my $infomode    = 0;
my $VMPATH      = "/var/emulab/vms/vminfo";
my $EXTRAFS	= "/capture";
my $VGNAME	= "xen-vg";
my $role;
my $XMINFO;

#
# Turn off line buffering on output
#
$| = 1;

# Locals
my %xminfo = ();

# Protos
sub Fatal($);
sub CreateExtraFS();

#
# Parse command arguments. Once we return from getopts, all that should be
# left are the required arguments.
#
my %options = ();
if (! getopts($optlist, \%options)) {
    usage();
}
if (defined($options{"d"})) {
    $debug = 1;
}
if (defined($options{"i"})) {
    $infomode = 1;
}
if (defined($options{"r"})) {
    $role = $options{"r"};
}
usage()
    if (@ARGV != 1);

my $vnodeid = $ARGV[0];
$role       = $vnodeid if (!defined($role));

if (defined($options{"x"})) {
    $XMINFO = $options{"x"};
}
else {
    $XMINFO = "$VMPATH/$vnodeid/xm.conf";
}

CreateExtraFS();
system("mkdir $EXTRAFS/$role")
    if (! -e "$EXTRAFS/$role");

#
# We need this file to figure out the disk info.
#
if (! -e "$XMINFO") {
    Fatal("$XMINFO does not exist");
}
open(XM, $XMINFO)
    or Fatal("Could not open $XMINFO: $!");
while (<XM>) {
    if ($_ =~ /^([-\w]*)\s*=\s*(.*)$/) {
	my $key = $1;
	my $val = $2;
	if ($val =~ /^'(.*)'$/) {
	    $val = $1;
	}
	$xminfo{$key} = "$val";
    }
    elsif ($_ =~ /^([-\w]*)\s*[\+\=]+\s*(.*)$/) {
	my $key = $1;
	my $val = $2;
	if ($val =~ /^'(.*)'$/) {
	    $val = $1;
	}
	$xminfo{$key} .= $val;
    }
}
close(XM);
# Filled in later.
$xminfo{"disksizes"} = "";

# For safety, only local vnc
if (exists($xminfo{"vnc"})) {
    $xminfo{"vnclisten"} = "127.0.0.1";
}

#
# Copy the kernel (and ramdisk) into the directory and change xminfo.
#
if (exists($xminfo{"kernel"})) {
    if (! -e $xminfo{"kernel"}) {
	Fatal($xminfo{"kernel"} . " does not exist");
    }
    my $kernel = "$EXTRAFS/$role/" . basename($xminfo{"kernel"});
    system("cp " . $xminfo{"kernel"} . " $kernel") == 0
	or Fatal("Could not copy kernel to $kernel");
    $xminfo{"kernel"} = basename($xminfo{"kernel"});

    if (exists($xminfo{"ramdisk"})) {
	if (! -e $xminfo{"ramdisk"}) {
	    Fatal($xminfo{"ramdisk"} . " does not exist");
	}
	my $ramdisk = "$EXTRAFS/$role/" . basename($xminfo{"ramdisk"});
	system("cp " . $xminfo{"ramdisk"} . " $ramdisk") == 0
	    or Fatal("Could not copy ramdisk to $ramdisk");
	$xminfo{"ramdisk"} = basename($xminfo{"ramdisk"});
    }
}

#
# Parse the disk info.
#
if (!exists($xminfo{'disk'})) {
    Fatal("No disk info in config file!");
}
my $disklist = eval $xminfo{'disk'};
my %diskinfo = ();
foreach my $disk (@$disklist) {
    if ($disk =~ /^phy:([^,]*)/) {
	if (! -e $1) {
	    Fatal("$disk does not exist")
	}
	$diskinfo{$1} = {"spec" => $disk};
    }
    else {
	Fatal("Cannot parse disk: $disk");
    }
}

foreach my $device (keys(%diskinfo)) {
    my $spec = $diskinfo{$device}->{"spec"};
    my $dev;
    my $filename;
    if ($spec =~ /,(sd\w+),/ || $spec =~ /,(hd\w+),/ ||
	$spec =~ /,(xvd\w+),/) {
	$dev = $1;
    }
    else {
	Fatal("Could not parse $spec");
    }
    $filename = "$role/$dev";

    #
    # Figure out the size of the LVM.
    #
    my $lv_size = `lvs -o lv_size --noheadings --units g $device`;
    Fatal("Could not get lvsize for $device")
	if ($?);
    chomp($lv_size);
    $lv_size =~ s/^\s+//;
    $lv_size =~ s/\s+$//;

    #
    # We store the size in the xminfo so we can write out a new one.
    # The sizes are for building the lvms later.
    #
    $xminfo{"disksizes"} .= ","
	if ($xminfo{"disksizes"} ne "");
    $xminfo{"disksizes"} .= "$dev:$lv_size";
    
    #
    # Do not need to do anything. 
    #
    if ($device =~ /swap/) {
	next;
    }
    print "Working on $device.\n";
    print "Size is $lv_size. Writing to $EXTRAFS/$filename\n";
    
    if ($infomode) {
	system("imagezip -i $device");
    }
    else {
	system("imagezip -o $device $EXTRAFS/$filename");
    }
    if ($?) {
	Fatal("imagezip failed");
    }
}

#
# Write out the config file.
#
if ($infomode) {
    print Dumper(\%xminfo);
}
else {
    #
    # Before we write it out, need to munge the vif spec since there is
    # no need for the script. Use just the default.
    #
    $xminfo{"vif"} =~ s/,\s*script=[^\']*//g;

    $XMINFO = "$EXTRAFS/$role/xm.conf";
    open(XM, ">$XMINFO")
	or Fatal("Could not open $XMINFO: $!");
    foreach my $key (keys(%xminfo)) {
	my $val = $xminfo{$key};
	if ($val =~ /^\[/) {
	    print XM "$key = $val\n";
	}
	else {
	    print XM "$key = '$val'\n";
	}
    }
    close(XM);
}

exit(0);

#
# Create an extra FS using an LVM.
#
sub CreateExtraFS()
{
    return
	if (-e $EXTRAFS);

    system("mkdir $EXTRAFS") == 0
	or Fatal("mkdir($EXTRAFS) failed");
    
    system("/sbin/lvcreate -n extrafs -L 100G $VGNAME") == 0
	or Fatal("lvcreate failed");

    system("mke2fs -j /dev/$VGNAME/extrafs") == 0
	or Fatal("mke2fs failed");

    system("mount /dev/$VGNAME/extrafs $EXTRAFS") == 0
	or Fatal("mount failed");
}

sub Fatal($)
{
    my ($msg) = @_;

    die("*** $0:\n".
	"    $msg\n");
}

