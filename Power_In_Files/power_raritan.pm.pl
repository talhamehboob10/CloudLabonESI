#!/usr/bin/perl -w

#
# Copyright (c) 2000-2020 University of Utah and the Flux Group.
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
# snmpit module for Raritan PX2 power controllers
#
# supports new(ip), power(on|off|cyc[le],port), status
#

package power_raritan;

$| = 1; # Turn off line buffering on output

use SNMP;
use strict;
use Data::Dumper;

#
# XXX for configurations in which Raritan unit always returns error
# even when it works.
#
my $ignore_errors = 0;

sub new($$;$) {

    # The next two lines are some voodoo taken from perltoot(1)
    my $proto = shift;
    my $class = ref($proto) || $proto;

    my $devicename = shift;
    my $debug = shift;

    if (!defined($debug)) {
	$debug = 0;
    }

    if ($debug) {
	print "power_raritan module initializing... debug level $debug\n";
    }

    $SNMP::debugging = ($debug - 5) if $debug > 5;
    my $mibpath = "/usr/local/share/snmp/mibs";
    # Ubuntu, powerlocal ...
    my $mibpathalt = "/var/lib/snmp/mibs/ietf";

    foreach my $mib ("SNMPv2-SMI.txt",
		     "SNMPv2-MIB.txt",
		     "RFC1155-SMI.txt",
		     "PDU2-MIB.txt") {
	if (-e "$mibpath/$mib") {
	    &SNMP::addMibDirs($mibpath);
	    &SNMP::addMibFiles("$mibpath/$mib");
	}
	elsif (-e "$mibpathalt/$mib") {
	    &SNMP::addMibDirs($mibpathalt);
	    &SNMP::addMibFiles("$mibpathalt/$mib");
	}
    }
    $SNMP::save_descriptions = 1; # must be set prior to mib initialization
    SNMP::initMib();              # parses default list of Mib modules
    $SNMP::use_enums = 1;         #use enum values instead of only ints
    print "Opening SNMP session to $devicename..." if $debug;
    my $sess =new SNMP::Session(DestHost => $devicename, Community => 'private', Version => '1');
    if (!defined($sess)) {
	warn("ERROR: Unable to connect to $devicename via SNMP\n");
	return undef;
    }

    my $self = {};

    $self->{SESS} = $sess;
    $self->{DEBUG} = $debug;
    $self->{DEVICENAME} = $devicename;

    bless($self,$class);
    return $self;
}

my %CtlOIDS = (
# XXX symbolic names do not work for some reason
#    default => ["switchingOperation.1", "on", "off", "cycle"]
    default => [".1.3.6.1.4.1.13742.6.4.1.2.1.2.1", "on", "off", "cycle"]
);

sub power {
    my $self = shift;
    my $op = shift;
    my @ports = @_;
    my $oids = $CtlOIDS{"default"};
    my $type = SNMP::translateObj($self->{SESS}->get("sysObjectID.0"));

    print "Got type '$type'\n" if $self->{DEBUG};

    if    ($op eq "on")  { $op = @$oids[1]; }
    elsif ($op eq "off") { $op = @$oids[2]; }
    elsif ($op =~ /cyc/) { $op = @$oids[3]; }

    my $errors = 0;

    foreach my $port (@ports) {
	print STDERR "**** Controlling port $port\n" if ($self->{DEBUG} > 1);
	print STDERR "OID is: @$oids[0], operation is $op\n" if ($self->{DEBUG} > 2);
	if ($self->UpdateField(@$oids[0],$port,$op)) {
	    print STDERR "Outlet #$port control failed.\n";
	    $errors++;
	}
    }

    return $errors;
}

sub status {
    my $self = shift;
    my $statusp = shift;
    my %status;

    my $noutletsOID = ".1.3.6.1.4.1.13742.6.3.2.2.1.4.1";
    my $StatOID = ".1.3.6.1.4.1.13742.6.4.1.2.1.3.1";
    my $CurrentOID = ".1.3.6.1.4.1.13742.6.5.2.3.1.4.1.1.1";
    my $PowerOID = ".1.3.6.1.4.1.13742.6.5.2.3.1.4.1.1.5";
    my $EnergyOID = ".1.3.6.1.4.1.13742.6.5.2.3.1.4.1.1.8";

    print STDERR "**** Getting status for ports\n" if ($self->{DEBUG} > 1);
    my $noutlets = $self->{SESS}->get($noutletsOID);
    if (!defined($noutlets)) {
	print STDERR $self->{DEVICENAME}, ": no answer from device\n";
	return 1;
    }
    print STDERR "outlets: $noutlets\n" if ($self->{DEBUG} > 2);

    my @OIDs = ();
    foreach my $n (1..$noutlets) {
	push @OIDs, [$StatOID,$n];
    }
    my $vars = new SNMP::VarList(@OIDs);

    my @vals = $self->{SESS}->get($vars);
    if (!@vals) {
	print STDERR $self->{DEVICENAME}, ": no answer from device\n";
	return 1;
    }
    print("Status is '", join(' ', @vals), "'\n") if $self->{DEBUG};
    
    my $o = 1;
    foreach my $ostat (@vals) {
	my $outlet = "outlet$o";
	$status{$outlet} = $ostat;
	$o++;
    }

    print STDERR "**** Getting current/power/enerty for PDU\n"
	if ($self->{DEBUG} > 1);
    @OIDs = ([$CurrentOID], [$PowerOID], [$EnergyOID]);
    $vars = new SNMP::VarList(@OIDs);
    @vals = $self->{SESS}->get($vars);
    if ($vals[0] && $vals[0] =~ /^(\d+)$/) {
	my $val = sprintf("%.1f", $1 / 10);
	print STDERR "current: $val\n" if ($self->{DEBUG} > 2);
	$status{current} = $val;
    }
    if ($vals[1] && $vals[1] =~ /^(\d+)$/) {
	my $val = $1;
	print STDERR "power: $val\n" if ($self->{DEBUG} > 2);
	$status{power} = $val;
    }
    if ($vals[2] && $vals[2] =~ /^(\d+)$/) {
	my $val = sprintf("%.3f", $1 / 1000);
	print STDERR "active energy: $val\n" if ($self->{DEBUG} > 2);
	$status{energy} = $val;
    }
    if ($statusp) {
	%$statusp = %status;
    }

    return 0;
}

sub UpdateField {
    my ($self,$OID,$port,$val) = @_;

    print "sess=$self->{SESS} $OID $port $val\n" if $self->{DEBUG} > 1;

    my $Status = 0;
    my $retval;

    print "Checking port $port of $self->{DEVICENAME} for $val..." if $self->{DEBUG};
    $Status = $self->{SESS}->get([[$OID,$port]]);
    if (!defined $Status) {
	print STDERR "Port $port, change to $val: No answer from device\n";
	return 1;
    } else {
	print "Okay.\nPort $port was $Status\n" if $self->{DEBUG};
	if ($Status ne $val) {
	    print "Setting $port to $val..." if $self->{DEBUG};
	    $retval = $self->{SESS}->set([[$OID,$port,$val,"INTEGER"]]);
	    $retval = "" if (!defined($retval));
	    print "Set returned '$retval'\n" if $self->{DEBUG};
	    if ($retval) {
		return 0;
	    }
	    # XXX warn, but otherwise ignore errors
	    if ($ignore_errors) {
		print STDERR "WARNING: $port '$val' failed, ignoring\n";
		return 0;
	    }
	    return 1;
	}
	return 0;
    }
}

# End with true
1;
