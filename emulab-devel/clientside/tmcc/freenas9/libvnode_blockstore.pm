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
my $ISTGT                = "/usr/local/bin/istgt";
my $ISTGT_CONFIG_FILE    = "/usr/local/etc/istgt/istgt.conf";
my $ISTGT_PID_FILE       = "/var/run/istgt.pid";
my $ISTGT_MAXWAIT        = 30; # 30 seconds

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
sub restartIstgt();
sub getIfConfig($);
sub getVlan($);
sub getNextAuthITag();
sub genSerial();
sub findAuthITag($;$);
sub findAuthIId($);
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
    if ($vnode_id =~ /^[-\w]+\-(\d+)$/) {
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

    # Create the experimental net (tagged vlan) interface, if not present.
    return -1
	if (createVlanInterface($vnode_id, $vnconfig) != 0);


    # Push this vnode's IP address onto the vlan interface.
    return -1
	if (setupIPAlias($vnconfig) != 0);

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

sub getSliceList() {
    return freenasSliceList();
}

# Helper function - restart the ISTGT process to reconfigure iSCSI stuff.
sub restartIstgt() {
    if (! -e $ISTGT_PID_FILE) {
	warn("*** WARNING: blockstore_restartIstgt: ".
	     "ISTGT PID file missing! Is it not running?");
	return -1;
    }
    if (!open(ISTPID, "<$ISTGT_PID_FILE")) {
	warn("*** WARNING: blockstore_restartIstgt: ".
	     "Could not open ISTGT PID file for reading!");
	return -1;
    }
    my $pid = <ISTPID>;
    close(ISTPID);
    chomp $pid;
    if (!$pid || $pid !~ /^(\d+)$/) {
	warn("*** WARNING: blockstore_restartIstgt: ".
	     "ISTGT PID does not look like a number!");
	return -1;
    }
    $pid = $1; # untaint

    # Kill the istgt process.
    if (kill("TERM", $pid) != 1) {
	warn("*** WARNING: blockstore_restartIstgt: ".
	     "Could not send KILL signal to ISTGT: $!");
	return -1;
    }

    # Wait for the istgt process to die.
    my $dead = 0;
    for (my $i = 0; $i < $ISTGT_MAXWAIT; $i++) {
	sleep(1);
	if (!kill(0, $pid)) {
	    $dead = 1;
	    last;
	}
    }

    if (!$dead) {
	warn("*** WARNING: blockstore_restartIstgt: ".
	     "ISTGT still alive after $ISTGT_MAXWAIT seconds!");
	return -1;
    }

    # Restart istgt.
    if (system("$ISTGT -c $ISTGT_CONFIG_FILE") != 0) {
	warn("*** WARNING: blockstore_restartIstgt: ".
	     "Could not start ISTGT!");
	return -1;
    }

    return 0;
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
    # By default, we will create "best effort" ephemeral volumes.
    #
    my $sparse = 1;

    #
    # If this is a use of a persistent store, the BSID is a unique
    # volume name based on the lease ID. Look up the volume to make
    # sure it exists, but do nothing else other than stash away some
    # state for exportSlice.
    #
    if ($bsid =~ /^lease-\d+$/) {
	# XXX we no longer share mappings so don't need iname info
	#my $volumes = freenasVolumeList(1, 1);
	my $volumes = freenasVolumeList(0, 1);
	my $vref = $volumes->{$bsid};
	if (!defined($vref)) {
	    warn("*** ERROR: blockstore_allocSlice: $volname: ".
		 "Requested volume not found: $bsid!");
	    return -1;
	}

	#
	# For possible later cloning, find the highest numbered snapshot
	# Note that the 'snapshots' list returned by freenasVolumeList is
	# already sorted from newest to oldest, so we just grab the first one.
	#
	if (exists($vref->{'snapshots'})) {
	    my $snap = (split(',', $vref->{'snapshots'}))[0];
	    if ($snap =~ /@(\d+)$/) {
		$priv->{'lastsnapshot'} = $1;
	    }
	}

	$priv->{'pool'} = $vref->{'pool'};
	$priv->{'volume'} = $vref->{'volume'};
	# XXX we no longer share mappings
	#if (exists($vref->{'iname'})) {
	#    $priv->{'iname'} = $vref->{'iname'};
	#}
	return 0;
    }

    $priv->{'pool'} = $bsid;
    $priv->{'volume'} = $vnode_id;
    return freenasVolumeCreate($bsid, $vnode_id, $size, $sparse);
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

    my $isro = "false";
    my $isclone = "false";
    if (exists($sconf->{'PERMS'})) {
	if ($sconf->{'PERMS'} eq "RO") {
	    $isclone = "true";
	    $isro = "true";
	}
	elsif ($sconf->{'PERMS'} eq "CLONE") {
	    $isclone = "true";
	}
    }

    #
    # If the mapping to a persistent store is RO or CLONE, then we will
    # create a read-only (RO) or read-write (CLONE) ephemeral clone for
    # each such mapping.
    #
    if ($volume =~ /^lease-\d+$/ && $isclone eq "true") {
	#
	# If no snapshot exists, create one. VolumeClone must have
	# a snapshot to hang the clone on. If a snapshot already exists
	# we assume another mapping has already gone through here and
	# we just use the same snapshot.
	#
	# XXX could this race with another vnode setup? If so, we could
	# wind up creating multiple snapshots for the same volume.
	# That does not matter right now, but something to watch out for.
	#
	if (!exists($priv->{'lastsnapshot'})) {
	    # XXX this will be an error
	    warn("*** WARNING: blockstore_exportSlice: $volname: ".
		 "no snapshot found; created one for now");
	    my $tstamp = time();
	    if (freenasVolumeSnapshot($pool, $volume, $tstamp)) {
		warn("*** ERROR: blockstore_exportSlice: $volname: ".
		     "Could not create snapshot for RO/Clone mapping");
		return -1;
	    }
	    $priv->{'lastsnapshot'} = $tstamp;
	}

	#
	# Create a clone with the same name as an ephemeral blockstore
	# would have. Note that it is in a different pool however,
	# since snapshot/clone must be in the same pool as the origin.
	# Clone will use the most recent snapshot (though there should
	# only be one anyway).
	#
	if (freenasVolumeClone($pool, $volume, $vnode_id)) {
	    warn("*** ERROR: blockstore_exportSlice: $volname: ".
		 "Could not create clone for RO/Clone mapping");
	    return -1;
	}
	$volume = $vnode_id;
    }

    # If operating on a lease, we use the lease id as the iSCSI
    # initiator group identifier instead of the vnode_id because this
    # entry may end up being shared (simultaneous RO use).
    my $tag_ident = $vnode_id;
    # XXX we no longer share mappings
    #if ($priv->{'volume'} =~ /^lease-\d+$/) {
    #    $tag_ident = $priv->{'volume'};
    #}

    #
    # Go through the whole iSCSI extent/target setup if it hasn't been
    # done yet for this volume.  (If this is a persistent lease, it
    # may already be exported and in use.)
    #
    # XXX note that the API doc indicates that you would just specify
    # type 'ZVOL' but that doesn't work. You have to set:
    #      iscsi_target_extent_type=='Disk' and
    #      iscsi_target_extent_disk=='zvol/...'
    #
    # XXX currently iname will never exist since we don't share mappings.
    # The "else" code is left just in case we need it again in the future.
    #
    if (!exists($priv->{'iname'})) {
	#
	# Create iSCSI extent.
	#
	my $res = freenasRequest($FREENAS_API_RESOURCE_IST_EXTENT,
				 "POST", undef,
				 {"iscsi_target_extent_name" => $iqn,
				  "iscsi_target_extent_serial" => genSerial(),
				  "iscsi_target_extent_type" => "Disk",
				  "iscsi_target_extent_disk" => "zvol/$pool/$volume",
				  "iscsi_target_extent_ro" => $isro});
	if (!$res) {
	    warn("*** ERROR: blockstore_exportSlice: $volname: ".
		 "Failed to create iSCSI extent: $@");
	    return -1;
	}

	# save the index for making a target association
	my $eindex = $res->{'id'};

	# Create iSCSI auth group
	my $tag = getNextAuthITag();
	if ($tag !~ /^(\d+)$/) {
	    warn("*** ERROR: blockstore_exportSlice: $volname: ".
		 "bad tag returned from getNextAuthITag: $tag");
	    return -1;
	}
	$tag = $1; # untaint.

	#
	# Create an authorized initiator.
        #
	# XXX sigh...once again the FreeNAS API does not work, it just
	# returns status 302 with reason "FOUND" which is normally a
	# redirect to a new location (but it returns the same location
	# in this case).
	#
	eval { freenasRunCmd($FREENAS_CLI_VERB_IST_AUTHI,
			     "add $tag ALL $network/$cmask $tag_ident") };
	if ($@) {
	    warn("*** ERROR: blockstore_exportSlice: $volname: ".
		 "Failed to create iSCSI auth group: $@");
	    return -1;
	}

	#
	# Create iSCSI target.
	#
	# XXX ugh, this used to all be done with iscsi/target, but now
	# they have broken it into two pieces: create the target, create
	# a target group.
	#
	$res = freenasRequest($FREENAS_API_RESOURCE_IST_TARGET,
			      "POST", undef,
			      {"iscsi_target_name" => $iqn});
	if (!$res) {
	    warn("*** ERROR: blockstore_exportSlice: $volname: ".
		 "Failed to create iSCSI target: $@");
	    return -1;
	}
	if (!exists($res->{'id'})) {
	    warn("*** ERROR: blockstore_exportSlice: $volname: ".
		 "No index for iSCSI target we just created!?");
	    return -1;
	}
	my $tindex = $res->{'id'};

	# XXX we need the authinit index, not tag
	my $aindex = findAuthIId($tag);

	$res = freenasRequest($FREENAS_API_RESOURCE_IST_TGTGROUP,
			      "POST", undef,
			      {"iscsi_target" => $tindex,
			       "iscsi_target_initiatorgroup" => $aindex,
			       "iscsi_target_portalgroup" => $ISCSI_GLOBAL_PORTAL,
			       "iscsi_target_authgroup" => undef,
			       "iscsi_target_authtype" => "None"});
	if (!$res) {
	    warn("*** ERROR: blockstore_exportSlice: $volname: ".
		 "Failed to create iSCSI targetgroup: $@");
	    return -1;
	}

	# Bind iSCSI target to slice (extent)
	$res = freenasRequest($FREENAS_API_RESOURCE_IST_ASSOC,
			      "POST", undef,
			      {"iscsi_target" => $tindex,
			       "iscsi_extent" => $eindex});
	if (!$res) {
	    warn("*** ERROR: blockstore_exportSlice: $volname: ".
		 "Failed to associate iSCSI target with extent: $@");
	    return -1;
	}
    }
    # The iSCSI target/extent setup is already in place, so just
    # modify the authorized networks.  Check that the incoming
    # requested perms are RO, and validate that the dataset isn't
    # currently in use RW.
    else {
	# XXX for now
	warn("*** ERROR: unexpected arrival in shared dataset code!");
	return -1;

	# Check requested perms.
	if ($isclone eq "false") {
	    warn("*** ERROR: blockstore_exportSlice: $volname: ".
		 "Cannot re-export in-use dataset as RW!");
	    return -1;
	}

	# Check current use mode - must not be RW.  Searching for the
	# target entry serves as a sanity check as well.
	my $targets = freenasTargetList(1);
	if (!exists($targets->{$iqn})) {
	    warn("*** ERROR: blockstore_exportSlice: $volname: ".
		 "Couldn't find the iSCSI target while attempting re-export!");
	    return -1;
	}

	# Grab the current iSCSI initiator group so we can modify it.
	my $authent = findAuthITag($tag_ident);
	if (!$authent) {
	    warn("*** ERROR: blockstore_exportSlice: $volname: ".
		 "Couldn't find the iSCSI auth group entry while attempting re-export!");
	    return -1;
	}
	if ($authent->{'tag'} !~ /^(\d+)$/) {
	    warn("*** ERROR: blockstore_exportSlice: $volname: ".
		 "Malformed tag returned for current authentication group entry while attempting re-export!");
	    return -1;
	}
	my $curtag = $1; # untaint;
	my @auth_networks = split(/\s+/, $authent->{'auth_network'});
	# The incoming network shouldn't already be there, but let's check.
	if (grep(/^$network\/$cmask$/, @auth_networks)) {
	    warn("*** WARNING: blockstore_exportSlice: $volname: ".
		 "Our network is already present in iSCSI auth group: $network/$cmask");
	} else {
	    push @auth_networks, "$network/$cmask";
	    my $auth_network_str = join(' ', @auth_networks);
	    eval { freenasRunCmd($FREENAS_CLI_VERB_IST_AUTHI, 
				 "edit $curtag ALL ".
				 "'$auth_network_str' $tag_ident") };
	    if ($@) {
		warn("*** ERROR: blockstore_exportSlice: $volname: ".
		     "Failed to modify iSCSI auth group (re-export): $@");
		return -1;
	    }
	}

	# Restart ISTGT to pull in change.  We have to do this because
	# the IST_AUTHI command above doesn't do it for us...
	if (restartIstgt() != 0) {
		warn("*** ERROR: blockstore_exportSlice: $volname: ".
		     "restartIstgt failed!  ISTGT may not be running!");
		return -1;
	}
    }

    # All setup and exported!
    return 0;
}

# Helper function.
# Locate and return tag for given identifier, if it exists.
sub findAuthITag($;$) {
    my ($ident,$idxp) = @_;

    return undef
	if !defined($ident);

    my $aiinfo = freenasAuthInitList();

    foreach my $ai (keys %{$aiinfo}) {
	my $aient = $aiinfo->{$ai};
	if (exists($aient->{'comment'}) && $aient->{'comment'} eq $ident &&
	    exists($aient->{'tag'})) {
	    if ($idxp) {
		$$idxp = $aient->{'id'};
	    }
	    return $aient;
	}
    }

    return undef;
}

# Helper function.
# Locate and return ID for given auth tag, if it exists
sub findAuthIId($) {
    my ($tag) = @_;

    return undef
	if !defined($tag);

    my $aiinfo = freenasAuthInitList();

    foreach my $ai (keys %{$aiinfo}) {
	my $aient = $aiinfo->{$ai};
	if (exists($aient->{'tag'}) && $aient->{'tag'} eq $tag) {
	    return $aient->{'id'};
	}
    }

    return undef;
}

# Helper function.
# Locate and return next unused tag ID for iSCSI initiator groups.
sub getNextAuthITag() {
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
    my $retval = {};
    my $notexist = 0;

    return undef
	if (!defined($vtag) || $vtag !~ /^(\d+)$/);

    my $vlanif = $VLAN_IFACE_PREFIX . $vtag;    
    if (!open(IFPIPE,"$IFCONFIG $vlanif 2>&1 |")) {
	warn("*** ERROR: blockstore_getVlan: ".
	     "Could not run ifconfig: $!");
	return undef;
    }

    while (my $ln = <IFPIPE>) {
	chomp $ln;
        IFLINE: for ($ln) {
	    /description: (.+)/ && do {
		$retval->{'description'} = $1;
		last IFLINE;
	    };
	    /vlan: (\d+) parent interface: (\w+)/ && do {
		$retval->{'tag'}  = $1;
		$retval->{'pint'} = $2;
		last IFLINE;
	    };
	    /does not exist/ && do {
		$notexist = 1;
		last IFLINE;
	    };
	}
    }

    close(IFPIPE);

    if ($? != 0) {
	if (!$notexist) {
	    warn("*** ERROR: blockstore_getVlan: ".
		 "ifconfig returned an error: $?");
	}
	return undef;
    }

    return $retval;
}

#
# Does _any_ IPv4 address exist on a given network interface?
#
sub addressExists($) {
    my ($iface,) = @_;
    my $retval = 0;
    
    my $ifc_out = `$IFCONFIG $iface 2>&1`;
    if ($? != 0) {
	warn("*** ERROR: blockstore_addressExists: ".
	     "Problem running ifconfig: $ifc_out");
	$retval = 0;
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
	# Create the vlan entry directly.  FreeNAS 9 nukes network
	# interface addresses/aliases it doesn't know about, so we can't
	# use its API directly. :-(  See also the comment
	# in setupIPAliases().
	if (system("$IFCONFIG $viface create vlan $vtag".
		   " vlandev $piface description $lname") != 0) {
	    warn("*** ERROR: blockstore_createVlanInterface: ". 
		 "failure while creating vlan interface: $!");
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
	# Add an alias for this pseudo-VM.  Have to do this underneath FreeNAS
	# because it makes adding and removing them ridiculously impractical.
	# To be more specific, it does various bad things, like remove ALL
	# configuration across ALL interfaces when an address/alias is
	# removed from an interface.  It then re-configs everything from
	# it's DB. This is very disruptive to say the least!
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

    # Does the vlan interface exist?  Nothing to do if it doesn't!
    if (!getVlan($vtag)) {
	warn("*** WARNING: blockstore_removeVlanInterface: ".
	     "Vlan entry for $vtag does not exist...");
	return 0;
    }

    if (!addressExists($viface)) {
	if (system("$IFCONFIG $viface destroy") != 0) {
	    warn("*** ERROR: blockstore_removeVlanInterface: ".
		 "failure while removing $viface interface: $?");
	}
    }

    return 0;
}

#
# Reverse counterpart to exportSlice().
#
sub unexportSlice($$$$) {
    my ($vnode_id, $sconf, $vnconfig, $priv) = @_;

    my $volname = $sconf->{'VOLNAME'};
    $volname = "UNKNOWN" if (!$volname);

    # All of the sanity checking was done when we first created and
    # exported this blockstore.  Assume nothing has changed...
    $sconf->{'UUID'} =~ /^([-\.:\w]+)$/;
    my $iqn = lc($1); # untaint and lowercase.

    # There should only be one ifconfig entry - checked earlier.
    my $ifcfg   = (@{$vnconfig->{'ifconfig'}})[0];
    my $nmask   = $ifcfg->{'IPMASK'};
    my $cmask   = libutil::CIDRmask($nmask);
    my $network = libutil::ipToNetwork($ifcfg->{'IPADDR'}, $nmask);
    if (!$cmask || !$network) {
	warn("*** ERROR: blockstore_unexportSlice: ".
	     "Error calculating ip network information.");
	return -1;
    }

    # If operating on a lease, we use the lease name as the
    # iSCSI auth group identifier instead of the vnode_id because
    # this entry may be shared (simultaneous RO use).
    my $tag_ident = $vnode_id;
    # XXX we no longer share mappings
    #if ($sconf->{'UUID'} =~ /:(lease-\d+)$/) {
    #    $tag_ident = $1; # untaint
    #}

    # Fetch the authorized initators entry associated with this slice,
    # and yank its network entry out of the list.  It this is the last
    # remaining entry, we tear down the export. If any network entries
    # remain, this tells us that other experiments are still using
    # this iSCSI target (simultaneous RO). In that case we only
    # modify the set of authorized initiators.
    my $authtag = 0;
    my @pruned_networks = ();
    my $authidx;
    my $curtag = findAuthITag($tag_ident,\$authidx);
    if ($curtag && $curtag->{'tag'} =~ /^(\d+)$/) {
	$authtag = $1; # untaint;
	@pruned_networks = grep {!/^$network\/$cmask$/} split(/\s+/, $curtag->{'auth_network'});
    }

    # If there are no networks left in the authorized initiators list, then
    # we are completely done with this export - tear it down!
    if (!@pruned_networks) {
	my ($associd,$targetid,$extentid,$tgroupid,$msg);
	my $assocs = freenasAssocList();
	foreach my $aid (keys %$assocs) {
	    if (exists($assocs->{$aid}->{'target_name'}) &&
		$assocs->{$aid}->{'target_name'} eq $iqn &&
		exists($assocs->{$aid}->{'extent_name'}) &&
		$assocs->{$aid}->{'extent_name'} eq $iqn) {
		$associd = $aid;
		$targetid = $assocs->{$aid}->{'target'};
		$extentid = $assocs->{$aid}->{'extent'};
		$tgroupid = $assocs->{$aid}->{'target_group'};
		last;
	    }
	}

	# Remove association
	$msg = "assoc for $iqn not found\n";
	if (!$associd ||
	    !freenasRequest("$FREENAS_API_RESOURCE_IST_ASSOC/$associd",
			    "DELETE", undef, undef, undef, \$msg)) {
	    warn("*** WARNING: blockstore_unexportSlice: $volname: ".
		 "Failed to disassociate iSCSI target with extent:\n$msg");
	}

	# Remove target group.
	if (!$tgroupid ||
	    !freenasRequest("$FREENAS_API_RESOURCE_IST_TGTGROUP/$tgroupid",
			    "DELETE", undef, undef, undef, \$msg)) {
	    warn("*** WARNING: blockstore_unexportSlice: $volname: ".
		 "Failed to remove iSCSI target group:\n$msg");
	}

	# Remove iSCSI target.
	if (!$targetid ||
	    !freenasRequest("$FREENAS_API_RESOURCE_IST_TARGET/$targetid",
			    "DELETE", undef, undef, undef, \$msg)) {
	    warn("*** WARNING: blockstore_unexportSlice: $volname: ".
		 "Failed to remove iSCSI target:\n$msg");
	}

	# Remove iSCSI auth group
	if (!$authidx ||
	    !freenasRequest("$FREENAS_API_RESOURCE_IST_AUTHI/$authidx",
			    "DELETE", undef, undef, undef, \$msg)) {
	    warn("*** WARNING: blockstore_unexportSlice: $volname: ".
		 "Failed to remove iSCSI auth group:\n$msg");
	}

	# Remove iSCSI extent.
	if (!$extentid ||
	    !freenasRequest("$FREENAS_API_RESOURCE_IST_EXTENT/$extentid",
			    "DELETE", undef, undef, undef, \$msg)) {
	    warn("*** WARNING: blockstore_unexportSlice: $volname: ".
		 "Failed to remove iSCSI extent:\n$msg");
	}
    }
    # This export is still referenced, so leave export but update the
    # authorized initiators list.
    else {
	# XXX for now
	warn("*** ERROR: unexpected arrival in shared dataset code!");
	return -1;

	my $auth_network_str = join(' ', @pruned_networks);
	eval { freenasRunCmd($FREENAS_CLI_VERB_IST_AUTHI,
			     "edit $authtag ALL '$auth_network_str' ".
			     "$tag_ident") };
	if ($@) {
	    warn("*** ERROR: blockstore_unexportSlice: $volname: ".
		 "Failed to modify iSCSI auth group (re-export): $@");
	    return -1;
	}

	# Restart ISTGT to pull in change.  We have to do this because
	# the IST_AUTHI command above doesn't do it for us...
	if (restartIstgt() != 0) {
		warn("*** ERROR: blockstore_unexportSlice: $volname: ".
		     "restartIstgt failed!  ISTGT may not be running!");
		return -1;
	}
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
	my $volumes = freenasVolumeList(0, 1);

	#
	# Check for clone volumes. A clone will have our (vnode_id)
	# name and be a "cloneof" a snapshot of this lease.
	#
	if (exists($volumes->{$vnode_id})) {
	    my $vref = $volumes->{$vnode_id};
	    my $pool = $vref->{'pool'};
	    my $cloneof = $vref->{'cloneof'};
	    if (defined($cloneof) && $cloneof =~ /^$bsid\@\d+/ &&
		exists($volumes->{$bsid})) {
		my $snaps = $volumes->{$bsid}->{'snapshots'};

		#
		# If we are a clone of the most recent snapshot, just Destroy
		# which leaves the snapshot; otherwise Declone and attempt to
		# remove the old snapshot.
		#
		# Note that we do not use the cached 'lastsnapshot' in our
		# private data since that was saved back when we were created
		# which could be a long time ago (and hence very stale).
		#
		if (defined($snaps) && $cloneof eq (split(',', $snaps))[0]) {
		    return freenasVolumeDestroy($pool, $vnode_id);
		}
		return freenasVolumeDeclone($pool, $vnode_id);
	    }
	    warn("*** WARNING: blockstore_deallocSlice: $volname: ".
		 "Found stale clone volume '$pool/$vnode_id'");
	}

	if (exists($volumes->{$bsid})) {
	    return 0;
	}
	warn("*** ERROR: blockstore_deallocSlice: $volname: ".
	     "Requested volume not found: $bsid!");
	return -1;
    }

    #
    # Ephemeral volume. We use Declone here rather than Destroy since someday
    # we will have clones of ephemeral volumes. In that case we will not have
    # to worry about keeping the latest snapshot as there will only be one
    # and it should go away on last use.
    #
    return freenasVolumeDeclone($bsid, $vnode_id);
}

# Required perl foo
1;
