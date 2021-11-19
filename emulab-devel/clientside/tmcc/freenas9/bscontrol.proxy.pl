#!/usr/bin/perl -wT
#
# Copyright (c) 2013-2017 University of Utah and the Flux Group.
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
use English;
use Getopt::Std;

#
# Proxy for the blockstore server control program on boss.
#

sub usage()
{
    print STDERR "Usage: bscontrol [-hd] command args\n";
    print STDERR "   -h       This message\n";
    print STDERR "   -d       Print additional debug info\n";
    print STDERR "commands:\n";
    print STDERR "   pools    Print size info about pools\n";
    print STDERR "   volumes  Print info about volumes\n";
    print STDERR "   create <pool> <vol> <size> [ <fstype> ]\n";
    print STDERR "            Create <vol> in <pool> with <size> in MiB; optionally create a filesystem of type <fstype> on it\n";
    print STDERR "   snapshot <pool> <vol> <tstamp>\n";
    print STDERR "            Create a snapshot of <pool>/<vol> with timestamp <tstamp>\n";
    print STDERR "   clone    <pool> <ovol> <nvol> [ <tstamp> ]\n";
    print STDERR "            Create a clone of <pool>/<vol> called <nvol> from the snapshot at <tstamp> (most recent if not specified)\n";
    print STDERR "   destroy <pool> <vol>\n";
    print STDERR "            Destroy <vol> in <pool>\n";
    print STDERR "   desnapshot <pool> <vol> [ <tstamp> ]\n";
    print STDERR "            Destroy snapshot <vol>/<pool>@<tstamp>; if <tstamp> is not given, destroy all snapshots\n";
    print STDERR "   desnapshotall <pool> <vol>\n";
    print STDERR "            Like desnapshot, but removes non-blockstore related snapshots as well\n";
    print STDERR "   declone <pool> <vol>\n";
    print STDERR "            Destroy clone <vol> in <pool>; also destroys associated snapshot if this is the last clone\n";
    print STDERR "iSCSI-related debugging commands:\n";
    print STDERR "   slices    Print info about Emulab slices\n";
    print STDERR "   targets   Print info about iSCSI targets\n";
    print STDERR "   extents   Print info about iSCSI extents\n";
    print STDERR "   assocs    Print info about iSCSI target/extent assocs\n";
    print STDERR "   authinit  Print info about iSCSI authorized initiators\n";
    print STDERR "   nextaitag Print next available initiator tag\n";
    exit(-1);
}
my $optlist  = "hd";
my $debug = 0;

#
# Turn off line buffering on output
#
$| = 1;

# Drag in path stuff so we can find emulab stuff.
BEGIN { require "/etc/emulab/paths.pm"; import emulabpaths; }

# Libraries
use libfreenas;

# Protos
sub fatal($);

# Commands
my %cmds = (
    "pools"      => \&pools,
    "volumes"    => \&volumes,
    "create"     => \&create,
    "snapshot"   => \&snapshot,
    "clone"      => \&clone,
    "destroy"    => \&destroy,
    "desnapshot" => \&desnapshot,
    "declone"    => \&declone,
    "slices"     => \&slices,
    "extents"    => \&extents,
    "authinit"   => \&authinit,
    "nextaitag"  => \&nexttag,
    "targets"    => \&targets,
    "assocs"     => \&assocs,
    "desnapshotall" => \&desnapshotall,
);

#
# Parse command arguments. Once we return from getopts, all that should be
# left are the required arguments.
#
my %options = ();
if (! getopts($optlist, \%options)) {
    usage();
}
if (defined($options{h})) {
    usage();
}
if (defined($options{d})) {
    $debug = 1;
}
if (@ARGV < 1) {
    usage();
}

my $cmd = shift;
if (!exists($cmds{$cmd})) {
    print STDERR "Unrecognized command '$cmd', should be one of:\n";
    print STDERR "  ", join(", ", keys %cmds), "\n";
    usage();
}

exit(&{$cmds{$cmd}}(@ARGV));

#
# Print all the available pools from which blockstores can be allocated
# along with size info.
#
sub pools()
{
    my $pref = freenasPoolList();
    foreach my $pool (keys %{$pref}) {
	my $size = int($pref->{$pool}->{'size'});
	my $avail = int($pref->{$pool}->{'avail'});
	print "pool=$pool size=$size avail=$avail\n";
    }

    return 0;
}

#
# Print uninterpreted volume info.
#
sub volumes()
{
    my $vref = freenasVolumeList(1,1);
    foreach my $vol (keys %{$vref}) {
	my $pool = $vref->{$vol}->{'pool'};
	my $iname = $vref->{$vol}->{'iname'};
	my $size = int($vref->{$vol}->{'size'});
	my $snapshots = $vref->{$vol}->{'snapshots'};
	my $cloneof = $vref->{$vol}->{'cloneof'};

	print "volume=$vol pool=$pool size=$size";
	if ($iname) {
	    print " iname=$iname";
	}
	if ($cloneof) {
	    print " cloneof=$cloneof";
	}
	if ($snapshots) {
	    print " snapshots=$snapshots";
	}
	print "\n";
    }

    return 0;
}

#
# Print uninterpreted Emulab slice info.
#
sub slices()
{
    my $eref = freenasSliceList();
    foreach my $ext (keys %{$eref}) {
	foreach my $key ("pid", "eid", "volname", "bsid", "vnode_id", "size", "type") {
	    my $val = $eref->{$ext}->{$key};
	    $val = lc($val)
		if ($key eq "type");
	    print "$key=$val "
		if (defined($val));
	}
	print "\n";
    }

    return 0;
}

#
# Print uninterpreted iSCSI extent info.
#
sub extents()
{
    my $eref = freenasExtentList(0);
    foreach my $ext (keys %{$eref}) {
	foreach my $key ("id", "name", "path", "type", "blocksize", "filesize", "naa") {
	    my $val = $eref->{$ext}->{$key};
	    $val = lc($val)
		if ($key eq "type");
	    print "$key=$val "
		if (defined($val));
	}
	print "\n";
    }

    return 0;
}

#
# Print semi-interpreted iSCSI target info.
#
# XXX At some point between 9.3 stable releases, they changed most of the
# target info to be associated with a target group instead. We just recouple
# them here.
#
sub targets()
{
    my $tref = freenasTargetList(0);
    my $tgref = freenasTargetGroupList(1);
    foreach my $t (keys %{$tref}) {
	foreach my $key ("id", "name", "alias") {
	    my $val = $tref->{$t}->{$key};
	    print "$key=$val "
		if (defined($val));
	}
	if (exists($tgref->{$t})) {
	    my $tg = $tgref->{$t};
	    foreach my $key ("portalgroup", "initiatorgroup", "authgroup", "authtype", "initialdigest") {
		my $val = $tg->{$key};
		print "$key=$val "
		    if (defined($val));
	    }
	}
	print "\n";
    }

    return 0;
}

#
# Print uninterpreted iSCSI target/extent association info.
#
sub assocs()
{
    my $aref = freenasAssocList();
    foreach my $a (keys %{$aref}) {
	foreach my $key ("id", "target", "target_name", "target_group", "extent", "extent_name") {
	    my $val = $aref->{$a}->{$key};
	    print "$key=$val "
		if (defined($val));
	}
	print "\n";
    }

    return 0;
}

#
# Print uninterpreted iSCSI authorized initiator info.
#
sub authinit()
{
    my $airef = freenasAuthInitList();
    foreach my $ai (keys %{$airef}) {
	foreach my $key ("id", "tag", "auth_network", "comment") {
	    my $val = $airef->{$ai}->{$key};
	    print "$key=$val "
		if (defined($val));
	}
	print "\n";
    }

    return 0;
}

#
# Print next available authinit tag
#
sub nexttag() {
    my $aiinfo = freenasAuthInitList();

    my @taglist = ();
    foreach my $ai (keys %{$aiinfo}) {
	my $tag = $aiinfo->{$ai}->{'tag'};
	if (defined($tag) && $tag =~ /^(\d+)$/) {
	    push(@taglist, $1);
	}
    }

    my $freetag = 1;
    foreach my $curtag (sort {$a <=> $b} @taglist) {
	last
	    if ($freetag < $curtag);
	$freetag++;
    }

    print "nexttag=$freetag\n";
}

sub create($$$;$)
{
    my ($pool,$vol,$size,$fstype) = @_;

    # XXX create non-sparse (pre-allocated) volumes
    my $sparse = 0;

    if (defined($pool) && $pool =~ /^([-\w]+)$/) {
	$pool = $1;
    } else {
	print STDERR "bscontrol_proxy: bogus pool arg\n";
	return 1;
    }
    if (defined($vol) && $vol =~ /^([-\w]+)$/) {
	$vol = $1;
    } else {
	print STDERR "bscontrol_proxy: bogus volume arg\n";
	return 1;
    }
    if (defined($size) && $size =~ /^(\d+)$/) {
	$size = $1;
    } else {
	print STDERR "bscontrol_proxy: bogus size arg\n";
	return 1;
    }
    if (!defined($fstype)) {
	$fstype = "none";
    } elsif ($fstype =~ /^(ext2|ext3|ext4|ufs)$/) {
	$fstype = $1;
    } else {
	print STDERR "bscontrol_proxy: bogus fstype arg\n";
	return 1;
    }

    my $rv = freenasVolumeCreate($pool, $vol, $size, $sparse);
    if ($rv == 0 && $fstype ne "none") {
	$rv = freenasFSCreate($pool, $vol, $fstype);
	if ($rv && freenasVolumeDestroy($pool, $vol)) {
	    print STDERR "bscontrol_proxy: could not destroy new volume ".
		"after FS creation failure.\n";
	}
    }

    return $rv;
}

sub snapshot($$$)
{
    my ($pool,$vol,$tstamp) = @_;

    if (defined($pool) && $pool =~ /^([-\w]+)$/) {
	$pool = $1;
    } else {
	print STDERR "bscontrol_proxy: bogus pool arg\n";
	return 1;
    }
    if (defined($vol) && $vol =~ /^([-\w]+)$/) {
	$vol = $1;
    } else {
	print STDERR "bscontrol_proxy: bogus volume arg\n";
	return 1;
    }
    if (defined($tstamp) && $tstamp =~ /^(\d+)$/) {
	$tstamp = $1;
    } else {
	print STDERR "bscontrol_proxy: bogus tstamp arg\n";
	return 1;
    }

    return freenasVolumeSnapshot($pool, $vol, $tstamp);
}

sub desnapshot($$$)
{
    my ($pool,$vol,$tstamp) = @_;

    if (defined($pool) && $pool =~ /^([-\w]+)$/) {
	$pool = $1;
    } else {
	print STDERR "bscontrol_proxy: bogus pool arg\n";
	return 1;
    }
    if (defined($vol) && $vol =~ /^([-\w]+)$/) {
	$vol = $1;
    } else {
	print STDERR "bscontrol_proxy: bogus volume arg\n";
	return 1;
    }
    if (defined($tstamp)) {
	if ($tstamp =~ /^(\d+)$/) {
	    $tstamp = $1;
	} else {
	    print STDERR "bscontrol_proxy: bogus tstamp arg\n";
	    return 1;
	}
    }

    return freenasVolumeDesnapshot($pool, $vol, $tstamp, 0);
}

sub desnapshotall($$)
{
    my ($pool,$vol) = @_;

    if (defined($pool) && $pool =~ /^([-\w]+)$/) {
	$pool = $1;
    } else {
	print STDERR "bscontrol_proxy: bogus pool arg\n";
	return 1;
    }
    if (defined($vol) && $vol =~ /^([-\w]+)$/) {
	$vol = $1;
    } else {
	print STDERR "bscontrol_proxy: bogus volume arg\n";
	return 1;
    }

    return freenasVolumeDesnapshot($pool, $vol, undef, 1);
}

sub clone($$$;$)
{
    my ($pool,$ovol,$nvol,$tstamp) = @_;

    if (defined($pool) && $pool =~ /^([-\w]+)$/) {
	$pool = $1;
    } else {
	print STDERR "bscontrol_proxy: bogus pool arg\n";
	return 1;
    }
    if (defined($ovol) && $ovol =~ /^([-\w]+)$/) {
	$ovol = $1;
    } else {
	print STDERR "bscontrol_proxy: bogus origin volume arg\n";
	return 1;
    }
    if (defined($nvol) && $nvol =~ /^([-\w]+)$/) {
	$nvol = $1;
    } else {
	print STDERR "bscontrol_proxy: bogus clone volume arg\n";
	return 1;
    }
    if (defined($tstamp)) {
	if ($tstamp =~ /^(\d+)$/) {
	    $tstamp = $1;
	} else {
	    print STDERR "bscontrol_proxy: bogus tstamp arg\n";
	    return 1;
	}
    } else {
	# zero means most recent
	$tstamp = 0;
    }

    return freenasVolumeClone($pool, $ovol, $nvol, $tstamp);
}

sub destroy($$$)
{
    my ($pool,$vol) = @_;

    if (defined($pool) && $pool =~ /^([-\w]+)$/) {
	$pool = $1;
    } else {
	print STDERR "bscontrol_proxy: bogus pool arg\n";
	return 1;
    }
    if (defined($vol) && $vol =~ /^([-\w]+)$/) {
	$vol = $1;
    } else {
	print STDERR "bscontrol_proxy: bogus volume arg\n";
	return 1;
    }

    return freenasVolumeDestroy($pool, $vol);
}

sub declone($$$)
{
    my ($pool,$vol) = @_;

    if (defined($pool) && $pool =~ /^([-\w]+)$/) {
	$pool = $1;
    } else {
	print STDERR "bscontrol_proxy: bogus pool arg\n";
	return 1;
    }
    if (defined($vol) && $vol =~ /^([-\w]+)$/) {
	$vol = $1;
    } else {
	print STDERR "bscontrol_proxy: bogus volume arg\n";
	return 1;
    }

    return freenasVolumeDeclone($pool, $vol);
}
