#!/usr/bin/perl -W

#
# Copyright (c) 2010-2018 University of Utah and the Flux Group.
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
# snmpit module for Netscout series 3900 layer 1 switch
#

package snmpit_netscout;
use strict;

$| = 1; # Turn off line buffering on output

use English;
use SNMP; 
use snmpit_lib;
use libdb;

use libtestbed;
use Expect;
use Lan;
use Port;


# CLI constants
my $CLI_UNNAMED_PATTERN = "[Uu]nnamed";
my $CLI_UNNAMED_NAME = "unnamed";
my $CLI_NOCONNECTION = "A00";
my $CLI_TIMEOUT = 180;

# commands to show something
my $CLI_SHOW_CONNECTIONS = "show connections raw\r";
my $CLI_SHOW_PORT_NAMES  = "show port names *\r";
my $CLI_SHOW_PORT_RATES  = "show port rate raw *\r";

# mappings from port control command to CLI command
my %portCMDs =
(
    "enable" => "00",
    "disable"=> "00",
    "1000mbit"=> "9F",
    "100mbit"=> "9B",
    "10mbit" => "99",
    "auto"   => "00",
    "full"   => "94",
    "half"   => "8C",
    "auto1000mbit" => "9C",
    "full1000mbit" => "94",
    "half1000mbit" => "8C",
    "auto100mbit"  => "9A",
    "full100mbit"  => "92",
    "half100mbit"  => "8A",
    "auto10mbit"   => "99",
    "full10mbit"   => "91",
    "half10mbit"   => "89",
);

#
# port rate values on Apcon, for raw port info translation 
#
my %portRates =
(
    "00" => ["Auto Negotiate", "auto", "auto"],
    "9F" => ["10/100/1000 Mbps Full/Half Duplex", "auto", "auto"],
    "9C" => ["1000 Mbps Full/Half Duplex", "auto", "1000Mb"],
    "94" => ["1000 Mbps Full Duplex", "full", "1000Mb"],
    "8C" => ["1000 Mbps Half Duplex", "half", "1000Mb"],
    "9B" => ["10/100 Mbps Full/Half Duplex", "auto", "100Mb"],
    "9A" => ["100 Mbps Full/Half Duplex", "auto", "100Mb"],
    "92" => ["100 Mbps Full Duplex", "full", "100Mb"],
    "8A" => ["100 Mbps Half Duplex", "half", "100Mb"],
    "99" => ["10 Mbps Full/Half Duplex", "auto", "10Mb"],
    "91" => ["10 Mbps Full Duplex", "full", "10Mb"],
    "89" => ["10 Mbps Half Duplex", "half", "10Mb"],
    "FF" => ["Analyzer Tap Auto", "auto", "auto"],
    "FC" => ["Analyzer Tap 1000 Mbps Full/Half Duplex", "auto", "1000Mb"],
    "F4" => ["Analyzer Tap 1000 Mbps Full Duplex", "full", "1000Mb"],
    "EC" => ["Analyzer Tap 1000 Mbps Half Duplex", "half", "1000Mb"],
    "FB" => ["Analyzer Tap 10/100 Mbps Full/Half Duplex", "auto", "100Mb"],
    "FA" => ["Analyzer Tap 100 Mbps Full/Half Duplex", "auto", "100Mb"],
    "F2" => ["Analyzer Tap 100 Mbps Full Duplex", "full", "100Mb"],
    "EA" => ["Analyzer Tap 100 Mbps Half Duplex", "half", "100Mb"],
    "F9" => ["Analyzer Tap 10 Mbps Full/Half Duplex", "auto", "10Mb"],
    "F1" => ["Analyzer Tap 10 Mbps Full Duplex", "full", "10Mb"],
    "E9" => ["Analyzer Tap 10 Mbps Half Duplex", "half", "10Mb"],
);

my %emptyVlans = ();

#
# All functions are based on snmpit_hp class.
#
# NOTES: This device is a layer 1 switch that has no idea
# about VLAN. We use the port name on switch as VLAN name here. 
# So in this module, vlan_id and vlan_number are the same 
# thing. vlan_id acts as the port name.
#
# Another fact: the port name can't exist without naming
# a port. So we can't find a VLAN if no ports are in it.
#

#
# Creates a new object.
#
# usage: new($classname,$devicename,$debuglevel,$community)
#        returns a new object.
#
# We actually donot use SNMP, the SNMP values here, like
# community, are just for compatibility.
#
sub new($$$;$) {

    # The next two lines are some voodoo taken from perltoot(1)
    my $proto = shift;
    my $class = ref($proto) || $proto;

    my $name = shift;
    my $debugLevel = shift;
    my $community = shift;  # actually the password for ssh

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

    #
    # A simple trick here: we store the ssh password in the 
    # 'snmp_community' column.
    #
    if ($community) { # Allow this to over-ride the default
        $self->{COMMUNITY}    = $community;
    } else {
        $self->{COMMUNITY}    = $options->{'snmp_community'};
    }
    $self->{PASSWORD} = $self->{COMMUNITY};

    # other global variables
    $self->{DOALLPORTS} = 0;
    $self->{DOALLPORTS} = 1;
    $self->{SKIPIGMP} = 1;

    if ($self->{DEBUG}) {
        print "snmpit_netscout initializing $self->{NAME}, " .
            "debug level $self->{DEBUG}\n" ;   
    }

    $self->{SESS} = undef;
    $self->{CLI_PROMPT} = "=> ";

    # Make it a class object
    bless($self, $class);

    #
    # Lazy initialization of the Expect object is adopted, so
    # we set the session object to be undef.
    #
    $self->{SESS} = undef;

    #$self->readTranslationTable();

    return $self;
}

#
# Create an Expect object that spawns the ssh process 
# to switch.
#
sub createExpectObject($)
{
    my $self = shift;
    
    my $spawn_cmd = "ssh -p 22022 -l administrator $self->{NAME}";
    # Create Expect object and initialize it:
    my $exp = new Expect();
    if (!$exp) {
        # upper layer will check this
        return undef;
    }
    $exp->raw_pty(0);
    $exp->log_stdout(0);
    $exp->spawn($spawn_cmd)
    or die "Cannot spawn $spawn_cmd: $!\n";
    $exp->expect($CLI_TIMEOUT,
         ["administrator\@$self->{NAME}'s password:" => sub { my $e = shift;
                               $e->send($self->{PASSWORD}."\n");
                               exp_continue;}],
         ["Are you sure you want to continue connecting (yes/no)?" => sub { 
                               # Only occurs for the first time connection...
                               my $e = shift;
                               $e->send("yes\n");
                               exp_continue;}],
         ["Access denied. Username/Password is invalid!" => sub { 
                               die "Password incorrect!\n";} ],
         [ timeout => sub { die "Timeout when connect to switch!\n";} ],
         $self->{CLI_PROMPT} );

    $exp->debug(0);
    return $exp;
}

#
# The ports look like 01.02.03 where the first token is always 01,
# the second is the blade (card) and the third if the port. Nice.
#
sub toNetscoutPort($$)
{
        my ($self, $p) = @_;
        
        my $ntsport = $p->getEndByNode($self->{NAME});
        if (!defined($ntsport)) {
        	return $p;
        }
        
        my $card = sprintf("%02d", int($ntsport->card()));
        my $port = sprintf("%02d", int($ntsport->port()));
        
        return "01."."$card".".${port}";
}

sub fromNetscoutPort($$)
{
	my ($self, $ap) = @_;
	
	if ($ap =~ /01\.([0-9]{2})\.([0-9]{2})/) {
                # froms switch to db
                my $card = int($1);
                my $port = int($2);
        
                return Port->LookupByTriple($self->{NAME}, $card, $port);
        }
        
        return $ap;
}


##############################################################################


#
# helper to do CLI command and check the error msg
#
sub doCLICmd($$)
{
    my ($self, $cmd) = @_;
    my $output = "";
    my $exp = $self->{SESS};

    if (!$exp) {
	#
	# Create the Expect object, lazy initialization.
	#
	# We'd better set a long timeout on Apcon switch
	# to keep the connection alive.
	$self->{SESS} = $self->createExpectObject();
	if (!$self->{SESS}) {
	    warn "WARNNING: Unable to connect to $self->{NAME}\n";
	    return (1, "Unable to connect to switch $self->{NAME}.");
	}
	$exp = $self->{SESS};
    }

    $exp->clear_accum(); # Clean the accumulated output, as a rule.
    $exp->send($cmd . "\r");
    $exp->expect($CLI_TIMEOUT,
         [$self->{CLI_PROMPT} => sub {
             my $e = shift;
             $output = $e->before();
          }]);

    $cmd = quotemeta($cmd);
    if ( $output =~ /^($cmd)[\r\n]+ERROR:[\r\n]+(.*)/) {
	$self->debug("snmpit_apcon: Error in doCLICmd: $2\n");
        return (1, $2);
    } else {
        return (0, $output);
    }
}


#
# get the raw CLI output of a command
#
sub getRawOutput($$)
{
    my ($self, $cmd) = @_;
    my ($rt, $output) = $self->doCLICmd($cmd);
    if ( !$rt ) {        
        my $qcmd = quotemeta($cmd);
        if ( $output =~ /^($qcmd)/ ) {
            return substr($output, length($cmd)+1);
        }        
    }

    return undef;
}

#
# Helper
#
sub topologyName($$)
{
    my ($self, $vlan) = @_;
    
    return "lan${vlan}";
}

#
# Get the list of ports in a topology. It is rather annoying that the
# topology tells you what ports are in it, but that does not tell you
# anything about the connections. And the connection list says nothing
# about what topology the connections are attached to. And the port list
# says nothing about what connection or topology the port is attached to.
#
sub topologyPortList($$)
{
    my ($self, $vlan) = @_;
    my $id = $self->{NAME} . ":topologyPortList";
    my %ports = ();
    my $toponame = $self->topologyName($vlan);

    my $raw = $self->getRawOutput("show topology members $toponame");
    if (!defined($raw)) {
	$self->debug("$id: No topology members for $toponame\n");
	return undef;
    }
    my @lines = split("\n", $raw);
    while (@lines) {
	my $line = shift(@lines);

	#
	# Looking for:
	#
	# Stuff ...
	# Ports		: 2
	#   01.02.03
	#   01.02.04
	# More Stuff ...
	#
	if ($line =~ /^Ports\s+:\s+\d+/) {
	    # Gobble.
	    $line = shift(@lines);
	    
	    while ($line =~ /^\s+([0-9]{2}\.[0-9]{2}\.[0-9]{2})/) {
		$ports{$1} = $1;
		$line = shift(@lines);
	    }
	    last;
	}
    }
    $self->debug("$id: ports: " . join(",", keys(%ports)) . "\n");

    return \%ports;
}

#
# See if a pair of ports is in a connection in the lan. We use the
# topology to get all the ports, and then check to see if the ports
# we are asking about are in the list. We do this to avoid messing
# with ports/connections that are not where we think they are.
#
# Note that the topology port list might include tap/mirror ports.
#
sub pairConnected($$$$)
{
    my ($self, $vlan, $port1, $port2) = @_;
    my $id = $self->{NAME} . ":getConnections";

    # all ports in the topology.
    my $ports = $self->topologyPortList($vlan);
    return 0
	if (!defined($ports));
    
    return 1
	if (exists($ports->{$port1}) && exists($ports->{$port2}));
    return 0;
}

#
# Utility function to acl all of the port alarms.
#
sub AckPortAlarms($)
{
    my ($self) = @_;
    my $cmd = "ack port alarm all";

    $self->debug("snmpit_netscout:AckPortAlarms: $cmd\n");

    return $self->doCLICmd($cmd);
}

# 
# Connect ports functions:
#

#
# Make a duplex connection $src <> $dst
# We create a topology (-t) using the vlan_id so we can easily
# figure out what connections make up a vlan. Note that this will
# be just a source and destination, and optionally a tap port.
#
sub connectDuplex($$$$)
{
    my ($self, $vlan_id, $src, $dst) = @_;
    my $cmd = "connect -t lan${vlan_id} -d prtnum $src $dst";

    $self->debug("snmpit_netscout:connectDuplex: $cmd\n");

    return $self->doCLICmd($cmd);
}

#
# Disconnect two ports in a duplex connection.
#
sub disconnectDuplex($$$$) 
{
    my ($self, $vlan_id, $src, $dst) = @_;
    my $cmd = "disconnect -F -t lan${vlan_id} -d prtnum $src $dst";

    $self->debug("snmpit_netscout:disconnectDuplex: $cmd\n");

    return $self->doCLICmd($cmd);
}

#
# Is a port connected (in a connection).
#
sub portConnected($$)
{
    my ($self, $port) = @_;
    my $id = $self->{NAME} . ":portConnected";

    my $raw = $self->getRawOutput("show connected ports sea $port");
    if (!defined($raw)) {
	warn("$id: Error asking if port $port is connected\n");
	return 0;
    }
    foreach my $line ( split /\n/, $raw ) {
	if ($line =~ /$port/) {
	    return 1;
	}
    }
    return 0;
}

#
# Tap a duplex connection.
#
sub tapDuplex($$$$)
{
    my ($self, $vlan_id, $src, $tap) = @_;

    return undef;
}	

sub untapDuplex($$$)
{
    my ($self, $src, $tap) = @_;

    return undef;
}	

#
# Set a variable associated with a port.
#
# usage: portControl($self, $command, @ports)
#     returns 0 on success.
#     returns number of failed ports on failure.
#     returns -1 if the operation is unsupported
#
sub portControl ($$@) {
    my $self = shift;
    my $id = $self->{NAME} . ":portControl";

    my $cmd = shift;
    my @pcports = @_;
    my $errors = 0;

    warn "$id: ignoring '$cmd' for @pcports\n";
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

    if ($self->findVlan($vlan_number)) {
        return 1;
    } else {
        return 0;
    }
}

#
# Original purpose: 
# Given VLAN indentifiers from the database, finds the 802.1Q VLAN
# number for them. If not VLAN id is given, returns mappings for the entire
# switch.
#
# On Netscout switch, no VLAN exists. So we use port name as VLAN name. This 
# funtion actually either list all VLAN names or do the existance checking,
# which will set the mapping value to undef for nonexisted VLANs. 
# 
# usage: findVlans($self, @vlan_ids)
#        returns a hash mapping VLAN ids to ... VLAN ids.
#        any VLANs not found have NULL VLAN numbers
#
sub findVlans($@) { 
    my $self = shift;
    my @vlan_ids = @_;
    my %mapping = ();
    my $id = $self->{NAME} . "::findVlans";
    
    if (scalar(@vlan_ids) > 0) { @mapping{@vlan_ids} = undef; }

    # 
    # Get all topology names, which are considered to be VLAN names.
    #
    my $raw = $self->getRawOutput("show topologies all");
    if (!defined($raw)) {
	warn("$id: Could not get the topology list\n");
	return undef;
    }
    foreach my $line ( split /\n/, $raw ) {
	if ($line =~ /^lan(\d+)\s+(\d+)\s*$/) {
	    if (!@vlan_ids || exists($mapping{$1})) {
		$mapping{$1} = $1;
	    }
	}
    }
    return %mapping;
}


#
# See the comments of findVlans above for explanation.
#
# usage: findVlan($self, $vlan_id,$no_retry)
#        returns the VLAN number for the given vlan_id if it exists
#        returns undef if the VLAN id is not found
#
sub findVlan($$;$) { 
    my $self = shift;
    my $vlan_id = shift;
    my $no_retry = shift; # We ignore this.
    my $id = $self->{NAME} . ":findVlan";

    $self->debug("$id ( $vlan_id )\n",2);

    #
    # We cannot name connections, but we can create a named topology
    # with the same name. See connectDuplex() above.
    #
    my $toponame = "vlan${vlan_id}";

    my ($rt, $output) = $self->doCLICmd("show topology members $toponame");
    return $vlan_id
	if ($rt == 0);

    if ($output !~ /topology not found/i) {
	warn("$id: Unexpected error message: $output\n");
    }
    return undef;
}

#   
# Create a VLAN on this switch, with the given identifier (which comes from
# the database) and given 802.1Q tag number, which is ignored.
#
# usage: createVlan($self, $vlan_id, $vlan_number)
#        returns the new VLAN number on success
#        returns 0 on failure
#
sub createVlan($$$;$) {
    my $self = shift;
    my $vlan_id = shift;
    my $vlan_number = shift; # we ignore tag on Netscout switch
    my $otherargs = shift;
    my $id = $self->{NAME} . ":createVlan";

    #
    # To acts similar to other device modules
    #
    if (!defined($vlan_number)) {
        warn "$id called without supplying vlan_number";
        return 0;
    }
    my $check_number = $self->findVlan($vlan_id,1);
    if (defined($check_number)) {
        warn "$id: recreating vlan id $vlan_id \n";
        return 0;
    }
    
    print "  Creating VLAN $vlan_id as VLAN #$vlan_id on " .
        "$self->{NAME} ...\n";

    #
    # Create a "topology" with this name.
    #
    my $toponame = "lan${vlan_id}";
	
    my ($rt, $output) = $self->doCLICmd("add topology $toponame");
    return $vlan_id
	if ($rt == 0);

    if ($output !~ /already exists/i) {
	warn("$id: Unexpected error: $output\n");
	return 0;
    }
    warn("$id: VLAN $vlan_id already exists. Continuing ...\n");
    return $vlan_id;
}

#
# Put the given ports in the given VLAN. The vlan tag is actually the
# vlan ID (see createVlan() above). And of course, we better get two
# ports since all we can handle is creating a connection between two
# ports. 
#
# usage: setPortVlan($self, $vlan_number, @ports)
#     returns 0 on sucess.
#     returns the number of failed ports on failure.
#
sub setPortVlan($$@) {
    my $self = shift;
    my $vlan_id = shift;
    my @pcports = @_;

    my $id = $self->{NAME} . "::setPortVlan";
    $self->debug("$id: $vlan_id ");
    $self->debug("ports: " . Port->toStrings(@pcports). "\n");

    if (@pcports != 2) {
        warn "$id: supports only two ports in one VLAN.\n";
        return 1;
    }

    my @ports = grep(!ref($_), map( $self->toNetscoutPort($_->getSwitchPort()),
				    @pcports));
    $self->lock();

    # Check if ports are free; they should not be in any other connections.
    foreach my $port (@ports) {
	if ($self->portConnected($port)) {
            warn "$id: ERROR: Port $port already in use.\n";
            $self->unlock();
	    $self->debug("$id: Port $port already in use.\n");
            return 1;
        }
    }

    my ($rt, $msg) = $self->connectDuplex($vlan_id, $ports[0], $ports[1]);
    if ($rt) {
	warn "$id: ERROR: failed to connect @ports: $msg\n";
	$self->debug("$id: failed to connect @ports: $msg\n");
	$self->unlock();
	return 1;
    }
    $self->AckPortAlarms();

    $self->unlock();
    return 0;
}


#
# Remove the given ports from the given VLAN. As above, we better get
# two ports since that is all we can do. 
#
# usage: delPortVlan($self, $vlan_number, @ports)
#     returns 0 on sucess.
#     returns the number of failed ports on failure.
#
sub delPortVlan($$@) {
    my $self = shift;
    my $vlan_id = shift;
    my @pcports = @_;

    my $id = $self->{NAME} . "::delPortVlan";
    $self->debug($self->{NAME} . "::delPortVlan $vlan_id ");
    $self->debug("ports: " . Port->toStrings(@pcports) . "\n");

    if (@pcports != 2) {
        warn "$id: supports only two ports in one VLAN.\n";
        return 1;
    }
    my @ports = grep(!ref($_), map($self->toNetscoutPort($_->getSwitchPort()),
				   @pcports));

    $self->lock();

    #
    # This is just a sanity check to make sure the switch really thinks
    # the ports are in the topology.
    #
    # Simplification; we use deactivate to kill all the connections since
    # if we leave the tap connection the switch gets confused. I think this
    # is okay at this point since all we have are duplex connections between
    # two ports, with optional tap ports.
    #
    if (!$self->pairConnected($vlan_id, @ports)) {
	warn("$id: ERROR: Ports are not connected in $vlan_id: @ports\n");
        $self->unlock();
	return 1;
    }
    return $self->removePortsFromVlan($vlan_id);
    $self->unlock();
    return 0;
}

#
# Disables all ports in the given VLANS. Each VLAN is given as a VLAN
# 802.1Q tag value.
#
# usage: removePortsFromVlan(self,@vlan)
#     returns 0 on sucess.
#     returns the number of failed ports on failure.
#
sub removePortsFromVlan($@) {
    my $self = shift;
    my @vlan_numbers = @_;
    my $errors = 0;
    my $id = $self->{NAME} . "::removePortsFromVlan";

    #
    # We can use the topology deactivate command; it will remove all the
    # connections, which is typically just one connection. But might also
    # include tap connections in the future.
    #
    # Note; if we remove the connection without removing the tap connection,
    # things get confused for the topology.
    #
    foreach my $vlan_id (@vlan_numbers) {
	my $toponame = $self->topologyName($vlan_id);

	#
	# Get the port list first; we are going to have to remove all the
	# ports from the topology after we deactivate it. 
	#
	my $ports = $self->topologyPortList($vlan_id);
	if (!defined($ports)) {
	    $errors++;
	    next;
	}
	my ($rt, $output) = $self->doCLICmd("deactivate topology $toponame");
	if ($rt) {
	    if ($output !~ /Nothing to deactivate/i) {
		warn("$id: ERROR: Failed to deactivate $vlan_id: $output\n");
		$errors++;
	    }
	}
    }
    return $errors;
}

#
# Removes and disables some ports in a given VLAN.
# The VLAN is given as a VLAN 802.1Q tag value.
#
# This function is the same to delPortVlan because
# disconnect a connection will disable its two endports
# at the same time.
#
# usage: removeSomePortsFromVlan(self,vlan,@ports)
#     returns 0 on sucess.
#     returns the number of failed ports on failure.
#
sub removeSomePortsFromVlan($$@) {
    my ($self, $vlan_number, @ports) = @_;
    return $self->delPortVlan($vlan_number, @ports);
}

#
# Remove the given VLANs from this switch. Removes all ports from the VLAN,
# The VLAN is given as a VLAN identifier from the database.
#
# usage: removeVlan(self,int vlan)
#     returns 1 on success
#     returns 0 on failure
#
#
sub removeVlan($@) {
    my $self = shift;
    my @vlan_numbers = @_;
    my $id = $self->{NAME} . "::removeVlan";
    my $errors = 0;

    foreach my $vlan_id (@vlan_numbers) {
        if ($self->removePortsFromVlan($vlan_id)) {
            $errors++;
        }
	else {
	    #
	    # Killing the topology kills our record of the vlan.
	    #
	    my $toponame = "lan${vlan_id}";
	    my ($rt, $output) = $self->doCLICmd("delete topology $toponame");
	    if ($rt) {
		if ($output !~ /topology not found/i) {
		    warn("$id: ERROR: Could not remove vlan: $output\n");
		    $errors++;
		}
	    }
            print "Removed VLAN $vlan_id on switch $self->{NAME}.\n";    
        }    
    }

    return ($errors == 0) ? 1:0;
}


#
# Determine if a VLAN has any members 
# (Used by stack->switchesWithPortsInVlan())
#
sub vlanHasPorts($$) {
    my ($self, $vlan_number) = @_;
    my $id = $self->{NAME} . "::vlanHasPorts";
    my $ports = $self->topologyPortList($vlan_number);

    return 1
	if (defined($ports) && keys(%{$ports}));

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
    my $id = $self->{NAME} . ":listVlans";
    my @list = ();
    
    #
    # We want the list of all topologies with the proper name.
    #
    my $raw = $self->getRawOutput("show topologies all");
    if (!defined($raw)) {
	warn "$id: Could not get topology list\n";
	return ();
    }
    foreach my $line ( split /\n/, $raw ) {
	if ($line =~ /^lan(\d+)\s+(\d+)\s*$/) {
	    my $vlan_id = $1;
	    my $ports = $self->topologyPortList($vlan_id);
	    next
		if (!defined($ports));

	    my @pcports = map($_->getPCPort(), 
			      grep(ref($_), 
				   map($self->fromNetscoutPort($_),
				       keys(%{$ports}))));
        
	    push @list, [$vlan_id, $vlan_id, \@pcports];
	}
    }
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
    my $id = $self->{NAME} . ":listPorts";
    my @ports = ();

    my $raw = $self->getRawOutput("show port *\r");
    if (!defined($raw)) {
        warn "$id could not get port rawinfo *\n";
	return undef;
    }
    foreach my $line ( split /\n/, $raw ) {	
	my $port;
	my $enabled;
	my $up     = "down";
	my $speed  = "???";
	my $duplex = "full";

	# First token is the portnum.
	if ($line =~ /^([0-9]{2}\.[0-9]{2}\.[0-9]{2})/) {
	    $port = $self->fromNetscoutPort($1);
	    if (!ref($port)) {
		warn "$id: Could not map to Port: '$1'\n";
		next;
	    }
	    $port = $port->getPCPort();
	}
	else {
	    # Skip the noise.
	    next;
	}
	if ($line =~ /Not Connected/) {
	    $enabled = "no";
	}
	else {
	    $enabled = "yes";
	}
	if ($line =~ /Error/ || $line =~ /Not Present/) {
	    $up = "down";
	}
	if ($line =~ /\s+(\d+)\s+/) {
	    $speed = $1;
	}
	push(@ports, [$port, $enabled, $up, $speed, $duplex]);
    }
    return @ports;
}

# 
# Get statistics for ports on the switch
#
# Unsupported operation on Apcon 2000-series switch via CLI.
#
# usage: getStats($self)
# see snmpit_cisco_stack.pm for a description of return value format
#
#
sub getStats() {
    my $self = shift;

    warn "Port statistics are unavaialble on our Apcon 2000 switch.";
    return undef;
}


#
# Get the ifindex for an EtherChannel (trunk given as a list of ports)
#
# usage: getChannelIfIndex(self, ports)
#        Returns: undef if more than one port is given, and no channel is found
#           an ifindex if a channel is found and/or only one port is given
#
sub getChannelIfIndex($@) {
    warn "ERROR: Apcon switch doesn't support trunking";
    return undef;
}


#
# Enable, or disable,  port on a trunk
#
# usage: setVlansOnTrunk(self, modport, value, vlan_numbers)
#        modport: module.port of the trunk to operate on
#        value: 0 to disallow the VLAN on the trunk, 1 to allow it
#     vlan_numbers: An array of 802.1Q VLAN numbers to operate on
#        Returns 1 on success, 0 otherwise
#
sub setVlansOnTrunk($$$$) {
    warn "ERROR: Apcon switch doesn't support trunking";
    return 0;
}

#
# Enable trunking on a port
#
# usage: enablePortTrunking2(self, modport, nativevlan, equaltrunking)
#        modport: module.port of the trunk to operate on
#        nativevlan: VLAN number of the native VLAN for this trunk
#     equaltrunk: don't do dual mode; tag PVID also.
#        Returns 1 on success, 0 otherwise
#
sub enablePortTrunking2($$$$) {
    warn "ERROR: Apcon switch doesn't support trunking";
    return 0;
}

#
# Disable trunking on a port
#
# usage: disablePortTrunking(self, modport)
#        modport: module.port of the trunk to operate on
#        Returns 1 on success, 0 otherwise
#
sub disablePortTrunking($$;$) {
    warn "ERROR: Apcon switch doesn't support trunking";
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


#
# Enable Openflow
#
sub enableOpenflow($$) {
    warn "ERROR: Apcon switch doesn't support Openflow now";
    return 0;
}

#
# Disable Openflow
#
sub disableOpenflow($$) {
    warn "ERROR: Apcon switch doesn't support Openflow now";
    return 0;
}

#
# Set controller
#
sub setOpenflowController($$$) {
    warn "ERROR: Apcon switch doesn't support Openflow now";
    return 0;
}

#
# Set listener
#
sub setOpenflowListener($$$) {
    warn "ERROR: Apcon switch doesn't support Openflow now";
    return 0;
}

#
# Get used listener ports
#
sub getUsedOpenflowListenerPorts($) {
    my %ports = ();

    warn "ERROR: Apcon switch doesn't support Openflow now";
    return %ports;
}


#
# Check if Openflow is supported on this switch
#
sub isOpenflowSupported($) {
    return 0;
}


#
# Print warning messages for empty VLANs that will be deleted 
# after unloading the package.
#
END 
{

}

# End with true
1;
