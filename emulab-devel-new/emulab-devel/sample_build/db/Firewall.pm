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

#
# Some firewall stuff.
#
package Firewall;
use strict;
use Exporter;
use vars qw(@ISA @EXPORT);
@ISA = "Exporter";
@EXPORT = qw ( doFWlans undoFWNodes
	       FWSETUP FWADDNODES FWDELNODES FWTEARDOWN
	       );

# Configure variables
my $TB	      = "/users/mshobana/CloudLabonESI/emulab-devel-new/emulab-devel/sample_build";
my $TBOPS     = "testbed-ops\@ops.cloudlab.umass.edu";
my $POWER     = "$TB/bin/power";
my $SNMPIT    = "$TB/bin/snmpit";
my $VNODESETUP= "$TB/sbin/vnode_setup";

# Flags.
sub FWSETUP()		{ return 1; }
sub FWADDNODES()	{ return 2; }
sub FWDELNODES()	{ return 3; }
sub FWTEARDOWN()	{ return 4; }

# XXX fixme: should not be hardwired!
my $cnetstack    = "-S Control";
my $cnetvlanname = "Control";

use emdbi;
use libdb;
use libtestbed;
use libadminmfs;
use libtblog_simple;
use Node;
use Interface;
use Experiment;
use Lan;

#
# Setup and teardown experiment firewall.
#
# XXX note that right now, we just setup the switch infrastructure
# first, and then just let everything else go.  Firewalled nodes will
# not boot until the firewall is up since the VLAN is isolated til then.
# The firewall will boot ok since it still talks to the real control net.
#
# XXX for tearing down firewalls, we assume that nodes have been "cleansed"
# and it is safe to put ports back into the default control net VLAN.
#
sub doFWlans($$$) {
    my ($experiment, $action, $nodelist) = @_;
    my ($fwnode, $fwvlanname, $fwvlan, $fwport, $fwvid);
    my %nodenames;

    my $pid = $experiment->pid();
    my $eid = $experiment->eid();

    #
    # See if there is a firewall, fetching node/VLAN info if so.
    # If not, we are all done.
    #
    if (!$experiment->IsFirewalled(\$fwnode, \$fwvid, \$fwvlan)) {
	return 0;
    }

    if ($action == FWSETUP) {
	# Allow redo.
	$fwvid = TBGetUniqueIndex("cnet_vlanid")
	    if (!defined($fwvid));

	print "Setting up control net firewall.\n";
    }
    else {
	if ($action == FWADDNODES) {
	    print "Adding nodes to control net firewall.\n";
	}
	elsif ($action == FWDELNODES) {
	    print "Removing nodes from control net firewall.\n";
	}
	else {
	    print "Tearing down control net firewall.\n";
	}

	# Prior setup didn't succeed, nothing to do
	if (!defined($fwvid)) {
	    return 0;
	}
    }

    # See below.
    if (defined($nodelist)) {
	foreach my $nodeid (@$nodelist) {
	    my $node = Node->Lookup($nodeid);
	    if (!defined($node)) {
		tberror("Could not map $nodeid to its object");
		return 1;
	    }
	    $nodenames{$nodeid} = $node;
	}
    }

    # Get current list of reserved nodes. 
    my @allnodes;
    if (Node->BulkLookup($experiment, \@allnodes) < 0) {
	tberror("Failed to load reserved nodes");
	return 1;
    }

    # XXX vlanid in the DB is currently an int, we need a more unique name
    $fwvlanname = "fw$fwvid";

    #
    # Find all the experiment nodes and their control interface switch ports
    #
    my $portlist  = "";
    foreach my $node (@allnodes) {
	next
	    if ($node->isremotenode() || $node->isvirtnode());

	my $control_iface = Interface->LookupControl($node);
	if (!defined($control_iface)) {
	    tberror("Could not find control iface object for $node");
	    return 1;
	}
	my $node_id = $node->node_id();
	my $cif = $control_iface->iface();
	    
	if ($node_id eq $fwnode) {
	    $fwport = "$node_id:$cif";
	}
	elsif (defined($nodelist)) {
	    # Only nodes we are moving in/out of the experiment.
	    $portlist .= " $node_id:$cif"
		if (exists($nodenames{$node_id}));
	}
	else {
	    $portlist .= " $node_id:$cif";
	}
    }
    if (!defined($fwport)) {
	tberror "Firewall node '$fwnode' not found in $pid/${eid}!";
	return 0;
    }
    if ($portlist eq "") {
	#
	# We catch this up in swapexp; admin users can specify just a firewall,
	# but mere users must have at least one firewalled node. Just print
	# the warning though. 
	# 
	tbwarn "No firewalled nodes in $pid/${eid}!";
    }

    #
    # XXX hack commands til we nail down the API
    #
    my $fwsetupstr1 = "$SNMPIT $cnetstack -m $fwvlanname $pid $eid $portlist";
    my $fwsetupstr3 = "$SNMPIT $cnetstack -T $fwport $cnetvlanname ";
    my $fwtakedownstr0 = "$SNMPIT $cnetstack -e $fwport";
    my $fwtakedownstr1 = ($portlist eq "" ? "true" :
		  "$SNMPIT $cnetstack -m $cnetvlanname $pid $eid $portlist");
    my $fwtakedownstr1b = ($portlist eq "" ? "true" :
		  "$SNMPIT -f $cnetstack -m $cnetvlanname $portlist");
    my $fwtakedownstr2 = "$SNMPIT $cnetstack -o $fwvlanname $pid $eid";
    my $fwtakedownstr3 = "$SNMPIT $cnetstack -U $fwport";
    my $fwtakedownstr4 = "$SNMPIT $cnetstack -f -m $cnetvlanname $fwport";

    if ($action == FWSETUP) {
	TBDebugTimeStamp("snmpit firewall setup: VLAN");
	print "doFW: '$fwsetupstr1'\n";
	if (system($fwsetupstr1)) {
	    tberror({type => 'secondary', severity => SEV_SECONDARY,
		     error => ['fwcnvlan_setup_failed']},
		    "Failed to setup Firewall control net VLAN.");
	    return 1;
	}
	my $vlan = VLan->Lookup($experiment, $fwvlanname);
	if (!defined($vlan)) {
	    tberror({type => 'secondary', severity => SEV_SECONDARY,
		     error => ['fwcnvlan_setup_failed']},
		    "Failed to locate vlan object for $fwvlanname");
	    return 1;
	}
	if ($vlan->GetTag(\$fwvlan) != 0) {
	    tberror("No vlan tag associated with $vlan");
	    goto badsetup;
	}

	#
	# No point to trunking if thre are no ports; fails.
	#
	if ($portlist ne "") {
	    $fwsetupstr3 = "$fwsetupstr3 " . $vlan->id();
	    TBDebugTimeStamp("snmpit firewall setup: trunk");
	    print "doFW: '$fwsetupstr3'\n";
	    if (system($fwsetupstr3)) {
		tberror "Failed to setup Firewall trunk on port $fwport.";
	      badsetup:
		print "doFW: '$fwtakedownstr1'\n";
		if (system($fwtakedownstr1)) {
		    tberror "Could not return $portlist to Control VLAN!";
		    return 1;
		}
		print "doFW: '$fwtakedownstr2'\n";
		if (system($fwtakedownstr2)) {
		    tberror "Could not destroy VLAN $fwvlanname ($fwvlan)!";
		    return 1;
		}
		print "doFW: '$fwtakedownstr3'\n";
		if (system($fwtakedownstr3)) {
		    tberror "Could not untrunk $fwport!";
		    return 1;
		}
		print "doFW: '$fwtakedownstr4'\n";
		if (system($fwtakedownstr4)) {
		    tberror "Could not move $fwport back to Control lan!";
		}
		return 1;
	    }
	}
	TBDebugTimeStamp("snmpit firewall setup done");

	# Record VLAN info now that everything is done
	$experiment->SetFirewallVlan($fwvid, $fwvlan);
	return 0;
    }
    elsif ($action == FWADDNODES) {
	my $vlan = VLan->Lookup($experiment, $fwvlanname);
	if (!defined($vlan)) {
	    tberror "Cannot find vlan object for $fwvlanname";
	    return 1;
	}
	TBDebugTimeStamp("snmpit firewall port addition");
	print "doFW: '$fwsetupstr1'\n";
	if (system($fwsetupstr1)) {
	    tberror "Failed to add nodes to Firewall control net VLAN.";
	    return 1;
	}
	#
	# Redo the trunk operation since there might not have been
	# any ports last time, and the vlan would not have existed,
	# so the trunk would not be setup.
	#
	$fwsetupstr3 = "$fwsetupstr3 " . $vlan->id();
	print "doFW: '$fwsetupstr3'\n";
	if (system($fwsetupstr3)) {
	    tberror "Failed to setup Firewall trunk on port $fwport.";
	    return 1;
	}
	TBDebugTimeStamp("snmpit firewall setup done");
    }
    elsif ($action == FWDELNODES) {
	TBDebugTimeStamp("snmpit firewall port deletion");
	print "doFW: '$fwtakedownstr1'\n";
	if (system($fwtakedownstr1)) {
	    #
	    # If the exit value is "2" then retry with hidden force option
	    # since the port was probably already moved, but snmpit has no
	    # way to verify that. We do know it is out of the old vlan though.
	    #
	    if ($? >> 8 == 2) {
		system($fwtakedownstr1b);
	    }
	    if ($?) {
		tberror "Failed to remove nodes from Firewall ".
			"control net VLAN.\n";
		return 1;
	    }
	}
	TBDebugTimeStamp("snmpit firewall setup done");
    }
    else {
	TBDebugTimeStamp("snmpit re-enable fw control port: $fwport");
	print "doFW: '$fwtakedownstr0'\n";
	my $failed = 0;
	if (system($fwtakedownstr0)) {
	    tberror "Could not re-enable firewall control port $fwport!";
	    $failed = 1;
	}
	#
	# Do not try to do this if the vlan is already gone.
	#
	my $vlan = VLan->Lookup($experiment, $fwvlanname);
	if (defined($vlan)) {
	    TBDebugTimeStamp("snmpit firewall teardown: VLAN");
	    print "doFW: '$fwtakedownstr1'\n";
	    if (system($fwtakedownstr1)) {
		tberror "Could not return $portlist to Control VLAN!";
		return 1;
	    }
	    print "doFW: '$fwtakedownstr2'\n";
	    if (system($fwtakedownstr2)) {
		tberror "Could not destroy VLAN $fwvlanname ($fwvlan)!";
		return 1;
	    }
	}
	TBDebugTimeStamp("snmpit firewall teardown: trunk");
	print "doFW: '$fwtakedownstr3'\n";
	if (system($fwtakedownstr3)) {
	    tberror "Could not tear down trunk on $fwport!";
	    $failed = 1;
	}
	print "doFW: '$fwtakedownstr4'\n";
	if (system($fwtakedownstr4)) {
	    tberror "Could not return $fwport to Control VLAN!";
	    $failed = 1;
	}
	if ($failed) {
	    return 1;
	}
	TBDebugTimeStamp("snmpit firewall teardown done");

	# Clean VLAN info from DB
	$experiment->ClearFirewallVlan();
    }
    return 0;
}

#
# Undo the firewall state for a set of nodes in the indicated experiment.
# If no nodes are specified, we remove all nodes and tear down the firewall.
#
# This function takes care of ensuring that all such nodes have been
# neutered prior to being released:
#
# Change the OSID of all nodes (firewall included) to reboot into
# the admin MFS and then power cycle them.  We must power cycle to
# ensure nodes don't spoof a simple reboot request and pretend to
# come up in the MFS.  The power "cycle" is actually an "off"
# followed by an "on", since true power cycling of large numbers
# of nodes may be done in batches to avoid network (or power)
# overload on restart.  Skewed reboots like this open a window of
# vulnerability where nodes rebooted later might be able, before
# they are rebooted, to spoof the reload server for nodes that have
# just rebooted.  So we first turn everyone off, then batched power
# ons are safe.
#
# Note that we take down the firewall while the nodes are turned
# off.  This is a convenient time while we know no nodes are in
# transition.  Plus, since we take down the firewall too, other
# nodes would not be able to reboot if we left the firewall up.
#
# BIG SECURITY ASSUMPTION: we are assuming that upon power on,
# no node can somehow reboot from the hard disk instead of
# from the network.  If it does, it is out from behind the
# firewall and can wreak havoc.
#
sub undoFWNodes($;$@) {
    my ($experiment, $leavefw, @nodes) = @_;
    my $doall   = 0;
    my $fwerr   = 0;
    my @fwstate = ();
    my $zap = 1;
    my $pid = $experiment->pid();
    my $eid = $experiment->eid();
    $leavefw = 0
	if (!defined($leavefw));

    my $fwnode;
    return 0
	if ($experiment->IsFirewalled(\$fwnode) == 0);

    if (!@nodes || scalar(@nodes) == 0) {
	$experiment->LocalNodeListNames(\@nodes, 1);
	if ($leavefw) {
	    @nodes = grep {$_ ne $fwnode} @nodes;
	}
	else {
	    $doall = 1;
	}
    }

    #
    # There has to at least be a firewall node to be interesting
    #
    if (@nodes == 0) {
	return 0;
    }

    if ($doall) {
	print "Taking down experiment firewall.\n";
    } else {
	if (grep {$_ eq $fwnode} @nodes) {
	    tberror "Cannot remove firewall node from an experiment!";
	    return 1;
	}
	print "Removing firewalled nodes from experiment.\n";
    }

    #
    # At the lowest level of security, we don't do the diskzap dance
    # unless we have paniced.
    #
    # This level ("blue") is used for experiments where we are trying to
    # protect the inside from outside; i.e., there is no bad stuff inside
    # to clean up.
    #
    my $paniced = $experiment->paniced();
    my $security_level = $experiment->security_level();
    if ($paniced == 0 && $security_level < TBDB_SECLEVEL_ZAPDISK()) {
	$zap = 0;
    }

    #
    # First turn off all the machines.
    # If we fail, the firewall in left in place, and some nodes may
    # be powered off.
    #
    if ($zap) {
	print STDERR "Powering down firewalled nodes.\n";
	TBDebugTimeStamp("Powering down nodes");
	system("$POWER off @nodes");
	if ($?) {
	    tberror(SEV_SECONDARY, 'power_off_failed');
	    $fwerr = "Failed to power off all nodes!";
	    @fwstate = ("Firewall is still in place",
			"Some nodes may NOT be powered off",
			"Nodes NOT switched to admin MFS");
	    goto done;
	}

	#
	# Force all nodes into admin mode.
	# If we fail, the firewall is left in place.
	#
	my %myargs;
	$myargs{'name'} = "tbswap";
	$myargs{'on'} = 1;
	$myargs{'clearall'} = 1;
	if (TBAdminMfsSelect(\%myargs, undef, @nodes)) {
	    $fwerr = "Failed to force all nodes into admin mode!";
	    @fwstate = ("Firewall is still in place",
			"All nodes are powered off",
			"Not all nodes have been switched to admin MFS");
	    goto done;
	}
    }

    #
    # Once all nodes have been turned off and their DB state changed
    # to force MFS booting, we can modify the switch firewall state,
    # either tearing down the firewall ($doall) entirely or just moving
    # the indicated nodes out from behind it (!$doall).
    #
    # If this fails, we warn and punt.  The switch or DB state could
    # be screwed up at this point.
    #
    if ($doall) {
	if (doFWlans($experiment, FWTEARDOWN, undef)) {
	    $fwerr = "Failed to tear down firewall!";
	    @fwstate = ("Firewall may NOT be in place",
			$zap ? ("All nodes are powered off",
				"All nodes set to admin mode") : (),
			"Switch/DB firewall state could be inconsistent!");
	    goto done;
	}
    } else {
	my @deleted = @nodes;
	if (doFWlans($experiment, FWDELNODES, \@deleted)) {
	    $fwerr = "Failed to remove nodes from firewall VLAN!";
	    @fwstate = ("Nodes may still be in firewall VLAN",
			$zap ? ("All nodes are powered off",
				"All nodes set to admin mode") : ());
	    goto done;
	}
    }

    #
    # Now we power on the nodes and let them boot into the MFS,
    # where they will run the disk bootblock zapper.
    #
    # If this fails, we power off all the nodes again and get a
    # little edgy in our error messages to emphasize the gravity
    # of the situation.  Someday we could just move the failed
    # nodes into a special firewalled holding experiment, and
    # let the experiment swapout finish, freeing up the nodes that
    # did succeed.
    #
    if ($zap) {
	print STDERR "Booting nodes into admin MFS and zapping bootblocks.\n";
	TBDebugTimeStamp("Booting admin MFS/zapping bootblocks");
	my @failed = ();
	my %myargs = ();
	$myargs{'name'} = "tbswap";
	$myargs{'command'} = "sudo /usr/local/bin/diskzap";
	$myargs{'poweron'} = 1;
	$myargs{'retry'} = 1;
	if (TBAdminMfsRunCmd(\%myargs, \@failed, @nodes)) {
	    foreach my $failed (@failed) {
		tberror(SEV_ERROR, 'invalidate_bootblock_failed', $failed);
	    }
	    $fwerr = "Failed to invalidate bootblocks on @failed!";
	    @fwstate = ("Firewall is NOT in place",
			"All nodes set to admin mode");
	    system("$POWER off @nodes");
	    if ($?) {
		push(@fwstate, "Some nodes may NOT be powered off");
	    } else {
		push(@fwstate, "All nodes are powered off");
	    }
	    push(@fwstate, "MAKE SURE THESE NODES DO NOT BOOT FROM DISK!");
	}
    }

done:
    #
    # If we had a failure when tearing down the firewall completely,
    # we act as though the panic button had been pressed (set panic
    # bit in DB, disable cnet port, and inform tbops).  This hopefully
    # ensures that everything will get cleaned up correctly.  This may
    # eventually prove to be overkill.
    #
    # If we failed while removing some nodes from behind the firewall
    # we don't get quite so cranky.
    #
    if ($fwerr) {
	my $op;

	if ($doall) {
	    my $fwiface;
	    if ($experiment->FirewallAndIface(\$fwnode, \$fwiface) != 0 ||
		system("$SNMPIT -d ${fwnode}:${fwiface}") != 0) {
		push(@fwstate,
		     "Firewall cnet interface ${fwnode}:${fwiface} NOT disabled");
	    } else {
		push(@fwstate,
		     "Firewall cnet interface ${fwnode}:${fwiface} disabled");
	    }
	    $experiment->SetPanicBit(2);
	    $op = "Swapout";
	} else {
	    $op = "Modify";
	}

	my $this_user = User->ThisUser();
	my $user_uid;
	my $user_name;
	my $user_email;
	if (defined($this_user)) {
	    $user_uid   = $this_user->uid();
	    $user_name  = $this_user->name();
	    $user_email = $this_user->email();
	}
	tberror "$fwerr" . "\nINFORMING $TBOPS!";
	if (defined($user_email)) {
	    SENDMAIL("$user_name <$user_email>",
		     "Firewalled experiment $op failed".
		     " for $pid/$eid",
		     "$op of firewalled experiment $pid/$eid".
		     " by $user_uid failed!\n".
		     "Admin intervention required:\n\n$fwerr\n\n".
		     "Current state of @nodes:\n\n".
		     join("\n", @fwstate) . "\n",
		     "$user_name <$user_email>",
		     "Cc: $TBOPS");
	}
	return 1;
    }

    return 0;
}

#
# The guts of "panic", which is also used for non-firewalled experiments.
#
# Flags.
sub PANIC_PANIC()		{ return 1; }
sub PANIC_CLEAR()		{ return 2; }
sub PANIC_ZAP()			{ return 3; }

sub Panic($$$)
{
    my ($experiment, $level, $which) = @_;

    my $pid = $experiment->pid();
    my $eid = $experiment->eid();

    my $firewalled = $experiment->IsFirewalled();
    my ($firewall, $iface);
    if ($firewalled) {
	if ($experiment->FirewallAndIface(\$firewall, \$iface) != 0) {
	    print STDERR "Could not determine firewall port for $experiment\n";
	    return -1;
	}
    }
    my @nodes = ();
    $experiment->LocalNodeListNames(\@nodes, 1);
    my @vnodes = $experiment->VirtNodeList(1);
	
    if ($which == PANIC_ZAP()) {
	$level = $experiment->paniced();
	goto nonodes1
	    if (!@nodes);
	
	print STDERR "Powering down paniced nodes.\n";
	system("$POWER off @nodes");
	if ($?) {
	    print STDERR "Failed to power off all nodes!\n";
	    print STDERR "Nodes NOT switched to admin MFS\n";
	    goto badzap;
	}

	#
	# Force all nodes into admin mode.
	#
	my %myargs;
	$myargs{'name'}     = "$0";
	$myargs{'on'}       = 1;
	$myargs{'clearall'} = 1;
	if (TBAdminMfsSelect(\%myargs, undef, @nodes)) {
	    print STDERR "Failed to force all nodes into admin mode!\n";
	    goto badzap;
	}
      nonodes1:

	#
	# This code is not used for firewalled experiments, so we only
	# have to worry about the control network.
	#
	if ($level == 2) {
	    system("$SNMPIT -R $pid $eid");
	    if ($?) {
		goto badzap;
	    }
	}
	goto nonodes2
	    if (!@nodes);
	
	#
	# Now we power on the nodes and let them boot into the MFS,
	# where they will run the disk bootblock zapper.
	#
	# If this fails, we power off all the nodes again and get a
	# little edgy in our error messages to emphasize the gravity
	# of the situation.  Someday we could just move the failed
	# nodes into a special firewalled holding experiment, and
	# let the experiment swapout finish, freeing up the nodes that
	# did succeed.
	#
	print STDERR "Booting nodes into admin MFS and zapping bootblocks.\n";
	my @failed = ();
	%myargs = ();
	$myargs{'name'}    = "$0";
	$myargs{'command'} = "sudo /usr/local/bin/diskzap";
	$myargs{'poweron'} = 1;
	$myargs{'retry'}   = 1;
	if (TBAdminMfsRunCmd(\%myargs, \@failed, @nodes)) {
	    print STDERR "Failed to invalidate bootblocks on @failed!\n";
	  badzap:
	    print STDERR "Powering nodes off again ...\n";
	    system("$POWER off @nodes");
	    if ($?) {
		print STDERR "Some nodes may NOT be powered off.\n";
	    } else {
		print STDERR "All nodes are powered off.\n";
	    }
	    print STDERR "MAKE SURE THESE NODES DO NOT BOOT FROM DISK!\n";

	    SENDMAIL($TBOPS,
		     "Failed to invalidate boot blocks for $pid/$eid\n",
		     "Failed to invalidate boot blocks while swapping out\n".
		     "paniced experiment $pid/$eid.\n");
	    goto bad;
	}
      nonodes2:
    }
    elsif ($which == PANIC_CLEAR()) {
	$level = $experiment->paniced();
	
	if ($level == 1) {
	    goto nonodes
		if (!@nodes);

	    #
	    # Do the VMs. We continue if we get errors, want to do
	    # as much as possible.
	    #
	    if (@vnodes) {
		print "Restarting all containers ...\n";
		system("$VNODESETUP -d -f -j $pid $eid");
	    }
	    
	    #
	    # Turn admin mode back off and reboot back to the old OS
	    #
	    print "Allowing all nodes to reboot out of admin mode ...\n";

	    my %myargs;
	    $myargs{'name'}     = "$0";
	    $myargs{'on'}       = 0;
	    $myargs{'clearall'} = 0;
	    if (TBAdminMfsSelect(\%myargs, undef, @nodes)) {
		print STDERR "Could not turn admin mode off for nodes\n";
		goto bad;
	    }
	    $myargs{'reboot'} = 1;
	    $myargs{'wait'}   = 0;
	    if (TBAdminMfsBoot(\%myargs, undef, @nodes)) {
		print STDERR "Failed to reboot nodes out of admin mode\n";
		goto bad;
	    }
	  nonodes:
	}
	else {
	    print "Enabling the control network ...\n";
	    if ($firewalled) {
		system("$SNMPIT -e ${firewall}:${iface}");
	    }
	    else {
		system("$SNMPIT -R $pid $eid");
	    }
	    if ($?) {
		print STDERR "snmpit exited with $?\n";
		goto bad;
	    }
	}
	$experiment->SetPanicBit(0);
    }
    elsif ($which == PANIC_PANIC()) {
	if ($level == 1) {
	    #
	    # Do the VMs. We continue if we get errors, want to do
	    # as much as possible.
	    #
	    if (@vnodes) {
		print "Halting all containers ...\n";
		system("$VNODESETUP -d -f -h $pid $eid");
	    }
	    
	    #
	    # Boot into the admin MFS
	    #
	    print "Booting all phys nodes into admin mode and waiting ...\n";
	    
	    my %myargs;
	    $myargs{'name'} = "$0";
	    $myargs{'on'}   = 1;
	    if (TBAdminMfsSelect(\%myargs, undef, @nodes)) {
		print STDERR "Failed to force all nodes into admin mode!\n";
		print STDERR "Falling back to control network disable\n";
		$level = 2;
		goto level2;
	    }
	    $myargs{'reboot'} = 1;
	    $myargs{'wait'}   = 1;
	    $myargs{'retry'}  = 1;
	    if (TBAdminMfsBoot(\%myargs, undef, @nodes)) {
		print STDERR "Failed to boot all nodes into admin mode!\n";
		print STDERR "Falling back to control network disable\n";
		$level = 2;
		goto level2;
	    }
	}
	else {
	  level2:
	    print "Disabling the control network ...\n";
	    if ($firewalled) {
		system("$SNMPIT -d ${firewall}:${iface}");
	    }
	    else {
		system("$SNMPIT -D $pid $eid");
	    }
	    if ($?) {
		print STDERR "snmpit exited with $?\n";
		goto bad;
	    }
	}
	$experiment->SetPanicBit($level);
    }
    return 0;

  bad:
    return -1;
}
