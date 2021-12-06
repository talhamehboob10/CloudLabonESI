#!/usr/bin/perl -w
#
# Copyright (c) 2000-2021 University of Utah and the Flux Group.
# 
# {{{EMULAB-LGPL
# 
# This file is part of the Emulab network testbed software.
# 
# This file is free software; you can redistribute it and/or modify it
# under the terms of the GNU Lesser General Public License as published by
# the Free Software Foundation; either version 2.1 of the License, or (at
# your option) any later version.
# 
# This file is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
# FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Lesser General Public
# License for more details.
# 
# You should have received a copy of the GNU Lesser General Public License
# along with this file.  If not, see <http://www.gnu.org/licenses/>.
# 
# }}}
#

#
# Module of subroutines useful to snmpit and its modules
#

package snmpit_lib;

use Exporter;
@ISA = ("Exporter");
use vars qw($PORT_FORMAT_IFINDEX $PORT_FORMAT_MODPORT
            $PORT_FORMAT_NODEPORT $PORT_FORMAT_PORT $PORT_FORMAT_PORTINDEX);

# For convertPortFormat in the device libraries.
$PORT_FORMAT_IFINDEX  = 1;
$PORT_FORMAT_MODPORT  = 2;
$PORT_FORMAT_NODEPORT = 3;
$PORT_FORMAT_PORT     = 4;
$PORT_FORMAT_PORTINDEX= 5;

@EXPORT = qw( macport portnum portiface Dev vlanmemb vlanid
		getTestSwitches getControlSwitches getSwitchesInStack
                getSwitchesInStacks
		getVlanPorts getAllVlanPorts
		getExperimentTrunks setVlanStack
		getExperimentVlans getDeviceNames getDeviceType
		getInterfaceSettings mapPortsToDevices getSwitchPrimaryStack
		getSwitchStacks getStacksForSwitches
		getStackType getStackLeader filterVlansBySwitches
		getDeviceOptions getTrunks getTrunksFromSwitches
                getTrunkHash 
		getExperimentPorts snmpitGet snmpitGetWarn snmpitGetFatal
                getExperimentControlPorts
                getPlannedStacksForVlans getActualStacksForVlans
                filterPlannedVlans
		snmpitSet snmpitSetWarn snmpitSetFatal 
                snmpitBulkwalk snmpitBulkwalkWarn snmpitBulkwalkFatal
	        setPortEnabled setPortTagged IsPortTagged
		printVars tbsort getExperimentCurrentTrunks
	        getExperimentVlanPorts
                uniq isSwitchPort getPathVlanIfaces
		reserveVlanTag getReservedVlanTag clearReservedVlanTag
                convertPortFromString convertPortsFromStrings
                mapVlansToSwitches mapStaleVlansToSwitches
		getTrunksForVlan getExperimentTrunksForVlan
		getSwitchTrunkPath setSwitchTrunkPath
		mapPortsToSwitches findAndDumpLan
	        getTrunkedStitchPorts
		snmpit_lock snmpit_unlock
		$PORT_FORMAT_IFINDEX $PORT_FORMAT_MODPORT
                $PORT_FORMAT_NODEPORT $PORT_FORMAT_PORT $PORT_FORMAT_PORTINDEX
);

use English;
use libdb;
use libtestbed;
use libtblog qw(tbdie tbwarn tbreport SEV_ERROR);
use Experiment;
use Lan;
use emutil qw(SpanningTree);
use strict;
use SNMP;
use Port;
use Carp qw(cluck);
use Data::Dumper;

my $TBOPS = libtestbed::TB_OPSEMAIL;

my $debug = 0;

my $DEFAULT_RETRIES = 10;

my $SNMPIT_GET = 0;
my $SNMPIT_SET = 1;
my $SNMPIT_BULKWALK = 2;

##################################################
# deprecated:

my %Devices=();
# Devices maps device names to device IPs

my %Interfaces=();
# Interfaces maps pcX:Y<==>MAC

my %PortIface=();
# Maps pcX:Y<==>pcX:iface

my %IfaceModPorts=();
# Maps switch:iface <=> switch:card.port

my %Ports=();
# Ports maps pcX:Y<==>switch:port

##################################################

my %vlanmembers=();
# vlanmembers maps id -> members

my %vlanids=();
# vlanids maps pid:eid <==> id

my %DeviceOptions=();
# Maps devicename -> hash of options to avoid db call after forking;

my $snmpitErrorString;

# Protos
sub getTrunkPath($$$$);

#
# Initialize the library
#
sub init($) {
    $debug = shift || $debug;    
    &ReadDeviceOptions;
    return 0;
}

#
# Very very powerful converter: string -> Port instance
# the string can be iface or card+port format
#
sub convertPortFromString($;$)
{
    my ($str, $dev) = @_;

    if (ref($str) =~ /Port/) {
	return $str;
    }

    my $p = Port->LookupByIface($str);
    return $p if $p;

    $p = Port->LookupByTriple($str);
    return $p if $p;

    if (defined($dev)) {
	$p = Port->LookupByIface(Port->Tokens2IfaceString($dev, $str));
	return $p if $p;

	my ($card, $port) = Port->ParseCardPortString($str);
	if ($card) {
	    $p = Port->LookupByTriple(Port->Tokens2TripleString($dev, $card, $port));
	    return $p if $p;
	}
    } elsif ($str =~ /^(.+):(.+)$/) {
	my $node = $1;
	my $card = $2;

	my $result = DBQueryFatal("SELECT isswitch FROM node_types WHERE type IN ".
				  "(SELECT type FROM nodes WHERE node_id='$node')");

	#
	# Make sure this is not switch port
	#
	if ($result->numrows() != 1 || ($result->fetchrow())[0] != 1) {
	    #
	    # deal with old node:card format
	    #
	    $p = Port->LookupByTriple(Port->Tokens2TripleString($node, $card, "1"));
	    return $p if $p;
	}
    }

    return undef;			      
}

sub convertPortsFromStrings($@)
{
    my ($dev, @strs) = @_;

    return grep(defined($_), map(convertPortFromString($_, $dev), @strs)); 
}

#
# Deprecated
# Map between interfaces and mac addresses
#
sub macport { 
    return undef;
}

#
# Deprecated
# Map between node:iface and port numbers
#
sub portiface { 
    return undef;
}


#
# Deprecated
# Map between switch interfaces and port numbers
#
sub portnum {
    return undef;
}

#
# Deprecated
# Map between interfaces and the devices they are attached to
#
sub Dev { 
    return undef;
}

#
# Deprecated
# Map between ifaces and switch port
#
sub ifacemodport { 
    return undef;
}

#
# Get real ifaces on switch node in a VLAN that implements a path
# that consists of two layer 1 connections and also has a switch as
# the middle node.
#
sub getPathVlanIfaces($$) {
    my $vlanid = shift;
    my $ifaces = shift;

    my $vlan  = VLan->Lookup($vlanid);
    my $vname = $vlan->vname();
    my $experiment = $vlan->GetExperiment();
    my $pid = $experiment->pid();
    my $eid = $experiment->eid();
    
    my %ifacesonswitchnode = ();
    
    # find the underline path of the link
    my $query_result =
	DBQueryWarn("select distinct implemented_by_path from ".
		    "virt_lans where pid='$pid' and eid='$eid' ".
		    "          and vname='$vname'");
    if (!$query_result || !$query_result->numrows) {
	# Not an error since encapsulation vlans have generated names.
	%$ifaces = %ifacesonswitchnode;
	return 1;
    }

    # default implemented_by is empty
    my ($path) = $query_result->fetchrow_array();
    if (!defined($path) || $path eq "") {
	# Also not an error.
	%$ifaces = %ifacesonswitchnode;
	return 1;
    }

    # find the segments of the path
    $query_result = DBQueryWarn("select segmentname, segmentindex, layer from virt_paths ".
				"where pid='$pid' and eid='$eid' and pathname='$path';");
    if (!$query_result || !$query_result->numrows) {
	warn "Can't find path $path definition in DB.";
	return -1;
    }
    
    if ($query_result->numrows > 2) {
	my ($segname, $segindex, $layer) = $query_result->fetchrow();

	# only print warning msg when we are dealing with layer 1 links
	if ($layer == 1) {
	    warn "We can't handle the path with more than two segments.";
	}
	return -1;
    }
    
    my @vlans = ();
    VLan->ExperimentVLans($experiment, \@vlans);
    
    while (my ($segname, $segindex, $layer) = $query_result->fetchrow())
    {
	#
	# we only deal with layer 1 links
	#
	if ($layer != 1) {
	    return -1;
	}
	
	foreach my $myvlan (@vlans)
	{	    
	    if ($myvlan->vname eq $segname) {
		my @members;

		$vlan->MemberList(\@members);		
		foreach my $member (@members) {
		    my ($node,$iface);

		    $member->GetAttribute("node_id",  \$node);
		    $member->GetAttribute("iface", \$iface);

		    if ($myvlan->IsMember($node, $iface)) {
			my @pref;

			$myvlan->PortList(\@pref);

			# only two ports allowed in the vlan
			if (@pref != 2) {
			    warn "Vlan ".$myvlan->id()." doesnot have exact two ports.\n";
			    return -1;
			}
				       
			if ($pref[0] eq "$node:$iface") {
			    $ifacesonswitchnode{"$node:$iface"} = $pref[1];
			} else {
			    $ifacesonswitchnode{"$node:$iface"} = $pref[0];
			}
		    }
		}
	    }
	}
    }

    %$ifaces = %ifacesonswitchnode;
    return 0;
}


#
# Returns an array of ports (in node:card form) used by the given VLANs
#
sub getVlanPorts (@) { 
    my @vlans = @_;
    # Silently exit if they passed us no VLANs
    if (!@vlans) {
	return ();
    }
    my @ports = ();

    foreach my $vlanid (@vlans) {
	my $vlan = $vlanid;
	
	if (!ref($vlan)) {
	    $vlan = VLan->Lookup($vlanid);
	    if (!defined($vlan)) {
        	die("*** $0:\n".
		    "    No vlanid $vlanid in the DB!\n");
	    }
	}
    	my @members;
    	if ($vlan->MemberList(\@members) != 0) {
        	die("*** $0:\n".
		    "    Unable to load members for $vlan\n");
	}
	
	#
	# getPathVlanIfaces call removed because we've made
	# virtual ports and wires.
	#
	foreach my $member (@members) {
	    my $nodeid;
	    my $iface;
	    my $port;
	    my $trivial;
	    
	    if ($member->GetAttribute("node_id", \$nodeid) != 0 ||
		$member->GetAttribute("iface", \$iface) != 0) {
		die("*** $0:\n".
		    "    Missing attributes for $member in $vlan\n");
	    }
	    #
	    # A lan that is a mix of real ports and trivial ports, is type vlan
	    # (so it gets built on the switches), but will include those
	    # trivial ports in the member list, but they need to be ignored
	    # when operating on it as a vlan. libvtop sets this attribute when
	    # it happens, and we watch for it here, pruning out those trivial
	    # interfaces. A better way might be to remove them completely in
	    # libvtop, but thats a bigger change with more side effects.
	    #
	    next
		if ($member->GetAttribute("trivial", \$trivial) == 0);
	
	    $port = Port->LookupByIface($nodeid, $iface);
	    #
	    # Ports can be undef -- i.e., if this is a layer 2 path implemented
	    # by layer 1 wires, it hasn't been given a type yet.
	    #
	    if (defined($port)) {
		push(@ports, $port);
	    }
	}	
    }
    return @ports;
}

sub getExperimentTrunks($$@)
{
    my ($pid, $eid, @vlans) = @_;

    return getExperimentTrunksHelper(0, $pid, $eid, @vlans);
}

#
# Returns an an array of trunked ports (in node:card form) used by an
# experiment. These are ports that must be in trunk mode; whether they
# are currently *in* trunk mode is not relevant.
#
sub getExperimentTrunksHelper($$$@) {
    my ($current, $pid, $eid, @vlans) = @_;
    my %ports = ();

    # For debugging only.
    @vlans = getExperimentVlans($pid, $eid)
	if (!@vlans);

    my $experiment = Experiment->Lookup($pid, $eid);
    return undef
	if (!defined($experiment));

    #
    # We want to restrict the set of ports to just those in the
    # provided vlans, lest we get into a problem with a missing device from
    # the stack. This became necessary after adding shared vlans, since
    # those ports technically belong to the current experiment, but are
    # setup in the context of a different experiment.
    #
    # Consider these different setups.
    # 1. Normal:
    #    The vlans and the ports belong to the experiment in question.
    # 2. Shared Nodes:
    #    There is a base vlan (dual mode) for the shared node experiment
    #    and all of the ports belong to that experiment. That vlan is setup
    #    at the beginning of time when swapping in the shared node
    #    experiment. When experiments that use the shared nodes are
    #    swapped, we never want to touch the port trunk mode, just add
    #    vlans to those ports since they will already be tagged.
    #    NOTE: Fake nodes (like ion) are also considered shared nodes,
    #    but in a different holding experiment. 
    # 3. Shared vlans:
    #    These vlans exist in a holding experiment, but the ports that we
    #    put into those vlans belong to nodes in other experiments.
    #    Basically the reverse of the situation above with shared nodes.
    #    We run snmpit in the context of the holding experiment, and so the
    #    ports we want to trunk belong to another experiment. See, exactly
    #    the opposite of above. Ick.
    #    NOTE: If we a shared vlan is being used by a shared node, we
    #    do not want to mess with trunk mode on those ports.
    #
    # So the cases are:
    # 1. Swapin/Swapout normal experiment.
    # 2. Swapin/Swapout the shared node experiment.
    # 3. Swapin/Swapout experiments using shared nodes.
    # 4. Swapin/Swapout experiments using shared vlans.
    # 5. Swapin/Swapout experiments using shared nodes AND shared vlans.
    #
    # Remember, for 4 that we run snmpit in the context of the holding
    # experiment that owns the shared vlan. AND we run snmpit in the
    # context of the experiment swaping.
    #
    # So we have to check each node (its ports) in a vlan against the
    # current experiment. We skip those ports that do not belong to it if
    # the experiment they belong to is a shared node holding experiment).
    # We can determine this by looking in the reserved table for the node.
    # A physical node is a shared host and a virtual node is a shared node.
    # But if the port does not belong to it, is a shared vlan port, and
    # not a shared node port, we have to trunk/untrunk it!
    # 
    foreach my $vlanid (@vlans) {
	# Allow vlan list to be vlan objects.
	$vlanid = $vlanid->id()
	    if (ref($vlanid));

	my @vlanports =
	    ($current ? getExperimentVlanPorts($vlanid) :getVlanPorts($vlanid));
	
	foreach my $port (@vlanports) {
	    next
		if (!$port->trunk());

	    my $node = Node->Lookup($port->node_id());
	    if (!defined($node)) {
		print STDERR "*** getExperimentTrunks: ".
		    "*** No such node for $port\n";
		next;
	    }
	    my $reservation = $node->Reservation();
	    if (!defined($reservation)) {
		print STDERR "*** getExperimentTrunks: ".
		    "$node is not reserved!\n";
		next;
	    }

	    #
	    # Case #1 and #2.
	    #
	    if ($experiment->SameExperiment($reservation)) {
		$ports{$port->toString()} = $port;
		next;
	    }
	    #
	    # Case #3; skip ports belonging to a shared physical host.
	    # They are already in trunk mode and should be left alone,
	    # or we risk losing all of the vlans that port is tagged on. 
	    #
	    # XXX Sanity check to make sure?
	    #
	    next
		if ($node->sharing_mode());
	    
	    #
	    # Case #4: Running snmpit on a shared vlan, all ports belong
	    # to other experiments, they are need to be trunked, and we
	    # know from case #3 above that they are not shared hosts.
	    #
	    my $query_result =
		DBQueryFatal("select lanid from shared_vlans ".
			     "where lanid='$vlanid'");
	    if ($query_result->numrows) {
		$ports{$port->toString()} = $port;
		next;
	    }
	    print STDERR "*** getExperimentTrunks: ".
		"Do not know trunk mode for $port in $vlanid!\n";
	}
    }
    return %ports;
}

#
# Returns an an array of trunked ports (in node:card form) used by an
# experiment. These are the ports that are actually in trunk mode,
# rather then the ports we want to be in trunk mode (above function).
#
sub getExperimentCurrentTrunks($$@) {
    my ($pid, $eid, @vlans) = @_;
    my %ports = ();
    
    #
    # Get all of the ports we are allowed to act on from above function.
    #
    my %allports = getExperimentTrunksHelper(1, $pid, $eid, @vlans);

    #
    # Check which of these ports is actually in trunk mode. 
    #
    foreach my $key (keys(%allports)) {
	my $port    = $allports{$key};
	my $node_id = $port->node_id();
	my $iface   = $port->iface();
	
	my $query_result =
	    DBQueryFatal("select tagged from interface_state ".
			 "where node_id='$node_id' and iface='$iface' and ".
			 "      tagged!=0");

	next
	    if (! $query_result->numrows);

	$ports{$key} = $port;
    }
    return %ports;
}

#
# Returns an an array of ports that currently in
# the given vlan.
#
sub getExperimentVlanPorts($) { 
    my ($vlanid) = @_;

    my $query_result =
	DBQueryFatal("select members from vlans as v ".
		     "where v.id='$vlanid'");
    return ()
	if (!$query_result->numrows());

    my ($members) = $query_result->fetchrow_array();
    my @members   = split(/\s+/, $members);

    return Port->LookupByIfaces(@members); 
}

#
# Get the list of stacks that the given set of VLANs *will* or *should* exist
# on
#
sub getPlannedStacksForVlans(@) { 
    my @vlans = @_;

    # Get VLAN members, then go from there to devices, then from there to
    # stacks
    my @ports = getVlanPorts(@vlans);
    if ($debug) {
        print "getPlannedStacksForVlans: got ports " . Port->toStrings(@ports) . "\n";
    }
    my @devices = getDeviceNames(@ports);
    if ($debug) {
        print("getPlannedStacksForVlans: got devices " . join(",",@devices)
            . "\n");
    }
    my @stacks = getStacksForSwitches(@devices);
    if ($debug) {
        print("getPlannedStacksForVlans: got stacks " . join(",",@stacks) . "\n");
    }
    return @stacks;
}

#
# Filter a set of vlans by devices; return only those vlans that exist
# on the set of provided stacks. Do not worry about vlans that cross
# stacks; that is caught higher up.
#
sub filterVlansBySwitches($@) {
    my ($devref, @vlans) = @_;
    my @result   = ();
    my %devices  = ();

    if ($debug) {
	print("filterVlansBySwitches: " . join(",", @{ $devref }) . "\n");
    }

    foreach my $device (@{ $devref }) {
	$devices{$device} = $device;
    }
    
    foreach my $vlanid (@vlans) {
	my @ports = getVlanPorts($vlanid);
	if ($debug) {
	    print("filterVlansBySwitches: ".
		  "ports for $vlanid: " . Port->toStrings(@ports) . "\n");
	}
	my @tmp = getDeviceNames(@ports);
	if ($debug) {
	    print("filterVlansBySwitches: ".
		  "devices for $vlanid: " . join(",",@tmp) . "\n");
	}
	foreach my $device (@tmp) {
	    if (exists($devices{$device})) {
		push(@result, $vlanid);
		last;
	    }
	}
    }
    return @result;
}

#
# Get the list of stacks that the given VLANs actually occupy
#
sub getActualStacksForVlans(@) {
    my @vlans = @_;

    # Run through all the VLANs and make a list of the stacks they
    # use
    my @stacks;
    foreach my $vlan (@vlans) {
        my ($vlanobj, $stack);
        if ($debug) {
            print("getActualStacksForVlans: looking up ($vlan)\n");
        }
        if (defined($vlanobj = VLan->Lookup($vlan)) &&
            defined($stack = $vlanobj->GetStack())) {

            if ($debug) {
                print("getActualStacksForVlans: found stack $stack in database\n");
            }
            push @stacks, $stack;
        }
    }
    return uniq(@stacks);
}

#
# Ditto for stack that VLAN exists on
#
sub setVlanStack($$) {
    my ($vlan_id, $stack_id) = @_;
    
    my $vlan = VLan->Lookup($vlan_id);
    return ()
	if (!defined($vlan));
    return ()
	if ($vlan->SetStack($stack_id) != 0);

    return 0;
}

#
# Update database to reserve a vlan tag. The tables will be locked to
# make sure we can get it. 
#
sub reserveVlanTag ($$) {
    my ($vlan_id, $tag) = @_;
    
    if (!$vlan_id || !defined($tag)) {
	return 0;
    }

    my $vlan = VLan->Lookup($vlan_id);
    return 0
	if (!defined($vlan));

    return $vlan->ReserveVlanTag($tag);
}

sub clearReservedVlanTag ($) {
    my ($vlan_id) = @_;
    
    my $vlan = VLan->Lookup($vlan_id);
    return -1
	if (!defined($vlan));

    return $vlan->ClearReservedVlanTag();
}

sub getReservedVlanTag ($) {
    my ($vlan_id) = @_;

    my $vlan = VLan->Lookup($vlan_id);
    return 0
	if (!defined($vlan));

    return $vlan->GetReservedVlanTag();
}

#
# Given a list of VLANs, return only the VLANs that are beleived to actually
# exist on the switches
#
sub filterPlannedVlans(@) {
    my @vlans = @_;
    my @out;
    foreach my $vlan (@vlans) {
        my $vlanobj = VLan->Lookup($vlan);
        if (!defined($vlanobj)) {
            warn "snmpit: Warning, tried to check status of non-existant " .
                "VLAN $vlan\n";
            next;
        }
        if ($vlanobj->CreatedOnSwitches()) {
            push @out, $vlan;
        }
    }
    return @out;
}

#
# Update database to mark port as enabled or disabled.
#
sub setPortEnabled($$) { 
    my ($port, $enabled) = @_;

    my ($node, $iface) = ($port->node_id(), $port->iface());
    $enabled = ($enabled ? 1 : 0);

    DBQueryFatal("update interface_state set enabled=$enabled ".
		 "where node_id='$node' and iface='$iface'");
    
    return 0;
}

# Ditto for trunked.
sub setPortTagged($$) { 
    my ($port, $tagged) = @_;

    my ($node, $iface) = ($port->node_id(), $port->iface());
    $tagged = ($tagged ? 1 : 0);

    DBQueryFatal("update interface_state set tagged=$tagged ".
		 "where node_id='$node' and iface='$iface'");
}

# Ditto for trunked.
sub IsPortTagged($) { 
    my ($port) = @_;

    my ($node, $iface) = ($port->node_id(), $port->iface());

    my $query_result =
	DBQueryFatal("select tagged from interface_state ".
		     "where node_id='$node' and iface='$iface' and tagged!=0");
    
    return $query_result->numrows();
}

#                                                                                    
# If a port is on switch, some port ops in snmpit                                    
# should be avoided.                                                                 
#                                                                                    
sub isSwitchPort($) {
	my $port = shift;

	my $node = $port->node_id();	
	my $result = DBQueryFatal("SELECT isswitch FROM node_types WHERE type IN ".
				  "(SELECT type FROM nodes WHERE node_id='$node')");
				  
	if ($result->numrows() != 1) {
	    return 0;
	}
	
	if (($result->fetchrow())[0] == 1) {
	    return 1;
	}

	return 0;
}

#
# Returns an array of all VLAN id's used by a given experiment.
# Optional list of vlan ids restricts operation to just those vlans,
#
sub getExperimentVlans ($$@) {
    my ($pid, $eid, @optvlans) = @_;

    my $experiment = Experiment->Lookup($pid, $eid);
    if (!defined($experiment)) {
	die("*** $0:\n".
	    "    getExperimentVlans($pid,$eid) - no such experiment\n");
    }
    my @vlans;
    if (VLan->ExperimentVLans($experiment, \@vlans) != 0) {
	die("*** $0:\n".
	    "    Unable to load VLANs for $experiment\n");
    }

    # Convert to how the rest of snmpit wants to see this stuff.
    my @result = ();
    foreach my $vlan (@vlans) {
	push(@result, $vlan->id())
	    if (!@optvlans || grep {$_ == $vlan->id()} @optvlans);
    }
    return @result;
}

#
# Returns an array of all ports used by a given experiment
#
sub getExperimentPorts ($$) {
    my ($pid, $eid) = @_;

    return getVlanPorts(getExperimentVlans($pid,$eid));
}

#
# Returns all ports for a vlan, from lans and from vlans.
# Cause of syncVlansFromTables ...
#
sub getAllVlanPorts($)
{
    my ($vlan_id) = @_;
    my @ports    = ();

    if (VLan->Lookup($vlan_id)) {
	@ports = uniq_ports(getVlanPorts($vlan_id),
			    getExperimentVlanPorts($vlan_id));
    }
    else {
	@ports = getExperimentVlanPorts($vlan_id);
    }
    return @ports;
}

#
# Returns an array of control net ports used by a given experiment
#
sub getExperimentControlPorts ($$) {
    my ($pid, $eid) = @_;

    # 
    # Get a list of all *physical* nodes in the experiment
    #
    my $exp = Experiment->Lookup($pid,$eid);
    my @nodes = $exp->NodeList(0,0);
    # plab and related nodes are still in the list, so filter them out
    @nodes = grep {$_->control_iface()} @nodes; 

    #
    # Get control net interfaces
    #
    my @ports = map { Port->LookupByIface($_->node_id(), $_->control_iface()) } @nodes;

    #
    # Convert from iface to port number when we return
    #
    return @ports; 
}

#
# Usage: getDeviceNames(@ports)
#
# Returns an array of the names of all devices used in the given ports
#
sub getDeviceNames(@) { 
    my @ports = @_;
    my %devices = ();
    foreach my $port (@ports) {
	if (!defined($port)) {
	    die("getDeviceNames: undefined port");
	}
	my $device = $port->switch_node_id();

	$devices{$device} = 1;

        if ($debug) {
            print "getDevicesNames: Mapping ".$port->toTripleString()." to $device\n";
        }
    }
    return (sort {tbsort($a,$b)} keys %devices);
}

#
# Returns a hash, keyed by device, of all ports in the given list that are
# on that device
#
sub mapPortsToDevices(@) { 
    my @ports = @_;
    my %map = ();
    foreach my $port (@ports) {
	my ($device) = getDeviceNames($port);
	if (defined($device)) { # getDeviceNames does the job of warning users
	    push @{$map{$device}},$port;
	}
    }
    return %map;
}

#
# Returns the device type for the given node_id
#
sub getDeviceType ($) {

    my ($node) = @_;

    my $result =
	DBQueryFatal("SELECT type FROM nodes WHERE node_id='$node'");

    my @row = $result->fetchrow();
    # Sanity check - make sure the node exists
    if (!@row) {
	die "No such node: $node\n";
    }

    return $row[0];
}

#
# Returns (current_speed,duplex) for the given interface (in node:port form)
#
sub getInterfaceSettings ($) { 

    my ($interface) = @_;

    #
    # Switch ports are evil and we don't touch them.
    #
    if (isSwitchPort($interface)) {
	return ();
    }
    
    my $node  = $interface->node_id();
    my $iface = $interface->iface();

    my $result =
	DBQueryFatal("SELECT i.current_speed,i.duplex,".
		     "       i.noportcontrol,ic.capval ".
		     "  FROM interfaces as i " .
		     "left join interface_capabilities as ic on ".
		     "     ic.type=i.interface_type and ".
		     "     capkey='noportcontrol' ".
		     "WHERE i.node_id='$node' and i.iface='$iface' ");

    # Sanity check - make sure the interface exists
    if ($result->numrows() != 1) {
	die "No such interface: ".$interface->toString()."\n";
    }
    my ($speed,$duplex,$noportcontrol,$noportcontrolcap) =
	$result->fetchrow_array();

    # If the port does not support portcontrol, ignore it.
    if ($noportcontrol ||
	(defined($noportcontrolcap) && $noportcontrolcap)) {
	return ();
    }
    return ($speed,$duplex);
}

#
# Returns an array with then names of all switches identified as test switches
#
sub getTestSwitches () {
    my $result =
	DBQueryFatal("SELECT node_id FROM nodes WHERE role='testswitch'");
    my @switches = (); 
    while (my @row = $result->fetchrow()) {
	my $node = Node->Lookup($row[0]);
	my $disabled;
	$node->NodeAttribute("snmpit_disable", \$disabled);
	if (! defined($disabled) || !$disabled) {
	    push @switches, $row[0];
	}
    }

    return @switches;
}

#
# Returns an array with the names of all switches identified as control switches
#
sub getControlSwitches () {
    my $result =
	DBQueryFatal("SELECT node_id FROM nodes WHERE role='ctrlswitch'");
    my @switches = (); 
    while (my @row = $result->fetchrow()) {
	push @switches, $row[0];
    }

    return @switches;
}

#
# Returns an array with the names of all switches in the given stack
#
sub getSwitchesInStack ($) {
    my ($stack_id) = @_;
    my $result = DBQueryFatal("SELECT node_id FROM switch_stacks " .
	"WHERE stack_id='$stack_id'");
    my @switches = (); 
    while (my @row = $result->fetchrow()) {
	push @switches, $row[0];
    }

    return @switches;
}

#
# Returns an array with the names of all switches in the given *stacks*, with
# no switches duplicated
#
sub getSwitchesInStacks (@) {
    my @stack_ids = @_;
    my @switches;
    foreach my $stack_id (@stack_ids) {
        push @switches, getSwitchesInStack($stack_id);
    }

    return uniq(@switches);
}

#
# Returns the stack_id of a switch's primary stack
#
sub getSwitchPrimaryStack($) {
    my $switch = shift;
    my $result = DBQueryFatal("SELECT stack_id FROM switch_stacks WHERE " .
    		"node_id='$switch' and is_primary=1");
    if (!$result->numrows()) {
	print STDERR "No primary stack_id found for switch $switch\n"
	    if ($debug);
	return undef;
    } elsif ($result->numrows() > 1) {
	print STDERR "Switch $switch is marked as primary in more than one " .
	    "stack\n";
	return undef;
    } else {
	my ($stack_id) = ($result->fetchrow());
	return $stack_id;
    }
}

#
# Returns the stack_ids of the primary stacks for the given switches.
# Surpresses duplicates.
#
sub getStacksForSwitches(@) {
    my (@switches) = @_;
    my @stacks;
    foreach my $switch (@switches) {
        push @stacks, getSwitchPrimaryStack($switch);
    }

    return uniq(@stacks);
}

#
# Returns a list of all stack_ids that a switch belongs to
#
sub getSwitchStacks($) {
    my $switch = shift;
    my $result = DBQueryFatal("SELECT stack_id FROM switch_stacks WHERE " .
    		"node_id='$switch'");
    if (!$result->numrows()) {
	print STDERR "No stack_id found for switch $switch\n";
	return undef;
    } else {
	my @stack_ids;
	while (my ($stack_id) = ($result->fetchrow())) {
	    push @stack_ids, $stack_id;
	}
	return @stack_ids;
    }
}

#
# Returns the type of the given stack_id. If called in list context, also
# returns whether or not the stack supports private VLANs, whether it
# uses a single VLAN domain, and the SNMP community to use.
#
sub getStackType($) {
    my $stack = shift;
    my $result = DBQueryFatal("SELECT stack_type, supports_private, " .
	"single_domain, snmp_community FROM switch_stack_types " .
	"WHERE stack_id='$stack'");
    if (!$result->numrows()) {
	print STDERR "No stack found called $stack\n";
	return undef;
    } else {
	my ($stack_type,$supports_private,$single_domain,$community)
	    = ($result->fetchrow());
	if (defined wantarray) {
	    return ($stack_type,$supports_private,$single_domain, $community);
	} else {
	    return $stack_type;
	}
    }
}

#
# Returns the leader for the given stack - the meaning of this is vendor-
# specific. May be undefined.
#
sub getStackLeader($) {
    my $stack = shift;
    my $result = DBQueryFatal("SELECT leader FROM switch_stack_types " .
	"WHERE stack_id='$stack'");
    if (!$result->numrows()) {
	print STDERR "No stack found called $stack\n";
	return undef;
    } else {
	my ($leader) = ($result->fetchrow());
	return $leader;
    }
}

#
# Get a hash that describes the configuration options for a switch. The idea is
# that the device's object will call this method to get some options.  Right
# now, all this stuff actually comes from the stack, but there could be
# switch-specific configuration in the future. Provides defaults for NULL
# columns
#
# We could probably make this look more like an object, for type checking, but
# that just doesn't seem necessary yet.
#
sub getDeviceOptions($) {
    my $switch = shift;
    my %options;

    if (my $cached_options = $DeviceOptions{$switch}) {
	return $cached_options;
    }
    my $result = DBQueryFatal("SELECT supports_private, " .
	"single_domain, s.snmp_community as device_community, ".
        "t.min_vlan, t.max_vlan, " .
	"t.snmp_community as stack_community, ".
	"s.min_vlan as device_min, s.max_vlan as device_max ".
	"FROM switch_stacks AS s left join switch_stack_types AS t " .
	"    ON s.stack_id = t.stack_id ".
	"WHERE s.node_id='$switch'");

    if (!$result->numrows()) {
	print STDERR "No switch $switch found, or it is not in a stack\n";
	return undef;
    }

    my ($supports_private, $single_domain, $device_community, $min_vlan,
	$max_vlan, $stack_community, $device_min, $device_max) =
	    $result->fetchrow();

    $options{'supports_private'} = $supports_private;
    $options{'single_domain'} = $single_domain;
    $options{'snmp_community'} =
 	$device_community || $stack_community || "public";
    $options{'min_vlan'} = $device_min || $min_vlan || 2;
    $options{'max_vlan'} = $device_max || $max_vlan || 1000;

    my $type = $options{'type'} = getDeviceType($switch);

    my $q = "(select \"default\" source, attrkey, attrvalue from ".
	    "node_type_attributes where type='$type' ".
	    "and attrkey like 'snmpit%') union ".
	    "(select \"override\" source, attrkey, attrvalue from ".
	    "node_attributes where node_id='$switch' ".
	    "and attrkey like 'snmpit%') order by source";
	   
    $result = DBQuery($q);
    if ($result && $result->numrows()) {
	while (my ($source, $key, $value) = $result->fetchrow()) {
		$key =~ s/^snmpit_//;
		$options{$key} = $value;
	}
    }
    $DeviceOptions{$switch} = \%options;

    if ($debug) {
	print "Options for $switch:\n";
	while (my ($key,$value) = each %options) {
	    # let's not willingly spit out authentication info
	    if ($key =~ /^(snmp_community|username|password)$/) {
		$value = "<hidden>";
	    }
	    $value = "undef"
		if (!defined($value));
	    print "$key = $value\n"
	}
    }

    return \%options;
}

sub ReadDeviceOptions() {
    my $result = DBQuery("select distinct node_id from switch_stacks");
    print STDERR "No switch found in any stack\n"
	unless ($result && $result->numrows());
    while (my ($switch) = $result->fetchrow()) { getDeviceOptions($switch); }
}

#
# Returns a structure representing all trunk links. It's a hash, keyed by
# switch, that contains hash references. Each of the second level hashes
# is keyed by destination, with the value being an array reference that
# contains the card.port pairs to which the trunk is conencted. For exammple,
# ('cisco1' => { 'cisco3' => ['1.1','1.2'] },
#  'cisco3' => { 'cisco1' => ['2.1','2.2'] } )
#
# After port refactoring:
# ( 'src' => { 'dst' => [ port1, port2 ] }, ... )
#
sub getTrunks() {

    my %trunks = ();
    
    my @ports = Port->LookupByWireType("Trunk");
    
    foreach my $p (@ports) {
	    push @{ $trunks{$p->node_id()}{$p->other_end_node_id()} }, $p;
    }

    return %trunks;
	
}

#
# Find the best path from one switch to another. Returns an empty list if no
# path exists, otherwise returns a list of switch names. Arguments are:
# A reference to a hash, as returned by the getTrunks() function
# A reference to an array of unvisited switches: Use [keys %trunks]
# Two siwtch names, the source and the destination 
#
sub getTrunkPath($$$$) {
    my ($trunks, $unvisited, $src,$dst) = @_;
    if ($src eq $dst) {
	#
	# The source and destination are the same
	#
	return ($src);
    } elsif ($trunks->{$src}{$dst}) {
	#
	# The source and destination are directly connected
	#
	return ($src,$dst);
    } else {
	# The source and destination aren't directly connected. We'll need to 
	# recurse across other trunks to find solution
	my @minPath = ();

	#
	# We use the @$unvisited list to pick switches to traverse to, so
	# that we don't re-visit switches we've already been to, which would 
	# cause infinite recursion
	#
	foreach my $i (0 .. $#{$unvisited}) {
	    if ($trunks->{$src}{$$unvisited[$i]}) {

		#
		# We need to pull theswitch out of the unvisted list that we
		# pass to it.
		#
		my @list = @$unvisited;
		splice(@list,$i,1);

		#
		# Check to see if the path we get with this switch is the 
		# best one found so far
		#
		my @path = getTrunkPath($trunks,\@list,$$unvisited[$i],$dst);
		if (@path && ((!@minPath) || (@path < @minPath))) {
		    @minPath = @path;
		}
	    }

	}

	#
	# If we found a path, tack ourselves on the front and return. If not,
	# return the empty list of failure.
	#
	if (@minPath) {
	    return ($src,@minPath);
	} else {
	    return ();
	}
    }
}

#
# This is a replacement for getTrunksFromSwitches, used by the stack
# module.  The idea is to use the path in the DB, as computed by
# assign. Fall back to old method method if no path defined in the DB.
# We need the switches in case we fall back, otherwise we do what
# the DB says (as computed by assign), ignoring the switches. 
#
sub getTrunksForVlan($@)
{
    my ($vlan_id, @switches) = @_;
    my %trunks = getTrunks();
    
    my $vlan = VLan->Lookup($vlan_id);
    return ()
	if (!defined($vlan));

    if ($debug) {
	print STDERR "getTrunksForVlan: $vlan_id: @switches\n";
    }
    
    #
    # We want to use the path that is in the DB.
    #
    my $path = $vlan->GetSwitchPath();
    if (!defined($path) || $path eq "") {
	#
	# Nothing defined in the DB, so fall back to old method.
	#
	# One switch, cannot be a path.
	# 
	return ()
	    if (scalar(@switches) < 2);
	
	my @trunks = getTrunksFromSwitches(\%trunks, @switches);

	#
	# Now form a spanning tree to ensure there are no loops.
	#
	@trunks = SpanningTree(\@trunks);

	if ($debug) {
	    print STDERR " old style path: " .
		join(" ", map { join(":", @$_) } @trunks) . "\n";
	}
	return @trunks;
    }
    print STDERR " DB path: $path\n" if ($debug);
    my @path = ();
    foreach my $p (split(" ", $path)) {
	my ($a,$b) = split(":", $p);
	if (!exists($trunks{$a})) {
	    print STDERR "No trunk entry for $a\n";
	    next;
	}
	if (!exists($trunks{$a}->{$b})) {
	    print STDERR "No trunk entry for $a:$b\n";
	    next;
	}
	push(@path, [$a, $b]);
    }
    if (@path && $debug) {
	print STDERR " new style path: ".
	    join(" ", map { join(":", @$_) } @path) . "\n";
    }
    return @path;
}

#
# Same as above, only we want the recorded switch path from vlans table,
# since this might be a swapmod and the contents of the lans table is
# not how things are now, but how they will be later. 
#
sub getExperimentTrunksForVlan($@)
{
    my ($vlan_id, @switches) = @_;
    my %trunks = getTrunks();
    
    my $vlan = VLan->Lookup($vlan_id);
    return ()
	if (!defined($vlan));

    if ($debug) {
	print STDERR "getExperimentTrunksForVlan: $vlan_id: @switches\n";
    }

    #
    # We want to use the path that is in the DB.
    #
    my $path = $vlan->GetVlanSwitchPath();
    if (!defined($path) || $path eq "") {
	#
	# Nothing defined in the DB, so fall back to old method.
	#
	# One switch, cannot be a path.
	# 
	return ()
	    if (scalar(@switches) < 2);
	
	my @trunks = getTrunksFromSwitches(\%trunks, @switches);

	#
	# Now form a spanning tree to ensure there are no loops.
	#
	@trunks = SpanningTree(\@trunks);

	if ($debug) {
	    print STDERR " old style path: " .
		join(" ", map { join(":", @$_) } @trunks) . "\n";
	}
	return @trunks;
    }
    print STDERR " DB path: $path\n" if ($debug);
    my @path = ();
    foreach my $p (split(" ", $path)) {
	my ($a,$b) = split(":", $p);
	if (!exists($trunks{$a})) {
	    print STDERR "No trunk entry for $a\n";
	    next;
	}
	if (!exists($trunks{$a}->{$b})) {
	    print STDERR "No trunk entry for $a:$b\n";
	    next;
	}
	push(@path, [$a, $b]);
    }
    if (@path && $debug) {
	print STDERR " new style path: ".
	    join(" ", map { join(":", @$_) } @path) . "\n";
    }
    return @path;
}

#
# Given a set of vlans, determine *exactly* what devices are needed
# for the ports and any trunks that need to be crossed. This is done
# in the stack module, but really want to do this before the stack
# is created so that we do not add extra devices if not needed.
#
sub mapVlansToSwitches(@)
{
    my @vlan_ids = @_;
    my %switches = ();

    #
    # This code is lifted from setPortVlan() in snmpit_stack.pm
    #
    foreach my $vlan_id (@vlan_ids) {
	my @ports   = uniq_ports(getVlanPorts($vlan_id),
				 getExperimentVlanPorts($vlan_id));
	my %map     = mapPortsToDevices(@ports);

	#
	# Initial set of switches.
	#
	foreach my $switch (keys(%map)) {
	    $switches{$switch} = 1;
	}

	#
	# We want to use the DB path if it exists.
	#
	my @trunks = getTrunksForVlan($vlan_id, keys(%map));

	# And update the total set of switches.
	foreach my $trunk (@trunks) {
	    my ($src,$dst) = @$trunk;
	    $switches{$src} = $switches{$dst} = 1;
	}
    }
    my @sorted = sort {tbsort($a,$b)} keys %switches;
    print "mapVlansToSwitches: @sorted\n" if ($debug);
    return @sorted;
}

#
# An alternate version for a "stale" vlan; one that is destroyed cause of
# a swapmod (syncVlansFromTables). 
#
sub mapStaleVlansToSwitches(@)
{
    my @vlan_ids = @_;
    my %switches = ();

    foreach my $vlan_id (@vlan_ids) {
	#
	# Get the ports that we think are already in the vlan, since
	# this might be a remove/modify operation. Can probably optimize
	# this. 
	#
	my @ports   = getExperimentVlanPorts($vlan_id);
	my %map     = mapPortsToDevices(@ports);

	#
	# Initial set of switches.
	#
	foreach my $switch (keys(%map)) {
	    $switches{$switch} = 1;
	}

	#
	# We want to use the DB path if it exists.
	#
	my @trunks = getExperimentTrunksForVlan($vlan_id, keys(%map));

	# And update the total set of switches.
	foreach my $trunk (@trunks) {
	    my ($src,$dst) = @$trunk;
	    $switches{$src} = $switches{$dst} = 1;
	}
    }
    my @sorted = sort {tbsort($a,$b)} keys %switches;
    print "mapStaleVlansToSwitches: @sorted\n" if ($debug);
    return @sorted;
}

#
# Map a set of ports to the devices they are on plus the trunks.
# See above.
#
sub mapPortsToSwitches(@)
{
    my @ports    = @_;
    my %switches = ();
    my %trunks   = getTrunks();
    my %map      = mapPortsToDevices(@ports);
    my %devices  = ();

    #
    # Watch for one device, no trunks to worry about.
    #
    return (keys(%map))
	if (scalar(keys(%map)) == 1);
    
    foreach my $device (keys %map) {
	$devices{$device} = 1;
    }

    #
    # This code is lifted from setPortVlan() in snmpit_stack.pm
    #
    # Find every switch which might have to transit this VLAN through
    # its trunks.
    #
    my @trunks = getTrunksFromSwitches(\%trunks, keys %devices);

    #
    # Now form a spanning tree to ensure there are no loops.
    #
    @trunks = SpanningTree(\@trunks);
    
    foreach my $trunk (@trunks) {
	my ($src,$dst) = @$trunk;
	$devices{$src} = $devices{$dst} = 1;
    }
    # And update the total set of switches.
    foreach my $device (keys(%devices)) {
	$switches{$device} = 1;
    }
    my @sorted = sort {tbsort($a,$b)} keys %switches;
    return @sorted;
}

#
# Calc a new switch trunk path from the current set of devices.
#
sub getSwitchTrunkPath($)
{
    my ($vlan) = @_;
    my %switches = ();

    my @ports   = getVlanPorts($vlan->lanid());
    my %map     = mapPortsToDevices(@ports);
    my @trunks  = getTrunksForVlan($vlan->lanid(), keys(%map));

    return join(" ", map { join(":", @$_) } @trunks);
}

sub setSwitchTrunkPath($)
{
    my ($vlan) = @_;

    return $vlan->SetSwitchPath(getSwitchTrunkPath($vlan));
}

#
# Returns a list of trunks, in the form [src, dest], from a path (as returned
# by getTrunkPath() ). For example, if the input is:
# (cisco1, cisco3, cisco4), the return value is:
# ([cisco1, cisco3], [cisco3, cisco4])
#
sub getTrunksFromPath(@) { 
    my @path = @_;
    my @trunks = ();
    my $lastswitch = "";
    foreach my $switch (@path) {
	if ($lastswitch) {
	    push @trunks, [$lastswitch, $switch];
	}
	$lastswitch = $switch;
    }

    return @trunks;
}

#
# Given a list of lists of trunks (returned by multiple getTrunksFromPath() 
# calls), return a list of the unique trunks found in this list
#
sub getUniqueTrunks(@) { 
    my @trunkLists = @_;
    my @unique = ();
    foreach my $trunkref (@trunkLists) {
	my @trunks = @$trunkref;
	TRUNK: foreach my $trunk (@trunks) {
	    # Since source and destination are interchangable, we have to
	    # check both possible orderings
	    foreach my $unique (@unique) {
		if ((($unique->[0] eq $trunk->[0]) &&
		     ($unique->[1] eq $trunk->[1])) ||
		    (($unique->[0] eq $trunk->[1]) &&
		     ($unique->[1] eq $trunk->[0]))) {
			 # Yep, it's already in the list - go to the next one
			 next TRUNK;
		}
	    }

	    # Made it through, we must not have seen this one before
	    push @unique, $trunk;
	}
    }

    return @unique;
}

#
# Given a trunk structure (as returned by getTrunks() ), and a list of switches,
# return a list of all trunks (in the [src, dest] form) that are needed to span
# all the switches (ie. which trunks the VLAN must be allowed on)
#
sub getTrunksFromSwitches($@) { 
    my $trunks = shift;
    my @switches = @_;

    #
    # First, find the paths between each set of switches
    #
    my @paths = ();
    foreach my $switch1 (@switches) {
	foreach my $switch2 (@switches) {
	    push @paths, [ getTrunkPath($trunks, [ keys %$trunks ],
					$switch1, $switch2) ];
	}
    }

    #
    # Now, make a list of all the the trunks used by these paths
    #
    my @trunkList = ();
    foreach my $path (@paths) {
	push @trunkList, [ getTrunksFromPath(@$path) ];
    }

    #
    # Remove any duplicates from the list of trunks
    #
    my @trunks = getUniqueTrunks(@trunkList);

    return @trunks;
}

#
# Make a hash of all trunk ports for easy checking - the keys into the hash are
# in the form "switch/mod.port" - the contents are 1 if the port belongs to a
# trunk, and undef if not
#
# ('cisco1' => { 'cisco3' => ['1.1','1.2'] },
#  'cisco3' => { 'cisco1' => ['2.1','2.2'] } )
#
sub getTrunkHash() { 
    my %trunks = getTrunks();
    my %trunkhash = ();
    foreach my $switch1 (keys %trunks) {
        foreach my $switch2 (keys %{$trunks{$switch1}}) {
            foreach my $port (@{$trunks{$switch1}{$switch2}}) {
                # XXX backward compat
                my $portstr = "$switch1/".$port->card().".".$port->port();
                $trunkhash{$portstr} = 1;
            }
        }
    }
    return %trunkhash;
}

#
# Look for trunked stitch ports.
#
sub getTrunkedStitchPorts()
{
    my @stitchPorts = ();

    #
    # Use the external interfaces table. We are looking for those
    # ports with the LAG flag set. 
    #
    my $query_result =
	DBQueryWarn("select n.node_id,w.iface1 from external_networks as n ".
		    "left join wires as w on ".
		    "     w.node_id1=n.node_id ".
		    "left join interfaces as i on ".
		    "     i.node_id=w.node_id2 and i.iface=w.iface2 ".
		    "where i.LAG=1");
    return ()
	if (!$query_result->numrows);

    while (my ($node_id,$iface) = $query_result->fetchrow_array()) {
	my $port = Port->LookupByIface($node_id, $iface);
	if (!$port) {
	    print STDERR "Could not get Port for $node_id:$iface\n";
	    return ();
	}
	push(@stitchPorts, $port);
    }
    return @stitchPorts;
}

#
# Execute and SNMP command, retrying in case there are transient errors.
#
# usage: snmpitDoIt(getOrSet, session, var, [retries])
# args:  getOrSet - either $SNMPIT_GET or $SNMPIT_SET
#        session - SNMP::Session object, already connected to the SNMP
#                  device
#        var     - An SNMP::Varbind or a reference to a two-element array
#                  (similar to a single Varbind)
#        retries - Number of times to retry in case of failure
# returns: the value on sucess, undef on failure
#
sub snmpitDoIt($$$;$) {

    my ($getOrSet,$sess,$var,$retries) = @_;

    if (! defined($retries) ) {
	$retries = $DEFAULT_RETRIES;
    }

    #
    # Make sure we're given valid inputs
    #
    if (!$sess) {
	$snmpitErrorString = "No valid SNMP session given!\n";
	return undef;
    }

    my $array_size;
    if ($getOrSet == $SNMPIT_GET) {
	$array_size = 2;
    } elsif ($getOrSet == $SNMPIT_BULKWALK) {
	$array_size = 1;
    } else {
	$array_size = 4;
    }

    if (((ref($var) ne "SNMP::Varbind") && (ref($var) ne "SNMP::VarList")) &&
	    ((ref($var) ne "ARRAY") || ((@$var != $array_size) && (@$var != 4)))) {
	$snmpitErrorString = "Invalid SNMP variable given ($var)!\n";
	return undef;
    }

    #
    # Retry several times
    #
    foreach my $retry ( 1 .. $retries) {
	my $status;
        my @return;
	if ($getOrSet == $SNMPIT_GET) {
	    $status = $sess->get($var);
	} elsif ($getOrSet == $SNMPIT_BULKWALK) {
	    @return = $sess->bulkwalk(0,32,$var);
	} else {
	    $status = $sess->set($var);
	}

	#
	# Avoid unitialized variable warnings when printing errors
	#
	if (! defined($status)) {
	    $status = "(undefined)";
	}

	#
	# We detect errors by looking at the ErrorNumber variable from the
	# session
	#
	if ($sess->{ErrorNum}) {
	    my $type;
	    if ($getOrSet == $SNMPIT_GET) {
		$type = "get";
	    } elsif ($getOrSet == $SNMPIT_BULKWALK) {
		$type = "bulkwalk";
	    } else {
		$type = "set";
	    }
	    $snmpitErrorString  = "SNMPIT $type failed for device " .
                "$sess->{DestHost} (try $retry of $retries)\n";
            $snmpitErrorString .= "Variable was " .  printVars($var) . "\n";
	    $snmpitErrorString .= "Returned $status, ErrorNum was " .
		   "$sess->{ErrorNum}\n";
	    if ($sess->{ErrorStr}) {
		$snmpitErrorString .= "Error string is: $sess->{ErrorStr}\n";
	    }
	} else {
	    if ($getOrSet == $SNMPIT_GET) {
		return $var->[2];
	    } elsif ($getOrSet == $SNMPIT_BULKWALK) {
                return @return;
	    } else {
	        return 1;
	    }
	}

	#
	# Don't flood requests too fast. Randomize the sleep a little so that
	# we don't end up with all our retries coming in at the same time.
	#
        sleep(1);
	select(undef, undef, undef, rand(1));
    }

    #
    # If we made it out, all of the attempts must have failed
    #
    return undef;
}

#
# usage: snmpitGet(session, var, [retries])
# args:  session - SNMP::Session object, already connected to the SNMP
#                  device
#        var     - An SNMP::Varbind or a reference to a two-element array
#                  (similar to a single Varbind)
#        retries - Number of times to retry in case of failure
# returns: the value on sucess, undef on failure
#
sub snmpitGet($$;$) {
    my ($sess,$var,$retries) = @_;
    my $result;

    $result = snmpitDoIt($SNMPIT_GET,$sess,$var,$retries);

    return $result;
}

#
# Same as snmpitGet, but send mail if any error occur
#
sub snmpitGetWarn($$;$) {
    my ($sess,$var,$retries) = @_;
    my $result;

    $result = snmpitDoIt($SNMPIT_GET,$sess,$var,$retries);

    if (! defined $result) {
	snmpitWarn("SNMP GET failed");
    }
    return $result;
}

#
# Same as snmpitGetWarn, but also exits from the program if there is a 
# failure.
#
sub snmpitGetFatal($$;$) {
    my ($sess,$var,$retries) = @_;
    my $result;

    $result = snmpitDoIt($SNMPIT_GET,$sess,$var,$retries);

    if (! defined $result) {
	tbreport(SEV_ERROR, 'snmp_get_fatal');
	snmpitFatal("SNMP GET failed");
    }
    return $result;
}

#
# usage: snmpitSet(session, var, [retries])
# args:  session - SNMP::Session object, already connected to the SNMP
#                  device
#        var     - An SNMP::Varbind or a reference to a two-element array
#                  (similar to a single Varbind)
#        retries - Number of times to retry in case of failure
# returns: true on success, undef on failure
#
sub snmpitSet($$;$) {
    my ($sess,$var,$retries) = @_;
    my $result;

    $result = snmpitDoIt($SNMPIT_SET,$sess,$var,$retries);

    return $result;
}

#
# Same as snmpitSet, but send mail if any error occur
#
sub snmpitSetWarn($$;$) {
    my ($sess,$var,$retries) = @_;
    my $result;

    $result = snmpitDoIt($SNMPIT_SET,$sess,$var,$retries);

    if (! defined $result) {
	snmpitWarn("SNMP SET failed");
    }
    return $result;
}

#
# Same as snmpitSetWarn, but also exits from the program if there is a 
# failure.
#
sub snmpitSetFatal($$;$) {
    my ($sess,$var,$retries) = @_;
    my $result;

    $result = snmpitDoIt($SNMPIT_SET,$sess,$var,$retries);

    if (! defined $result) {
	tbreport(SEV_ERROR, 'snmp_set_fatal');
	snmpitFatal("SNMP SET failed");
    }
    return $result;
}

#
# usage: snmpitBulkwalk(session, var, [retries])
# args:  session - SNMP::Session object, already connected to the SNMP
#                  device
#        var     - An SNMP::Varbind or a reference to a single-element array
#        retries - Number of times to retry in case of failure
# returns: an array of values on success, undef on failure
#
sub snmpitBulkwalk($$;$) {
    my ($sess,$var,$retries) = @_;
    my @result;

    @result = snmpitDoIt($SNMPIT_BULKWALK,$sess,$var,$retries);

    return @result;
}

#
# Same as snmpitBulkwalk, but send mail if any errors occur
#
sub snmpitBulkwalkWarn($$;$) {
    my ($sess,$var,$retries) = @_;
    my @result;

    @result = snmpitDoIt($SNMPIT_BULKWALK,$sess,$var,$retries);

    if (! @result) {
	snmpitWarn("SNMP Bulkwalk failed");
    }
    return @result;
}

#
# Same as snmpitBulkwalkWarn, but also exits from the program if there is a 
# failure.
#
sub snmpitBulkwalkFatal($$;$) {
    my ($sess,$var,$retries) = @_;
    my @result;

    @result = snmpitDoIt($SNMPIT_BULKWALK,$sess,$var,$retries);

    if (! @result) {
	snmpitFatal("SNMP Bulkwalk failed");
    }
    return @result;
}

#
# Print out SNMP::VarList and SNMP::Varbind structures. Useful for debugging
#
sub printVars($) {
    my ($vars) = @_;
    if (!defined($vars)) {
	return "[(undefined)]";
    } elsif (ref($vars) eq "SNMP::VarList") {
	return "[" . join(", ",map( {"[".join(",",@$_)."\]";}  @$vars)) . "]";
    } elsif (ref($vars) eq "SNMP::Varbind") {
	return "[" . join(",",@$vars) . "]";
    } elsif (ref($vars) eq "ARRAY") {
	return "[" . join(",",map( {defined($_)? $_ : "(undefined)"} @$vars))
		. "]";
    } else {
	return "[unknown value]";
    }
}

#
# Both print out an error message and mail it to the testbed ops. Prints out
# the snmpitErrorString set by snmpitGet.
#
# usage: snmpitWarn(message,fatal)
#
sub snmpitWarn($$) {

    my ($message,$fatal) = @_;

    #
    # Untaint $PRORAM_NAME
    #
    my $progname;
    if ($PROGRAM_NAME =~ /^([-\w.\/]+)$/) {
	$progname = $1;
    } else {
	$progname = "Tainted";
    }

    my $text = "$message - In $progname\n" .
    	       "$snmpitErrorString\n";
	
    if ($fatal) {
        tbdie({cause => 'hardware'}, $text);
    } else {
        tbwarn({cause => 'hardware'}, $text);
    }

}

#
# Like snmpitWarn, but die too
#
sub snmpitFatal($) {
    my ($message) = @_;
    snmpitWarn($message,1);
}

#
# Used to sort a set of nodes in testbed order (ie. pc2 < pc10)
#
# usage: tbsort($a,$b)
#        returns -1 if $a < $b
#        returns  0 if $a == $b
#        returns  1 if $a > $b
#
sub tbsort { 
    my ($a,$b) = @_;
    $a =~ /^([a-z]*)([0-9]*):?([0-9]*)/;
    my $a_let = ($1 || "");
    my $a_num = ($2 || 0);
    my $a_num2 = ($3 || 0);
    $b =~ /^([a-z]*)([0-9]*):?([0-9]*)/;
    my $b_let = ($1 || "");
    my $b_num = ($2 || 0);
    my $b_num2 = ($3 || 0);
    if ($a_let eq $b_let) {
	if ($a_num == $b_num) {
	    return $a_num2 <=> $b_num2;
	} else {
	    return $a_num <=> $b_num;
	}
    } else {
	return $a_let cmp $b_let;
    }
    return 0;
}


#
# Silly helper function - returns its input array with duplicates removed
# (ordering is likely to be changed)
#
sub uniq(@) {
    my %elts;
    foreach my $elt (@_) { $elts{$elt} = 1; }
    return keys %elts;
}

#                                                                                                                                                                                                                  
# uniq for ports
#                                                                                                                                                                                                                  
sub uniq_ports(@) {
    my %elts;
    my @pts;
    foreach my $p (@_) {
        if (!exists($elts{$p->toString()})) {
            $elts{$p->toString()} = 1;
            push @pts, $p;
	}
    }
    return @pts;
}

sub findAndDumpLan($)
{
    my ($lan_id) = @_;
    
    my $lan = Lan->Lookup($lan_id);
    return
	if (!defined($lan));

    print STDERR Dumper($lan->{'LAN'}) . "\n";
}

#
# Coarse grain locking
#
my $snmpit_lock_held;

sub snmpit_lock($)
{
    my ($token) = @_;

    if ($snmpit_lock_held) {
	print STDERR "snmpit_lock($token): ".
	    "Lock already held: $snmpit_lock_held\n";
	return -1;
    }
    my $old_umask = umask(0);
    my $rv = (TBScriptLock($token,0,1800) == TBSCRIPTLOCK_OKAY() ? 0 : 1);
    umask($old_umask);
    if ($rv == 0) {
	$snmpit_lock_held = $token;
    }
    return $rv;
}

sub snmpit_unlock($)
{
    my ($token) = @_;
    
    if ($snmpit_lock_held) {
	if ($snmpit_lock_held eq $token) {
	    TBScriptUnlock();
	    $snmpit_lock_held = undef;
	}
	else {
	    print STDERR "snmpit_unlock($token): ".
		"Lock help by another: $snmpit_lock_held\n";
	    return -1;
	}
    }
    return 0;
}

# End with true
1;

