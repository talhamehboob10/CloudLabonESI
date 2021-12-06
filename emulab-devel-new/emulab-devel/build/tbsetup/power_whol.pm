#!/usr/bin/perl -wT

#
# Copyright (c) 2004-2017 University of Utah and the Flux Group.
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
# Handle "Whack on LAN" reset.
# Currently we serialize the operation, one node at a time.
# Eventually we could do this in groups by putting multiple node
# MAC addrs in the magic whol packet.
#

package power_whol;

use Exporter;
@ISA = ("Exporter");
@EXPORT = qw( wholctrl );

use lib "/users/mshobana/emulab-devel/build/lib";
use libdb;
use Interface;

#
# Commands we run
#
my $TBROOT = '/users/mshobana/emulab-devel/build';
my $bossnode = 'boss';

my $TBWHOLPOWER = "$TBROOT/sbin/whol";
my $SNMPIT = "$TBROOT/bin/snmpit -q";
my $whollan = "WhOL";

my $whackall = 1;
my $dowhack = 1;
my $debug = 0;

# Turn off line buffering on output
$| = 1;

my %portinfo = ();

# usage: wholctrl(cmd, nodes)
# cmd = { "cycle" | "on" | "off" }
# nodes = list of one or more physcial node names
#
# Returns 0 on success. Non-zero on failure.
# 
sub wholctrl($$@) {
    my ($cmd, $iface, @nodes) = @_;
    my $exitval = 0;

    if ($cmd ne "cycle") {
	warn "WhOL module can only \"cycle\" nodes\n";
	return 1;
    }

    print STDERR "WhOL called with iface=$iface ", join(" ", @nodes), "\n"
	if ($debug);

    #
    # Locate the whackable interface on each node along with its mac
    # Find the boss interface while we are at it
    #
    for my $node (@nodes) {
	my $interface;
	my @interfaces = ();
	if (Interface->LookupAll($node, \@interfaces)) {
	    warn "Could not lookup interfaces for $node, skipping\n";
	    $exitval++;
	    next;
	}
	foreach my $i (@interfaces) {
	    if ($i->IsExperimental() and $i->whol()) {
		$interface = $i;
		last;
	    }
	}
	if (!defined($interface)) {
	    warn "No WhOL interface for $node, skipping\n";
	    $exitval++;
	    next;
	}
	$portinfo{$node}{"iface"} = $interface->iface();
	$portinfo{$node}{"mac"} = $interface->mac();
	print STDERR "WhOL: $node: $iface, $mac\n"
	    if ($debug);
    }

    # XXX locking

    if ($whackall) {
	if (whacksome($iface, @nodes)) {
	    $exitval++;
	}
    }
    else {
	for my $node (@nodes) {
	    my @nodelist = ($node);

	    if (whacksome($iface, @nodelist)) {
		$exitval++;
	    }
	}
    }

    # XXX unlocking

    return $exitval;
}

sub whacksome($@) {
    my ($iface, @nodelist) = @_;
    my $failed = 0;

    my @portlist = map { "$_:" . $portinfo{$_}{"iface"} } @nodelist;
    my $portstr = join(" ", @portlist);

    if ($debug) {
	print STDERR "Whackin: ", join(" ", @nodelist), "\n";
	print STDERR "Ports:   ", $portstr, "\n";
    }

    #
    # Save off the state of all ports
    #
    if (!open(SNMPIT, "$SNMPIT -b $portstr |")) {
	warn "WhOL: snmpit -b failed\n";
	return 1;
    }
    while (my $line = <SNMPIT>) {
	chomp($line);

	my %args = parseStatusString($line);
	my $port = $args{port};
	if (!$port) {
	    warn "WhOL: snmpit returned bogus status string\n";
	    return 1;
	}
	my ($node) = split(":", $port);
	# untaint
	if ($line =~ /(.*)/) {
	    $portinfo{$node}{status} = $1;
	}
    }
    if (!close(SNMPIT) || $?) {
	warn "WhOL: could not get status for ports\n";
	return 1;
    }
    if ($debug) {
	print STDERR "Old port status:\n";
	for my $key (keys(%portinfo)) {
	    print STDERR "  $key: ", $portinfo{$key}{status}, "\n"
		if ($portinfo{$key}{status});
	}
    }

    #
    # Divide the nodes up into used and unused based on the status of
    # their WhOL experimental interface:
    #
    # enabled=yes	port in use
    # enabled=no	not used
    #
    # If a port is "in use" we assume it has talked to the switch and
    # no speed/duplex changes are needed.
    #
    # If the port is unused, we assume that the port will try to auto
    # negotiate with the switch when enabled.  In this case we set
    # auto-negotiation on the switch to maximize the chance that we will
    # sucessfully communicate with the card.
    #
    my $autoneg = "";
    for my $key (keys(%portinfo)) {
	if ($portinfo{$key}{status} &&
	    $portinfo{$key}{status} =~ /enabled=no/) {
	    $autoneg .= "$key ";
	}
    }
    if ($autoneg ne "") {
	print STDERR "Setting autonegotiate on ports: $autoneg\n"
	    if ($debug);
	if (system("$SNMPIT -a $portstr")) {
	    warn "WhOL: could not set autoconfig for $portstr\n";
# not fatal for now til we fix autoneg on cisco2950s
#	    $failed++;
	}
    }

    #
    # Put all ports in the WhOL VLAN, snmpit will enable them.
    #
    if (system("$SNMPIT --whol-magic -f -m $whollan $portstr")) {
	warn "WhOL: could not place ports in WHOL LAN\n";
	$failed++;
    }
    
    #
    # Strafe the VLAN with fiery packets of death.
    #
    if (!$failed && $dowhack) {
	my $macstr = join(" ", map { $portinfo{$_}{mac} } @nodelist);

	# XXX leave time for auto-negotiation if port had to be enabled
	sleep(5);

	if (system("$TBWHOLPOWER $iface $macstr")) {
	    warn "WhOL: could not send WhOL packets\n";
	    $failed++;
	} else {
	    print STDERR "Whacked ", join(' ', @nodelist), "\n";
	}
    }

    #
    # Restore all ports to their previous state.
    # This will move ports back to their original VLANs,
    # disabling unused ports.
    #
    my $statstr = "";
    for my $node (@nodelist) {
	$statstr .= " -B '" . $portinfo{$node}{status} . "'";
    }
    if (system("$SNMPIT $statstr")) {
	warn "WhOL: could not restore port state:\n";
	for my $node (@nodelist) {
	    print STDERR "  ", $portinfo{$node}{status}, "\n";
	}
	$failed++;
    }

    return $failed;
}

#
# Snagged from snmpit.
# Parse a port status string. Returns a key-value hash pair
#
sub parseStatusString($) {
    my ($string) = @_;
    chomp $string;

    my %pairs;
    foreach my $pair (split /;/, $string) {
        my ($key, $value) = split /=/,$pair,2;
        if (!$key || !$value) {
            die "ERROR: Bad port status string: $string\n";
        } else {
            $pairs{$key} = $value;
        }
    }

    return %pairs;
}

1;
