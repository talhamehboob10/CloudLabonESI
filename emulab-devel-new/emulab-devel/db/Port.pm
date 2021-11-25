#
# This is the Port class that represent a port in VLAN.
# It aims at providing all avaialble information of a
# port rather than just a string representation consisting
# of node and card or port only, which is used by most snmpit
# code.
#
# Previous string representation only has node and card for
# a PC port, which can not be unique when representing a port
# on a test node switch, such as our hp5406 nodes.
# A Port class instance uniquely identifies a port with
# all of its properties, such as node_id, card, port and iface.
#
# Some important terms used:
# - Tokens: seperated fields of a port, e.g. "node1", "card2", "iface3", etc.
# - Iface:  interface on a node, or a full representation of
#   an interface, say "iface2", "node1:iface4".
# - Triple: a port representation that uses three fields:
#   node, card and port, like "node1:card2.port1".
# - String: a string representation of a port, ususally a
#   combination of tokens, e.g. "node1:iface3", "node1:card3.port4".
#
# All code that needs to convert between different representations
# or merely parse tokens from string and vice-verse must
# use the converters provided in this class.
#
# Copyright (c) 2011-2020 University of Utah and the Flux Group.
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
package Port;

use strict;
use Exporter;
use vars qw(@ISA @EXPORT);

@ISA    = "Exporter";
@EXPORT = qw ( );

use libdb;
use EmulabConstants;
use Interface;
use English;
use Node;
use Carp qw(cluck);
use Data::Dumper;
use overload ('""' => 'Stringify');

# Local constants
my $WIRE_END_NODE   = "node";
my $WIRE_END_SWITCH = "switch";

# Cache of port instances
# node:iface OR node:card.port => Port Instance
my %allports = ();

# Ends of wires, node:iface OR node:card.port => Port Instance
my %wiredports = ();

#
# check if a var is a Port instance
#
sub isPort($$)
{
	my ($c, $p) = @_;
	if (ref($p) eq "Port") {
		return 1;
	}
	return 0;
}

#
# Get the other end port of a wire by triple representation of this end port
# the classname can be ignored
# the representation can be a triple-port string or triple tokens
#
sub GetOtherEndByTriple($;$$$)
{
    my ($c, $node, $card, $port) = @_;
    my $str;

    if (!defined($node)) {
	$str = $c;
    } elsif (!defined($card)) {
	$str = $node;
    } elsif (!defined($port)) {
	$str = Port->Tokens2TripleString($c, $node, $card);
    } else {
	$str = Port->Tokens2TripleString($node, $card, $port);
    }

    if (exists($wiredports{$str})) {
	return $wiredports{$str};
    }

    my $p = Port->LookupByTriple($str);
    if (defined($p)) {

	$wiredports{$p->toTripleString()} = $p->getOtherEndPort();
	$wiredports{$p->toIfaceString()} = $p->getOtherEndPort();

	return $p->getOtherEndPort();
    } else {
	return undef;
    }
}

#
# Get the other end port of a wire by iface representation of this end port
# the classname can be ignored
# the representation can be a iface-port string or iface tokens
#
sub GetOtherEndByIface($;$$)
{
    my ($c, $node, $iface) = @_;
    my $str;
    my $p;
    
    if (defined($iface)) {
	$str = Port->Tokens2IfaceString($node, $iface);
    } elsif (!defined($node)) {
        $str = $c;
    } else {
        $str = $node;
        $p = Port->LookupByIface($str);
        if (!defined($p)) {
            $str = Port->Tokens2IfaceString($c, $node);
            $p = Port->LookupByIface($str);
            if (!defined($p)) {
                return undef;
            }
        }
    }
    
    if (!defined($p)) {
    	$p = Port->LookupByIface($str);
    }
    if (defined($p)) {
    
    	$wiredports{$p->toTripleString()} = $p->getOtherEndPort();
	$wiredports{$p->toIfaceString()} = $p->getOtherEndPort();

	return $p->getOtherEndPort();
    } else {
	return undef;
    }
}    


#
# Parse node:iface string into tokens
# classname can be ignored
#
sub ParseIfaceString($;$)
{
    my ($c, $striface) = @_;

    if (!defined($striface)) {
	$striface = $c;
    }

    if ($striface =~ /^([^:]+):(.+)$/) {
	return ($1, $2);
    }

    return (undef, undef);
}

#
# Parse node:card.port string into tokens
# can be called without the classname
#
sub ParseTripleString($;$)
{
    my ($c, $triplestring) = @_;

    if (!defined($triplestring)) {
	$triplestring = $c;
    }

    if ($triplestring =~ /^([^:]+):(\d+)\.(\d+)$/) {
	return ($1, $2, $3);
    }

    return (undef, undef, undef);
}

sub ParseCardPortString($;$)
{
    my ($c, $cp) = @_;

    if (!defined($cp)) {
	$cp = $c;
    }

    # Should not include all fields
    if ($cp =~ /^([^:]+):(\d+)[\/\.](\d+)$/) {
	return (undef, undef);
    }

    if ($cp =~ /^(\d+)\.(\d+)$/ || $cp =~ /^(\d+)\/(\d+)$/) {
	return ($1, $2);
    }

    return (undef, undef);
}

sub Iface2Triple($;$)
{
    my ($c, $striface) = @_;

    if (!defined($striface)) {
	$striface = $c;
    }

    if (exists($allports{$striface})) {
	return $allports{$striface}->toTripleString();
    } else {
	my ($nodeid, $iface) = ParseIfaceString($striface);
	if (!defined($iface)) {
	    return undef;
	}

	my $port = Port->LookupByIface($nodeid, $iface);
	if (defined($port) && $port != 0 && $port != -1) {
	    return $port->toTripleString();
	} else {
	    return undef;
	}
    }
}

sub Triple2Iface($;$)
{
    my ($c, $strtriple) = @_;

    if (!defined($strtriple)) {
	$strtriple = $c;
    }

    if (exists($allports{$strtriple})) {
	return $allports{$strtriple}->toIfaceString();
    } else {
	my ($nodeid, $card, $port) = ParseTripleString($strtriple);
	if (!defined($card) || !defined($port) || !defined($nodeid)) {
	    return undef;
	}

	my $portInst = Port->LookupByTriple($nodeid, $card, $port);
	if (defined($portInst && $port != 0 && $port != -1)) {
	    return $portInst->toIfaceString();
	} else {
	    return undef;
	}
    }
}

sub Tokens2TripleString($$$;$)
{
    my ($c, $nodeid, $card, $port) = @_;

    if (!defined($port)) {
	$port = $card;
	$card = $nodeid;
	$nodeid = $c;
    }

    return "$nodeid:$card.$port";
}

sub Tokens2IfaceString($$;$)
{
    my ($c, $nodeid, $iface) = @_;

    if (!defined($iface)) {
	$iface = $nodeid;
	$nodeid = $c;
    }

    return "$nodeid:$iface";
}


# functions started with fake_ are used to handle
# a special 'node:card/port' representation.

sub fake_CardPort2Iface($$;$)
{
    my ($cn, $c, $p) = @_;

    if (!defined($p)) {
	$p = $c;
	$c = $cn;
    }
    return "$c/$p";
}

sub fake_TripleString2IfaceString($;$)
{
    my ($cn, $t) = @_;

    if (!defined($t)) {
	$t = $cn;
    }

    my ($n, $c, $p) = ParseTripleString($t);
    if (!defined($n) || !defined($c) || !defined($p)) {
        return undef;
    }

    return "$n:".fake_CardPort2Iface($c, $p);
}

sub fake_IfaceString2TripleTokens($;$)
{
    my ($cn, $i) = @_;

    if (!defined($i)) {
	$i = $cn;
    }

    my ($n, $iface) = ParseIfaceString($i);
    
    if (defined($iface) && $iface =~ /^(\d+)\/(\d+)$/) {
	return ($n, $1, $2);
    }    

    return (undef, undef, undef);
}

#
# Class method
# Find the port instance by a given string, if no port found from DB, 
# make a fake one.
#
# This is useful when a port string is derived from the switch, but
# it is not stored in DB. (eg. listing all ports on a switch)
#
# Note from RPR: We have never represented the switch side of
# [interfaces] (except trunks) in the database. Most 'wires' table
# entries have a "real" [interface] on the PC side, but are just
# dangling references on the switch side.
#
sub LookupByStringForced($$)
{
    my ($class, $str) = @_;
    my $inst = {};
    
    my $p = Port->LookupByIface($str);
    if (defined($p)) {
	return $p;
    }
    else {
	$p = Port->LookupByTriple($str);
	if (defined($p)) {
	    return $p;
	}
    }
    
    my $iface;
    my ($nodeid, $card, $port) = Port->ParseTripleString($str);
    if (!defined($port)) {
	($nodeid, $card, $port) = Port->fake_IfaceString2TripleTokens($str);
	if (!defined($port)) {
	    ($nodeid, $iface) = Port->ParseIfaceString($str);
	    if (!defined($iface)) {
		$port = undef;
	    } else {
		$port = 1;
		$card = $iface;
	    }
	} else {
	    $iface = Port->fake_CardPort2Iface($card, $port);
	}
    } else {
	$iface = Port->fake_CardPort2Iface($card, $port);
    }
    
    if (defined($port)) {
	my $irowref = {};
	my $wrowref = {};
	
	$inst->{"RAW_STRING"} = $str;
	$inst->{"FORCED"} = 1;
	$inst->{"HAS_FIELDS"} = 1;
	
	$irowref->{'iface'} = $iface;
	$irowref->{'node_id'} = $nodeid;
	$irowref->{'card'} = $card;
	$irowref->{'port'} = $port;
	$irowref->{'trunk_mode'} = "equal";
	$inst->{"INTERFACES_ROW"} = Interface->MakeFake($nodeid, $irowref);

	# XXX: Incomplete, but if the port isn't in the wires table,
	# what are we to do?  We know nothing about the other end.
	$wrowref->{'type'} = TBDB_WIRETYPE_UNUSED();
	$wrowref->{'node_id1'} = $nodeid;
	$wrowref->{'card1'} = $card;
	$wrowref->{'port1'} = $port;
	$inst->{"WIRES_ROW"} = Interface::Wire->MakeFake($wrowref);
    }
    else {
	$inst->{"RAW_STRING"} = $str;
	$inst->{"FORCED"} = 1;
	$inst->{"HAS_FIELDS"} = 0;
    }
    
    #
    # We should determine this according to the query result
    # in nodes table by nodeid.
    #
    $inst->{"WIRE_END"} = $WIRE_END_SWITCH;
    
    bless($inst, $class);
    return $inst;
}

#
# Class method
# get the port instance according to its iface-string representation
#
sub LookupByIface($$;$)
{
    my ($class, $nodeid, $iface, $force) = @_;
    my $striface="";

    if (!defined($iface)) {
	$striface = $nodeid;
	($nodeid, $iface) = Port->ParseIfaceString($striface);	
    } else {
	$striface = Tokens2IfaceString($class, $nodeid, $iface);	
    }
    
    if (!defined($striface) || !defined($nodeid)) {
        return undef;
    }

    if (exists($allports{$striface})) {
	return $allports{$striface};
    }

    my $interface = Interface->LookupByIface($nodeid, $iface);
    if (!defined($interface)) {
	my ($n, $c, $p) = fake_IfaceString2TripleTokens($class, $striface);
	if (defined($p)) {
	    return LookupByTriple($class, $n, $c, $p);
	} else {
	    return undef;
	}
    }
    my $card = $interface->card();
    my $port = $interface->port();
    my $wire;

    if ($interface->logical()) {
	# This looks at both sides of wire. 
	$wire = Interface::LogicalWire->Lookup($nodeid, $iface);
    }
    else {
	$wire = Interface::Wire->LookupAny($nodeid, $card, $port);
    }
    return undef
	if (!defined($wire));

    my $inst = {};
    $inst->{"INTERFACES_ROW"} = $interface;
    $inst->{"WIRES_ROW"} = $wire;

    if ($wire->type() eq TBDB_WIRETYPE_NODE() ||
	$wire->type() eq TBDB_WIRETYPE_CONTROL()) {
	if ($wire->node_id1() eq $nodeid) {
	    $inst->{"WIRE_END"} = $WIRE_END_NODE;
	} else {
	    $inst->{"WIRE_END"} = $WIRE_END_SWITCH;
	}
    } elsif ($wire->type() eq TBDB_WIRETYPE_TRUNK()) {
	$inst->{"WIRE_END"} = $WIRE_END_SWITCH;
    } elsif ($wire->node_id2() eq $nodeid) {
	$inst->{"WIRE_END"} = $WIRE_END_SWITCH;	
    } else {
	# XXX: Other cases are unhandled for now...
	return undef;
    }

    $inst->{"FORCED"} = 0;
    $inst->{"HAS_FIELDS"} = 1;

    bless($inst, $class);

    $allports{$striface} = $inst;
    $allports{Tokens2TripleString($class, $nodeid, $card, $port)} = $inst;

    return $inst;
}

#
# Class method
# get the port instance according to its triple-string representation
#
sub LookupByTriple($$;$$)
{
    my ($class, $nodeid, $card, $port) = @_;
    my $interface;
    my $strtriple;

    if (!defined($card)) {
	$strtriple = $nodeid;
	($nodeid, $card, $port) = Port->ParseTripleString($strtriple);
    } else {
	$strtriple = Tokens2TripleString($class, $nodeid, $card, $port);
    }
    
    if (!defined($strtriple) || !defined($nodeid) || !defined($card)) {
        return undef;
    }

    if (exists($allports{$strtriple})) {
	return $allports{$strtriple};
    }

    my $inst = {};

    #
    # When looking up triple (say, from a snmpit device module) we are given
    # the switch side of a wire. But if the node is a testnode and isswitch,
    # we really want a logical wire. It would be better if we knew this is
    # what we want for sure.
    #
    my $node = Node->Lookup($nodeid);
    return undef
	if (!defined($node));

    # There *will* be a physical wire.
    my $wire = Interface::Wire->LookupAny($nodeid, $card, $port);    
    return undef
	if (!defined($wire));

    #
    # Now see if we really want the logical wire.
    #
    if ($node->role() eq $NODEROLE_TESTNODE && $node->isswitch() &&
	ref($wire) eq "Interface::LogicalWire") {
	my $logwire =
	    Interface::LogicalWire->LookupByPhysIface($nodeid,
						      $wire->physiface1());
    }
    
    if ($wire->type() eq TBDB_WIRETYPE_NODE() ||
	$wire->type() eq TBDB_WIRETYPE_CONTROL()) {
	# Emulab is consistent about using the node_id1, etc. fields for the
	# endpoint for the above wire types.  If it were not, we would need
	# to consult the 'nodes' table to see what role the node has.
	if ($wire->node_id1() eq $nodeid) {
	    $inst->{"WIRE_END"} = $WIRE_END_NODE;
	} else {
	    $inst->{"WIRE_END"} = $WIRE_END_SWITCH;
	}
    } elsif ($wire->type() eq TBDB_WIRETYPE_TRUNK()) {
	$inst->{"WIRE_END"} = $WIRE_END_SWITCH;
    } elsif ($wire->node_id2() eq $nodeid) {
	# This is a failsafe case for wire types that are 'exotic'.
	$inst->{"WIRE_END"} = $WIRE_END_SWITCH;	
    } else {
	# XXX: Other cases are unhandled for now...
	return undef;
    }
    $inst->{"WIRES_ROW"} = $wire;

    #
    # Lookup the interface for the correct side of the wire.
    #
    if ($wire->node_id2() eq $nodeid) {
	$interface = Interface->LookupByIface($nodeid, $wire->iface2());
    }
    else {
	$interface = Interface->LookupByIface($nodeid, $wire->iface1());
    }

    # Note: The code will almost always fall into this conditional
    # block for switch ports because we typically do not have entries
    # for them in the 'interfaces' table.
    if (!defined($interface)) {
	my $rowref = {};
	my $iface = fake_CardPort2Iface($card, $port);
	$rowref->{'iface'} = $iface;
	$rowref->{'node_id'} = $nodeid;
	$rowref->{'card'} = $card;
	$rowref->{'port'} = $port;
	$rowref->{'trunk_mode'} = "equal";
	$interface = Interface->MakeFake($nodeid, $rowref);
    } 
    my $iface = $interface->iface();

    $inst->{"INTERFACES_ROW"} = $interface;
    $inst->{"FORCED"} = 0;
    $inst->{"HAS_FIELDS"} = 1;

    # wire mapping
    
    bless($inst, $class);

    $allports{$strtriple} = $inst;
    $allports{Tokens2IfaceString($class, $nodeid, $iface)} = $inst;

    return $inst;
}

sub LookupByIfaces($@)
{
    my ($c, @ifs) = @_;

    return map(Port->LookupByIface($_), @ifs);
}

sub LookupByTriples($@)
{
    my ($c, @ifs) = @_;

    return map(Port->LookupByTriple($_), @ifs);
}

#
# Class method
# Get all ports by their wire type
#
sub LookupByWireType($$)
{
    my ($c, $wt) = @_;
    my @ports = ();
	
    my $result =
	DBQueryFatal("(SELECT node_id1,iface1,node_id2,iface2 ".
		     "  FROM wires ".
		     " WHERE type='$wt') ".
		     "union ".
		     " (SELECT node_id1,iface1,node_id2,iface2 ".
		     "  FROM logical_wires ".
		     " WHERE type='$wt') ");

    while (my ($node_id1, $iface1, $node_id2, $iface2) = $result->fetchrow()) {
	my $p1 = Port->LookupByIface($node_id1, $iface1);
	if (defined($p1)) {
	    push @ports, $p1;
	}
	my $p2 = Port->LookupByIface($node_id2, $iface2);
	if (defined($p2)) {
	    push @ports, $p2;
	}
    }
    return @ports;
}

sub field($$)  {
    my ($self, $slot) = @_;

    return -1
	if ((! ref($_[0])) || ($_[0]->{'HAS_FIELDS'} == 0));

    return $self->{'INTERFACES_ROW'}->$slot();
}
sub node_id($) { return field($_[0], 'node_id'); }
sub port($)    { return field($_[0], 'port'); }
sub iface($)   { return field($_[0], 'iface'); }
sub mac($)     { return field($_[0], 'mac'); }
sub IP($)      { return field($_[0], 'IP'); }
sub role($)    { return field($_[0], 'role'); }
sub interface_type($)    { return field($_[0], 'type'); }
sub mask($)    { return field($_[0], 'mask'); }
sub uuid($)    { return field($_[0], 'uuid'); }
sub trunk($)   { return field($_[0], 'trunk'); }
sub trunk_mode($) { return field($_[0], 'trunk_mode'); }
sub logical($) { return field($_[0], 'logical'); }
# These two come from the "interface_state" table, which gives the
# current view vs. the "mandated" (mapped) state from the interfaces table.
sub tagged($)  { return field($_[0], 'tagged'); }
sub enabled($) { return field($_[0], 'enabled'); }

sub wire_end($) { return $_[0]->{'WIRE_END'}; }
sub is_switch_side($) { return $_[0]->wire_end() eq $WIRE_END_SWITCH; }

sub wire_type($)   { return $_[0]->{'WIRES_ROW'}->type(); }
sub is_trunk_port($)  { return $_[0]->wire_type() eq TBDB_WIRETYPE_TRUNK(); }

sub is_forced($) { return $_[0]->{"FORCED"};}
sub has_fields($) { return $_[0]->{"HAS_FIELDS"};}
sub raw_string($) { return $_[0]->{"RAW_STRING"};}

#
# When logical, convert the card back from logical number.
#
sub card($)
{
    my ($self) = shift;
    my $card   = field($self, 'card');

    return $card;
}

sub switch_node_id($)
{
    my $self = shift;
    if ($self->is_switch_side()) {
	return $self->node_id();
    } else {
	return $self->other_end_node_id();
    }
}

sub switch_card($)
{
    my $self = shift;
    if ($self->is_switch_side()) {
	return $self->card();
    } else {
	return $self->other_end_card();
    }
}

sub switch_port($)
{
    my $self = shift;
    if ($self->is_switch_side()) {
	return $self->port();
    } else {
	return $self->other_end_port();
    }
}

sub switch_iface($)
{
    my $self = shift;
    if ($self->is_switch_side()) {
	return $self->iface();
    } else {
	return $self->other_end_iface();
    }
}

sub pc_node_id($)
{
    my $self = shift;
    if (!$self->is_switch_side() ||
	$self->is_trunk_port()) {
	return $self->node_id();
    } else {
	return $self->other_end_node_id();
    }
}

sub pc_card($)
{
    my $self = shift;
    if (!$self->is_switch_side() ||
	$self->is_trunk_port()) {
	return $self->card();
    } else {
	return $self->other_end_card();
    }
}

sub pc_port($)
{
    my $self = shift;
    if (!$self->is_switch_side() ||
	$self->is_trunk_port()) {
	return $self->port();
    } else {
	return $self->other_end_port();
    }
}

sub pc_iface($)
{
    my $self = shift;
    if (!$self->is_switch_side() ||
	$self->is_trunk_port()) {
	return $self->iface();
    } else {
	return $self->other_end_iface();
    }
}

#
# get node_id field of the other end Port instance
#
sub other_end_node_id($)   
{ 
    my $self = $_[0];
    
    if ($self->is_forced) {
	if ($self->has_fields()) {
	    return $self->node_id();
	} else {
	    return $self->raw_string();
	}
    }

    if ($self->node_id() eq $self->{'WIRES_ROW'}->node_id1()) {
	return $self->{'WIRES_ROW'}->node_id2(); 
    } else {
	return $self->{'WIRES_ROW'}->node_id1();
    }
}

#
# get card field of the other end Port instance
#
sub other_end_card($) 
{
    my $self = $_[0];
    
    if ($self->is_forced) {
	if ($self->has_fields()) {
	    return $self->card();
	} else {
	    return $self->raw_string();
	}
    }
    my $card;

    if ($self->node_id() eq $self->{'WIRES_ROW'}->node_id1()) {
	$card = $self->{'WIRES_ROW'}->card2(); 
    } else {
	$card = $self->{'WIRES_ROW'}->card1();
    }
    return $card;
}

#
# get port field of the other end Port instance
#
sub other_end_port($) 
{
    my $self = $_[0];
    
    if ($self->is_forced) {
	if ($self->has_fields()) {
	    return $self->port();
	} else {
	    return $self->raw_string();
	}
    }

    if ($self->node_id() eq $self->{'WIRES_ROW'}->node_id1()) {
	return $self->{'WIRES_ROW'}->port2(); 
    } else {
	return $self->{'WIRES_ROW'}->port1();
    }
}

#
# get iface field of the other end Port instance
#
sub other_end_iface($)
{
    my $self = $_[0];
    
    if ($self->is_forced) {
	if ($self->has_fields()) {
	    return $self->iface();
	} else {
	    return $self->raw_string();
	}
    }

    if ($self->node_id() eq $self->{'WIRES_ROW'}->node_id1()) {
	return Port->LookupByTriple(
	    $self->{'WIRES_ROW'}->node_id2(),
	    $self->{'WIRES_ROW'}->card2(),
	    $self->{'WIRES_ROW'}->port2())->iface(); 
    } else {
	return Port->LookupByTriple(
	    $self->{'WIRES_ROW'}->node_id1(),
	    $self->{'WIRES_ROW'}->card1(),
	    $self->{'WIRES_ROW'}->port1())->iface(); 
    }
}

#
# to the 'iface' string representation
#
sub toIfaceString($) {
    my $self = shift;
    if (!$self->has_fields()) {
	return $self->raw_string();
    }
    return Tokens2IfaceString($self->node_id(), $self->iface());
}
    
#
# to the 'triple' string representation
# 
sub toTripleString($) {
    my $self = shift;
    if (!$self->has_fields()) {
	return $self->raw_string();
    }
    return Tokens2TripleString($self->node_id(), $self->card(), $self->port());
}

#
# to default string representation, which default is 'triple'
# 
sub toString($) {
    my $self = shift;
    if (!$self->has_fields()) {
	return $self->raw_string();
    }
    return $self->toTripleString();
}

#
# convert to the old "node:card" string
#
sub toNodeCardString($) {
    return Tokens2IfaceString($_[0]->node_id(), $_[0]->card());
}

#
# get port instance according to the given node_id
# 
sub getEndByNode($$) {
	my ($self, $n) = @_;
	if ($n eq $self->node_id()) {
		return $self;
	} elsif ($n eq $self->other_end_node_id()) { 
		return $self->getOtherEndPort();
	} else {
		return undef;
	}
}

#
# get the other side's triple string representation
#
sub getOtherEndTripleString($) {
    return Tokens2TripleString($_[0]->other_end_node_id(), $_[0]->other_end_card(), $_[0]->other_end_port());
}

#
# get the other side's iface string representation
#
sub getOtherEndIfaceString($) {
    return Tokens2IfaceString($_[0]->other_end_node_id(), $_[0]->other_end_iface());
}

#
# get the other side of a port instance, according to 'wires' DB table
#
sub getOtherEndPort($) {
    my $self = $_[0];
    my $pt = Port->LookupByTriple($self->getOtherEndTripleString());
    if (defined($pt)) {
	return $pt;
    } else {
	return $self;
    }
}

#
# get the PC side of a port instance.  It is bogus to call this on an
# inter-switch trunk port, but we return the local ("this") side
# anyway in this case since some snmpit code using this method doesn't
# check the link type.
#
sub getPCPort($) {
    my $self = $_[0];
    
    if ($self->is_forced) {
	return $self;
    }

    if (!$self->is_switch_side() ||
	$self->is_trunk_port()) {
	return $self;
    } else {
	return $self->getOtherEndPort();
    }
}

#
# get the switch side of a port instance.  This call is ambiguous in
# the case of an inter-switch trunk port, and will always return "this"
# port.
#
sub getSwitchPort($) {
    my $self = $_[0];
    
    if ($self->is_forced) {
	return $self;
    }

    if ($self->is_switch_side()) {
	return $self;
    } else {
	return $self->getOtherEndPort();
    }
}

#
# convert an array of ports into string, in iface representation
#
sub toIfaceStrings($@)
{
	my ($c, @pts) = @_;
	if (@pts != 0) {
	    if (Port->isPort($pts[0])) {
		return join(" ", map($_->toIfaceString(), @pts)); 
	    }
	}
	return join(" ", @pts);
}

#
# convert an array of ports into string, in triple-filed representation
#
sub toTripleStrings($@)
{
	my ($c, @pts) = @_;
	if (@pts != 0) {
	    if (Port->isPort($pts[0])) {
		return join(" ", map($_->toTripleString(), @pts)); 
	    }
	}
	return join(" ", @pts);
}

#
# convert an array of ports into string, in default string representation
#
sub toStrings($@)
{
	my ($c, @pts) = @_;
	if (@pts != 0) {
	    if (Port->isPort($pts[0])) {
		return join(" ", map($_->toString(), @pts)); 
	    }
	}
	return join(" ", @pts);
}

#
# Stringify for output.
#
sub Stringify($)
{
    my ($self) = @_;
    
    return $self->toString();
}

#
# Comparison
#
sub SamePort($$)
{
    my ($this, $that) = @_;

    return ($this->node_id() eq $that->node_id() &&
	    $this->card() == $that->card() &&
	    $this->port() == $that->port() ? 1 : 0);
}
return 1;
