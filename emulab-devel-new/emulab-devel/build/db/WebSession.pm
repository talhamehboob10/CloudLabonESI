#!/usr/bin/perl -wT
#
# Copyright (c) 2013-2014 University of Utah and the Flux Group.
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
package WebSession;

use strict;
use Carp;
use Exporter;
use SelfLoader ();
use vars qw(@ISA @EXPORT $AUTOLOAD);
@ISA    = qw(Exporter);
@EXPORT = qw( );

use emdb;
use JSON;
use Data::Dumper;
use overload ('""' => 'Stringify');

# Configure variables
my $TB	     = "/users/mshobana/emulab-devel/build";

#
# Lookup by session id
#
sub Lookup($$)
{
    my ($class, $id) = @_;

    if ($id !~ /^[-\w]+$/) {
	return undef;
    }
    my $query_result =
	DBQueryWarn("select session_id,session_data, ".
		    "    UNIX_TIMESTAMP(session_expires) as session_expires ".
		    "  from web_sessions ".
		    "where session_id='$id' and session_expires>now()");

    return undef
	if (!$query_result || !$query_result->numrows);
      
    my $self           = {};
    $self->{'DBROW'}   = $query_result->fetchrow_hashref();

    bless($self, $class);

    #
    # Turn the session data into a perl array so we can mess with it.
    #
    $self->{'DATA'}    = eval { decode_json($self->session_data()); };
    if ($@) {
	print STDERR "Could not json decode session data\n";
	return -1;
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
    # Or it is for a session data.
    if (scalar(@_) == 2) {
	return $self->{'DATA'}->{$name} = $_[1];
    }
    elsif (exists($self->{'DATA'}->{$name})) {
	return $self->{'DATA'}->{$name};
    }
    carp("No such slot '$name' field in class $type");
    return undef;
}

# Break circular reference someplace to avoid exit errors.
sub DESTROY {
    my $self = shift;

    $self->{'DBROW'} = undef;
    $self->{'DATA'}  = undef;
}

#
# Write the session back to the DB.
#
sub Store($)
{
    my ($self) = @_;
    
    my $id       = $self->session_id();
    my $data     = eval { encode_json($self->{'DATA'}); };
    if ($@) {
	print STDERR "Could not json encode session data\n";
	return -1;
    }
    $data = emdb::DBQuoteSpecial($data);
    DBQueryWarn("update web_sessions set session_data=$data ".
		"where session_id='$id'")
	or return -1;

    return 0;
}

#
# Stringify for output.
#
sub Stringify($)
{
    my ($self) = @_;
    
    my $id       = $self->session_id();
    my $expires  = $self->session_expires();

    return "[WebSession: $id: $expires]";
}

# Debugging.
sub Dump($)
{
    my ($self) = @_;
    
    print STDERR Dumper($self->{'DATA'}) . "\n";
}

# _Always_ make sure that this 1 is at the end of the file...
1;
