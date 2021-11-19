#!/usr/bin/perl -wT
#
# Copyright (c) 2009-2019 University of Utah and the Flux Group.
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
package VirtExperiment;
use strict;
use Carp;
use Exporter;
use vars qw(@ISA @EXPORT);

@ISA    = "Exporter";
@EXPORT = qw ( );

# Must come after package declaration!
use emdb;
use emutil;
use libtestbed;
use Data::Dumper;
use overload ('""' => 'Stringify');

use vars qw($STORE_FLAGS_DEBUG $STORE_FLAGS_IMPOTENT $STORE_FLAGS_SIMPARSE
            $STORE_FLAGS_REPLACE
	    $LOOKUP_FLAGS_NOLOAD
	    %virtual_tables %experiment_fields
	    $AUTOLOAD @EXPORT_OK);

# Store() flags.
$STORE_FLAGS_DEBUG	= 0x01;
$STORE_FLAGS_IMPOTENT	= 0x02;
$STORE_FLAGS_SIMPARSE	= 0x04;
$STORE_FLAGS_REPLACE    = 0x08;
# Lookup Flags
$LOOKUP_FLAGS_NOLOAD    = 0x01;

# Why, why, why?
@EXPORT_OK = qw($STORE_FLAGS_DEBUG $STORE_FLAGS_IMPOTENT
		$STORE_FLAGS_SIMPARSE $STORE_FLAGS_REPLACE
                $LOOKUP_FLAGS_NOLOAD);

# Configure variables
my $TB		= "/test";
my $BOSSNODE    = "boss.cloudlab.umass.edu";
my $CONTROL	= "ops.cloudlab.umass.edu";
my $TBOPS       = "testbed-ops\@ops.cloudlab.umass.edu";

# Cache of instances to avoid regenerating them.
my %virtexperiments   = ();
BEGIN { use emutil; emutil::AddCache(\%virtexperiments); }
my $debug	      = 0;

#
# Describe the virt tables and their primary keys. 
#
%virtual_tables = 
    ("virt_nodes"		=> [ "vname" ],
     "virt_lans"		=> [ "vname", "vnode", "vport"],
     "virt_lan_lans"		=> [ "vname" ],
     "virt_lan_settings"	=> [ "vname", "capkey" ],
     "virt_lan_member_settings" => [ "vname", "member", "capkey" ],
     "virt_trafgens"		=> [ "vname", "vnode" ],
     "virt_agents"		=> [ "vname", "vname", "vnode" ],
     "virt_node_desires"	=> [ "vname", "desire" ],
     "virt_node_startloc"	=> [ "vname", "building" ],
     "virt_routes"		=> [ "vname", "src", "dst" ],
     "virt_vtypes"		=> [ "name" ],
     "virt_programs"		=> [ "vname", "vnode" ],
     "virt_node_attributes"	=> [ "vname", "attrkey" ],
     "virt_node_disks"		=> [ "vname", "diskname" ],
     "virt_user_environment"	=> [ "name", "value" ],
     "virt_bridges"		=> [ "vname", "vlink", "vport"],
     "nseconfigs"		=> [ "vname" ],
     "eventlist"		=> [ "idx" ],
     "event_groups"		=> [ "group_name", "agent_name" ],
     "virt_firewalls"		=> [ "fwname", "type", "style" ],
     "firewall_rules"		=> [ "fwname", "ruleno", "rule" ],
     "elabinelab_attributes"	=> [ "role", "attrkey", "ordering" ],
     "virt_tiptunnels"		=> [ "host", "vnode" ],
     "virt_parameters"          => [ "name", "value" ],
     "virt_paths"		=> [ "pathname", "segmentname"],
     "experiment_blobs"         => [ "path", "action" ],
     "virt_blobs"               => [ "vblob_id", "filename" ],
     "virt_client_service_ctl"  => [ "vnode", "service_idx", "env", "whence" ],
     "virt_client_service_hooks"=> [ "vnode", "service_idx", "env", "whence",
				     "hook_vblob_id" ],
     "virt_client_service_opts" => [ "vnode", "opt_name", "opt_value" ],
     "virt_blockstores"		=> [ "vname" ],
     "virt_blockstore_attributes" => [ "vname", "attrkey" ],
     "virt_address_allocation"  => [ "pool_id" ],
);

# 
# The experiment table is special. Only certain fields are allowed to
# be updated.
#
%experiment_fields = ("multiplex_factor"	=> 1,
		      "packing_strategy"        => 1,
		      "forcelinkdelays"		=> 1,
		      "uselinkdelays"		=> 1,
		      "usewatunnels"		=> 1,
		      "uselatestwadata"		=> 1,
		      "wa_delay_solverweight"	=> 1,
		      "wa_bw_solverweight"	=> 1,
		      "wa_plr_solverweight"	=> 1,
		      "cpu_usage"		=> 1,
		      "mem_usage"		=> 1,
		      "allowfixnode"		=> 1,
		      "encap_style"		=> 1,
		      "jail_osname"		=> 1,
		      "delay_osname"		=> 1,
		      "sync_server"		=> 1,
		      "use_ipassign"		=> 1,
		      "ipassign_args"		=> 1,
		      "usemodelnet"		=> 1,
		      "modelnet_cores"		=> 1,
		      "modelnet_edges"		=> 1,
		      "elab_in_elab"		=> 1,
		      "elabinelab_eid"		=> 1,
		      "elabinelab_cvstag"	=> 1,
		      "elabinelab_singlenet"	=> 1,
		      "security_level"		=> 1,
		      "delay_capacity"		=> 1,
		      "dpdb"			=> 1,
		      "nonfsmounts"		=> 1,
		      "nfsmounts"		=> 1,
		      "skipvlans"		=> 1);

#
# Grab the virtual topo for an experiment.
#
sub Lookup($$;$)
{
    my ($class, $experiment, $flags) = @_;
    $flags = 0
	if (!defined($flags));
    
    my $noload = ($flags & $LOOKUP_FLAGS_NOLOAD ? 1 : 0);

    return undef
	if (!ref($experiment));

    my $idx = $experiment->idx();

    # Look in cache first
    return $virtexperiments{"$idx"}
        if (exists($virtexperiments{"$idx"}));

    my $self              = {};
    $self->{'EXPERIMENT'} = $experiment;
    bless($self, $class);

    # Load all the virt tables.
    foreach my $tablename (keys(%virtual_tables)) {
	my $table = VirtExperiment::VirtTable->Create($self, $tablename);
	if (!defined($table)) {
	    carp("Could not create table object for $tablename");
	    return undef;
	}
	if (!$noload) {
	    if ($table->Load() != 0) {
		carp("Could not load rows for $table");
		return undef;
	    }
	}
	$self->{'TABLES'}->{$tablename} = $table;	
    }

    # Make a copy of the experiment DBrow, and delete all the stuff we
    # are not allowed to change through this interface.
    my $dbrow  = $experiment->dbrow();
    my $newrow = {}; 

    foreach my $key (keys(%{ $dbrow })) {
	$newrow->{$key} = $dbrow->{$key}
	    if (exists($experiment_fields{$key}));
    }
    $self->{'DBROW'} = $newrow;

    # Add to cache.
    $virtexperiments{"$idx"} = $self;

    return $self;
}
# accessors
sub experiment($)       { return $_[0]->{'EXPERIMENT'}; }
sub dbrow($)            { return $_[0]->{'DBROW'}; }
sub table($$)		{ return $_[0]->{'TABLES'}->{$_[1]}; }
sub pid($)		{ return $_[0]->experiment()->pid(); }
sub pid_idx($)		{ return $_[0]->experiment()->pid_idx(); }
sub eid($)		{ return $_[0]->experiment()->eid(); }
sub exptidx($)		{ return $_[0]->experiment()->idx(); }

# To avoid wrtting out all the methods.
sub AUTOLOAD {
    my $self = shift;
    my $type = ref($self) or croak "$self is not an object";

    my $name = $AUTOLOAD;
    $name =~ s/.*://;   # strip fully-qualified portion

    unless (exists($experiment_fields{$name})) {
	carp("No such slot '$name' field in class $type");
	return undef;
    }
    if (@_) {
	return $self->{'DBROW'}->{$name} = shift;
    }
    else {
	return $self->{'DBROW'}->{$name};
    }
}

# Break circular reference someplace to avoid exit errors.
sub DESTROY {
    my $self = shift;

    $self->{'DBROW'}      = undef;
    $self->{'EXPERIMENT'} = undef;
}

#
# Create a new experiment virtual topology. This means loading the
# experiment, but not any of the virt tables. We never create a new
# "experiment" via this path, just a new virt topology for an existing
# experiment.
#
sub CreateNew($$)
{
    my ($class, $experiment) = @_;

    return VirtExperiment->Lookup($experiment, $LOOKUP_FLAGS_NOLOAD);
}

#
# Add a new empty table row. Caller must populate it.
#
sub NewTableRow($$$)
{
    my ($self, $tablename, $argref) = @_;
    
    return undef
	if (! ref($self));
    return undef
	if (!exists($virtual_tables{$tablename}));

    my $table = $self->{'TABLES'}->{$tablename};
    my $row   = $table->NewRow($argref);
    if (!defined($row)) {
	carp("Could not create new table row in $self");
	return undef;
    }
    return $row;
}

#
# Store the experiment back to the DB. Includes the experiment table itself.
#
sub Store($;$)
{
    my ($self, $flags) = @_;
    $flags = 0
	if (!defined($flags));
    
    my $debug    = ($flags & $STORE_FLAGS_DEBUG ? 1 : 0);
    my $impotent = ($flags & $STORE_FLAGS_IMPOTENT ? 1 : 0);
    my $simparse = ($flags & $STORE_FLAGS_SIMPARSE ? 1 : 0);
    my $exptidx  = $self->exptidx();
    my $pid      = $self->pid();
    my $eid      = $self->eid();

    # If these are the results of parsing the nse specifications,
    # we do not expect updates to the experiments table.
    goto skip
	if ($simparse);

    #
    # Delete anything we are not allowed to set via this interface.
    #
    my $dbrow = $self->dbrow();
    
    foreach my $key (keys(%{ $dbrow })) {
	delete($dbrow->{$key})
	    if (! exists($experiment_fields{$key}));
    }

    #
    # Get the default values for the required fields.
    #
    my $describe_result =
	DBQueryWarn("describe experiments");
    return -1
	if (!defined($describe_result) || !$describe_result->numrows);

    #
    # Insert the default values for slots that we do not have
    # so that we can set them properly in the DB query.
    #
    while (my $rowref = $describe_result->fetchrow_hashref()) {
	my $slot  = $rowref->{"Field"};
	my $value = $rowref->{"Default"};

	if (exists($experiment_fields{$slot}) &&
	    ! exists($dbrow->{$slot})) {
	    $dbrow->{$slot} = (defined($value) ? $value : "NULL");
	}
    }

    my @setlist  = ();
    
    foreach my $key (keys(%{ $dbrow })) {
	my $val = $dbrow->{$key};

	# Always skip these; they come from the experiment object. Prevents
	# users from messing up the DB with a bogus XML file.
	next
	    if ($key eq "pid" ||$key eq "eid" || $key eq "idx");

	if (!defined($val) ||
	    $val eq "NULL" || $val eq "__NULL__" || $val eq "") {
	    push(@setlist, "$key=NULL");
	}
	else {
	    # Sanity check the fields.
	    if (TBcheck_dbslot($val, "experiments", $key,
			       TBDB_CHECKDBSLOT_WARN()|
			       TBDB_CHECKDBSLOT_ERROR())) {
		$val = DBQuoteSpecial($val);
		    
		push(@setlist, "$key=$val");
	    }
	    else {
		carp("Illegal characters in table data: experiments:".
		     "$key - $val");
		return -1;
	    }
	}	    
    }
    my $query =
	"update experiments ".
	"set " . join(",", @setlist) . " where idx='$exptidx'";

    print "$query\n"
	if ($debug);

    return -1
	if (!$impotent && !DBQueryWarn($query));
  skip:

    #
    # And then the virt table rows. First need to delete them all.
    #
    if (!$impotent) {
	#
	# Need this below:
	#
	my $query_result =
	    DBQueryWarn("select idx from event_objecttypes where type='NSE'");
	return -1
	    if (!defined($query_result) || !$query_result->numrows);
	my ($nse_objtype) = $query_result->fetchrow_array();
	
	foreach my $tablename (keys(%virtual_tables)) {
	    if ($simparse) {
		#
		# The nseconfigs table is special. During a simparse,
		# we need delete all rows for the experiment except
		# the one with the vname 'fullsim'. This row is
		# essentially virtual info and does not change across
		# swapins where as the other rows depend on the
		# mapping
		#
		if ($tablename eq "nseconfigs") {
		    DBQueryWarn("delete from $tablename ". 
				"where eid='$eid' and pid='$pid' and ".
				"vname!='fullsim'")
			or return -1;
		}
		elsif ($tablename eq "eventlist" ||
		       $tablename eq "virt_agents") {
		    #
		    # Both eventlist and virt_agents need to be
		    # cleared for NSE event objecttype since entries
		    # in this table depend on the particular mapping
		    #
		    DBQueryWarn("delete from $tablename ". 
				"where pid='$pid' and eid='$eid' and ".
				"objecttype='$nse_objtype'")
			or return -1;
		} 
	    }
	    else {
		#
		# In normal mode all rows deleted. During the nse parse,
		# leave the other tables alone.
		#
		DBQueryWarn("delete from $tablename ".
			    "where eid='$eid' and pid='$pid'")
		    or return -1;
	    }
	}
    }

    foreach my $tablename (keys(%virtual_tables)) {
	if (exists($self->{'TABLES'}->{$tablename})) {
	    my $table = $self->{'TABLES'}->{$tablename};
	    if ($table->Store($flags) != 0) {
		carp("Could not store table $table");
		return -1;
	    }
	}
    }
    return 0;
}

#
# Find a particular row in a table.
#
sub Find($$@)
{
    my $self = shift();
    my $tablename = shift();
    my @args = @_;

    if (!exists($self->{'TABLES'}->{$tablename})) {
	warn("Find: unknown table search: $tablename");
	return undef;
    }
    my $table = $self->{'TABLES'}->{$tablename};
    return $table->Find(@args);
}

#
# Return a table.
#
sub Table($$)
{
    my $self = shift();
    my $tablename = shift();

    if (!exists($self->{'TABLES'}->{$tablename})) {
	warn("Table: unknown table: $tablename");
	return undef;
    }
    return $self->{'TABLES'}->{$tablename};
}

#
# Flush from our little cache, as for the expire daemon.
#
sub Flush($)
{
    my ($self) = @_;

    delete($virtexperiments{$self->exptidx()});
}

#
# Dump the contents of virt tables.
#
sub Dump($)
{
    my ($self) = @_;

    my $dbrow = $self->dbrow();

    print $self . "\n";
    foreach my $key (keys(%{ $dbrow })) {
	my $val = $dbrow->{$key};
	$val = "NULL"
	    if (!defined($val));
	    
	print "  $key : $val\n";
    }

    foreach my $tablename (keys(%virtual_tables)) {
	if (exists($self->{'TABLES'}->{$tablename})) {
	    my $table = $self->{'TABLES'}->{$tablename};
	    $table->Dump();
	}
    }
}

#
# Refresh a class instance by reloading from the DB.
#
sub Refresh($)
{
    my ($self) = @_;

    return -1
	if (! ref($self));

    return -1;
}

#
# Stringify for output.
#
sub Stringify($)
{
    my ($self) = @_;
    
    my $pid   = $self->pid();
    my $eid   = $self->eid();
    my $idx   = $self->exptidx();

    return "[VirtExperiment: $pid/$eid/$idx]";
}

############################################################################
#
# VirtTable wraps up a bunch of table rows.
#
package VirtExperiment::VirtTable;
use Carp;
use English;
use overload ('""' => 'Stringify');
use libdb;
use emutil;
use VirtExperiment;

my %dbslotnames = ();

#
# A table 
#
sub Create($$$)
{
    my ($class, $virtexperiment, $tablename) = @_;

    $class = ref($class) || $class;
    my $experiment = $virtexperiment->experiment();
    my $slotnames;

    #
    # See if we have loaded the DB defs for this table.
    #
    my $varname = $tablename . "_dbdefs";
    if (defined($dbslotnames{$varname})) {
	$slotnames = $dbslotnames{$varname};
    }
    else {
	$slotnames = {};

	my $describe_result =
	    DBQueryWarn("describe $tablename");

	return -1
	    if (!defined($describe_result) || !$describe_result->numrows);

	#
	# Record the default values for slots.
	#
	while (my $rowref = $describe_result->fetchrow_hashref()) {
	    my $slot  = $rowref->{"Field"};
	    my $value = $rowref->{"Default"};

	    $slotnames->{$slot} = $value;
	}
	$dbslotnames{$varname} = $slotnames;
    }
    
    my $self = {};
    $self->{'TABLENAME'}  = $tablename;
    $self->{'EXPERIMENT'} = $experiment;
    $self->{'VIRTEXPT'}   = $virtexperiment;
    $self->{'SLOTNAMES'}  = $slotnames;
    $self->{'TABLEHASH'}  = {};
    $self->{'TABLELIST'}  = [];
    $self->{'COUNTER'}    = 1;
    bless($self, $class);

    return $self;
}
sub experiment($)       { return $_[0]->{'EXPERIMENT'}; }
sub virtexperiment($)   { return $_[0]->{'VIRTEXPT'}; }
sub tablename($)        { return $_[0]->{'TABLENAME'}; }
sub slotnames($)        { return $_[0]->{'SLOTNAMES'}; }
sub tablelist($)        { return $_[0]->{'TABLELIST'}; }
sub tablehash($)        { return $_[0]->{'TABLEHASH'}; }

# Break circular reference someplace to avoid exit errors.
sub DESTROY {
    my $self = shift;

    $self->{'TABLENAME'}  = undef;
    $self->{'EXPERIMENT'} = undef;
    $self->{'VIRTEXPT'}   = undef;
    $self->{'SLOTNAMES'}  = undef;
    $self->{'TABLEHASH'}  = undef;
    $self->{'TABLELIST'}  = undef;
    $self->{'COUNTER'}    = undef;
}

#
# Lookup the rows for a table from the DB.
#
sub Load($)
{
    my ($self) = @_;

    return -1
	if (! ref($self));

    my $experiment = $self->experiment();
    my $exptidx    = $experiment->idx();
    my $tablename  = $self->tablename();
    
    return -1
	if (!exists($VirtExperiment::virtual_tables{$tablename}));

    my $query_result =
	DBQueryWarn("select * from $tablename where exptidx=$exptidx");

    return -1
	if (!defined($query_result));
    return 0
	if (!$query_result->numrows);

    while (my $row = $query_result->fetchrow_hashref()) {
	my $tablerow = $self->NewRow($row);
	if (!defined($tablerow)) {
	    return -1;
	}
    }
    return 0;
}

#
# Create a new table row.
#
sub NewRow($$)
{
    my ($self, $argref) = @_;
    
    my $tablename  = $self->tablename();
    my $class = "VirtExperiment::VirtTableRow::$tablename";
    my $obj   = $class->Create($self);

    #
    # These are the required keys, they must be defined for the new row
    # to make any sense. Other slots can be filled in later of course.
    #
    my @pkeys = @{$VirtExperiment::virtual_tables{$tablename}};
    my @pvals = ();
    foreach my $key (@pkeys) {
	if (!exists($argref->{$key})) {
	    if ($tablename eq "eventlist" && $key eq "idx") {
		$argref->{$key} = $self->{'COUNTER'}++;
	    }
	    else {
		carp("Missing table key $key for new table in $tablename");
		return undef;
	    }
	}
	push(@pvals, $argref->{$key});
    }
    # This is the full key. Make sure it does not already exist.
    my $akey = join(":", @pvals);
    if (exists($self->{'TABLEHASH'}->{$akey})) {
	carp("Already have entry for '$akey' in $self");
	return undef;
    }
    foreach my $key (keys(%{$argref})) {
	$obj->$key($argref->{$key});
    }

    # Add to list of rows for this table.
    push(@{ $self->{'TABLELIST'} }, $obj);
    # And to the hash array using the pkey.
    $self->{'TABLEHASH'}->{$akey} = $obj;

    return $obj;
}

#
# Dump out rows for table.
#
sub Dump($)
{
    my ($self) = @_;

    my @rows = @{ $self->{'TABLELIST'} };

    return
	if (!@rows);
	    
    foreach my $rowref (@rows) {
	$rowref->Dump();
    }
}

#
# Store rows for table.
#
sub Store($$)
{
    my ($self,$flags) = @_;

    my @rows = @{ $self->{'TABLELIST'} };

    return 0
	if (!@rows);
	    
    foreach my $rowref (@rows) {
	$rowref->Store($flags) == 0
	    or return -1;
    }
    return 0;
}

#
# Return list of rows.
#
sub Rows($)
{
    my ($self) = @_;
    my @rows   = @{ $self->{'TABLELIST'} };

    return @rows;
}

#
# Find a particular row in a table.
#
sub Find($@)
{
    my $self = shift();
    my @args = @_;
    my $tablename = $self->tablename();

    # No members.
    return undef
	if (! @{ $self->{'TABLELIST'} });

    # Get the slotnames that determine the lookup from the table above.
    if (!exists($VirtExperiment::virtual_tables{$tablename})) {
	warn("Find: No entry in virtual_tables for $tablename");
	return undef;
    }
    my @pkeys = @{ $VirtExperiment::virtual_tables{$tablename} };
    if (scalar(@pkeys) != scalar(@args)) {
	warn("Find: Wrong number of arguments for lookup in $self");
	return undef;
    }
    # This is the full key. 
    my $akey = join(":", @args);

    return $self->{'TABLEHASH'}->{$akey};
}

#
# Delete a row in a table. Do not call this. Utility for below.
#
sub _deletetablerow($$)
{
    my ($self, $row) = @_;

    my $tablename = $self->tablename();
    my @newrows   = ();

    my @rows = @{ $self->{'TABLELIST'} };
    foreach my $rowref (@rows) {
	push(@newrows, $rowref)
	    if (! ($rowref->SameRow($row)));
    }
    $self->{'TABLELIST'} = \@newrows;

    my @keys = keys(%{ $self->{'TABLEHASH'} });
    foreach my $key (@keys) {
	my $ref = $self->{'TABLEHASH'}->{$key};
	
	if ($ref->SameRow($row)) {
	    delete($self->{'TABLEHASH'}->{$key});
	    last;
	}
    }
    return 0;
}

#
# Stringify for output.
#
sub Stringify($)
{
    my ($self) = @_;

    my $table = $self->tablename();
    my $pid   = ($self->experiment() ? $self->experiment()->pid() : "?");
    my $eid   = ($self->experiment() ? $self->experiment()->eid() : "?");
    my $idx   = ($self->experiment() ? $self->experiment()->idx() : "?");

    return "[$table: $pid/$eid/$idx]";
}


############################################################################
#
# VirtTableRow is a superclass to avoid a bunch of typing. It wraps up DB
# table rows with methods, but without having to type all the stuff out
# for each virt table.
#
package VirtExperiment::VirtTableRow;
use Carp;
use English;
use overload ('""' => 'Stringify');
use vars qw($AUTOLOAD);
use libdb;
use emutil;
use VirtExperiment;

sub AUTOLOAD {
    my $self = shift;
    my $type = ref($self) or croak "$self is not an object";

    my $name = $AUTOLOAD;
    $name =~ s/.*://;   # strip fully-qualified portion

    my $row = $self->tablerow();

    unless (exists($self->{'SLOTNAMES'}->{$name})) {
	print STDERR "No such slot '$name' field in class $type\n";
	return undef;
    }
    if (@_) {
	return $self->{'TABLEROW'}->{$name} = shift;
    }
    else {
	return $self->{'TABLEROW'}->{$name};
    }
}

# Break circular reference someplace to avoid exit errors.
sub DESTROY {
    my $self = shift;

    $self->{'TABLEROW'}   = undef;
    $self->{'TABLENAME'}  = undef;
    $self->{'EXPERIMENT'} = undef;
    $self->{'TABLE'}      = undef;
    $self->{'SLOTNAMES'}  = undef;
}

sub SameRow($$)
{
    my ($this, $that) = @_;

    return $this->tablerow() == $that->tablerow();
}

#
# A table row. 
#
sub Create($$$)
{
    my ($class, $table, $tablerow) = @_;

    $class = ref($class) || $class;
    my $experiment = $table->experiment();
    my $tablename;
    my $slotnames;

    # The intent is to allow contruction of a virtual topo from scratch.
    $tablerow = {} if (!defined($tablerow));

    if ($class =~ /^VirtExperiment::VirtTableRow::(.*)$/) {
	$tablename = $1;
    }
    else {
	croak("$class is not in correct format");
    }

    #
    # See if we have loaded the DB defs for this table.
    #
    my $varname = $tablename . "_dbdefs";
    if (defined($dbslotnames{$varname})) {
	$slotnames = $dbslotnames{$varname};
    }
    else {
	$slotnames = {};

	my $describe_result =
	    DBQueryWarn("describe $tablename");

	return -1
	    if (!defined($describe_result) || !$describe_result->numrows);

	#
	# Record the default values for slots.
	#
	while (my $rowref = $describe_result->fetchrow_hashref()) {
	    my $slot  = $rowref->{"Field"};
	    my $value = $rowref->{"Default"};

	    $slotnames->{$slot} = $value;
	}
	$dbslotnames{$varname} = $slotnames;
    }
    
    my $self = {};
    $self->{'TABLEROW'}   = $tablerow;
    $self->{'TABLENAME'}  = $tablename;
    $self->{'EXPERIMENT'} = $experiment;
    $self->{'TABLE'}      = $table;
    $self->{'SLOTNAMES'}  = $slotnames;
    bless($self, $class);

    return $self;
}
sub experiment($)       { return $_[0]->{'EXPERIMENT'}; }
sub table($)            { return $_[0]->{'TABLE'}; }
sub tablename($)        { return $_[0]->{'TABLENAME'}; }
sub tablerow($)         { return $_[0]->{'TABLEROW'}; }
sub slotnames($)        { return $_[0]->{'SLOTNAMES'}; }

#
# Store a single table row to the DB.
#
sub Store($;$)
{
    my ($self, $flags) = @_;
    $flags = 0
	if (!defined($flags));
    
    my $debug    = ($flags & $VirtExperiment::STORE_FLAGS_DEBUG ? 1 : 0);
    my $impotent = ($flags & $VirtExperiment::STORE_FLAGS_IMPOTENT ? 1 : 0);
    my $simparse = ($flags & $VirtExperiment::STORE_FLAGS_SIMPARSE ? 1 : 0);
    my $replace  = ($flags & $VirtExperiment::STORE_FLAGS_REPLACE ? 1 : 0);
    my $tablename= $self->tablename();
    my $row      = $self->tablerow();
    my $pid      = $self->experiment()->pid();
    my $eid      = $self->experiment()->eid();
    my $exptidx  = $self->experiment()->idx();

    # These are the required keys, they must be defined.
    my %pkeys   =
	map { $_ => $_ } @{$VirtExperiment::virtual_tables{$tablename}};
    
    my @fields  = ("exptidx", "pid", "eid");
    my @values  = ("'$exptidx'", "'$pid'", "'$eid'");

    foreach my $key (keys(%{ $row })) {
	my $val = $row->{$key};

	# Always skip these; they come from the experiment object. Prevents
	# users from messing up the DB with a bogus XML file.
	next
	    if ($key eq "pid" ||$key eq "eid" || $key eq "exptidx");
	
	if ($key eq "idx") {
	    # This test for eventlist.
	    if ($tablename eq "eventlist") {
		push(@values, "NULL");
	    }
	    elsif ($val =~ /^\d*$/) {
		push(@values, DBQuoteSpecial($val));
	    }
	    else {
		carp("Illegal characters in table data: ".
		     "$tablename:$key - $val\n");
		return -1;
	    }
	}
	elsif (!defined($val) || $val eq "NULL") {
	    push(@values, "NULL");
	}
	elsif ($val eq "") {
	    push(@values, "''");
	}
	else {
	    # Sanity check the fields.
	    if (TBcheck_dbslot($val, $tablename, $key,
			       TBDB_CHECKDBSLOT_WARN()|
			       TBDB_CHECKDBSLOT_ERROR())) {
		push(@values, DBQuoteSpecial($val));
	    }
	    else {
		carp("Illegal characters in table data for $tablename:\n".
		     "    $key - $val: ". TBFieldErrorString() . "\n");
		return -1;
	    }
	}
	# If a key remove from the list; we got it.
	delete($pkeys{$key})
	    if (exists($pkeys{$key}));
	push(@fields, $key);
    }
    if (keys(%pkeys)) {
	carp("Missing primary keys in $self");
	return -1;
    }
    my $query;
    if ($simparse || $replace) {
	#
	# If we are called after an nseparse, we need to use replace
	# coz some of the tables such as virt_agents and eventlist are
	# not truly virtual tables. That is coz they contain the vnode
	# field which is the same as the vname field in the reserved
	# table. For simulated nodes, the mapping may change across
	# swapins and the event may have to be delivered to a
	# different simhost
	#
	$query =
	    "replace into $tablename (" . join(",", @fields) . ") ".
	    "values (" . join(",", @values) . ") ";
    }
    else {
	$query =
	    "insert into $tablename (" . join(",", @fields) . ") ".
	    "values (" . join(",", @values) . ") ";
    }
  
    print "$query\n"
	if ($debug);

    return -1
	if (!$impotent && !DBQueryWarn($query));

    return 0;
}

#
# Delete a row.
#
sub Delete($;$)
{
    my ($self, $flags) = @_;
    $flags = 0
	if (!defined($flags));
    
    my $debug    = ($flags & $VirtExperiment::STORE_FLAGS_DEBUG ? 1 : 0);
    my $impotent = ($flags & $VirtExperiment::STORE_FLAGS_IMPOTENT ? 1 : 0);
    my $exptidx  = $self->experiment()->idx();
    my $table    = $self->table();
    my $tablename= $self->tablename();
    my $row      = $self->tablerow();

    # These are the keys for the table.
    my %pkeys   =
	map { $_ => $_ } @{$VirtExperiment::virtual_tables{$tablename}};

    # Gets values for the keys, to use in the query below.
    foreach my $key (keys(%pkeys)) {
	$pkeys{$key} = $row->{$key};
    }

    my $query = "delete from $tablename where exptidx=$exptidx and ".
	join(" and ", map("$_='" . $pkeys{$_} . "'", keys(%pkeys)));
    
    print "$query\n"
	if ($debug);

    if (!$impotent) {
	return -1
	    if (!DBQueryWarn($query));

	$table->_deletetablerow($self);
    }
    return 0;
}

#
# Dump the contents of virt tables.
#
sub Dump($)
{
    my ($self) = @_;

    my $dbrow = $self->tablerow();

    print $self . "\n";
    foreach my $key (keys(%{ $dbrow })) {
	my $val = $dbrow->{$key};
	$val = "NULL"
	    if (!defined($val));
	    
	print "  $key : $val\n";
    }
}

#
# Stringify for output.
#
sub Stringify($)
{
    my ($self) = @_;

    my $table = $self->tablename();
    my $row   = $self->tablerow();
    my $pid   = ($self->experiment() ? $self->experiment()->pid() : "?");
    my $eid   = ($self->experiment() ? $self->experiment()->eid() : "?");
    my $idx   = ($self->experiment() ? $self->experiment()->idx() : "?");

    my @keys   = @{ $VirtExperiment::virtual_tables{$table} };
    my @values = map { $row->{$_} } @keys;
    @values    = map { (defined($_) ? $_ : "NULL") } @values;
    my $keystr = join(",", @values);

    return "[$table: $pid/$eid/$idx $keystr]";
}

############################################################################
# And now subclasses for each virtual table.
#
package VirtExperiment::VirtTableRow::virt_nodes;
use vars qw(@ISA);
@ISA = "VirtExperiment::VirtTableRow";
use VirtExperiment;

package VirtExperiment::VirtTableRow::virt_lans;
use vars qw(@ISA);
@ISA = "VirtExperiment::VirtTableRow";
use VirtExperiment;

package VirtExperiment::VirtTableRow::virt_lan_lans;
use vars qw(@ISA);
@ISA = "VirtExperiment::VirtTableRow";
use VirtExperiment;

package VirtExperiment::VirtTableRow::virt_lan_settings;
use vars qw(@ISA);
@ISA = "VirtExperiment::VirtTableRow";
use VirtExperiment;

package VirtExperiment::VirtTableRow::virt_lan_member_settings;
use vars qw(@ISA);
@ISA = "VirtExperiment::VirtTableRow";
use VirtExperiment;

package VirtExperiment::VirtTableRow::virt_trafgens;
use vars qw(@ISA);
@ISA = "VirtExperiment::VirtTableRow";
use VirtExperiment;

package VirtExperiment::VirtTableRow::virt_agents;
use vars qw(@ISA);
@ISA = "VirtExperiment::VirtTableRow";
use VirtExperiment;

package VirtExperiment::VirtTableRow::virt_node_desires;
use vars qw(@ISA);
@ISA = "VirtExperiment::VirtTableRow";
use VirtExperiment;

package VirtExperiment::VirtTableRow::virt_node_startloc;
use vars qw(@ISA);
@ISA = "VirtExperiment::VirtTableRow";
use VirtExperiment;

package VirtExperiment::VirtTableRow::virt_routes;
use vars qw(@ISA);
@ISA = "VirtExperiment::VirtTableRow";
use VirtExperiment;

package VirtExperiment::VirtTableRow::virt_vtypes;
use vars qw(@ISA);
@ISA = "VirtExperiment::VirtTableRow";
use VirtExperiment;

package VirtExperiment::VirtTableRow::virt_programs;
use vars qw(@ISA);
@ISA = "VirtExperiment::VirtTableRow";
use VirtExperiment;

package VirtExperiment::VirtTableRow::virt_node_attributes;
use vars qw(@ISA);
@ISA = "VirtExperiment::VirtTableRow";
use VirtExperiment;

package VirtExperiment::VirtTableRow::virt_node_disks;
use vars qw(@ISA);
@ISA = "VirtExperiment::VirtTableRow";
use VirtExperiment;

package VirtExperiment::VirtTableRow::virt_user_environment;
use vars qw(@ISA);
@ISA = "VirtExperiment::VirtTableRow";
use VirtExperiment;

package VirtExperiment::VirtTableRow::nseconfigs;
use vars qw(@ISA);
@ISA = "VirtExperiment::VirtTableRow";
use VirtExperiment;

package VirtExperiment::VirtTableRow::eventlist;
use vars qw(@ISA);
@ISA = "VirtExperiment::VirtTableRow";
use VirtExperiment;

package VirtExperiment::VirtTableRow::event_groups;
use vars qw(@ISA);
@ISA = "VirtExperiment::VirtTableRow";
use VirtExperiment;

package VirtExperiment::VirtTableRow::virt_firewalls;
use vars qw(@ISA);
@ISA = "VirtExperiment::VirtTableRow";
use VirtExperiment;

package VirtExperiment::VirtTableRow::firewall_rules;
use vars qw(@ISA);
@ISA = "VirtExperiment::VirtTableRow";
use VirtExperiment;

package VirtExperiment::VirtTableRow::virt_tiptunnels;
use vars qw(@ISA);
@ISA = "VirtExperiment::VirtTableRow";
use VirtExperiment;

package VirtExperiment::VirtTableRow::virt_parameters;
use vars qw(@ISA);
@ISA = "VirtExperiment::VirtTableRow";
use VirtExperiment;

package VirtExperiment::VirtTableRow::elabinelab_attributes;
use vars qw(@ISA);
@ISA = "VirtExperiment::VirtTableRow";
use VirtExperiment;

package VirtExperiment::VirtTableRow::virt_paths;
use vars qw(@ISA);
@ISA = "VirtExperiment::VirtTableRow";
use VirtExperiment;

package VirtExperiment::VirtTableRow::experiment_blobs;
use vars qw(@ISA);
@ISA = "VirtExperiment::VirtTableRow";
use VirtExperiment;
use VirtExperiment;

package VirtExperiment::VirtTableRow::virt_blobs;
use vars qw(@ISA);
@ISA = "VirtExperiment::VirtTableRow";
use VirtExperiment;

package VirtExperiment::VirtTableRow::virt_client_service_ctl;
use vars qw(@ISA);
@ISA = "VirtExperiment::VirtTableRow";
use VirtExperiment;

package VirtExperiment::VirtTableRow::virt_client_service_hooks;
use vars qw(@ISA);
@ISA = "VirtExperiment::VirtTableRow";
use VirtExperiment;

package VirtExperiment::VirtTableRow::virt_client_service_opts;
use vars qw(@ISA);
@ISA = "VirtExperiment::VirtTableRow";
use VirtExperiment;

package VirtExperiment::VirtTableRow::virt_bridges;
use vars qw(@ISA);
@ISA = "VirtExperiment::VirtTableRow";
use VirtExperiment;

package VirtExperiment::VirtTableRow::virt_blockstores;
use vars qw(@ISA);
@ISA = "VirtExperiment::VirtTableRow";
use VirtExperiment;

package VirtExperiment::VirtTableRow::virt_blockstore_attributes;
use vars qw(@ISA);
@ISA = "VirtExperiment::VirtTableRow";
use VirtExperiment;

package VirtExperiment::VirtTableRow::virt_address_allocation;
use vars qw(@ISA);
@ISA = "VirtExperiment::VirtTableRow";
use VirtExperiment;

# _Always_ make sure that this 1 is at the end of the file...
1;
