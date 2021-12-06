#!/usr/bin/perl -wT
#
# Copyright (c) 2012,2013,2016 University of Utah and the Flux Group.
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
package BlockstoreType;

use strict;
use Exporter;
use vars qw(@ISA @EXPORT);

@ISA    = "Exporter";
@EXPORT = qw ( );

use libdb;
use libtestbed;
use English;
use Data::Dumper;
use overload ('""' => 'Stringify');

# Cache of instances to avoid regenerating them.
my %bstypes	= ();
BEGIN { use emutil; emutil::AddCache(\%bstypes); }
my $debug	= 0;

# Little helper and debug function.
sub mysystem($)
{
    my ($command) = @_;

    print STDERR "Running '$command'\n"
	if ($debug);
    return system($command);
}

#
# Lookup a (physical) storage object type and create a class instance to 
# return.
#
sub Lookup($$)
{
    my ($class, $type) = @_;

    # Look in cache first
    return $bstypes{$type}
        if (exists($bstypes{$type}));

    my $self         = {};
    $self->{"TYPE"}  = $type;
    $self->{"ATTRS"} = undef;

    bless($self, $class);

    # Load attributes for type from DB.  No attrs means type doesn't exist.
    $self->LoadAttributes();
    if (!$self->{"ATTRS"}) {
	return undef;
    }

    # Add to cache.
    $bstypes{$type} = $self;
    return $self;
}

#
# Force a reload of the data.
#
sub LookupSync($$)
{
    my ($class, $type) = @_;

    # delete from cache
    delete($bstypes{$type})
        if (exists($bstypes{$type}));

    return Lookup($class, $type);
}

#
# Return a list of all types.
#
sub AllTypes($)
{
    my ($class)  = @_;
    my @alltypes = ();
    
    my $query_result =
	DBQueryWarn("select distinct type from blockstore_type_attributes");
    
    return ()
	if (!$query_result || !$query_result->numrows);

    while (my ($type) = $query_result->fetchrow_array()) {
	my $typeinfo = Lookup($class, $type);

	# Something went wrong?
	return ()
	    if (!defined($typeinfo));
	
	push(@alltypes, $typeinfo);
    }
    return @alltypes;
}

sub AllClasses($)
{
    my ($class) = @_;
    my @allclasses = ();

    my @alltypes = $class->AllTypes();

    foreach my $bst (@alltypes) {
	my $cl = $bst->class();
	if ($cl) {
	    push(@allclasses, $cl)
	}
    }
    return @allclasses;
}

sub AllProtocols($)
{
    my ($class) = @_;
    my @allprotos = ();

    my @alltypes = $class->AllTypes();

    foreach my $bst (@alltypes) {
	my $proto = $bst->protocol();
	if ($proto) {
	    push(@allprotos, $proto)
	}
    }
    return @allprotos;
}

#
# Load attributes if not already loaded.
#
sub LoadAttributes($)
{
    my ($self) = @_;

    return -1
	if (!ref($self));

    return 0
	if (defined($self->{"ATTRS"}));

    #
    # Get the attribute array.
    #
    my $type = $self->type();
    
    my $query_result =
	DBQueryWarn("select attrkey,attrvalue,attrtype,isfeature ".
		    "  from blockstore_type_attributes ".
		    "where type='$type'");

    $self->{"ATTRS"} = {};
    while (my ($key,$val,$type,$isfeature) = $query_result->fetchrow_array()) {
	$self->{"ATTRS"}->{$key} = { "key"   => $key,
				     "value" => $val,
				     "type"  => $type ,
				     "isfeature" => $isfeature };
    }
    return 0;
}

#
# Stringify for output.
#
sub Stringify($)
{
    my ($self) = @_;
    
    my $type  = $self->type();
    my $class = $self->class();

    return "[BlockstoreType: $type/$class]";
}

#
# Look for an attribute.
#
sub GetAttribute($$;$$$)
{
    my ($self, $attrkey, $pattrvalue, $pattrtype, $pattrfeature) = @_;
    
    goto bad
	if (!ref($self));

    $self->LoadAttributes() == 0
	or goto bad;

    if (!exists($self->{"ATTRS"}->{$attrkey})) {
	return undef
	    if (!defined($pattrvalue));
	$$pattrvalue = undef;
	return 0;
    }

    my $ref = $self->{"ATTRS"}->{$attrkey};

    # Return value instead if a $pattrvalue not provided. 
    return $ref->{'value'}
        if (!defined($pattrvalue));
    
    $$pattrvalue = $ref->{'value'};
    $$pattrtype  = $ref->{'type'}
        if (defined($pattrtype));
    $$pattrfeature = $ref->{'isfeature'}
        if (defined($pattrfeature));

    return 0;
    
  bad:
    return undef
	if (!defined($pattrvalue));
    $$pattrvalue = undef;
    return -1;
}

#
# Grab all attributes.
#
sub GetAttributes($)
{
    my ($self) = @_;
    
    return undef
	if (!ref($self));

    $self->LoadAttributes() == 0
	or return undef;

    return $self->{"ATTRS"};
}

# Shortcuts for typical attributes.
sub type($)            {return $_[0]->{'TYPE'}; }
sub class($;$)         {return GetAttribute($_[0], "class", $_[1]); }
sub protocol($;$)      {return GetAttribute($_[0], "protocol", $_[1]); }

#
# Set the value of an attribute
#
sub SetAttribute($$$;$$)
{
    my ($self, $attrkey, $attrvalue, $attrtype, $attrfeature) = @_;
    
    goto bad
	if (!ref($self));

    $self->LoadAttributes() == 0
	or return -1;

    $attrtype = "string"
	if (!defined($attrtype));
    $attrfeature = (defined($attrfeature) && $attrfeature) ? 1 : 0;
    my $safe_attrvalue = DBQuoteSpecial($attrvalue);
    my $type = $self->type();

    DBQueryWarn("replace into blockstore_type_attributes set ".
		"  type='$type', attrkey='$attrkey', ".
		"  attrtype='$attrtype', attrvalue=$safe_attrvalue, ".
		"  isfeature='$attrfeature'")
	or return -1;

    $self->{"ATTRS"}->{$attrkey} = $attrvalue;
    return 0;
}

# _Always_ make sure that this 1 is at the end of the file...

1;
