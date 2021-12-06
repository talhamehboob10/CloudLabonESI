#!/usr/bin/perl -wT
#
# Copyright (c) 2005-2021 University of Utah and the Flux Group.
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
package NodeType;

use strict;
use Exporter;
use vars qw(@ISA @EXPORT);

@ISA    = "Exporter";
@EXPORT = qw ( );

use libdb;
use libtestbed;
use EmulabConstants;
use English;
use Data::Dumper;
use overload ('""' => 'Stringify');

# Configure variables
my $TB		= "/users/mshobana/CloudLabonESI/emulab-devel-new/emulab-devel/sample_build";
my $BOSSNODE    = "boss.cloudlab.umass.edu";

# Cache of instances to avoid regenerating them.
my %nodetypes	= ();
my %nodeclasses = ();
BEGIN { use emutil;
	emutil::AddCache(\%nodetypes);
	emutil::AddCache(\%nodeclasses); }

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
# Lookup a (physical) node and create a class instance to return.
#
sub Lookup($$)
{
    my ($class, $type) = @_;
    my $query_result;

    # Look in cache first
    return $nodetypes{$type}
        if (exists($nodetypes{$type}));

    if ($type =~ /^[-\w]+$/) {
	$query_result =
	    DBQueryWarn("select * from node_types where type='$type'");
    }
    else {
	return undef;
    }
    return undef
	if (!$query_result || !$query_result->numrows);

    return LookupRow($class, $type, $query_result->fetchrow_hashref());
}

sub LookupRow($$$)
{
    my ($class, $type, $row) = @_;

    my $self         = {};
    # Do not use the embedded type field, cause of auxtypes.
    $self->{"TYPE"}  = $type;
    $self->{"DBROW"} = $row;
    $self->{"CLASS"} = ($type eq $row->{"class"} ? $type : undef);
    $self->{"ATTRS"} = undef;
    $self->{"FETRS"} = undef;
    $self->{"ISAUX"} = 0;

    bless($self, $class);

    # Add to cache.
    $nodetypes{$type} = $self;
    return $self;
}

# accessors
sub field($$)  { return ((! ref($_[0])) ? -1 : $_[0]->{'DBROW'}->{$_[1]}); }
# Do not use the embedded type field, cause of auxtypes.
sub type($)           { return $_[0]->{'TYPE'}; }
sub class($)          { return field($_[0], 'class'); }
sub IsAuxType($)      { return $_[0]->{'ISAUX'}; }
sub architecture($)   { return field($_[0], 'architecture'); }
sub isvirtnode($)     { return field($_[0], 'isvirtnode'); }
sub isjailed($)       { return field($_[0], 'isjailed'); }
sub isdynamic($)      { return field($_[0], 'isdynamic'); }
sub isremotenode($)   { return field($_[0], 'isremotenode'); }
sub issubnode($)      { return field($_[0], 'issubnode'); }
sub isplabdslice($)   { return field($_[0], 'isplabdslice'); }
sub isplabphysnode($) { return field($_[0], 'isplabphysnode'); }
sub issimnode($)      { return field($_[0], 'issimnode'); }
sub isgeninode($)     { return field($_[0], 'isgeninode'); }
sub isfednode($)      { return field($_[0], 'isfednode'); }
sub isswitch($)       { return field($_[0], 'isswitch'); }
sub attributes($)     { return $_[0]->{'ATTRS'}; }
sub features($)       { return $_[0]->{'FETRS'}; }

#
# Force a reload of the data.
#
sub LookupSync($$)
{
    my ($class, $type) = @_;

    # delete from cache
    delete($nodetypes{$type})
        if (exists($nodetypes{$type}));
    delete($nodeclasses{$type})
        if (exists($nodeclasses{$type}));

    return Lookup($class, $type);
}

#
# Find me a type, or a class, or by auxtype. Just find me something!
#
sub LookupAny($$)
{
    my ($class, $type) = @_;

    my $obj = NodeType->Lookup($type);
    return $obj
	if (defined($obj));

    my $query_result =
	DBQueryWarn("select type from node_types where class='$type' limit 1");
    return undef
	if (!$query_result);
    if ($query_result->numrows) {
	my ($ntype) = $query_result->fetchrow_array();
	my $obj = NodeType->Lookup($ntype);
	return undef
	    if (!defined($obj));
	$obj->{'CLASS'} = $type;
	return $obj;
    }

    # Try for an auxtype.
    return NodeType->LookupAuxType($type);
}

#
# Return a list of all types.
#
sub AllTypes($)
{
    my ($class)  = @_;
    my @alltypes = ();
    
    my $query_result =
	DBQueryWarn("select type from node_types");
    
    return undef
	if (!$query_result || !$query_result->numrows);

    while (my ($type) = $query_result->fetchrow_array()) {
	my $typeinfo = Lookup($class, $type);

	# Something went wrong?
	return undef
	    if (!defined($typeinfo));
	
	push(@alltypes, $typeinfo);
    }
    return @alltypes;
}

#
# Lookup all types of a given architecture.
#
sub LookupArchitectureTypes($$)
{
    my ($class,$arch)  = @_;
    my @alltypes = ();
    
    my $query_result =
	DBQueryWarn("select type from node_types where architecture='$arch'");
    
    return undef
	if (!$query_result || !$query_result->numrows);

    while (my ($type) = $query_result->fetchrow_array()) {
	my $typeinfo = Lookup($class, $type);

	# Something went wrong?
	return undef
	    if (!defined($typeinfo));
	
	push(@alltypes, $typeinfo);
    }
    return @alltypes;
}

#
# Lookup an auxtype.
#
sub LookupAuxType($$)
{
    my ($class, $auxtype)  = @_;
    
    my $query_result =
	DBQueryWarn("select nt.type from node_types_auxtypes as at ".
		    "left join node_types as nt on nt.type=at.type ".
		    "where at.auxtype='$auxtype'");
    
    return undef
	if (!$query_result || !$query_result->numrows);

    my ($type) = $query_result->fetchrow_array();
    my $typeinfo = Lookup($class, $type);

    # Something went wrong?
    return undef
	if (!defined($typeinfo));

    #
    # Generate a new type entry, but named by the auxtype instead.
    # Underlying data is shared; might need to change that.
    #
    my $newtype         = {};
    $newtype->{"TYPE"}  = $auxtype;
    $newtype->{"DBROW"} = $typeinfo->{"DBROW"};
    $newtype->{"ATTRS"} = $typeinfo->{"ATTRS"};
    $newtype->{"FETRS"} = $typeinfo->{"FETRS"};
    $newtype->{"ISAUX"} = 1;
    $newtype->{"BASE"}  = $typeinfo;
    bless($newtype, $class);

    # Add to cache.
    $nodetypes{$auxtype} = $newtype;
    return $newtype;
}
sub BaseType($)
{
    my ($self) = @_;
    
    return undef
	if (!$self->IsAuxType());
    return $self->{'BASE'};
}

#
# Return list of all auxtypes.
#
sub AuxTypes($)
{
    my ($class)  = @_;
    my @auxtypes = ();
    
    my $query_result =
	DBQueryFatal("select at.auxtype,nt.type ".
		     "  from node_types_auxtypes as at ".
		     "left join node_types as nt on nt.type=at.type ");
    
    return ()
	if (!$query_result || !$query_result->numrows);

    while (my ($auxtype, $type) = $query_result->fetchrow_array()) {
	my $typeinfo = LookupAuxType($class, $auxtype);

	# Something went wrong?
	return undef
	    if (!defined($typeinfo));
	
	push(@auxtypes, $typeinfo);
    }
    return @auxtypes;
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
	DBQueryWarn("select attrkey,attrvalue,attrtype ".
		    "  from node_type_attributes ".
		    "where type='$type'");

    $self->{"ATTRS"} = {};
    while (my ($key,$val,$type) = $query_result->fetchrow_array()) {
	$self->{"ATTRS"}->{$key} = { "key"   => $key,
				     "value" => $val,
				     "type"  => $type };
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

    return "[NodeType: $type/$class]";
}

#
# Did we find this type cause it was a class lookup. Bogus, need a
# different object for this.
#
sub IsClass($)
{
    my ($self) = @_;

    return (defined($self->{'CLASS'}) ? 1 : 0);
}

#
# Look for an attribute.
#
sub GetAttribute($$;$$)
{
    my ($self, $attrkey, $pattrvalue, $pattrtype) = @_;
    
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

    return 0;
    
  bad:
    return undef
	if (!defined($pattrvalue));
    $$pattrvalue = undef;
    return -1;
}

#
# Look for an attribute.
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
sub default_osid($;$)  {return GetAttribute($_[0], "default_osid", $_[1]); }
sub default_imageid($;$){return GetAttribute($_[0], "default_imageid",$_[1]); }
sub delay_osid($;$)    {return GetAttribute($_[0], "delay_osid", $_[1]); }
sub jail_osid($;$)     {return GetAttribute($_[0], "jail_osid", $_[1]); }
sub imageable($;$)     {return GetAttribute($_[0], "imageable", $_[1]); }
sub memory($;$)        {return GetAttribute($_[0], "memory", $_[1]); }
sub disksize($;$)      {return GetAttribute($_[0], "disksize", $_[1]); }
sub disktype($;$)      {return GetAttribute($_[0], "disktype", $_[1]); }
sub bootdisk_unit($;$) {return GetAttribute($_[0], "bootdisk_unit", $_[1]); }
sub boot_method($;$)   {return GetAttribute($_[0], "boot_method", $_[1]); }
sub pxe_boot_path($;$) {return GetAttribute($_[0], "pxe_boot_path", $_[1]); }
sub processor($;$)     {return GetAttribute($_[0], "processor", $_[1]); }
sub frequency($;$)     {return GetAttribute($_[0], "frequency", $_[1]); }
sub bios_waittime($;$) {return GetAttribute($_[0], "bios_waittime", $_[1]); }
sub control_iface($;$) {return GetAttribute($_[0], "control_interface",$_[1]);}
sub adminmfs_osid($;$) {return GetAttribute($_[0], "adminmfs_osid",$_[1]);}
sub reoverymfs_osid($;$) {return GetAttribute($_[0], "recoverymfs_osid",$_[1]);}
sub rebootable($;$)    {return GetAttribute($_[0], "rebootable",$_[1]);}
sub power_delay($;$)   {return GetAttribute($_[0], "power_delay",$_[1]);}
sub shared($;$)        {return GetAttribute($_[0], "shared",$_[1]);}
sub cyclewhenoff($;$)  {return GetAttribute($_[0], "cyclewhenoff",$_[1]);}
sub brokenipmi($;$)    {return GetAttribute($_[0], "brokenipmi",$_[1]);}

sub initial_experiment($;$) {
    return GetAttribute($_[0], "initial_experiment",$_[1]);
}
sub virtnode_capacity($;$) {
    return GetAttribute($_[0], "virtnode_capacity", $_[1]);
}
sub simnode_capacity($;$) {
    return GetAttribute($_[0], "simnode_capacity", $_[1]);
}
sub delay_capacity($;$) {
    return GetAttribute($_[0], "delay_capacity", $_[1]);
}
sub trivlink_maxspeed($;$) {
    return GetAttribute($_[0], "trivlink_maxspeed", $_[1]);
}
sub isdedicatedremote($;$) {
    return GetAttribute($_[0], "dedicated_widearea", $_[1]);
}
sub isfakenode($;$) {
    return GetAttribute($_[0], "fakenode", $_[1]);
}
sub isblackbox($;$) {
    return GetAttribute($_[0], "blackbox", $_[1]);
}
sub required_license($;$) {
    return GetAttribute($_[0], "required_license", $_[1]);
}
sub requires_frequency_reservation($;$) {
    return GetAttribute($_[0], "requires_frequency_reservation", $_[1]);
}
sub requires_reservation($;$) {
    return GetAttribute($_[0], "requires_reservation", $_[1]);
}
sub delayreloadtillalloc($;$) {
    return GetAttribute($_[0], "delayreloadtillalloc", $_[1]);
}
sub powercycleafterreload($;$) {
    return GetAttribute($_[0], "powercycleafterreload", $_[1]);
}
sub reservable($;$) {
    return GetAttribute($_[0], "reservable", $_[1]);
}
sub control_interface($;$) { return control_iface($_[0], $_[1]); }

#
# Set the value of an attribute
#
sub SetAttribute($$$;$)
{
    my ($self, $attrkey, $attrvalue, $attrtype) = @_;
    
    goto bad
	if (!ref($self));

    $self->LoadAttributes() == 0
	or return -1;

    $attrtype = "string"
	if (!defined($attrtype));
    my $safe_attrvalue = DBQuoteSpecial($attrvalue);
    my $type = $self->type();

    DBQueryWarn("replace into node_type_attributes set ".
		"  type='$type', attrkey='$attrkey', ".
		"  attrtype='$attrtype', attrvalue=$safe_attrvalue")
	or return -1;

    $self->{"ATTRS"}->{$attrkey} = $attrvalue;
    return 0;
}

#
# Load features if not already loaded.
#
sub LoadFeatures($)
{
    my ($self) = @_;

    return 0
	if (defined($self->{"FETRS"}));

    #
    # Get the attribute array.
    #
    my $type = $self->type();
    
    my $query_result =
	DBQueryWarn("select feature,weight from node_type_features ".
		    "where type='$type'");

    $self->{"FETRS"} = {};
    while (my ($key,$val) = $query_result->fetchrow_array()) {
	$self->{"FETRS"}->{$key} = $val;
    }
    return 0;
}
#
# Look for a feature
#
sub GetFeature($$)
{
    my ($self, $key) = @_;
    
    $self->LoadFeatures() == 0
	or return undef;

    if (!exists($self->{"FETRS"}->{$key})) {
	return undef;
    }
    return $self->{"FETRS"}->{$key};
}
sub disksize_any($)	{ return $_[0]->GetFeature("?+disk_any"); }

#
# Free/Inuse count for a type.
#
sub Counts($)
{
    my ($self) = @_;
    my $type   = $self->type();
    my $total  = 0;
    my $free   = 0;
    
    my $query_result =
	DBQueryWarn("select count(*) from nodes where type='$type'");
    return undef
	if (!defined($query_result));
    if ($query_result->numrows) {
	($total) = $query_result->fetchrow_array();
    }
    $query_result =
	DBQueryWarn("select count(a.node_id) from nodes as a ".
		     "left join reserved as b on a.node_id=b.node_id ".
		     "where b.node_id is null and a.type='$type' and ".
                     "    a.reserved_pid is null and ".
                     "    (a.eventstate='" . TBDB_NODESTATE_ISUP . "' or ".
                     "     a.eventstate='" . TBDB_NODESTATE_POWEROFF . "' or ".
                     "     a.eventstate='" . TBDB_NODESTATE_ALWAYSUP . "' or ".
                     "     a.eventstate='" . TBDB_NODESTATE_PXEWAIT . "')");
    return undef
	if (!defined($query_result));
    if ($query_result->numrows) {
	($free) = $query_result->fetchrow_array();
    }
    return {"total" => $total, "free" => $free};
}

#
# Utility function to look up a global vtype and return the list.
#
sub GlobalVtypeTypes($$)
{
    my ($class, $vtype) = @_;
    my @result = ();

    my $query_result =
	DBQueryWarn("select types from global_vtypes where vtype='$vtype'");
    return ()
	if (!defined($query_result) || !$query_result->numrows);

    my ($typestring) = $query_result->fetchrow_array();
    foreach my $t (split(/\s+/, $typestring)) {
	my $type = NodeType->Lookup($t);
	push(@result, $type)
	    if (defined($type));
    }
    return @result;
}

# _Always_ make sure that this 1 is at the end of the file...

1;
