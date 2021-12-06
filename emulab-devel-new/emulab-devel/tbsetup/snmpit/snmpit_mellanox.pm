#!/usr/bin/perl -w

#
# Copyright (c) 2013-2018 University of Utah and the Flux Group.
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
# snmpit module for Mellanox Ethernet networks switches
#

package snmpit_mellanox;
use strict;

$| = 1; # Turn off line buffering on output

use English;
use SNMP;
use snmpit_lib;
use MLNX_XMLGateway;

use libtestbed;
use Lan;
use Port;
use Data::Dumper;

# Mellanox REST API static paths
my $MLNX_BASE  = "/mlnxos/v1";
my $MLNX_VSR   = "$MLNX_BASE/vsr/default_vsr";
my $MLNX_IFC_PREFIX = "$MLNX_VSR/interfaces";
my $MLNX_VLAN_PREFIX = "$MLNX_VSR/vlans";

my $MLNX_DEF_VLAN = 1;

# status indicators for ports (ifTable entries).
my $STATUS_UP = 1;
my $STATUS_DOWN = 2;
my $SNMP_NO_INSTANCE = "NOSUCHINSTANCE";

#
# Port status and control.
#
my $PORT_ADMIN_STATUS     = "ifAdminStatus";
my $PORT_OPER_STATUS      = "ifOperStatus";
my $PORT_SPEED            = "ifHighSpeed";

my %cmdPaths =
    (
     "enable"   => ["set-modify", "enabled=true", undef],
     "disable"  => ["set-modify", "enabled=false", undef],
    );


# Most are defined in snmpit_lib, let's not repeat or change
#my $PORT_FORMAT_IFINDEX   = 1;
#my $PORT_FORMAT_MODPORT   = 2;
#my $PORT_FORMAT_NODEPORT  = 3;
#my $PORT_FORMAT_PORT      = 4;
#my $PORT_FORMAT_PORTINDEX = 5;
my $PORT_FORMAT_MLNX      = 6;

#
# Creates a new object. 
#
# usage: new($classname,$devicename,$debuglevel,$community)
#        returns a new object, blessed into the snmpit_mellanox class.
#
sub new($$$;$) {

    # The next two lines are some voodoo taken from perltoot(1)
    my $proto = shift;
    my $class = ref($proto) || $proto;

    my $name = shift;
    my $debugLevel = shift;
    my $authstring = shift;  # user:pass[:community] for Mellanox switches.

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

    # ifIndex mapping store
    $self->{IFINDEX} = {};
    $self->{POIFINDEX} = {};

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

    if (!$authstring) { # Allow this to over-ride the default
        $authstring = $options->{'snmp_community'};
    }

    if (!defined($authstring)) {
	warn "ERROR: Auth string must be defined for $self->{NAME}\n";
	return undef;
    }

    # Parse out the various bits we need from the auth string.
    my ($user, $pass, $community) = split(/:/, $authstring);
    if (!defined($user) || !defined($pass)) {
	warn "ERROR: Auth string must contain at least a username and ".
	     "password, separated by ':', for $self->{NAME}\n";
	return undef;
    }
    $self->{USER} = $user;
    $self->{PASS} = $pass;

    # Default the SNMP community string to "public" if not specified.
    $self->{COMMUNITY} = $community || "public";
 
    if ($self->{DEBUG}) {
        print "snmpit_mellanox initializing $self->{NAME}, " .
            "debug level $self->{DEBUG}\n" ;   
    }

    #
    # Set up SNMP module variables, and connect to the device
    #
    $SNMP::debugging = ($self->{DEBUG} - 2) if $self->{DEBUG} > 2;

    # Placeholder for SNMP session object
    $self->{SESS} = 0;

    # Placeholder for XML-gateway adapter
    $self->{CLT} = 0;

    # Make it a class object
    bless($self, $class);

    # Create SNMP session
    if (!$self->initSNMPSession()) {
	return undef;
    }

    # Create XML-gateway wrapper instance
    if (!$self->initRPCSession()) {
	return undef; 
    }

    #
    # Sometimes the SNMP session gets created when there is no connectivity
    # to the device so let's try something simple
    #
    my $test_case = $self->get1("sysObjectID", 0);
    if (!defined($test_case)) {
	warn "ERROR: Unable to retrieve via SNMP from $self->{NAME}\n";
	return undef;
    }

    # Creat ifindex interface map
    if (!$self->readifIndex()) {
	warn "ERROR: Unable to produce ifindex map for $self->{NAME}\n";
	return undef;
    }

    return $self;
}

#
# Create an SNMP session object for the switch this instance is wrapping.
#
sub initSNMPSession($) {
    my $self = shift;

    $self->{SESS} = new SNMP::Session(DestHost => $self->{NAME},Version => "2c",
				      Timeout => 4000000, Retries=> 12,
				      Community => $self->{COMMUNITY});

    if (!$self->{SESS}) {
	#
	# Bomb out if the session could not be established
	#
	warn "ERROR: Unable to connect via SNMP to $self->{NAME}\n";
	return 0;
    }

    return 1;
}

#
# Initialize XML-gateway object
#
sub initRPCSession($) {
    my $self = shift;

    $self->{CLT} = eval { MLNX_XMLGateway->new("$self->{USER}:$self->{PASS}\@".
					       "$self->{NAME}") };
    if ($@) {
	warn "ERROR: Unable to create XML-gateway object for ".
	     "$self->{NAME}: $@\n";
	return 0;
    }

    # Enable debugging in gateway wrapper library if set for snmpit.
    if ($self->{DEBUG} > 0) {
	$self->{CLT}->debug($self->{DEBUG});
    }

    return 1;
}


#
# Read, build, and stash away a mapping from card/port to ifindex.
#
# Pull in the description field for all ports on the switch (indexed
# by ifindex).  It's Incredibly silly that the Mellanox XML-gateway
# doesn't let you get this info directly (well, it does for regular
# ports, but not portchannels).
#
sub readifIndex($) {
    my $self = shift;
    my $id = $self->{NAME} . "::readifIndex";
    $self->debug("$id:\n", 2);

    my ($rows) = snmpitBulkwalkFatal($self->{SESS}, ["ifDescr"]);

    if (!@$rows) {
	warn "$id: ERROR: No interface description rows returned ".
	     "while attempting to build ifindex table.\n";
	return 0;
    }

    foreach my $rowref (@$rows) {
	my ($name,$ifindex,$descr) = @$rowref;
	$self->debug("$id: got $name, $ifindex, description: $descr\n", 3);
	if ($name ne "ifDescr") {
	    warn "$id: WARNING: Foreign snmp var returned: $name";
	    return 0;
	}
	# Ethernet ports and port channels are all we care about.
	if ($descr =~ /^Eth\d+\/\d+$/) {
	    $self->{IFINDEX}{$descr}   = $ifindex;
	    $self->{IFINDEX}{$ifindex} = $descr;
	} elsif ($descr =~ /^Po\d+$/) {
	    $self->{POIFINDEX}{$descr}   = $ifindex;
	    $self->{POIFINDEX}{$ifindex} = $descr;
	}
    }

    # Success
    return 1;
}


#
# XML-gateway call helper.
#
# usage: callRPC($self, $callstack)
#        return remote method return value on success.
#        return undef and print error on failure.
#
sub callRPC {
    my ($self, $callstack) = @_;

    my $resp = eval { $self->{CLT}->call($callstack) };
    if ($@) {
	warn "WARNING: XML-gateway call failed to $self->{NAME}: $@\n";
	return undef;
    }

    return $resp;
}

sub PortInstance2ifindex($$) {
    my ($self, $Port) = @_;

    return $self->mlnx2ifindex($self->PortInstance2mlnx($Port));
}

sub PortInstance2mlnx($$) {
    my ($self, $Port) = @_;

    # Ports instances of type "other" are switch portchannels.
    if ($Port->role() eq "other") {
	return $Port->iface();
    } else {
	return "Eth". $Port->card() ."/". $Port->port();
    }
}

sub ifindex2PortInstance($$) {
    my ($self, $ifindex) = @_;

    if (exists($self->{IFINDEX}{$ifindex})) {
	$self->{IFINDEX}{$ifindex} =~ /^Eth(\d+)\/(\d+)$/;
	return Port->LookupByStringForced(
	    Port->Tokens2TripleString($self->{NAME}, $1, $2));
    } elsif (exists($self->{POIFINDEX}{$ifindex})) {
	return Port->LookupByStringForced(
	    Port->Tokens2IfaceString($self->{NAME}, 
				     $self->{POIFINDEX}{$ifindex}));
    }

    warn "WARNING: No such port on $self->{NAME} with ifindex: $ifindex\n";
    return undef;
}

sub ifindex2mlnx($$) {
    my ($self, $ifindex) = @_;

    if (exists($self->{IFINDEX}{$ifindex})) {
	return $self->{IFINDEX}{$ifindex};
    } elsif (exists($self->{POIFINDEX}{$ifindex})) {
	return $self->{POIFINDEX}{$ifindex};
    }

    warn "WARNING: No such port on $self->{NAME} with ident: $ifindex\n";
    return undef;
}

sub mlnx2PortInstance($$) {
    my ($self, $mlnx) = @_;
    
    return $self->ifindex2PortInstance($self->mlnx2ifindex($mlnx));
}

sub mlnx2ifindex($$) {
    my ($self, $mlnx) = @_;

    # The IFINDEX hash contains forward and reverse entries, so just
    # call the reverse function.
    return $self->ifindex2mlnx($mlnx);
}

#
# Converting port formats.
#
sub convertPortFormat($$@) {
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
    } elsif ($sample =~ /^Eth/ || $sample =~ /^Po/) {
	$input = $PORT_FORMAT_MLNX;
    } elsif ($sample =~ /^\d+$/) {
	$input = $PORT_FORMAT_IFINDEX;
    } else {
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

	if ($output == $PORT_FORMAT_IFINDEX) {
	    my @ifports = map $self->PortInstance2ifindex($_), @swports;
	    return @ifports;
	} else {
	    my @mlnxports = map $self->PortInstance2mlnx($_), @swports;
	    return @mlnxports;
	}
    } elsif ($input == $PORT_FORMAT_IFINDEX) {
	if ($output == $PORT_FORMAT_PORT) {
	    my @swports = map $self->ifindex2PortInstance($_), @ports;
	    return @swports;
	} else { # output is PORT_FORMAT_MLNX
	    my @mlnxports = map $self->ifindex2mlnx($_), @ports;
	    return @mlnxports;
	}
	
    } else { # input is $PORT_FORMAT_MLNX
	if ($output == $PORT_FORMAT_IFINDEX) {
	    my @ifports = map $self->mlnx2ifindex($_), @ports;
	    return @ifports;
	} else { # output is PORT_FORMAT_PORT
	    my @swports = map $self->mlnx2PortInstance($_), @ports;
	    return @swports
	}	
    }

    #
    # Some combination we don't know how to handle
    #
    warn "$id: Bad input/output combination ($input/$output)\n";
    return undef;    
}

# SNMP helpers imported from the beyond.

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

# SNMP shorthand

sub get1($$$) {
    my ($self, $obj, $instance) = @_;
    my $id = $self->{NAME} . "::get1($obj.$instance)";
    my $closure = sub () {
	my $RetVal = snmpitGet($self->{SESS}, [$obj, $instance], 1);
	if (!defined($RetVal)) { sleep 4;}
	return $RetVal;
    };
    my $RetVal = $self->hammer($closure, $id, 40);
    if (!defined($RetVal)) {
	warn "$id failed - $snmpit_lib::snmpitErrorString\n";
    }

    #
    # Accoding to my testing on Extreme switch, no-instance will
    # still return a string "NOSUCHINSTANCE";
    #
    if ($SNMP_NO_INSTANCE eq $RetVal) {
	return undef;
    }
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
	    if ($sess->{ErrorNum}) {
		my $bad = "$id had error number " . $sess->{ErrorNum} .
			  " and had error string " . $sess->{ErrorStr} . "\n";
		print $bad;
	    }
	}
	return $RetVal;
    };
    my $RetVal = $self->hammer($closure, $id, $retries);
    return $RetVal;
}

#
# Helper function.  Grab all vlans tag numbers on the switch.
#
sub getAllVlanNumbers($) {
    my ($self,) = @_;

    my $resp = $self->callRPC(["get", "$MLNX_VLAN_PREFIX/*"]);
    return () if !defined($resp);

    my @vlnums = ();
    foreach my $rv (@$resp) {
	push @vlnums, $rv->[2];
    }

    $self->debug("Found VLANS: @vlnums\n", 2);
    
    return @vlnums;
}

#
# Helper function.  Extract information on all ports and return this
# to the caller.  This function expects a reference to an array of
# ifindex (integer) numbers, or the string "ALL".
#
sub getPortState($$) {
    my ($self, $ports) = @_;

    my %ret = ();
    my $id = $self->{NAME} . "::getPortState";

    if (ref($ports) eq "ARRAY") {
	# nothing to do - just a valid case.
    } elsif ($ports eq "ALL") {
	$self->debug("$id: state for all ports requested.\n");
	$ports = [];
	@{$ports} = grep {/^\d+$/} ((keys %{$self->{IFINDEX}}), 
				    (keys %{$self->{POIFINDEX}}));
    } else {
	warn "$id: WARNING: Invalid argument\n";
	return undef;
    }

    $self->debug("$id: getting state for ifindexes: @{$ports}\n",2);

    my @getcmds = ();
    foreach my $ifindex (@{$ports}) {
	push @getcmds, ["get", "$MLNX_IFC_PREFIX/$ifindex/vlans/pvid"];
	push @getcmds, ["get", "$MLNX_IFC_PREFIX/$ifindex/vlans/allowed/*"];
	push @getcmds, ["get", "$MLNX_IFC_PREFIX/$ifindex/vlans/mode"];
	push @getcmds, ["get", "$MLNX_IFC_PREFIX/$ifindex/enabled"];
    }

    my $resp = $self->callRPC(\@getcmds);
    if (!defined($resp)) {
	warn "$id: WARNING: Failed to obtain information for requested ".
	     "ports.\n";
	return undef;
    }

    foreach my $rv (@$resp) {
	my ($path, $type, $val) = @$rv;
        RETPATH: for ($path) {
	    my $ifindex;
	    /^$MLNX_IFC_PREFIX\/(\d+)\// && do {
		$ifindex = $1;
		if (!exists($ret{$ifindex})) {
		    $ret{$ifindex} = {};
		    $ret{$ifindex}{PVID} = 0;
		    $ret{$ifindex}{ALLOWED} = {};
		    $ret{$ifindex}{MODE} = "*UNKNOWN*";
		    $ret{$ifindex}{ENABLED} = "*UNKNOWN*";
		}
		# fall through to next tests.
	    };
	    goto DEFCASE unless defined($ifindex);

	    /vlans\/pvid$/ && do {
		$ret{$ifindex}{PVID} = $val;
		last RETPATH;
	    };

	    /vlans\/allowed\/\d+$/ && do {
		$ret{$ifindex}{ALLOWED}{$val} = 1;
		last RETPATH;
	    };

	    /vlans\/mode$/ && do {
		$ret{$ifindex}{MODE} = $val;
		last RETPATH;
	    };

	    /enabled$/ && do {
		$ret{$ifindex}{ENABLED} = $val;
		last RETPATH;
	    };

	    DEFCASE:
	    warn "$id: WARNING: Unexpected path found in response.";
	}
    }

    return \%ret;
}


############# Standard snmpit driver interface APIs:################

#
# Set a variable associated with a port. The commands to execute are given
# in the cmdOIs hash above
#
# usage: portControl($self, $command, @ports)
#	 returns 0 on success.
#	 returns number of failed ports on failure.
#	 returns -1 if the operation is unsupported
#
# Note:  The Mellanox XML-gateway doesn't (yet) support setting the
#        interface speed.  We just lie to the caller that the change
#        went through and hope that the database only lists the speed
#        actually set on the ports.  ALso, duplex is meaningless in
#        the post-FE world, so is ignored.
# 
sub portControl ($$@) {
    my $self = shift;
    my $cmd = shift;
    my @ports = @_;

    my $id = $self->{NAME} . "::portControl";
    my $errors = 0;
    
    $self->debug("portControl: $cmd -> (".Port->toStrings(@ports).")\n");

    my @ifports = $self->convertPortFormat($PORT_FORMAT_IFINDEX, @ports);

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

    if (defined $cmdPaths{$cmd}) {
	my $path = $cmdPaths{$cmd};
	foreach my $ifport (@ifports) {
	    my $cmd = [$path->[0], "$MLNX_IFC_PREFIX/$ifport/$path->[1]", 
		       $path->[2]];
	    my $retval = $self->callRPC($cmd);
	    if (!defined($retval)) {
		warn "$id: WARNING: Failed to execute $cmd on $ifport.\n";
		$errors++;
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
# Check to see if the given 802.1Q VLAN tag exists on the switch
#
# usage: vlanNumberExists($self, $vlan_number)
#        returns 1 if the VLAN exists, 0 otherwise
#
sub vlanNumberExists($$) {
    my ($self, $vlan_number) = @_;
    my $id = $self->{NAME}."::vlanNumberExists($vlan_number)";

    $self->debug($id."\n");

    foreach my $vltag ($self->getAllVlanNumbers()) {
	return 1 if $vltag == $vlan_number;
    }

    $self->debug($id." VLAN #$vlan_number does not exist.\n");
    return 0;
}

#
# Given VLAN indentifiers from the database, finds the 802.1Q VLAN
# number for them. If no VLAN id is given, returns mappings for the entire
# switch.
# 
# usage: findVlans($self, @vlan_ids)
#        returns a hash mapping VLAN ids to 802.1Q VLAN numbers
#        any VLANs not found have NULL VLAN numbers
#
sub findVlans($@) {
    my $self = shift;
    my @vlan_ids = @_;
    my $id = $self->{NAME} . "::findVlans";
    $self->debug("$id\n");

    my %all = ();
    my %mps = ();

    my @getcmds = ();
    foreach my $vlnum ($self->getAllVlanNumbers()) {
	push @getcmds, ["get", "$MLNX_VLAN_PREFIX/$vlnum/name"];
    }

    my $resp = $self->callRPC(\@getcmds);
    if (defined($resp) && @$resp) {
	foreach my $rv (@$resp) {
	    $rv->[0] =~ qr|^$MLNX_VLAN_PREFIX/(\d+)/|;
	    my $vlnum = $1;
	    my $vlid = $rv->[2] ? $rv->[2] : "unnamed-$vlnum";
	    $self->debug("$id: Adding $vlid => $vlnum\n",2);
	    $all{$vlid} = $vlnum;
	}
    }

    # Filter through looking for those vlans that we care about.
    #
    # XXX: if the return value is not defined (indicating an error
    # talking to the switch), should we return undef, or just a null
    # mapping?  I'm thinking the former...
    foreach my $vlid (@vlan_ids) {
	if ($vlid eq "default") {
	    $mps{$vlid} = $MLNX_DEF_VLAN;
	} elsif (exists($all{$vlid})) {
	    $mps{$vlid} = $all{$vlid};
	} else {
	    $mps{$vlid} = undef;
	}
    }

    # Did caller ask for info on all vlans?
    if (!@vlan_ids) {
	%mps = %all;
    }

    $self->debug("$id RPC results: " . Dumper(\%mps), 2);
    return %mps;
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
    my $no_retry = shift; # ignored here
    my $id = $self->{NAME} . "::findVlan";

    $self->debug("$id ( $vlan_id )\n",2);

    my %mps = $self->findVlans($vlan_id);
    if (exists($mps{$vlan_id})) {
	return $mps{$vlan_id};
    }
    
    return undef;
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
    my $id = $self->{NAME} . "::createVlan";

    if (!defined($vlan_number)) {
	warn "$id: WARNING: called without supplying vlan_number";
	return 0;
    }

    $self->debug("createVlan: name $vlan_id number $vlan_number \n");

    $self->lock();
    my $check_number = $self->findVlan($vlan_id,1);
    if (defined($check_number)) {
	if ($check_number != $vlan_number) {
	    warn "$id: WARNING: Not creating $vlan_id because it already ".
	         "exists with VLAN number $check_number instead of $vlan_number\n";
	    $self->unlock();
            return 0;
	}
	print "  VLAN $vlan_id already exists as VLAN #$vlan_number on " .
	    "$self->{NAME} ...\n";
	$self->unlock();
	return $vlan_number;
    }
    
    print "  Creating VLAN $vlan_id as VLAN #$vlan_number on " .
	"$self->{NAME} ...\n";

    my $crcmd = ["action", "$MLNX_VLAN_PREFIX/add", {vlan_id => $vlan_number}];
    my $nmcmd = ["set-modify","$MLNX_VLAN_PREFIX/$vlan_number/name=$vlan_id"];
    my $resp = $self->callRPC([$crcmd, $nmcmd]);

    #
    # XXX creating a VLAN has the most unfortunate side-effect of adding that
    # VLAN to every trunk port. Since we know at this point that we are a
    # brand new VLAN, just remove it from ALL trunks here.
    #
    # Note that this works, but is probably overkill. It seem that if you just
    # delete a VLAN from a trunk port once, it changes the default (implicit)
    # config from:
    #    ... switchport trunk allowed-vlan all
    # to:
    #    ... switchport trunk allowed-vlan none
    #    ... switchport trunk allowed-vlan add 260
    #    ... switchport trunk allowed-vlan add 271
    #    ...
    #
    # In other words, it changes to the more desired behavior of forcing you
    # to explicitly add any VLAN you want on a trunk. But this behavior is not
    # documented and could probably change at any time.
    #
    # So, we stick with this overkill method since it is safe. What we would
    # really like is a documented API call that directly enables us to set
    # "allowed-vlan none". We could then call that when setting up a trunk.
    #
    if (defined($resp)) {
	$self->removeTrunkPortsFromVlan($vlan_number);
    }

    $self->unlock();
    
    if (!defined($resp)) {
	warn "$id: WARNING: Creating VLAN $vlan_id as VLAN #$vlan_number on ".
	     "$self->{NAME} failed.\n";
	# XXX: Why shouldn't this be a hard failure?
    }
    
    return $vlan_number;
}

#
# Put the given ports in the given VLAN. The VLAN is given as an 802.1Q 
# tag number.
############################################################
# Semantics:
#
#   Case mode(port):
#      'free' or 'in default untagged':
#          add port to vlan_number untagged.
#      'in use(not in default) untagged':
#          add port to vlan_number untagged.
#      'in use(not in default) all tagged':
#          add port to vlan_number tagged.
#      'in use(may in default) native tagged':
#          add port to vlan_number tagged;
#          if native_vlan == default:
#              remove native_vlan
#
# Mellanox 'free': switchportMode='access' AND vlan tag = 1
#
############################################################
# usage: setPortVlan($self, $vlan_number, @ports)
#	 returns 0 on sucess.
#	 returns the number of failed ports on failure.
#
sub setPortVlan($$@) {
    my $self = shift;
    my $vlan_number = shift;
    my @ports = @_;
    my $errors = 0;

    my $id = $self->{NAME} . "::setPortVlan($vlan_number)";
    $self->debug($id."\n");

    # Vlan must exist before being used in this function.
    if (!$self->vlanNumberExists($vlan_number)) {
	warn "$id: WARNING: VLAN $vlan_number does not exist.\n";
	return 1;
    }

    # Anything to do?
    return 0 unless(@ports);

    my @swports = $self->convertPortFormat($PORT_FORMAT_IFINDEX, @ports);

    $self->lock();
    my $pstates = $self->getPortState(\@swports);
    if (!defined($pstates)) {
	warn "$id: WARNING: Failed to get port states.\n";
	$self->unlock();
	return scalar(@ports);
    }

    my @setcmds = ();
    # Figure out what to do based on the mode each port is in.  Queue up the
    # right command(s).
    foreach my $ifindex (@swports) {
        MODESW: for ($pstates->{$ifindex}{MODE}) {
	    /^access$/ && do {
		push @setcmds, ["set-modify", "$MLNX_IFC_PREFIX/$ifindex/vlans/pvid=$vlan_number"]
		    if $pstates->{$ifindex}{PVID} != $vlan_number;
		last MODESW;
	    };

	    /^trunk$/ && do {
		# Only attempt to add the vlan if it isn't already in the
		# port's allowed list.
		if (!exists($pstates->{$ifindex}{ALLOWED}{$vlan_number})) {
		    push @setcmds, ["action", "$MLNX_IFC_PREFIX/$ifindex/vlans/allowed/add", {vlan_ids => $vlan_number}];
		    $pstates->{$ifindex}{ALLOWED}{$vlan_number} = 1;
		    # Remove the default vlan sentinel if it's present.
		    if ($vlan_number != $MLNX_DEF_VLAN &&
			exists($pstates->{$ifindex}{ALLOWED}{$MLNX_DEF_VLAN})) {
			push @setcmds, ["action", "$MLNX_IFC_PREFIX/$ifindex/vlans/allowed/delete", {vlan_ids => $MLNX_DEF_VLAN}];
			delete $pstates->{$ifindex}{ALLOWED}{$MLNX_DEF_VLAN};
		    }
		}
		last MODESW;
	    };

	    /^hybrid$/ && do {
		# Only add the vlan to the port's list if it isn't already
		# there, or if it isn't the native vlan.
		if (!exists($pstates->{$ifindex}{ALLOWED}{$vlan_number})
		    && $pstates->{$ifindex}{PVID} != $vlan_number) {
		    push @setcmds, ["action", "$MLNX_IFC_PREFIX/$ifindex/vlans/allowed/add", {vlan_ids => $vlan_number}];
		    $pstates->{$ifindex}{ALLOWED}{$vlan_number} = 1;
		}
		last MODESW;
	    };

	    # default case
	    warn "$id: WARNING: Unknown port mode for ifindex $ifindex: $_\n";
	    $errors++;
	}
	  
	# enable/disable ports: if the vlan is 'default', then disable
	# ports (which means deleting the ports from some vlan).
	my $truth = $vlan_number eq $MLNX_DEF_VLAN ? "false" : "true";
	push @setcmds, ["set-modify", "$MLNX_IFC_PREFIX/$ifindex/enabled=$truth"];
    }

    if (@setcmds) {
	my $resp = $self->callRPC(\@setcmds);
	if (!defined($resp)) {
	    $errors = scalar(@ports);
	}
    }

    $self->unlock();
    return $errors;
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
    my $errors = 0;

    my $id = $self->{NAME}."::delPortVlan($vlan_number)";
    $self->debug($id."\n");

    if (!$self->vlanNumberExists($vlan_number)) {
	warn "$id: WARNING: VLAN $vlan_number does not exist.\n";
	return 1;
    }
    
    return 0 unless(@ports);

    $self->debug("$id: incoming ports list: @ports\n",2);

    my @swports = $self->convertPortFormat($PORT_FORMAT_IFINDEX, @ports);

    $self->lock();
    my $pstates = $self->getPortState(\@swports);
    if (!defined($pstates)) {
	warn "$id: WARNING: Failed to get port states.\n";
	$self->unlock();
	return scalar(@ports);
    }

    my @setcmds = ();
    foreach my $ifindex (@swports) {
	my %ifc = %{$pstates->{$ifindex}};

	# Figuring out what to do with the port is something of a
	# nasty business that depends on what mode it's in, and how
	# the given vlan is affiliated with it.
        MODESW: for ($ifc{MODE}) {

	    /^access$/ && do {
		# Disable the port if the access vlan matches.
		if ($ifc{PVID} == $vlan_number) {
		    push @setcmds, ["set-modify", "$MLNX_IFC_PREFIX/$ifindex/vlans/pvid=$MLNX_DEF_VLAN"];
		    push @setcmds, ["set-modify", "$MLNX_IFC_PREFIX/$ifindex/enabled=false"];
		}
		last MODESW;
	    };

	    /^trunk$/ && do {
		# If the vlan is in the allowed list for this trunk
		# link, then remove it from the list.
		if (exists($ifc{ALLOWED}{$vlan_number})) {
		    if (keys(%{$ifc{ALLOWED}}) == 1) {
			# If we are removing the last vlan in the
			# list, then emit a warning and add the
			# default vlan since a port in "trunk" mode
			# must be a member of at least one vlan.
			push @setcmds, ["action", "$MLNX_IFC_PREFIX/$ifindex/vlans/allowed/add", { vlan_ids => $MLNX_DEF_VLAN }];
			$ifc{ALLOWED}{$MLNX_DEF_VLAN} = 1;
			warn "$id: WARNING: Removing last vlan from an ".
			     "equal-mode trunk's allowed list ".
			     "(ifindex: $ifindex).\n";
		    }
		    push @setcmds, ["action", "$MLNX_IFC_PREFIX/$ifindex/vlans/allowed/delete", {vlan_ids => $vlan_number}];
		    delete $ifc{ALLOWED}{$vlan_number};
		}
		last MODESW;
	    };

	    /^hybrid$/ && do {
		# Zap the untagged access vlan back to the default if
		# the given vlan is the same as what is currently set
		# on the port.  Emit a warning when doing this.
		if ($ifc{PVID} == $vlan_number) {
		    push @setcmds, ["set-modify", "$MLNX_IFC_PREFIX/$ifindex/vlans/pvid=$MLNX_DEF_VLAN"];
		    warn "$id: WARNING: native vlan removal requested on ".
			 "dual-mode trunk port on $self->{NAME} ".
			 "(ifindex: $ifindex).\n";
		}
		# Remove the vlan from the allowed list if it's there.
		# Note that the native vlan CANNOT show up in the
		# allowed list on a Mellanox switch (thus the elsif here).
		# When in dual/hybrid mode, the "allow" list CAN be empty.
		elsif (exists($ifc{ALLOWED}{$vlan_number})) {
		    push @setcmds, ["action", "$MLNX_IFC_PREFIX/$ifindex/vlans/allowed/delete", {vlan_ids => $vlan_number}];
		    delete $ifc{ALLOWED}{$vlan_number};
		}
		last MODESW;
	    };

	    # default - if we get here, it's probably because the port is
	    # a member of a portchannel.  Querying the mode seems to not
	    # return anything in this case.  We don't want to do anything
	    # directly to these ports in any case.
	    $self->debug("$id: Unknown port mode ($_) for ifindex $ifindex.\n");
	}
    }

    if (@setcmds) {
	my $resp = $self->callRPC(\@setcmds);
	if (!defined($resp)) {
	    $errors = scalar(@ports);
	}
    }

    $self->unlock();
    return $errors;
}

#
# This is a Mellanox-specific version of removePortsFromVlan that is
# optimized to remove only trunk ports from a single Vlan.
#
sub removeTrunkPortsFromVlan($$) {
    my $self = shift;
    my $vlan = shift;
    my $errors = 0;
    my $id = $self->{NAME} . "::removeTrunkPortsFromVlan($vlan)";

    $self->debug($id."\n");
    
    return 0 if (!defined($vlan));

    #
    # Get the state for all ports
    #
    my @swports = grep {/^\d+$/} keys %{$self->{IFINDEX}};
    my @didports = ();
    $self->lock();
    my $pstates = $self->getPortState(\@swports);
    if (!defined($pstates)) {
	warn "$id: WARNING: Failed to get port states.\n";
	$self->unlock();
	return $errors;
    }

    my @setcmds = ();
    foreach my $ifindex (@swports) {
	my %ifc = %{$pstates->{$ifindex}};

	next
	    if ($ifc{MODE} ne "trunk");

	$self->debug("$id: trunk before: ifindex=$ifindex, vlans: " .
		     join(' ', keys %{$ifc{ALLOWED}}) . "\n", 1);

	#
	# If the vlan is in the allowed list for this trunk link, then remove
	# it from the list. We make sure that all trunks are left with at least
	# the default VLAN.
	#
	if (exists($ifc{ALLOWED}{$vlan})) {
	    if (keys(%{$ifc{ALLOWED}}) == 1) {
		#
		# We are the only VLAN, emit a warning and add the default vlan
		# since trunk ports must be a member of at least one vlan.
		#
		push @setcmds, ["action", "$MLNX_IFC_PREFIX/$ifindex/vlans/allowed/add", { vlan_ids => $MLNX_DEF_VLAN }];
		$ifc{ALLOWED}{$MLNX_DEF_VLAN} = 1;
		warn "$id: WARNING: Removing last vlan from an ".
		    "equal-mode trunk's allowed list ".
		    "(ifindex: $ifindex).\n";
	    }
	    push @setcmds, ["action", "$MLNX_IFC_PREFIX/$ifindex/vlans/allowed/delete", {vlan_ids => $vlan}];
	    delete $ifc{ALLOWED}{$vlan};
	    push @didports, $ifindex;
	}
    }

    if (@setcmds) {
	my $resp = $self->callRPC(\@setcmds);
	if (!defined($resp)) {
	    $errors = 1;
	}

	if (@didports && $self->{DEBUG} > 0) {
	    my $pstates = $self->getPortState(\@didports);
	    if (defined($pstates)) {
		foreach my $ifindex (@didports) {
		    my %ifc = %{$pstates->{$ifindex}};
		    next
			if ($ifc{MODE} ne "trunk");

		    print STDERR "$id: trunk after: ifindex=$ifindex, vlans: ",
			join(' ', keys %{$ifc{ALLOWED}}), "\n";
		}
	    }
	}
    }

    $self->unlock();
    return $errors;
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

    # Just the ifindexes ma'am (filter out the reverse mappings).
    my @allports = grep {/^\d+$/} keys %{$self->{IFINDEX}};

    foreach my $vlan_number (@vlan_numbers) {
	$errors += $self->delPortVlan($vlan_number, @allports);
    }

    return $errors;
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
#              nonative vlan:
#                       untag               
#
# usage: removeSomePortsFromVlan(self,vlan,@ports)
#	 returns 0 on sucess.
#	 returns the number of failed ports on failure.
#
# XXX: why does this function exist?  It seems to have the exact same
#      semantics as delPortVlan(). In fact, that's how it's implemented here.
sub removeSomePortsFromVlan($$@) {
    my ($self, $vlan_number, @ports) = @_;
    my $id = $self->{NAME} . "::removeSomePortsFromVlan";

    $self->debug($id."\n");
    return $self->delPortVlan($vlan_number, @ports);
}

#
# Remove the given VLANs from this switch. Removes all ports from the VLAN,
# The VLAN is given as a VLAN identifier from the database.
#
# usage: removeVlan(self,int vlan)
#	 returns 1 on success
#	 returns 0 on failure
#
sub removeVlan($@) {
    my $self = shift;
    my @vlan_numbers = @_;
    my $errors = 0;
    my $id = $self->{NAME} . "::removeVlan";
    
    $self->removePortsFromVlan(@vlan_numbers);

    my @setcmds = ();
    $self->lock();
    my @curvlans = $self->getAllVlanNumbers();
    foreach my $vlan_number (@vlan_numbers) {
	push @setcmds, ["action", "$MLNX_VLAN_PREFIX/delete", {vlan_id => $vlan_number}]
	    if grep(/^$vlan_number$/, @curvlans);
    }

    my $resp = $self->callRPC(\@setcmds);
    if (!defined($resp)) {
	warn "$id: failed on $self->{NAME}.\n";
	$errors = scalar(@vlan_numbers);
    }

    $self->unlock();
    return $errors ? 0 : 1;
}

#
# Not something we need to support with Mellanox switches.  Only port
# enable and disable are supported, and both can be done inside
# portControl().
#
sub UpdateField($$$@) {
    warn "WARNING: snmpit_mellanox does not support UpdateField().\n";
    return 0;
}

#
# Determine if a VLAN has any members 
# (Used by stack->switchesWithPortsInVlan())
#
sub vlanHasPorts($$) {
    my ($self, $vlan_number) = @_;
    my $id = $self->{NAME}."::vlanHasPorts($vlan_number)";

    my $pstates = $self->getPortState("ALL");
    if (!defined($pstates)) {
	warn "$id: WARNING: Failed to get port states.\n";
	return 0;
    }

    foreach my $ifindex (keys %$pstates) {
	if ($pstates->{$ifindex}{PVID} == $vlan_number ||
	    exists($pstates->{$ifindex}{ALLOWED}{$vlan_number})) {
	    return 1;
	}
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
    my $id = $self->{NAME} . "::listVlans()";
    my @list = ();

    $self->debug($id,1);

    my $pstates = $self->getPortState("ALL");
    if (!defined($pstates)) {
	warn "$id: WARNING: Failed to get port states.\n";
	return undef;
    }

    my @vlcmds = ();
    foreach my $vlan ($self->getAllVlanNumbers()) {
	push @vlcmds, ["get","$MLNX_VLAN_PREFIX/$vlan/name"];
    }
    
    my $resp = $self->callRPC(\@vlcmds);
    if (!defined($resp) || !@$resp) {
	warn "$id: WARNING: Unable to get vlan names.\n";
	return undef;
    }

    foreach my $rv (@$resp) {
	my ($path, $type, $vlname) = @{$rv};
	$path =~ qr|^$MLNX_VLAN_PREFIX/(\d+)/|;
	my $vlnum = $1;
	my @vlifindexes = ();
	foreach my $ifindex (keys %$pstates) {
	    if ($pstates->{$ifindex}{PVID} == $vlnum ||
		exists($pstates->{$ifindex}{ALLOWED}{$vlnum})) {
		push @vlifindexes, $ifindex;
	    }
	}
	my @ports = map {$_->getOtherEndPort()} 
	            $self->convertPortFormat($PORT_FORMAT_PORT, @vlifindexes);
	push @list, [$vlname, $vlnum, \@ports];
    }

    $self->debug("vlan list:\n".Dumper(\@list), 2);
    return @list;
}

#
# List all ports on the device
#
# For Mellanox switches: All ports are always full duplex.
#
# usage: listPorts($self)
# see snmpit_cisco_stack.pm for a description of return value format
#
sub listPorts($) {
    my $self = shift;
    
    my @rv = ();
    my %Able = ();
    my %NodePorts = ();

    my $id = $self->{NAME}."::listPorts";

    my ($varname, $modport, $ifIndex, $portIndex, $status, $portname);

    for (my $ifTable = [$PORT_ADMIN_STATUS, 0]; 
	 $self->{SESS}->getnext($ifTable);
	 $varname =~ /^$PORT_ADMIN_STATUS/) 
    {
	($varname,$ifIndex,$status) = @{$ifTable};

	# Skip non-Ethernet ports.
	next unless exists($self->{IFINDEX}{$ifIndex})
	    && $self->{IFINDEX}{$ifIndex} =~ /^Eth/;			   

	# Make sure this port is wired up and connecting to a node.
	my ($port) = $self->convertPortFormat($PORT_FORMAT_PORT, $ifIndex);
	if (defined($port) && defined($port->getOtherEndPort())) {
	    $self->debug("$varname $ifIndex $status\n");
	    if ($varname =~ /$PORT_ADMIN_STATUS/) { 
		$Able{$ifIndex} = ($status =~ /up/ || "$status" eq $STATUS_UP)  ? "yes" : "no";
		$NodePorts{$ifIndex} = $port->getOtherEndPort();
	    }
	}
    }

    foreach $ifIndex (keys %Able) {
	my ($link, $speed);
	$status = $self->get1($PORT_OPER_STATUS, $ifIndex);
	if (defined($status)) {
	    $link = ($status =~ /up/ || "$status" eq $STATUS_UP) ? "yes" : "no";
	}

	$status = $self->get1($PORT_SPEED, $ifIndex);
	if (defined($status)) {
	    $speed = "$status"."Mbps";
	}

	push @rv, [$NodePorts{$ifIndex}, $Able{$ifIndex},
		   $link, $speed, "full"];
    }

    return @rv;
}

# 
# Get statistics for ports on the switch
#
# usage: getStats($self)
# see snmpit_cisco_stack.pm for a description of return value format
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

    my %allports = ();
    
    #
    # We need to flip the two-dimentional array we got from bulkwalk on
    # its side, and convert ifindexes into Port instance
    #
    my $i = 0;
    my %stats;
    foreach my $array (@stats) {
	while (@$array) {
	    my ($name,$ifindex,$value) = @{shift @$array};

	    # Skip if this isn't an Ethernet port.
	    next unless exists($self->{IFINDEX}{$ifindex});

	    # Make sure this port is wired up and connecting to a node.
	    my ($swport) = $self->convertPortFormat($PORT_FORMAT_PORT, $ifindex);
	    if (defined($swport) && defined($swport->getOtherEndPort())) {
		my $nportstr = $swport->getOtherEndPort()->toTripleString();
		$allports{$nportstr} = $swport;
		${$stats{$nportstr}}[$i] = $value;
	    }
	}
	$i++;
    }

    return map [$allports{$_}, @{$stats{$_}}], sort {tbsort($a,$b)} keys %stats;
}

#
# Used to flush FDB entries easily
#
# usage: resetVlanIfOnTrunk(self, modport, vlan)
#
# note: the modport here is most likely a channel ifindex.
# 
sub resetVlanIfOnTrunk($$$) {
    my ($self, $modport, $vlan) = @_;

    #
    # MAYBE-TODO: check like snmpit_hp?
    #

    $self->setVlansOnTrunk($modport, 0, $vlan);
    $self->setVlansOnTrunk($modport, 1, $vlan);

    return 0;
}

#
# Get the ifindex for an EtherChannel (trunk given as a list of ports)
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

    my @swports = $self->convertPortFormat($PORT_FORMAT_IFINDEX, @ports);
    my @getcmds = ();
    foreach my $ifindex (@swports) {
	push @getcmds, ["get","$MLNX_IFC_PREFIX/$ifindex/lag/membership"];
    }

    my $resp = $self->callRPC(\@getcmds);

    if (!defined($resp)) {
	warn "$id: WARNING: Failed to lookup port channel membership.\n";
	return undef;
    }

    # Go through the LAG membership for each port.  If it's '0', then
    # the port doesn't belong to a LAG.  Otherwise, lookup the LAG's
    # ifindex and set it to be returned.  The index returned by the
    # above "get" calls corresponds to the interface number,
    # e.g. "Po1", not to the ifindex of the LAG interface. As with other
    # snmpit modules, we'll take the first valid interface we find here.
    foreach my $rv (@$resp) {
	my (undef, undef, $chidx) = @$rv;
	if ($chidx != 0 && exists($self->{POIFINDEX}{"Po${chidx}"})) {
	    $chifindex = $self->{POIFINDEX}{"Po${chidx}"};
	    last;
	}
    }

    # If no port channel was found, but only one port was provided, attempt
    # to set the return value to its ifindex.  This follows the semantics in
    # snmpit_cisco.pm
    if (!defined($chifindex) && scalar(@swports) == 1 && $swports[0]) {
	$chifindex = $swports[0];
    }

    if (defined($chifindex)) {
	$self->debug("$id: found channel index $chifindex\n",1);
    } else {
	$self->debug("$id: no channel found for $ports[0] ($swports[0])\n",1);
    }

    return $chifindex;
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
    my $id = $self->{NAME} . "::setVlansOnTrunk";
    my $errors = 0;

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

    my ($poifindex) = $self->convertPortFormat($PORT_FORMAT_IFINDEX, $modport);
    if (!exists($self->{POIFINDEX}{$poifindex})) {
        warn "$id: WARNING: port $modport is not a portchannel.\n";
        # We still want to be able to handle setVlansOnTrunk being called for 
        # non-portchannels.  Loop over the vlans and call the proper functions.
        foreach my $vlan (@vlan_numbers) {
            next unless $self->vlanNumberExists($vlan);
            if ($value == 1) {
                $errors += $self->setPortVlan($vlan, $poifindex);
            } else {
                $errors += $self->removeSomePortsFromVlan($vlan, $poifindex);
            }
        }
        return $errors ? 0 : 1;
    }

    $self->lock();

    my $pstate = $self->getPortState([$poifindex]);
    if (!defined($pstate)) {
	warn "$id: WARNING: Could not get port state for ifindex $poifindex\n";
	$self->unlock();
	return 0;
    }

    # Yuck.  Have to process each vlan in turn, and deal with the "empty list"
    # problem.  More details in the comments below.
    my @setcmds;
    foreach my $vlnum (@vlan_numbers) {
	@setcmds = ();
	# Only attempt removal if the vlan is actually in the allowed list.
	if ($value == 0 && exists($pstate->{$poifindex}{ALLOWED}{$vlnum})) { 
	    # If removing the last entry, then add the default
	    # vlan as a sentinel.  Trunks have to have at least
	    # one entry in their allowed list on Mellanox switches.
	    if (keys(%{$pstate->{$poifindex}{ALLOWED}}) == 1) {
		push @setcmds, ["action","$MLNX_IFC_PREFIX/$poifindex/vlans/allowed/add",{ vlan_ids => $MLNX_DEF_VLAN }];
		$pstate->{$poifindex}{ALLOWED}{$MLNX_DEF_VLAN} = 1;
	    }
	    push @setcmds, ["action","$MLNX_IFC_PREFIX/$poifindex/vlans/allowed/delete",{ vlan_ids => $vlnum }];
	    delete $pstate->{$poifindex}{ALLOWED}{$vlnum};
	}
	# Only add the vlan if it isn't already in the allowed list.
	elsif ($value == 1 && !exists($pstate->{$poifindex}{ALLOWED}{$vlnum})) {
	    push @setcmds, ["action","$MLNX_IFC_PREFIX/$poifindex/vlans/allowed/add",{ vlan_ids => $vlnum }];
	    $pstate->{$poifindex}{ALLOWED}{$vlnum} = 1;
	    # If adding vlans, check to see if the default vlan (sentinel)
	    # is in the allowed list.  Zap it if so.
	    if (exists($pstate->{$poifindex}{ALLOWED}{$MLNX_DEF_VLAN})) {
		push @setcmds, ["action","$MLNX_IFC_PREFIX/$poifindex/vlans/allowed/delete",{ vlan_ids => $MLNX_DEF_VLAN }];
		delete $pstate->{$poifindex}{ALLOWED}{$MLNX_DEF_VLAN};
	    }
	}
	
	my $resp = $self->callRPC(\@setcmds);
	$self->unlock();
	if (!defined($resp)) {
	    warn "$id: WARNING: Could not add vlan $vlnum to portchannel ".
		 "with ifindex $poifindex\n";
	    $errors++;
	} 
    }

    return $errors ? 0 : 1;
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
    my $id = $self->{NAME} .
		"::enablePortTrunking($port,$native_vlan,$equaltrunking)";
    my $retval = 1;

    $self->debug($id."\n");
    if ((!$equaltrunking) &&
	(!defined($native_vlan) || ($native_vlan <= 1))) {
	warn "$id: WARNING: inappropriate or missing PVID for trunk.\n";
	return 0;
    }

    my ($ifindex) = $self->convertPortFormat($PORT_FORMAT_IFINDEX, $port);

    $self->lock();
    my $pstate = $self->getPortState([$ifindex]);
    if (!defined($pstate)) {
	warn "$id: WARNING: unable to get port state for ifindex $ifindex\n";
	return 0;
    }

    my @setcmds = ();
    if ($equaltrunking) {
	# Don't try to enable trunk mode if it's already set on the port.
	if ($pstate->{$ifindex}{MODE} ne "trunk") {
	    push @setcmds, ["set-modify","$MLNX_IFC_PREFIX/$ifindex/vlans/mode=trunk"];

	    # By default Mellanox puts all existing vlans in the 'allowed'
	    # list when a port is placed in 'trunk' mode.  So, we zap the
	    # whole list, save for the given native vlan.  Major derp on
	    # Mellanox's part: You can't ask to delete a vlan from the
	    # allowed list if it isn't actually in the list (even within a
	    # range spec).  Therefore, we have to list out the known vlans
	    # individually for deletion.
	    foreach my $vlnum ($self->getAllVlanNumbers()) {
		push @setcmds, ["action","$MLNX_IFC_PREFIX/$ifindex/vlans/allowed/delete", { vlan_ids => $vlnum }]
		    if $vlnum != $native_vlan;
	    }
	}
	# Add the native vlan if we need to for ports already in trunk mode,
	# unless the requested vlan is the default vlan.
	elsif (!exists($pstate->{$ifindex}{ALLOWED}{$native_vlan})
	       && $native_vlan != $MLNX_DEF_VLAN) {
	    push @setcmds, ["action","$MLNX_IFC_PREFIX/$ifindex/vlans/allowed/add", { vlan_ids => $native_vlan }];
	}
    } else {
	# Mellanox does _not_ put all existing vlans in the allowed list when
	# a port is placed in 'hybrid' mode.  It starts off empty. Way to be 
	# consistent guys!
	push @setcmds, ["set-modify","$MLNX_IFC_PREFIX/$ifindex/vlans/mode=hybrid"]
	    if $pstate->{$ifindex}{MODE} ne "hybrid";
	push @setcmds, ["set-modify","$MLNX_IFC_PREFIX/$ifindex/vlans/pvid=$native_vlan"];
    }

    if (@setcmds) {
	my $resp = $self->callRPC(\@setcmds);
	if (!defined($resp)) {
	    $retval = 0;
	}
	elsif (1) {
	    my $pstate = $self->getPortState([$ifindex]);
	    if (defined($pstate)) {
		print STDERR "$id: trunk: ifindex=$ifindex, vlans: ", join(' ', keys %{$pstate->{$ifindex}{ALLOWED}}), "\n";
	    }
	}
    }

    $self->unlock();
    return $retval;
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

    $self->debug($id."\n");

    my ($ifindex) = $self->convertPortFormat($PORT_FORMAT_IFINDEX, $port);

    $self->lock();
    my $pstate = $self->getPortState([$ifindex]);
    if (!defined($pstate)) {
	warn "$id: WARNING: unable to get port state for ifindex $ifindex\n";
	$self->unlock();
	return 0;
    }

    # If for whatever reason the port is already in access mode, we just
    # abort and report success.
    if ($pstate->{$ifindex}{MODE} eq "access") {
	warn "$id: WARNING: Interface with ifindex $ifindex is ".
	     "already in access mode";
	$self->unlock();
	return 1;
    }

    my @setcmds = ();
    push @setcmds, ["set-modify", "$MLNX_IFC_PREFIX/$ifindex/vlans/mode=access"];
    if ($pstate->{$ifindex}{MODE} eq "hybrid") {
	# The port "forgets" what its native vlan was set to when the mode is
	# changed to "access", so we put it back as the access vlan.
	push @setcmds, ["set-modify", "$MLNX_IFC_PREFIX/$ifindex/vlans/pvid=$pstate->{$ifindex}{PVID}"];
    }

    my $resp = $self->callRPC(\@setcmds);
    if (!defined($resp)) {
	return 0;
    }

    return 1;
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
# Enable Openflow
#
sub enableOpenflow($$) {
    warn "ERROR: Openflow not currently supported on Mellanox switches.\n";
    return 0;
}

#
# Disable Openflow
#
sub disableOpenflow($$) {
    warn "ERROR: Openflow not currently supported on Mellanox switches.\n";
    return 0;
}

#
# Set controller
#
sub setOpenflowController($$$) {
    warn "ERROR: Openflow not currently supported on Mellanox switches.\n";
    return 0;
}

#
# Set listener
#
sub setOpenflowListener($$$) {
    warn "ERROR: Openflow not currently supported on Mellanox switches.\n";
    return 0;
}

#
# Get used listener ports
#
sub getUsedOpenflowListenerPorts($) {
    my %ports = ();

    warn "ERROR: Openflow not currently supported on Mellanox switches.\n";
    return %ports;
}


#
# Check if Openflow is supported on this switch
#
sub isOpenflowSupported($) {
    return 0;
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

# End with true
1;
