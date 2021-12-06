#!/usr/bin/perl -wT
#
# Copyright (c) 2013-2019 University of Utah and the Flux Group.
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
package PreReservation;

use strict;
use Carp;
use Exporter;
use SelfLoader ();
use vars qw(@ISA @EXPORT $AUTOLOAD);
@ISA    = qw(Exporter);
@EXPORT = qw( );

use emdb;
use emutil;
use Node;
use libtestbed;
use Data::Dumper;
use overload ('""' => 'Stringify');

# Configure variables
my $TB	     = "/users/mshobana/emulab-devel/build";

#
# Lookup.
#
sub Lookup($$$)
{
    my ($class, $arg1, $arg2) = @_;
    my $query_result;

    if (defined($arg1) && defined($arg2) &&
	$arg1 =~ /^[-\w]*$/ && $arg2 =~ /^[-\w]*$/) {
	$query_result =
	    DBQueryWarn("select *,UNIX_TIMESTAMP(created) as created ".
			"    from project_reservations ".
			"where pid='$arg1' and name='$arg2'");
    }
    elsif (ValidUUID($arg1)) {
	$query_result =
	    DBQueryWarn("select *,UNIX_TIMESTAMP(created) as created ".
			"    from project_reservations ".
			"where uuid='$arg1'");
    }
    else {
	return undef;
    }
    return undef
	if (!$query_result || !$query_result->numrows);
      
    my $self             = {};
    $self->{'DBROW'}     = $query_result->fetchrow_hashref();
    $self->{'NODES'}     = {};
    $self->{'PRERES'}    = {};
    bless($self, $class);

    #
    # Also the pending nodes, if any.
    #
    my $pid     = $self->pid();
    my $pid_idx = $self->pid_idx();
    my $resname = $self->name();
    $query_result = DBQueryWarn("select node_id from node_reservations ".
				"where pid_idx='$pid_idx' and ".
				"      reservation_name='$resname'");
    while (my ($node_id) = $query_result->fetchrow_array()) {
	my $node = Node->Lookup($node_id);
	if (!defined($node)) {
	    print STDERR "No such node $node_id\n";
	    return undef;
	}
	$self->{'NODES'}->{$node_id} = $node;
    }
    #
    # And the nodes currently pre-reserved.
    #
    $query_result = DBQueryWarn("select node_id from nodes ".
				"where reserved_pid='$pid' and ".
				"      reservation_name='$resname'");
    while (my ($node_id) = $query_result->fetchrow_array()) {
	my $node = Node->Lookup($node_id);
	if (!defined($node)) {
	    print STDERR "No such node $node_id\n";
	    return undef;
	}
	$self->{'PRERES'}->{$node_id} = $node;
    }
    return $self;
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
    return undef;
}
sub Nodes($)		{ return values(%{$_[0]->{'NODES'}}); }
sub PreReserved($)	{ return values(%{$_[0]->{'PRERES'}}); }

# Break circular reference someplace to avoid exit errors.
sub DESTROY {
    my $self = shift;

    $self->{'DBROW'}  = undef;
    $self->{'NODES'}  = undef;
    $self->{'PRERES'} = undef;
}

sub Stringify($)
{
    my ($self) = @_;

    my $name = $self->name();
    my $uid  = $self->uid();
    my $pid  = $self->pid();

    return "[PreReservation: $pid/$name $uid]";
}    

# _Always_ make sure that this 1 is at the end of the file...
1;
