#!/usr/bin/perl -w

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
# Copyright (c) 2000-2020 University of Utah and the Flux Group.
# Copyright (c) 2004-2015 Regents, University of California.
# All rights reserved.
#

#
# snmpit module for HP procurve and flexfabric (comware) switches.
# The Comware module (snmpit_h3c) inherits from the base (snmpit_hp) class.
#

# XXX: krw: Rename base HP module here so that we don't actually use
#      this for the procurve models until I have more time to integrate.
package snmpit_hpupd;
use strict;

$| = 1; # Turn off line buffering on output

use English;
use SNMP;
use File::Temp qw(tempfile);
use lib '/usr/testbed/lib';
use snmpit_lib;

use libtestbed;
use Port;

#
# These are the commands that can be passed to the portControl function
# below
#
my %cmdOIDs =
(
    "enable" => ["ifAdminStatus","up"],
    "disable"=> ["ifAdminStatus","down"],
    "1000mbit"=> ["hpSwitchPortFastEtherMode","auto-1000Mbits"],
    "100mbit"=> ["hpSwitchPortFastEtherMode","auto-100Mbits"],
    "10mbit" => ["hpSwitchPortFastEtherMode","auto-10Mbits"],
    "auto"   => ["hpSwitchPortFastEtherMode","auto-neg"],
    "full"   => ["hpSwitchPortFastEtherMode","full"],
    "half"   => ["hpSwitchPortFastEtherMode","half"],
);

#
# some long OIDs that get used frequently.
#
my $normOID = "dot1qVlanStaticUntaggedPorts";
my $forbidOID = "dot1qVlanForbiddenEgressPorts";
my $egressOID = "dot1qVlanStaticEgressPorts";
my $aftOID = "dot1qPortAcceptableFrameTypes";
my $createOID = "dot1qVlanStaticRowStatus";

#
# Enterprise OID for toggling jumbo frame support on a vlan
#
my $jumboOID = '1.3.6.1.4.1.11.2.14.11.5.1.12.1.8.1.1.1';

#
# Openflow OIDs, only number format now.
#
#my $ofOID = 'iso.org.dod.internet.private.enterprises.11.2.14.11.5.1.7.1.35';
my $ofOID = '1.3.6.1.4.1.11.2.14.11.5.1.7.1.35';
my $ofEnableOID     = $ofOID.'.1.1.2';
my $ofControllerOID = $ofOID.'.1.1.3';
my $ofListenerOID   = $ofOID.'.1.1.4';
my $ofFailModeOID   = $ofOID.'.1.1.11';
my $ofSupportOID    = $ofOID.'.2.1.0';

# This string is enough now, but the Openflow OID may change in future. 
# The maintainers should keep in mind of this ID. 
my $ofListenerVarNameMarker = '35.1.1.4';

#
# Ports can be passed around in three formats:
# ifindex: positive integer corresponding to the interface index (eg. 42)
# modport: dotted module.port format, following the physical reality of
#	Cisco switches (eg. 5.42)
# nodeport: node:port pair, referring to the node that the switch port is
# 	connected to (eg. "pc42:1")
#
# See the function convertPortFormat below for conversions between these
# formats
#
my $PORT_FORMAT_IFINDEX  = 1;
my $PORT_FORMAT_MODPORT  = 2;
my $PORT_FORMAT_NODEPORT = 3;  # XXX - not used anymore here.
my $PORT_FORMAT_PORT = 4;

#
# Creates a new object.
#
# usage: new($classname,$devicename,$debuglevel,$community)
#        returns a new object, blessed into the snmpit_intel class.
#
sub new($$$;$) {

    # The next two lines are some voodoo taken from perltoot(1)
    my $proto = shift;
    my $class = ref($proto) || $proto;

    my $name = shift;
    my $debugLevel = shift;
    my $authstr = shift;

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
    $self->{BLOCK} = 1;
    $self->{CONFIRM} = 1;
    $self->{NAME} = $name;

    #
    # Get config options from the database
    #
    my $options = getDeviceOptions($self->{NAME});
    if (!$options) {
	warn "ERROR: Getting switch options for $self->{NAME}\n";
	return undef;
    }

    $self->{MIN_VLAN}         = $options->{'min_vlan'};
    $self->{MAX_VLAN}         = $options->{'max_vlan'};

    # If no auth string was passed to the constructor, get value from DB.
    if (!$authstr) {
	$authstr = $options->{'snmp_community'};
    }
    # Grab extra auth parameters, if set.
    my ($community, $username, $passwd) = split(/:/, $authstr);
    $self->{COMMUNITY} = $community;
    if ($username) {
	$self->{USERNAME} = $username;
    } else {
	$self->{USERNAME} = "snmpit";
    }
    if ($passwd) {
	$self->{PASSWORD} = $passwd;
    } else {
	$self->{PASSWORD} = $community;
    }
    if (exists($options->{'sshkey'})) {
	$self->{SSHKEY} = $options->{'sshkey'};
    }
    else {
	$self->{SSHKEY} = undef;
    }

    # Use jumbo frames?
    if (exists($options->{'use_jumbo'}) 
	&& $options->{'use_jumbo'} == 1) {
	$self->{DOJUMBO} = 1;
    } else {
	$self->{DOJUMBO} = 0;
    }

    # Funky switch (firmware) that cannot manipulate BAGGs with snmp.
    if (exists($options->{'badBAGG'}) && $options->{'badBAGG'} == 1) {
	$self->{BADBAGG} = 1;
    } else {
	$self->{BADBAGG} = 0;
    }

    # Use VRF for OF controller communication (H3C)?
    if (exists($options->{'openflow_vrf'})
	&& $options->{'openflow_vrf'}) {
	$self->{OFVRF} = $options->{'openflow_vrf'};
    } else {
	$self->{OFVRF} = undef;
    }

    #
    # set up hashes for internal use
    #
    $self->{IFINDEX} = {};
    $self->{TRUNKINDEX} = {};
    $self->{TRUNKS} = {};
    $self->{IFDESCR} = {};
    $self->{cmdOIDs} = \%cmdOIDs;

    # other global variables
    $self->{DOALLPORTS} = 0;
    $self->{DOALLPORTS} = 1;
    $self->{SKIPIGMP} = 1;

    if ($self->{DEBUG}) {
	print "snmpit_hp initializing $self->{NAME}, " .
	    "debug level $self->{DEBUG}\n" ;   
    }


    #
    # Set up SNMP module variables, and connect to the device
    #
    $SNMP::debugging = ($self->{DEBUG} - 2) if $self->{DEBUG} > 2;
    my $mibpath = '/usr/local/share/snmp/mibs';
    &SNMP::addMibDirs($mibpath);
    &SNMP::addMibFiles("$mibpath/SNMPv2-SMI.txt", "$mibpath/SNMPv2-TC.txt", 
	               "$mibpath/SNMPv2-MIB.txt", "$mibpath/IANAifType-MIB.txt",
		       "$mibpath/IF-MIB.txt", "$mibpath/BRIDGE-MIB.txt", 
		       "$mibpath/IEEE8023-LAG-MIB.txt",
		       "$mibpath/HP-ICF-OID.txt", "$mibpath/HH3C-OID-MIB.txt",
		       "$mibpath/HH3C-SPLAT-INF.txt", 
		       "$mibpath/HH3C-PRODUCT-ID.txt");
    $SNMP::save_descriptions = 1; # must be set prior to mib initialization
    SNMP::initMib();		  # parses default list of Mib modules 
    $SNMP::use_enums = 1;	  # use enum values instead of only ints

    warn ("Opening SNMP session to $self->{NAME}...") if ($self->{DEBUG});

    $self->{SESS} = new SNMP::Session(DestHost => $self->{NAME},Version => "2c",
	Timeout => 3000000, Retries=> 9, Community => $self->{COMMUNITY});

    if (!$self->{SESS}) {
	#
	# Bomb out if the session could not be established
	#
	warn "WARNING: Unable to connect via SNMP to $self->{NAME}\n";
	return undef;
    }
    #
    # The bless needs to occur before readifIndex(), since it's a class 
    # method
    #

    #
    # Sometimes the SNMP session gets created when there is no connectivity
    # to the device so let's try something simple
    #
    my $test_case = snmpitGet($self->{SESS}, ["sysObjectID", 0], 1);
    if (!defined($test_case)) {
	warn "WARNING: Unable to retrieve via SNMP from $self->{NAME}\n";
	return undef;
    }
    $self->{HPTYPE} = SNMP::translateObj($test_case);

    warn ("Queried switch type: $self->{HPTYPE}\n") if ($self->{DEBUG});

    if ($test_case =~ '^.1.3.6.1.4.1.25506') {
       my $sysDescr = snmpitGet($self->{SESS}, ['sysDescr', 0], 1);
       $class = $self->{H3C} =
               ($sysDescr =~ / Version 5\./) ? 'snmpit_h3cv5' : 'snmpit_h3c';
    }
    bless($self,$class);
    $self->readifIndex();

    return $self;
}

# Attempt to repeat an action until it succeeds

sub hammer($$$;$) {
    my ($self, $closure, $id, $retries) = @_;

    if (!defined($retries)) { $retries = 12; }
    for my $i (1 .. $retries) {
	my $result = $closure->();
	if (defined($result) || ($retries == 1)) { return $result; }
	warn $id . " ... will try again\n";
	sleep 1;
    }
    warn  $id . " .. giving up\n";
    return undef;
}

# shorthand

sub printSnmpErr($$) {
    my ($sess, $id) = @_;
    if ($sess->{ErrorNum}) {
	print "$id had error number " . $sess->{ErrorNum} .
		  " and had error string " . $sess->{ErrorStr} . "\n";
    }
}

sub get1($$$) {
    my ($self, $obj, $instance) = @_;
    my $id = $self->{NAME} . "::get1($obj.$instance)";
    my $closure = sub () {
	my $RetVal = snmpitGet($self->{SESS}, [$obj, $instance], 1);
	if (!defined($RetVal)) { sleep 4;}
	return $RetVal;
    };
    my $RetVal = $self->hammer($closure, $id, 40);
    printSnmpErr($self->{SESS}, $id)
	if (!defined($RetVal));
    return $RetVal;
}

sub set($$;$$) {
    my ($self, $varbind, $id, $retries) = @_;
    if (!defined($id)) { $id = $self->{NAME} . ":set "; }
    if (!defined($retries)) { $retries = 2; }
    my $sess = $self->{SESS};
    my $closure = sub () {
	my $RetVal = $sess->set($varbind);
	my $status = $RetVal;
	if (!defined($RetVal)) {
	    $status = "(undefined)";
	    printSnmpErr($sess, $id);
	}
	return $RetVal;
    };
    my $RetVal = $self->hammer($closure, $id, $retries);
    return $RetVal;
}

sub mirvPortSet($) {
    my ($bitfield) = @_;
    #$bitfield = substr($bitfield,0,127); XXX: yuck.
    my $unpacked = unpack("B*",$bitfield);
    return [split //, $unpacked];
}

sub testPortSet($$) {
    my ($bitfield, $index) = @_;
    return @{mirvPortSet($bitfield)}[$index];
}

#
# opPortSet($op, $bitfield, @indices)
# set or clear bits in a port set,  $op > 0 means set, otherwise clear
#
sub opPortSet($$@) {
    my ($op, $bitfield, @indices) = @_;
    my @bits = mirvPortSet($bitfield);

    foreach my $index (@indices) { $bits[$index] = $op > 0 ? 1 : 0; }

    return pack("B*", join('',@bits));
}

# Translate a list of ifIndexes to a PortSet

sub listToPortSet($@)
{
    my $self = shift;
    my @ports = @_;

    my ($max, $portbitstring, $portSet, $port);
    my @portbits;

    $self->debug("listToPortsSet: input @ports\n",2);
    if (scalar @ports) {
	@ports = sort { $b <=> $a} @ports;
	$max = ($ports[0] | 7);
    } else { $max = 7 ; }
    $port = 0;
    while ($port <= $max) { $portbits[$port] = 48 ; $port++; }
    while (scalar @ports) { $port = pop @ports; $portbits[$port - 1] = 49; }
    $self->debug("portbits after insertions: @portbits\n",2);
    $portbitstring = pack "C*", @portbits;
    $self->debug("listToPortSet output string $portbitstring \n");
    $portSet = pack "B*", $portbitstring ;
    return $portSet;
}

# Translate a PortSet to a list of ifIndexes

sub bitSetToList($)
{
    my ($arrayref) = @_;
    my @ports = ();
    my $max = scalar (@$arrayref);

    for (my $port = 0; $port < $max; $port++)
	{ if (@$arrayref[$port]) { push @ports, (1 + $port); } }
    return @ports;
}

sub portSetToList($$) {
    my ($self, $portset) = @_;
    return bitSetToList(mirvPortSet($portset));
}

sub getOidToMappedList($$$) {
    my ($self, $oid, $idx) = @_;
    if (my $bits = $self->get1($oid,$idx)) {
	return $self->portSetToList($bits);
    } else { return (); }
}

sub trunkedPorts($@) {
    my ($self, @ports) = @_;
    my ($trunks, $dualPorts, $modes, $pids, $j, @nports) = ({}, {});
    @$dualPorts{$self->portSetToList($self->get1($forbidOID,1))} = undef;
    if (@ports) {
	$modes = [ map { [ $aftOID, $_ ] } @ports ];
	$j = $self->{SESS}->get($modes);
    } else {
	($modes) = $self->{SESS}->bulkwalk(0,32, [$aftOID]);
    }
    foreach my $aref (@$modes) {
	my ($name, $ifIndex, $val) = @$aref;
	if ($val eq 'admitOnlyVlanTagged') {
	    $$trunks{$ifIndex} = 1;
	} elsif (exists($$dualPorts{$ifIndex})) {
	    $$trunks{$ifIndex} = $self->get1('dot1qPvid', $ifIndex);
	}
    }
    return ($trunks);
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
sub portControl ($$@) {
    my $self = shift;

    my $cmd = shift;
    my @ports = @_;
    my $cmdOIDs = $self->{cmdOIDs};

    $self->debug("portControl: $cmd -> (@ports)\n");

    #
    # Find the command in the %cmdOIDs hash (defined at the top of this file).
    # Some commands involve multiple SNMP commands, so we need to make sure
    # we get all of them
    #
    if (defined $$cmdOIDs{$cmd}) {
	my @oid = @{$$cmdOIDs{$cmd}};
	my $errors = 0;

	while (@oid) {
	    my $myoid = shift @oid;
	    my $myval = shift @oid;
	    $errors += $self->UpdateField($myoid,$myval,@ports);
	}
	return $errors;
    } else {
	#
	# Command not supported
	#
	$self->debug("Unsupported port control command '$cmd' ignored.\n");
	return 0;
    }
}

#
# Get a vlan's ifindex given it's tag
#
sub getVlanIfindexFromTag($$) {
    my ($self, $tag) = @_;
    my $id = $self->{NAME} . "::getVlanIfindexFromTag";

    my ($rows) = snmpitBulkwalkFatal($self->{SESS}, ["ifDescr"]);

    if (!@$rows) {
	warn "$id: ERROR: No interface description rows returned ".
	     "while attempting to search for vlan ifindex!\n";
	return undef;
    }

    foreach my $rowref (@$rows) {
	my ($name,$ifindex,$descr) = @$rowref;
	next unless $descr =~ /VLAN(\d+)/i;
	if ($tag == $1) {
	    return $ifindex;
	}
    }

    warn "$id: no ifindex found for vlan with tag: $tag\n";
    return undef;
}

#
# Set jumbo frames on a vlan
#
sub setVlanJumbo($$) {
    my ($self, $tag) = @_;
    my $id = $self->{NAME} . "::setVlanJumbo";

    my $vifindex = $self->getVlanIfindexFromTag($tag);
    goto bad if !defined($vifindex);

    $self->debug("id: Enabling jumbo frames on vlan $tag (ifindex: $vifindex)\n");

    my $res = $self->set([$jumboOID,$vifindex,1,"INTEGER"], $id);
    goto bad if !defined($res);

    return 0;

  bad:
    warn "$id: Could not enable jumbo frames for vlan with tag: $tag\n";
    return 1;
}



#
# HP's refuse to create vlans with display names that can
# be interpreted as vlan numbers
#
sub convertVlanName($) {
	my $id = shift;
	my $new;
	if ( $id =~ /^_(\d+)$/) {
	    $new = $1;
	    return ((($new > 0) && ($new  < 4095)) ? $new : $id);
	}
	if ( $id =~ /^(\d+)$/) {
	    $new = $1;
	    return ((($new > 0) && ($new  < 4095)) ? "_$new" : $id);
	}
	return $id;
}

#
# Try to pull a VLAN number out of a long OID string
#
sub parseVlanNumberFromOID($) {
    my ($oid) = @_;
    # OID must be a dotted string
    my (@elts) = split /\./, $oid;
    if (scalar(@elts) < 2) {
        return undef;
    }
    # Second-to-last element must be the right text string or numeric ID
    if ($elts[$#elts-1] eq "dot1qVlanStaticName" || $elts[$#elts-1] eq "1") {
        # Last element must be numeric
        if ($elts[$#elts] =~ /\d+/) {
            return $elts[$#elts];
        } else {
            return undef;
        }
    } else {
        return undef;
    }
}

sub checkLACP($$) {
   my ($self, $port) = @_;
   if (my $j = $self->{TRUNKINDEX}{$port})
       { $port = $j + $self->{TRUNKOFFSET}; }
   return $port;
}

#
# Convert a set of ports to an alternate format. The input format is detected
# automatically. See the declarations of the constants at the top of this
# file for a description of the different port formats.
#
# usage: convertPortFormat($self, $output format, @ports)
#        returns a list of ports in the specified output format
#        returns undef if the output format is unknown
#
# TODO: Add debugging output, better comments, more sanity checking
#
sub convertPortFormat($$@) {
    my $self = shift;
    my $output = shift;
    my @ports = @_;
    my @results = ();

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
	warn "convertPortFormat: Given a bad list of ports\n";
	return undef;
    }

    my $input;
    SWITCH: for ($sample) {
    	(Port->isPort($sample)) && do { $input = $PORT_FORMAT_PORT; last; };
	(/^\d+$/) && do { $input = $PORT_FORMAT_IFINDEX; last; };
	(/^\d+\.\d+$/) && do { $input = $PORT_FORMAT_MODPORT; last; };
	(/^$self->{NAME}\.\d+\/\d+$/) && do { $input = $PORT_FORMAT_MODPORT;
		@ports = map {/^$self->{NAME}\.(\d+)\/(\d+)$/; "$1.$2";} @ports; last; };
	warn "convertPortFormat: Unknown input port format: $sample\n"; 
	return ();
    }

    #
    # It's possible the ports are already in the right format
    #
    if ($input == $output) {
	if ($input == $PORT_FORMAT_IFINDEX) {
	    @results = map $self->checkLACP($_), @ports;
	    goto done;
	}
	$self->debug("Not converting, input format = output format\n",3);
	return @ports;
    }

    my $name = $self->{NAME};
    if ($input == $PORT_FORMAT_IFINDEX) {
	my $ifxModport = sub ($) {
	    my ($port, $modport) = ($_, $self->{IFINDEX}{$_});
	    print "$name: no modport for ifindex $port\n" unless ($modport);
	    return $modport ? $modport : "1.$port";
	};
	my @modports = map $ifxModport->($_), @ports;
	if ($output == $PORT_FORMAT_MODPORT) {
	    $self->debug("Converting ifindex to modport\n",3);
	    @results = @modports;
	    goto done;
	} elsif ($output == $PORT_FORMAT_PORT) {
	    $self->debug("Converting ifindex to Port object\n",3);
	    @results = map Port->LookupByStringForced("$name:$_"), @modports;
	    goto done;
	}
    } elsif ($input == $PORT_FORMAT_MODPORT) {
	if ($output == $PORT_FORMAT_IFINDEX) {
	    $self->debug("Converting modport to ifindex\n",3);
	    @results = map $self->{IFINDEX}{$_}, @ports;
	    goto done;
	} elsif ($output == $PORT_FORMAT_PORT) {
	    $self->debug("Converting modport to Port object\n",3);
	    @results = map Port->LookupByStringForced("$name:$_"), @ports;
	    goto done;
	}
    } elsif ($input == $PORT_FORMAT_PORT) { 
    	if ($output == $PORT_FORMAT_IFINDEX) {
            $self->debug("Converting Port object to ifindex\n",3);
            @results = map $self->{IFINDEX}{(split /:/,
                                         ($_->node_id() eq $self->{NAME})?
                                         $_->toTripleString():
                                         $_->getOtherEndTripleString()
                )[1]}, @ports;
	    goto done;
        } elsif ($output == $PORT_FORMAT_MODPORT) {
            $self->debug("Converting Port object to modport\n",3);
            @results = map { (split /:/,
                          ($_->node_id() eq $self->{NAME})?
                          $_->toTripleString():
                          $_->getOtherEndTripleString()
                )[1]} @ports;
	    goto done;
	}
    }

    #
    # Some combination we don't know how to handle
    #
    warn "convertPortFormat: Bad input/output combination ($input/$output)\n";
    return ();

  done:
    #
    # The control flow change was to facilitate trying to debug an
    # odd problem in Utah on the procuve-geni switches.
    #
    if (@results) {
	foreach my $port (@results) {
	    my $inport = shift(@ports);
	    if (!defined($port)) {
		print STDERR "convertPortFormat: Bad conversion for $inport ".
		    "($input/$output)\n";
		return ();
	    }
	    #print STDERR "convertPortFormat: $inport/$port\n";
	}
    }
    return @results;
}
# 
# Check to see if the given 802.1Q VLAN tag exists on the switch
#
# usage: vlanNumberExists($self, $vlan_number)
#        returns 1 if the VLAN exists, 0 otherwise
#
sub vlanNumberExists($$) {
    my ($self, $vlan_number) = @_;

    my $rv = $self->get1("dot1qVlanStaticRowStatus", $vlan_number);
    if (!defined($rv) || !$rv || $rv ne "active") {
	return 0;
    }
    return 1;
}

#
# Given VLAN indentifiers from the database, finds the 802.1Q VLAN
# number for them. If not VLAN id is given, returns mappings for the entire
# switch.
# 
# usage: findVlans($self, @vlan_ids)
#        returns a hash mapping VLAN ids to 802.1Q VLAN numbers
#        any VLANs not found have NULL VLAN numbers
#
sub findVlans($@) { 
    my $self = shift;
    my @vlan_ids = @_;
    my %mapping = ();
    my $id = $self->{NAME} . "::findVlans";
    my ($count, $name, $vlan_number, $vlan_name) = (scalar(@vlan_ids));
    $self->debug("$id\n");

    if ($count > 0) { @mapping{@vlan_ids} = undef; }

    #
    # Find all VLAN names. Do one to get the first field...
    #
    my ($rows) = $self->{SESS}->bulkwalk(0,32, ["dot1qVlanStaticName"]);
    foreach my $rowref (@$rows) {
	($name,$vlan_number,$vlan_name) = @$rowref;
	$self->debug("$id: Got $name $vlan_number $vlan_name\n",2);
        # Hack to get around some strange behavior
        if ((!defined($vlan_number) || $vlan_number eq "") &&
                defined(parseVlanNumberFromOID($name))) {
            $vlan_number = parseVlanNumberFromOID($name);
            $self->debug("Changed vlan_number to $vlan_number\n",3);
        }
	$vlan_name = convertVlanName($vlan_name);
	#
	# We only want the names - we ignore everything else
	#
	    if (!@vlan_ids || exists $mapping{$vlan_name}) {
		$self->debug("$id: $vlan_name=>$vlan_number\n",2);
		$mapping{$vlan_name} = $vlan_number;
	    }
    }

    return %mapping;
}

#
# Given a VLAN identifier from the database, find the 802.1Q VLAN
# number that is assigned to that VLAN. Retries several times (to account
# for propagation delays) unless the $no_retry option is given.
#
# usage: findVlan($self, $vlan_id,$no_retry)
#        returns the VLAN number for the given vlan_id if it exists
#        returns undef if the VLAN id is not found
#
sub findVlan($$;$) { 
    my $self = shift;
    my $vlan_id = shift;
    my $no_retry = shift;
    my $id = $self->{NAME} . ":findVlan";

    $self->debug("$id ( $vlan_id )\n",2);
    my $max_tries = $no_retry ? 1 : 5;
    #
    # We try this a few times, with 5 second sleeps, since it can take
    # a while for VLAN information to propagate
    #
    my $closure = sub () {
	my %mapping = $self->findVlans($vlan_id);
	my $vlan_number = $mapping{$vlan_id};
	if (defined($vlan_number)) { return $vlan_number; }
	sleep 4;
	return undef;
    };
    return $self->hammer($closure,$id,$max_tries);
}

#   
# Create a VLAN on this switch, with the given identifier (which comes from
# the database) and given 802.1Q tag number.
#
# usage: createVlan($self, $vlan_id, $vlan_number)
#        returns the new VLAN number on success
#        returns 0 on failure
#
sub createVlan($$$;$) {
    my $self = shift;
    my $vlan_id = shift;
    my $vlan_number = shift;
    my $otherargs = shift;
    my $id = $self->{NAME} . ":createVlan";

    if (!defined($vlan_number)) {
	warn "$id called without supplying vlan_number";
	return 0;
    }
    my $check_number = $self->findVlan($vlan_id,1);
    if (defined($check_number)) {
	if ($check_number != $vlan_number) {
		warn "$id: recreating vlan id $vlan_id which has ".
		     "existing vlan number $check_number with the new number ".
		     "$vlan_number\n";
		     return 0;
	}
     }
    my $vlan ="$vlan_number";
    my $hpvlan_id = convertVlanName("$vlan_id");
    my $VlanName = 'dot1qVlanStaticName'; # vlan # is index
    $self->debug("createVlan: name $vlan_id number $vlan_number \n");
    #
    # Perform the actual creation. Yes, this next line MUST happen all in
    # one set command....
    #
    my $closure = sub () {
    	my $RetVal = $self->set
	       ([[$VlanName,$vlan,$hpvlan_id,"OCTETSTR"],
	     [$createOID,$vlan, "createAndGo","INTEGER"]], "$id: creation");
	if (defined($RetVal)) { return $RetVal; }
	#
	# Sometimes we loose responses, or on the second time around
	# it might refuse to create a vlan that's already there, so wait
	# a bit to see if it exists (also so as to not get too agressive
	# with the switch which caused nortels to crash with IGMP stuff)
	#
	sleep (2);
	$RetVal = $self->get1($createOID, $vlan);
	if (defined($RetVal) && ($RetVal ne "active")) { return undef ;}
	return $RetVal;
    };
    my $RetVal = $self->hammer($closure, "$id: creation");
    if (!defined($RetVal)) { return 0; }
    print "  Creating VLAN $vlan_id as VLAN #$vlan_number on " .
	    "$self->{NAME} ...\n";

    #
    # Check that it happened.
    #
    $RetVal = $self->get1($VlanName, $vlan);
    if (!defined($RetVal) || ("$RetVal" ne $hpvlan_id)) {
	warn "$id: created vlan $vlan_id with name $RetVal" .
	  "instead of $hpvlan_id\n";
    }

    #
    # Enable jumbo frames, if switch option is set.
    #
    if ($self->{DOJUMBO}) {
	if ($self->setVlanJumbo($vlan_number) != 0) {
	    warn "$id: enable jumbo failed for vlan $vlan_id ...\n";
	}
    }

    if ($self->{SKIPIGMP}) { return $vlan_number ; }

    my $IgmpEnable = 'hpSwitchIgmpState';
    $RetVal = $self->get1($IgmpEnable, $vlan);

    $closure = sub () {
	my $check = $self->set([[$IgmpEnable,$vlan,"enable","INTEGER"]]);
	if (!defined($check)) { sleep (5);}
	return $check;
    };
    $RetVal = $self->hammer($closure, "$id: setting snooping", 3);
    if (!defined($RetVal)) { return 0; }

    $closure = sub () {
	my $check = $self->get1($IgmpEnable, $vlan);
	if (!defined($check) || ($check ne "enable"))
		{ sleep (4); return undef ;}
	return $check;
    };
    $RetVal = $self->hammer($closure, "$id: checking snooping");
    if (!defined($RetVal)) { return 0; }

    return $vlan_number;
}
#
# gets the forbidden, untagged, and egress lists for a vlan
# sends back as a 3 element array of lists.  (Thats the order
# the packet traces for the HP had them in).
#
sub getVlanLists($$) {
    my ($self, $vlan) = @_;
    my $ret = [0, 0, 0];
    @$ret[0] = $self->{H3C} ? [0] : mirvPortSet($self->get1($forbidOID, $vlan));
    @$ret[1] = mirvPortSet($self->get1($normOID, $vlan));
    @$ret[2] = mirvPortSet($self->get1($egressOID, $vlan));
    return $ret;
}

#
# sets the forbidden, untagged, and egress lists for a vlan
# sends back as a 3 element array of lists.
# (Thats the order we saw in a tcpdump of vlan creation.)
# (or in some cases 6 elements for 2 vlans).
#
sub setVlanLists($@) {
    my ($self, @args) = @_;
    my $oids = [$forbidOID, $normOID, $egressOID];
    my $j = 0; my $todo = [ 0 ];
    while (@args) {
	my $vlan = shift @args;
	my $arrayref = shift @args;
	foreach my $i (0, 1, 2) {
	    next if (($i != 2) && $self->{H3C});
	    @$todo[$j++] = [ @$oids[$i], $vlan,
		    pack("B*",join('', @{@$arrayref[$i]})), "OCTETSTR"];
	}
    }
    $j = $self->set($todo);
    if (!defined($j)) { print "vlists failed\n";}
    return $j;
}

#
# Some design comments about HP switch conventions:

# This code was written after having observed packet traces while
# running the HP management tool, which appeared to remove a port
# from a vlan merely by getting and setting the 3 OID in getVlanLists
# or transferred it between vlans by setting a pair of the 3 OIDS.

# It seems that a port may be an untagged member of at most one vlan
# but may be a tagged member of several others,  i.e. the packets
# ared rx'd from the port or tx'd to the port with vlan tags added.

# If a port appears only in the $egressOIDs and never in a $normOID
# (so that it is like a normal interswitch single wire trunk), the
# The $aftOID = admitOnlyVlanTagged, without our having to set it.

# The OID describing the PVID of a port seem to correspond to
# the untagged membership of the port in some vlan, and it does
# not seem necessary to set this OID either.

# In this case, the port has $aftOID (dot1QPortAceptableFrameType) = admitAll.

# If we want the port to be like dual mode port on a foundry or cisco, we can
# merely add the port to the egress OID of any additonal vlan.

# However, if a switch belongs to a unique vlan, and is an untagged member,
# there would be no way to determine if the intent was to be a dual mode port
# or for the port have the semantics of most other switches, i.e. adding it
# to one vlan takes it out of the first.

# Since this is the common case, we record the dual mode intent
# by marking the port as being forbidden to join vlan 1.

#
# Put the given ports in the given VLAN. The VLAN is given as an 802.1Q 
# tag number.
#
# usage: setPortVlan($self, $vlan_number, @ports)
#	 returns 0 on sucess.
#	 returns the number of failed ports on failure.
#
sub setPortVlan($$@) {
    my $self = shift;
    my $vlan_number = shift;
    my @ports = @_;

    my $id = $self->{NAME} . "::setPortVlan($vlan_number)";
    $self->debug($id);
    my %vlansToPorts; # i.e. bumpedVlansToListOfPorts
    my @newTaggedPorts = ();
    my ($errors, $portIndex, $pvid, $rv, @protoTrunks) = (0);
	   
    #
    # Run the port list through portmap to find the ports on the switch that
    # we are concerned with
    #

    return 0 unless(@ports);
    my @portlist = $self->convertPortFormat($PORT_FORMAT_IFINDEX, @ports);
    return -1
	if (!@portlist);
    $self->debug("ports: " . join(",",@ports) . "\n");
    $self->debug("as ifIndexes: " . join(",",@portlist) . "\n");

    #
    # Need to determine status and remove ports from default_vlan
    # before adding to other.  This is a read_modify_write so lock out
    # other instances of snmpit_hp.

    my $defaultInfo = $self->getVlanLists(1);
    foreach $portIndex (@portlist) {
	# check for three easy cases
	# a. known dual port.
	# b. the ports is not allocated
	# c. the port is a trunk

	# case a: This is a dual port, so it doesn't have to leave its PVID.
	if (@{@$defaultInfo[0]}[$portIndex - 1]) {
	    push @newTaggedPorts, $portIndex;
	    next;
	}
	# case b: Unallocated untrunked port.
	if (@{@$defaultInfo[1]}[$portIndex - 1]) {
	    $pvid = 1;
	} else {
	    my $tagOnly = $self->get1($aftOID,$portIndex);
	    if ($tagOnly eq "admitOnlyVlanTagged") {
		# case c: Trunk Port
		if (@{@$defaultInfo[2]}[$portIndex - 1]) {
		    # Total grot - happens when port was made an equal trunk
		    # having no vlans, so is on vlan 1, and might be disabled.
		    # It might also be the case that this version of the driver
		    # is being run for the first time on a switch where
		    # we were previously sloppier about membership in vlan 1.
		    push @protoTrunks, $portIndex;
		}
		push @newTaggedPorts, $portIndex;
		next;
	    } else {
		# case d: untrunked port leaving another vlan.
		# a little more work - get its PVID and assume that
		# is the vlan which it is leaviing. and toss it
		# into the bumpedVlan hash.
		$pvid = $self->get1("dot1qPvid", $portIndex);
	    }
	}
	push @{$vlansToPorts{$pvid}}, $portIndex # autovivifies if null
	    if (defined($pvid) && ($pvid != $vlan_number));
    }
    @{$self->{DISPLACED_VLANS}} = grep {$_ != 1;} keys %vlansToPorts;
 
    $self->lock();
    my $newInfo = $self->getVlanLists($vlan_number);
    foreach my $vlan (keys %vlansToPorts) {
	my $oldInfo = $self->getVlanLists($vlan) ;
	foreach $portIndex (@{$vlansToPorts{$vlan}}) {
	    @{@$oldInfo[1]}[$portIndex-1] = 0;
	    @{@$newInfo[1]}[$portIndex-1] = 1;
	    @{@$oldInfo[2]}[$portIndex-1] = 0;
	    @{@$newInfo[2]}[$portIndex-1] = 1;
	}
	$self->setVlanLists($vlan, $oldInfo, $vlan_number, $newInfo);
    }

    # Now add tagged ports separately, just to be safe.

    if (@newTaggedPorts) {
	foreach $portIndex (@newTaggedPorts)
		{ @{@$newInfo[2]}[$portIndex-1] = 1; }
	$self->setVlanLists($vlan_number, $newInfo);
    }
    $self->unlock();

    # We need to make sure the ports get enabled, and protoTrunks cleaned up.

    if (@protoTrunks) {
	$rv = $self->delPortVlan(1, @protoTrunks) +
		    $self->portControl("enable", @protoTrunks);
	$errors += $rv;
	warn "$id: $rv failures with protoTrunks\n"
	     if ($rv);
    }

    my $onoroff = ($vlan_number ne "1") ? "enable" : "disable";
    $self->debug("$id; will $onoroff"  . join(',',@ports) . "...\n");
    if ( $rv = $self->portControl($onoroff, @ports) ) {
	warn "$id: Port enable had $rv failures.\n";
	$errors += $rv;
    }

    return $errors;
}

sub not_in($$@) {
    my $self = shift;
    my $value = shift;
    my @list = @_;

    return 0 == scalar(grep {$_ == $value;} @list);
}

#
# Remove the given ports from the given VLAN. The VLAN is given as an 802.1Q 
# tag number.
#
# usage: delPortVlan($self, $vlan_number, @ports)
#	 returns 0 on sucess.
#	 returns the number of failed ports on failure.
#
sub delPortVlan($$@) {
    my $self = shift;
    my $vlan_number = shift;
    my @ports = @_;

    return $self->updateOneVlan(0,0,0,$vlan_number,@ports);
}

sub updateOneVlan($$$$$@)
{
    my ($self,$forbid,$untag,$mem,$vlan_number,@ports) = @_;

    $self->debug($self->{NAME} . "::updateOneVlan($untag,$mem,$vlan_number) ");
	   
    #
    # Run the port list through portmap to find the ports on the switch that
    # we are concerned with
    #

    $self->lock();
    my @portlist = $self->convertPortFormat($PORT_FORMAT_IFINDEX, @ports);
    return -1
	if (!@portlist);
    $self->debug("ports: " . join(",",@ports) . "\n");
    $self->debug("as ifIndexes: " . join(",",@portlist) . "\n");

    my $vlist = $self->getVlanLists($vlan_number);
    foreach my $port (@portlist) {
	next if ($self->{ifx2d1dx} && !($port = $self->{ifx2d1dx}{$port}));
	@{@$vlist[0]}[$port - 1] = $forbid if ($vlan_number eq "1");
	@{@$vlist[1]}[$port - 1] = $untag;
	@{@$vlist[2]}[$port - 1] = $mem;
    }
    my $result = $self->setVlanLists($vlan_number, $vlist);
    if (!defined($result)) {
	print STDERR $self->{NAME} .
	    ": updateOneVlan($forbid,$untag,$mem,$vlan_number) failed for: ";
	foreach my $port (@ports) {
	    my $ifindex = shift(@portlist);
	    print STDERR "$port:$ifindex ";
	}
	print STDERR "\n";
    }
    $self->unlock();
    return defined($result) ? 0 : 1;
}

#
# Disables all ports in the given VLANS. Each VLAN is given as a VLAN
# 802.1Q tag value.
#
# usage: removePortsFromVlan(self,@vlan)
#	 returns 0 on sucess.
#	 returns the number of failed ports on failure.
#
sub removePortsFromVlan($@) {
    my $self = shift;
    my @vlan_numbers = @_;
    my $errors = 0;
    my $id = $self->{NAME} . "::removePortsFromVlan";

    foreach my $vlan_number (@vlan_numbers) {
	my @ports = $self->portSetToList($self->get1($egressOID, $vlan_number));
	if (@ports) {
	    $errors += $self->removeSomePortsFromVlan($vlan_number, @ports);
	}
    }
    return $errors;
}

#
# Removes and disables some ports in a given VLAN.
# The VLAN is given as a VLAN 802.1Q tag value.
#
# usage: removeSomePortsFromVlan(self,vlan,@ports)
#	 returns 0 on sucess.
#	 returns the number of failed ports on failure.
#
sub removeSomePortsFromVlan($$@) {
    my ($self, $vlan_number, @ports) = @_;
    my ($errors, $changes, $id, %porthash, $tagOnly, $pvid) =
	(0, 0, $self->{NAME} . "::removeSomePortsFromVlan");

    # Callers should know better.
    return 0
	if (!@ports);

    @ports = $self->convertPortFormat($PORT_FORMAT_IFINDEX,@ports);
    return -1
	if (! @ports);
    @porthash{@ports} = @ports;
    my $dualPorts = mirvPortSet($self->get1($forbidOID, 1)); # array

    foreach my $portIndex (@ports) {
	if (@$dualPorts[$portIndex-1]) {
	    # We make any dual ports whose PVID is this vlan into equaltrunks.
	    # A dualtrunked port whose primary vlan is not this vlan
	    # can be deleted by the code dealing with normal ports
	    $pvid = $self->get1("dot1qPvid", $portIndex);
	    next if ("$pvid" ne $vlan_number);
	    $self->updateOneVlan(0,0,1,$vlan_number,$portIndex); #make tagged
	    $self->updateOneVlan(0,0,0,1,$portIndex); # clear dual marker.
	    # fall through to next case
	}
	$tagOnly = $self->get1($aftOID,$portIndex);
	if ($tagOnly eq "admitOnlyVlanTagged") {
	    if ($self->delPortVlan($vlan_number, $portIndex)) {
		# assume it failed because it belonged to no other vlans
		# so add it to vlan 1 and try again.
		$self->updateOneVlan(0,0,1,1,$portIndex);
		if ($self->delPortVlan($vlan_number, $portIndex)) {
		    warn "$id: failed to remove ifIndex $portIndex\n";
		}
	    }
	    delete $porthash{$portIndex};
	}
    }

    # Now, remove the remaining ports from the vlan.
    $self->lock();
    my $defaultLists = $self->getVlanLists(1);
    my $vLists = $self->getVlanLists($vlan_number);
    my @portlist = bitSetToList(@$vLists[2]);
    $self->debug("$id $vlan_number: @portlist\n",2);

    foreach my $portIndex (@portlist) {
	next unless exists($porthash{$portIndex});
	if (@{@$vLists[1]}[$portIndex - 1]) {
	    # otherwise, port is tagged.

	    @{@$defaultLists[1]}[$portIndex - 1] = 1;
	    @{@$defaultLists[2]}[$portIndex - 1] = 1;
	    $self->debug("disabling port $portIndex  "
			    . "from vlan $vlan_number \n" );
	    $self->set(["ifAdminStatus",$portIndex,"down","INTEGER"],$id);
	}
	@{@$vLists[1]}[$portIndex - 1] = 0;
	@{@$vLists[2]}[$portIndex - 1] = 0;
	$changes++;
    }
    $errors += $self->setVlanLists($vlan_number, $vLists, 1, $defaultLists)
	    if ($changes > 0);
    $self->unlock();
    return $errors;
}

#
# Remove the given VLANs from this switch. Removes all ports from the VLAN,
# The VLAN is given as a VLAN identifier from the database.
#
# usage: removeVlan(self,int vlan)
#	 returns 1 on success
#	 returns 0 on failure
#
#
sub removeVlan($@) {
    my $self = shift;
    my @vlan_numbers = @_;
    my $errors = 0;
    my $name = $self->{NAME};

    $self->removePortsFromVlan(@vlan_numbers);
    foreach my $vlan_number (@vlan_numbers) {
	#
	# Perform the actual removal
	#
	print "  Removing VLAN # $vlan_number ... ";
	my $RetVal = $self->set([[$createOID,$vlan_number,"destroy","INTEGER"]]);
	if ($RetVal) {
	    print "Removed VLAN $vlan_number on switch $name.\n";
	} else {
	    print STDERR "Removing VLAN $vlan_number failed on switch $name.\n";
	    $errors++;
	}
	# The next call would buy time to let switch consolidate itself
	# Nortels have bizarre failures when quickly creating and destroying
	# vlans with IGMP snooping enabled.
	# $self->{SESS}->bulkwalk(0,32,[$createOID]);
    }
    return ($errors == 0) ? 1 : 0;
}

#
# XXX: Major cleanup
#
sub UpdateField($$$@) {
    my ($self, $OID, $val, @ports)= @_;
    my $id = $self->{NAME} . "::UpdateField OID $OID value $val";
    $self->debug("$id: ports @ports\n");

    my $result = 0;
    my $oidval = $val;
    my ($Status, $portname, $row);


    foreach $portname (@ports) {
	($row) = $self->convertPortFormat($PORT_FORMAT_IFINDEX,$portname);
	next
	    if (!defined($row));
	$self->debug("checking row $row for $val ...\n");
	$Status = $self->get1($OID,$row);
	if (!defined($Status)) {
	    print STDERR "id: Port $portname No answer from device\n";
	    next;
	}
	$self->debug("Port $portname, row $row was $Status\n");
	if ($OID eq "hpSwitchPortFastEtherMode") {
	    #
	    # Procurves use the same mib variable to set both
	    # speed and duplex concurrently; only certain
	    # combinations are permitted.  (We won't support
	    # auto-10-100MBits. And at least the 5400 series
	    # doesn't seem to support full-duplex-1000Mbits.)
	    #
	    my @state = split "-", $Status;
	    if (($val eq "half") || ($val eq "full")) {
		if ($state[0] eq "auto") {
		    if (($state[1] eq "neg") || ($state[1] eq "10")) {
			# can't autospeed with specific duplex.
			$oidval = ($val eq "half") ?
			   "half-duplex-100Mbits" : "full-duplex-100Mbits";
		    } elsif ($state[1] eq "1000Mbits") {
			$oidval = $Status;
		    } else {
			$oidval = $val . "-duplex-" . $state[1] ;
		    }
		} else {
			$oidval = $val . "-duplex-" . $state[2] ;
		}
	    } else {
		if (($val eq "auto-neg") || ($val eq "auto-1000Mbits") ||
			($state[1] ne "duplex")) {
		    $oidval = $val;
		} else {
		    my @valarr = split "-", $val;
		    $oidval = $state[0] . "-duplex-" . "$valarr[1]";
		}
	    }
	}
	if ($Status ne $oidval) {
	    $self->debug("Setting $portname (r $row) to $oidval...");
	    $Status = $self->set([[$OID,$row,$oidval,"INTEGER"]]);
	    $result =  (defined($Status)) ? 0 : -1;
	    $self->debug($result ? "failed.\n" : "succeeded.\n");
	}
    }
    return $result;
}

#
# Determine if a VLAN has any members 
# (Used by stack->switchesWithPortsInVlan())
#
sub vlanHasPorts($$) {
    my ($self, $vlan_number) = @_;

    my $portset = $self->get1($egressOID,$vlan_number);
    if (defined($portset)) {
	my @ports = $self->portSetToList($portset);
	if (@ports) { return 1; }
    }
    return 0;
}

#
# List all VLANs on the device
#
# usage: listVlans($self)
# see snmpit_cisco_stack.pm for a description of return value format
#
sub listVlans($) {
    my $self = shift;

    my (%Names, %Numbers, %Members, %Normports);
    my ($vlan_name, $oid, $vlan_number, $value, $rowref);
    my ($modport, $node, $ifIndex, @portlist, @memberlist);
    $self->debug($self->{NAME} . "::listVlans()\n",1);
    my $maxport = $self->{MAXPORT};

    #
    # Walk the tree to find the VLAN names
    #
    my ($rows) = $self->{SESS}->bulkwalk(0,32,["dot1qVlanStaticName"]);
    foreach $rowref (@$rows) {
	($oid, $vlan_number, $vlan_name) = @$rowref;
	$self->debug("Got $oid $vlan_number $vlan_name\n",3);
        # Hack to get around some strange behavior
        if ((!defined($vlan_number) || $vlan_number eq "") &&
                defined(parseVlanNumberFromOID($oid))) {
            $vlan_number = parseVlanNumberFromOID($oid);
            $self->debug("Changed vlan_number to $vlan_number\n",3);
        }
	next if ("$vlan_number" eq "1");
	$vlan_name = convertVlanName($vlan_name);
	if (!$Names{$vlan_number}) {
	    $Names{$vlan_number} = $vlan_name;
	    @{$Members{$vlan_number}} = ();
	}
    }

    #
    #  Walk the tree for the VLAN members
    #
    ($rows) = $self->{SESS}->bulkwalk(0,32,["dot1qVlanStaticEgressPorts"]);
    foreach $rowref (@$rows) {
	($oid,$vlan_number,$value) = @$rowref;
	next if ("$vlan_number" eq "1");
	@portlist = $self->portSetToList($value);
	if ($self->{d1dx2ifx}) {
	    @portlist = map { $self->{d1dx2ifx}{$_}} @portlist ;
	}
	$self->debug("Got $oid $vlan_number @portlist\n",3);

	foreach $ifIndex (@portlist) {
	    ($node) = $self->convertPortFormat($PORT_FORMAT_PORT,$ifIndex);
	    if (!$node) {
		($modport) = $self->convertPortFormat
				    ($PORT_FORMAT_MODPORT,$ifIndex);
		$node = Port->LookupByStringForced($self->{NAME} . ":$modport");
	    }
	    # Let's be clear about what kind of connection this is and
	    # get the right port object.  If there is an endpoint here,
	    # get that.  If this is a trunk, then the member we want to
	    # put in the list is the "local" side (this switch's port).
	    my $mbrport;
	    if ($node->is_trunk_port()) {
		$mbrport = $node;
	    } else {
		# getOtherEndPort() will return the object upon which the
		# method is invoked if it fails to lookup the other side.
		$mbrport = $node->getOtherEndPort();
	    }
	    push @{$Members{$vlan_number}}, $mbrport;
	    $self->debug("$self->{NAME}:$vlan_number $node:$mbrport\n", 3);

	    if (!$Names{$vlan_number}) {
		$self->debug("listVlans: WARNING: port $node in non-existant " .
		    "VLAN $vlan_number\n", 1);
	    }
	}
    }

    #
    # Build a list from the name and membership lists
    #
    my @list = ();
    foreach my $vlan_id (sort keys %Names) {
	push @list, [$Names{$vlan_id},$vlan_id,$Members{$vlan_id}];
    }

    #$self->debug($self->{NAME} .":". join("\n",(map {join ",", @$_} @list))."\n");
    return @list;
}

#
# List all ports on the device
#
# usage: listPorts($self)
# see snmpit_cisco_stack.pm for a description of return value format
#
sub listPorts($) {
    my $self = shift;

    my %Able = ();
    my %Link = ();
    my %auto = ();
    my %speed = ();
    my %duplex = ();

    my $ifTable = ["ifAdminStatus",0];

    #
    # Get the ifAdminStatus (enabled/disabled) and ifOperStatus
    # (up/down)
    #
    my ($varname, $modport, $ifIndex, $portIndex, $status, $portname);
    $self->{SESS}->getnext($ifTable);
    do {
	($varname,$ifIndex,$status) = @{$ifTable};
	$self->debug("$varname $ifIndex $status\n");
	if (($ifIndex <= $self->{MAXPORT}) && ($varname =~ /AdminStatus/)) { 
	    $Able{$ifIndex} = ($status =~/up/ ? "yes" : "no");
	}
	$self->{SESS}->getnext($ifTable);
    } while ( $varname =~ /^ifAdminStatus$/) ;

    #
    # Get the port configuration, including speed, duplex, and whether or not
    # it is autoconfiguring
    #
    foreach $ifIndex (keys %Able) {
	if ($status = $self->{SESS}->get(["ifOperStatus",$ifIndex])) {
	    $Link{$ifIndex} = $status;
	}
        if ($self->{H3C}) {
            if ($status = $self->get1("hh3cifEthernetSpeed",$ifIndex))
                { $speed{$ifIndex} = $status; }
            if ($status = $self->get1("hh3cifEthernetDuplex",$ifIndex))
                { $duplex{$ifIndex} = $status; }
            next;
        }
	# HP combines speed and duplex and it has to be teased apart lexically.
	if ($status = $self->get1("hpSwitchPortFastEtherMode",$ifIndex)) {
	    my @parse = split("-duplex-", $status);
	    if (2 == scalar(@parse)) {
		$duplex{$ifIndex} = $parse[0];
		$speed{$ifIndex} = $parse[1];
	    } else {
		@parse = split("auto-",$status);
		$duplex{$ifIndex} = "auto";
		$speed{$ifIndex} = $parse[1];
		if ($speed{$ifIndex} eq "neg") {
		    $speed{$ifIndex} = "auto";
		}
	    }
	}
    };

    #
    # Put all of the data gathered in the loop into a list suitable for
    # returning
    #
    my @rv = ();
    foreach my $id ( keys %Able ) {
	$modport = $self->{IFINDEX}{$id};
	$portname = $self->{NAME} . ":$modport";
	my $port = Port->LookupByTriple($portname); 
	if (defined($port)) {
		$port = $port->getOtherEndPort();
	}

	#
	# Skip ports that don't seem to have anything interesting attached
	#
	if (!$port && $self->{DOALLPORTS}) {
		$modport =~ s/\./\//;
		$port = Port->LookupByStringForced($self->{NAME} . ":$modport");
	}
	if (!$port) {
	    $self->debug("$id ($modport) not connected, skipping\n");
	    next;
	}
	if (! defined ($speed{$id}) ) { $speed{$id} = " "; }
	if (! defined ($duplex{$id}) ) { $duplex{$id} = " "; }
	push @rv, [$port,$Able{$id},$Link{$id},$speed{$id},$duplex{$id}];
    }
    return @rv;
}

# 
# Get statistics for ports on the switch
#
# usage: getStats($self)
# see snmpit_cisco_stack.pm for a description of return value format
#
#
sub getStats() {
    my $self = shift;

    #
    # Walk the tree for the VLAN members
    #
    my $vars = new SNMP::VarList(['ifInOctets'],['ifInUcastPkts'],
    				 ['ifInNUcastPkts'],['ifInDiscards'],
				 ['ifInErrors'],['ifInUnknownProtos'],
				 ['ifOutOctets'],['ifOutUcastPkts'],
				 ['ifOutNUcastPkts'],['ifOutDiscards'],
				 ['ifOutErrors'],['ifOutQLen']);
    my @stats = $self->{SESS}->bulkwalk(0,32,$vars);

    #
    # We need to flip the two-dimentional array we got from bulkwalk on
    # its side, and convert ifindexes into node:port
    #
    my $i = 0;
    my %stats;
    foreach my $array (@stats) {
	while (@$array) {
	    my ($name,$ifindex,$value) = @{shift @$array};

            # See comments in walkTable above.

            if (! defined $self->{IFINDEX}{$ifindex}) { next; }
            my $po = convertPortFromString("$self->{NAME}:".$self->{IFINDEX}{$ifindex});
            if (! defined $po) { next; } # Skip if we don't know about it
            my $port = $po->getOtherEndPort()->toTripleString();
            
	    ${$stats{$port}}[$i] = $value;
	}
	$i++;
    }

    return map [convertPortFromString($_),@{$stats{$_}}], sort {tbsort($a,$b)} keys %stats;
}

#
# Used to flush FDB entries easily
#
# usage: resetVlanIfOnTrunk(self, modport, vlan)
#
sub resetVlanIfOnTrunk($$$) {
    my ($self, $modport, $vlan) = @_;
    my ($ifIndex) = $self->convertPortFormat($PORT_FORMAT_IFINDEX,$modport);
    return -1
	if (!$ifIndex);
    $self->debug($self->{NAME} . "::resetVlanIfOnTrunk m $modport "
		    . "vlan $vlan ifIndex $ifIndex\n",1);
    if ($self->{d1dx2ifx}) { $ifIndex = $self->{d1dx2ifx}{$ifIndex}; }
    my $vlan_ports = $self->get1($egressOID, $vlan);
    if (testPortSet($vlan_ports, $ifIndex - 1)) {
	$self->setVlansOnTrunk($modport,0,$vlan);
	$self->setVlansOnTrunk($modport,1,$vlan);
    }
    return 0;
}

#
# Get the ifindex for an EtherChannel (trunk given as a list of ports)
#
# usage: getChannelIfIndex(self, ports)
#        Returns: undef if more than one port is given, and no channel is found
#           an ifindex if a channel is found and/or only one port is given
#
# N.B. by Sklower - cisco's use this to put vlans on multiwire trunks;
# it gets called from _stack.pm
#
# HP's also require a different ifindex for putting a vlan on a multiwire
# trunk from the individual ifindex from any constituent port.
#
# although Rob Ricci's vision is that this would only get called when putting
# vlans on multi-wire interswitch trunks and the check would happen in
# _stack, it is 1.) possible to use snmpit -i Switch <mod>/<port> to do
# maintenance functions of vlans and so you should check for each port
# any way, and 2.) the check is cheap and can be done in convertPortFormat.
#
sub getChannelIfIndex($@) {
    my $self = shift;
    my @ports = @_;
    my @ifIndexes = $self->convertPortFormat($PORT_FORMAT_IFINDEX,@ports);
    my $ifindex = undef;

    return undef
	if (! @ifIndexes);

    #
    # Try to get a channel number for each one of the ports in turn - we'll
    # take the first one we get
    #
    foreach my $port (@ifIndexes) {
        if ($port) { $ifindex = $port; last; }
    }
    return $ifindex;
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

    #
    # Some error checking
    #
    if (($value != 1) && ($value != 0)) {
	warn "$id: Invalid value $value.\n";
	return 0;
    }
    if (grep(/^1$/,@vlan_numbers)) {
	warn "$id: will not set port $modport on VLAN 1.\n";
	return 0;
    }
    $self->debug("$id: m $modport v $value nums @vlan_numbers\n");
    my ($ifIndex) = $self->convertPortFormat($PORT_FORMAT_IFINDEX, $modport);
    return undef
	if (! $ifIndex);

    #
    # Make sure ostensible trunk is either trunk or dual mode
    #
    my $trunks = $self->trunkedPorts($ifIndex);
    if (!$$trunks{$ifIndex}) {
	warn "$id: port $modport is not trunked.\n";
	return 0;
    }

    #
    # Look to see if this is an aggregate on a switch we have marked as not
    # being able to manipulate BAGGs with snmp. The ifIndex is already
    # converted if its a BAGG, so the easiest way to check is to compare to
    # the base trunk offset.
    #
    if ($self->{BADBAGG} && $ifIndex > $self->{"TRUNKOFFSET"}) {
	return $self->setVlansOnBAGG($ifIndex, $value, @vlan_numbers);
    }
    foreach my $vlan_number (@vlan_numbers) {
	if ($self->updateOneVlan(0, 0, $value, $vlan_number, $modport))  {
	    $errors++;
	    warn "$id:couldn't " .  (($value == 1) ? "add" : "remove") .
		    " port $modport on vlan $vlan_number\n" ;
	}
    }
    return !$errors;
}

#
# 
#
sub setVlansOnBAGG($$$@)
{
    my ($self, $bagIndex, $value, @vlan_numbers) = @_;
    my $id = $self->{NAME} . "::setVlansOnBAGG";

    # We need the BAGG name.
    my $bagName = $self->{IFDESCR}->{$bagIndex};

    my $cmdstr = "interface $bagName\n";
    if (!$value) {
	$cmdstr .= "undo ";
    }
    $cmdstr .= "port trunk permit vlan " . join(' ', @vlan_numbers) . "\n";
    $self->debug("$id: $cmdstr\n");
    my $clires = $self->doH3CNetconfCLI($cmdstr);
    if (!defined($clires)) {
	warn "$id: Internal error setting BAGG membership on $bagName: " .
	    join(' ', @vlan_numbers) . "\n";
	return 0;
    }
    if ($clires =~ /^\s+(%.+)$/m) {
	warn "id: Error returned from CLI:\n" . "\t$1\n";
	return 0;
    }
    return 1;
}

#
# Enable trunking on a port
#
# usage: enablePortTrunking2(self, modport, nativevlan, equaltrunking[, drop])
#        modport: module.port of the trunk to operate on
#        nativevlan: VLAN number of the native VLAN for this trunk
#	 equaltrunk: don't do dual mode; tag PVID also.
#	 exclude: need to choose something other than this, which actually
#        is the current PVID for this port.
#        Returns 1 on success, 0 otherwise
#
sub enablePortTrunking2($$$$) {
    my ($self,$port,$native_vlan,$equaltrunking) = @_;
    my ($ifIndex) = $self->convertPortFormat($PORT_FORMAT_IFINDEX,$port);
    return 0
	if (!$ifIndex);
    my $id = $self->{NAME} .
		"::enablePortTrunking($port,$native_vlan,$equaltrunking)";
    my ($defLists, $rv);
		
    if ((!$equaltrunking) && (!defined($native_vlan) || ($native_vlan <= 1))) {
	warn "$id: inappropriate or missing PVID for trunk\n";
	return 0;
    }
    #
    # Deal with already trunked ports here, so as to not disrupt traffic
    #
    my $tagOnly = $self->get1($aftOID,$ifIndex);
    my $dualPorts = mirvPortSet($self->get1($forbidOID, 1)); # array
    my $pvid = $self->get1("dot1qPvid", $ifIndex);
    if ($tagOnly eq "admitOnlyVlanTagged") {
	if ($equaltrunking) {
	    # We've been called redundantly, so just add the vlan
	    return 1 if ($native_vlan eq "1");
	    # the following enables empty trunks and drops vlan 1 from them;
	    return ! $self->setPortVlan($native_vlan, $port);
	} else {
	    # update to dual mode
	    return (!$self->updateOneVlan(0, 1, 1, $native_vlan, $port)) # untag
		    && (!$self->updateOneVlan(1, 0, 0, 1, $port)); # mark
	}
    } elsif (@$dualPorts[$ifIndex-1]) {
	if ($equaltrunking) {
	    $rv = $self->updateOneVlan(0, 0, 0, 1, $port) || # clear marker
		$self->updateOneVlan(0, 0, 1, $pvid, $port) || # make untagged
		(($native_vlan ne "$pvid") &&
		    $self->updateOneVlan(0, 0, 1, $native_vlan, $port));
	    return !$rv;
	}
	return 1 if ($native_vlan eq "$pvid"); # port already member
	$self->updateOneVlan(0, 0, 1, $pvid, $port); # make pvid tagged
	$self->updateOneVlan(0, 1, 1, $native_vlan, $port); # make untagged
    } elsif ($native_vlan ne "$pvid") {
	warn "$id: Unable to add Trunk to native VLAN\n"
	    if $self->setPortVlan($native_vlan, $port);
    }
    #
    # Set port type apropriately.
    #
    if ($equaltrunking) {
	$rv = $self->updateOneVlan(0, 0, 1, $native_vlan, $port); # untag
    } else {
	$rv = $self->updateOneVlan(1, 0, 0, 1, $port); # mark dual
    }
    return  !$rv;
}

#
# Internal helper for trunking
#
sub otherTrunkedVlans($$$)
{
    my ($self, $portIndex, $pvid) = @_;
    my @others;
    #
    # we have to walk all of the blasted vlans to find out
    # which ones have this port as a member.
    #
    my ($rows) = $self->{SESS}->bulkwalk(0,32, [$egressOID]);
    foreach my $rowref (@$rows) {
	my ($ignored_name, $vnum, $portset) = @$rowref;
        push @others, $vnum
	    if (testPortSet($portset, $portIndex - 1) && ($vnum ne "$pvid"));
    }
    return @others;
}

#
# Disable trunking on a port
#
# usage: disablePortTrunking(self, modport)
#        Returns 1 on success, 0 otherwise
#
sub disablePortTrunking($$) {
    my ($self, $port) = @_;
    my $id = $self->{NAME} . "::disablePortTrunking($port)";

    my ($portIndex) = $self->convertPortFormat($PORT_FORMAT_IFINDEX,$port);
    if (!$portIndex) {
	warn "$id: Unable convert $port to ifindex\n";
	return 0;
    }
    my $native_vlan = $self->get1("dot1qPvid",$portIndex) || 1;
    my @remvlans = $self->otherTrunkedVlans($portIndex, $native_vlan);

    if ($native_vlan eq "1") {
	$self->updateOneVlan(0, 1, 1, 1, $port); # make untagged
	warn "$id: Unable to disable former equaltrunk\n"
	    if ($self->portControl("disable",$port));
    } else {
	$self->updateOneVlan(0, 0, 0, 1, $port); # clear marker
	$self->updateOneVlan(0, 1, 1, $native_vlan, $port); # make untagged;
    }
    foreach my $vlan_number (@remvlans) {
	warn "$id: Unable to remove VLAN $vlan_number\n"
	   if $self->delPortVlan($vlan_number, $portIndex);
    }
    return 1;
}

my %blade_sizes = ( 
   hpSwitchJ8697A => 24, # hp5406zl
   hpSwitchJ8698A => 24, # hp5412zl
   hpSwitchJ8770A => 24, # hp4204
   hpSwitchJ8773A => 24, # hp4208
);

sub calcModPort($$) {
    my ($self, $ifindex) = @_;
    my ($j, $port, $mod);
    my $bladesize = $blade_sizes{$self->{HPTYPE}};
    if ($self->{H3C}) {
        if ($j = $self->{IFINDEX}{$ifindex})
            { return $j; }
        else { return "0.$ifindex"; }
    }
    if (defined($bladesize)) {
	$j = $ifindex - 1;
	$port = 1 + ($j % $bladesize);
	$mod = 1 + int ($j / $bladesize);
    } else
	{ $mod = 1; $port = $ifindex; }
    return "$mod.$port";
}

#
# Reads the IfIndex table from the switch, for SNMP functions that use 
# IfIndex rather than the module.port style. Fills out the objects IFINDEX
# members,
#
# usage: readifIndex(self)
#        returns nothing but sets the instance variable IFINDEX.
#
# TODO: XXXXXXXXXXXXXXXXXXXXXXX - the 288 is a crock; 
# for some reason doing an swalk of ifType returns 161 instead of
# "ieee8023adLag"; we should walk ifType look for the least ifIndex of
# that type and walk hpSwitchPortTrunkType looking for the least lacpTrk
# to figure out the offset.

sub readifIndex($) {
    my $self = shift;
    my ($maxport, $maxtrunk, $name, $ifindex, $iidoid, $port, $mod, $j) = (0,0);
    $self->debug($self->{NAME} . "::readifIndex:\n", 2);

    my ($rows) = snmpitBulkwalkFatal($self->{SESS}, ["hpSwitchPortTrunkGroup"]);
    my $t_off = $self->{TRUNKOFFSET} = 288;

    foreach my $rowref (@$rows) {
	($name,$ifindex,$iidoid) = @$rowref;
	$self->debug("got $name, $ifindex, iidoid $iidoid\n", 2);
	$self->{TRUNKINDEX}{$ifindex} = $iidoid;
	if ($iidoid) { push @{$self->{TRUNKS}{$iidoid}}, $ifindex; }
	if ($ifindex > $maxport) { $maxport = $ifindex;}
	if ($iidoid > $maxtrunk) { $maxtrunk = $iidoid;}
    }
    while (($ifindex, $iidoid) = each %{$self->{TRUNKINDEX}}) {
	my $modport = $self->calcModPort($ifindex);
	my $portindex = $iidoid ? ($t_off + $iidoid) : $ifindex ;
	$self->{IFINDEX}{$modport} = $portindex;
	$self->{IFINDEX}{$ifindex} = $modport;
	$self->debug("$ifindex, $modport\n", 2);
    }
    foreach $j (keys %{$self->{TRUNKS}}) {
	$ifindex = $j + $t_off;
	if (my $lref = $self->{TRUNKS}{$j}) {
	    $port = $self->{IFINDEX}{@$lref[0]}; #actually modport
	} else {  $port = "1." . $ifindex; } # the else should never happen
	$self->{IFINDEX}{$ifindex} = $port;
	$self->{IFINDEX}{$port} = $ifindex;
	$self->{TRUNKINDEX}{$ifindex} = 0; # simplifies convertPortIndex
	$self->debug("$ifindex, $port\n", 2);
    }
    $self->{MAXPORT} = $maxport;
    $self->{MAXTRUNK} = $maxtrunk;
}


#
# Read a set of values for all given ports.
#
# usage: getFields(self,ports,oids)
#        ports: Reference to a list of ports, in any allowable port format
#        oids: A list of OIDs to reteive values for
#
# On sucess, returns a two-dimensional list indexed by port,oid
#
sub getFields($$$) {
    my $self = shift;
    my ($ports,$oids) = @_;

    my @ifindicies = $self->convertPortFormat($PORT_FORMAT_IFINDEX,@$ports);
    return ()
	if (! @ifindicies);
    my @oids = @$oids;


    #
    # Put together an SNMP::VarList for all the values we want to get
    #
    my @vars = ();
    foreach my $ifindex (@ifindicies) {
	foreach my $oid (@oids) {
	    push @vars, ["$oid","$ifindex"];
	}
    }

    #
    # If we try to ask for too many things at once, we get back really bogus
    # errors. So, we limit ourselves to an arbitrary number that, by
    # experimentation, works.
    #
    my $maxvars = 16;
    my @results = ();
    while (@vars) {
	my $varList = new SNMP::VarList(splice(@vars,0,$maxvars));
	my $rv = $self->{SESS}->get($varList);
	push @results, @$varList;
    }
	    
    #
    # Build up the two-dimensional list for returning
    #
    my @return = ();
    foreach my $i (0 .. $#ifindicies) {
	foreach my $j (0 .. $#oids) {
	    my $val = shift @results;
	    $return[$i][$j] = $$val[2];
	}
    }

    return @return;
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

my $lock_held = 0;

sub lock($) {
    my $self = shift;
    my $token = "snmpit_" . $self->{NAME};
    if ($lock_held == 0) {
	my $old_umask = umask(0);
	die if (TBScriptLock($token,0,1800) != TBSCRIPTLOCK_OKAY());
	umask($old_umask);
    }
    $lock_held = 1;
}

sub unlock($) {
	if ($lock_held == 1) { TBScriptUnlock();}
	$lock_held = 0;
}

#
# Enable Openflow
#
sub enableOpenflow($$) {
    my $self = shift;
    my $vlan = shift;
    my $RetVal;
    
    $RetVal = $self->set([$ofEnableOID, $vlan, 1, "INTEGER"]);
    if (!defined($RetVal)) {
	warn "ERROR: Unable to enable Openflow on VLAN $vlan\n";
	return 0;
    }
    return 1;
}

#
# Disable Openflow
#
sub disableOpenflow($$) {
    my $self = shift;
    my $vlan = shift;
    my $RetVal;
    
    $RetVal = $self->set([$ofEnableOID, $vlan, 2, "INTEGER"]);
    if (!defined($RetVal)) {
	warn "ERROR: Unable to disable Openflow on VLAN $vlan\n";
	return 0;
    }
    return 1;
}

#
# Set controller
#
sub setOpenflowController($$$$) {
    my $self = shift;
    my $vlan = shift;
    my $controller = shift;
    my $option = shift;
    my $RetVal;
    
    $RetVal = $self->set([$ofControllerOID, $vlan, $controller, "OCTETSTR"]);
    if (!defined($RetVal)) {
	warn "ERROR: Unable to set controller on VLAN $vlan\n";
	return 0;
    }
    if (defined($option) && $option eq "fail-secure") {
	$RetVal = $self->set([$ofFailModeOID, $vlan, 1, "INTEGER"]);
	if (!defined($RetVal)) {
	    warn "ERROR: Unable to set controller option $option ".
		"on VLAN $vlan\n";
	    return 0;
	}
    }
    return 1;
}

#
# Set listener
#
sub setOpenflowListener($$$) {
    my $self = shift;
    my $vlan = shift;
    my $listener = shift;
    my $RetVal;
    
    $RetVal = $self->set([$ofListenerOID, $vlan, $listener, "OCTETSTR"]);
    if (!defined($RetVal)) {
	warn "ERROR: Unable to set listener on VLAN $vlan\n";
	return 0;
    }
    return 1;
}

#
# Get used listener ports
#
sub getUsedOpenflowListenerPorts($) {
    my $self = shift;
    my %ports = ();

    my $listener = [$ofListenerOID,0];

    #
    # Get all listeners and gather their ports
    #
    my ($varname, $vlan, $connstr);
    $self->{SESS}->getnext($listener);
    do {
	($varname, $vlan, $connstr) = @{$listener};
	$self->debug("listener: $varname $vlan $connstr \n");
	if ($varname =~ /$ofListenerVarNameMarker/) {
	    my ($proto, $port) = split(":", $connstr);
	    if (defined($port)){
                $ports{$port} = 1;
            }
	    
	    #
	    # the SNMP session with MIB gives varname with strings not numbers, but
	    # the string names can't be used to get the next entry in table! So we
	    # have to use the numbered OID. To get the next entry, we must
	    # append the current instance ID, which is the last section of the dotted
	    # varname, to the numbered OID.
	    #
	    my $lastdot = rindex($varname, '.');
	    $listener->[0] = $ofListenerOID.".".substr($varname, $lastdot+1);
	    $self->{SESS}->getnext($listener);
	}	
    } while ($varname =~ /$ofListenerVarNameMarker/);

    return %ports;
}


#
# Check if Openflow is supported on this switch
#
sub isOpenflowSupported($) {
    my $self = shift;
    my $ret;
    
    $ret = $self->get1($ofSupportOID, 0);
    if (defined($ret) && $ret ne 'NOSUCHOBJECT') {
	return 1;
    } else {
	return 0;
    }
}

##############################################################################
###                         H3C/Comware module                             ###
##############################################################################

package snmpit_h3c;
use strict;
use English;
use XML::LibXML;
use File::Temp qw(tempfile);
use snmpit_lib;
use snmpit_libNetconf;
use vars qw(@ISA);
@ISA = 'snmpit_hpupd';

# Some differences between h3c switches earlier HP switches:

# The literature claims that it supports the IETF P and Q bridge mibs
# with the exception of the  $forbidOID.

# However, the $aftOID is useless in determining if a port is trunked;
# we have to use a private mib variable, hh3cifVLANType.

# The interpretation of the 
# dot1qVlanStatic{Untagged,Egress}Ports are different in that
# for the older HP's the index of the bit is taken to be an ifIndex
# whereas on the h3c's it interpreted as an index in the dot13d agreegate
# index space which appears to have different numbering.

# putting a port into vlan requires only setting the appropriate bit
# in just the dot1qVlanStaticEgressPorts variable, instead of the 6 instances
# required as an atomic action for the older HP's.

my $typeOID = 'hh3cifVLANType';

#
# Creates a new object.  Since snmpit_h3c is a child class of the HP
# Provision class above, this constructor mainly relies on its
# constructor.  The only other bit it does is create a
# snmpit_libNetconf object for use when OpenFlow configuration is
# requested.
#
# usage: new($classname,$devicename,$debuglevel,$authstr)
#        returns a new object, blessed into the snmpit_intel class.
#
sub new($$$;$) {
    my ($class, $devicename, $debuglevel, $authstr) = @_;

    # Our parent class does most of the init work, and even blesses the
    # returned object into THIS class (because this new() method didn't
    # exist previously).
    my $self = $class->SUPER::new($devicename, $debuglevel, $authstr);
    if (!defined($self)) {
	# Errors have already been emitted.
	return undef;
    }
    my $args = {
	"USERNAME"  => $self->{USERNAME}, 
	"PASSWORD"  => $self->{PASSWORD}, 
	"PORT"      => $self->{PORT},
    };
    
    #
    # See if we are using an ssh key for the netconf connection. We have to
    # copy the key and set the mode so that ssh is happy.
    #
    if ($self->{"SSHKEY"}) {
	my $sshkey;
	
	if (open(SSH, $self->{"SSHKEY"})) {
	    while (<SSH>) {
		$sshkey .= $_;
	    }
	    close(SSH);
	}
	else {
	    warn "$self->{NAME}: Could open " . $self->{"SSHKEY"} . "\n";
	    return undef;
	}
	my ($tempfile, $filename) =
	    tempfile("/tmp/snmpit_ssh.XXXXX", "UNLINK" => 1);
	print $tempfile $sshkey;
	close($tempfile);
	# To make ssh happy.
	system("/bin/chmod 600 $filename");
	$args->{"SSHKEY"} = $filename;
    }
    
    my $ncobj = snmpit_libNetconf->new($devicename, $args, $debuglevel);
    if (!defined($ncobj)) {
	warn "$self->{NAME}: Could not instantiate a libNetconf object!\n";
	return undef;
    }
    $self->{NCOBJ} = $ncobj;

    return $self;
}

# some h3c specific helper functions

sub getOidToMappedList($$$) {
    my ($self, $oid, $idx) = @_;
    my $bits = $self->get1($oid,$idx);
    return map { $self->{d1dx2ifx}{$_} } $self->portSetToList($bits);
}

sub mapListToOid($@) {
    my ($self, @l) = @_;
    return $self->listToPortSet(map { $self->{ifx2d1dx}{$_} } @l );
}

sub getVlanMembers($$) {
    my ($self, $vlan) = @_;
    my @allmems = $self->getOidToMappedList($egressOID,$vlan);
    my @normmems = $self->getOidToMappedList($normOID,$vlan);
    my $mems = { map { ($_, 'tagged') }  @allmems } ;
    @$mems{@normmems} = ('untagged') x @normmems ;
    return $mems;
}

sub setVlanMembers($$$) {
    my ($self, $vlan, $mems, $rv) = @_;
    my $id = $self->{NAME} . '::setvLanMembers';
    $rv = $self->set([$egressOID,$vlan,$self->mapListToOid(keys %$mems)], $id);
    return (defined($rv) ? 0 : 1);
}

sub leBitsToList($$) {
    my ($self,$bits) = @_;
    my ($lim, $i, @result) = ((8 * length($bits)), -1);
    while (++$i < $lim) { if (vec($bits,$i,1)) { push @result, $i+1; } }
    return @result;
}

sub removeSomeVlanMembers($$$@) {
    my ($self, $vlan, $mems, @ports) = @_;
    my @disable = grep {$$mems{$_} && ($$mems{$_} eq 'untagged')} @ports;
    my $duals = $self->trunkedPorts(@disable);
    @disable = grep {!$$duals{$_}} @disable;
    delete @$mems{@ports};
    return $self->setVlanMembers($vlan, $mems)
	    + (@disable ? $self->portControl("disable", @disable): 0);
}

#
# published interfaces description in snmpit_hp package
#
sub removeSomePortsFromVlan($$@) {
    my ($self, $vlan, @ports) = @_;
    @ports = $self->convertPortFormat($PORT_FORMAT_IFINDEX,@ports);
    $self->lock();
    my $mems = $self->getVlanMembers($vlan);
    my $errors = $self->removeSomeVlanMembers($vlan, $mems, @ports);
    $self->unlock();
    return $errors;
}

sub removePortsFromVlan($@) {
    my ($self, @vlans) = @_;
    my $errors = 0;
    $self->lock();
    foreach my $vlan (@vlans) {
	my $mems = $self->getVlanMembers($vlan);
	$errors += $self->removeSomeVlanMembers($vlan, $mems, keys %$mems);
    }
    $self->unlock();
    return $errors;
}

use Data::Dumper;

sub enablePortTrunking2($$$$) {
    my ($self,$port,$native_vlan,$equaltrunking) = @_;
    my ($ifIndex) = $self->convertPortFormat($PORT_FORMAT_IFINDEX,$port);
    my $id = $self->{NAME} .
		"::enablePortTrunking($port,$native_vlan,$equaltrunking)";
    my $errors = 0;

    $self->lock();
    my ($trunks, $oldpid) = ($self->trunkedPorts($ifIndex));
    if (!($oldpid = $$trunks{$ifIndex})) {
	$errors = $self->set([$typeOID, $ifIndex, 'vLANTrunk']);
	$errors += $self->removeSomePortsFromVlan(1,$ifIndex);
    } else {
	$errors = $self->portControl("enable", $ifIndex);
    }
    $native_vlan = 1 if ($equaltrunking);
    $errors += $self->setPortVlan($native_vlan, $ifIndex)
	    if ($native_vlan != 1);
    $errors += !defined($self->set(['dot1qPvid', $ifIndex, $native_vlan]))
	if ((defined($oldpid)&&($oldpid!=$native_vlan)) || ($native_vlan!=1));
    $self->unlock();
    return $errors == 0;
}

sub disablePortTrunking($$) {
    my ($self, $port) = @_;
    my $id = $self->{NAME} . "::disablePortTrunking($port)";
    my $errors = 0;

    my ($portIndex) = $self->convertPortFormat($PORT_FORMAT_IFINDEX,$port);
    my $trunks = $self->trunkedPorts($portIndex);
    my $native_vlan = $$trunks{$portIndex};
    if (!$native_vlan) {
	warn "$id: $portIndex does not have a native vlan\n";
	return 0;
    }
    my @remvlans = $self->otherTrunkedVlans($portIndex, 0);

    foreach my $vlan_number (@remvlans) {
	warn "$id: Unable to remove VLAN $vlan_number on $portIndex\n"
	   if $self->removeSomePortsFromVlan($vlan_number, $portIndex);
    }
    my $rv = $self->set([$typeOID, $portIndex, 'access']);
    if (!defined($rv)) {
	warn "$id: Unable to set access mode on $portIndex\n";
	$errors++;
    }
    if ($self->setPortVlan($native_vlan, $portIndex)) {
	warn "$id: Unable to reset native vlan $native_vlan on $portIndex\n";
	$errors++;
    }
    return $errors == 0;
}

sub setPortVlan($$@) {
    my ($self, $vlan_number, @ports) = @_;
    my ($portIndex, $pvid, $rv, @protoTrunks, @newTaggedPorts);
    my %vlansToPorts; # i.e. bumpedVlansToListOfPorts
    my $id = $self->{NAME} . "::setPortVlan($vlan_number)";
    return 0 unless(@ports);
    my @portlist = $self->convertPortFormat($PORT_FORMAT_IFINDEX, @ports);
    return -1 unless (@portlist);

    $self->debug($id);
    $self->debug("ports: " . join(",",@ports) . "\n");
    $self->debug("as ifIndexes: " . join(",",@portlist) . "\n");
    my $oldTrunks = $self->trunkedPorts(@portlist);

    foreach $portIndex (@portlist) {
	if (exists($$oldTrunks{$portIndex})) {
	    push @newTaggedPorts, $portIndex;
	    next;
	}
	$pvid = $self->get1("dot1qPvid", $portIndex);
	push @{$vlansToPorts{$pvid}}, $portIndex
	    if (defined($pvid) && ($pvid != $vlan_number));
    }
    @{$self->{DISPLACED_VLANS}} = grep {$_ != 1;} keys %vlansToPorts;
 
    $self->lock();
    my $newInfo = $self->getVlanMembers($vlan_number);
    foreach my $vlan (keys %vlansToPorts)
	{ map { $$newInfo{$_} = 'untagged'} (@{$vlansToPorts{$vlan}}); }

    # Now add tagged ports separately, just to be safe.

    @$newInfo{@newTaggedPorts} = ('tagged') x @newTaggedPorts
	if (@newTaggedPorts);
    my $errors = $self->setVlanMembers($vlan_number,$newInfo);
    $self->unlock();
    if ($errors) {
	return $errors;
    }

    my $onoroff = ($vlan_number ne "1") ? "enable" : "disable";
    $self->debug("$id; will $onoroff"  . join(',',@ports) . "...\n");
    if ( $rv = $self->portControl($onoroff, @ports) ) {
	warn "$id: Port enable had $rv failures.\n";
	$errors += $rv;
    }
    return $errors;
}

# h3c variants of snmpit_hp helpers;
my %h3c_cmdOIDs =
(
    "enable" => ["ifAdminStatus","up"],
    "disable"=> ["ifAdminStatus","down"],
    "10000mbit"=> ["hh3cifEthernetSpeed","S10000M"],
    "1000mbit"=> ["hh3cifEthernetSpeed","S10000M"],
    "100mbit"=> ["hh3cifEthernetSpeed","S100M"],
    "10mbit" => ["hh3cifEthernetSpeed","S10M"],
    # Most modern switches (with 1Gb+ links) don't support changing the duplex.
    #"auto"   => ["hh3cifEthernetDuplex","auto"],
    #"full"   => ["hh3cifEthernetDuplex","full"],
    #"half"   => ["hh3cifEthernetDuplex","half"],
);

sub readifIndex($) {
    my $self = shift;
    my ($t_off, $maxport, $name, $ifindex, $iidoid, $port, $mod) = (0,0);
    my ($leadmod, $modport, $submod, $boport);
    my ($ge, $fe, $he) = ("GigabitEthernet", "FortyGigE", "HundredGigE");
    my $te = "Ten-$ge";
    $self->debug($self->{NAME} . "::readifIndex:\n", 2);

    # First, we scrape the dot2dBasePortIfIndex table, which maps port/LAG
    # ifindices to their offsets inside of the PortSets used in various
    # SNMP tables (e.g. dot1qVlanStaticEgressPorts).
    my ($rows) = snmpitBulkwalk($self->{SESS}, ["dot1dBasePortIfIndex"]);
    $self->{d1dx2ifx} = { map { (@$_[1], @$_[2])} @$rows };
    $self->{ifx2d1dx} = { map { (@$_[2], @$_[1])} @$rows };

    # Second, grab the list of ports on the switch via the "ifDescr"
    # table.  Keep track of the highest ifindex we've seen as
    # "maxport".  Load up the IFINDEX map with what we get.  
    # KRW: Shouldn't this filter based on the actual port type?  
    # Otherwise we will end up with a large "maxport" due to LAGs 
    # and other virtual ports with large ifindices.
    ($rows) = snmpitBulkwalkFatal($self->{SESS}, ["ifDescr"]);
    foreach my $rowref (@$rows) {
	($name,$ifindex,$iidoid) = @$rowref;
	$self->debug("got $name, $ifindex, iidoid $iidoid\n", 2);
	$self->{IFDESCR}{$ifindex} = $iidoid;
	$maxport = $ifindex if ($ifindex > $maxport);
	next unless
	    ($iidoid =~ /^($ge|$te|$fe|$he)(\d+)\/(\d+)\/(\d+)(:(\d+))?$/);
	($mod, $submod, $port, $boport) = ($2,$3,$4,$6);
	$leadmod = $mod unless defined($leadmod);
	$mod++ if ($leadmod eq '0');
	# HORRIBLE hack for submodules > 0 and breakout ports.
	if ($submod > 0 || defined($boport)) {
	    $mod = 0;
	    $port = $ifindex;
	}
	$modport = "$mod.$port";
	$self->{IFINDEX}{$modport} = $ifindex;
	$self->{IFINDEX}{$ifindex} = $modport;
    }

    # Next we grab information about the LAGs defined on the switch.
    # Associated ports are discovered and indexed.  The "TRUNK" object
    # keys are misleading.  They should use LAG (or similar) instead.
    # Note that the inner loop actually rewrites the IFINDEX entries
    # for ports that are members of a LAG.  Of particular interest is
    # that all of these port entres (and the entry for the LAG itself)
    # are setup to resolve to the _same_ (base) modport and the
    # ifindex of the LAG.
    ($rows) = snmpitBulkwalk($self->{SESS}, ["dot3adAggPortListTable"]);
    # We record the lowest numbered ifindex in the AggPortListTable as
    # the "trunk offset" ($t_off).
    map {if (($t_off == 0) || ($t_off > @$_[1])) {$t_off = @$_[1];};} @$rows;
    if ($t_off > 0) { $t_off--; }
    foreach my $rowref (@$rows) {
        ($name,$ifindex,$iidoid) = @$rowref;
        $self->debug("got $name, $ifindex\n", 2);
        my @mems = $self->portSetToList($iidoid);
        next unless(@mems);
        $self->debug("agg port `mems` before mapping: @mems\n", 2);
	@mems = map { $self->{d1dx2ifx}{$_};} @mems;
        $self->debug("agg port `mems` after mapping: @mems\n", 2);
        $self->{TRUNKS}{$ifindex - $t_off} = [ @mems];
        map {$self->{TRUNKINDEX}{$_} = $ifindex - $t_off; } @mems;
        $modport = $self->{IFINDEX}{$mems[0]};
        foreach $port (@mems, $ifindex) {
            $name = $self->{IFINDEX}{$port} || "0.$ifindex";
            $self->{IFINDEX}{$port} = $modport;
            $self->{IFINDEX}{$name} = $ifindex;
        }
    }
    if (0) {
	print STDERR Dumper($self->{"IFDESCR"});
	print STDERR Dumper($self->{"IFINDEX"});
	print STDERR Dumper($self->{"TRUNKS"});
	print STDERR Dumper($self->{"TRUNKINDEX"});
	print STDERR $t_off . "\n";
    }

    # Record some final metadata for this switch.
    $self->{MAXPORT} = $maxport;
    $self->{TRUNKOFFSET} = $t_off;
    $self->{cmdOIDs} = \%h3c_cmdOIDs;
}


#
# Utility function to extract port trunk information.
#
# With a list of ports, return the set of ports that are not simply in
# "access" mode. When called with no list, return the complete set of
# trunked ports.
#
# Return structure is a reference to a hash whose keys are port
# ifindices, and values are the PVIDs of the corresponding ports.
#
sub trunkedPorts($@) {
    my ($self, @ports) = @_;
    my ($trunks, $modes, $pids, $j) = ({});
    if (@ports) {
	$modes = [ map { [ $typeOID, $_ ] } @ports ];
	$j = $self->{SESS}->get($modes);
    } else {
	($modes) = $self->{SESS}->bulkwalk(0,32, [$typeOID]);
    }
    @ports = map { @$_[1] } grep { @$_[2] ne 'access' } @$modes; 
    if (@ports) {
	$pids = [ map { [ 'dot1qPvid', $_ ] } @ports ];
	$j = $self->{SESS}->get($pids);
	map { $$trunks{@$_[1]} = @$_[2]} @$pids;
    }
    return ($trunks);
}

#
# Utility function to return the list of vlans allowed on a particular
# trunk, EXCLUDING the vlan tag passed in as the "$pvid" argument.
#
sub otherTrunkedVlans($$$)
{
    my ($self, $portIndex, $pvid) = @_;
    my $highbits = $self->get1('hh3cifVLANTrunkAllowListHigh',$portIndex);
    my $lowbits = $self->get1('hh3cifVLANTrunkAllowListLow',$portIndex);
    my @others = ($self->leBitsToList($lowbits),
		     map {$_ + 2048} $self->leBitsToList($highbits));
    return (grep { $_ ne "$pvid" } @others);
}

###
### Section: Netconf support functions for H3C
###
my $H3C_DATA_URL = "http://www.hp.com/netconf/data:1.0";

sub _el ($) { return XML::LibXML::Element->new($_[0]); }

sub _zipelts (@) {
    my $top_elt = shift;
    my $cur_elt = $top_elt;
    foreach my $elt (@_) {
	$cur_elt->appendChild($elt);
	$cur_elt = $elt;
    }
    return $top_elt;
}

#
# Make test filter to check for presence of OpenFlow commands on switch.
#
sub mkOFPTestFilter() {
    my $filter_el = _el("filter");
    $filter_el->setAttribute("type", "subtree");
    my $top_el = _el("top");
    $top_el->setNamespace($H3C_DATA_URL);
    my $name_el = _el("Name");
    $name_el->appendText("ofp");

    return _zipelts($filter_el, $top_el, _el("RBAC"), _el("Features"), 
		    _el("Feature"), $name_el);
}

#
# Run a CLI command via Netconf
#
sub doH3CNetconfCLI($$;$) {
    my ($self, $cmd, $execflag) = @_;

    my $clitype = $execflag ? "Execution" : "Configuration";
    my $id = "$self->{NAME}::doH3CNetconfCLI";
    my $retval = undef;

    if (!$cmd) {
	warn "$id: Must supply CLI command!\n";
	return undef;
    }

    my $cli_el = _el($clitype);
    $cli_el->appendText($cmd);
    my $clires = $self->{NCOBJ}->doRPC("CLI", $cli_el);
    if (!defined($clires)) {
	warn "$id: Error attempting to run Netconf CLI command!\n";
	return undef;
    }
    elsif ($clires->[0] == NCRPCRAWRES()) {
	my $res_el = $clires->[1];
	if ($res_el->nodeName() ne "CLI") {
	    warn "$id: got non-CLI data back!?\n";
	    return undef;
	}
	my ($exec_el,) = $res_el->getChildrenByLocalName($clitype);
	if (!$exec_el) {
	    warn "$id: No return data?!\n";
	    return undef;
	}
	$retval = $exec_el->textContent() || "";
    }
    elsif ($clires->[0] eq NCRPCERR()) {
	my $err = $clires->[1];
	warn "$id: Error returned:\n".
	    "\ttype: $err->{type}, tag: $err->{tag}, sev: $err->{severity}\n".
	    "\tmessage: $err->{message}\n".
	    "\textra info: $err->{info}\n";
	$retval = undef;
    }
    else {
	warn "$id: Unhandled return code ".
	    "from libNetconf: $clires->[0]\n";
	$retval = undef;
    }

    return $retval;
}

sub getOFInstances($) {
    my ($self,) = @_;

    my $instances = {};

    my $rawres = $self->doH3CNetconfCLI("display openflow summary\n");
    if (!defined($rawres)) {
	warn "$self->{NAME} Cannot obtain list of OpenFlow instances!\n";
	return undef;
    }

    foreach my $rawln (split(/\n/, $rawres)) {
	chomp $rawln;
	RAWPARSE: for ($rawln) {
	    /^(\d+)\s+(\w+)/ && do {
		$instances->{$1} = $2;
		last RAWPARSE;
	    };
	    # No default action
	}
    }

    return $instances;
}

#
# Create baseline OF instance for a given vlan.  Do not enable it.
# OF controller is set elsewhere.
#
# WARNING: Does not check to see if instance exists first!
#
sub createOFInstance($$) {
    my ($self, $vlan) = @_;

    my $id = "$self->{NAME}::createOFInstance";

    my $cmdstr = "openflow instance $vlan\n";
    $cmdstr .= "classification vlan $vlan\n";
    $cmdstr .= "flow-table mac-ip 100 extensibility 200\n";
    $cmdstr .= "fail-open mode secure\n";
    $cmdstr .= "mac-learning forbidden\n";

    my $clires = $self->doH3CNetconfCLI($cmdstr);
    if (!defined($clires)) {
	warn "$id: Error setting up OF instance for vlan $vlan\n";
	return 0;
    }
    if ($clires =~ /^\s+(%.+)$/m) {
	warn "$id: Error returned from CLI:\n".
	    "\t$1\n";
	return 0;
    }

    return 1;
}

###
### OpenFlow snmpit module API functions follow.
###

#
# Enable Openflow
#
sub enableOpenflow($$) {
    my $self = shift;
    my $vlan = shift;

    my $id = "$self->{NAME}::enableOpenflow";

    my $oflist = $self->getOFInstances();
    if (!defined($oflist)) {
	warn "$id: Could not fetch OF instance list!\n";
	return 0;
    }
    if (!exists($oflist->{$vlan})) {
	print "$id: Creating OF instance for vlan $vlan\n";
	return 0
	    if !$self->createOFInstance($vlan);
    }

    my $clires = $self->doH3CNetconfCLI("openflow instance $vlan\n".
					"active instance\n");
    if (!defined($clires)) {
	warn "$id: Internal error while enabling OF for vlan $vlan\n";
	return 0;
    }
    if ($clires =~ /^\s+(%.+)$/m) {
	warn "$id: Error returned from CLI:\n".
	    "\t$1\n";
	return 0;
    }

    return 1;
}

#
# Disable Openflow (and destroy related instance).
#
sub disableOpenflow($$) {
    my $self = shift;
    my $vlan = shift;

    my $id = "$self->{NAME}::disableOpenflow";

    my $oflist = $self->getOFInstances();
    if (!defined($oflist)) {
	warn "$id: Could not fetch OF instance list!\n";
	return 0;
    }
    if (!exists($oflist->{$vlan})) {
	warn "$id: No OF instance exists for vlan $vlan.\n";
	return 1; # Not an error.
    }

    my $clires = $self->doH3CNetconfCLI("undo openflow instance $vlan\n");
    if (!defined($clires)) {
	warn "$id: Internal error while disabling OF for vlan $vlan\n";
	return 0;
    }
    if ($clires =~ /^\s+(%.+)$/m) {
	warn "$id: Error returned from CLI:\n".
	    "\t$1\n";
	return 0;
    }

    return 1;    
}

#
# Set controller
#
sub setOpenflowController($$$$) {
    my $self = shift;
    my $vlan = shift;
    my $controller = shift;
    my $option = shift;

    my $id = "$self->{NAME}::setOpenflowController";
    my ($ctrlproto, $ctrladdr, $ctrlport) = split(/:/, $controller);

    # Get list of OF instances.
    my $oflist = $self->getOFInstances();
    if (!defined($oflist)) {
	warn "$id: Error getting OF instances list.\n";
	return 0;
    }

    # Create instance for this vlan, if it doesn't exist yet.
    if (!exists($oflist->{$vlan})) {
	print "$id: Creating OF instance for vlan $vlan\n";
	return 0
	    if !$self->createOFInstance($vlan);
    }

    # Put together command for setting the controller for the instance.
    my $cmdstr = "openflow instance $vlan\n";
    $cmdstr .= "controller 1 address ip $ctrladdr port $ctrlport".
	(defined($self->{OFVRF}) ? " vrf $self->{OFVRF}\n" : "\n");
    #if (defined($option) && $option eq "fail-safe") {
    #	$cmdstr .= "fail-open mode secure\n";
    #}

    my $clires = $self->doH3CNetconfCLI($cmdstr);
    if (!defined($clires)) {
	warn "$id: Internal error while setting OF controller for vlan $vlan\n";
	return 0;
    }
    if ($clires =~ /^\s+(%.+)$/m) {
	warn "$id: Error returned from CLI:\n".
	    "\t$1\n";
	return 0;
    }
    
    return 1;
}

#
# Set listener
#
sub setOpenflowListener($$$) {
    my $self = shift;
    my $vlan = shift;
    my $listener = shift;

    warn "$self->{NAME}: OpenFlow listeners are not supported!\n";
    return 0;
}

#
# Get used listener ports
#
sub getUsedOpenflowListenerPorts($) {
    my $self = shift;

    warn "$self->{NAME}: OpenFlow listeners are not supported!\n";
    return ();
}

#
# Check if Openflow is supported on this switch
#
sub isOpenflowSupported($) {
    my $self = shift;

    # Just assume Comware switches support OF.  We'll quickly find out
    # otherwise when trying to get the current list of OF instances in
    # one of the real OF commands above.  Might want to add an option
    # attribute to explicitly disable OF on a switch.
    #
    # We could call getOFInstances() here as a check, but that just
    # makes the whole OF setup process take longer.
    #
    my $myret = 1;

    # Code below doesn't work on the HP 12910. Switch complains about
    # the "RBAC" token in the filter.
    #
    #my $filter = mkOFPTestFilter();
    #my $res = $self->{NCOBJ}->doGet($filter);
    #if ($res && $res->[0] == NCRPCDATA()) {
    #	my $data_el = $res->[1];
    #	my $xpc = XML::LibXML::XPathContext->new($data_el);
    #	$xpc->registerNs('x',$H3C_DATA_URL);
    #	if ($xpc->findvalue("//x:Name") eq "ofp") {
    #	    $myret = 1;
    #	}
    #}

    return $myret;
}

#
# DETER has an hp10512 switch running version 5 comware
#
# There are there are at least two differences between the v5 and v7
# firmware impacting snmpit.  The first is that snmp modification
# to vlan membership of aggregates is not allowed.
#
# We will assume that any aggregates are created, placed into trunk
# mode and enabled manually by testbed operators, and will only support
# dynamic vlan changes, i.e. no -E, -T, -U on aggregates.
#
# The second is that the clearing membership of a trunked port in
# a vlan does not remove the vlan from the list of vlans permitted
# on the trunk, resulting in misleading configuration files, i.e.
# the vlan would appear to be permitted on the trunk if recreated
# but would not be passed on the port.  We'll worry about dual
# mode ports later.
#
# Both of these problems are addressed by a v5 specific version
# of setVlanMembers which invokes CLI specifically to patch up
# the special cases.  The rest of the routines below are just helpers.

# The only other v5 change is that in reading the aggregate
# memberships, the indices are in the dot1d space.  This may also be
# true of v7, but the v7 switches we've seen so far the same values
# in the dot1d and ifIndex space for normal ports, which is not true
# on DETER's v5 switch.

package snmpit_h3cv5;
use strict;
use vars qw(@ISA);
@ISA = 'snmpit_h3c';
my @expect_results;

sub simpleCli($$$) {
   my ($self, $out, $in) = @_;
   $self->setup_cli()
       unless ($self->{CLI_SESSION});
   my $sess = $self->{CLI_SESSION} ;
   $sess->send($out . "\r");
   @expect_results = $sess->expect(2, $in);
   my $accum = $sess->set_accum("");
}

sub setup_cli($) {
    my $self = shift;
    my $host = $self->{NAME};
    if (!eval("require Expect")) {
       die ("$host"."::setup_cli: require Expect failed, aborting\n");
    }
    require Expect;
    local $ENV{PATH} = '/bin:/usr/bin'; # silence taint error
    my $sess = $self->{CLI_SESSION} = Expect->spawn("telnet",$host);
    $sess->notransfer(0);
    if ($self->{DEBUG} == 0) { $sess->log_stdout(0); }
}

sub setTrunkVlans($$$@) {
    my ($self, $idx, $add, @vlans) = @_;
    my ($iname, $hname) = ($self->{IFDESCR}{$idx}, $self->{NAME});
    $self->simpleCli("return","<$hname>");
    $self->simpleCli("system-view","[$hname]");
    $self->simpleCli("interface $iname","[$hname-$iname]");
    while (scalar(@vlans)) {
       # Comware CLI seems to limit you to having <=10 vlans in the following
       my @leadvs = splice(@vlans,0,8);
       my $cmd = ($add ? "" : "undo ") .
                       "port trunk permit vlan " . join(' ',@leadvs);
       $self->simpleCli($cmd,"[$hname-$iname]");
    }
}
sub setVlanMembers($$$) {
    my ($self, $vlan, $mems, $ifIndex) = @_;
    my $cur_mems = $self->getVlanMembers($vlan);

    # look for changes, fix permitted list on dropped trunked ports
    foreach my $idx (keys %$cur_mems, keys %$mems) {
       # ifIndex of any aggregate will also appear; members dealt with then.
       next
           if ($self->{TRUNKINDEX}->{$idx});
       # consider only changes. (also $idx's appearing twice are not changing!)
       next
           unless (exists($$mems{$idx}) ne exists($$cur_mems{$idx}));
       my $ax = $idx - $self->{TRUNKOFFSET};
       if (($ax > 0) && exists ($self->{TRUNKS}->{$ax})) {
           foreach my $i (@{$self->{TRUNKS}->{$ax}})
               {$$mems{$idx} ? ($$mems{$i} = 'tagged') : delete($$mems{$i});}
           $self->setTrunkVlans($idx, $$mems{$idx}, $vlan);
           next;
       }
       next
           unless ($$cur_mems{$idx} && ($$cur_mems{$idx} eq 'tagged'));
       # if here, we are dropping the non-aggregate trunked port $idx.
       $self->setTrunkVlans($idx, 0, $vlan);
    }
    # now safe to handle non-aggregates as before
    return snmpit_h3c::setVlanMembers($self, $vlan, $mems);
}

# we ran this under the debugger to cleam up the mess generated
# by the second problem noted above.
sub tidyTrunks($@) {
    my ($self, @trunks) = @_;
    my $fv = { $self->findVlans() };
    my @all = values %$fv;
    foreach my $idx (keys %{$self->trunkedPorts(@trunks)}) {
       my $tvlans = {};
       my @vnums = $self->otherTrunkedVlans($idx,0);
       foreach my $ov ($self->otherTrunkedVlans($idx,0)) {
           if (!  scalar(grep {$_ eq $ov} @all))
               { $self->debug("$idx, $ov -> no vlan\n");}
           elsif (! ${$self->getVlanMembers($ov)}{$idx})
               { $self->debug("$idx, $ov -> not member\n");}
           else { next;}
           $$tvlans{$ov} = 1;
       }
       my @tmems = keys %$tvlans;
       if (@tmems) {
           print "bad mems of trunk $idx are ". join(',',@tmems) ."\n";
           $self->setTrunkVlans($idx, 0, @tmems);
       }
    }
}

# End with true
1;
