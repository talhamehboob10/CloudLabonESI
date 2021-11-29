#!/usr/bin/perl -w

#
# Copyright (c) 2000-2018 University of Utah and the Flux Group.
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
# snmpit module for APC MasterSwitch power controllers
#
# supports new(ip), power(on|off|cyc[le],port), status
#

package snmpit_apc;

$| = 1; # Turn off line buffering on output

use SNMP;
use strict;

#
# XXX for configurations in which APC unit always returns error
# even when it works.
#
# NOTE: You can probably fix such units by instead making sure the
# controller uses the 'rPDUOutletControlOutletCommand' OID in power() below.
# The default 'sPDUOutletCtl' will work on these controllers but will return
# a '' status. I would guess that everything running "masterSwitch.6" and
# later should be using the newer OID.
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
	print "snmpit_apc module initializing... debug level $debug\n";
    }

    $SNMP::debugging = ($debug - 5) if $debug > 5;
    my $mibpath = "/usr/local/share/snmp/mibs";
    &SNMP::addMibDirs($mibpath);
    &SNMP::addMibFiles("$mibpath/SNMPv2-SMI.txt",
		       "$mibpath/SNMPv2-MIB.txt",
		       "$mibpath/RFC1155-SMI.txt",
		       "$mibpath/PowerNet-MIB.txt");
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
    default => ["sPDUOutletCtl",
		"outletOn", "outletOff", "outletReboot"],
    rPDU    => ["rPDUOutletControlOutletCommand",
		"immediateOn", "immediateOff", "immediateReboot"]
);

sub power {
    my $self = shift;
    my $op = shift;
    my @ports = @_;
    my $oids = $CtlOIDS{"default"};
    my $type = SNMP::translateObj($self->{SESS}->get("sysObjectID.0"));

    print "Got type '$type'\n" if $self->{DEBUG};
    if (defined($type)) {
	if ($type eq "masterSwitchrPDU") {
	    $oids = $CtlOIDS{"rPDU"};
	}
	# XXX wonky APC power controllers at the fort (AP7941) return
	# either masterSwitch.5 or masterSwitch.5.1.3.4.5
	elsif ($type =~ /^masterSwitch.5/) {
	    $oids = $CtlOIDS{"rPDU"};
	}
	# XXX newer APC power controllers we have (AP8941, AP7900B) need to
	# use this OID else they return an error on set operations (though
	# the operations do work!)
	elsif ($type eq "masterSwitch.6" || $type eq "masterSwitch.8") {
	    $oids = $CtlOIDS{"rPDU"};
	}
    }

#   "rPDUOutletControl" is ".1.3.6.1.4.1.318.1.1.12.3.3";
#   "sPDUOutletCtl"     is ".1.3.6.1.4.1.318.1.1.4.4.2.1.3";
    if    ($op eq "on")  { $op = @$oids[1]; }
    elsif ($op eq "off") { $op = @$oids[2]; }
    elsif ($op =~ /cyc/) { $op = @$oids[3]; }

    my $errors = 0;

    foreach my $port (@ports) {
	print STDERR "**** Controlling port $port\n" if ($self->{DEBUG} > 1);
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

# status for AP7941: .1.3.6.1.4.1.318.1.1.12.3.5
    my $StatOID = ".1.3.6.1.4.1.318.1.1.4.2.2";
    my $Status = 0;

    $Status = $self->{SESS}->get([[$StatOID,0]]);
    if (!defined $Status) {
	print STDERR $self->{DEVICENAME}, ": no answer from device\n";
	return 1;
    }
    print("Status is '$Status'\n") if $self->{DEBUG};

    if ($statusp) {
	my @stats = split '\s+', $Status;
	my $o = 1;
	foreach my $ostat (@stats) {
	    my $outlet = "outlet$o";
	    $status{$outlet} = $ostat;
	    $o++;
	}
	%$statusp = %status;
    }

    #
    # We can retrieve the total amperage in use (in tenths of amps) 
    # on an APC by retrieving the rPDULoadStatusLoad.  There are 
    # entries for each of the phases of power that the device supports,
    # and for each of the banks of power it provides.
    #
    # We could add either the phases or the banks, but since the phases
    # come first, we use them.  We grab the number of phases supported,
    # then use that as a limit on how many status load values we retrieve.
    #
    # The OID to retrieve the phases is: ".1.3.6.1.4.1.318.1.1.12.1.9"
    # for more recent units, or:         ".1.3.6.1.4.1.318.1.1.12.2.1.2"
    # for older ones;
    # the load status table OID is:      ".1.3.6.1.4.1.318.1.1.12.2.3.1.1.2".
    #
    my ($phases,$banks);

    $phases = $self->{SESS}->get([["rPDUIdentDeviceNumPhases",0]]);
    if (!$phases) {
	# not all models support this MIB, try another
	$phases = $self->{SESS}->get([["rPDULoadDevNumPhases",0]]);
	if (!$phases) {
	    # some don't support either, bail.
	    print STDERR "Query phase: IdentDeviceNumPhases/LoadDevNumPhases failed\n"
		if $self->{DEBUG};
	    return 0;
	}
    }

    $banks = $self->{SESS}->get([["rPDULoadDevNumBanks",0]]);
    if (!$banks) {
	# not clear if we really need this, so just continue
	print STDERR "Query phase: LoadDevNumBanks failed\n"
	    if $self->{DEBUG};
	$banks = 0;
    }

    print "Okay.\nPhase report was '$phases'\n" if $self->{DEBUG};
    print "Bank report was '$banks'\n" if $self->{DEBUG};
    my ($varname, $index, $power, $val, $done);
    my %perphase = ();
    my %perbank = ();
    my $oid = ["rPDULoadStatusLoad",1];

    $self->{SESS}->get($oid);
    while ($$oid[0] =~ /rPDULoad/) {
	print "rPDULoadStatusLoad returns: ", join('/', @$oid), "\n" if $self->{DEBUG} > 1;
        ($varname, $index, $val) = @{$oid};
        if ($varname eq "rPDULoadStatusLoad") {
            if ($index <= $phases) {
    		print "Raw current value $val\n" if $self->{DEBUG};
                $status{current} += $val;
		$perphase{$index} = $val;
            } elsif ($phases == 1 && $banks > 0) {
		$perbank{$index-$phases} = $val;
	    }
        }
        $self->{SESS}->getnext($oid);
    }

    if ($self->{DEBUG}) {
	print "Total raw current is $status{current}\n";
	print "Phases:\n";
	foreach my $i (sort keys %perphase) {
	    print "$i: ", $perphase{$i} / 10, "\n";
	}
	if ($banks > 0) {
	    print "Banks:\n";
	    foreach my $i (sort keys %perbank) {
		print "$i: ", $perbank{$i} / 10, "\n";
	    }
	}
    }
    $status{current} /= 10;

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
