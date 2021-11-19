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
# Support functions for the libvnode API and also for bscontrol which is
# a proxy for the blockstore server control program on boss.
#
# Uses the FreeNAS API directly.
#
# XXX things the API cannot do yet:
#
# - no known problems!
#
# API also does not report an error for:
#
# 1. attempting to remove a snapshot with a dependent clone
#
# So right now we use the API for all listing functions (get volumes,
# get extents, etc.) and for snapshots/clones and destroying "datasets".
#
# TODO:
#
# Even after optimization (caching API results), API calls still represent
# the majority of time used for creation of blockstore vnodes. A measurement
# of the setup of an experiment with 50 clone blockstores shows that
# 450 API calls (down from 600) are made accounting for 457 of the 466 total
# seconds of runtime (down from 511 of 528) required to set them all up.
#
# For vnode destruction, it is the same deal. After caching and eliminating
# a gratuitous API call, it is still 650 calls and 428 seconds (vs. 796 calls
# and 486 seconds before).
#
# Further optimizations:
#
# - In freenasAssocList, try only getting the info for the extent, target
#   and targetgroup needed rather than getting the info for all and picking
#   through it. I suspect this won't make much of a difference as it is the
#   API calls that are expensive, not the amount of data requested/returned.
#   This call takes a significant amount of the total time required for a
#   vnode teardown.
#
# - Is there some way to do a persistent connection? I am not sure whether
#   that is something the API would allow. Note that the latest FreeNAS
#   supports a websockets API.
#

package libfreenas;
use Exporter;
@ISA    = "Exporter";
@EXPORT =
    qw( 
        freenasSetDebug
	freenasPoolList freenasVolumeList freenasSliceList
	freenasAuthInitList freenasExtentList freenasTargetList
	freenasTargetGroupList freenasAssocList
	freenasVolumeCreate freenasVolumeDestroy freenasFSCreate
	freenasVolumeSnapshot freenasVolumeClone
	freenasVolumeDesnapshot freenasVolumeDeclone
        freenasVolumeCopy freenasVolumeCopyStatus
	freenasParseListing freenasRequest
        freenasLock freenasUnlock
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
use List::Util qw(first);

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

#
# Global variables
#
my $debug  = 0;
my $auth;
my $server;
my $islocked = 0;

my $VC_INVALID   = 0;
my $VC_BASEINFO	 = 1;
my $VC_SNAPINFO  = 2;
my $VC_INAMEINFO = 4;
my $volcachevalid = $VC_INVALID;
my $volcache;

sub freenasPoolList();
sub freenasVolumeList($;$);
sub freenasVolumeCreate($$$;$$);
sub freenasVolumeDestroy($$;$);
sub freenasFSCreate($$$;$);
sub freenasParseListing($);

sub freenasVolumeSnapshot($$;$$);
sub freenasVolumeDesnapshot($$;$$$);
sub freenasVolumeClone($$$;$$);
sub freenasVolumeDeclone($$;$);
sub freenasVolumeCopy($$$;$);
sub freenasVolumeCopyStatus($$);

#
# Local Functions
#
sub listPools();
sub convertZfsToMebi($);
sub volumeDestroy($$$$$);
sub snapshotHasClone($$);
sub getZvolsFromVolinfo($);
sub parseSliceName($);
sub parseSlicePath($);
sub calcSliceSizes($);

#
# Turn off line buffering on output
#
$| = 1;

sub freenasSetDebug($)
{
    $debug = shift;
    print "libfreenas: debug=$debug\n"
	if ($debug);
}

#
# Make sure we don't race with libvnode_blockstore operations.
#
sub freenasLock(;$)
{
    my ($timo) = @_;
    $timo = 900
	if (!defined($timo));	# XXX same as libvnode_blockstore

    TBDebugTimeStampWithDate("freenasLock: getting lock")
	if ($debug > 1);

    my $locked = TBScriptLock($GLOBAL_CONF_LOCK, 0, $timo);
    if ($locked != TBSCRIPTLOCK_OKAY()) {
	TBDebugTimeStampWithDate("freenasLock: could not get lock after $timo seconds!")
	    if ($debug > 1);
	return -1;
    }

    TBDebugTimeStampWithDate("freenasLock: got lock")
	if ($debug > 1);

    $islocked = 1;
    return 0;
}

sub freenasUnlock()
{
    TBDebugTimeStampWithDate("freenasUnlock: releasing lock")
	if ($debug > 1);
    $islocked = 0;
    $volcachevalid = $VC_INVALID;
    TBScriptUnlock();
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

    # XXX conservative: anything but a GET invalidates any cache we have
    if ($method ne "GET") {
	$volcachevalid = $VC_INVALID;
    }

    my $http = HTTP::Tiny->new("timeout" => 30);

    my $url = "http://$server/api/v1.0/$resource/$paramstr";
    my %headers = (
	"Content-Type"  => "application/json",
	"Authorization" => "Basic " . MIME::Base64::encode_base64($auth, "")
    );
    my %options = ("headers" => \%headers, "content" => $datastr); 

    TBDebugTimeStampWithDate("freenasRequest: $resource ($method): calling")
	if ($debug > 1);
    print STDERR "freenasRequest: URL: $url\nCONTENT: $datastr\n"
	if ($debug > 2);

    my $res = $http->request($method, $url, \%options);

    TBDebugTimeStampWithDate("freenasRequest: call returned")
	if ($debug > 1);
    print STDERR "freenasRequest: RESPONSE: ", Dumper($res), "\n"
	if ($debug > 2);

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

#
# Get a full listing of extant volume information.
#
# Note that we don't bother to lock here, the caller will have to
# lockout if it wants a consistent picture of affairs.
#
sub freenasVolumeList($;$)
{
    my ($inameinfo,$snapinfo) = @_;
    my $vollist = {};

    $inameinfo = 0 if (!defined($inameinfo));
    $snapinfo  = 0 if (!defined($snapinfo));

    #
    # See if we can use our simple cache to avoid API calls.
    #
    if ($islocked && $volcachevalid &&
	(!$inameinfo || ($volcachevalid & $VC_INAMEINFO) != 0) &&
	(!$snapinfo || ($volcachevalid & $VC_SNAPINFO) != 0)) {
	print STDERR "freenasVolumeList: returning cached info\n"
	    if ($debug > 1);
	return $volcache;
    }
    $volcachevalid = $VC_INVALID;
    $volcache = undef;

    # Assorted hack maps
    my %inames = ();	# volume-name -> slice-name
    my %snaps = ();	# volume-name -> (snapshot1 snapshot2 ...)
    my %clones = ();	# clone-volume-name -> snapshot
    my %zvolsizes = ();	# volume-name -> (volsize, used, refer)

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

	#
	# Have to use "zfs get" to get clone info.
	#
	# XXX freakin' awesome. We cannot just use "zfs get" to get the
	# comma-seperated "clones" list for each snapshot because get
	# will only return 1024 chars worth of property value. That is only
	# around 50 clones given our naming scheme. While we won't usually
	# have that many active clones of a dataset, it will blow things up
	# if we do! So we do a recursive get of the "origin" property
	# for all volumes. For a filesystem advertised to handle bazillions
	# of gonzo-uber-byte files, this is a pretty tightwad limit...
	#
	if (open(ZFS, "$ZFS_CMD get -o name,value -Hpr -t volume origin |")) {
	    while (my $line = <ZFS>) {
		chomp $line;
		my ($vname, $val) = split(/\s+/, $line);
		next
		    if ($val eq "-");
		if ($val =~ /\/([^\/]+)$/) {
		    my $sname = $1;
		    if (first { $_ eq $val } @snames) {
			$clones{$vname} = $sname;
		    }
		}
	    }
	    close(ZFS);
	} else {
	    warn("*** WARNING: could not run 'zfs get' for clone info");
	}
    }

    #
    # XXX The new-ish /storage/volumes/<pool>/zvols API would get us all
    # the remaining info we need, including sizes. But...we would have to
    # call it individually for every pool, and we don't know what all the
    # storage pools are without still more work.
    #

    #
    # For now we get size info (volsize,used,referenced) via the ZFS tool.
    # The zvols API would do it, but if we were to start using that, we
    # should use it to get all the volume info (see the note above)
    # rather than making two API calls (which are expensive).
    #
    # Random note: if volsize is 0, then the volume is being copied.
    #
    if (open(ZFS, "$ZFS_CMD get -t volume -o name,property,value -Hp volsize,used,referenced |")) {
	while (my $line = <ZFS>) {
	    chomp $line;
	    my ($name, $prop, $val) = split(/\s+/, $line);
	    $zvolsizes{$name} = () if (!exists($zvolsizes{$name}));
	    $zvolsizes{$name}->{$prop} = $val;
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

	    # fill in the size info
	    $vol->{'size'} = $vol->{'used'} = $vol->{'refer'} = 0;
	    if (exists($zvolsizes{$volname})) {
		if (exists($zvolsizes{$volname}->{'volsize'})) {
		    $vol->{'size'} =
			int(convertToMebi($zvolsizes{$volname}->{'volsize'}));
		}
		if (exists($zvolsizes{$volname}->{'used'})) {
		    $vol->{'used'} =
			int(convertToMebi($zvolsizes{$volname}->{'used'}));
		}
		if (exists($zvolsizes{$volname}->{'referenced'})) {
		    $vol->{'refer'} =
			int(convertToMebi($zvolsizes{$volname}->{'referenced'}));
		}
	    } else {
		warn("*** WARNING: could not get sizes of $volname");
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

    #
    # Cache the API info if possible
    #
    if ($islocked) {
	$volcache = $vollist;
	$volcachevalid = $VC_BASEINFO;
	$volcachevalid |= $VC_INAMEINFO if ($inameinfo);
	$volcachevalid |= $VC_SNAPINFO if ($snapinfo);
    }
    
    return $vollist;
}

sub freenasPoolList() {
    return listPools();
}

#
# Create a ZFS zvol.
#
sub freenasVolumeCreate($$$;$$)
{
    my ($pool, $volname, $size, $sparse, $dolock) = @_;

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
    $dolock = 1
	if (!defined($dolock));

    freenasLock()
	if ($dolock);

    # Does the requested pool exist?
    my $pools = listPools();
    my $destpool;
    if (exists($pools->{$pool})) {
	$destpool = $pools->{$pool};
    } else {
	warn("*** ERROR: freenasVolumeCreate: ".
	     "Requested pool not found: $pool!");
	freenasUnlock()
	    if ($dolock);
	return -1;
    }

    # Is there enough space in the requested pool?
    # If not, there is a discrepancy between reality and the Emulab database.
    if ($size + $ZPOOL_LOW_WATERMARK > $destpool->{'avail'}) {
	warn("*** ERROR: freenasVolumeCreate: ". 
	     "Not enough space remaining in requested pool: $pool");
	freenasUnlock()
	    if ($dolock);
	return -1;
    }

    # XXX the traditional default for FreeNAS seems to be true
    my $sparsearg = JSON::PP::true;
    if (defined($sparse) && $sparse == 0) {
	$sparsearg = JSON::PP::false;
    }

    #
    # XXX don't explicitly turn compression on/off, use the default from
    # the pool. I.e., I removed the:
    #			      "compression" => "off",
    # attribute in the call below.
    #
    my $msg;
    my $res = freenasRequest("$FREENAS_API_RESOURCE_VOLUME/${pool}/zvols",
			     "POST", undef,
			     {"name" => "$volname",
			      "volsize" => "${size}M",
			      "sparse" => $sparsearg },
			     202, \$msg);
    if (!$res) {
	if ($msg) {
	    warn("*** ERROR: freenasVolumeCreate: ".
		 "volume '$pool/$volname' creation failed:\n$msg");
	} else {
	    warn("*** ERROR: freenasVolumeCreate: volume creation failed");
	}
	freenasUnlock()
	    if ($dolock);
	return -1;
    }

    freenasUnlock()
	if ($dolock);
    return 0;
}

sub freenasVolumeSnapshot($$;$$)
{
    my ($pool, $volname, $tstamp, $dolock) = @_;

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
    $dolock = 1
	if (!defined($dolock));

    freenasLock()
	if ($dolock);

    # Get volume and snapshot info
    my $vollist = freenasVolumeList(0, 1);

    # The base volume must exist
    my $vref = $vollist->{$volname};
    if (!$vref || $vref->{'pool'} ne $pool) {
	warn("*** ERROR: freenasVolumeSnapshot: ".
	     "Base volume '$volname' does not exist in pool '$pool'");
	freenasUnlock()
	    if ($dolock);
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
		freenasUnlock()
		    if ($dolock);
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
	freenasUnlock()
	    if ($dolock);
	return -1;
    }

    freenasUnlock()
	if ($dolock);
    return 0;
}

sub freenasVolumeDesnapshot($$;$$$)
{
    my ($pool, $volname, $tstamp, $force, $dolock) = @_;

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
    $dolock = 1
	if (!defined($dolock));

    freenasLock()
	if ($dolock);

    # Get volume and snapshot info
    my $vollist = freenasVolumeList(0, ($force ? 2 : 1));

    # The base volume must exist
    my $vref = $vollist->{$volname};
    if (!$vref || $vref->{'pool'} ne $pool) {
	warn("*** ERROR: freenasVolumeDesnapshot: ".
	     "Base volume '$volname' does not exist in pool '$pool'");
	freenasUnlock()
	    if ($dolock);
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

    freenasUnlock()
	if ($dolock);
    return $rv;
}

#
# Create a clone volume named $nvolname from volume $ovolname.
# The clone will be created from the snapshot $volname-$tag where
# $tag is interpreted as a timestamp. If $tag == 0, use the most recent
# (i.e., largest timestamp) snapshot.
#
sub freenasVolumeClone($$$;$$)
{
    my ($pool, $ovolname, $nvolname, $tag, $dolock) = @_;

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
    $dolock = 1
	if (!defined($dolock));

    freenasLock()
	if ($dolock);

    # Get volume and snapshot info
    my $vollist = freenasVolumeList(0, 1);

    # The base volume must exist, the clone must not
    my $ovref = $vollist->{$ovolname};
    if (!$ovref || $ovref->{'pool'} ne $pool) {
	warn("*** ERROR: freenasVolumeClone: ".
	     "Base volume '$ovolname' does not exist in pool '$pool'");
	freenasUnlock()
	    if ($dolock);
	return -1;
    }
    if (exists($vollist->{$nvolname})) {
	warn("*** ERROR: freenasVolumeClone: ".
	     "Volume '$nvolname' already exists");
	freenasUnlock()
	    if ($dolock);
	return -1;
    }

    # Base must have at least one snapshot
    if (!exists($ovref->{'snapshots'})) {
	warn("*** ERROR: freenasVolumeClone: ".
	     "Base volume '$ovolname' has no snapshots");
	freenasUnlock()
	    if ($dolock);
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
	    freenasUnlock()
		if ($dolock);
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
	freenasUnlock()
	    if ($dolock);
	return -1;
    }

    freenasUnlock()
	if ($dolock);
    return 0;
}

#
# Create a deep copy of a ZFS volume:
# - Snapshot the source volume
# - Start a resumeable zsend/zrecv pipeline
# - Do the copy
# - Remove the snapshot (in both old and new volumes)
#
# zfs snapshot persist-1/lease-546@copy
# zfs send -R persist-1/lease-546@copy | zfs recv -Fs persist-1/lease-546-new
# zfs destroy persist-1/lease-546@copy
# zfs destroy persist-1/lease-546-new@copy
#
# If the send or recv are interrupted, the target volume will have a
# receive_resume_token attribute that can be used to continue the copy:
#
# zfs send -t <token> | zfs recv -s persist-1/lease-546-new
#
sub freenasVolumeCopy($$$;$)
{
    my ($pool, $ovolname, $nvolname, $dolock) = @_;

    # Untaint arguments that are passed to a command execution
    $pool = untaintHostname($pool);
    $ovolname = untaintHostname($ovolname);
    $nvolname = untaintHostname($nvolname);
    if (!$pool || !$ovolname || !$nvolname) {
	warn("*** ERROR: freenasVolumeCopy: ".
	     "Invalid arguments");
	return -1;
    }
    $dolock = 1
	if (!defined($dolock));

    freenasLock()
	if ($dolock);

    # Get volume and snapshot info
    my $vollist = freenasVolumeList(0, 2);

    # The source volume must exist
    my $vref = $vollist->{$ovolname};
    if (!$vref || $vref->{'pool'} ne $pool) {
	warn("*** ERROR: freenasVolumeSnapshot: ".
	     "Source volume '$ovolname' does not exist in pool '$pool'");
	freenasUnlock()
	    if ($dolock);
	return -1;
    }

    # The destination volume must NOT exist
    my $nvref = $vollist->{$nvolname};
    if ($nvref && $nvref->{'pool'} eq $pool) {
	warn("*** ERROR: freenasVolumeCopy: ".
	     "Destination volume '$nvolname' already exists in pool '$pool'");
	freenasUnlock()
	    if ($dolock);
	return -1;
    }

    # The snapshot must not exist
    my $sname = "C" . time();
    my $snapshot = "$ovolname\@$sname";
    if (exists($vref->{'snapshots'})) {
	my @snaps = split(',', $vref->{'snapshots'});

	foreach my $sname (@snaps) {
	    if ($snapshot eq $sname) {
		warn("*** ERROR: freenasVolumeCopy: ".
		     "Source snapshot '$snapshot' already exists");
		freenasUnlock()
		    if ($dolock);
		return -1;
	    }
	}
    }

    # Create the snapshot
    my $res = freenasRequest($FREENAS_API_RESOURCE_SNAPSHOT, "POST", undef,
			     {"dataset" => "$pool/$ovolname",
			      "name" => "$sname"});
    if (!$res) {
	warn("*** ERROR: freenasVolumeSnapshot: could not create snapshot");
	freenasUnlock()
	    if ($dolock);
	return -1;
    }

    freenasUnlock()
	if ($dolock);

    #
    # Do the send/recv pipeline.
    #
    # This could take a really, really long time so we leave things unlocked
    # while we do it.
    #
    # We leave an "in progress" file in the volatile /var/run directory so
    # we can tell if a supposedly active copy might have been terminated
    # by a server reboot or crash of the bscontrol.proxy instance. The
    # existance of the file detects the former, we write our pid into the
    # file to detect the latter.
    #
    TBDebugTimeStampWithDate("freenasVolumeCopy: starting send/recv")
	if ($debug);
    my $pfile = "/var/run/$pool-$nvolname.copying";
    if (open(FD, ">$pfile")) {
	print FD "$PID\n";
	close(FD);
    }
    if (system("$ZFS_CMD send -R $pool/$snapshot | $ZFS_CMD recv -Fs $pool/$nvolname")) {
	TBDebugTimeStampWithDate("freenasVolumeCopy: send/recv FAILED")
	    if ($debug);
	my $msg = "";
	my $token =
	    `$ZFS_CMD get -Ho value receive_resume_token $pool/$nvolname`;
	chomp($token);
	if ($token ne "-") {
	    $msg = ", may be able to finish with:\n".
		"  $ZFS_CMD send -t $token | $ZFS_CMD recv -s $pool/$nvolname";
	}
	warn("*** ERROR: ".
	     "'$ZFS_CMD send -R $pool/$snapshot | $ZFS_CMD recv -Fs $pool/$nvolname' failed$msg\n");
	unlink($pfile);
	return -1;
    }
    unlink($pfile);
    TBDebugTimeStampWithDate("freenasVolumeCopy: finished send/recv")
	if ($debug);

    freenasLock()
	if ($dolock);

    # Remove the snapshot in both the original and copy datasets
    my $msg;
    my $resource = "$FREENAS_API_RESOURCE_SNAPSHOT/${pool}\%2F${snapshot}";
    $res = freenasRequest($resource, "DELETE", undef, undef, undef, \$msg);
    if (!$res) {
	warn("*** WARNING: freenasVolumeCopy: ".
	     "delete of $snapshot failed:\n$msg");
    }
    $snapshot = "$nvolname\@$sname";
    $resource = "$FREENAS_API_RESOURCE_SNAPSHOT/${pool}\%2F${snapshot}";
    $res = freenasRequest($resource, "DELETE", undef, undef, undef, \$msg);
    if (!$res) {
	warn("*** WARNING: freenasVolumeCopy: ".
	     "delete of $snapshot failed:\n$msg");
    }

    freenasUnlock()
	if ($dolock);

    return 0;
}

#
# Determine if a volume copy is still running.
# Returns zero if not, non-zero if so.
#
# Note that we should only be called if the volume exists and has the
# receive_resume_token.
#
sub copyRunning($$)
{
    my ($pool, $volname) = @_;
    my $pfile = "/var/run/$pool-$volname.copying";

    # if the pidfile does not exist, we must have rebooted
    if (! -e $pfile) {
	return 0;
    }

    # if we cannot open the file, be conservative and assume still running
    if (!open(FD, "<$pfile")) {
	warn("*** WARNING: $pool/$volname copy file exists but unreadable");
	return 1;
    }

    my $dapid = <FD>;
    close(FD);
    chomp($dapid);

    # ditto if the contents is malformed
    if ($dapid !~ /^(\d+)$/) {
	warn("*** WARNING: $pool/$volname copy file does not contain a pid");
	return 1;
    }

    $dapid = $1;
    return kill(0, $dapid);
}

#
# From the blockstore server perspecive, a copy is in progress (or did
# not complete) if the "receive_resume_token" property is set on zfs dataset.
# It is still in progress if send/recv processes exist. We should write some
# state to disk (a "pid file") to make this detection easier.
#
# The "referenced" attribute tells how much data has been copied, ala:
#    zfs get -Hp referenced persist-1/lease-200
#
# Returns:
#  * status=INVALID
#    Volume cannot be found
#  * status=INPROGRESS, size=<size-in-MiB>
#    resume_token exists and send/recv pipeline is running
#  * status=ABORTED, size=<size-in-MiB>
#    resume_token exists and send/recv pipeline is not running
#  * status=DONE, size=<size-in-MiB>
#    None of the above are true (note that the volume might not
#    even have been involved in a copy)
#
sub freenasVolumeCopyStatus($$)
{
    my ($pool, $volname) = @_;
    my $status = "UNKNOWN";
    my $size = -1;

    # Untaint arguments that are passed to a command execution
    $pool = untaintHostname($pool);
    $volname = untaintHostname($volname);
    if (!$pool || !$volname) {
	warn("*** ERROR: freenasVolumeCopyStatus: Invalid arguments");
	return undef;
    }

    if (open(ZFS, "$ZFS_CMD get -o property,value -Hp referenced,receive_resume_token $pool/$volname 2>&1 |")) {
	while (my $line = <ZFS>) {
	    chomp $line;
	    if ($line =~ /dataset does not exist/) {
		$status = "INVALID";
		next;
	    }
	    my ($name, $val) = split(/\s+/, $line);
	    if ($name eq "referenced") {
		$size = int(convertToMebi($val));
	    } elsif ($name eq "receive_resume_token") {
		if ($val eq "-") {
		    $status = "DONE";
		} elsif (copyRunning($pool, $volname)) {
		    $status = "INPROGRESS";
		} else {
		    $status = "ABORTED";
		}
	    } else {
		# just ignore unknown lines
		next;
	    }
	}
	close(ZFS);
    } else {
	warn("*** WARNING: could not run 'zfs get' for zvol status info");
    }
    return ($status, $size);
}

sub freenasVolumeDeclone($$;$)
{
    my ($pool, $volname, $dolock) = @_;

    # Untaint arguments since they are passed to a command execution
    $pool = untaintHostname($pool);
    $volname = untaintHostname($volname);
    if (!$pool || !$volname) {
	warn("*** ERROR: freenasVolumeDeclone: ".
	     "Invalid arguments");
	return -1;
    }
    $dolock = 1
	if (!defined($dolock));

    return volumeDestroy($pool, $volname, 1, "freenasVolumeDeclone", $dolock);
}

sub freenasVolumeDestroy($$;$)
{
    my ($pool, $volname, $dolock) = @_;

    # Untaint arguments since they are passed to a command execution
    $pool = untaintHostname($pool);
    $volname = untaintHostname($volname);
    if (!$pool || !$volname) {
	warn("*** ERROR: freenasVolumeDestroy: ".
	     "Invalid arguments");
	return -1;
    }
    $dolock = 1
	if (!defined($dolock));

    return volumeDestroy($pool, $volname, 0, "freenasVolumeDestroy", $dolock);
}

#
# The guts of destroy and declone
#
sub volumeDestroy($$$$$) {
    my ($pool, $volname, $declone, $tag, $dolock) = @_;
    my $tries = 0;

  retry:
    if (++$tries > $MAX_RETRY_COUNT) {
	warn("*** WARNING: $tag: ".
	     "Could not free volume after $MAX_RETRY_COUNT attempts!");
	return -1;
    }
    
    freenasLock()
      if ($dolock);

    # Get volume and snapshot info
    my $vollist = freenasVolumeList(0, 1);

    #
    # volume must exist
    # XXX let's not consider this an error if it disappears after we
    # have tried once. It probably means that someone else removed it.
    # Maybe we should not consider this an error even on the first try?
    #
    my $vref = $vollist->{$volname};
    if (!$vref || $vref->{'pool'} ne $pool) {
	if ($tries > 1) {
	    warn("*** ERROR: $tag: ".
		 "Volume '$volname' does not exist in pool '$pool'");
	    freenasUnlock()
		if ($dolock);
	    return -1;
	}
	warn("*** WARNING: $tag: ".
	     "Volume '$volname' in pool '$pool' disappeared while we slept");
	freenasUnlock()
	    if ($dolock);
	return 0;
    }

    #
    # Volume must not have snapshots.
    # Note that in the case of a clone volume, we are talking about snapshots
    # of the clone itself, not the snapshot that the clone is based on.
    # I.e., this is not inconsistant with the "If decloning" section below.
    #
    if (exists($vref->{'snapshots'})) {
	warn("*** ERROR: $tag: ".
	     "Volume '$volname' has clones and/or snapshots, cannot destroy");
	freenasUnlock()
	    if ($dolock);
	return -1;
    }
 
    #
    # Deallocate volume.
    # If it fails, we retry on some errors up to MAX_RETRY times.
    # Note that we release the lock between retries, so we must restart
    # from scratch each time as the volume status might have changed while
    # we slept.
    #
    my $resource = "$FREENAS_API_RESOURCE_VOLUME/$pool/datasets/$volname";
    my $msg;

    my $res = freenasRequest($resource, "DELETE", undef, undef, undef, \$msg);
    if (!$res) { 
	if ($msg =~ /dataset is busy/) {
	    warn("*** WARNING: $tag: Volume is busy. ".
		 "Waiting $VOLUME_BUSY_WAIT seconds before trying again ".
		 "(tries=$tries).");
	    freenasUnlock()
		if ($dolock);
	    sleep $VOLUME_BUSY_WAIT;
	    goto retry;
	}
	if ($msg =~ /does not exist/) {
	    if ($tries < $MAX_RETRY_COUNT) {
		warn("*** WARNING: $tag: Volume seems to be gone, retrying.");
		freenasUnlock()
		    if ($dolock);
		# Bump counter to just under termination to try once more.
		$tries = $MAX_RETRY_COUNT-1;
		sleep $VOLUME_GONE_WAIT;
		goto retry;
	    }
	    warn("*** WARNING: $tag: Volume still seems to be gone.");
	    freenasUnlock()
		if ($dolock);

	    # Bail now because we don't want to report this as an
	    # error to the caller.
	    return 0;
	} 
	$msg =~ s/\\n/\n  /g;
	warn("*** ERROR: $tag: Volume removal failed:\n$msg");
	freenasUnlock()
	    if ($dolock);
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
		freenasUnlock()
		    if ($dolock);
		return -1;
	    }
	} else {
	    warn("*** WARNING: $tag: ".
		 "Destroying clone but not origin snapshot '$snapshot'");
	}
    }

    freenasUnlock()
	if ($dolock);
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

sub freenasFSCreate($$$;$) {
    my ($pool,$vol,$fstype,$dolock) = @_;
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
    freenasLock()
	if ($dolock);
    if (system("$cmd /dev/zvol/$pool/$vol $redir") != 0) {
	warn("*** WARNING: freenasFSCreate: '$cmd /dev/zvol/$pool/$vol' failed");
	freenasUnlock()
	    if ($dolock);
	return -1;
    }

    freenasUnlock()
	if ($dolock);
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
