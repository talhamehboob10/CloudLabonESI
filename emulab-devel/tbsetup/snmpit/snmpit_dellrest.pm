#!/usr/bin/perl -w

#
# Copyright (c) 2019, 2021 University of Utah and the Flux Group.
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
# snmpit module for Dell OS10 switches supporting RESTCONF interface.
#
# Behavior/requirements of OS10:
#
#      port in access mode, must have an access vlan
#      port in trunk mode, needs no access vlan or trunk vlans
#      port in trunk mode with no access vlan, will get put in vlan1 when
#        switched to access mode
#      port in trunk mode with access vlan, will leave port in that access
#        vlan when switched to access mode
#
# NOTE: when putting a port in trunk mode, be sure to remove access vlan
# if it is vlan1 or if trunk is in "equal" mode.
#

package snmpit_dellrest;
use strict;
use Data::Dumper;

$| = 1; # Turn off line buffering on output

use English;
use SNMP;
use URI::Escape;
use snmpit_lib;
use Port;
use dell_rest;

# Just... Don't.
BEGIN { libtblog::tblog_stop_capture(); }

# Most are defined in snmpit_lib, let's not repeat or change
#my $PORT_FORMAT_IFINDEX   = 1;
#my $PORT_FORMAT_MODPORT   = 2;
#my $PORT_FORMAT_NODEPORT  = 3;
#my $PORT_FORMAT_PORT      = 4;
#my $PORT_FORMAT_PORTINDEX = 5;
my $PORT_FORMAT_NATIVE     = 6;

#
# In April 2021 I did an optimization pass to try to reduce the number of
# REST API calls made (since they take a minimum of 2s each). Til they have
# more real world testing, with different firmware versions, make this
# optional. Set this to zero to revert to the "old ways" which have been
# working for several years. The biggest difference was avoiding enabling
# and disabling one port per call. For big LANs, this is a huge improvement.
#
# Quick numbers for 38 node LAN (38 ports, 1 VLAN):
#  Old snmpit -t:  82 seconds, calls:  5 getinfo ( 4 cached),  40 other.
#  New snmpit -t:  12 seconds, calls:  5 getinfo ( 4 cached),   3 other.
#  Old snmpit -r: 155 seconds, calls:  7 getinfo ( 6 cached),  77 other.
#  New snmpit -r:  12 seconds, calls:  7 getinfo ( 6 cached),   3 other.
# Mostly these are savings of individual calls to enable/disable ports.
#
# With multiplexed links (tagged ports):
#  Old snmpit -t: 228 seconds, calls: 43 getinfo (42 cached), 116 other.
#  New snmpit -t: 154 seconds, calls: 43 getinfo (42 cached),  79 other.
#  Old snmpit -r: 157 seconds, calls: 44 getinfo (43 cached),  77 other.
#  New snmpit -r: 154 seconds, calls: 44 getinfo (43 cached),  77 other.
# Not as dramatic due to the fact that the backend-independent part of
# snmpit makes per-port calls to enable/disable trunking. So no easy
# opportunities to reduce calls.
#
# A 38 node "snake" (76 ports, 38 VLANs):
#  Old snmpit -t: 234 seconds, calls: 190 getinfo (189 cached), 114 other.
#  New snmpit -t: 230 seconds, calls: 190 getinfo (189 cached), 114 other.
#  Old snmpit -r: 378 seconds, calls:  81 getinfo ( 80 cached), 190 other.
#  New snmpit -r: 159 seconds, calls:  81 getinfo ( 80 cached),  77 other.
#
# A 176 node LAN across seven switches now takes 69 seconds for either
# create or remove vs. over 6 minutes to create and 12 minutes to destroy.
#
# Additional targets: enablePortTrunking2, disablePortTrunking
#
my $OPTIMIZE       = 1;

#
# XXX safety net: make sure we don't remove this vlan from any port.
#
# This is the Emulab/CloudLab/Powder hardware management VLAN. We don't want
# to lose contact with any far-flung, hard to access Powder end-point switches.
#
my $SACRED_VLAN	   = 10;

#
# Creates a new object.
#
# usage: new($classname,$devicename,$debuglevel)
#        returns a new object, blessed into the snmpit_dellrest class.
#
sub new($$$)
{
    # The next two lines are some voodoo taken from perltoot(1)
    my $proto = shift;
    my $class = ref($proto) || $proto;

    my $name = shift;                       # the name of the switch, e.g. e1200a
    my $debugLevel = shift;

    #
    # Create the actual object
    #
    my $self = {};

    #
    # Set the defaults for this object
    # 
    if (defined($debugLevel)) {
		$self->{DEBUG} = $debugLevel;
    } else {
		$self->{DEBUG} = 0;
    }
    $self->{NAME} = $name;

    #
    # Get config options from the database
    #
    my $options = getDeviceOptions($self->{NAME});
    if (!$options) {
	warn "ERROR: Getting switch options for $self->{NAME}\n";
	return undef;
    }

    $self->{MIN_VLAN} = $options->{'min_vlan'};
    $self->{MAX_VLAN} = $options->{'max_vlan'};

    if (!exists($options->{"username"}) || !exists($options->{"password"})) {
	warn "ERROR: No credentials found for OS10 switch $self->{NAME}\n";
	return undef;
    }

    #
    # Get devicetype from database
    #
    $self->{TYPE} = getDeviceType($self->{NAME});

    my $swcreds = $options->{"username"} . ":" . $options->{"password"};
    $self->{ROBJ} = dell_rest->new($self->{NAME}, $debugLevel, $swcreds);
    if (!$self->{ROBJ}) {
	warn "ERROR: Could not create REST object for $self->{NAME}\n";
	return undef;
    }

    #
    # PortInfo...um, info
    #
    $self->{GOTPORTINFO} = 0;
    $self->{PORTS} = {};	# All physcial, non-management ports
    $self->{VLANS} = {};	# Vlan port devices
    $self->{PORTCHANS} = {};	# Port-channel devices
    $self->{ACCESS} = {};	# "access mode" ports
    $self->{TRUNK} = {};	# "trunk mode" ports
    $self->{IFINDEX} = {};	# port -> if-index map
    $self->{IFINDEXMAP} = {};	# ifindex -> port map
    
    # XXX some stats
    $self->{CALLGETINFO} = 0;
    $self->{CACHEGETINFO} = 0;
    $self->{CALLOTHER} = 0;
    $self->{SAVEDCALLS} = 0;

    bless($self,$class);

    return $self;
}

sub DESTROY($)
{
    my ($self) = @_;
    my $id = "$self->{NAME}";
    my $gicalls = $self->{CALLGETINFO};
    my $gihits = $self->{CACHEGETINFO};
    my $ocalls = $self->{CALLOTHER};
    my $scalls = $self->{SAVEDCALLS};

    print "$id: RESTCONF calls: $gicalls getinfo ($gihits cached), $ocalls other, $scalls other calls avoided.\n"
	if ($self->{DEBUG});
}

#
# Prints out a debugging message, but only if debugging is on. If a level is
# given, the debuglevel must be >= that level for the message to print. If
# the level is omitted, 1 is assumed
#
# Usage: debug($self, $message, $level)
#
sub debug($$;$) {
    my $self = shift;
    my $string = shift;
    my $debuglevel = shift;
    if (!(defined $debuglevel)) {
	    $debuglevel = 1;
    }
    if ($self->{DEBUG} >= $debuglevel) {
	print STDERR $string;
    }
}

##############################################################################
## Internal / Utility Functions Section
##

#
# Port names are of the form <type><node>[/<slot>/<port>[:<subport]]
# Sort them by type lexigraphically and then by node/slot/port/subport
# numerically in that order.
#
sub portSort($$)
{
    my ($a,$b) = @_;
    my (@aa,@ba);

    if ($a =~ /^([^\d]+)(\d+)(?:\/(\d+)\/(\d+)(?:\:(\d+))?)?$/) {
	@aa = ($1,$2,$3,$4,$5);
    } else {
	return $a cmp $b;
    }
    if ($b =~ /^([^\d]+)(\d+)(?:\/(\d+)\/(\d+)(?:\:(\d+))?)?$/) {
	@ba = ($1,$2,$3,$4,$5);
    } else {
	return $a cmp $b;
    }

    my $rv = ($aa[0] cmp $ba[0]);
    return $rv if $rv;

    if ($aa[0] eq "port-channel" || $aa[0] eq "vlan") {
	return ($aa[1] <=> $ba[1]);
    }

    $aa[4] = 0 if (!defined $aa[4]);
    $ba[4] = 0 if (!defined $ba[4]);

    return ($aa[1] <=> $ba[1] ||
	    $aa[2] <=> $ba[2] ||
	    $aa[3] <=> $ba[3] ||
	    $aa[4] <=> $ba[4]);
}

#
# XXX Crap! I was hoping to get by without the old if-index, but snmpit_stack
# uses them to identify port channels. The RESTCONF interface exposes these
# via the interface-state target, but I don't want to make another expensive
# API call just to get that. Plus last time I did this, the call returned
# JSON that could not be parsed by the Perl JSON package (some "unprintable"
# chars in the media-policy-table).
#
# So we are just going to make them up for now with a very simple algorithm:
#
# regular-port: ((slot * port * 5) + subport) + 1
#   where subport is zero if the port is not broken out, 1-4 otherwise
#   and the final "+1" is just so no port maps to zero (which indicates failure).
# 
# port-channel: (port-channel-node + 1000)
#   where "node" is the number in the name and
#   "+1000" to avoid collisions with port ifindexes.
#
# port-channel: (vlan-node + 2000)
#   where "node" is the number in the name and
#   "+2000" to avoid collisions with port/port-channel ifindexes.
#
sub mapPortToIndex($$)
{
    my ($self, $iface) = @_;
    my $id = "$self->{NAME}::mapPortToIndex()";
    my $index = 0;

    if ($iface !~ /^([^\d]+)(\d+)(?:\/(\d+)\/(\d+)(?:\:(\d+))?)?$/) {
	warn "$id: ERROR: Cannot parse '$iface'.\n";
	return 0;
    }

    my ($type,$node,$slot,$port,$subport) = ($1,$2,$3,$4,$5);
    if ($type eq "port-channel") {
	$index = $node + 1000;
    }
    elsif ($type eq "vlan") {
	$index = $node + 2000;
    }
    elsif ($type eq "ethernet") {
	$subport = 0 if (!defined($subport));
	$index = ($slot * $port * 5) + $subport + 1;
    }
    else {
	warn "$id: ERROR: Cannot map '$iface' to ifindex.\n";
	return 0;
    }

    return $index;
}

#
# Get the SW version. Determines what optimizations we can do.
# Return as an array of (version, subversion, ...)
#
sub getOS10Version($)
{
    my ($self) = @_;

    if (!defined($self->{OS10VERSION})) {
	$self->{CALLOTHER}++;
	my $path = "dell-system-software:system-sw-state/sw-version";
	my $json = $self->{ROBJ}->call("GET", $path);
	if ($json) {
	    $self->{OS10VERSION} =
		$json->{"dell-system-software:sw-version"}->{"sw-version"};
	} else {
	    warn "WARNING: could not get OS10 version, assuming < 5\n";
	    # XXX the oldest version I know with REST API
	    $self->{OS10VERSION} = "10.4.3.1";
	}
	print "$self->{NAME}: OS10 version: $self->{OS10VERSION}\n"
	    if ($self->{DEBUG});
    }

    return split('\.', $self->{OS10VERSION});
}

sub getOnePortInfo($$;$)
{
    my ($self, $iface, $silent) = @_;
    my $id = "$self->{NAME}::getOnePortInfo()";
    my $error = "";

    $self->debug("$id: entering\n");

    my $path = "interfaces/interface=" . uri_escape($iface);
    my $json = $self->{ROBJ}->call("GET", $path, undef, undef, \$error);
    if (!$json) {
	if (!$silent) {
	    warn "$id: ERROR: Could not read '$iface' interface information:\n".
		$error . "\n";
	}
	return undef;
    }
    $self->debug("$id: '$path' call returns:\n" . Dumper($json), 4);

    return $json;
}

sub getPortInfo($)
{
    my $self = shift;
    my $id = "$self->{NAME}::getPortInfo()";

    $self->debug("$id: entering, usecache=". ($self->{GOTPORTINFO} ? 1 : 0). "\n");

    $self->{CALLGETINFO}++;
    if ($self->{GOTPORTINFO}) {
	$self->{CACHEGETINFO}++;
	return 1;
    }

    my $path = "interfaces";
    my $json = $self->{ROBJ}->call("GET", $path);
    if (!$json) {
	warn "$id: ERROR: Could not read interface information.\n";
	return 0;
    }
    $self->debug("$id: '$path' call returns:\n" . Dumper($json), 4);

    if (exists($json->{"ietf-interfaces:interfaces"})) {
	foreach my $iface (@{$json->{"ietf-interfaces:interfaces"}->{"interface"}}) {
	    my $name = $iface->{"name"};
	    my $type = $iface->{"type"};
	    my $enabled = (!exists($iface->{"enabled"}) || $iface->{"enabled"}) ? 1 : 0;
	    my $ix;

	    #
	    #
	    # Ethernet
	    # Modes:
	    #   <none>: "switchport access vlan ...", aka an untagged port
	    #   MODE_L2DISABLED: "no switchport", aka part of a port channel?
	    #	MODE_L2HYBRID: "switchport mode trunk", aka a trunk port
	    #
	    if ($type eq "iana-if-type:ethernetCsmacd") {
		if (!exists($iface->{"dell-interface:mode"})) {
		    $self->{PORTS}{$name}->{"enabled"} = $enabled;
		    $self->{ACCESS}{$name}->{"avlan"} = 0;
		    $ix = $self->mapPortToIndex($name);
		    $self->{IFINDEX}{$name} = $ix;
		    $self->{IFINDEXMAP}{$ix} = $name;
		} elsif ($iface->{"dell-interface:mode"} eq "MODE_L2HYBRID") {
		    $self->{PORTS}{$name}->{"enabled"} = $enabled;
		    $self->{TRUNK}{$name}->{"vlans"} = [];
		    $ix = $self->mapPortToIndex($name);
		    $self->{IFINDEX}{$name} = $ix;
		    $self->{IFINDEXMAP}{$ix} = $name;
		} elsif ($iface->{"dell-interface:mode"} eq "MODE_L2DISABLED") {
		    # probably part of a port-channel, not counted as a port
		    ;
		} else {
		    my $mode = $iface->{"dell-interface:mode"};
		    warn "$id: interface '$name' has unknown mode '$mode', ignored\n";
		}
	    }
	    # Vlans
	    elsif ($type eq "iana-if-type:l2vlan") {
		if ($name =~ /^vlan(\d+)$/) {
		    $self->{VLANS}{$name}->{"tag"} = $1;
		    if (exists($iface->{"description"})) {
			$self->{VLANS}{$name}->{"ename"} = $iface->{"description"};
		    } else {
			$self->{VLANS}{$name}->{"ename"} = $name;
		    }
		    if (exists($iface->{"dell-interface:untagged-ports"})) {
			$self->{VLANS}{$name}->{"untagged"} = 
			    $iface->{"dell-interface:untagged-ports"};
		    } else {
			$self->{VLANS}{$name}->{"untagged"} = [];
		    }
		    if (exists($iface->{"dell-interface:tagged-ports"})) {
			$self->{VLANS}{$name}->{"tagged"} = 
			    $iface->{"dell-interface:tagged-ports"};
		    } else {
			$self->{VLANS}{$name}->{"tagged"} = [];
		    }
		    $ix = $self->mapPortToIndex($name);
		    $self->{IFINDEX}{$name} = $ix;
		    $self->{IFINDEXMAP}{$ix} = $name;
		} else {
		    warn "$id: unknown name format '$name' for vlan device, ignored\n";
		}
	    }
	    # Port channels
	    elsif ($type eq "iana-if-type:ieee8023adLag") {
		if (!exists($iface->{"dell-interface:mode"})) {
		    $self->{ACCESS}{$name}->{"avlan"} = 0;
		} elsif ($iface->{"dell-interface:mode"} eq "MODE_L2HYBRID") {
		    $self->{TRUNK}{$name}->{"vlans"} = [];
		} elsif ($iface->{"dell-interface:mode"} eq "MODE_L2DISABLED") {
		    # probably part of a port-channel, not counted as a port
		    warn "$id: port-channel '$name' is part of a port-channel, ignored\n";
		    next;
		} else {
		    my $mode = $iface->{"dell-interface:mode"};
		    warn "$id: interface '$name' has unknown mode '$mode', ignored\n";
		    next;
		}
		$self->{PORTS}{$name}->{"enabled"} = $enabled;
		$self->{PORTCHANS}{$name}->{"members"} = [];
		if (exists($iface->{"dell-interface:member-ports"})) {
		    foreach my $mref (@{$iface->{"dell-interface:member-ports"}}) {
			push @{$self->{PORTCHANS}{$name}->{"members"}},
			    $mref->{"name"};
		    }
		}
		$ix = $self->mapPortToIndex($name);
		$self->{IFINDEX}{$name} = $ix;
		$self->{IFINDEXMAP}{$ix} = $name;
	    }
	    # Management/null -- ignore
	    elsif ($type eq "dell-base-interface-common:management" ||
		   $type eq "dell-base-interface-common:null") {
		next;
	    }
	    # Something else?!
	    else {
		warn "$id: unknown interface type '$type', ignored\n";
		next;
	    }
	}

	#
	# For access ports, figure out the VLAN they are in.
	#
	foreach my $iface (keys %{$self->{ACCESS}}) {
	    foreach my $viface (keys %{$self->{VLANS}}) {
		my $tag = $self->{VLANS}{$viface}->{"tag"};
		if ($self->inVlanUntagged($tag, $iface)) {
		    $self->{ACCESS}{$iface}->{"avlan"} = $tag;
		}
	    }
	}
	
	#
	# For trunk ports, figure out the tagged and untagged (access) VLANs.
	#
	foreach my $iface (keys %{$self->{TRUNK}}) {
	    foreach my $viface (keys %{$self->{VLANS}}) {
		my $tag = $self->{VLANS}{$viface}->{"tag"};
		if ($self->inVlanUntagged($tag, $iface)) {
		    $self->{TRUNK}{$iface}->{"avlan"} = $tag;
		} elsif ($self->inVlanTagged($tag, $iface)) {
		    push(@{$self->{TRUNK}{$iface}->{"vlans"}}, $tag);
		}
	    }
	}
    }

    $self->dumpPortInfo();

    $self->{GOTPORTINFO} = 1;
    return 1;
}

sub refreshPortInfo($;$)
{
    my ($self,$lazy) = @_;
    $lazy = 0 if !defined($lazy);
    my $id = "$self->{NAME}::refreshPortInfo()";
    
    $self->debug("$id: entering, lazy=$lazy\n");

    $self->{GOTPORTINFO} = 0;
    $self->{PORTS} = {};
    $self->{VLANS} = {};
    $self->{PORTCHANS} = {};
    $self->{ACCESS} = {};
    $self->{TRUNK} = {};
    $self->{IFINDEX} = {};

    return $lazy ? 1 : $self->getPortInfo();
}

sub dumpPortInfo($;$)
{
    my ($self,$force) = @_;
    my $debug = $force ? 3 : $self->{DEBUG};
    my $id = "$self->{NAME}::dumpPortInfo";

    if ($debug > 1) {
	my @ports = sort portSort keys %{$self->{PORTS}};
	if (@ports > 0) {
	    print STDERR "$id: All ports:     ", join(' ', @ports), "\n";
	}
	@ports = sort portSort keys %{$self->{ACCESS}};
	if (@ports) {
	    print STDERR "$id: Access ports:  ", join(' ', @ports), "\n";
	    if ($debug > 2) {
		foreach my $access (@ports) {
		    my $avlan = $self->{ACCESS}{$access}->{"avlan"};
		    my $ifix = $self->{IFINDEX}{$access};
		    my $enabled = $self->{PORTS}{$access}->{"enabled"};
		    print STDERR "$id: ACCESS port=$access, ifindex=$ifix, enabled=$enabled, access=$avlan\n";
		}
	    }
	}
	@ports = sort portSort keys %{$self->{TRUNK}};
	if (@ports) {
	    print STDERR "$id: Trunk ports:   ", join(' ', @ports), "\n";
	    if ($debug > 2) {
		foreach my $trunk (@ports) {
		    my @vlans = @{$self->{TRUNK}{$trunk}->{"vlans"}};
		    my $avlan = $self->{TRUNK}{$trunk}->{"avlan"};
		    my $ifix = $self->{IFINDEX}{$trunk};
		    my $enabled = $self->{PORTS}{$trunk}->{"enabled"};
		    my $avstr = ($avlan ? ", access=$avlan" : "");
		    print STDERR "$id: TRUNK port=$trunk, enabled=$enabled, ifindex=$ifix, members=",
			join(' ', sort { $a <=> $b} @vlans), "$avstr\n";
		}
	    }
	}
	@ports = sort portSort keys %{$self->{PORTCHANS}};
	if (@ports) {
	    print STDERR "$id: Port channels:  ", join(' ', @ports), "\n";
	    if ($debug > 2) {
		foreach my $po (@ports) {
		    my $ifix = $self->{IFINDEX}{$po};
		    my $enabled = $self->{PORTS}{$po}->{"enabled"};
		    my @members = @{$self->{PORTCHANS}{$po}->{"members"}};
		    print STDERR "$id: PCHAN port=$po, ifindex=$ifix, enabled=$enabled, members=",
			join(' ', sort portSort @members), "\n";
		}
	    }
	}
	@ports = sort portSort keys %{$self->{VLANS}};
	if (@ports) {
	    print STDERR "$id: VLANs:          ", join(' ', @ports), "\n";
	    if ($debug > 2) {
		foreach my $vlan (@ports) {
		    my $vlanname = $self->{VLANS}{$vlan}->{"ename"};
		    my $vlantag = $self->{VLANS}{$vlan}->{"tag"};
		    my @members = (@{$self->{VLANS}{$vlan}->{"untagged"}}, 
				   @{$self->{VLANS}{$vlan}->{"tagged"}});
		    my $ifix = $self->{IFINDEX}{$vlan};
		    print STDERR "$id: VLAN ifindex=$ifix, id=$vlanname, tag=$vlantag, members=",
			join(' ', sort portSort @members), "\n";
		}
	    }
	}
    }
}

#
# Return speed of port in Gbps, or 0 if there is some issue.
#
sub getPortSpeed($$)
{
    my ($self,$iface) = @_;
    my $speed = 0;

    # XXX fer now hack, we need to query the port-groups to really get this
    if ($iface =~ /^([^\d]+)(\d+)(?:\/(\d+)\/(\d+)(?:\:(\d+))?)?$/) {
	my ($type,$node,$slot,$port,$subport) = ($1,$2,$3,$4,$5);
	if ($type eq "ethernet") {
	    if ($port <= 48) {
		$speed = defined($subport) ? 10 : 25;
	    } else {
		$speed = defined($subport) ? 40 : 100;
	    }
	} elsif ($type eq "port-channel") {
	    # add up the speeds of all the members
	    foreach my $member (@{$self->{PORTCHANS}{$iface}->{"members"}}) {
		$speed += $self->getPortSpeed($member);
	    }
	}
    }

    return $speed;
}

sub inVlanUntagged($$$)
{
    my ($self,$vtag,$iface) = @_;
    my $vname = "vlan$vtag";

    if (exists($self->{VLANS}{$vname}) &&
	exists($self->{VLANS}{$vname}->{"untagged"})) {
	foreach my $viface (@{$self->{VLANS}{$vname}->{"untagged"}}) {
	    if ($iface eq $viface) {
		return 1;
	    }
	}
    }
    return 0;
}

sub inVlanTagged($$$)
{
    my ($self,$vtag,$iface) = @_;
    my $vname = "vlan$vtag";

    if (exists($self->{VLANS}{$vname}) &&
	exists($self->{VLANS}{$vname}->{"tagged"})) {
	foreach my $viface (@{$self->{VLANS}{$vname}->{"tagged"}}) {
	    if ($iface eq $viface) {
		return 1;
	    }
	}
    }
    return 0;
}

sub addCacheVlanPort($$$$)
{
    my ($self,$vtag,$iface,$list) = @_;
    my $id = "$self->{NAME}::addCacheVlanPort()";

    my $vname = "vlan$vtag";
    if (!exists($self->{VLANS}{$vname})) {
	warn "$id: ERROR: no such vlan $vname!\n";
	return 0;
    }
    push @{$self->{VLANS}{$vname}->{$list}}, $iface;
    return 1;
}

sub removeCacheVlanPort($$$$)
{
    my ($self,$vtag,$iface,$list) = @_;
    my $id = "$self->{NAME}::removeCacheVlanPort()";
    my $found = 0;

    my $vname = "vlan$vtag";
    if (!exists($self->{VLANS}{$vname})) {
	warn "$id: ERROR: no such vlan $vname!\n";
	return 0;
    }

    my $ix = 0;
    foreach my $viface (@{$self->{VLANS}{$vname}->{$list}}) {
	if ($iface eq $viface) {
	    splice(@{$self->{VLANS}{$vname}->{$list}}, $ix, 1);
	    $found = 1;
	    last;
	}
	$ix++;
    }

    return $found;
}

sub addCacheTrunkVlan($$$)
{
    my ($self,$vtag,$iface) = @_;
    my $id = "$self->{NAME}::addCacheTrunkVlan()";

    if (!exists($self->{TRUNK}{$iface})) {
	warn "$id: ERROR: $iface is not a trunk!?\n";
	return 0;
    }
    push @{$self->{TRUNK}{$iface}->{"vlans"}}, $vtag;
    return 1;
}

sub removeCacheTrunkVlan($$$)
{
    my ($self,$vtag,$iface) = @_;
    my $id = "$self->{NAME}::removeCacheTrunkVlan()";
    my $found = 0;

    if (!exists($self->{TRUNK}{$iface})) {
	warn "$id: ERROR: $iface is not a trunk!?\n";
	return 0;
    }
    my $ix = 0;
    foreach my $tag (@{$self->{TRUNK}{$iface}->{"vlans"}}) {
	if ($tag eq $vtag) {
	    splice(@{$self->{TRUNK}{$iface}->{"vlans"}}, $ix, 1);
	    $found = 1;
	    last;
	}
	$ix++;
    }

    return $found;
}

sub enablePort($$$)
{
    my ($self,$on,$iface) = @_;
    my $id = "$self->{NAME}::enablePort()";

    # Build up a hash with all the right stuff
    my $porthash = $self->{ROBJ}->enablePortSpec($on, $iface);

    # Enable/disable the port
    $self->{CALLOTHER}++;
    my $path = "interfaces/interface/" . uri_escape($iface);
    my $RetVal = $self->{ROBJ}->call("PATCH", $path, $porthash);
    if (!defined($RetVal)) { 
	my $able = $on ? "enable" : "disable";
	warn "$id: ERROR: $able port '$iface' failed.\n";
	return 0;
    }

    # update cached info
    if ($self->{GOTPORTINFO}) {
	$self->{PORTS}{$iface}->{"enabled"} = $on;
    }

    return 1;
}

#
# Bulk enable/disable.
# We may need to enable or disable multiple ports during a VLAN operation
# and doing them individually through enablePort is too expensive via this
# interfaces (~2 seconds per call). So we take advantage of being able to
# specify a list of ports to operate on.
#
# XXX This spec came from turning on "cli mode rest-translate" and doing
# an "int range ..." followed by "no shutdown" to see what curl command it
# produced.
#
sub enablePorts($$@)
{
    my ($self,$on,@ifaces) = @_;
    my $id = "$self->{NAME}::enablePorts()";

    # XXX for backware compat, we use enablePort for the single port case
    if (@ifaces == 1) {
	return $self->enablePort($on, @ifaces);
    }

    # Build up a hash with all the right stuff
    my $porthash = $self->{ROBJ}->enableMultiplePortsSpec($on, @ifaces);

    # Enable/disable the ports
    $self->{CALLOTHER}++;
    my $path = "ietf-interfaces:interfaces";
    my $RetVal = $self->{ROBJ}->call("PATCH", $path, $porthash);
    if (!defined($RetVal)) { 
	my $able = $on ? "enable" : "disable";
	warn "$id: ERROR: $able ports '" . join(' ', @ifaces) . "' failed.\n";
	return 0;
    }

    # update cached info
    if ($self->{GOTPORTINFO}) {
	foreach my $iface (@ifaces) {
	    $self->{PORTS}{$iface}->{"enabled"} = $on;
	}
    }

    return 1;
}

#
# Put ports in a VLAN, untagged and tagged.
# Returns number of failures.
#
sub addVlanPorts($$$$)
{
    my ($self,$vlan_number,$uportlist,$tportlist) = @_;
    my $id = "$self->{NAME}::addVlanPorts";
    my $nports = scalar(@{$tportlist}) + scalar(@{$uportlist});
    
    $self->{CALLOTHER}++;
    my $vlanhash = $self->{ROBJ}->addPortsVlanSpec($vlan_number,
						   $uportlist, $tportlist);
    my $path = "interfaces/interface/vlan$vlan_number";
    my $RetVal = $self->{ROBJ}->call("PATCH", $path, $vlanhash);
    if (!defined($RetVal)) { 
	warn "$id: ERROR: add tagged and untagged ports to VLAN $vlan_number failed.\n";
	return $nports;
    }

    if ($self->{GOTPORTINFO}) {
	foreach my $iface (@{$uportlist}) {
	    my $oavlan;

	    $self->addCacheVlanPort($vlan_number, $iface, "untagged");
	    if (exists($self->{ACCESS}{$iface})) {
		$oavlan = $self->{ACCESS}{$iface}->{"avlan"};
		$self->{ACCESS}{$iface}->{"avlan"} = $vlan_number;
	    } elsif (exists($self->{TRUNK}{$iface})) {
		$oavlan = $self->{TRUNK}{$iface}->{"avlan"}
		    if (exists($self->{TRUNK}{$iface}->{"avlan"}));
		$self->{TRUNK}{$iface}->{"avlan"} = $vlan_number;
	    }
	    # pops it out of the old vlan
	    $self->removeCacheVlanPort($oavlan, $iface, "untagged")
		if (defined($oavlan));

	}
	foreach my $iface (@{$tportlist}) {
	    $self->addCacheVlanPort($vlan_number, $iface, "tagged");
	    $self->addCacheTrunkVlan($vlan_number, $iface);
	}
    }

    return 0;
}

#
# Remove ports in a VLAN, untagged and tagged.
# Returns total number of failures.
#
# Caller should check basics like whether the VLAN exists and the ports are
# actually in the VLAN in question. Otherwise, this is going to be a slow fail.
#
sub removeVlanPorts($$$$)
{
    my ($self,$vlan_number,$uportlist,$tportlist) = @_;
    my $id = "$self->{NAME}::removeVlanPorts";
    my $nports = scalar(@{$tportlist}) + scalar(@{$uportlist});
    my $errors = 0;
    my $viface = "vlan$vlan_number";
    
    #
    # XXX Sanity check. Don't remove ANY port from the management VLAN.
    # Just fail if they try.
    #
    if ($vlan_number == $SACRED_VLAN) {
	warn "$id: ERROR: refusing to remove vlan $SACRED_VLAN from ports!\n";
	return 1;
    }

    if (@{$tportlist} > 0) {
	my @vers = $self->getOS10Version();
	if ($OPTIMIZE && $vers[1] > 4) {
	    $self->{CALLOTHER}++;
	    my $calls = scalar(@${tportlist}) - 1;
	    $self->{SAVEDCALLS} += $calls;
	    $self->debug("$id: saved $calls RESTAPI calls\n", 2);
	    my $path = "ietf-interfaces:interfaces";
	    my $vlanhash = $self->{ROBJ}->removeTaggedPortsVlanSpec($vlan_number, $tportlist);
	    my $RetVal = $self->{ROBJ}->call("PATCH", $path, $vlanhash);
	    if (!defined($RetVal)) {
		warn "$id: ERROR: removing tagged ports '".
		    join(',', @{$tportlist}), "' from $viface.\n";
		$errors += scalar(@${tportlist});
	    }
	} else {
	    foreach my $iface (@{$tportlist}) {
		# XXX should this be an error?
		if (!exists($self->{TRUNK}{$iface})) {
		    warn "$id: ERROR: ".
			"cannot remove $viface from untrunked port $iface.\n";
		    $errors++;
		    next;
		}

		$self->{CALLOTHER}++;
		my $path = "interfaces/interface/$viface/tagged-ports=" .
		    uri_escape($iface);
		my $error = "UNKNOWN";
		if (!$self->{ROBJ}->call("DELETE", $path, undef, undef, \$error)) {
		    warn "$id: ERROR: ".
			"removing tagged port $iface from $viface.\n";
		    $errors++;
		    next;
		}
	    }
	}

	# update cache stats, unless there were errors
	if (!$errors) {
	    foreach my $iface (@{$tportlist}) {
		$self->removeCacheTrunkVlan($vlan_number, $iface);
		$self->removeCacheVlanPort($vlan_number, $iface, "tagged");
	    }
	}
    }

    #
    # For untagged ports, we can just add them to the default VLAN (1)
    # and that will remove them from the other vlan.
    #
    if (@{$uportlist} > 0) {
	if ($OPTIMIZE) {
	    my @tports = ();
	    my $calls = scalar(@{$uportlist}) - 1;
	    $self->{SAVEDCALLS} += $calls;
	    $self->debug("$id: saved $calls RESTAPI calls\n", 2);
	    my $rv = $self->addVlanPorts(1, $uportlist, \@tports);
	    if ($rv) {
		warn "$id: ERROR: removing untagged ports '".
		    join(',', @{$uportlist}), "' from $viface.\n";
		$errors += $rv;
	    }
	} else {
	    foreach my $iface (@{$uportlist}) {
		$self->{CALLOTHER}++;
		my $path = "interfaces/interface/$viface/untagged-ports=" .
		    uri_escape($iface);
		my $error = "UNKNOWN";
		if (!$self->{ROBJ}->call("DELETE", $path, undef, undef, \$error)) {
		    warn "$id: ERROR: removing untagged port ".
			"'$iface' from $viface.\n";
		    $errors++;
		}
	    }
	}

	# update cache stats, unless there were errors
	if (!$errors) {
	    foreach my $iface (@{$uportlist}) {
		if (exists($self->{ACCESS}{$iface})) {
		    $self->{ACCESS}{$iface}->{"avlan"} = 1;
		} elsif (exists($self->{TRUNK}{$iface})) {
		    delete $self->{TRUNK}{$iface}->{"avlan"};
		}
	    }
	}
    }

    if ($errors) {
	# force cache refresh if any errors
	$self->refreshPortInfo(1);
    }

    return $errors;
}

sub PortInstance2native($$)
{
    my ($self, $Port) = @_;

    return $Port->iface();
}

sub native2PortInstance($$)
{
    my ($self, $iface) = @_;
    my $string;

    if ($iface =~ /^ethernet(\d+)\/(\d+)\/(\d+)$/) {
	$string = Port->Tokens2TripleString($self->{NAME}, $3, $2);
    }
    else {
	$string = Port->Tokens2IfaceString($self->{NAME}, $iface);
    }
    return Port->LookupByStringForced($string);
}

#
# Converting port formats.
#
sub convertPortFormat($$@)
{
    my $self = shift;
    my $output = shift;
    my @ports = @_;

    my $id = $self->{NAME} . "::convertPortFormat";

    #
    # Avoid warnings by exiting if no ports given
    # 
    if (!@ports) {
	return ();
    }

    #
    # We determine the type by sampling the first port given
    #
    my $sample = $ports[0];
    if (!defined($sample)) {
	warn "$id: Given a bad list of ports\n";
	return undef;
    }

    my $input = undef;
    if (Port->isPort($sample)) {
	$input = $PORT_FORMAT_PORT;
    }
    elsif ($sample =~ /^ethernet/ || $sample =~ /^port-channel/) {
	$input = $PORT_FORMAT_NATIVE;
    }
    elsif ($sample =~ /^\d+$/) {
        $input = $PORT_FORMAT_IFINDEX;
    }
    else {
	warn "$id: do not support input port format of '$sample'\n";
	return undef;
    }
    
    #
    # It's possible the ports are already in the right format
    #
    if ($input == $output) {
	return @ports;
    }

    if ($input == $PORT_FORMAT_PORT) {
	my @swports = map $_->getEndByNode($self->{NAME}), @ports;

	if ($output == $PORT_FORMAT_NATIVE) {
	    my @nports = map $self->PortInstance2native($_), @swports;
	    return @nports;
	}
	elsif ($output == $PORT_FORMAT_IFINDEX) {
	    my @nports = map $self->PortInstance2native($_), @swports;
	    my @ix = map $self->{IFINDEX}{$_}, @nports;
	    return @ix;
	}
    }
    elsif ($input == $PORT_FORMAT_NATIVE) {
	if ($output == $PORT_FORMAT_PORT) {
	    my @swports = map $self->native2PortInstance($_), @ports;
	    return @swports
	}	
	elsif ($output == $PORT_FORMAT_IFINDEX) {
	    my @ix = map $self->{IFINDEX}{$_}, @ports;
	    return @ix;
	}
    }
    elsif ($input == $PORT_FORMAT_IFINDEX) {
	if ($output == $PORT_FORMAT_PORT) {
	    my @nports = map $self->{IFINDEXMAP}{$_}, @ports;
	    my @swports = map $self->native2PortInstance($_), @nports;
	    return @swports
	}	
	elsif ($output == $PORT_FORMAT_NATIVE) {
	    my @nports = map $self->{IFINDEXMAP}{$_}, @ports;
	    return @nports
	}	
    }

    #
    # Some combination we don't know how to handle
    #
    warn "$id: Bad input/output combination ($input/$output)\n";
    return undef;    
}

##############################################################################
## Internal routines not used right now
##

#
# Determine if a VLAN has any members 
# (Used by stack->switchesWithPortsInVlan())
#
sub vlanHasPorts($$)
{
    my ($self, $vlan_number) = @_;
    my $id = "$self->{NAME}::vlanHasPorts()";

    my $info = $self->getOnePortInfo("vlan$vlan_number", 1);
    if (!$info) {
	warn "$id: ERROR: Could not find vlan: $vlan_number\n";
	return 0;
    }
    my $iface = (@{$info->{'interface'}})[0];
    if (!$iface || $iface->{'type'} ne "iana-if-type:l2vlan") {
	warn "$id: ERROR: vlan$vlan_number is not a vlan?!\n";
	return 0;
    }

    if (exists($iface->{'dell-interface:untagged-ports'}) ||
	exists($iface->{'dell-interface:tagged-ports'})) {
	return 1;
    }
    return 0;
}

#
# Remove the input ports from any VLAN they might be in, except for the
# default vlan.
#
sub removePortsFromAllVlans($$@)
{
    my ($self, $tagged_only, @ports) = @_;
    my $id = "$self->{NAME}::removePortsFromAllVlans";
    my $errors = 0;

    $self->debug("$id: entering\n");

    # Bail now if the list of ports is empty.
    if (!@ports) {
	$self->debug("$id: called with empty port list... ".
		     "Returning success!\n");
	return 0;
    }

    # Get complete Port/Vlan info
    if (!$self->getPortInfo()) {
	warn "$id: ERROR: getPortInfo failed.\n";
	return 0;
    }
    
    my %porthash = ();
    foreach my $port ($self->convertPortFormat($PORT_FORMAT_NATIVE, @ports)) {
	$porthash{$port} = 1;
    }

    #
    # Loops through all VLANs to see which ones have any of the named ports.
    # Remove those ports from the requisite VLANs.
    #
    foreach my $vlan (keys %{$self->{VLANS}}) {
	my $vlinfo = $self->{VLANS}{$vlan};
	my $vlan_number = $vlinfo->{"tag"};

	# vlan 1 is the default vlan; we don't explicitly remove anything
	# from it. When a port is added to another untagged VLAN, it is
	# automatically removed from vlan1.
	next if ($vlan_number == 1);

	my @trmlist = ();
	foreach my $port (@{$vlinfo->{"tagged"}}) {
	    if ($porthash{$port}) {
		push (@trmlist, $port);
	    }
	}
	my @urmlist = ();
	if (!$tagged_only) {
	    foreach my $port (@{$vlinfo->{"untagged"}}) {
		if ($porthash{$port}) {
		    push (@urmlist, $port);
		}
	    }
	}

	$self->debug("$id: Attempting to remove " .
		     join(' ', @urmlist, @trmlist) .
		     " from vlan number $vlan_number\n");
	return $self->removeVlanPorts($vlan_number, \@urmlist, \@trmlist);
    }
}

#
# Not something we need to support with Dell RESTCONF switches.  Only port
# enable and disable are supported, and both can be done inside
# portControl().
#
sub UpdateField($$$@) {
    warn "WARNING: snmpit_dellrest does not support UpdateField().\n";
    return 0;
}

#
# XXX hack internal method for return stats for all ports.
# There seems to be some bug in the RESTCONF implementation where GETing
# "interface/interfaces_state" returns malformed JSON. So we are going to
# attempt to parse out the pieces we need.
#
# XXX as of at least OS10 version 10.4.3.3 they have fixed whatever issue
# there was with malformed JSON. So we are back to getting JSON formatted
# data from call.
#
# Returns a hash of refs to stats indexed by interface.
# Returns an empty hash on any error.
#
sub getAllStats($)
{
    my ($self) = @_;
    my $id = $self->{NAME}."::getAllStats";
    my %stats = ();

    $self->{CALLOTHER}++;
    my $path = "interfaces-state";
    my $error = "UNKNOWN";
    my $json = $self->{ROBJ}->call("GET", $path, undef, undef, \$error, 0);
    if (!$json) {
	warn "$id: ERROR: Could not read interface state: $error\n";
	return %stats;
    }
    if (exists($json->{"ietf-interfaces:interfaces-state"})) {
	my $ifs = $json->{"ietf-interfaces:interfaces-state"}->{"interface"};
	foreach my $info (@{$ifs}) {
	    my $iface = $info->{"name"};

	    # only care about ethernet/port-channel interfaces
	    next if (!exists($self->{PORTS}{$iface}));

	    $stats{$iface} = $info->{"statistics"};
	}
    }
    return %stats;
}

##############################################################################
## Snmpit API Module Methods Section
##

#
# List all ports on the device
#
# usage: listPorts($self)
#
# returns: A list of port information. Each entry is an array reference. The
#	array is in the form [id, enabled, link, speed, duplex] where:
#		id is the port identifier (in node:port form)
#		enabled is "yes" if the port is enabled, "no" otherwise
#		link is "up" if the port has carrier, "down" otherwise
#		speed is in the form "XMbps"
#		duplex is "full" or "half"
#
sub listPorts($) {
    my $self = shift;
    my $id = "$self->{NAME}::listPorts()";

    my %Nodeports = ();
    my %Able = ();
    my %Link = ();
    my %speed = ();

    if (!$self->getPortInfo()) {
	warn "$id: ERROR: could not get port info!\n";
	return ();
    }

    foreach my $iface (keys %{$self->{PORTS}}) {
	#
	# Skip ports that don't seem to have anything interesting attached
	#
	my ($port) = $self->convertPortFormat($PORT_FORMAT_PORT, $iface);
	my $nodeport = $port->getOtherEndPort();
	$self->debug("$id: $port ($iface) is connected to $nodeport.\n",3);
	if (!defined($port) || !defined($nodeport) || 
	    $port->toString() eq $nodeport->toString()) {
	    $self->debug("Port $port not connected, skipping\n");
	    next;
	}
	$Nodeports{$iface} = $nodeport;
	$Able{$iface} = $self->{PORTS}{$iface}->{"enabled"} ? "yes" : "no";
	$speed{$iface} = $self->getPortSpeed($iface) . "000Mbps";

	# %Link can be gotten via interfaces-state/interface=.../oper-status
	# XXX duplex is "full"
    }

    #
    # Put all of the data gathered in the loop into a list suitable for
    # returning
    #
    my @rv = ();
    foreach my $iface (sort keys %Nodeports) {
	push @rv, [$Nodeports{$iface},$Able{$iface},"up",$speed{$iface},"full"];
    }
    return @rv;
}

#
# List all VLANs on the device
#
# usage: listVlans($self)
#
# returns: A list of VLAN information. Each entry is an array reference. The
#	array is in the form [id, num, members] where:
#		id is the VLAN identifier, as stored in the database
#		num is the 802.1Q vlan tag number.
#		members is a reference to an array of VLAN members
#
sub listVlans($)
{
    my $self = shift;
    my $id = "$self->{NAME}::listVlans()";
    my @vlaninfo = ();
    
    if (!$self->getPortInfo()) {
	warn "$id: ERROR: could not get port info!\n";
	return ();
    }

    foreach my $vlan (keys %{$self->{VLANS}}) {
	my $ename = $self->{VLANS}{$vlan}->{"ename"};
	my $tag = $self->{VLANS}{$vlan}->{"tag"};
	my @members = (@{$self->{VLANS}{$vlan}->{"untagged"}}, 
		       @{$self->{VLANS}{$vlan}->{"tagged"}});

	if ($tag != 1) {
	    my @ports = $self->convertPortFormat($PORT_FORMAT_PORT, @members);
	    push(@vlaninfo, [$ename, $tag, \@ports]);
	}
    }
    return @vlaninfo;
}

#
# Set a variable associated with a port. The commands to execute are given
# in the cmdOIs hash above
#
# usage: portControl($self, $command, @ports)
#	 returns 0 on success.
#	 returns number of failed ports on failure.
#	 returns -1 if the operation is unsupported
#
# Note:  The only port speed changes that can be made are 10/25Gb or
#	 40/100Gb on the switches we have. And those changes are made
#	 to port groups. We don't support this. We just lie to the caller
#	 that the change went through and hope that the database only
#	 lists the speed actually set on the ports. Also, duplex is
#	 meaningless in the post-FE world, so is ignored.
# 
sub portControl ($$@) {
    my $self = shift;
    my $cmd = shift;
    my @ports = @_;

    my $id = $self->{NAME} . "::portControl";
    my $errors = 0;
    
    $self->debug("portControl: $cmd -> (".Port->toStrings(@ports).")\n");

    my @nports = $self->convertPortFormat($PORT_FORMAT_NATIVE, @ports);
    if (@nports == 0) {
	return 0;
    }

    # The Mellanox XML-gateway API doesn't support setting speed at
    # all, so we just pretend ...
    my %fakeCmds = (
	'auto'      => 1,
        '1000mbit'  => 1,
	'10000mbit' => 1,
	'25000mbit' => 1,
	'40000mbit' => 1,
	'full'      => 1,
	);

    if ($cmd eq "enable" || $cmd eq "disable") {
	if ($OPTIMIZE) {
	    my $calls = scalar(@nports) - 1;
	    $self->{SAVEDCALLS} += $calls;
	    $self->debug("$id: saved $calls RESTAPI calls\n", 2);
	    my $retval = $self->enablePorts(($cmd eq "enable" ? 1 : 0),
					    @nports);
	    if (!defined($retval)) {
		warn "$id: WARNING: Failed to execute '$cmd' on " .
		    join(' ', @nports) . ".\n";
		$errors += scalar(@nports);
	    }
	} else {
	    foreach my $iface (@nports) {
		my $retval = $self->enablePort(($cmd eq "enable"), $iface);
		if (!defined($retval)) {
		    warn "$id: WARNING: Failed to execute '$cmd' on $iface.\n";
		    $errors++;
		}
	    }
	}
    } elsif (!defined $fakeCmds{$cmd}) {
	#
	# Command not supported, not even a fake command.
	#
	$self->debug("Unsupported port control command '$cmd' ignored.\n");
    }

    return $errors;
}

# 
# Check to see if the given "real" VLAN number (i.e. tag) exists on the switch
#
# usage: vlanNumberExists($self, $vlan_number)
#        returns 1 if the 802.1Q VLAN tag exists, 0 otherwise
#
sub vlanNumberExists($$)
{
    my ($self, $vlanno) = @_;
    my $id = "$self->{NAME}::listVlans()";

    if ($vlanno !~ /^(\d+)$/) {
	warn "$id: ERROR: malformed VLAN number '$vlanno'!\n";
	return 0;
    }
    my $iface = "vlan$1";

    # use cached info if we have it
    if ($self->{GOTPORTINFO}) {
	return exists($self->{VLANS}{$iface}) ? 1 : 0;
    }
    # otherwise just get info for this VLAN
    return $self->getOnePortInfo($iface, 1) ? 1 : 0;
}

#
# Given VLAN indentifiers from the database, finds the VLAN tag number
# for them. If no VLAN id is given, returns mappings for the entire switch.
# 
# usage: findVlans($self, @vlan_ids)
#        returns a hash mapping VLAN ids to VLAN numbers
#        any VLANs not found have NULL VLAN numbers
#
sub findVlans($@)
{
    my $self = shift;
    my @vlan_ids = @_;
    my %vlanmap = ();
    my $id = "$self->{NAME}::findVlans()";

    if (!$self->getPortInfo()) {
	warn "$id: ERROR: could not get port info!\n";
	return ();
    }

    foreach my $vlan (keys %{$self->{VLANS}}) {
	my $vlanname = $self->{VLANS}{$vlan}->{"ename"};
	my $tag = $self->{VLANS}{$vlan}->{"tag"};

	# add to hash if theres no @vlan_ids list (requesting all) or if the
	# vlan is actually in the list
	if ( @vlan_ids == 0 || (grep {$_ eq $vlanname} @vlan_ids) ) {
	    $vlanmap{$vlanname} = $tag;
	}
    }

    return %vlanmap;
}

#
# Given a VLAN identifier from the database, find the VLAN tag that is
# assigned to that VLAN. Retries several times (to account for propagation
# delays) unless the $no_retry option is given.
#
# usage: findVlan($self, $vlan_id,$no_retry)
#        returns the VLAN number for the given vlan_id if it exists
#        returns undef if the VLAN id is not found
#
sub findVlan($$;$)
{ 
    my $self = shift;
    my $vlan_id = shift;
    my $no_retry = shift;
    my $id = "$self->{NAME}::findVlan($vlan_id)";
    
    my $max_tries;
    if ($no_retry) {
	$max_tries = 1;
    } else {
	$max_tries = 10;
    }

    # We try this a few times, with 1 second sleeps, since it can take
    # a while for VLAN information to propagate
    foreach my $try (1 .. $max_tries) {

	my %mapping = $self->findVlans($vlan_id);
	if (defined($mapping{$vlan_id})) {
	    $self->debug("$id: found tag " . $mapping{$vlan_id} . "\n",3);
	    return $mapping{$vlan_id};
	}

	# Wait before we try again
	if ($try < $max_tries) {
	    $self->debug("findVlan: failed, trying again\n");
	    sleep 1;
	    $self->refreshPortInfo();
	}
    }

    # Didn't find it
    return undef;
}

#
# Create a VLAN on this switch, with the given identifier (which comes from
# the database) and given 802.1Q tag number ($vlan_number). 
#
# usage: createVlan($self, $vlan_id, $vlan_number)
#        returns the new VLAN number on success
#        returns 0 on failure
#
sub createVlan($$$;$)
{
    my ($self,$vlan_id,$vlan_number,$otherargs) = @_;
    my $id = "$self->{NAME}::createVlan()";
	
    $self->debug("$id: entering\n");

    # Check to see if the requested vlan number already exists.
    if ($self->vlanNumberExists($vlan_number)) {
	warn "$id: ERROR: VLAN $vlan_number already exists\n";
	return 0;
    }

    # Was OpenFlow requested?  If so, they lose!
    if ($otherargs && ref($otherargs) eq 'HASH' && 
	exists($otherargs->{"ofenabled"}) && $otherargs->{"ofenabled"} == 1) {
	warn "$id: ERROR: Openflow not supported\n";
	return 0;
    }

    # Create VLAN
    $self->{CALLOTHER}++;
    my $vlanhash = $self->{ROBJ}->makeVlanSpec($vlan_number, $vlan_id);
    my $RetVal = $self->{ROBJ}->call("POST", "interfaces", $vlanhash);
    if (!defined($RetVal)) { 
	warn "$id: ERROR: VLAN Create id '$vlan_id' as VLAN $vlan_number failed.\n";
	return 0;
    }

    #
    # XXX since reading interface/VLAN state from the switch is expensive,
    # we just update our cached state.
    #
    if ($self->{GOTPORTINFO}) {
	my $name = "vlan$vlan_number";
	$self->{VLANS}{$name}->{"tag"} = $vlan_number;
	$self->{VLANS}{$name}->{"ename"} = $vlan_id;
	$self->{VLANS}{$name}->{"untagged"} = [];
	$self->{VLANS}{$name}->{"tagged"} = [];
	my $ix = $self->mapPortToIndex($name);
	$self->{IFINDEX}{$name} = $ix;
	$self->{IFINDEXMAP}{$ix} = $name;
    }

    return $vlan_number;
}

#
# Removes and disables some ports in a given VLAN.
# The VLAN is given as a VLAN 802.1Q tag value.
#
# Semantics:
#     Case:
#         untagged:
#                       move to default VLAN, put port down
#         alltagged:
#                       untag port
#         nativetagged:
#              remove native vlan:
#                       clear native
#              nonactive vlan:
#                       untag               
#
# usage: removeSomePortsFromVlan(self,vlan,@ports)
#	 returns 0 on sucess.
#	 returns the number of failed ports on failure.
#
sub removeSomePortsFromVlan($$@) {
    my ($self, $vlan_number, @ports) = @_;
    my $id = $self->{NAME} . "::removeSomePortsFromVlan";

    $self->debug($id."\n");

    # Doing this with vlan 1 would be a disaster
    if ($vlan_number == 1) {
	warn "$id: ERROR: No way will I do this on vlan1!\n";
	return scalar(@ports);
    }
    
    # N.B. delPortVlan will invoke getPortInfo()
    return $self->delPortVlan($vlan_number, @ports);
}

#
# Delete multiple vlans:
# curl -i -k -H "Accept: application/json" -H "Content-Type: application/json" -u $USER_NAME:$PASSWORD -d '{"ietf-interfaces:interfaces":{"dell-interface-range:interface-range":[{"name":"358,343,415","type":"iana-if-type:l2vlan","operation":"DELETE"}]}}' -X PATCH https://$MGMT_IP/restconf/data/ietf-interfaces:interfaces
#

#
# Remove the given VLANs from this switch. Removes all ports from the VLAN,
# so it's not necessary to call removePortsFromVlan() first. The VLAN is
# given as a 802.1Q VLAN tag number (so NOT as a vlan_id from the database!)
#
# usage: removeVlan(self,int vlan)
#	 returns 1 on success
#	 returns 0 on failure
#
sub removeVlan($@)
{
    my ($self,@vlan_numbers) = @_;
    my $errors = 0;
    my $id = "$self->{NAME}::removeVlan()";

    $self->debug("$id: entering\n");

    # make sure there is something to do before we get switch info
    if (@vlan_numbers == 0) {
	return 1;
    }

    # be conservative and get complete Port/Vlan info
    if (!$self->getPortInfo()) {
	warn "$id: ERROR: getPortInfo failed.\n";
	return 0;
    }

    my @vlans = ();
    foreach my $vlan_number (@vlan_numbers) {
	# We won't remove vlan 1.
	next if ($vlan_number == 1);

	# ...or a vlan that does not exist.
	next if (!$self->vlanNumberExists($vlan_number));

	# XXX we also won't remove the sacred vlan
	if ($vlan_number == $SACRED_VLAN) {
	    warn "$id: ERROR: refusing to remove vlan $SACRED_VLAN!\n";
	    next;
	}

	push @vlans, $vlan_number;
    }

    # check again to see if there is anything to do
    if (@vlans == 0) {
	return 1;
    }

    #
    # First we try removing all vlans in one operation.
    # If that fails, we try again one at a time to get as many as possible
    # and to determine which ones were not removed.
    #
    my @deadvlans = ();
    my @vers = $self->getOS10Version();
    if ($OPTIMIZE && $vers[1] > 4) {
	print "  Removing VLANs # " . join(' ', @vlans) .
	    " on switch $self->{NAME} ... ";

	$self->{CALLOTHER}++;
	my $path = "ietf-interfaces:interfaces";
	my $vlanhash = $self->{ROBJ}->removeVlansSpec(@vlans);
	my $RetVal = $self->{ROBJ}->call("PATCH", $path, $vlanhash);
	if (!defined($RetVal)) {
	    print "FAILED! Retrying individually ...\n";
	    $self->{SAVEDCALLS} -= 1;
	} else {
	    print "Done.\n";

	    my $calls = scalar(@vlans) - 1;
	    $self->{SAVEDCALLS} += $calls;
	    $self->debug("$id: saved $calls RESTAPI calls\n", 2);

	    @deadvlans = @vlans;
	    @vlans = ();
	}
    }

    foreach my $vlan_number (@vlans) {
	# Perform the removal (no need to remove ports from the VLAN first)
	print "  Removing VLAN # $vlan_number ... ";
	$self->{CALLOTHER}++;
	my $vname = "vlan$vlan_number";
	my $error = "UNKNOWN";
	my $RetVal = $self->{ROBJ}->call("DELETE",
					 "interfaces/interface/$vname",
					 undef, undef, \$error);
	if ($RetVal) { 
	    print "Removed VLAN $vlan_number on switch $self->{NAME}.\n";
	    push @deadvlans, $vlan_number;
	} else {
	    warn "$id: ERROR: Removal of VLAN $vlan_number failed: $error\n";
	    $errors++;
	}
    }
    
    #
    # XXX hack state update:
    # removed untagged ports revert to vlan1
    # removed tagged ports remain in whatever other VLANs they are in
    #
    foreach my $vlan_number (@deadvlans) {
	my $vname = "vlan$vlan_number";
	if ($self->{GOTPORTINFO}) {
	    push(@{$self->{VLANS}{"vlan1"}->{"untagged"}},
		 @{$self->{VLANS}{$vname}->{"untagged"}});
	    foreach my $port (@{$self->{VLANS}{$vname}->{"untagged"}}) {
		$self->{ACCESS}{$port}->{"avlan"} = 1;
	    }
	    foreach my $port (@{$self->{VLANS}{$vname}->{"tagged"}}) {
		if (exists($self->{TRUNK}{$port}->{"avlan"}) &&
		    $self->{TRUNK}{$port}->{"avlan"} == $vlan_number) {
		    $self->{TRUNK}{$port}->{"avlan"} = 1;
		    my @nvlans = ();
		    foreach my $tag (@{$self->{TRUNK}{$port}->{"vlans"}}) {
			push(@nvlans, $vlan_number)
			    if ($tag != $vlan_number);
		    }
		    $self->{TRUNK}{$port}->{"vlans"} = [ @nvlans ];
		}
	    }
	    delete $self->{VLANS}{$vname};
	    delete $self->{IFINDEXMAP}{$self->{IFINDEX}{$vname}};
	    delete $self->{IFINDEX}{$vname};
	}
    }

    return ($errors == 0) ? 1 : 0;
}

#
# Put the given ports in the given VLAN. The VLAN is given as an 802.1Q 
# tag number. (so NOT as a vlan_id from the database!)
############################################################
# Semantics:
#
#   Port state:
#      access mode, vlan1 untagged:
#          add port to vlan_number untagged.
#      access mode, vlan_number untagged:
#	   do nothing
#      access mode, other vlan untagged:
#          add port to vlan_number untagged.
#      trunk mode, no access vlan, other tagged vlans:
#          add port to vlan_number tagged.
#      trunk mode, access vlan not vlan1, other tagged vlans:
#          add port to vlan_number tagged, if untagged vlan is vlan1, remove
#
# Mellanox 'free': switchportMode='access' AND vlan tag = 1
#
############################################################
# usage: setPortVlan($self, $vlan_number, @ports)
#	 returns 0 on success.
#	 returns the number of failed ports on failure
#
sub setPortVlan($$@) {
    my ($self, $vlan_number, @ports) = @_;
    my $id = "$self->{NAME}::setPortVlan($vlan_number)";

    $self->debug("$id: entering\n");

    if (@ports == 0) {
	return 0;
    }
    
    if ($vlan_number == 1) {
	warn "$id: ERROR: should not invoke with vlan1!\n";
	return scalar(@ports);
    }

    # Get complete Port/Vlan info
    if (!$self->getPortInfo()) {
	warn "$id: ERROR: getPortInfo failed.\n";
	return scalar(@ports);
    }

    # Make sure the vlan exists
    if (!$self->vlanNumberExists($vlan_number)) {
	warn "$id: ERROR: Could not find vlan $vlan_number\n";
	return scalar(@ports);
    }

    # Convert the list of input ports into the two formats we need here.
    # Hopefully the incoming list contains port objects already - otherwise
    # we are in for DB queries.
    my @portlist = $self->convertPortFormat($PORT_FORMAT_NATIVE, @ports);
    my @portobj = $self->convertPortFormat($PORT_FORMAT_PORT, @ports);
    $self->debug("$id: input ports: " . join(",",@ports) . "\n",2);
    $self->debug("$id: in native syntax: " . join(",",@portlist) . "\n",2);

    #
    # Figure out what to do based on the mode each port is in.
    #
    my $i = 0;
    my @uportlist = ();
    my @tportlist = ();
    my @enablelist = ();
    foreach my $swport (@portlist) {
	# Access mode port
	if (exists($self->{ACCESS}{$swport})) {
	    # already in the vlan, don't bother
	    if ($self->inVlanUntagged($vlan_number, $swport)) {
		$self->debug("$id: Port $portobj[$i] already untagged in $vlan_number\n",2);
		next;
	    }
	    $self->debug("$id: Adding port $portobj[$i] as untagged to $vlan_number\n",2);

	    # gather these up so we can do it all at once
	    push @uportlist, $swport;

	    # must enable the port (unless putting in vlan1)
	    if ($vlan_number != 1) {
		push @enablelist, $swport;
	    }
	}
	# Trunk mode port
	elsif (exists($self->{TRUNK}{$swport})) {
	    # we are already in the vlan tagged
	    if ($self->inVlanTagged($vlan_number, $swport)) {
		$self->debug("$id: Port $portobj[$i] already tagged in $vlan_number\n",2);
		next;
	    }
	    # we are the access vlan for the port, nothing to do
	    if (exists($self->{TRUNK}{$swport}->{"avlan"})) {
		my $atag = $self->{TRUNK}{$swport}->{"avlan"};
		if ($atag == $vlan_number) {
		    $self->debug("$id: $vlan_number is access vlan for port $portobj[$i]\n",2);
		    next;
		}

		#
		# XXX hack check: I don't think this should happen but make
		# sure that if there is an access vlan for the port, it is not
		# vlan1
		#
		if ($atag == 1) {
		    warn "$id: ERROR: Trunk port $portobj[$i] has access vlan1, fix it!\n";
		}
	    }

	    # gather these up so we can do it all at once
	    push @tportlist, $swport;

	    # must enable the port if not already enabled
	    if (!$self->{PORTS}{$swport}->{"enabled"}) {
		push @enablelist, $swport;
	    }
	} else {
	    warn "$id: ERROR: Unknown state for port $portobj[$i], fix it!\n";
	}
	$i++;
    }

    #
    # Add untagged/tagged ports to vlan
    #
    # XXX right now we assume that if ths fails, nothing got added.
    # This might be a very, very bad assumption.
    #
    my $RetVal = $self->addVlanPorts($vlan_number, \@uportlist, \@tportlist);
    if ($RetVal) { 
	warn "$id: ERROR: add ports to VLAN $vlan_number failed.\n";
	return $RetVal;
    }
    
    #
    # Enable any ports that need it.
    # XXX we don't treat this as an error, though maybe we should.
    #
    if (@enablelist > 0) {
	if ($OPTIMIZE) {
	    my $calls = scalar(@enablelist) - 1;
	    $self->{SAVEDCALLS} += $calls;
	    $self->debug("$id: saved $calls RESTAPI calls\n", 2);
	    if (!$self->enablePorts(1, @enablelist)) {
		warn "$id: WARNING: could not enable ports '" .
		    join(' ', @enablelist) . "'\n";
	    }
	} else {
	    foreach my $iface (@enablelist) {
		if (!$self->enablePort(1, $iface)) {
		    warn "$id: WARNING: could not enable port '$iface'\n";
		}
	    }
	}
    }
    return 0;
}

#
# Remove the given ports from the given VLAN. The VLAN is given as an 802.1Q 
# tag number.
#
# XXX This is actually an internal routine and is not called by snmpit or
# snmpit_stack.
#
# usage: delPortVlan($self, $vlan_number, @ports)
#	 returns 0 on sucess.
#	 returns the number of failed ports on failure.
#
sub delPortVlan($$@)
{
    my ($self,$vlan_number,@ports) = @_;
    my $errors = 0;
    my $id = $self->{NAME}."::delPortVlan($vlan_number)";

    $self->debug("$id: entering\n");

    if (@ports == 0) {
	return 0;
    }
    
    # Get complete Port/Vlan info
    if (!$self->getPortInfo()) {
	warn "$id: ERROR: getPortInfo failed.\n";
	return scalar(@ports);
    }

    if (!$self->vlanNumberExists($vlan_number)) {
	warn "$id: WARNING: VLAN $vlan_number does not exist.\n";
	return scalar(@ports);
    }

    my @swports = $self->convertPortFormat($PORT_FORMAT_NATIVE, @ports);
    my @dbports = $self->convertPortFormat($PORT_FORMAT_PORT, @ports);
    $self->debug("$id: input ports: " . join(",",@ports) . "\n",2);
    $self->debug("$id: in native syntax: " . join(",",@swports) . "\n",2);

    #
    # Figure out what to do based on the mode each port is in.
    #
    my $i = 0;
    my @uportlist = ();
    my @tportlist = ();
    my @disablelist = ();
    foreach my $swport (@swports) {
	# Access mode port
	if (exists($self->{ACCESS}{$swport})) {
	    # we are in the vlan untagged
	    if ($self->inVlanUntagged($vlan_number, $swport)) {
		$self->debug("$id: Removing untagged port $dbports[$i] from $vlan_number\n",2);

		# gather these up so we can do it all at once
		push @uportlist, $swport;
		# note also that we need to disable the port
		push @disablelist, $swport;
	    }
	}
	# Trunk mode port
	elsif (exists($self->{TRUNK}{$swport})) {
	    # we are in the vlan tagged
	    if ($self->inVlanTagged($vlan_number, $swport)) {
		$self->debug("$id: Removing tagged port $dbports[$i] from $vlan_number\n",2);

		# gather these up so we can do it all at once
		push @tportlist, $swport;
		# note that it is okay to remove the last port from a trunk
		next;
	    }
	    # we are the access vlan for the port,
	    if (exists($self->{TRUNK}{$swport}->{"avlan"})) {
		my $atag = $self->{TRUNK}{$swport}->{"avlan"};

		#
		# This is quite possibly not what was intended (leaving the
		# port without an access vlan) so warn the user
		#
		$self->debug("$id: $vlan_number is access vlan for port $dbports[$i]\n",2);

		# gather these up so we can do it all at once
		push @uportlist, $swport;
	    }
	}
	else {
	    warn "$id: ERROR: Unknown state for port $dbports[$i], fix it!\n";
	}
	$i++;
    }

    #
    # Disable untagged ports that will be reverting to the default VLAN.
    # We don't want nodes to be able to send/receive traffic on that VLAN.
    #
    # XXX right now we assume that if this fails, no ports got disabled.
    # This might be a very, very bad assumption.
    #
    if (@disablelist > 0) {
	my @vers = $self->getOS10Version();
	if ($OPTIMIZE && $vers[1] > 4) {
	    my $calls = scalar(@disablelist) - 1;
	    $self->{SAVEDCALLS} += $calls;
	    $self->debug("$id: saved $calls RESTAPI calls\n", 2);
	    if (!$self->enablePorts(0, @disablelist)) {
		warn "$id: WARNING: could not disable ports '" .
		    join(' ', @disablelist) . "'\n";
		return scalar(@ports);
	    }
	} else {
	    foreach my $iface (@disablelist) {
		if (!$self->enablePort(0, $iface)) {
		    warn "$id: ERROR: could not disable port '$iface'\n";
		    return scalar(@ports);
		}
	    }
	}
    }

    #
    # Remove untagged/tagged ports from vlan
    #
    # XXX right now we assume that if ths fails, nothing got removed.
    # This might be a very, very bad assumption.
    #
    my $RetVal = $self->removeVlanPorts($vlan_number, \@uportlist, \@tportlist);
    if ($RetVal) { 
	warn "$id: ERROR: remove ports from VLAN $vlan_number failed.\n";
	return $RetVal;
    }
    
    return 0;
}

#
# Removes all ports from the given VLANs. Each VLAN is given as a VLAN
# 802.1Q tag value.
#
# usage: removePortsFromVlan(self,@vlan)
#	 returns 0 on success.
#	 returns the number of failed ports on failure.
#
sub removePortsFromVlan($@) {
    my $self = shift;
    my @vlan_numbers = @_;
    my $errors = 0;
    my $id = $self->{NAME} . "::removePortsFromVlan";

    $self->debug($id."\n");
    
    return 0 unless(@vlan_numbers);

    # Get complete Port/Vlan info
    if (!$self->getPortInfo()) {
	warn "$id: ERROR: getPortInfo failed.\n";
	return 1;
    }

    foreach my $vlan_number (@vlan_numbers) {
	# Doing this with vlan 1 would be a disaster
	if ($vlan_number == 1) {
	    warn "$id: WARNING: No way will I do this on vlan1, skipped\n";
	    next;
	}

	my $vname = "vlan$vlan_number";
	if (!exists($self->{VLANS}{$vname})) {
	    warn "$id: WARNING: $vname does not exist.\n";
	    next;
	}

	# Get list of ports in the VLAN
	my @ports = ();
	push @ports, @{$self->{VLANS}{$vname}->{"untagged"}};
	push @ports, @{$self->{VLANS}{$vname}->{"tagged"}};

	$errors += $self->delPortVlan($vlan_number, @ports);
    }

    return $errors;
}

##############################################################################
## Trunk and port channel backends - not fully implemented yet.
##

#
# Enable trunking on a port.
# Here we mean trunking in the "carries more than one vlan" sense.
# It is not clear whether we could be called on a port that is already in
# trunk mode and what should happen if it is (i.e., do we remove the existing
# set of ports?) So until we know otherwise, don't allow it.
#
# On OS10, port will remain in whatever access port it was in previously.
# If we are doing equal trunking, we need to remove that port.
#
# usage: enablePortTrunking2(self, modport, nativevlan, equaltrunking)
#        modport: module.port of the trunk to operate on
#        nativevlan: VLAN number of the native VLAN for this trunk
#	 equaltrunk: don't do dual mode; tag PVID also.
#
# Returns 1 on success, 0 otherwise
#
sub enablePortTrunking2($$$$) {
    my ($self,$port,$native_vlan,$equaltrunking) = @_;
    my $id = $self->{NAME} .
		"::enablePortTrunking2($port,$native_vlan,$equaltrunking)";

    $self->debug($id."\n");

    if (!$equaltrunking && (!defined($native_vlan) || ($native_vlan <= 1))) {
	warn "$id: WARNING: inappropriate or missing PVID for trunk.\n";
	return 0;
    }

    # Get complete Port/Vlan info
    if (!$self->getPortInfo()) {
	warn "$id: ERROR: getPortInfo failed.\n";
	return 0;
    }

    my ($iface) = $self->convertPortFormat($PORT_FORMAT_NATIVE, $port);
    my ($istrunk, $avlan);
    if (exists($self->{TRUNK}{$iface})) {
	$avlan = $self->{TRUNK}{$iface}->{"avlan"};
	$istrunk = 1;
    }
    elsif (exists($self->{ACCESS}{$iface})) {
	$avlan = $self->{ACCESS}{$iface}->{"avlan"};
	$istrunk = 0;
    }
    else {
	warn "$id: ERROR: Huh? port '$iface' is not in access or trunk mode, doing nothing.\n";
	return 0;
    }

    #
    # Put it in trunk mode if not already
    #
    if (!$istrunk) {
	$self->{CALLOTHER}++;
	my $porthash = $self->{ROBJ}->trunkPortSpec($iface);
	my $path = "interfaces/interface/" . uri_escape($iface);
	my $RetVal = $self->{ROBJ}->call("PATCH", $path, $porthash);
	if (!defined($RetVal)) { 
	    warn "$id: ERROR: enabling trunk mode failed.\n";
	    return 0;
	}

	# Update cached info to reflect trunking
	delete $self->{ACCESS}{$iface};
	$self->{TRUNK}{$iface}->{"avlan"} = $avlan;
	$self->{TRUNK}{$iface}->{"vlans"} = [];
    }

    #
    # In equal trunking mode, remove port from access vlan and add tagged
    # to new native vlan.
    #
    if ($equaltrunking) {
	my @uplist = ($iface);
	my @tplist = ();
	if (defined($avlan) &&
	    $self->removeVlanPorts($avlan, \@uplist, \@tplist)) {
	    warn "$id: ERROR: failed to remove port access vlan.\n";
	    return 0;
	}
	# Update cached info
	delete $self->{TRUNK}{$iface}->{"avlan"};
	if (defined($avlan)) {
	    $self->removeCacheVlanPort($avlan, $iface, "untagged");
	    undef $avlan;
	}

	if ($native_vlan != 1) {
	    @uplist = ();
	    @tplist = ($iface);
	    if ($self->addVlanPorts($native_vlan, \@uplist, \@tplist)) {
		warn "$id: ERROR: failed to add native vlan $native_vlan.\n";
		return 0;
	    }

	    # Update cached info
	    push(@{$self->{TRUNK}{$iface}->{"vlans"}}, $iface);
	    $self->addCacheVlanPort($native_vlan, $iface, "tagged");
	}
    }

    #
    # Otherwise add the specified native vlan as the access vlan
    #
    elsif (!defined($avlan) || $native_vlan != $avlan) {
	my @uplist = ($iface);
	my @tplist = ();
	if ($self->addVlanPorts($native_vlan, \@uplist, \@tplist)) {
	    warn "$id: ERROR: failed to add native vlan.\n";
	    return 0;
	}

	# Update cached info
	$self->{TRUNK}{$iface}->{"avlan"} = $native_vlan;
	$self->addCacheVlanPort($native_vlan, $iface, "untagged");

	# If the access vlan was vlan1, we need to enable the port
	if (!$self->{PORTS}{$iface}->{"enabled"} &&
	    $self->enablePort(1, $iface)) {
	    warn "$id: ERROR: failed to enable $iface.\n";
	    return 0;
	}
    }

    return 1;
}

#
# Disable trunking on a port.
# Here we mean trunking in the "carries more than one vlan" sense.
#
# Apparently, when there is also an access VLAN, the port should be left in
# that VLAN. If there is no access VLAN, it should be put in vlan1.
# 
# These appear to be the behaviors of OS10 when a port is un-trunked, so all
# we have to do is untrunk the port! We do this by removing the "mode"
# attribute.
#
# usage: disablePortTrunking(self, modport)
#        Returns 1 on success, 0 otherwise
#
sub disablePortTrunking($$) {
    my ($self, $port) = @_;
    my $id = $self->{NAME} . "::disablePortTrunking($port)";

    $self->debug($id."\n");

    # Get complete Port/Vlan info
    if (!$self->getPortInfo()) {
	warn "$id: ERROR: getPortInfo failed.\n";
	return 0;
    }

    my ($name) = $self->convertPortFormat($PORT_FORMAT_NATIVE, $port);
    if (!exists($self->{TRUNK}{$name})) {
	warn "$id: WARNING: port is not in Trunk mode, doing nothing.\n";
	return 1;
    }

    # XXX don't disable trunking if the port carries the SACRED_VLAN.
    if ($self->inVlanTagged($SACRED_VLAN, $name)) {
	warn "$id: ERROR: refusing to untrunk $name with tagged port $SACRED_VLAN\n";
	return 0;
    }

    # if the port will be reverted to vlan1, disable it
    if (!exists($self->{TRUNK}{$name}->{"avlan"}) ||
	$self->{TRUNK}{$name}->{"avlan"} == 1) {
	if (!$self->enablePort(0, $name)) {
	    warn "$id: ERROR: could not disable port '$name'\n";
	    return 0;
	}
	$self->{PORTS}{$name}->{"enabled"} = 0;
    }

    $self->{CALLOTHER}++;
    my $path = "interfaces/interface/" . uri_escape($name) . "/mode";
    my $error = "UNKNOWN";
    my $RetVal = $self->{ROBJ}->call("DELETE", $path, undef, undef, \$error);
    if (!$RetVal) { 
	warn "$id: ERROR: disabling trunking failed: $error\n";
	return 0;
    }

    # XXX hack state update
    # remove port from TRUNK list
    # add port to ACCESS list
    # remove tagged vlans
    # make sure untagged vlan is set (to vlan1 if nothing else)
    if ($self->{GOTPORTINFO}) {
	my $avlan = exists($self->{TRUNK}{$name}->{"avlan"}) ?
	    $self->{TRUNK}{$name}->{"avlan"} : 1;
	my @vlans = exists($self->{TRUNK}{$name}->{"vlans"}) ?
	    @{$self->{TRUNK}{$name}->{"vlans"}} : ();
	
	delete $self->{TRUNK}{$name};
	$self->{ACCESS}{$name}->{"avlan"} = $avlan;
	foreach my $tag (@vlans) {
	    $self->removeCacheVlanPort($tag, $name, "tagged");
	}
	if ($avlan == 1) {
	    $self->addCacheVlanPort(1, $name, "untagged");
	}
    }

    print "$id: disabled trunking.\n";
    return 1;
}

#
# Enable, or disable,  port on a trunk
#
# usage: setVlansOnTrunk(self, modport, value, vlan_numbers)
#        modport: module.port of the trunk to operate on
#        value: 0 to disallow the VLAN on the trunk, 1 to allow it
#	 vlan_numbers: An array of 802.1Q VLAN numbers to operate on
#        Returns 1 on success, 0 otherwise
#
sub setVlansOnTrunk($$$$) {
    my ($self, $modport, $value, @vlan_numbers) = @_;
    my $errors = 0;
    my $id = $self->{NAME} . "::setVlansOnTrunk";

    $self->debug("$id: entering, modport: $modport, value: $value, vlans: ".join(",",@vlan_numbers)."\n");

    #
    # Some error checking (from HP)
    #
    if (($value != 1) && ($value != 0)) {
	warn "$id: WARNING: Invalid value $value passed to function.\n";
	return 0;
    }
    if (grep(/^1$/,@vlan_numbers)) {
	warn "$id: WARNING: VLAN 1 passed to function.\n";
	return 0;
    }

    # Get complete Port/Vlan info
    if (!$self->getPortInfo()) {
	warn "$id: ERROR: getPortInfo failed.\n";
	return 0;
    }

    my ($iface) = $self->convertPortFormat($PORT_FORMAT_NATIVE, $modport);
    if (!$iface) {
	warn "$id: WARNING: Could not get native name for port $modport\n";
	return 0;
    }

    # Add or remove the vlan from the trunk on the port or portchannel.
    foreach my $vlan (@vlan_numbers) {
	next unless $self->vlanNumberExists($vlan);
	if ($value == 1) {
	    $errors += $self->setPortVlan($vlan, $iface);
	} else {
	    $errors += $self->delPortVlan($vlan, $iface);
	}
    }

    return $errors ? 0 : 1;
}
	
#
# Used to flush FDB entries easily
#
# usage: resetVlanIfOnTrunk(self, modport, vlan)
#
sub resetVlanIfOnTrunk($$$) {
    my ($self, $modport, $vlan) = @_;
    my $id = $self->{NAME} . "::resetVlansOnTrunk";

    $self->debug("$id: entering, modport: $modport, vlan: $vlan\n");

    $self->setVlansOnTrunk($modport, 0, $vlan);
    $self->setVlansOnTrunk($modport, 1, $vlan);

    return 0;
}

#
# Get the ifindex for an EtherChannel (trunk given as a list of ports)
# where "trunk" here means interswitch link.
#
# usage: getChannelIfIndex(self, ports)
#        Returns: undef if more than one port is given, and no channel is found
#           an ifindex if a channel is found and/or only one port is given
#
sub getChannelIfIndex($@) {
    my $self = shift;
    my @ports = @_;
    my $id = $self->{NAME}."::getChannelIfIndex";
    my $chifindex = undef;

    $self->debug("$id: entering\n",2);

    #
    # @ports should contain just port channel names (e.g., "port-channel1")
    # so our job is easy.
    #
    my @swports = $self->convertPortFormat($PORT_FORMAT_NATIVE, @ports);
    if (@swports > 1) {
	warn "$id: ERROR did not expect more than one port: " .
	    join(' ', @swports) . "\n";
	return undef;
    }

    my $port = $swports[0];
    if ($port =~ /^port-channel\d+$/) {
	$chifindex = $self->{IFINDEX}{$port};
	$self->debug("found port channel '$port', ifindex $chifindex\n",2);
    }
    #
    # Just return the port channel index.
    #
    # XXX this is old cisco-ish behavior that snmpit_stack seems to expect
    # for interswitch links that are not port channels.
    #
    elsif (exists($self->{TRUNK}{$port})) {
	$chifindex = $self->{IFINDEX}{$port};	
	$self->debug("found regular port '$port', ifindex $chifindex\n",2);
    }
    else {
	warn "$id: ERROR unexpected non-port-channel, non-trunk port '$port'\n";
	return undef;
    }

    return $chifindex;
}

#
# Read a set of values for all given ports.
#
# XXX this is an SNMP specific call only used to get port counters.
# We hack the bejesus out of it, mapping OIDs to values returned via the
# RESTCONF interface. This will fail dramatically if used for anything but
# portstats...	
#
# usage: getFields(self,ports,oids)
#        ports: Reference to a list of ports, in any allowable port format
#        oids: A list of OIDs to reteive values for
#
# On success, returns a two-dimensional list indexed by port,oid
#
sub getFields($$$) {
    my $self = shift;
    my $id = $self->{NAME}."::getFields";
    my ($ports,$oids) = @_;
    my %oidmap = (
	'ifInOctets'		=> 'in-octets',
	'ifInUcastPkts'		=> 'in-unicast-pkts',
	'ifInNUcastPkts'	=> 'in-multicast-pkts',
	'ifInDiscards'		=> 'in-discards',
	'ifInErrors'		=> 'in-errors',
	'ifInUnknownProtos'	=> 'in-unknown-protos',
	'ifOutOctets'		=> 'out-octets',
	'ifOutUcastPkts'	=> 'out-unicast-pkts',
	'ifOutNUcastPkts'	=> 'out-multicast-pkts',
	'ifOutDiscards'		=> 'out-discards',
	'ifOutErrors'		=> 'out-errors',
	'ifOutQLen'		=> 'dell-interface:if-out-qlen',
	# 64-bit counter versions
	'ifHCInOctets'		=> 'in-octets',
	'ifHCInUcastPkts'	=> 'in-unicast-pkts',
	'ifHCInMulticastPkts'	=> 'in-multicast-pkts',
	'ifHCInBroadcastPkts'	=> 'in-broadcast-pkts',
	'ifHCOutOctets'		=> 'out-octets',
	'ifHCOutUcastPkts'	=> 'out-unicast-pkts',
	'ifHCOutMulticastPkts'	=> 'out-multicast-pkts',
	'ifHCOutBroadcastPkts'	=> 'out-broadcast-pkts'
    );


    my @ifaces = $self->convertPortFormat($PORT_FORMAT_NATIVE, @$ports);
    my @oids = @$oids;

    #
    # If we need to make an expensive call to the switch, we might as well
    # only do it once. Hence, if more than one port is specified, just get
    # info for all ports.
    #
    my %swstats = ();
    if (@ifaces == 1) {
	$self->{CALLOTHER}++;
	my $iface = $ifaces[0];
	my $path = "interfaces-state/interface=". uri_escape($iface). "/statistics";
	my $json = $self->{ROBJ}->call("GET", $path);
	$swstats{$iface} = $json->{"statistics"};
    } else {
	if (!$self->getPortInfo()) {
	    warn "$id: ERROR: could not get port info!\n";
	    return ();
	}
	%swstats = $self->getAllStats();
    }

    my @results = ();
    my $i = 0;
    foreach my $iface (@ifaces) {
	my $sref;

	# XXX same interface might appear more than once (link multiplexing)
	if (!exists($swstats{$iface})) {
	    warn "$id: no stats for $iface, ignoring\n";
	    next;
	} else {
	    $sref = $swstats{$iface};
	}
	my $j = 0;
	foreach my $oid (@oids) {
	    my $val = 0;
	    if (exists($sref->{$oidmap{$oid}})) {
		$val = $sref->{$oidmap{$oid}};
		# XXX switch returns mcast and bcast separate, must add it latter
		if ($oid eq "ifInNUcastPkts" &&
		    exists($sref->{'in-broadcast-pkts'})) {
		    $val += $sref->{'in-broadcast-pkts'};
		}
		elsif ($oid eq "ifOutNUcastPkts" &&
		    exists($sref->{'out-broadcast-pkts'})) {
		    $val += $sref->{'out-broadcast-pkts'};
		}
		#
		# XXX all but the "HC" counters are stored as unsigned
		# 32-bit in the DB, so let's be compatible.
		#
		if ($oid !~ /^ifHC/) {
		    $val = int($val) & 0xFFFFFFFF;
		}
	    }
	    $results[$i][$j] = $val;
	    $j++;
	}
	$i++;
    }

    return @results;
}

# 
# Get statistics for ports on the switch
# Returns a subset of the getFields() values but for all ports
#
# usage: getStats($self)
# see snmpit_cisco_stack.pm for a description of return value format
#
sub getStats()
{
    my $self = shift;
    my $id = $self->{NAME}."::getStats";

    my @vars = (
	'in-octets',
	'in-unicast-pkts',
	'in-multicast-pkts',	# should also include in-broadcast-pkts
	'in-discards',
	'in-errors',
	'in-unknown-protos',
	'out-octets',
	'out-unicast-pkts',
	'out-multicast-pkts',	# should also include out-broadcast-pkts
	'out-discards',
	'out-errors',
	'dell-interface:if-out-qlen'
    );
    my @nostats = (0,0,0,0,0,0,0,0,0,0,0,0);

    if (!$self->getPortInfo()) {
	warn "$id: ERROR: could not get port info!\n";
	return ();
    }

    # XXX hack to extract stats from janky JSON
    my %swstats = $self->getAllStats();
    
    my %allports = ();
    my %stats;
    foreach my $iface (keys %{$self->{PORTS}}) {
	my ($swport) = $self->convertPortFormat($PORT_FORMAT_PORT, $iface);

	#
	# Skip ports that don't seem to have anything interesting attached
	#
	my $nodeport = $swport->getOtherEndPort();
	if (!defined($swport) || !defined($nodeport)) {
	    next;
	}
	
	my $nportstr = $swport->getOtherEndPort()->toTripleString();
	$allports{$nportstr} = $swport;
	if (exists($swstats{$iface})) {
	    my $sref = $swstats{$iface};

	    my @pstats;
	    foreach my $var (@vars) {
		my $val;
		if (exists($sref->{$var})) {
		    $val = $sref->{$var};
		    # XXX switch returns mcast and bcast separate, add in latter
		    if ($var eq "in-multicast-pkts" &&
			exists($sref->{'in-broadcast-pkts'})) {
			$val += $sref->{'in-broadcast-pkts'};
		    }
		    elsif ($var eq "out-multicast-pkts" &&
			   exists($sref->{'out-broadcast-pkts'})) {
			$val += $sref->{'out-broadcast-pkts'};
		    }
		} else {
		    $val = 0;
		}

		# XXX these are not stored in the DB so no need to truncate

		push @{$stats{$nportstr}}, $val;
	    }
	} else {
	    @{$stats{$nportstr}} = @nostats;
	}
    }

    return map [$allports{$_}, @{$stats{$_}}], sort {tbsort($a,$b)} keys %stats;
}

# end with 1;
1;
