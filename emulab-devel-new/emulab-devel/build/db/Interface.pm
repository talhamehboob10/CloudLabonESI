#!/usr/bin/perl -wT
#
# Copyright (c) 2005-2018 University of Utah and the Flux Group.
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
package Interface;

use strict;
use Exporter;
use vars qw(@ISA @EXPORT);

@ISA    = "Exporter";
@EXPORT = qw ( );

use libdb;
use libtestbed;
use emutil qw(GenFakeMac);
use English;
use Carp qw(cluck);
use Data::Dumper;
use overload ('""' => 'Stringify');

# Configure variables
my $TB		= "/users/mshobana/emulab-devel/build";
my $BOSSNODE    = "boss.cloudlab.umass.edu";

# Cache of instances to avoid regenerating them.
my %all_interfaces   = ();
my %node_interfaces  = ();
BEGIN { use emutil;
	emutil::AddCache(\%all_interfaces); 
	emutil::AddCache(\%node_interfaces); }

# Manual
my $debug = 0;

#
# Lookup interfaces for a node and create a list of class instances to return.
# When using this interface we assume that this is the node side and
# the corresponding wire is node_id1.
#
sub LookupAll($$$)
{
    my ($class, $nodeid, $pref) = @_;
    my $node;

    if (ref($nodeid)) {
	$node   = $nodeid;
	$nodeid = $node->node_id();
    }
    else {
	require Node;
	$node = Node->Lookup($nodeid);
	if (!defined($node)) {
	    print STDERR "No such node in the DB: $nodeid\n";
	    return -1;
	}
    }
    # Look in cache first
    if (exists($node_interfaces{$nodeid})) {
	@$pref = @{ $node_interfaces{$nodeid} };
	return 0;
    }
    @$pref = ();

    #
    # Interfaces on dynamic virtnodes are marked with the logical flag.
    # We want those. But we want to ignore them on physical nodes, since
    # those refer to MLE interfaces.
    #
    my $logical_clause = ($node->isvirtnode() ? "" : "and i.logical=0");

    my $query_result =
	DBQueryWarn("select i.*,w.card1,w.port1 from interfaces as i ".
		    "left join wires as w on ".
		    "     w.node_id1=i.node_id and w.iface1=i.iface ".
		    "where i.node_id='$nodeid' $logical_clause");

    return -1
	if (!$query_result);
    return 0
	if (!$query_result->numrows);

    my $results = [];

    while (my $rowref = $query_result->fetchrow_hashref()) {
	my $iface = $rowref->{'iface'};
	my $card1 = $rowref->{'card1'};
	my $port1 = $rowref->{'port1'};
	my $interface;

	# Clean up the array, not part of the interface.
	delete($rowref->{'card1'});
	delete($rowref->{'port1'});

	#
	# If we already have this in the interface cache, lets not create
	# another one. Just use that one.
	#
	if (exists($all_interfaces{"$nodeid:$iface"})) {
	    $interface = $all_interfaces{"$nodeid:$iface"};
	}
        elsif (defined($card1) && defined($port1) &&
	       exists($all_interfaces{"$nodeid:$card1:$port1"})) {
	    $interface = $all_interfaces{"$nodeid:$card1:$port1"};
	}
	else {
	    $interface = {};

	    #
	    # Remove card,port in the results in preparation for removal
	    # from the table.
	    #
	    delete($rowref->{'card'})
		if (exists($rowref->{'card'}));
	    delete($rowref->{'port'})
		if (exists($rowref->{'port'}));
	
	    $interface->{"DBROW"}  = $rowref;
	    bless($interface, $class);

	    #
	    # Grab the wires table entry if there is one.
	    #
	    if (defined($card1) && defined($port1)) {
		my $wire = Interface::Wire->Lookup("$nodeid:$card1:$port1");
		if (!defined($wire)) {
		    print STDERR "*** Could not look up wire: ".
			"$nodeid:$card1:$port1\n";
		    return -1;
		}
		$interface->{'WIRE'} = $wire;

		#
		# Since we have a wire, we can set the card/port slots
		# for the interface. Basically, if an interface is not
		# wired up, then asking for its card/port is a nonsensical
		# thing to do and we will spit out a warning when that
		# happens so we can clean up the code.
		#
		$interface->{'CARD'} = $card1;
		$interface->{'PORT'} = $port1;
		
		# Cache
		$all_interfaces{"$nodeid:$card1:$port1"} = $interface;
	    }
	    else {
		$interface->{'WIRE'} = undef;
	    }

	    #
	    # And the interface_state table.
	    #
	    my $state_result =
		DBQueryWarn("select * from interface_state ".
			    "where node_id='$nodeid' and iface='$iface'");

	    return -1
		if (!$state_result);
	    if (!$state_result->numrows) {
		print STDERR
		    "*** Missing interface_state table entry for interface\n".
		    "    $nodeid:$iface.\n";
		return -1;
	    }
	    #
	    # Remove card,port in the results in preparation for removal
	    # from the table.
	    #
	    delete($state_result->{'card'})
		if (exists($state_result->{'card'}));
	    delete($state_result->{'port'})
		if (exists($state_result->{'port'}));
	    
	    $interface->{'STATE'} = $state_result->fetchrow_hashref();

	    # Cache.
	    $all_interfaces{"$nodeid:$iface"} = $interface;
	}
	push(@{ $results }, $interface);
    }
    # Add to cache of node interfaces
    $node_interfaces{$nodeid} = $results;
    
    @$pref = @{ $results };
    return 0;
}
# accessors
sub field($$)  { return ((! ref($_[0])) ? -1 : $_[0]->{'DBROW'}->{$_[1]}); }
sub node_id($) { return field($_[0], 'node_id'); }
sub iface($)   { return field($_[0], 'iface'); }
sub mac($)     { return field($_[0], 'mac'); }
sub IP($)      { return field($_[0], 'IP'); }
sub role($)    { return field($_[0], 'role'); }
sub type($)    { return field($_[0], 'interface_type'); }
sub logical($) { return field($_[0], 'logical'); }
sub speed($)   { return field($_[0], 'current_speed'); }
sub trunk_mode($) { return field($_[0], 'trunk_mode'); }
sub trunk($)   { return field($_[0], 'trunk'); }
sub whol($)    { return field($_[0], 'whol'); }
sub current_speed($) { return field($_[0], 'current_speed'); }
sub mask($)    { return field($_[0], 'mask'); }
sub uuid($)    { return field($_[0], 'uuid'); }
# These are special, now that interfaces no longer have card,port.
# There must be a wire to get that info.
sub card($)
{
    my ($self) = @_;

    if (!defined($self->{'CARD'})) {
	cluck("*** Wanted card, but no wire: $self");
	return undef;
    }
    return $self->{'CARD'};
}
sub port($)
{
    my ($self) = @_;

    if (!defined($self->{'PORT'})) {
	cluck("*** Wanted port, but no wire: $self");
	return undef;
    }
    return $self->{'PORT'};
}
# These are for the updatewires script.
sub card_saved($) { return field($_[0], 'card_saved'); }
sub port_saved($) { return field($_[0], 'port_saved'); }
# Wires table
sub wire($)    { return $_[0]->{'WIRE'}; }
sub wiredup($) { return (defined($_[0]->{'WIRE'}) ? 1 : 0); }
sub wirefield($$) {
    my ($self, $slot) = @_;
    if (!$self->wiredup()) {
	cluck("*** $self is not wired up, but asked for wire $slot!");
	return undef;
    }
    return $self->wire()->field($slot);
}
sub wire_type($)   { return $_[0]->wirefield('type'); }
sub wire_iface($)  { return $_[0]->wirefield('iface2'); }
sub switch_id($)   { return $_[0]->wirefield('node_id2'); }
sub switch_card($) { return $_[0]->wirefield('card2'); }
sub switch_port($) { return $_[0]->wirefield('port2'); }
sub wire_unused($) { return $_[0]->wire_type() eq "Unused" ? 1 : 0; }
# Interface State table
sub state($)       { return $_[0]->{'STATE'}; }
sub enabled($)     { return $_[0]->state()->{'enabled'}; }
sub tagged($)      { return $_[0]->state()->{'tagged'}; }
sub remaining_bandwidth { return $_[0]->state()->{'remaining_bandwidth'}; }

sub IsExperimental($)
{
    my ($self) = @_;

    return $self->role() eq TBDB_IFACEROLE_EXPERIMENT();
}
sub IsControl($)
{
    my ($self) = @_;

    return $self->role() eq TBDB_IFACEROLE_CONTROL();
}

sub IsManagement($)
{
    my ($self) = @_;

    return $self->role() eq TBDB_IFACEROLE_MANAGEMENT();
}

#
# Lookup by card,port. When using this interface we assume that this
# is the node side and the corresponding wire is node_id1.
#
# This is a bit of a legacy interface.
#
sub Lookup($$$;$)
{
    my ($class, $nodeid, $card, $port) = @_;

    $nodeid = $nodeid->node_id()
	if (ref($nodeid));

    # XXX: the node side always uses port 1.
    $port = 1
	if (!defined($port));

    cluck("Legacy Interface->Lookup($nodeid,$card,$port)");

    # Look in cache first
    return $all_interfaces{"$nodeid:$card:$port"}
        if (exists($all_interfaces{"$nodeid:$card:$port"}));

    #
    # Look in the wires table, in preparation for removing card,port from
    # the interfaces table.
    #
    my $wire = Interface::Wire->Lookup("$nodeid:$card:$port");
	
    #
    # If no wires entry and a legacy lookup, warn.
    #
    if (!defined($wire)) {
	cluck("*** No wires entry for Interface->Lookup($nodeid,$card,$port)");
	return undef;
    }
    return Interface->LookupByIface($nodeid, $wire->iface1());
}

sub Flush($)
{
    my ($self) = @_;
    my $nodeid  = $self->node_id();
    my $iface   = $self->iface();

    delete($all_interfaces{"$nodeid:$iface"});

    #
    # Check for cache entry by wire card,port.
    #
    if ($self->wiredup()) {
	my $card    = $self->card();
	my $port    = $self->port();
	delete($all_interfaces{"$nodeid:$card:$port"});
    }
}

#
# Refresh instance by reloading from the DB.
#
sub Refresh($)
{
    my ($self) = @_;

    return -1
	if (! ref($self));

    my $nodeid  = $self->node_id();
    my $iface   = $self->iface();

    my $query_result =
	DBQueryWarn("select * from interfaces ".
		    "where node_id='$nodeid' and iface='$iface'");
    return undef
	if (!$query_result || !$query_result->numrows);
    
    my $rowref = $query_result->fetchrow_hashref();    

    #
    # Remove card,port in the results in preparation for removal
    # from the table. If we have a wire, we do want card/port in
    # the interface.
    #
    delete($rowref->{'card'})
	if (exists($rowref->{'card'}));
    delete($rowref->{'port'})
	if (exists($rowref->{'port'}));

    $self->{"DBROW"} = $rowref;
    
    #
    # And the interface_state table.
    #
    if (defined($self->{'STATE'})) {
	$query_result =
	    DBQueryWarn("select * from interface_state ".
			"where node_id='$nodeid' and iface='$iface'");
	return undef
	    if (!$query_result || !$query_result->numrows);

	my $state_result = $query_result->fetchrow_hashref();

	#
	# Remove card,port in the results in preparation for removal
	# from the table.
	#
	delete($state_result->{'card'})
	    if (exists($state_result->{'card'}));
	delete($state_result->{'port'})
	    if (exists($state_result->{'port'}));
	
	$self->{'STATE'} = $state_result;
    }
    return 0;
}

#
# Create a new interface record. This also handles the wires table entries.
#
sub Create($$$)
{
    my ($class, $node, $argref) = @_;
    my ($card,$port);

    return undef
	if (! (ref($node) && ref($argref)));

    if (exists($argref->{'switch_id'})) {
	print STDERR "*** Creating a wire in Interface->Create() is no ".
	    "longer supported!\n";
	return undef;
    }
    if (exists($argref->{'card'})) {
	if (!DBSlotExists("interfaces", "card")) {
	    print STDERR "*** Interface->Create(): ignoring card/port, these ".
		"are now set with the wire.\n";
	}
	else {
	    $card = $argref->{'card'};
	    $port = $argref->{'port'};
	}
    }

    my $node_id = $node->node_id();

    my $MAC        = $argref->{'MAC'} || $argref->{'mac'};
    my $IP         = $argref->{'IP'};
    my $mask       = $argref->{'mask'};
    my $iftype     = $argref->{'type'} || $argref->{'interface_type'};
    my $ifrole     = $argref->{'role'};
    my $uuid       = $argref->{'uuid'};
    my $max_speed  = $argref->{'max_speed'};
    my $duplex     = $argref->{'duplex'};
    my $iface      = $argref->{'iface'};
    my $logical    = $argref->{'logical'};
    my $trunk      = $argref->{'trunk'};
    my $auto       = $argref->{'autocreated'};

    $IP = ""
	if (!defined($IP));
    $mask = ""
	if (!defined($mask));
    $duplex = "full"
	if (!defined($duplex));
    $max_speed = 0
	if (!defined($max_speed));
    $logical = 0
	if (!defined($logical));
    $auto = 0
	if (!defined($auto));
    $trunk = 0
	if (!defined($trunk));
    if (!defined($uuid)) {
	$uuid = NewUUID();
	if (!defined($uuid)) {
	    print STDERR "Could not generate a UUID!\n";
	    return undef;
	}
    }
    if (! (defined($ifrole) && defined($MAC) && defined($IP) && 
	   defined($iftype) && defined($iface) && defined($max_speed) &&
	   defined($duplex) && defined($uuid))) {
	print STDERR "Interface::Create: Missing fields in arguments:\n";
	print STDERR Dumper($argref);
	return undef;
    }

    # Lets make keep the special characters to a reasonable set.
    # Mike says no commas please.
    if ($iface !~ /^[-\w\/\.:]+$/) {
	print STDERR "Interface::Create: illegal characters in iface:\n";
	return undef;
    }

    #
    # Lock the tables to prevent concurrent creation
    #
    DBQueryWarn("lock tables interfaces write, ".
		"            interface_state write, ".
		"            vinterfaces read, ".
		"            node_history read, ".
		"            wires write")
	or return undef;

    #
    # See if we have a record; if we do, we can stop now. This is
    # not actually correct, since creating a node is not atomic.
    #
    my $query_result =
	DBQueryWarn("select node_id from interfaces ".
		    "where node_id='$node_id' and iface='$iface'");
    if ($query_result->numrows) {
	DBQueryWarn("unlock tables");
	return Interface->LookupByIface($node_id, $iface);
    }

    #
    # Generate a fake mac if requested. 
    #
    if ($MAC eq "genfake") {
	while (1) {
	    $MAC = GenFakeMac();

	    # Check to make sure unique. If not, try again.
	    $query_result =
		DBQueryWarn("(select mac from interfaces ".
			    " where mac='$MAC') ".
			    "union ".
			    "(select mac from vinterfaces ".
			    " where mac='$MAC') ".
			    "union ".
			    "(select cnet_mac as mac from node_history ".
			    " where cnet_mac='$MAC')");
	    if (!$query_result) {
		DBQueryWarn("unlock tables");
		return undef;
	    }
	    last
		if (!$query_result->numrows);
	}
    }
    
    if (!DBQueryWarn("insert into interfaces set ".
		"  node_id='$node_id', logical='$logical', " .
		"  role='$ifrole', ".
	        (defined($card) ? "  card=$card, port=$port, " : "") .
		"  mac='$MAC', IP='$IP', autocreated='$auto', " .
		(defined($mask) ? "mask='$mask', " : "") .
		($trunk ? "trunk='1', " : "") .
		"  interface_type='$iftype', iface='$iface', " .
		"  current_speed='$max_speed', duplex='$duplex', ".
		"  uuid='$uuid'")) {
	DBQueryWarn("unlock tables");
	return undef;
    }

    if (!DBQueryWarn("insert into interface_state set ".
		     "  node_id='$node_id', " .
		     (defined($card) ? "  card=$card, port=$port, " : "") .
		     ($trunk ? "remaining_bandwidth='$max_speed', " : "") .
		     "  iface='$iface'")) {
	DBQueryWarn("delete from interfaces ".
		    "where node_id='$node_id' and iface='$iface' ");
	DBQueryWarn("unlock tables");
	return undef;
    }

    DBQueryWarn("unlock tables");
    return Interface->LookupByIface($node_id, $iface);
}

#
# Delete a logical interface.
#
sub Delete($;$)
{
    my ($self, $real) = @_;
    my $logical = ($real ? 0 : 1);

    if ($logical && !$self->logical()) {
	print STDERR "Refusing to delete real $self\n";
	return -1;
    }
    my $node_id = $self->node_id();
    my $iface   = $self->iface();

    return -1
	if (!DBQueryWarn("delete from interface_state ".
			 "where node_id='$node_id' and iface='$iface'"));
    return -1
	if (!DBQueryWarn("delete from port_counters ".
			 "where node_id='$node_id' and iface='$iface'"));
    return -1
	if (!DBQueryWarn("delete from interfaces ".
			 "where logical=$logical and ".
			 "      node_id='$node_id' and iface='$iface'"));
    return 0;
}

#
# Delete this interface's wire entry.
#
sub DeleteWire($)
{
    my ($self) = @_;

    return 0
	if (!$self->wiredup());
    
    my $node_id = $self->node_id();
    my $card    = $self->card();
    my $port    = $self->port();

    return -1
	if (!DBQueryWarn("delete from wires ".
			 "where node_id1='$node_id' and card1='$card' and ".
			 "      port1='$port'"));
    return 0;
}

#
# Create a fake object, as for the mapper (assign_wrapper) during debugging.
# Port library uses this too.
#
sub MakeFake($$$)
{
    my ($class, $node, $argref) = @_;
    my ($card,$port);

    my $query_result =
	DBQueryWarn("show columns from interfaces");
    return undef
	if (!$query_result);
    
    while (my ($slot) = $query_result->fetchrow_array()) {
	if (!exists($argref->{$slot})) {
	    $argref->{$slot} = "";
	}
    }
    my $self            = {};
    my $nodeid = ref($node) ? $node->node_id() : $node;
    $argref->{'node_id'} = $nodeid;
    
    if (exists($argref->{'card'})) {
	$card = $argref->{'card'};
	$port = $argref->{'port'};
	delete($argref->{'card'});
	delete($argref->{'port'});
	$self->{'CARD'} = $card;
	$self->{'PORT'} = $port;
    }
    $self->{"DBROW"}    = $argref;
    $self->{"WIRE"}     = undef;
    $self->{"STATE"}    = {
	"node_id"  => $nodeid,
	"iface"    => $argref->{'iface'},
	"tagged"   => 0,
	"enabled"  => 1,
    };
    bless($self, $class);

    # Cache by card,port and by iface
    my $iface = $argref->{'iface'};
    $all_interfaces{"$nodeid:$iface"}      = $self;

    if (defined($card)) {
	$all_interfaces{"$nodeid:$card:$port"} = $self;
    }
    return $self;
}

#
# Lookup by iface
#
sub LookupByIface($$$)
{
    my ($class, $nodeid, $iface) = @_;
    my $interface = {};
    my $state_row;
    my $wire;

    $nodeid = $nodeid->node_id()
	if (ref($nodeid));

    # Look in cache first
    return $all_interfaces{"$nodeid:$iface"}
    if (exists($all_interfaces{"$nodeid:$iface"}));

    # Used from Protogeni code, so be careful.
    return undef
	if (! ($nodeid =~ /^[-\w]+$/ && $iface =~ /^[-\w\/\.:]+$/));

    my $query_result =
	DBQueryWarn("select * from interfaces ".
		    "where node_id='$nodeid' and iface='$iface'");
    return undef
	if (!$query_result);

    #
    # If no interfaces entry, this is bad.
    #
    if (!$query_result->numrows) {
	if ($debug) {
	    cluck("*** No interface entry for ".
		  "Interface->LookupByIface($nodeid,$iface)");
	}
	return undef;
    }
    my $rowref = $query_result->fetchrow_hashref();

    #
    # Remove card,port in the results in preparation for removal
    # from the table.
    #
    if (exists($rowref->{'card'})) {	
	$rowref->{'card_saved'} = $rowref->{'card'};
	delete($rowref->{'card'})
    }
    if (exists($rowref->{'port'})) {
	$rowref->{'port_saved'} = $rowref->{'port'};
	delete($rowref->{'port'})
    }

    #
    # And the interface_state table.
    #
    $query_result =
	DBQueryWarn("select * from interface_state ".
		    "where node_id='$nodeid' and iface='$iface'");
    return undef
	if (!$query_result);

    #
    # If a management interface or a switch, the lack of an interface_state
    # record is not a big deal, so let it slide. If it is a real node, then
    # whine about it but keep going. 
    #
    if (!$query_result->numrows) {
	require Node;
	my $node = Node->Lookup($nodeid);
	if (! ($rowref->{'role'} eq TBDB_IFACEROLE_MANAGEMENT() ||
	       (defined($node) && $node->role() ne "testnode"))) {
	    print STDERR "*** Missing missing interface_state ".
		"for $nodeid:$iface\n";
	}
    }
    else {
	$state_row = $query_result->fetchrow_hashref();

	#
	# Remove card,port in the results in preparation for removal
	# from the table.
	#
	delete($state_row->{'card'})
	    if (exists($state_row->{'card'}));
	delete($state_row->{'port'})
	    if (exists($state_row->{'port'}));
    }
    $interface->{"DBROW"} = $rowref;
    $interface->{'STATE'} = $state_row;
    $interface->{'WIRE'}  = undef;
    bless($interface, $class);

    # Does not have to exist.
    if ($interface->logical()) {
	$wire = Interface::LogicalWire->Lookup($nodeid, $iface);
    }
    else {
	$wire = Interface::Wire->LookupAnyByIface($nodeid, $iface);
    }
    
    # Cache by card,port and by iface
    $all_interfaces{"$nodeid:$iface"} = $interface;

    if (defined($wire)) {
	my ($card,$port);
	
	#
	# We still have to assume that the node is the node_id1 side of
	# the wire, at least for now. So if the interface corresponds
	# to the node_id2 side, get the card/port, but do not stash the
	# wire (wireup() is false). Need to come back to this later.
	#
	if ($wire->node_id1() eq $nodeid) {
	    $card = $wire->card1();
	    $port = $wire->port1();
	    $interface->{'WIRE'} = $wire;
	}
	else {
	    $card = $wire->card2();
	    $port = $wire->port2();
	}
	$all_interfaces{"$nodeid:$card:$port"} = $interface;

	$interface->{'CARD'} = $card;
	$interface->{'PORT'} = $port;
    }
    return $interface;
}

#
# Lookup by mac
#
sub LookupByMAC($$)
{
    my ($class, $mac) = @_;
    my $safe_mac = DBQuoteSpecial($mac);

    my $query_result =
	DBQueryWarn("select node_id,iface from interfaces ".
		    "where mac=$safe_mac");

    return undef
	if (!$query_result);
    return undef
	if (!$query_result->numrows);
    
    my ($nodeid, $iface) = $query_result->fetchrow_array();

    return Interface->LookupByIface($nodeid, $iface);
}

#
# Lookup by IP, but only on control or management interfaces.
# Makes no sense for experimental.
#
sub LookupByIP($$)
{
    my ($class, $ip) = @_;
    my $safe_ip = DBQuoteSpecial($ip);

    my $query_result =
	DBQueryWarn("select node_id,iface from interfaces ".
		    "where ip=$safe_ip and ".
		    "      (role='" . TBDB_IFACEROLE_CONTROL()  . "' or ".
		    "       role='" . TBDB_IFACEROLE_MANAGEMENT()  . "')");

    return undef
	if (!$query_result);
    return undef
	if (!$query_result->numrows);
    
    my ($nodeid, $iface) = $query_result->fetchrow_array();

    return Interface->LookupByIface($nodeid, $iface);
}

#
# Lookup by uuid
#
sub LookupByUUID($$)
{
    my ($class, $uuid) = @_;

    if (! ($uuid =~ /^\w+\-\w+\-\w+\-\w+\-\w+$/)) {
	return undef;
    }
    
    my $query_result =
	DBQueryWarn("select node_id,iface from interfaces ".
		    "where uuid='$uuid'");

    return undef
	if (!$query_result);
    return undef
	if (!$query_result->numrows);
    
    my ($nodeid, $iface) = $query_result->fetchrow_array();

    return Interface->LookupByIface($nodeid, $iface);
}

#
# Lookup the control interface for a node, which is something we do a lot.
#
sub LookupControl($)
{
    my ($class, $nodeid) = @_;

    $nodeid = $nodeid->node_id()
	if (ref($nodeid));

    my $query_result =
	DBQueryWarn("select iface from interfaces ".
		    "where node_id='$nodeid' and ".
		    "      role='" . TBDB_IFACEROLE_CONTROL()  . "'");

    return undef
	if (!$query_result);
    return undef
	if (!$query_result->numrows);

    my ($iface) = $query_result->fetchrow_array();

    return Interface->LookupByIface($nodeid, $iface);
}

#
# Lookup the management interface for a node.
#
sub LookupManagement($)
{
    my ($class, $nodeid) = @_;

    $nodeid = $nodeid->node_id()
	if (ref($nodeid));

    my $query_result =
	DBQueryWarn("select iface from interfaces ".
		    "where node_id='$nodeid' and ".
		    "      role='" . TBDB_IFACEROLE_MANAGEMENT()  . "'");

    return undef
	if (!$query_result);
    return undef
	if (!$query_result->numrows);

    my ($iface) = $query_result->fetchrow_array();

    return Interface->LookupByIface($nodeid, $iface);
}

#
# Stringify for output.
#
sub Stringify($)
{
    my ($self) = @_;
    
    my $nodeid = $self->node_id();
    my $iface  = $self->iface();

    return "[Interface: $nodeid:$iface]";
}

#
# Dump for debugging.
#
sub Dump($)
{
    my ($self) = @_;

    print "Node:      " . $self->node_id() . "\n";
    print "Iface:     " . $self->iface() . "\n";
    if ($self->wiredup()) {
	print "Card:      " . $self->card() . "\n";
	print "Port:      " . $self->port() . "\n";
    }
    print "Type:      " . $self->type() . "\n";
    print "Role:      " . $self->role() . "\n";
    print "Trunk:     " . $self->trunk() . "\n";
    print "IP:        " . ($self->IP() || "") . "\n";
    print "MAC:       " . $self->mac() . "\n";
    return 0;
}

#
# Temporary cruft for geni widearea switches.
#
sub LookUpWideAreaSwitch($$)
{
    my ($class, $hrn) = @_;
    my $safe_hrn = DBQuoteSpecial($hrn);

    my $query_result =
	DBQueryWarn("select node_id from widearea_switches ".
		    "where hrn=$safe_hrn");
    return undef
	if (!$query_result);
    if ($query_result->numrows) {
	my ($switch_id) = $query_result->fetchrow_array();
	return $switch_id;
    }
    my $next_id   = TBGetUniqueIndex('next_switch', 1);
    my $switch_id = "widearea_switch$next_id";

    return $switch_id
	if (DBQueryWarn("insert into widearea_switches set ".
			" hrn=$safe_hrn, node_id='$switch_id'"));
    return undef;
}

#
# Perform some updates ...
#
sub Update($$)
{
    my ($self, $argref) = @_;

    # Must be a real reference. 
    return -1
	if (! ref($self));

    my $nodeid  = $self->node_id();
    my $iface   = $self->iface();
    my @sets    = ();

    foreach my $key (keys(%{$argref})) {
	my $val = $argref->{$key};

	# Treat NULL special.
	push (@sets, "${key}=" . ($val eq "NULL" ?
				  "NULL" : DBQuoteSpecial($val)));
    }

    my $query = "update interfaces set " . join(",", @sets) .
	" where node_id='$nodeid' and iface='$iface'";

    return -1
	if (! DBQueryWarn($query));

    return Refresh($self);
}

#
# Lookup a specific attribute in the type capabilities table. 
#
sub TypeCapability($$$)
{
    my ($self, $capkey, $pcapval) = @_;
    
    return -1
	if (!ref($self));

    my $itype = $self->type();

    my $query_result =
	DBQueryWarn("select capval from interface_capabilities ".
		    "where type='$itype' and capkey='$capkey'");

    return -1
	if (!$query_result || !$query_result->numrows());
    my ($capval) = $query_result->fetchrow_array();
    $$pcapval = $capval;
    return 0;
}

##############################################################################
package Interface::VInterface;
use libdb;
use libtestbed;
use emutil qw(GenFakeMac);
use English;
use Carp;
use overload ('""' => 'Stringify');
use vars qw($AUTOLOAD);

my $nextfake = 0;

#
# Lookup by node_id,unit
#
sub Lookup($$$)
{
    my ($class, $nodeid, $unit) = @_;

    $nodeid = $nodeid->node_id()
	if (ref($nodeid));

    my $query_result =
	DBQueryWarn("select * from vinterfaces ".
		    "where node_id='$nodeid' and unit='$unit'");

    return undef
	if (!$query_result);
    return undef
	if (!$query_result->numrows);

    my $vinterface = {};
	
    $vinterface->{"DBROW"} = $query_result->fetchrow_hashref();
    $vinterface->{"HASH"}  = {};
    bless($vinterface, $class);
}

AUTOLOAD {
    my $self  = $_[0];
    my $type  = ref($self) or croak "$self is not an object";
    my $name  = $AUTOLOAD;
    $name =~ s/.*://;   # strip fully-qualified portion

    # A DB row proxy method call.
    if (exists($self->{'DBROW'}->{$name})) {
	return $self->{'DBROW'}->{$name};
    }
    # Or it is for a local storage slot.
    if ($name =~ /^_.*$/) {
	if (scalar(@_) == 2) {
	    return $self->{'HASH'}->{$name} = $_[1];
	}
	elsif (exists($self->{'HASH'}->{$name})) {
	    return $self->{'HASH'}->{$name};
	}
    }
    carp("No such slot '$name' field in class $type");
    return undef;
}

# Break circular reference someplace to avoid exit errors.
sub DESTROY {
    my $self = shift;

    $self->{'DBROW'} = undef;
    $self->{'HASH'}  = undef;
}

# The virtual iface name is $type$unit
sub viface($)     { return $_[0]->type() . $_[0]->unit(); }

#
# Lookup by the experiment/virtlan/vnode
#
sub LookupByVirtLan($$$$)
{
    my ($class, $experiment, $virtlan, $vnode) = @_;
    my $exptidx = $experiment->idx();

    $virtlan = DBQuoteSpecial($virtlan);
    $vnode   = DBQuoteSpecial($vnode);

    my $query_result =
	DBQueryWarn("select node_id,unit from vinterfaces as vif ".
		    "left join virt_lans as vl on vl.exptidx=vif.exptidx and ".
		    "  vl.ip=vif.IP ".
		    "where vif.exptidx='$exptidx' and ".
		    "      vl.vname=$virtlan and vl.vnode=$vnode");
    return undef
	if (!defined($query_result) || !$query_result->numrows);

    my ($node_id,$unit) = $query_result->fetchrow_array();
    return Interface::VInterface->Lookup($node_id, $unit);
}
    
#
# Create a new vinterface
#
sub Create($$$)
{
    my ($class, $nodeid, $argref) = @_;

    $nodeid = $nodeid->node_id()
	if (ref($nodeid));
    $argref->{'node_id'} = $nodeid;

    # This is generated by the insert.
    delete($argref->{'unit'})
	if (exists($argref->{'unit'}));

    DBQueryWarn("lock tables interfaces read, ".
		"            vinterfaces write, ".
		"            node_history read")
	or return undef;

    #
    # Generate a fake mac if requested. 
    #
    if (exists($argref->{'mac'}) && $argref->{'mac'} eq "genfake") {
	while (1) {
	    my $mac = GenFakeMac();

	    # Check to make sure unique. If not, try again.
	    my $query_result =
		DBQueryWarn("(select mac from interfaces ".
			    " where mac='$mac') ".
			    "union ".
			    "(select mac from vinterfaces ".
			    " where mac='$mac') ".
			    "union ".
			    "(select cnet_mac as mac from node_history ".
			    " where cnet_mac='$mac')");
	    if (!$query_result) {
		DBQueryWarn("unlock tables");
		return undef;
	    }
	    if (!$query_result->numrows) {
		$argref->{'mac'} = $mac;
		last;
	    }
	}
    }

    my $query = "insert into vinterfaces set ".
	join(",", map("$_='" . $argref->{$_} . "'", keys(%{$argref})));

    my $query_result = DBQueryWarn($query);
    DBQueryWarn("unlock tables");
    return undef
	if (!defined($query_result));

    my $unit= $query_result->insertid;
    return Interface::VInterface->Lookup($nodeid, $unit);
}

#
# Create a fake object, as for the mapper (assign_wrapper) during debugging.
#
sub MakeFake($$$)
{
    my ($class, $nodeid, $argref) = @_;

    $nodeid = $nodeid->node_id()
	if (ref($nodeid));
    $argref->{'node_id'}  = $nodeid;
    foreach my $field (('vnode_id', 'iface', 'vlanid', 'bandwidth')) {
	$argref->{$field} = undef if (!exists($argref->{$field}));
    }

    # This is usually generated by the insert.
    $argref->{'unit'}   = $nextfake++;

    my $self            = {};
    $self->{"DBROW"}    = $argref;
    $self->{"HASH"}     = {};
    $self->{"FAKE"}     = 1;
    bless($self, $class);
    return $self;
}

#
# Stringify for output.
#
sub Stringify($)
{
    my ($self) = @_;
    
    my $nodeid  = $self->node_id();
    my $unit    = $self->unit();
    my $iface   = (defined($self->iface()) ? ":" . $self->iface() : "");
    my $vnodeid = (defined($self->vnode_id()) ? ":" . $self->vnode_id() : "");

    return "[VInterface: $nodeid:${unit}${iface}${vnodeid}]";
}

#
# On a shared node, we have to "reserve" the required bandwidth on
# the physical interface.
#
sub ReserveSharedBandwidth($$)
{
    my ($self, $bandwidth) = @_;

    my $nodeid  = $self->node_id();
    my $unit    = $self->unit();
    my $iface   = $self->iface();

    # Must be a trivial link.
    return 0
	if (!defined($iface));

    #
    # Set the bw to the negative value; this is the bw that we need
    # to reserve later. Negative indicates we have not done it yet.
    #
    DBQueryWarn("update vinterfaces set bandwidth=0-${bandwidth} ".
		"where node_id='$nodeid' and unit='$unit'")
	or return -1;
	
    $self->{'DBROW'}->{'bandwidth'} = $bandwidth;
    return 0;
}

#
# Refresh instance by reloading from the DB.
#
sub Refresh($)
{
    my ($self) = @_;

    return -1
	if (! ref($self));

    my $nodeid  = $self->node_id();
    my $unit    = $self->unit();

    my $query_result =
	DBQueryWarn("select * from vinterfaces ".
		    "where node_id='$nodeid' and unit='$unit'");
    return undef
	if (!$query_result || !$query_result->numrows);

    $self->{"DBROW"} = $query_result->fetchrow_hashref();
    
    return 0;
}

#
# Perform some updates ...
#
sub Update($$)
{
    my ($self, $argref) = @_;

    # Must be a real reference. 
    return -1
	if (! ref($self));

    if (exists($self->{'FAKE'})) {
	foreach my $key (keys(%{$argref})) {
	    $self->{"DBROW"}->{$key} = $argref->{$key};
	}
	return 0;
    }

    my $nodeid  = $self->node_id();
    my $unit    = $self->unit();
    my @sets    = ();

    foreach my $key (keys(%{$argref})) {
	my $val = $argref->{$key};

	# Treat NULL special.
	push (@sets, "${key}=" . ($val eq "NULL" ?
				  "NULL" : DBQuoteSpecial($val)));
    }

    my $query = "update vinterfaces set " . join(",", @sets) .
	" where node_id='$nodeid' and unit='$unit'";

    return -1
	if (! DBQueryWarn($query));

    return Refresh($self);
}

##############################################################################
#
# A wrapper class for a wire. 
#
package Interface::Wire;
use libdb;
use Node;
use libtestbed;
use English;
use overload ('""' => 'Stringify');

#
# Lookup a wire, using the interface of the "pc" side.
#
sub Lookup($$)
{
    my ($class, $interface) = @_;

    my $query_result;
    if (!ref($interface) && $interface =~ /^urn:publicid:IDN+/) {
	# Allow lookup by remote interface URN
	$query_result =
	    DBQueryWarn("select * from wires ".
			"where external_interface='$interface'");
    } else {
	my ($node_id1,$card1,$port1,$iface1);
	
	if (!ref($interface)) {
	    # Allow "nodeid:card:port" argument.
	    if ($interface =~ /^([-\w]*):(\w+):(\w+)$/) {
		$node_id1 = $1;
		$card1    = $2;
		$port1    = $3;

		$query_result =
		    DBQueryWarn("select * from wires ".
				"where node_id1='$node_id1' and ".
				"      card1='$card1' and port1='$port1'");
	    }
	    else {
		return undef;
	    }
	}
	else {
	    $node_id1 = $interface->node_id();
	    $iface1   = $interface->iface();

	    $query_result =
		DBQueryWarn("select * from wires ".
			    "where node_id1='$node_id1' and ".
			    "      iface1='$iface1'");
	}
    }

    return undef
	if (!$query_result || !$query_result->numrows);

    my $wire = {};
    $wire->{"DBROW"}  = $query_result->fetchrow_hashref();
    bless($wire, $class);
    return $wire;
}
sub field($$)	       { return $_[0]->{'DBROW'}->{$_[1]}; }
sub node_id1($)        { return $_[0]->field('node_id1'); }
sub node_id2($)        { return $_[0]->field('node_id2'); }
sub card1($)           { return $_[0]->field('card1'); }
sub card2($)           { return $_[0]->field('card2'); }
sub port1($)           { return $_[0]->field('port1'); }
sub port2($)           { return $_[0]->field('port2'); }
sub iface1($)          { return $_[0]->field('iface1'); }
sub iface2($)          { return $_[0]->field('iface2'); }
sub type($)            { return $_[0]->field('type'); }
sub cable($)           { return $_[0]->field('cable'); }
sub len($)             { return $_[0]->field('len'); }
sub logical($)         { return $_[0]->field('logical'); }
sub trunkid($)         { return $_[0]->field('trunkid'); }
sub IsActive($)        { return ($_[0]->type() eq "Unused" ? 0 : 1); }

#
# Create a wire by Interfaces.
#
sub Create($$$$$)
{
    my ($self, $interface1, $interface2, $type, $argref) = @_;

    my $node_id1  = $interface1->node_id();
    my $iface1    = $interface1->iface();
    my $node_id2  = $interface2->node_id();
    my $iface2    = $interface2->iface();
    my $card1     = $argref->{'card1'};
    my $port1     = $argref->{'port1'};
    my $card2     = $argref->{'card2'};
    my $port2     = $argref->{'port2'};
    if (! (defined($card1) && defined($port1) &&
	   defined($card2) && defined($port2))) {
	print STDERR "*** Interface::Wire->Create(): missing arguments\n";
	return undef;
    }

    my $command = "insert into wires set".
	"  type='$type', " .
	"  node_id1='$node_id1',card1=$card1,port1=$port1, " .
	"  iface1='$iface1', ".
	"  node_id2='$node_id2',card2=$card2,port2=$port2, ".
	"  iface2='$iface2'";
    $command .= ",cable=" . DBQuoteSpecial($argref->{'cable'})
	if (exists($argref->{'cable'}));
    $command .= ",len=" . DBQuoteSpecial($argref->{'cablelen'})
	if (exists($argref->{'cablelen'}));
    $command .= ",external_wire=" . DBQuoteSpecial($argref->{'external_wire'})
	if (exists($argref->{'external_wire'}));
    $command .= ",external_interface=" .
	DBQuoteSpecial($argref->{'external_interface'})
	if (exists($argref->{'external_interface'}));

    DBQueryWarn($command) or
	return undef;

    return Interface::Wire->LookupByIface($node_id1, $iface1);
}

#
# Create a fake object. Port library uses this too.
#
sub MakeFake($$)
{
    my ($class, $argref) = @_;

    my $query_result =
	DBQueryWarn("show columns from wires");
    return undef
	if (!$query_result);
    
    while (my ($slot) = $query_result->fetchrow_array()) {
	if (!exists($argref->{$slot})) {
	    $argref->{$slot} = "";
	}
    }
    my $self            = {};
    $self->{"DBROW"}    = $argref;
    bless($self, $class);

    return $self;
}

#
# Find me a wire from either side using nodeid,card,port.
#
sub LookupAny($$$$)
{
    my ($class, $nodeid, $card, $port) = @_;

    $nodeid = $nodeid->node_id()
	if (ref($nodeid));

    my $query_result =
	DBQueryWarn("select * from wires ".
		    "where (node_id1='$nodeid' and ".
		    "       card1='$card' and port1='$port') or ".
		    "      (node_id2='$nodeid' and ".
		    "       card2='$card' and port2='$port')");

    return undef
	if (!$query_result || !$query_result->numrows);

    my $wire = {};
    $wire->{"DBROW"}  = $query_result->fetchrow_hashref();
    bless($wire, $class);
    return $wire;
}
sub LookupAnyByIface($$$)
{
    my ($class, $nodeid, $iface) = @_;

    $nodeid = $nodeid->node_id()
	if (ref($nodeid));

    my $query_result =
	DBQueryWarn("select * from wires ".
		    "where (node_id1='$nodeid' and iface1='$iface') or ".
		    "      (node_id2='$nodeid' and iface2='$iface')");

    return undef
	if (!$query_result || !$query_result->numrows);

    my $wire = {};
    $wire->{"DBROW"}  = $query_result->fetchrow_hashref();
    bless($wire, $class);
    return $wire;
}
sub LookupByIface($$$)
{
    my ($class, $nodeid, $iface) = @_;

    $nodeid = $nodeid->node_id()
	if (ref($nodeid));

    my $query_result =
	DBQueryWarn("select * from wires ".
		    "where (node_id1='$nodeid' and iface1='$iface')");

    return undef
	if (!$query_result || !$query_result->numrows);

    my $wire = {};
    $wire->{"DBROW"}  = $query_result->fetchrow_hashref();
    bless($wire, $class);
    return $wire;
}

sub LookupAnyByIfaces($$$$$)
{
    my ($class, $nodeid1, $iface1, $nodeid2, $iface2) = @_;

    $nodeid1 = $nodeid1->node_id()
	if (ref($nodeid1));
    $nodeid2 = $nodeid2->node_id()
	if (ref($nodeid2));

    my $query_result =
	DBQueryWarn("select * from wires ".
		    "where ((node_id1='$nodeid1' and iface1='$iface1') and ".
		    "       (node_id2='$nodeid2' and iface2='$iface2')) or ".
		    "      ((node_id2='$nodeid1' and iface2='$iface1') and ".
		    "       (node_id1='$nodeid2' and iface1='$iface2'))");

    return undef
	if (!$query_result || !$query_result->numrows);

    my $wire = {};
    $wire->{"DBROW"}  = $query_result->fetchrow_hashref();
    bless($wire, $class);
    return $wire;
}

#
# Delete a wire. For safety refuse to delete a real wire unless flag given.
#
sub Delete($;$)
{
    my ($self, $real) = @_;
    my $logical = ($real ? 0 : 1);

    if ($logical && !$self->logical()) {
	print STDERR "Refusing to delete real $self\n";
	return -1;
    }
    my $node_id1 = $self->node_id1();
    my $iface1   = $self->iface1();
    my $node_id2 = $self->node_id2();
    my $iface2   = $self->iface2();

    return -1
	if (!DBQueryWarn("delete from wires ".
			 "where node_id1='$node_id1' and iface1='$iface1' and ".
			 "      node_id2='$node_id2' and iface2='$iface2'"));
    return 0;
}

#
# A wire has two interfaces, but we do not always create interface
# table entries for both sides; the switch side is generally not in
# the interfaces table. 
#
sub Interfaces($)
{
    my ($self) = @_;

    return (Interface->LookupByIface($self->node_id1(), $self->iface1()),
	    Interface->LookupByIface($self->node_id2(), $self->iface2()));
}

#
# Stringify for output. 
#
sub Stringify($)
{
    my ($self) = @_;
    
    my $node1   = $self->node_id1();
    my $node2   = $self->node_id2();
    my $card1   = $self->card1();
    my $card2   = $self->card2();
    my $port1   = $self->port1();
    my $port2   = $self->port2();
    my $type    = ($self->logical() ? "LogicalWire" : "Wire");

    return "[$type: $node1:$card1:$port1/$node2:$card2:$port2]";
}

#
# Dump for debugging.
#
sub Dump($)
{
    my ($self) = @_;

    print "Node1:      " . $self->node_id1() . "\n";
    print "Iface1:     " . $self->iface1() . "\n";
    print "Card1:      " . $self->card1() . "\n";
    print "Port1:      " . $self->port1() . "\n";
    print "Node2:      " . $self->node_id2() . "\n";
    print "Iface2:     " . $self->iface2() . "\n";
    print "Card2:      " . $self->card2() . "\n";
    print "Port2:      " . $self->port2() . "\n";
    print "Type:       " . $self->type() . "\n";
    if ($self->cable()) {
	print "Cable:      " . $self->cable() . "\n";
	print "Length:     " . $self->len() . "\n";
    }
    return 0;
}

sub Update($$)
{
    my ($self, $argref) = @_;

    my $node_id1 = $self->node_id1();
    my $card1    = $self->card1();
    my $port1    = $self->port1();
    my @sets    = ();

    foreach my $key (keys(%{$argref})) {
	my $val = $argref->{$key};

	# Treat NULL special.
	push (@sets, "${key}=" . ($val eq "NULL" ?
				  "NULL" : DBQuoteSpecial($val)));
    }
    my $query = "update wires set " . join(",", @sets) .
	" where node_id1='$node_id1' and card1='$card1' and port1='$port1'";

    return -1
	if (! DBQueryWarn($query));

    my $query_result =
	DBQueryWarn("select * from wires ".
		    "where node_id1='$node_id1' and ".
		    "      card1='$card1' and port1='$port1'");
    return -1
	if (!$query_result || !$query_result->numrows);

    $self->{'DBROW'} = $query_result->fetchrow_hashref();
    return 0;
}

##############################################################################
#
# A wrapper class for a "logical wire". This is a wire that exists
# cause it was created with a layer 1 switch. 
#
package Interface::LogicalWire;
use libdb;
use Node;
use libtestbed;
use English;
use overload ('""' => 'Stringify');

#
# Lookup a logical wire.
#
sub Lookup($$$)
{
    my ($class, $nodeid, $iface) = @_;

    my $query_result =
	DBQueryWarn("select * from logical_wires ".
		    "where (node_id1='$nodeid' and iface1='$iface') or ".
		    "      (node_id2='$nodeid' and iface2='$iface')");

    return undef
	if (!$query_result || !$query_result->numrows);

    my $wire = {};
    $wire->{"DBROW"}  = $query_result->fetchrow_hashref();
    bless($wire, $class);

    #
    # Grab the physical wires.
    #
    my $node_id1   = $wire->node_id1();
    my $node_id2   = $wire->node_id2();
    my $physiface1 = $wire->physiface1();
    my $physiface2 = $wire->physiface2();
    
    my $pwire1 = Interface::Wire->LookupAnyByIface($node_id1, $physiface1);
    if (!defined($pwire1)) {
	print STDERR "*** No physical wire for $node_id1:$physiface1\n";
	return undef;
    }
    my $pwire2 = Interface::Wire->LookupAnyByIface($node_id2, $physiface2);
    if (!defined($pwire2)) {
	print STDERR "*** No physical wire for $node_id2:$physiface2\n";
	return undef;
    }
    #
    # Now we can get the card,port for each side, and so it looks like
    # a real wire to the callers (say, Port.pm).
    #
    my ($card1,$port1,$card2,$port2);
    if ($pwire1->node_id1() eq $node_id1 && $pwire1->iface1() eq $physiface1) {
	$card1 = $pwire1->card1();
	$port1 = $pwire1->port1();
    }
    else {
	$card1 = $pwire1->card2();
	$port1 = $pwire1->port2();
    }
    if ($pwire2->node_id1() eq $node_id2 && $pwire2->iface1() eq $physiface2) {
	$card2 = $pwire2->card1();
	$port2 = $pwire2->port1();
    }
    else {
	$card2 = $pwire2->card2();
	$port2 = $pwire2->port2();
    }
    $wire->{"CARD1"} = $card1;
    $wire->{"PORT1"} = $port1;
    $wire->{"CARD2"} = $card2;
    $wire->{"PORT2"} = $port2;
    
    return $wire;
}
sub field($$)	       { return $_[0]->{'DBROW'}->{$_[1]}; }
sub node_id1($)        { return $_[0]->field('node_id1'); }
sub node_id2($)        { return $_[0]->field('node_id2'); }
sub iface1($)          { return $_[0]->field('iface1'); }
sub iface2($)          { return $_[0]->field('iface2'); }
sub physiface1($)      { return $_[0]->field('physiface1'); }
sub physiface2($)      { return $_[0]->field('physiface2'); }
sub type($)            { return $_[0]->field('type'); }
sub IsActive($)        { return ($_[0]->type() eq "Unused" ? 0 : 1); }
sub card1($)           { return $_[0]->{'CARD1'}; }
sub port1($)           { return $_[0]->{'PORT1'}; }
sub card2($)           { return $_[0]->{'CARD2'}; }
sub port2($)           { return $_[0]->{'PORT2'}; }

#
# For snmpit.
#
sub LookupByWireID($$)
{
    my ($class, $wireid) = @_;
    my ($nodeid,$iface) = split(":", $wireid);

    return Lookup($class, $nodeid, $iface);
}
#
# For Port.pm
#
sub LookupByPhysIface($$)
{
    my ($self, $nodeid, $physiface) = @_;

    my $query_result =
	DBQueryWarn("select node_id1,iface1 from logical_wires ".
		    "where (node_id1='$nodeid' and ".
		    "       physiface1='$physiface') or ".
		    "      (node_id2='$nodeid' and ".
		    "       physiface2='$physiface')");

    return undef
	if (!$query_result || !$query_result->numrows);

    my ($node_id1,$iface1) = $query_result->fetchrow_array();

    return Interface::LogicalWire->Lookup($node_id1, $iface1);
}

#
# Create a pair of logical interfaces that will later be wired together
# at layer 1 with logical wire. Called from the mapper only.
#
sub Create($$$$$$)
{
    my ($class, $impotent, $nodeA, $portA, $nodeB, $portB) = @_;

    my $pnodeA = Node->Lookup($nodeA);
    if (!defined($pnodeA)) {
	print STDERR "Could not lookup '$nodeA'\n";
	return undef;
    }
    my $pnodeB = Node->Lookup($nodeB);
    if (!defined($pnodeB)) {
	print STDERR "Could not lookup '$nodeB'\n";
	return undef;
    }

    #
    # For consistency and because we still have an implicit assumption
    # the node is node_id1 in the wires table and the switch is node_id2.
    #
    if ($pnodeA->isswitch() && !$pnodeB->isswitch()) {
	($nodeA,$nodeB)   = ($nodeB,$nodeA);
	($portA,$portB)   = ($portB,$portA);
	($pnodeA,$pnodeB) = ($pnodeB,$pnodeA);
    }
    
    my $interfaceA = Interface->LookupByIface($pnodeA, $portA);
    if (!defined($interfaceA)) {
	print STDERR "Could not lookup '$pnodeA:$portA'\n";
	return undef;
    }
    if (!$interfaceA->wiredup()) {
	print STDERR "No wire for $interfaceA\n";
	return undef;
    }
    my $interfaceB = Interface->LookupByIface($pnodeB, $portB);
    if (!defined($interfaceB)) {
	print STDERR "Could not lookup '$pnodeB:$portB'\n";
	return undef;
    }
    if (!$interfaceB->wiredup()) {
	print STDERR "No wire for $interfaceB\n";
	return undef;
    }
    my $wireA = $interfaceA->wire();
    my $wireB = $interfaceB->wire();
    
    #
    # Create logical interfaces
    #
    # Must create a real copy, especially for MakeFake();
    my $argref = {};
    foreach my $key (keys(%{ $interfaceA->{'DBROW'} })) {
	$argref->{$key} = $interfaceA->{'DBROW'}->{$key};
    }
    if ($impotent) {
	# Need these for Fake interfaces.
	$argref->{'card'} = $wireA->card1();
	$argref->{'port'} = $wireA->port1();
    }
    $argref->{'iface'}   = sprintf("log%d%03d",$wireA->card1(),$wireA->port1());
    $argref->{'logical'} = 1;
    $argref->{'uuid'}    = undef;

    if (!$impotent) {
	$interfaceA = Interface->Create($pnodeA, $argref);
	return undef
	    if (!defined($interfaceA));
    }
    else {
	# Fake things up.
	$interfaceA = Interface->MakeFake($pnodeA, $argref);
    }

    # Must create a real copy, especially for MakeFake();
    $argref = {};
    foreach my $key (keys(%{ $interfaceB->{'DBROW'} })) {
	$argref->{$key} = $interfaceB->{'DBROW'}->{$key};
    }
    if ($impotent) {
	# Need these for Fake interfaces.
	$argref->{'card'} = $wireB->card1();
	$argref->{'port'} = $wireB->port1();
    }
    $argref->{'iface'}   = sprintf("log%d%03d",$wireB->card1(),$wireB->port1());
    $argref->{'logical'} = 1;
    $argref->{'uuid'}    = undef;

    if (!$impotent) {
	$interfaceB = Interface->Create($pnodeB, $argref);
	return undef
	    if (!defined($interfaceB));
    }
    else {
	# Fake things up.
	$interfaceB = Interface->MakeFake($pnodeB, $argref);
    }

    # Create a logical wires table entry.
    if (!$impotent) {
	my $node_id1   = $nodeA;
	my $node_id2   = $nodeB;
	my $iface1     = $interfaceA->iface();
	my $iface2     = $interfaceB->iface();
	my $physiface1 = $wireA->iface1();
	my $physiface2 = $wireB->iface1();

	#
	# The wire is not active yet. When snmpit runs and actually
	# wires things up at layer 1, it will update this wire to
	# reflect that. Use the 'Unused' type to indicate it is not
	# active.
	#
	if (!DBQueryWarn("insert into logical_wires set".
			 "  type='Unused', " .
			 "  node_id1='$node_id1',iface1='$iface1', ".
			 "  physiface1='$physiface1', ".
			 "  node_id2='$node_id2',iface2='$iface2', ".
			 "  physiface2='$physiface2'")) {
	    return undef;
	}
	return Lookup($class, $node_id1, $iface1);
    }
    my $dbrow = {};
    $dbrow->{"node_id1"}   = $nodeA;
    $dbrow->{"node_id2"}   = $nodeB;
    $dbrow->{"iface1"}     = $interfaceA->iface();
    $dbrow->{"iface2"}     = $interfaceB->iface();
    $dbrow->{"physiface1"} = $wireA->iface1();
    $dbrow->{"physiface2"} = $wireB->iface1();
    my $self = {};
    $self->{'DBROW'} = $dbrow;

    bless($self, $class);
    return $self;
}

#
# The wires table is indexed by node_id1,iface1 ... return
# something that allows us to find that wires table entry.
#
sub WireID($)
{
    my ($self) = @_;

    my $node_id1   = $self->node_id1();
    my $iface1     = $self->iface1();
    my $node_id2   = $self->node_id2();
    my $iface2     = $self->iface2();

    return "$node_id1:$iface1";
}

#
# Stringify for output. 
#
sub Stringify($)
{
    my ($self) = @_;

    my $node_id1  = $self->node_id1();
    my $node_id2  = $self->node_id2();
    my $iface1    = $self->iface1();
    my $iface2    = $self->iface2();

    return "[LogicalWire: $node_id1:$iface1/$node_id2:$iface2]";
}

#
# Return both interfaces for a logical wire.
#
sub Interfaces($)
{
    my ($self) = @_;

    return (Interface->LookupByIface($self->node_id1(), $self->iface1()),
	    Interface->LookupByIface($self->node_id2(), $self->iface2()));
}

#
# Delete logical wire.
#
sub Delete($)
{
    my ($self) = @_;
    my $node_id1 = $self->node_id1();
    my $iface1   = $self->iface1();
    my $node_id2 = $self->node_id2();
    my $iface2   = $self->iface2();
    
    return -1
	if (!DBQueryWarn("delete from logical_wires ".
			 "where node_id1='$node_id1' and iface1='$iface1' ".
			 "  and node_id2='$node_id2' and iface2='$iface2'"));
    return 0;
}

#
# Activate a (logical) wire by setting the type. Default to "Node".
#
sub Activate($$)
{
    my ($self, $vlan) = @_;
    my $node_id1 = $self->node_id1();
    my $iface1   = $self->iface1();
    my $node_id2 = $self->node_id2();
    my $iface2   = $self->iface2();
    my $type     = "Node";

    #
    # Unless it is supposed to be a trunk
    #
    if ($vlan->GetRole() eq "trunk") {
	$type = "Trunk";
    }
    
    return -1
	if (!DBQueryWarn("update logical_wires set type='$type' ".
			 "where node_id1='$node_id1' and iface1='$iface1' ".
			 "  and node_id2='$node_id2' and iface2='$iface2'"));

    return 0;
}

sub DeActivate($)
{
    my ($self) = @_;
    my $node_id1 = $self->node_id1();
    my $iface1   = $self->iface1();
    my $node_id2 = $self->node_id2();
    my $iface2   = $self->iface2();

    return -1
	if (!DBQueryWarn("update logical_wires set type='Unused' ".
			 "where node_id1='$node_id1' and iface1='$iface1' ".
			 "  and node_id2='$node_id2' and iface2='$iface2'"));

    return 0;
}

#
# Find all logical wires for an experiment.
#
sub ExperimentLogicalWires($$$)
{
    my ($class, $experiment, $plist) = @_;

    return -1
	if (! (ref($plist) && ref($experiment)));
    
    my $exptidx = $experiment->idx();
    my @result  = ();

    my $query_result =
	DBQueryWarn("select distinct node_id1,iface1,node_id2,iface2 ".
		    "  from logical_wires as w ".
		    "left join reserved as r on ".
		    "     w.node_id1=r.node_id or w.node_id2=r.node_id ".
		    "where r.exptidx='$exptidx'");
    return -1
	if (!$query_result);

    while (my ($node1,$iface1,$node2,$iface2) =
	   $query_result->fetchrow_array()) {
	my $logwire = Interface::LogicalWire->Lookup($node1,$iface1);
	if (!defined($logwire)) {
	    print STDERR "*** Could not lookup logical wire: ".
		"$node1:$iface1:$node2:$iface2\n";
	    return -1;
	}
	push(@result, $logwire);
    }
    @$plist = @result;
    return 0;
}

#
# Delete all logical wires for an experiment, as for swapout.
#
sub DeleteLogicalWires($$;$)
{
    my ($class, $experiment, $force) = @_;
    my @wires  = ();
    my $errors = 0;
    $force = 0 if (!defined($force));

    return -1
	if (! ref($experiment));
    
    return -1
	if (ExperimentLogicalWires(undef, $experiment, \@wires));
    return 0
	if (!@wires);

    foreach my $wire (@wires) {
	print STDERR "Deleting $wire\n";
	
	if ($wire->IsActive() && !$force) {
	    print STDERR "$wire is still active; cannot delete!\n";
	    $errors++;
	    next;
	}
	my ($interface1, $interface2) = $wire->Interfaces();

	if (defined($interface1) && $interface1->logical()) {
	    $interface1->Delete() == 0
		or return -1;
	}
	if (defined($interface2) && $interface2->logical()) {
	    $interface2->Delete() == 0
		or return -1;
	}
	if ($wire->Delete()) {
	    print STDERR "$wire could not be deleted!\n";
	    $errors++;
	}
    }
    return $errors;
}

#
# Backup all logical wires for an experiment, as for modify.
#
sub BackupLogicalWires($$$)
{
    my ($class, $experiment, $pstatedir) = @_;
    my $exptidx = $experiment->idx();

    my $query_result =
	DBQueryWarn("select distinct node_id1,iface1,node_id2,iface2 ".
		    "  from logical_wires as w ".
		    "left join reserved as r on ".
		    "     w.node_id1=r.node_id or w.node_id2=r.node_id ".
		    "where r.exptidx='$exptidx'");
    return -1
	if (!$query_result);
    return 0
	if (!$query_result->numrows);

    DBQueryWarn("select distinct w.* from logical_wires as w ".
		"left join reserved as r on ".
		"     w.node_id1=r.node_id or w.node_id2=r.node_id ".
		"where r.exptidx='$exptidx' ".
		"into outfile '$pstatedir/logical_wires'")
	or return -1;

    return 0
}

#
# Restore all logical wires for an experiment, as for modify.
#
sub RestoreLogicalWires($$$)
{
    my ($class, $experiment, $pstatedir) = @_;

    if (-e "$pstatedir/logical_wires") {
	DBQueryWarn("load data infile '$pstatedir/logical_wires' ".
		    "replace into table logical_wires")
	    or return -1;
    }
    return 0;
}

#
# Remove all logical wires for an experiment, as for modify.
#
sub RemoveLogicalWires($$)
{
    my ($class, $experiment) = @_;

    # Force deletion of active logical wires for swapmod. 
    return DeleteLogicalWires($class, $experiment, 1);
}

##############################################################################
#
# A trivial wrapper class for interface_types.
#
package Interface::Type;
use libdb;
use Node;
use libtestbed;
use English;
use overload ('""' => 'Stringify');

#
# Lookup by interface type name.
#
sub Lookup($$)
{
    my ($class, $type) = @_;

    if ($type !~ /^[-\w]+$/) {
	return undef;
    }
    my $query_result =
	DBQueryWarn("select * from interface_types where type='$type'");
    return undef
	if (!$query_result || !$query_result->numrows);
    
    my $blob = {};
    $blob->{"DBROW"}  = $query_result->fetchrow_hashref();
    $blob->{"CAPS"}   = {};

    # Load capabilities.
    $query_result =
	DBQueryWarn("select * from interface_capabilities where type='$type'");
    return undef
	if (!$query_result);
    while (my $row = $query_result->fetchrow_hashref()) {
	my $key = $row->{'capkey'};
	my $val = $row->{'capval'};
	$blob->{"CAPS"}->{$key} = $val;
    }
    bless($blob, $class);
    return $blob;
}
sub field($$)	       { return $_[0]->{'DBROW'}->{$_[1]}; }
sub type($)            { return $_[0]->field('type'); }
sub max_speed($)       { return $_[0]->field('max_speed'); }
sub manufacturer($)    { return $_[0]->field('manufacturer'); }
sub model($)           { return $_[0]->field('model'); }
sub ports($)           { return $_[0]->field('ports'); }
sub connector($)       { return $_[0]->field('connector'); }
sub capability($$)
{
    my ($self, $capkey) = @_;

    return undef
	if (!exists($self->{'CAPS'}->{$capkey}));

    return $self->{'CAPS'}->{$capkey};
}

#
# Stringify for output. 
#
sub Stringify($)
{
    my ($self) = @_;

    my $type    = $self->type();
    my $speed   = $self->max_speed();

    return "[InterfaceType: $type:$speed]";
}

#
# Find me the generic type given a speed.
#
sub GenericType($$)
{
    my ($class, $speed) = @_;
    my $itype;
    
    if ($speed eq "100Mb" || "$speed" eq "100000") {
	$itype = "generic";
    }
    elsif ($speed eq "1Gb" || "$speed" eq "1000000") {
	$itype = "generic_1G";
    }
    elsif ($speed eq "10Gb" || "$speed" eq "10000000") {
	$itype = "generic_10G";
    }
    elsif ($speed eq "25Gb" || "$speed" eq "25000000") {
	$itype = "generic_25G";
    }
    elsif ($speed eq "40Gb" || "$speed" eq "40000000") {
	$itype = "generic_40G";
    }
    elsif ($speed eq "56Gb" || "$speed" eq "56000000") {
	$itype = "generic_56G";
    }
    elsif ($speed eq "100Gb" || "$speed" eq "100000000") {
	$itype = "generic_100G";
    }
    else {
	return undef;
    }
    return Interface::Type->Lookup($itype);
}

# _Always_ make sure that this 1 is at the end of the file...
1;

