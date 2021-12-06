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
# Support functions for the libvnode API and also for bscontrol which is
# a proxy for the blockstore server control program on boss.
#
# Uses the FreeNAS API directly.
#
# XXX things the API cannot do yet:
#
# 1. create an authorized initiator (POST); always return 302 FOUND
#
# API also does not report an error for:
#
# 1. attempting to remove a snapshot with a dependent clone
#
# So right now we use the API for all listing functions (get volumes,
# get extents, etc.) and for snapshots/clones and destroying "datasets".
#

package libfreenas;
use Exporter;
@ISA    = "Exporter";
@EXPORT =
    qw( 
	freenasPoolList freenasVolumeList freenasSliceList
	freenasAuthInitList freenasExtentList freenasTargetList
	freenasTargetGroupList freenasAssocList
	freenasVolumeCreate freenasVolumeDestroy freenasFSCreate
	freenasVolumeSnapshot freenasVolumeClone
	freenasVolumeDesnapshot freenasVolumeDeclone
	freenasRunCmd freenasParseListing
	freenasRequest
	$FREENAS_CLI_VERB_IFACE $FREENAS_CLI_VERB_IST_EXTENT
	$FREENAS_CLI_VERB_IST_AUTHI $FREENAS_CLI_VERB_IST_TARGET
	$FREENAS_CLI_VERB_IST_ASSOC $FREENAS_CLI_VERB_VLAN
	$FREENAS_CLI_VERB_VOLUME $FREENAS_CLI_VERB_POOL
	$FREENAS_CLI_VERB_SNAPSHOT

	$FREENAS_API_RESOURCE_IFACE $FREENAS_API_RESOURCE_IST_EXTENT
	$FREENAS_API_RESOURCE_IST_AUTHI $FREENAS_API_RESOURCE_IST_TARGET
	$FREENAS_API_RESOURCE_IST_TGTGROUP
	$FREENAS_API_RESOURCE_IST_ASSOC $FREENAS_API_RESOURCE_VLAN
	$FREENAS_API_RESOURCE_VOLUME $FREENAS_API_RESOURCE_SNAPSHOT
    );

use strict;
use English;
use HTTP::Tiny;
use JSON::PP;
use MIME::Base64;
use Data::Dumper;
use Socket;
use File::Basename;
use File::Path;
use File::Copy;

# Pull in libvnode and other Emulab stuff
BEGIN { require "/etc/emulab/paths.pm"; import emulabpaths; }
use libutil;
use libtestbed;
use libsetup;

#
# Exported resources
#
our $FREENAS_API_RESOURCE_IFACE       = "network/interface";
our $FREENAS_API_RESOURCE_IST_EXTENT  = "services/iscsi/extent";
our $FREENAS_API_RESOURCE_IST_AUTHI   = "services/iscsi/authorizedinitiator";
our $FREENAS_API_RESOURCE_IST_TARGET  = "services/iscsi/target";
our $FREENAS_API_RESOURCE_IST_TGTGROUP= "services/iscsi/targetgroup";
our $FREENAS_API_RESOURCE_IST_ASSOC   = "services/iscsi/targettoextent";
our $FREENAS_API_RESOURCE_VLAN        = "network/vlan";
our $FREENAS_API_RESOURCE_VOLUME      = "storage/volume";
our $FREENAS_API_RESOURCE_SNAPSHOT    = "storage/snapshot";

#
# Exported CLI constants
#
our $FREENAS_CLI_VERB_IFACE       = "interface";
our $FREENAS_CLI_VERB_IST_EXTENT  = "ist_extent";
our $FREENAS_CLI_VERB_IST_AUTHI   = "ist_authinit";
our $FREENAS_CLI_VERB_IST_TARGET  = "ist";
our $FREENAS_CLI_VERB_IST_ASSOC   = "ist_assoc";
our $FREENAS_CLI_VERB_VLAN        = "vlan";
our $FREENAS_CLI_VERB_VOLUME      = "volume";
our $FREENAS_CLI_VERB_POOL        = "pool";
our $FREENAS_CLI_VERB_SNAPSHOT    = "snapshot";

#
# Constants
#
my $GLOBAL_CONF_LOCK     = "blkconf";
my $ZPOOL_CMD            = "/sbin/zpool";
my $ZFS_CMD              = "/sbin/zfs";
my $ZPOOL_STATUS_UNKNOWN = "unknown";
my $ZPOOL_STATUS_ONLINE  = "online";
my $ZPOOL_LOW_WATERMARK  = 2 * 2**10; # 2GiB, expressed in MiB
my $FREENAS_MNT_PREFIX   = "/mnt";
my $ISCSI_GLOBAL_PORTAL  = 1;
my $SER_PREFIX           = "d0d0";
my $VLAN_IFACE_PREFIX    = "vlan";
my $MAX_RETRY_COUNT      = 5;
my $VOLUME_BUSY_WAIT      = 10;
my $VOLUME_GONE_WAIT      = 5;
my $IFCONFIG             = "/sbin/ifconfig";
my $ALIASMASK            = "255.255.255.255";
my $LINUX_MKFS		 = "/usr/local/sbin/mke2fs";
my $FBSD_MKFS		 = "/sbin/newfs";
my $API_AUTHINFO	 = "$ETCDIR/freenas-api.auth";
my $API_SERVERIP	 = "/var/emulab/boot/myip";

# storageconfig constants
# XXX: should go somewhere more general
my $BS_CLASS_SAN         = "SAN";
my $BS_PROTO_ISCSI       = "iSCSI";
my $BS_UUID_TYPE_IQN     = "iqn";

# CLI stuff
my $FREENAS_CLI          = "$BINDIR/freenas-config";

my %cliverbs = (
    $FREENAS_CLI_VERB_IFACE      => 1,
    $FREENAS_CLI_VERB_IST_EXTENT => 1,
    $FREENAS_CLI_VERB_IST_AUTHI  => 1,
    $FREENAS_CLI_VERB_IST_TARGET => 1,
    $FREENAS_CLI_VERB_IST_ASSOC  => 1,
    $FREENAS_CLI_VERB_VLAN       => 1,
    $FREENAS_CLI_VERB_VOLUME     => 1,
    $FREENAS_CLI_VERB_POOL       => 1,
    $FREENAS_CLI_VERB_SNAPSHOT   => 1,
    );

#
# Global variables
#
my $debug  = 0;
my $auth;
my $server;

sub freenasPoolList();
sub freenasVolumeList($;$);
sub freenasVolumeCreate($$$;$);
sub freenasVolumeDestroy($$);
sub freenasFSCreate($$$);
sub freenasRunCmd($$);
sub freenasParseListing($);

sub freenasVolumeSnapshot($$;$);
sub freenasVolumeDesnapshot($$;$$);
sub freenasVolumeClone($$$;$);
sub freenasVolumeDeclone($$);

#
# Local Functions
#
sub listPools();
sub convertZfsToMebi($);
sub volumeDestroy($$$$);
sub snapshotHasClone($$);
sub getZvolsFromVolinfo($);
sub parseSliceName($);
sub parseSlicePath($);
sub calcSliceSizes($);

#
# Turn off line buffering on output
#
$| = 1;

sub setDebug($)
{
    $debug = shift;
    print "libfreenas: debug=$debug\n"
	if ($debug);
}

#
# Make a request via the FreeNAS v1.0 API.
#   $resourse is the resource path, e.g., "account/users"
#   $method is "GET", "PUT", "POST", or "DELETE" (default is "GET")
#   $paramp is a reference to a hash of KEY=VALUE URL params (default is ())
#   $datap is a reference to a hash of KEY=VALUE input content (default is ())
#   $exstat is the expected success status code if not the method default
#   $errorp is a reference to a string, used to return error string if !undef
# Return value is the decoded (as a hash) JSON KEY=VALUE returned by request
# Returns undef on failure.
#
sub freenasRequest($;$$$$$)
{
    my ($resource,$method,$paramp,$datap,$exstat,$errorp) = @_;
    my %data = $datap ? %$datap : ();
    my ($datastr,$paramstr);
    my %status = (
	"GET"    => 200,
	"PUT"    => 200,
	"POST"   => 201,
	"DELETE" => 204
    );

    # XXX read the authentication info in user:password format
    if (!$auth) {
	if (!open(FD, "<$API_AUTHINFO")) {
	    my $msg = "could not open $API_AUTHINFO";
	    if ($errorp) {
		$$errorp = $msg;
	    } else {
		warn("*** ERROR: freenasRequest: $msg");
	    }
	    return undef;
	}
	$auth = <FD>;
	close(FD);
	chomp $auth;
	if ($auth !~ /^(\w+:.*)$/) {
	    my $msg = " bogus authinfo, wrong format";
	    if ($errorp) {
		$$errorp = $msg;
	    } else {
		warn("*** ERROR: freenasRequest: $msg");
	    }
	    return undef;
	}
	$auth = $1;
    }

    # XXX use the node's IP rather than "localhost" if possible
    if (!$server) {
	$server = "localhost";
	if (-e "$API_SERVERIP" && open(FD, "<$API_SERVERIP")) {
	    $server = <FD>;
	    close(FD);
	    chomp $server;
	    if ($server =~ /^(\d+\.\d+\.\d+\.\d+)$/) {
		$server = $1;
	    }
	}
    }

    $method = "GET"
	if (!defined($method));

    $datastr = encode_json(\%data);
    $paramstr = "";
    if ($paramp) {
	my @params = ();
	foreach my $k (keys %$paramp) {
	    my $v = $paramp->{$k};
	    push @params, "$k=$v";
	}
	if (@params) {
	    $paramstr = "?" . join('&', @params);
	}
    }

    my $url = "http://$server/api/v1.0/$resource/$paramstr";
    print STDERR "freenasRequest: URL: $url\nCONTENT: $datastr\n"
	if ($debug);

    my %headers = (
	"Content-Type"  => "application/json",
	"Authorization" => "Basic " . MIME::Base64::encode_base64($auth, "")
    );
    my $http = HTTP::Tiny->new("timeout" => 30);
    my %options = ("headers" => \%headers, "content" => $datastr); 

    my $res = $http->request($method, $url, \%options);
    print STDERR "freenasRequest: RESPONSE: ", Dumper($res), "\n"
	if ($debug);

    $exstat = $status{$method}
	if (!defined($exstat));

    if ($res->{'success'} && $res->{'status'} == $exstat) {
	if (exists($res->{'headers'}{'content-type'}) &&
	    $res->{'headers'}{'content-type'} eq "application/json") {
	    return JSON::PP->new->decode($res->{'content'});
	}
	if (!exists($res->{'content'})) {
	    return {};
	}
	if (!ref($res->{'content'})) {
	    return { "content" => $res->{'content'} };
	}
	my $msg = "Unparsable content: " . Dumper($res->{'content'});
	if ($errorp) {
	    $$errorp = $msg;
	} else {
	    warn("*** ERROR: freenasRequest: $msg");
	}
	return undef;
    }
    if ($res->{'reason'}) {
	my $content;

	if (exists($res->{'content'}) &&
	    exists($res->{'headers'}{'content-type'})) {
	    my $ctype = $res->{'headers'}{'content-type'};
	    if ($ctype eq "text/plain") {
		$content = $res->{'content'};
	    } elsif ($ctype eq "application/json") {
		my $cref =
		    JSON::PP->new->allow_nonref->decode($res->{'content'});
		if ($cref && ref $cref) {
		    if (exists($cref->{'__all__'})) {
			$content = $cref->{'__all__'};
		    } elsif (exists($cref->{'error'})) {
			$content = $cref->{'error'};
		    } elsif (exists($cref->{'error_message'})) {
			$content = $cref->{'error_message'};
		    }
		} elsif ($cref) {
		    $content = $cref;
		} else {
		    $content = $res->{'content'};
		}
	    }
	}
	my $msg = "Request failed: " . $res->{'reason'};
	if ($content) {
	    $msg .= "\nFreeNAS error: $content";
	}
	if ($errorp) {
	    $$errorp = $msg;
	} else {
	    warn("*** ERROR: freenasRequest: $msg");
	}
	return undef;
    }

    my $msg = "Request failed: " . Dumper($res);
    if ($errorp) {
	$$errorp = $msg;
    } else {
	warn("*** ERROR: freenasRequest: $msg");
    }
    return undef;
}

sub freenasVolumeList($;$)
{
    my ($inameinfo,$snapinfo) = @_;
    my $vollist = {};

    $inameinfo = 0 if (!defined($inameinfo));
    $snapinfo  = 0 if (!defined($snapinfo));

    # Assorted hack maps
    my %inames = ();	# volume-name -> slice-name
    my %snaps = ();	# volume-name -> (snapshot1 snapshot2 ...)
    my %clones = ();	# clone-volume-name -> snapshot
    my %zvolsizes = ();	# volume-name -> volsize

    #
    # Extract blockstores from the freenas volume info and augment
    # with slice info where it exists.
    # 
    if ($inameinfo) {
	my $extinfo = freenasRequest($FREENAS_API_RESOURCE_IST_EXTENT,
				     "GET", { "limit" => 0 });
	foreach my $ext (@$extinfo) {
	    if ($ext->{'iscsi_target_extent_path'} =~ /^\/dev\/zvol\/([-\w]+\/[-\w+]+)$/) {
		$inames{$1} = $ext->{'iscsi_target_extent_name'};
	    }
	}
    }

    if ($snapinfo) {
	my $sinfo = freenasRequest($FREENAS_API_RESOURCE_SNAPSHOT,
				   "GET", { "limit" => 0 });
	my @snames = ();
	foreach my $snap (@$sinfo) {
	    my $vol = $snap->{'filesystem'};
	    next if (!$vol);

	    # XXX only track snapshots we create (10 digit timestamp)
	    # XXX note that we do return these if $snapinfo==2
	    next if ($snap->{'name'} !~ /^\d{10}$/ && $snapinfo != 2);

	    # XXX only handle zvols right now
	    next if ($snap->{'parent_type'} ne 'volume');

	    if ($snap->{'fullname'} =~ /^(.*)\/([^\/]+)$/) {
		my $sname = $2;
		push(@snames, "$1/$2");
		$snaps{$vol} = [ ] if (!exists($snaps{$vol}));
		push(@{$snaps{$vol}}, $sname);
	    }
	}

	# have to use "zfs get" to get clone info
	if (open(ZFS, "$ZFS_CMD get -o name,value -Hp clones @snames |")) {
	    while (my $line = <ZFS>) {
		chomp $line;
		my ($name, $val) = split(/\s+/, $line);
		if ($name =~ /\/([^\/]+)$/) {
		    my $sname = $1;
		    foreach my $clone (split(',', $val)) {
			$clones{$clone} = $sname;
		    }
		}
	    }
	    close(ZFS);
	} else {
	    warn("*** WARNING: could not run 'zfs get' for clone info");
	}
    }

    #
    # XXX unbelievable: the storage/volume API does not return the volsize
    # of a zvol! Gotta do it ourselves...
    #
    # XXX we could now get this through storage/volume/<pool>/zvols for
    # each pool, or storage/volume/<pool>/zvols/<volume> for each zvol.
    # But for now, let's just stick with the ZFS command.
    #
    if (open(ZFS, "$ZFS_CMD get -t volume -o name,value -Hp volsize |")) {
	while (my $line = <ZFS>) {
	    chomp $line;
	    my ($name, $val) = split(/\s+/, $line);
	    $zvolsizes{$name} = $val;
	}
	close(ZFS);
    } else {
	warn("*** WARNING: could not run 'zfs get' for zvol size info");
    }

    #
    # The FreeNAS API returns pools, filesystems, zvols using "volume"
    # so we have to dig the zvols out from there.
    #
    my $vinfo = freenasRequest($FREENAS_API_RESOURCE_VOLUME,
			       "GET", {"limit" => 0});
    my @zvols = getZvolsFromVolinfo($vinfo);

    foreach my $zvol (@zvols) {
	my $vol = {};
	my $volname = $zvol->{'path'};

	if ($volname =~ /^([-\w]+)\/([-\w+]+)$/) {
	    $vol->{'pool'} = $1;
	    $vol->{'volume'} = $2;
	    if (exists($zvolsizes{$volname})) {
		$vol->{'size'} = convertToMebi($zvolsizes{$volname});
	    } else {
		$vol->{'size'} = 0;
		warn("*** WARNING: could not get volume size of $volname");
	    }

	    if ($inameinfo && exists($inames{$zvol->{'path'}})) {
		$vol->{'iname'} = $inames{$zvol->{'path'}};
	    }
	    if ($snapinfo) {
		my $sref = $snaps{$zvol->{'path'}};
		if ($sref && @$sref > 0) {
		    #
		    # For convenience of the caller, who typically only cares
		    # about the most recent snapshot, we sort the snapshot
		    # list from newest to oldest.
		    #
		    # XXX note that we can just (reverse) sort lexically since
		    # the timestamp suffix is fixed in length. Well technically
		    # it is not fixed-length, but it won't go to 11 digits for
		    # another 270 years or so...
		    #
		    $vol->{'snapshots'} = join(',', sort {$b cmp $a} @$sref);
		}
		my $sname = $clones{$zvol->{'path'}};
		if ($sname) {
		    $vol->{'cloneof'} = $sname;
		}
	    }
	    $vollist->{$vol->{'volume'}} = $vol;
	}
    }

    return $vollist;
}

sub freenasPoolList() {
    return listPools();
}

#
# Create a ZFS zvol.
#
sub freenasVolumeCreate($$$;$)
{
    my ($pool, $volname, $size, $sparse) = @_;

    # Untaint arguments since they are passed to a command execution
    $pool = untaintHostname($pool);
    $volname = untaintHostname($volname);
    $size = untaintNumber($size);
    $sparse = untaintNumber($sparse);
    if (!$pool || !$volname || !$size) {
	warn("*** ERROR: freenasVolumeCreate: ".
	     "Invalid arguments");
	return -1;
    }

    # Does the requested pool exist?
    my $pools = listPools();
    my $destpool;
    if (exists($pools->{$pool})) {
	$destpool = $pools->{$pool};
    } else {
	warn("*** ERROR: freenasVolumeCreate: ".
	     "Requested pool not found: $pool!");
	return -1;
    }

    # Is there enough space in the requested pool?
    # If not, there is a discrepancy between reality and the Emulab database.
    if ($size + $ZPOOL_LOW_WATERMARK > $destpool->{'avail'}) {
	warn("*** ERROR: freenasVolumeCreate: ". 
	     "Not enough space remaining in requested pool: $pool");
	return -1;
    }

    # XXX the traditional default for FreeNAS seems to be true
    my $sparsearg = JSON::PP::true;
    if (defined($sparse) && $sparse == 0) {
	$sparsearg = JSON::PP::false;
    }

    my $msg;
    my $res = freenasRequest("$FREENAS_API_RESOURCE_VOLUME/${pool}/zvols",
			     "POST", undef,
			     {"name" => "$volname",
			      "volsize" => "${size}M",
			      "sparse" => $sparsearg },
			     undef, \$msg);
    if (!$res) {
	if ($msg) {
	    warn("*** ERROR: freenasVolumeCreate: ".
		 "volume creation failed:\n$msg");
	} else {
	    warn("*** ERROR: freenasVolumeCreate: volume creation failed");
	}
	return -1;
    }

    # Make sure compression is disabled. Could be an option?
    $res =
	freenasRequest("$FREENAS_API_RESOURCE_VOLUME/${pool}/zvols/${volname}",
		       "PUT", undef, { "compression" => "off" });
    if (!$res) {
	warn("*** ERROR: freenasVolumeCreate: could not disable compression");
    }

    return 0;
}

sub freenasVolumeSnapshot($$;$)
{
    my ($pool, $volname, $tstamp) = @_;

    # Untaint arguments that are passed to a command execution
    $pool = untaintHostname($pool);
    $volname = untaintHostname($volname);
    if (defined($tstamp) && $tstamp != 0) {
	$tstamp = untaintNumber($tstamp);
    } else {
	$tstamp = time();
    }
    if (!$pool || !$volname || !$tstamp) {
	warn("*** ERROR: freenasVolumeSnapshot: ".
	     "Invalid arguments");
	return -1;
    }

    # Get volume and snapshot info
    my $vollist = freenasVolumeList(0, 1);

    # The base volume must exist
    my $vref = $vollist->{$volname};
    if (!$vref || $vref->{'pool'} ne $pool) {
	warn("*** ERROR: freenasVolumeSnapshot: ".
	     "Base volume '$volname' does not exist in pool '$pool'");
	return -1;
    }

    # The snapshot must not exist
    my $snapshot = "$volname\@$tstamp";
    if (exists($vref->{'snapshots'})) {
	my @snaps = split(',', $vref->{'snapshots'});

	foreach my $sname (@snaps) {
	    if ($snapshot eq $sname) {
		warn("*** ERROR: freenasVolumeSnapshot: ".
		     "Snapshot '$snapshot' already exists");
		return -1;
	    }
	}
    }

    # Let's do it!
    my $res = freenasRequest($FREENAS_API_RESOURCE_SNAPSHOT, "POST", undef,
			     {"dataset" => "$pool/$volname",
			      "name" => "$tstamp"});
    if (!$res) {
	warn("*** ERROR: freenasVolumeSnapshot: could not create snapshot");
	return -1;
    }

    return 0;
}

sub freenasVolumeDesnapshot($$;$$)
{
    my ($pool, $volname, $tstamp, $force) = @_;

    # Untaint arguments that are passed to a command execution
    $pool = untaintHostname($pool);
    $volname = untaintHostname($volname);
    if (defined($tstamp)) {
	$tstamp = untaintNumber($tstamp);
    } else {
	$tstamp = 0;
    }
    if (!$pool || !$volname || !defined($tstamp)) {
	warn("*** ERROR: freenasVolumeSnapshot: ".
	     "Invalid arguments");
	return -1;
    }

    # Get volume and snapshot info
    my $vollist = freenasVolumeList(0, ($force ? 2 : 1));

    # The base volume must exist
    my $vref = $vollist->{$volname};
    if (!$vref || $vref->{'pool'} ne $pool) {
	warn("*** ERROR: freenasVolumeDesnapshot: ".
	     "Base volume '$volname' does not exist in pool '$pool'");
	return -1;
    }

    # Loop through removing snapshots as appropriate.
    my $rv = 0;
    if (exists($vref->{'snapshots'})) {
	my @snaps = split(',', $vref->{'snapshots'});
	my $snapshot = "$volname\@$tstamp"
	    if ($tstamp);

	foreach my $sname (@snaps) {
	    if (!$tstamp || $snapshot eq $sname) {
		#
		# XXX API does not return an error if you try to remove
		# a snapshot that has a clone. So we have to check ourselves.
		#
		if (snapshotHasClone($sname, $vollist)) {
		    warn("*** WARNING: freenasVolumeDesnapshot: ".
			 "snapshot '$sname' in use");

		    #
		    # XXX only return an error for this case if we are
		    # removing a specific snapshot. Otherwise, it causes
		    # too much drama up the line for something that is
		    # "normal" (i.e., we are attempting to remove all
		    # snapshots and some of them are in use).
		    #
		    if ($tstamp) {
			$rv = -1;
		    }
		    next;
		}

		#
		# Otherwise, try to remove the snapshot.
		#
		my $msg;
		my $resource =
		    "$FREENAS_API_RESOURCE_SNAPSHOT/${pool}\%2F${sname}";

		my $res = freenasRequest($resource, "DELETE",
					 undef, undef, undef, \$msg);
		if (!$res) {
		    warn("*** ERROR: freenasVolumeDesnapshot: ".
			 "delete of $snapshot failed:\n$msg");

		    # if it isn't an "in use" error, we really do fail
		    $rv = -1;
		}
	    }
	}
    }

    return $rv;
}

#
# Create a clone volume named $nvolname from volume $ovolname.
# The clone will be created from the snapshot $volname-$tag where
# $tag is interpreted as a timestamp. If $tag == 0, use the most recent
# (i.e., largest timestamp) snapshot.
#
sub freenasVolumeClone($$$;$)
{
    my ($pool, $ovolname, $nvolname, $tag) = @_;

    # Untaint arguments that are passed to a command execution
    $pool = untaintHostname($pool);
    $ovolname = untaintHostname($ovolname);
    $nvolname = untaintHostname($nvolname);
    if (defined($tag)) {
	$tag = untaintNumber($tag);
    } else {
	$tag = 0;
    }
    if (!$pool || !$ovolname || !$nvolname || !defined($tag)) {
	warn("*** ERROR: freenasVolumeClone: ".
	     "Invalid arguments");
	return -1;
    }

    # Get volume and snapshot info
    my $vollist = freenasVolumeList(0, 1);

    # The base volume must exist, the clone must not
    my $ovref = $vollist->{$ovolname};
    if (!$ovref || $ovref->{'pool'} ne $pool) {
	warn("*** ERROR: freenasVolumeClone: ".
	     "Base volume '$ovolname' does not exist in pool '$pool'");
	return -1;
    }
    if (exists($vollist->{$nvolname})) {
	warn("*** ERROR: freenasVolumeClone: ".
	     "Volume '$nvolname' already exists");
	return -1;
    }

    # Base must have at least one snapshot
    if (!exists($ovref->{'snapshots'})) {
	warn("*** ERROR: freenasVolumeClone: ".
	     "Base volume '$ovolname' has no snapshots");
	return -1;
    }
    my @snaps = split(',', $ovref->{'snapshots'});

    # If specified explicitly, the named snapshot must exist
    my $snapshot;
    if ($tag) {
	my $found = 0;
	$snapshot = "$ovolname\@$tag";
	foreach my $sname (@snaps) {
	    if ($snapshot eq $sname) {
		$found = 1;
		last;
	    }
	}
	if (!$found) {
	    warn("*** ERROR: freenasVolumeClone: ".
		 "Snapshot '$snapshot' does not exist");
	    return -1;
	}
    }

    # Otherwise find the most recent snapshot
    else {
	foreach my $sname (@snaps) {
	    if ($sname =~ /^$ovolname\@(\d+)$/ && $1 > $tag) {
		$tag = $1;
	    }
	}
	$snapshot = "$ovolname\@$tag";
    }

    my $resource =
	"$FREENAS_API_RESOURCE_SNAPSHOT/${pool}\%2F${snapshot}/clone";

    my $res = freenasRequest($resource, "POST", undef,
			     {"name" => "$pool/$nvolname"}, 202);
    if (!$res) {
	warn("*** ERROR: freenasVolumeClone: could not create clone");
	return -1;
    }

    return 0;
}

sub freenasVolumeDeclone($$)
{
    my ($pool, $volname) = @_;

    # Untaint arguments since they are passed to a command execution
    $pool = untaintHostname($pool);
    $volname = untaintHostname($volname);
    if (!$pool || !$volname) {
	warn("*** ERROR: freenasVolumeDeclone: ".
	     "Invalid arguments");
	return -1;
    }

    return volumeDestroy($pool, $volname, 1, "freenasVolumeDeclone");
}

sub freenasVolumeDestroy($$)
{
    my ($pool, $volname) = @_;

    # Untaint arguments since they are passed to a command execution
    $pool = untaintHostname($pool);
    $volname = untaintHostname($volname);
    if (!$pool || !$volname) {
	warn("*** ERROR: freenasVolumeDestroy: ".
	     "Invalid arguments");
	return -1;
    }

    return volumeDestroy($pool, $volname, 0, "freenasVolumeDestroy");
}

#
# The guts of destroy and declone
#
sub volumeDestroy($$$$) {
    my ($pool, $volname, $declone, $tag) = @_;

    # Get volume and snapshot info
    my $vollist = freenasVolumeList(0, 1);

    # Volume must exist
    my $vref = $vollist->{$volname};
    if (!$vref || $vref->{'pool'} ne $pool) {
	warn("*** ERROR: $tag: ".
	     "Volume '$volname' does not exist in pool '$pool'");
	return -1;
    }

    # Volume must not have snapshots
    if (exists($vref->{'snapshots'})) {
	warn("*** ERROR: $tag: ".
	     "Volume '$volname' has clones and/or snapshots, cannot destroy");
	return -1;
    }
 
    # Deallocate volume.  Wrap in loop to enable retries.
    my $count;
    for ($count = 1; $count <= $MAX_RETRY_COUNT; $count++) {
	my $resource = "$FREENAS_API_RESOURCE_VOLUME/$pool/datasets/$volname";
	my $msg;

	my $res = freenasRequest($resource, "DELETE", undef, undef,
				 undef, \$msg);

	# Retry on some errors
	if (!$res) { 
	    if ($msg =~ /dataset is busy/) {
		warn("*** WARNING: $tag: ".
		     "Volume is busy. ".
		     "Waiting $VOLUME_BUSY_WAIT seconds before trying again ".
		     "(count=$count).");
		sleep $VOLUME_BUSY_WAIT;
	    }
	    elsif ($msg =~ /does not exist/) {
		if ($count < $MAX_RETRY_COUNT) {
		    warn("*** WARNING: $tag: ".
			 "Volume seems to be gone, retrying.");
		    # Bump counter to just under termination to try once more.
		    $count = $MAX_RETRY_COUNT-1;
		    sleep $VOLUME_GONE_WAIT;
		} else {
		    warn("*** WARNING: $tag: ".
			 "Volume still seems to be gone.");
		    # Bail now because we don't want to report this as an
		    # error to the caller.
		    return 0;
		}
	    } 
	    else {
		$msg =~ s/\\n/\n  /g;
		warn("*** ERROR: $tag: ".
		     "Volume removal failed:\n$msg");
		return -1;
	    }
	} else {
	    # No error condition - jump out of loop.
	    last;
	}
    }

    # Note: Checks for lingering volumes will be performed separately in
    # consistency checking routines.

    if ($count > $MAX_RETRY_COUNT) {
	warn("*** WARNING: $tag: ".
	     "Could not free volume after several attempts!");
	return -1;
    }

    #
    # If decloning, see if we can whack the snapshot
    #
    if (exists($vref->{'cloneof'})) {
	my $snapshot = $vref->{'cloneof'};
	if ($declone) {
	    my $msg;
	    my $resource =
		"$FREENAS_API_RESOURCE_SNAPSHOT/${pool}\%2F${snapshot}";

	    my $res = freenasRequest($resource, "DELETE",
				     undef, undef, undef, \$msg);
	    if (!$res) {
		if ($msg =~ /has dependent clones/) {
		    return 0;
		}
		my $msg = "  $@";
		$msg =~ s/\\n/\n  /g;
		warn("*** ERROR: freenasVolumeDeclone: ".
		     "'del $pool/$snapshot' failed:\n$msg");
		return -1;
	    }
	} else {
	    warn("*** WARNING: $tag: ".
		 "Destroying clone but not origin snapshot '$snapshot'");
	}
    }

    return 0;
}

sub snapshotHasClone($$)
{
    my ($sname, $vollist) = @_;

    foreach my $vol (keys %{$vollist}) {
	if (exists($vollist->{$vol}->{'cloneof'}) && 
	    $vollist->{$vol}->{'cloneof'} eq $sname) {
	    return 1;
	}
    }
    return 0;
}

#
# Run a FreeNAS CLI command, checking for a return error and other
# such things.  We check that the incoming verb is valid.  Command line
# argument string needs to be untainted or this will fail.
#
# Throws exceptions (dies), passing along errors in $@.
#
sub freenasRunCmd($$) {
    my ($verb, $argstr) = @_;

    my $errstate = 0;
    my $message;

    die "Invalid FreeNAS CLI verb: $verb"
	unless exists($cliverbs{$verb});

    print "DEBUG: blockstore_freenasRunCmd:\n".
	"\trunning: $verb $argstr\n" if $debug;

    my $output = `$FREENAS_CLI $verb $argstr 2>&1`;

    if ($? != 0) {
	$errstate = 1;
	$output =~ /^(.+Error: .+)$/;
	$message = defined($1) ? $1 : "Error code: $?";
    } elsif ($output =~ /"error": true/) {
	$errstate = 1;
	$output =~ /"message": "([^"]+)"/;
	$message = defined($1) ? $1 : "Unknown error";
    }

    if ($errstate) {
	print STDERR $output if $debug;
	die $message;
    }

    return 0;
}

# Run our custom FreeNAS CLI to extract info.  
#
# Returns an array of hash references.  Each hash contains info from
# one line of output.  The hash keys are the field names from the
# header (first line of output).  The hash values are the
# corresponding pieces of data at each field location in a line.
sub freenasParseListing($) {
    my $verb = shift;
    my @retlist = ();

    die "Invalid FreeNAS CLI verb: $verb"
	unless exists($cliverbs{$verb});

    open(CLI, "$FREENAS_CLI $verb list |") or
	die "Can't run FreeNAS CLI: $!";

    my $header = <CLI>;

    return @retlist
	if !defined($header) or !$header;

    chomp $header;
    my @fields = split(/\t/, $header);

    while (my $line = <CLI>) {
	chomp $line;
	my @lparts = split(/\t/, $line);
	if (scalar(@lparts) != scalar(@fields)) {
	    warn("*** WARNING: blockstore_freenasParseListing: ".
		 "Bad output from CLI ($verb): $line");
	    next;
	}
	my %lineh = ();
	for (my $i = 0; $i < scalar(@fields); $i++) {
	    $lineh{$fields[$i]} = $lparts[$i];
	}
	push @retlist, \%lineh;
    }
    close(CLI);
    return @retlist;
}

sub freenasFSCreate($$$) {
    my ($pool,$vol,$fstype) = @_;
    my $cmd;

    if ($fstype =~ /^ext[234]$/) {
	$cmd = "$LINUX_MKFS -t $fstype -o Linux";
    } elsif ($fstype eq "ufs") {
	$cmd = "$FBSD_MKFS";
    } else {
	warn("*** WARNING: freenasFSCreate: unknown fs type '$fstype'");
	return -1;
    }
    my $redir = ">/dev/null 2>&1";
    if (system("$cmd /dev/zvol/$pool/$vol $redir") != 0) {
	warn("*** WARNING: freenasFSCreate: '$cmd /dev/zvol/$pool/$vol' failed");
	return -1;
    }

    return 0;
}

#
# Return list of authorized initiators
#
sub freenasAuthInitList() {
    my $aihash = {};
    my $aiinfo = freenasRequest($FREENAS_API_RESOURCE_IST_AUTHI,
				"GET", { "limit" => 0 });

    foreach my $ai (@$aiinfo) {
	# XXX shorten the names
	foreach my $key (keys %{$ai}) {
	    if ($key =~ /^iscsi_target_initiator_(.*)/) {
		if (!exists($ai->{$1})) {
		    $ai->{$1} = $ai->{$key};
		    delete $ai->{$key};
		}
	    }
	}
	$aihash->{$ai->{'id'}} = $ai;
    }

    return $aihash;
}

#
# Return list of extents
#
sub freenasExtentList($) {
    my ($byname) = @_;
    my $exthash = {};
    my $extinfo = freenasRequest($FREENAS_API_RESOURCE_IST_EXTENT,
				 "GET", { "limit" => 0 });

    foreach my $ext (@$extinfo) {
	# XXX shorten the names
	foreach my $key (keys %{$ext}) {
	    if ($key =~ /^iscsi_target_extent_(.*)/) {
		if (!exists($ext->{$1})) {
		    $ext->{$1} = $ext->{$key};
		    delete $ext->{$key};
		}
	    }
	}
	if ($byname) {
	    $exthash->{$ext->{'name'}} = $ext;
	} else {
	    $exthash->{$ext->{'id'}} = $ext;
	}
    }

    return $exthash;
}

#
# Return list of targets
#
sub freenasTargetList($) {
    my ($byname) = @_;
    my $thash = {};
    my $tinfo = freenasRequest($FREENAS_API_RESOURCE_IST_TARGET,
				"GET", { "limit" => 0 });

    foreach my $t (@$tinfo) {
	# XXX shorten the names
	foreach my $key (keys %{$t}) {
	    if ($key =~ /^iscsi_target_(.*)/) {
		if (!exists($t->{$1})) {
		    $t->{$1} = $t->{$key};
		    delete $t->{$key};
		}
	    }
	}
	if ($byname) {
	    $thash->{$t->{'name'}} = $t;
	} else {
	    $thash->{$t->{'id'}} = $t;
	}
    }

    return $thash;
}

#
# Return list of target groups
#
sub freenasTargetGroupList($) {
    my ($byname) = @_;
    my $thash = {};
    my $tinfo = freenasRequest($FREENAS_API_RESOURCE_IST_TGTGROUP,
				"GET", { "limit" => 0 });

    foreach my $t (@$tinfo) {
	# XXX shorten the names
	foreach my $key (keys %{$t}) {
	    # XXX groups do nt have names, name them by target id
	    if ($key eq "iscsi_target") {
		$t->{'name'} = $t->{$key};
		delete $t->{$key};
	    }
	    elsif ($key =~ /^iscsi_target_(.*)/) {
		if (!exists($t->{$1})) {
		    $t->{$1} = $t->{$key};
		    delete $t->{$key};
		}
	    }
	}
	if ($byname) {
	    $thash->{$t->{'name'}} = $t;
	} else {
	    $thash->{$t->{'id'}} = $t;
	}
    }

    return $thash;
}

#
# Return list of associations.
# If getnames is non-zero, we resolve the extent/target indicies into names.
#
sub freenasAssocList() {
    my $ahash = {};
    my $ainfo = freenasRequest($FREENAS_API_RESOURCE_IST_ASSOC,
			       "GET", { "limit" => 0 });
    if (@$ainfo == 0) {
	return $ahash;
    }

    #
    # Map indicies to names for targets and extents.
    # Our use of these associations pretty much operate on names but
    # internally they are tracked by indicies. Note that these indicies
    # can change as targets and extents come and go, so we cannot cache
    # the mappings, we have to look them up everytime.
    #
    my $einfo = freenasExtentList(0);
    my $tinfo = freenasTargetList(0);
    my $tginfo = freenasTargetGroupList(1);

    foreach my $a (@$ainfo) {
	# XXX shorten the names
	foreach my $key (keys %{$a}) {
	    if ($key =~ /^iscsi_(.*)/) {
		if (!exists($a->{$1})) {
		    $a->{$1} = $a->{$key};
		    delete $a->{$key};
		}
	    }
	    if ($key eq "iscsi_extent") {
		if ($einfo && exists($einfo->{$a->{'extent'}})) {
		    $a->{'extent_name'} = $einfo->{$a->{'extent'}}->{'name'};
		}
	    }
	    if ($key eq "iscsi_target") {
		if ($tinfo && exists($tinfo->{$a->{'target'}})) {
		    $a->{'target_name'} = $tinfo->{$a->{'target'}}->{'name'};
		}
	    }
	}
	# XXX associate with the target group too
	if (exists($a->{'target'}) && exists($tginfo->{$a->{'target'}})) {
	    $a->{'target_group'} = $tginfo->{$a->{'target'}}->{'id'};
	}

	$ahash->{$a->{'id'}} = $a;
    }

    return $ahash;
}

#
# Yank information about Emulab blockstore slices out of FreeNAS.
# We start with the extent info and augment with Emulab-specific info.
#
sub freenasSliceList() {
    my $sliceshash = {};

    my $extinfo = freenasExtentList(0);

    # Go through each slice hash, culling out extra info.
    # Save hash in global list.  Throw out malformed stuff.
    foreach my $eref (keys %$extinfo) {
	my $slice = $extinfo->{$eref};

	my ($pid,$eid,$volname) = parseSliceName($slice->{'name'});
	my ($bsid, $vnode_id) = parseSlicePath($slice->{'path'});
	if (!defined($pid) || !defined($bsid)) {
	    warn("*** WARNING: blockstore_getSliceList: ".
		 "malformed slice entry, skipping.");
	    next;
	}
	$slice->{'pid'} = $pid;
	$slice->{'eid'} = $eid;
	$slice->{'volname'} = $volname;
	$slice->{'bsid'} = $bsid;
	$slice->{'vnode_id'} = $vnode_id;
	$sliceshash->{$vnode_id} = $slice;
    }

    # Do the messy work of getting slice size info into mebibytes.
    calcSliceSizes($sliceshash);

    return $sliceshash;
}

#######################################################################
# package-local functions
#

#
# Return information on all of the volume pools available on this host.
# Note: to get exact sizes, we execute our own zfs command, e.g:
#
#   zfs get -o name,property,value -Hp available,used rz-1
#
# where "rz-1" is the "root" of the pool. We need -p so that zfs doesn't
# return "human readable" sizes. Zfs rounds up those sizes to the appropriate
# number of significant digits. However, rounding up available space makes
# it seem like we have more space than we actually do! E.g., 39.35T to 39.4T
# will be off by 50GB.
#
sub listPools() {
    my $poolh = {};
    my $vinfo = freenasRequest($FREENAS_API_RESOURCE_VOLUME,
			       "GET",  {"limit" => 0});
    
    # Create hash with pool name as key.  Stuff in some sentinel values
    # in case we don't get a match from 'zpool list' below.
    foreach my $pool (@$vinfo) {
	$pool->{'size'} = 0;
	$pool->{'avail'} = 0;
	$pool->{'used'} = 0;
	my $vname = $pool->{'vol_name'};
	if ($vname) {
	    $poolh->{$vname} = $pool;
	} else {
	    warn("*** WARNING: listPools: pool has no vol_name!");
	}
    }

    open(ZFS, "$ZFS_CMD get -o name,property,value -Hp used,avail |") or
	die "Can't run 'zfs get'!";

    while (my $line = <ZFS>) {
	chomp $line;
	my ($pname, $prop, $val) = split(/\s+/, $line);
	next if $pname =~ /\//;  	   # filter out zvols.
	next if $pname =~ /^freenas-boot/; # and the system pool and snapshots.
	if (exists($poolh->{$pname})) {
	    my $pool = $poolh->{$pname};
	    if ($prop eq "available") {
		$pool->{'avail'} = convertZfsToMebi($val);
	    } elsif ($prop eq "used") {
		$pool->{'used'} = convertZfsToMebi($val);
	    }
	} else {
	    warn("*** WARNING: listPools: ".
		 "No FreeNAS entry for zpool: $pname");
	}
    }
    close(ZFS);

    # calculates sizes for each pool based on used, avail
    foreach my $pname (keys %$poolh) {
	my $pool = $poolh->{$pname};
	if (!exists($pool->{'used'}) ||
	    !exists($pool->{'avail'})) {
	    warn("*** WARNING: blockstore_getPoolInfo: ".
		 "incomplete size info for zpool: $pname");
	} else {
	    $pool->{'size'} = $pool->{'used'} + $pool->{'avail'};
	}
    }

    return $poolh;
}

#
# ZFS uses "KB", "MB", etc. when it really means "KiB", "MiB", etc.
#
sub convertZfsToMebi($) {
    my ($zsize) = @_;

    if ($zsize =~ /([\d\.]+[KMGT])B?$/) {
	$zsize = $1 . "iB";
    }
    return convertToMebi($zsize);
}

sub getZvolsFromVolinfo($)
{
    my ($vinfo) = @_;
    my @zvols = ();

    foreach my $vol (@$vinfo) {
	if (exists($vol->{'type'}) && $vol->{'type'} eq "zvol") {
	    # If path doesn't exist, then name is actually the path
	    if (!exists($vol->{'path'})) {
		if ($vol->{'name'} =~ /^[^\/]+\/(.*)/) {
		    $vol->{'path'} = $vol->{'name'};
		    $vol->{'name'} = $1;
		}
	    }
	    push(@zvols, $vol);
	    next;
	}

	# not a zvol, see if there are children and search those
	if (exists($vol->{'children'})) {
	    push(@zvols, getZvolsFromVolinfo($vol->{'children'}));
	}
    }

    return @zvols;
}

# helper function.
# Slice names look like: 'iqn.<date>.<tld>.<domain>:<pid>:<eid>:<volname>'
sub parseSliceName($) {
    my $name = shift;
    my @parts = split(/:/, $name);
    if (scalar(@parts) != 4) {
	warn("*** WARNING: blockstore_parseSliceName: Bad slice name: $name");
	return undef;
    }
    shift @parts;
    return @parts;
}

# helper function.
# Paths look like this: '/mnt/<blockstore_id>/<vnode_id>' for file-based
# extent (slice), and '/dev/zvol/<blockstore_id>/<vnode_id>' for zvol extents.
sub parseSlicePath($) {
    my $path = shift;

    if ($path =~ /^\/(mnt|dev\/zvol)\/([^\/]+)\/([^\/]+)/) {
	return ($2, $3);
    }

    return undef;
}

sub calcSliceSizes($) {
    my $sliceshash = shift;

    # Ugh... Have to look up size via the "volume" list for zvol slices.
    my $zvollist = freenasVolumeList(0, 0);

    foreach my $slice (values(%$sliceshash)) {
	my $vnode_id = $slice->{'vnode_id'};
	my $type = lc($slice->{'type'});

	if ($type eq "zvol") {
	    if (!exists($zvollist->{$vnode_id})) {
		warn("*** WARNING: blockstore_calcSliceList: ".
		     "Could not find matching volume entry ($vnode_id) for ".
		     "zvol slice: $slice->{'name'}");
		next;
	    }
	    # already converted to Mebi
	    $slice->{'size'} = $zvollist->{$vnode_id}->{'size'};
	} elsif ($type eq "file") {
	    my $size = $slice->{'filesize'};
	    $size =~ s/B$/iB/; # re-write with correct units.
	    $slice->{'size'} = convertToMebi($size);
	}
    }
}

# Required perl foo
1;
