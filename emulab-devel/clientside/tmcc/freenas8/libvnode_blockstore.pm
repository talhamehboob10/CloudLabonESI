#!/usr/bin/perl -wT
#
# Copyright (c) 2013 University of Utah and the Flux Group.
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
# Implements the libvnode API for blockstore pseudo-VMs on FreeNAS 8
#
# Note that there is no distinguished first or last call of this library
# in the current implementation.  Every vnode creation (through mkvnode.pl)
# will invoke all the root* and vnode* functions.  It is up to us to make
# sure that "one time" operations really are executed only once.
#
# Some notes about the current implementation in this module:
#
# * No module-specific persistent state
#
#  This module does not store anything persistently outside of what
#  FreeNAS itself stores.  In other words, it refreshes it's idea of
#  what pools exist, what slices are present, etc., on demand via the
#  CLI each time it requires this information.  Slower, but more simple
#  and accurate.
#
# * Minimal parallelization
#
#  Some read-only calls don't try to grab a global lock, but everything else
#  does.  Concurrent setup requests should be pretty rare anyway.  The idea
#  here is twofold: 1) avoid hammering on the FreeNAS interface and 2)
#  ensure data about existing resources is consistent/accurate.
#
package libvnode_blockstore;
use Exporter;
@ISA    = "Exporter";
@EXPORT = qw( init setDebug rootPreConfig
              rootPreConfigNetwork rootPostConfig
	      vnodeCreate vnodeDestroy vnodeState
	      vnodeBoot vnodePreBoot vnodeHalt vnodeReboot
	      vnodeUnmount
	      vnodePreConfig vnodePreConfigControlNetwork
              vnodePreConfigExpNetwork vnodeConfigResources
              vnodeConfigDevices vnodePostConfig vnodeExec vnodeTearDown
	    );

%ops = ( 'init' => \&init,
         'setDebug' => \&setDebug,
         'rootPreConfig' => \&rootPreConfig,
         'rootPreConfigNetwork' => \&rootPreConfigNetwork,
         'rootPostConfig' => \&rootPostConfig,
         'vnodeCreate' => \&vnodeCreate,
         'vnodeDestroy' => \&vnodeDestroy,
	 'vnodeTearDown' => \&vnodeTearDown,
         'vnodeState' => \&vnodeState,
         'vnodeBoot' => \&vnodeBoot,
         'vnodeHalt' => \&vnodeHalt,
         'vnodeUnmount' => \&vnodeUnmount,
         'vnodeReboot' => \&vnodeReboot,
         'vnodeExec' => \&vnodeExec,
         'vnodePreConfig' => \&vnodePreConfig,
         'vnodePreConfigControlNetwork' => \&vnodePreConfigControlNetwork,
         'vnodePreConfigExpNetwork' => \&vnodePreConfigExpNetwork,
         'vnodeConfigResources' => \&vnodeConfigResources,
         'vnodeConfigDevices' => \&vnodeConfigDevices,
         'vnodePostConfig' => \&vnodePostConfig,
       );


use strict;
use English;
use Data::Dumper;
use Socket;
use File::Basename;
use File::Path;
use File::Copy;

# Pull in libvnode and other Emulab stuff
BEGIN { require "/etc/emulab/paths.pm"; import emulabpaths; }
use libutil;
use libgenvnode;
use libvnode;
use libtestbed;
use libsetup;
use libfreenas;

#
# Constants
#
my $GLOBAL_CONF_LOCK     = "blkconf";
my $ZPOOL_LOW_WATERMARK  = 2 * 2**10; # 2GiB, expressed in MiB
my $FREENAS_MNT_PREFIX   = "/mnt";
my $ISCSI_GLOBAL_PORTAL  = 1;
my $SER_PREFIX           = "d0d0";
my $VLAN_IFACE_PREFIX    = "vlan";
my $MAX_RETRY_COUNT      = 5;
my $SLICE_BUSY_WAIT      = 10;
my $SLICE_GONE_WAIT      = 5;
my $IFCONFIG             = "/sbin/ifconfig";
my $ALIASMASK            = "255.255.255.255";

# storageconfig constants
# XXX: should go somewhere more general
my $BS_CLASS_SAN         = "SAN";
my $BS_PROTO_ISCSI       = "iSCSI";
my $BS_UUID_TYPE_IQN     = "iqn";

#
# Global variables
#
my %vnstates = ();
my $_gFirstOnLAN = 0;
my $debug  = 0;

#
# Local Functions
#
sub getSliceList();
sub parseSliceName($);
sub parseSlicePath($);
sub calcSliceSizes($);
sub getIfConfig($);
sub getVlan($);
sub getNextAuthITag();
sub genSerial();
sub findAuthITag($);
sub createVlanInterface($$);
sub removeVlanInterface($$);
sub setupIPAlias($;$);
sub runBlockstoreCmds($$$);
sub allocSlice($$$$);
sub exportSlice($$$$);
sub deallocSlice($$$$);
sub unexportSlice($$$$);

# Dispatch table for storage configuration commands.
my %setup_cmds = (
    "SLICE"  => \&allocSlice,
    "EXPORT" => \&exportSlice
);

my %teardown_cmds = (
    "SLICE"  => \&deallocSlice,
    "EXPORT" => \&unexportSlice
);

#
# Turn off line buffering on output
#
$| = 1;

sub setDebug($)
{
    $debug = shift;
    libvnode::setDebug($debug);
    print "libvnode_blockstore: debug=$debug\n"
	if ($debug);
}

#
# Called by mkvnode.pl shortly after the module is loaded.
#
sub init($) {
    # XXX: doesn't seem to be passed in presently...
    my ($pnode,) = @_;

    # Nothing to do globally (yet).
    return 0;
}

#
# Do once-per-hypervisor-boot activities.
#
# Note that this function is called for each VM, so use a marker to
# tell whether or not we've already been here, done that.  
#
# NB: Since FreeNAS uses memory filesystems for pretty much
# everything, we don't have to worry about removing the flag file on
# shutdown/reboot.
#
sub rootPreConfig() {
    #
    # Haven't been called yet, grab the lock and double check that someone
    # didn't do it while we were waiting.
    #
    if (! -e "/var/run/blockstore.ready") {
	my $locked = TBScriptLock($GLOBAL_CONF_LOCK,
				  TBSCRIPTLOCK_GLOBALWAIT(), 900);
	if ($locked != TBSCRIPTLOCK_OKAY()) {
	    return 0
		if ($locked == TBSCRIPTLOCK_IGNORE());
	    print STDERR "Could not get the blkinit lock after a long time!\n";
	    return -1;
	}
    }
    if (-e "/var/run/blockstore.ready") {
        TBScriptUnlock();
        return 0;
    }
    
    print "Configuring root vnode context\n";

    # XXX: Put in consistency checks (maybe - they may go elsewhere.)

    mysystem("touch /var/run/blockstore.ready");
    TBScriptUnlock();
    return 0;    
}

# Nothing to do ...
sub rootPreConfigNetwork($$$$)
{
    my ($vnode_id, undef, $vnconfig, $private) = @_;
    my @node_ifs = @{ $vnconfig->{'ifconfig'} };
    my @node_lds = @{ $vnconfig->{'ldconfig'} };

    if (TBScriptLock($GLOBAL_CONF_LOCK, 0, 900) != TBSCRIPTLOCK_OKAY()) {
	print STDERR "Could not get the blknet lock after a long time!\n";
	return -1;
    }

    # XXX: Nothing to do?

    TBScriptUnlock();
    return 0;
}

# Nothing to do.
sub rootPostConfig($)
{
    return 0;
}

#
# Report back the current status of the blockstore slice.
#
sub vnodeState($$$$)
{
    my ($vnode_id, $vmid, $vnconfig, $private) = @_;

    # Initialize our state if necessary.
    if (!exists($vnstates{$vnode_id})) {
	# This looks strange, but if we don't yet know what state the
	# blockstore is in and this file exists, then assume it exists
	# and is "stopped".  We do this to fake out the vnode "boot"
	# code in mkvnode.pl
	if (-e CONFDIR() . "/running") {
	    $vnstates{$vnode_id} = VNODE_STATUS_STOPPED();
	} else {
	    # We don't seem to exist...
	    $vnstates{$vnode_id} = VNODE_STATUS_UNKNOWN();
	}
    }

    # Once initialized, further state management happens elsewhere.

    return $vnstates{$vnode_id};
}

# All the creation heavy lifting is coordinated from here for blockstores.
sub vnodeCreate($$$$)
{
    my ($vnode_id, undef, $vnconfig, $private) = @_;
    my $vninfo = $private;
    my $bsconf = $vnconfig->{'storageconfig'};
    my $cleanup = 0;

    # Create vmid from the vnode's name.
    my $vmid;
    if ($vnode_id =~ /^\w+\d+\-(\d+)$/) {
	$vmid = $1;
    } else {
	fatal("blockstore_vnodeCreate: ".
	      "bad vnode_id $vnode_id!");
    }
    $vninfo->{'vmid'} = $vmid;
    $private->{'vndir'} = VNODE_PATH($vnode_id);

    # Grab the global lock to prevent concurrency.
    if (TBScriptLock($GLOBAL_CONF_LOCK, 0, 900) != TBSCRIPTLOCK_OKAY()) {
	fatal("blockstore_vnodeCreate: ".
	      "Could not get the blkalloc lock after a long time!");
    }

    # Create the experimental net (tagged vlan) interface
    if (createVlanInterface($vnode_id, $vnconfig) != 0) {
	$cleanup = 1;
	warn("*** ERROR: blockstore_vnodeCreate: ".
	     "Failed to create experimental network interface!");
    }

    # Create blockstore slice
    if (runBlockstoreCmds($vnode_id, $vnconfig, $private) != 0) {
	$cleanup = 1;
	warn("*** ERROR: blockstore_vnodeCreate: ".
	     "Blockstore slice creation failed!");
    }

    # Rain or shine, the creation attempt is done, so unlock.
    TBScriptUnlock();

    # Try to cleanup if something failed above.  Existing callers
    # appear to assume that if vnodeCreate() fails, then they don't
    # need to do anything to clean up ...
    if ($cleanup) {
	vnodeDestroy($vnode_id, $vmid, $vnconfig, $private);
	fatal("blockstore_vnodeCreate: ".
	      "Failed creation attempt aborted.");
    }

    return $vmid;
}

# Nothing to do presently.
sub vnodePreConfig($$$$$){
    my ($vnode_id, $vmid, $vnconfig, $private, $callback) = @_;

    return 0;
}

# Blockstore pseudo-VMs do not have a control network to setup.
sub vnodePreConfigControlNetwork($$$$$$$$$$$$)
{
    my ($vnode_id, $vmid, $vnconfig, $private,
	$ip,$mask,$mac,$gw, $vname,$longdomain,$shortdomain,$bossip) = @_;

    return 0;
}

# Setup IP alias for this blockstore pseudo-VM.
sub vnodePreConfigExpNetwork($$$$)
{
    my ($vnode_id, $vmid, $vnconfig, $private) = @_;

    return -1
	unless setupIPAlias($vnconfig) == 0;

    return 0;
}

# Nothing to do.
sub vnodeConfigResources($$$$){
    my ($vnode_id, $vmid, $vnconfig, $private) = @_;

    return 0;
}

# Nothing to do.
sub vnodeConfigDevices($$$$)
{
    my ($vnode_id, $vmid, $vnconfig, $private) = @_;

    return 0;
}

# The blockstore slice should be setup, the vlan interface created and
# plumbed, and the export in place by now.  Just signal "ISUP".
sub vnodeBoot($$$$)
{
    my ($vnode_id, $vmid, $vnconfig, $private) = @_;
    my $vninfo = $private;

    # notify Emulab that we are up.  Have to go through the proper
    # state transitions...
    libutil::setState("BOOTING");
    libutil::setState("ISUP");

    return 0;
}

# Just a wee smidge of state management here.  Mark that the
# blockstore pseudo-VM is up and running since 'vnodeBoot' is run
# inside a forked process, where such memory state changes are lost.
sub vnodePostConfig($)
{
    my ($vnode_id, $vmid, $vnconfig, $private) = @_;

    $vnstates{$vnode_id} = VNODE_STATUS_RUNNING();
    return 0;
}

# blockstores don't "reboot", but we'll signal that we've gone through
# the motions anyway.  Hopefully this rapid firing of events doesn't freak
# out stated.
sub vnodeReboot($$$$)
{
    my ($vnode_id, $vmid, $vnconfig, $private) = @_;

    libutil::setState("SHUTDOWN");
    libutil::setState("BOOTING");
    libutil::setState("ISUP");

    return 0;
}

# Nothing to see here folks.  Move along!
sub vnodeTearDown($$$$)
{
    my ($vnode_id, $vmid, $vnconfig, $private) = @_;

    return 0;
}

# Reverse the list of 'storageconfig' setup directives, then run the
# corresponding teardown commands.  Hold the lock while we do this
# to avoid concurrency here.
sub vnodeDestroy($$$$){
    my ($vnode_id, $vmid, $vnconfig, $private) = @_;
    my $sconfigs = $vnconfig->{'storageconfig'};

    my @revconfigs = sort {$b->{'IDX'} <=> $a->{'IDX'}} @$sconfigs;

    # Mark this node as no longer running/existing (for vnodeState())
    unlink(CONFDIR() . "/running");
    $vnstates{$vnode_id} = VNODE_STATUS_UNKNOWN();

    # Grab the global lock to prevent concurrency.
    if (TBScriptLock($GLOBAL_CONF_LOCK, 0, 900) != TBSCRIPTLOCK_OKAY()) {
	fatal("blockstore_vnodeDestroy: ".
	      "Could not get the blkalloc lock after a long time!");
    }

    # Run through blockstore removal commands (reversed creation list).
    my $failed = 0;
    foreach my $sconf (@revconfigs) {
	my $cmd = $sconf->{'CMD'};
	if (exists($teardown_cmds{$cmd})) {
	    if ($teardown_cmds{$cmd}->($vnode_id, $sconf, 
				       $vnconfig, $private) != 0) {
		warn("*** ERROR: blockstore_vnodeDestroy: ".
		     "Teardown command failed: $cmd");
		# Don't die yet.  We want to try removing the
		# interface first.  Do jump out of this loop however
		# since subsequent commands here may also fail (and
		# perhaps cause worse fallout).
		$failed = 1;
		last;
	    }
	} else {
	    # Escape hatch for unknown command.
	    TBScriptUnlock();
	    fatal("blockstore_vnodeDestroy: ".
		  "Don't know how to execute: $cmd");
	}
    }

    # Lastly, remove the vlan inteface.  That we only have one interface
    # and that it has the correct params was established at creation time.
    if (removeVlanInterface($vnode_id, $vnconfig) != 0) {
	TBScriptUnlock();
	fatal("blockstore_vnodeDestroy: ".
	      "Could not remove the vlan interface!");
    }

    TBScriptUnlock();
    die() if $failed;      # If the command loop above failed, die now.
    return 0;
}

# blockstores don't "halt", but we'll signal that we did anyway.  Also
# remove the IP alias.
sub vnodeHalt($$$$)
{
    my ($vnode_id, $vmid, $vnconfig, $private) = @_;

    setupIPAlias($vnconfig,1);

    libutil::setState("SHUTDOWN");
    $vnstates{$vnode_id} = VNODE_STATUS_STOPPED();

    return 0;
}

# Nothing to do...
sub vnodeExec($$$$$)
{
    my ($vnode_id, $vmid, $vnconfig, $private, $command) = @_;

    return 0;
}

# On the surface it would seem like this might apply to blockstore pseudo-VMs.
# Teardown and destroy do the work that this might do.
sub vnodeUnmount($$$$)
{
    my ($vnode_id, $vmid, $vnconfig, $private) = @_;

    return 0;
}

#######################################################################
# package-local functions
#

#
# Run through list of storage commands and execute them, checking
# for errors.  (Should have a lock before doing this.)
#
sub runBlockstoreCmds($$$) {
    my ($vnode_id, $vnconfig, $private) = @_;
    my $sconfigs = $vnconfig->{'storageconfig'};
    
    foreach my $sconf (@$sconfigs) {
	my $cmd = $sconf->{'CMD'};
	if (exists($setup_cmds{$cmd})) {
	    if ($setup_cmds{$cmd}->($vnode_id, $sconf, 
				    $vnconfig, $private) != 0) {
		warn("*** ERROR: blockstore_runBlockstoreCmds: ".
		     "Failed to execute setup command: $cmd");
		return -1;
	    }
	} else {
	    warn("*** ERROR: blockstore_runBlockstoreCmds: ".
		 "Don't know how to execute: $cmd");
	    return -1;
	}
    }

    return 0;
}

# Yank information about blockstore slices out of FreeNAS.
# Note: this is an expensive call - may want to re-visit caching some of
# this later if performance becomes a problem.
sub getSliceList() {
    my $sliceshash = {};

    # Grab list of slices (iscsi extents) from FreeNAS
    my @slist = freenasParseListing($FREENAS_CLI_VERB_IST_EXTENT);

    # Just return if there are no slices.
    return if !@slist;

    # Go through each slice hash, culling out extra info.
    # Save hash in global list.  Throw out malformed stuff.
    foreach my $slice (@slist) {
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
# extent (slice), and 'zvol/<blockstore_id>/<vnode_id>' for zvol extents.
sub parseSlicePath($) {
    my $path = shift;

    my @parts = split(/\//, $path);
    shift @parts
	if (scalar(@parts) == 4 && !$parts[0]); # chomp leading slash part
    if (scalar(@parts) != 3 ||  $parts[0] !~ /^(mnt|zvol)$/i) {
	warn("*** WARNING: blockstore_parseSlicePath: ".
	     "malformed slice path: $path");
	return undef;
    }
    shift @parts;
    return @parts;
}

sub calcSliceSizes($) {
    my $sliceshash = shift;

    # Ugh... Have to look up size via the "volume" list for zvol slices.
    my $zvollist = freenasVolumeList(0);

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
    return;
}

# Allocate a slice based on information from Emulab Central
# XXX: Do 'sliceconfig' parameter checking.
sub allocSlice($$$$) {
    my ($vnode_id, $sconf, $vnconfig, $priv) = @_;

    my $bsid = $sconf->{'BSID'};
    my $volname = $sconf->{'VOLNAME'};
    $volname = "UNKNOWN" if (!$volname);
    my $size = $sconf->{'VOLSIZE'};

    #
    # If this is a use of a persistent store, the BSID is a unique
    # volume name based on the lease ID. Look up the volume to make
    # sure it exists, but do nothing else.
    #
    if ($bsid =~ /^lease-\d+$/) {
	my $volumes = freenasVolumeList(0);
	if (exists($volumes->{$bsid})) {
	    $priv->{'pool'} = $volumes->{$bsid}->{'pool'};
	    $priv->{'volume'} = $volumes->{$bsid}->{'volume'};
	    return 0;
	}
	warn("*** ERROR: blockstore_allocSlice: $volname: ".
	     "Requested volume not found: $bsid!");
	return -1;
    }

    $priv->{'pool'} = $bsid;
    $priv->{'volume'} = $vnode_id;
    return freenasVolumeCreate($bsid, $vnode_id, $size);
}

# Setup device export.
sub exportSlice($$$$) {
    my ($vnode_id, $sconf, $vnconfig, $priv) = @_;

    # Should only be one ifconfig entry - checked earlier.
    my $ifcfg   = (@{$vnconfig->{'ifconfig'}})[0];
    my $nmask   = $ifcfg->{'IPMASK'};
    my $cmask   = libutil::CIDRmask($nmask);
    my $network = libutil::ipToNetwork($ifcfg->{'IPADDR'}, $nmask);
    if (!$cmask || !$network) {
	warn("*** ERROR: blockstore_exportSlice: ".
	     "Error calculating ip network information.");
	return -1;
    }
    
    my $volname = $sconf->{'VOLNAME'};
    $volname = "UNKNOWN" if (!$volname);

    # Extract volume/pool as stashed away in prior setup.
    my $pool = $priv->{'pool'};
    my $volume = $priv->{'volume'};

    if (!defined($pool) || !defined($volume)) {
	warn("*** ERROR: blockstore_exportSlice: $volname: ".
	     "volume/pool not found!");
	return -1;
    }

    # Scrub request - we only support SAN/iSCSI at this point.
    if (!exists($sconf->{'CLASS'}) || $sconf->{'CLASS'} ne $BS_CLASS_SAN) {
	warn("*** ERROR: blockstore_exportSlice: $volname: ".
	     "invalid or missing blockstore class!");
	return -1;
    }

    if (!exists($sconf->{'PROTO'}) || $sconf->{'PROTO'} ne $BS_PROTO_ISCSI) {
	warn("*** ERROR: blockstore_exportSlice: $volname: ".
	     "invalid or missing blockstore protocol!");
	return -1;
    }

    if (!exists($sconf->{'UUID'}) || 
	!exists($sconf->{'UUID_TYPE'}) ||
	$sconf->{'UUID_TYPE'} ne $BS_UUID_TYPE_IQN)
    {
	warn("*** ERROR: blockstore_exportSlice: $volname: ".
	     "bad UUID information!");
	return -1;
    }
    # Check (and untaint) the UUID.
    if ($sconf->{'UUID'} !~ /^([-\.:\w]+)$/) {
	warn("*** ERROR: blockstore_exportSlice: $volname: ".
	     "bad characters in UUID!");
	return -1;
    }
    # XXX we lowercase the IQN since the ist_assoc will blow up with caps!
    my $iqn = lc($1);

    # Create iSCSI extent
    eval { freenasRunCmd($FREENAS_CLI_VERB_IST_EXTENT, 
			 "add $iqn $pool/$volume") };
    if ($@) {
	warn("*** ERROR: blockstore_exportSlice: $volname: ".
	     "Failed to create iSCSI extent: $@");
	return -1;
    }

    # Create iSCSI auth group
    my $tag = getNextAuthITag();
    if ($tag !~ /^(\d+)$/) {
	warn("*** ERROR: blockstore_exportSlice: $volname: ".
	     "bad tag returned from getNextAuthITag: $tag");
	return -1;
    }
    $tag = $1; # untaint.
    eval { freenasRunCmd($FREENAS_CLI_VERB_IST_AUTHI,
			 "add $tag ALL $network/$cmask $vnode_id") };
    if ($@) {
	warn("*** ERROR: blockstore_exportSlice: $volname: ".
	     "Failed to create iSCSI auth group: $@");
	return -1;
    }

    my $perm = "rw";
    if (exists($sconf->{'PERMS'}) && $sconf->{'PERMS'} eq "RO") {
	$perm = "ro";
    }

    # Create iSCSI target
    my $serial = genSerial();
    eval { freenasRunCmd($FREENAS_CLI_VERB_IST_TARGET,
		      "add $iqn $serial $ISCSI_GLOBAL_PORTAL ".
			 "$tag Auto -1 flags=$perm") };
    if ($@) {
	warn("*** ERROR: blockstore_exportSlice: $volname: ".
	     "Failed to create iSCSI target: $@");
	return -1;
    }

    # Bind iSCSI target to slice (extent)
    eval { freenasRunCmd($FREENAS_CLI_VERB_IST_ASSOC,
			 "add $iqn $iqn") };
    if ($@) {
	warn("*** ERROR: blockstore_exportSlice: $volname: ".
	     "Failed to associate iSCSI target with extent: $@");
	return -1;
    }

    # All setup and exported!
    return 0;
}

# Helper function.
# Locate and return tag for given network, if it exists.
sub findAuthITag($) {
    my ($vnode_id,) = @_;

    return undef
	if !defined($vnode_id);

    my @authentries = freenasParseListing($FREENAS_CLI_VERB_IST_AUTHI);

    return undef
	if !@authentries;

    foreach my $authent (@authentries) {
	if ($authent->{'comment'} eq $vnode_id) {
	    return $authent->{'tag'};
	}
    }

    return undef;
}

# Helper function.
# Locate and return next unused tag ID for iSCSI initiator groups.
sub getNextAuthITag() {
    my @authentries = freenasParseListing($FREENAS_CLI_VERB_IST_AUTHI);

    my $freetag = 1;

    return $freetag
	if !@authentries;

    foreach my $curtag (sort {$a <=> $b} map {$_->{'tag'}} @authentries) {
	next if (!defined($curtag) || $curtag !~ /^\d+$/);
	if ($freetag < $curtag) {
	    last;
	}
	$freetag += 1;
    }

    return $freetag;
}

# Helper function - Generate a random serial number for an iSCSI target
sub genSerial() {
    my $rand_hex = join "", map { unpack "H*", chr(rand(256)) } 1..6;
    return $SER_PREFIX . $rand_hex;
}

# Helper function - get the _single_ ifconfig line passed in via tmcd.
# If there is more than one, then there is a problem.
sub getIfConfig($) {
    my ($vnconfig,) = @_;

    my $ifconfigs = $vnconfig->{'ifconfig'};
    
    if (@$ifconfigs != 1) {
	warn("*** ERROR: blockstore_getIfConfig: ".
	     "Wrong number of network interfaces.  There can be only one!");
	return undef;
    }

    my $ifc = @$ifconfigs[0];

    if ($ifc->{'ITYPE'} ne "vlan") {
	warn("*** ERROR: blockstore_getIfConfig: ".
	     "Interface must be of type 'vlan'!");
	return undef;
    }

    return $ifc;
}

# Helper function - search output of FreeNAS vlan CLI command for the
# presence of the vlan name passed in.  Return what is found.
sub getVlan($) {
    my ($vtag,) = @_;

    return undef
	if (!defined($vtag) || $vtag !~ /^(\d+)$/);

    my @vlans = freenasParseListing($FREENAS_CLI_VERB_VLAN);

    my $retval = undef;
    foreach my $vlan (@vlans) {
	if ($vtag == $vlan->{'tag'}) {
	    $retval = $vlan;
	    last;
	}
    }
    
    return $retval;
}

sub addressExists($) {
    my ($iface,) = @_;
    my $retval = 0;
    
    my $ifc_out = `$IFCONFIG $iface`;
    if ($? != 0) {
	warn("*** ERROR: blockstore_addressExists: ".
	     "Problem running ifconfig: $?");
	$retval = undef;
    } elsif ($ifc_out =~ /inet \d+\.\d+\.\d+\.\d+/) {
	$retval = 1;
    } 

    return $retval;
}

#
# Make a vlan interface for this node (tagged, vlan).
#
sub createVlanInterface($$) {
    my ($vnode_id, $vnconfig) = @_;

    my $ifc    = getIfConfig($vnconfig);
    if (!defined($ifc)) {
	warn("*** ERROR: blockstore_createVlanInterface: ".
	     "No valid interface record found!");
	return -1;
    }

    my $vtag   = $ifc->{'VTAG'};
    my $pmac   = $ifc->{'PMAC'};
    my $piface = $ifc->{'IFACE'};
    my $lname  = $ifc->{'LAN'};

    my $viface = $VLAN_IFACE_PREFIX . $vtag;

    # Untaint stuff.
    if ($piface !~ /^([-\w]+)$/) {
	warn("*** ERROR: blockstore_createVlanInterface: ". 
	     "bad data physical interface name!");
	return -1;
    }
    $piface = $1;

    if ($pmac !~ /^([a-fA-F0-9:]+)$/) {
	warn("*** ERROR: blockstore_createVlanInterface: ". 
	     "bad data in physical mac address!");
	return -1;
    }
    $pmac = $1;

    if ($vtag !~ /^(\d+)$/) {
	warn("*** ERROR: blockstore_createVlanInterface: ". 
	     "bad data in vlan tag!");
	return -1;
    }
    $vtag = $1;

    # see if vlan already exists.  do sanity checks to make sure this
    # is the correct vlan for this interface, and then create it.
    my $vlan = getVlan($vtag);
    if ($vlan) {
	my $vlabel = $vlan->{'description'};
	# This is not a fool-proof consistency check, but the odds of
	# having an existing vlan with the same LAN name and vlan tag
	# as one in a different experiment are vanishingly small.
	if ($vlabel ne $lname) {
	    warn("*** ERROR: blockstore_createVlanInterface: ".
		 "Mismatched vlan: $lname != $vlabel");
	    return -1;
	}
    }
    # vlan does not exist.
    else {
	# Create the vlan entry in FreeNAS.
	eval { freenasRunCmd($FREENAS_CLI_VERB_VLAN,
			     "add $piface $viface $vtag $lname") };
	if ($@) {
	    warn("*** ERROR: blockstore_createVlanInterface: ". 
		 "failure while creating vlan interface: $@");
	    return -1;
	}

	# Create the vlan interface.
	eval { freenasRunCmd($FREENAS_CLI_VERB_IFACE,
			     "add $viface $lname") };
	if ($@) {
	    warn("*** ERROR: blockstore_createVlanInterface: ".
		 "failure while setting vlan interface parameters: $@");
	    return -1;
	}
    }

    # All done.
    return 0;
}

# Create (or remove) the ephemeral IP alias for this blockstore.
sub setupIPAlias($;$) {
    my ($vnconfig, $teardown) = @_;

    my $ifc    = getIfConfig($vnconfig);
    if (!defined($ifc)) {
	warn("*** ERROR: blockstore_createVlanInterface: ".
	     "No valid interface record found!");
	return -1;
    }

    my $vtag   = $ifc->{'VTAG'};
    my $ip     = $ifc->{'IPADDR'};
    my $qmask  = $ifc->{'IPMASK'};

    my $viface = $VLAN_IFACE_PREFIX . $vtag;

    if ($ip !~ /^([\.\d]+)$/) {
	warn("*** ERROR: blockstore_createVlanInterface: ". 
	     "bad data in IP address!");
	return -1;
    }
    $ip = $1;

    if ($qmask !~ /^([\.\d]+)$/) {
	warn("*** ERROR: blockstore_createVlanInterface: ". 
	     "bad characters in subnet!");
	return -1;
    }
    # If this is the first blockstore on the lan, then use the real netmask,
    # otherwise this is yet another alias on the same interface, so use the
    # all 1's mask.
    $qmask = addressExists($viface) ? $ALIASMASK : $1;

    if ($teardown) {
	if (system("$IFCONFIG $viface -alias $ip") != 0) {
	    warn("*** ERROR: blockstore_createVlanInterface: ".
		 "ifconfig failed while setting IP alias parameters: $?");
	}
    } else {
	# Add an alias for this psuedo-VM.  Have to do this underneath FreeNAS
	# because it makes adding and removing them ridiculously impractical.
	if (system("$IFCONFIG $viface alias $ip netmask $qmask") != 0) {
	    warn("*** ERROR: blockstore_createVlanInterface: ".
		 "ifconfig failed while clearing IP alias parameters: $?");
	}
    }

    return 0;
}

#
# Remove previously created VLAN interface.  Will only actually do
# something if all IP aliases have been removed.  I.e., the last
# pseudo-VM in the vlan on this blockstore host that passes through
# here will result in interface removal.
#
sub removeVlanInterface($$) {
    my ($vnode_id, $vnconfig) = @_;

    # Fetch the interface record for this pseudo-VM
    my $ifc    = getIfConfig($vnconfig);
    if (!defined($ifc)) {
	warn("*** ERROR: blockstore_removeVlanInterface: ".
	     "No valid interface record found!");
	return -1;
    }

    my $vtag   = $ifc->{'VTAG'};
    my $viface = $VLAN_IFACE_PREFIX . $vtag;

    # Does FreeNAS have record of this vlan?  If not, it's probably safe
    # to assume the interface isn't there, so there is nothing to do here.
    if (!getVlan($vtag)) {
	warn("*** WARNING: blockstore_removeVlanInterface: ".
	     "Vlan entry does not exist...");
	return 0;
    }

    if (!addressExists($viface)) {
	# No more addresses: Delete the vlan interface.
	eval { freenasRunCmd($FREENAS_CLI_VERB_VLAN,
			     "del $viface") };
	if ($@) {
	    warn("*** ERROR: blockstore_removeVlanInterface: ".
		 "failure while removing vlan interface: $@");
	}
    }

    return 0;
}

sub unexportSlice($$$$) {
    my ($vnode_id, $sconf, $vnconfig, $priv) = @_;

    my $volname = $sconf->{'VOLNAME'};
    $volname = "UNKNOWN" if (!$volname);

    # All of the sanity checking was done when we first created and
    # exported this blockstore.  Assume nothing has changed...
    $sconf->{'UUID'} =~ /^([-\.:\w]+)$/;
    my $iqn = lc($1); # untaint and lowercase.

    # Remove iSCSI target to extent mapping.
    eval { freenasRunCmd($FREENAS_CLI_VERB_IST_ASSOC,
			 "del $iqn $iqn") };
    if ($@) {
	warn("*** WARNING: blockstore_unexportSlice: $volname: ".
	     "Failed to disassociate iSCSI target with extent: $@");
    }

    # Remove iSCSI target.
    eval { freenasRunCmd($FREENAS_CLI_VERB_IST_TARGET,
			 "del $iqn") };
    if ($@) {
	warn("*** WARNING: blockstore_unexportSlice: $volname: ".
	     "Failed to remove iSCSI target: $@");
    }

    # Remove iSCSI auth group
    my $tag = findAuthITag($vnode_id);
    if ($tag && $tag =~ /^(\d+)$/) {
	$tag = $1; # untaint.
	eval { freenasRunCmd($FREENAS_CLI_VERB_IST_AUTHI,
			     "del $tag") };
	if ($@) {
	    warn("*** WARNING: blockstore_unexportSlice: $volname: ".
		 "Failed to remove iSCSI auth group: $@");
	}
    }

    # Remove iSCSI extent.
    eval { freenasRunCmd($FREENAS_CLI_VERB_IST_EXTENT, 
			 "del $iqn") };
    if ($@) {
	warn("*** WARNING: blockstore_unexportSlice: $volname: ".
	     "Failed to remove iSCSI extent: $@");
    }

    # All torn down and unexported!
    return 0;
}

sub deallocSlice($$$$) {
    my ($vnode_id, $sconf, $vnconfig, $priv) = @_;

    my $bsid = $sconf->{'BSID'};
    my $volname = $sconf->{'VOLNAME'};
    $volname = "UNKNOWN" if (!$volname);

    #
    # If this is a use of a persistent store, the BSID is a unique
    # volume name based on the lease ID. Look up the volume to make
    # sure it exists, but do nothing else.
    #
    if ($bsid =~ /^lease-\d+$/) {
	my $volumes = freenasVolumeList(0);
	if (exists($volumes->{$bsid})) {
	    return 0;
	}
	warn("*** ERROR: blockstore_deallocSlice: $volname: ".
	     "Requested volume not found: $bsid!");
	return -1;
    }

    return freenasVolumeDestroy($bsid, $vnode_id);
}

# Required perl foo
1;
