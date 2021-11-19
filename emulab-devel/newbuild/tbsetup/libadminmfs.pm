#!/usr/bin/perl -wT
#
# Copyright (c) 2005-2021 University of Utah and the Flux Group.
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
# Admin MFS library.  Routines related to getting into and out of the
# admin MFS and executing programs within it.
#
# Note that none of these routines are graceful about errors.  If some/all
# nodes fail, their bootinfo states may be modified and not all the same;
# i.e., some nodes may be set to boot into the MFS (or may even have booted
# into the MFS) and others not.  These routines are used primarily at swap
# out time where all inconsistent state will get fixed up anyway, or by
# node_admin where the caller is assumed to be saavy.
#
package libadminmfs;

use strict;
use Exporter;
use vars qw(@ISA @EXPORT);

@ISA    = "Exporter";
@EXPORT = qw ( TBAdminMfsBoot TBAdminMfsSelect TBAdminMfsRunCmd
    	       TBAdminMfsCreate TBAdminMfsDestroy);

# Must come after package declaration!
use libdb;
use libtestbed;
use StateWait;
use OSImage;
use Node;

#
# Function prototypes
#
sub TBAdminMfsBoot($$@);
sub TBAdminMfsSelect($$@);
sub TBAdminMfsRunCmd($$@);
sub TBAdminMfsCreate($$@);
sub TBAdminMfsDestroy($$@);

# Configure variables
my $TB		= "/home/achauhan06/CLOUDLAB/SSHCLOUD/CloudLabonESI/emulab-devel/newbuild";
my $TESTMODE    = 0;
my $TBOPS       = "testbed-ops\@ops.cloudlab.umass.edu";
my $ELABINELAB  = 0;
my $NFSMFS	= "";

my $nodereboot	= "$TB/bin/node_reboot";
my $power	= "$TB/bin/power";
my $osselect    = "$TB/bin/os_select";
my $nfsmfssetup = "$TB/sbin/nfsmfs_setup";
my $dhcpd_makeconf = "$TB/sbin/dhcpd_makeconf";

#
# The number of nodes we will power on at a time and the time to wait
# between batches.  These values are NOT the same as in libreboot.pm.
# I had to reduce the batch count to prevent problems.
#
my $BATCHCOUNT  = 8;
my $BATCHSLEEP	= 5;

#
# Timeout for a node to reboot into (or out of) the admin MFS
# XXX we could calculate this from node_type and os_info reboot times
#
my $reboottimo  = (6 * 60);
my $commandtimo = (2 * 60);
my $sleepwait   = 10;

#
# TBAdminMfsBoot(\%args, \@failed, @nodes)
#
# Boot up (reboot or power on) a set of nodes (@nodes) and optionally wait
# for them to enter or exit the admin MFS.  It is assumed that the node
# has been setup to boot into or out of the admin MFS as appropriate
# (TBAdminMfsSelect). If not, you could be waiting a long time!
# Arguments passed in the $args hash:
#
#	'name'	 string identifying the caller for error messages
#	'on'	 1 to enter MFS, 0 to exit
#	'reboot' 1 to reboot into MFS, -1 to "power on", 0 to do nothing
#	'prepare' 1 to run prepare on the way down
#	'wait'	 1 to wait for all nodes to reach MFS before returning,
#		 0 to return after reboot/power-on
#	'retry'  1 if we should retry once on nodes that do not make it
#		 into the MFS.
#
# Returns zero if all nodes successfully complete the reboot (wait==0)
# or reach the MFS (wait==1), and non-zero otherwise.  If the $failed ref
# is defined, it is an arrayref in which we return the list of nodes that
# failed.
#
# Note: NO PERMISSION CHECKING IS DONE.  It is assumed that the caller
# has performed all the necessary checks.
#
sub TBAdminMfsBoot($$@)
{
    my ($args, $failedref, @nodes) = @_;

    my $me = $args->{'name'};
    my $on = $args->{'on'};
    my $reboot = $args->{'reboot'};
    my $wait = $args->{'wait'};
    my $prepare = $args->{'prepare'};
    my $retry = $args->{'retry'};
    my $timo = 0;

    $retry = 0
        if (!defined($retry) || !$wait);

    #
    # Reboot or power on nodes...
    #
   if ($wait) {
	$StateWait::debug = 0;
	
	#
	# Initialize the statewait library.
	#
	my @states   = ();

	#
	# Only wait for MFSSETUP when going into the MFS. When coming out
	# of MFS, just wait for generic ISUP.
	# 
	push(@states, TBDB_NODESTATE_MFSSETUP())
	    if ($on);
	push(@states, TBDB_NODESTATE_ISUP());
    
	if (initStateWait(\@states, @nodes)) {
	    print STDERR "*** $me:\n".
		"    Failed to initialize the statewait library!\n";
	    @$failedref = @nodes
		if (defined($failedref));
	    return 1;
	}

	#
	# Calculate the maximum timeout that is needed based on nodes'
	# bios_waittimes.
	#
	$timo = $reboottimo;
	foreach my $n (@nodes) {
	    my $nobj = Node->Lookup($n);
	    if ($nobj && defined($nobj->bios_waittime()) &&
		$nobj->bios_waittime() > $timo) {
		$timo = $nobj->bios_waittime();
	    }
	}
    }

    if ($reboot) {
	#
	# Since the admin MFS is large, we do are own limiting of the number
	# of nodes rebooted in parallel.  This value is considerably lower than
	# that enforced in libreboot.pm.  Also note that we would need to
	# perform batching for the "power on" case anyway, as the power command
	# does not do any batching.
	#
	my @nodelist = @nodes;
	while (@nodelist) {
	    my $batch = "";
	    my $i = 0;
	    while ($i < $BATCHCOUNT && @nodelist > 0) {
		my $node = shift(@nodelist);
		$batch .= " $node";
		$i++;
	    }
	    if ($reboot > 0) {
		my $optarg = ($prepare ? "-p" : "");
		
		if (system("$nodereboot $optarg $batch")) {
		    print STDERR "*** $me:\n".
			"    WARNING: Could not reboot some of: $batch!\n";
		}
	    } elsif ($reboot < 0) {
		print STDOUT "Powering on nodes:\n";
		if (system("$power on $batch")) {
		    print STDERR "*** $me:\n".
			"    WARNING: Could not power on some of: $batch!\n";
		}
	    }
	    print STDOUT "  $batch ", @nodelist > 0 ? "...\n" : "\n";
	    if (@nodelist) {
		sleep($BATCHSLEEP);
	    }
	}
    }

    #
    # ...and wait for them to come back up.
    #
    if ($wait) {
	#
	# Initialize the statewait library.
	#
	my @finished = ();
	my @failed   = ();
	my $endtime = time() + $timo;

	print STDOUT "Waiting up to $timo seconds for nodes to come up.\n";
	
	# Now we can statewait.
	if (waitForState(\@finished, \@failed, $timo)) {
	    print STDERR "*** $me:\n".
		"    Failed in waitForState!\n";
	    @$failedref = @nodes
		if (defined($failedref));
	    return 1;
	}
	endStateWait();
	
	#
	# XXX gak! Our whole state wait system (actually event system)
	# doesn't distinguish timeouts.  A timeout is a failure in this
	# context since it means that some node did not get where it was
	# supposed to go, and that could be dangerous.  Fortunately, nodes
	# that do timeout, while not added to failed, are not added to
	# finished either (ditto for nodes that go through an improper
	# state transition sequence).  So if the sum of @finished + @failed
	# is not @nodes, then we know some nodes timed out.  So we can go
	# back and tease those out.
	#
	if (scalar(@nodes) > scalar(@finished) + scalar(@failed)) {
	    # there is probably a better way to do a set diff...
	    my %seen;
	    for my $n (@finished, @failed) {
		$seen{$n} = 1;
	    }
	    for my $n (@nodes) {
		push(@failed, $n)
		    if (!defined($seen{$n}));
	    }
	}

	if (@failed == 0) {
	    print STDOUT "All nodes are up.\n";
	    return 0;
	}

	print STDERR "*** $me:\n".
	             "    Failed to boot " . ($on ? "MFS" : "regular OS") .
		     " on: @failed\n";

	#
	# Failures to boot after powering on may be due to issues with
	# power-on and not related to the nodes themselves.  So we will
	# retry once, trying a power cycle the second time around.
	# This addresses cases where I have seen power on leave a machine
	# (pc600) in a hung state that can be cured by cycling (I have no
	# idea why...).
	#
	if ($reboot < 0 && $retry) {
	    print STDERR "Retrying on failed nodes ...\n";
	    my @myfailed;
	    my %myargs;
	    $myargs{'name'} = $me;
	    $myargs{'on'} = $on;
	    $myargs{'reboot'} = 1;
	    $myargs{'wait'} = $wait;
	    $myargs{'prepare'} = $prepare;
	    $myargs{'retry'} = 0;
	    if (TBAdminMfsBoot(\%myargs, \@myfailed, @failed) == 0) {
		return 0;
	    }
	    @failed = @myfailed;
	}

	@$failedref = @failed
	    if (defined($failedref));
	return 1;
    }

    return 0;
}

#
# TBAdminMfsSelect(\%args, \@failed, @nodes)
#
# For the given list of nodes, set or clear the temp OSID field so that
# they will or will not boot into the admin MFS.
#
# Arguments passed via the $args hashref:
#
#	'name'	   string identifying the caller for error messages
#	'on'	   1 to set temp OSID to MFS, 0 to clear
#	'clearall' 1 to clear one-shot and partition boot OSIDs
#		   (if 'on' is set), 0 leaves them alone
#       'recovery' use the recovery MFS instead of Admin (falling back
#                  to admin if not defined for the node).
#
# Returns zero if we successfully set the state for all nodes,
# and non-zero otherwise.  If the $failed ref is defined, it is an
# arrayref in which we return the list of nodes that failed.
#
# Note: NO PERMISSION CHECKING IS DONE.  It is assumed that the caller
# has performed all the necessary checks.
#
# Note: this call will clear any user-set startupcmd and status.  The
# caller is responsible for saving it if they care.
#
sub TBAdminMfsSelect($$@)
{
    my ($args, $failedref, @nodes) = @_;

    return 0
	if (@nodes == 0);

    my $me = $args->{'name'};
    my $on = $args->{'on'};
    my $only = $args->{'clearall'};
    my $recovery = $args->{'recovery'};
    my @good = ();
    my @bad = ();

    #
    # Set/clear the temp OSID for all nodes.
    #
    if ($on) {
	# clear one-shot boots
	if ($only && system("$osselect -c -1 @nodes")) {
	    print STDERR "*** $me:\n".
		"    Failed to clear one-shot boot for @nodes!\n";
	    @{$failedref} = @nodes
		if (defined($failedref));
	    return 1;
	}

	# determine the correct admin OSID for all nodes
	my %adminosid = ();
	for my $node (@nodes) {
	    my $osid;
	    if ($recovery) {
		$osid = TBNodeRecoveryOSID($node);
		if (!$osid) {
		    $osid = TBNodeAdminOSID($node);
		}
	    }
	    else {
		$osid = TBNodeAdminOSID($node);
	    }
	    push @{$adminosid{$osid}}, $node;
	}

	# and set it
	my $pxechanged = 0;
	my @admingood = ();
	for my $osid (keys %adminosid) {
	    my @n = @{$adminosid{$osid}};
	    if (system("$osselect -t $osid @n")) {
		print STDERR "*** $me:\n".
		    "    Failed to set temp boot to $osid for @n!\n";
		push(@bad, @n);
	    } else {
		push(@good, @n);

		# Construct the good list for nodes that are booting the
		# admin MFS; this list may be different than the @good
		# list (some nodes may boot the recovery MFS, for
		# instance).
		foreach my $nodeid (@n) {
		    if (TBNodeAdminOSID($nodeid) == $osid) {
			push @admingood, $nodeid;
		    }
		}

		#
		# See if this OSID requires a different pxeboot program.
		# If the OSID is a Linux MFS that needs to be booted by
		# grub2pxe, and if the node or node type has the
		# grub2pxe_path attribute, then change next_pxe_boot_path.
		#
		# If the default pxe_boot_path node/type attr is already
		# a grub2pxe, no need to set the grub2pxe_path node/type
		# attr for this to work.
		#
		my $osi = OSImage->Lookup($osid);
		my $path = $osi->osinfo()->path();
		if (-e "$path/grub.cfg") {
		    foreach my $nodeid (@n) {
			my $nodeobject = Node->Lookup($nodeid);
			my $gp;
			$nodeobject->NodeAttribute('grub2pxe_path',\$gp);
			if (!defined($gp)) {
			    $nodeobject->NodeTypeAttribute('grub2pxe_path',\$gp);
			}
			next
			    if (!defined($gp));
			my $node_pxechanged = 0;
			if ($nodeobject->PXESelect($gp, "next_pxe_boot_path",
						   0, \$node_pxechanged)) {
			    print STDERR "$me: pxe_select $nodeid $gp failed!";
			    next;
			}
			$pxechanged += $node_pxechanged;
		    }
		}
	    }
	}
	if ($pxechanged && system("$dhcpd_makeconf -i -r")) {
	    print STDERR "*** $me: restart DHCPD failed!";
	    return 1;
	}

	#
	# Possibly construct a dynamic NFS MFS for some nodes, but only
	# for those that are going to load the node/type default admin
	# mfs, because that is all the NFS MFS creation script supports.
	#
	my %cargs;
	$cargs{'name'} = $me;
	my @cfailed = ();
	if (@admingood && TBAdminMfsCreate(\%cargs, \@cfailed, @admingood)) {
	    print STDERR "*** $me:\n".
		"    Failed to create NFS FS for @cfailed; ".
		"continuing, but those nodes won't boot!\n";
	}

	# clear partition boots for successful nodes
	if ($only && system("$osselect -c @good")) {
	    print STDERR "*** $me:\n".
		"    Failed to clear partition boot for @good!\n";
	    @{$failedref} = @nodes
		if (defined($failedref));
	    return 1;
	}
    } else {
	if (system("$osselect -c -t @nodes")) {
	    print STDERR "*** $me:\n".
		"    Failed to clear temp boot for @nodes!\n";
	    @{$failedref} = @nodes
		if (defined($failedref));
	    return 1;
	}
	@good = @nodes;

	my $pxechanged = 0;
	foreach my $nodeid (@nodes) {
	    my $nodeobject = Node->Lookup($nodeid);
	    my $node_pxechanged = 0;
	    if (defined($nodeobject->next_pxe_boot_path)) {
		if ($nodeobject->PXESelect("", "next_pxe_boot_path",
					   0, \$node_pxechanged)) {
		    print STDERR "$me: pxe_select $nodeid '' failed!";
		    next;
		}
		$pxechanged += $node_pxechanged;
	    }
	}
	if ($pxechanged && system("$dhcpd_makeconf -i -r")) {
	    print STDERR "*** $me: restart DHCPD failed!";
	    return 1;
	}

	#
	# XXX note that this is a "soft" destroy.
	# We will only rename the existing MFS so that if the node
	# is currently running on it, it will continue to function.
	#
	# XXX: note that we call this even if we might not be running
	# the admin mfs (e.g. if we were told to run the recovery MFS
	# above).  This is harmless in that case.
	#
	my %cargs;
	$cargs{'name'} = $me;
	my @cfailed = ();
	if (TBAdminMfsDestroy(\%cargs, \@cfailed, @good)) {
	    print STDERR "*** $me:\n".
		"    Failed to destroy NFS FS for @cfailed; ".
		"continuing, but these FSes will need to be cleaned up!\n";
	}
    }

    #
    # Make sure we don't execute any unintended command, either those
    # set by the user when we enter admin mode, or those set by us when
    # we leave admin mode.
    #
    if (@good > 0) {
	my $cond = "node_id in (" . join(",", map("'$_'", @good)) . ")";
	if (!DBQueryWarn("update nodes set startupcmd='', startstatus='none' ".
			 "where $cond")) {
	    print STDERR "*** $me:\n".
		"    Failed to clear startup state for @good!\n";
	    push(@bad, @good);
	}
    }

    @{$failedref} = @bad
	if (defined($failedref));

    return (@bad != 0);
}

#
# TBAdminMfsRunCmd(\%args, \@failed, @nodes)
#
# For the given list of nodes, boot each one into the admin MFS and run the
# indicated command.  Upon successful completion, all nodes are left in the
# MFS with admin mode enabled.  Arguments passed in the $args hash:
#
#	'name'	    string identifying the caller for error messages
#	'command'   command+args to run on the nodes
#	'timeout'   time in seconds to wait for command completion
#		    (starts when node has booted into MFS)
#	'poweron'   1 if nodes need to be powered on initially
#		    rather than rebooted
#	'pfunc'
#	'pinterval'
#	'pcookie'   Progress tracking.  'pfunc' will be called every
#		    'pinterval' seconds with argument 'pcookie' and a
#		    node-indexed status hash for all nodes.  If
#		    the function returns 0, we abort as we would with
#		    a timeout.
#	'timestamp' if timestamps after significant events are desired
#	'prepare'   1 if nodes should be rebooted with "prepare" flag
#	'retry'     1 if we should retry once on nodes that do not make it
#		    into the MFS.
#
# Returns zero if all nodes successfully run the command.
# If the $failed ref is defined, it is an arrayref in which we return the
# list of nodes that failed.
#
# Note: NO PERMISSION CHECKING IS DONE.  It is assumed that the caller
# has performed all the necessary checks.
#
# Note: this call will clear any user-set startupcmd and status.  The
# caller is responsible for saving it if they care.
#
sub TBAdminMfsRunCmd($$@)
{
    my ($args, $failedref, @nodes) = @_;

    my $me = $args->{'name'};
    my $cmd = $args->{'command'};
    my $timeout = $args->{'timeout'};
    my $poweron = $args->{'poweron'};
    my $timestamp = $args->{'timestamp'};
    my $pfunc = $args->{'pfunc'};
    my $pinterval = $args->{'pinterval'};
    my $pcookie = $args->{'pcookie'};
    my $prepare = $args->{'prepare'};
    my $retry = $args->{'retry'};

    # we always need a value
    $timeout = $commandtimo
	if (!defined($timeout));
    $poweron = 0
	if (!defined($poweron));
    if ($pfunc) {
	$pinterval = 10
	    if (!defined($pinterval));
    }

    #
    # Arrange for the node to boot into the MFS, but don't boot it yet.
    #
    my %myargs;
    $myargs{'name'} = $me;
    $myargs{'on'} = 1;
    $myargs{'clearall'} = 0;
    if (TBAdminMfsSelect(\%myargs, undef, @nodes)) {
	@{$failedref} = @nodes
	    if (defined($failedref));
	return 1;
    }

    #
    # Record the startup command.  The status has already been set to
    # 'none' by Select above.
    #
    my $allcond = "node_id in (" . join(",", map("'$_'", @nodes)) . ")";
    if (!DBQueryWarn("update nodes set startupcmd='$cmd' where $allcond")) {
	print STDERR "*** $me:\n".
	    "    DB error updating node startupcmd info for @nodes!\n";
	@{$failedref} = @nodes
	    if (defined($failedref));
	return 1;
    }

    #
    # Now reboot into the admin MFS.  TBAdminMfsBoot will return when
    # the nodes report ISUP, which they will do before firing off the
    # startup command.
    #
    TBDebugTimeStamp("Booting nodes into admin MFS")
	if ($timestamp);
    %myargs = ();
    $myargs{'name'} = $me;
    $myargs{'on'} = 1;
    $myargs{'reboot'} = $poweron ? -1 : 1;
    $myargs{'retry'} = $retry;
    $myargs{'prepare'} = $prepare;
    $myargs{'wait'} = 1;
    my @failed = ();
    if (TBAdminMfsBoot(\%myargs, \@failed, @nodes)) {
	print STDERR "*** $me:\n".
	    "    failed admin MFS boot for @failed!\n";
	@{$failedref} = @nodes
	    if (defined($failedref));
	return 1;
    }

    #
    # Wait for the command completion status or til we time out
    #
    TBDebugTimeStamp("Nodes in admin MFS, running command")
	if ($timestamp);
    my @running = @nodes;
    my %status = ();
    foreach my $node (@nodes) {
	$status{$node} = "none";
    }
    my $endtime = time() + $timeout;
    my $interval = $pfunc ? $pinterval : $sleepwait;
    while (@running > 0 && time() < $endtime) {
	sleep($interval);

	my $cond = "node_id in (" . join(",", map("'$_'", @running)) . ")";
	my $query_result =
	    DBQueryWarn("select node_id,startstatus from nodes where $cond");

	if (!$query_result || $query_result->numrows < 1) {
	    print STDERR "*** $me:\n".
		"    DB error getting startstatus for @running!\n";
	    @running = ();
	    last;
	}
 
	while (my ($node, $result) = $query_result->fetchrow_array()) {
	    $status{$node} = $result;
	}

	#
	# Run the progress function with the updated status of all nodes.
	#
	if ($pfunc && &$pfunc($pcookie, \%status) == 0) {
	    last;
	}

	#
	# Recompute the set of running nodes after any progress function
	# has been called in case that function has updated a node's status.
	# We trust that the function will be well behaved and not add nodes
	# that don't belong!
	#
	@running = grep { $status{$_} eq "none" } keys(%status);
    }

    #
    # Everyone has reported or we timed out.
    # Find out who succeeded, who failed, and who timed out.
    #
    TBDebugTimeStamp("Node admin MFS commands completed/timedout")
	if ($timestamp);
    my @succeeded = ();
    my @timedout = ();
    for my $node (@nodes) {
	if ($status{$node} eq "none" || $status{$node} eq "timeout") {
	    push(@timedout, $node);
	} elsif (int($status{$node}) != 0) {
	    push(@failed, $node);
	} else {
	    push(@succeeded, $node);
	}
    }

    if (scalar(@nodes) != scalar(@succeeded)) {
	if (scalar(@failed) > 0) {
	    print STDERR "*** $me:\n".
		"    Command run failed on @failed\n";
	    push(@{$failedref}, @failed)
		if (defined($failedref));
	}
	if (scalar(@timedout) > 0) {
	    print STDERR "*** $me:\n".
		"    Timed-out while running command on @timedout\n";
	    push(@{$failedref}, @timedout)
		if (defined($failedref));
	}
	return 1;
    }

    print STDOUT "All nodes have completed their command.\n";
    return 0;
}

#
# TBAdminMfsCreate(\%args, \@failed, @nodes)
#
# For the given list of nodes, find those that need their MFS created
# dynamically and do so.
#
# Arguments passed via the $args hashref:
#
#	'name'	   string identifying the caller for error messages
#	'force'    1 to force re-creation of the MFS if it already exists,
#		   0 will just reuse any existing MFS.
#
# Returns zero if we successfully created all MFSes and non-zero otherwise.
# If the $failed ref is defined, it is an arrayref in which we return the
# list of nodes that failed.
#
# Note: NO PERMISSION CHECKING IS DONE.  It is assumed that the caller
# has performed all the necessary checks.
#
sub TBAdminMfsCreate($$@)
{
    my ($args, $failedref, @nodes) = @_;

    return 0
	if (!$NFSMFS);
    return 0
	if (@nodes == 0);

    my $me = $args->{'name'};
    my $force = exists($args->{'force'}) ? $args->{'force'} : 0;

    #
    # Find all the nodes that require a dynamic MFS
    #
    my @nfsnodes = ();
    for my $node (@nodes) {
	my $osobj = OSImage->Lookup(TBNodeAdminOSID($node));
	if ($osobj && $osobj->IsNfsMfs()) {
	    push @nfsnodes, $node;
	}
    }

    #
    # If any nodes are using an NFS-based MFS, set them up.
    #
    if (@nfsnodes > 0) {
	my $args = $force ? "-f" : "";
	if (system("$nfsmfssetup $args @nfsnodes")) {
	    @$failedref = @nfsnodes
		if (defined($failedref));
	    return 1;
	}
    }

    return 0;
}

#
# TBAdminMfsDestroy(\%args, \@failed, @nodes)
#
# For the given list of nodes, find those that use a dynamic MFS
# and destroy it.
#
# Arguments passed via the $args hashref:
#
#	'name'	   string identifying the caller for error messages
#	'force'    1 to force actual destruction of the MFS, screwing
#		   the node if it is currently running on it.
#		   0 will just rename the existing MFS instead,
#		   with the old copy destroyed on next creation.
#
# Returns zero if we successfully destroyed all MFSes and non-zero otherwise.
# If the $failed ref is defined, it is an arrayref in which we return the
# list of nodes that failed.
#
# Note: NO PERMISSION CHECKING IS DONE.  It is assumed that the caller
# has performed all the necessary checks.
#
sub TBAdminMfsDestroy($$@)
{
    my ($args, $failedref, @nodes) = @_;

    return 0
	if (!$NFSMFS);
    return 0
	if (@nodes == 0);

    my $me = $args->{'name'};
    my $force = exists($args->{'force'}) ? $args->{'force'} : 0;

    #
    # Find all the nodes that require a dynamic MFS
    #
    my @nfsnodes = ();
    for my $node (@nodes) {
	my $osobj = OSImage->Lookup(TBNodeAdminOSID($node));
	if ($osobj && $osobj->IsNfsMfs()) {
	    push @nfsnodes, $node;
	}
    }

    #
    # If any nodes are using an NFS-based MFS, set them up.
    #
    if (@nfsnodes > 0) {
	my $args = $force ? "-f" : "";
	if (system("$nfsmfssetup -D $args @nfsnodes")) {
	    @$failedref = @nfsnodes
		if (defined($failedref));
	    return 1;
	}
    }

    return 0;
}
