#!/usr/bin/perl -wT
#
# Copyright (c) 2012-2021 University of Utah and the Flux Group.
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
package Blockstore;

use strict;
use Carp;
use Exporter;
use vars qw(@ISA @EXPORT $AUTOLOAD);

@ISA = qw(Exporter);
@EXPORT = qw ( );

use libdb;
use libtestbed;
use English;
use Data::Dumper;
use overload ('""' => 'Stringify');

my @BLOCKSTORE_ROLES = ("element","compound","partition");
my $debug	= 0;

#
# Lookup a (physical) storage object type and create a class instance to 
# return.
#
sub Lookup($$$)
{
    my ($class, $nodeid, $bsid) = @_;

    return undef
	if (!($nodeid && $bsid) ||
	    !($nodeid =~ /^[-\w]+$/ && $bsid =~ /^[-\w]+$/));

    my $query_result =
	DBQueryWarn("select * from blockstores ".
		    "where node_id='$nodeid' and bs_id='$bsid'");

    return undef
	if (!$query_result || !$query_result->numrows);

    my $self         = {};
    $self->{"HASH"}  = {};
    $self->{"DBROW"} = $query_result->fetchrow_hashref();

    bless($self, $class);
    return $self;
}

sub LookupByLease($$)
{
    my ($class, $leaseidx) = @_;

    return undef
	if (!($leaseidx && $leaseidx =~ /^\d+$/));

    my $query_result =
	DBQueryWarn("select * from blockstores where lease_idx='$leaseidx'");

    return undef
	if (!$query_result || !$query_result->numrows);

    my $self         = {};
    $self->{"HASH"}  = {};
    $self->{"DBROW"} = $query_result->fetchrow_hashref();

    bless($self, $class);
    return $self;
}

sub LookupByIndex($$)
{
    my ($class, $bsidx) = @_;

    return undef
	if (!defined($bsidx) || $bsidx !~ /^(\d+)$/ || $1 == 0);

    my $query_result =
	DBQueryWarn("select * from blockstores where bsidx=$bsidx");

    return undef
	if (!$query_result || !$query_result->numrows);

    my $self         = {};
    $self->{"HASH"}  = {};
    $self->{"DBROW"} = $query_result->fetchrow_hashref();

    bless($self, $class);
    return $self;
}

#
# Return a list of blockstore objects, one for each blockstores on this node.
#
sub LookupAll($$)
{
    my ($class, $nodeid) = @_;
    my @result = ();

    return undef
	if (!defined($nodeid));

    my $query_result =
	DBQueryWarn("select bsidx from blockstores where node_id='$nodeid'");

    return undef
	if (!$query_result);

    while (my ($bsidx) = $query_result->fetchrow_array()) {
	push(@result, LookupByIndex($class, $bsidx));
    }

    return @result;
}

# To avoid writing out all the methods.
AUTOLOAD {
    my $self  = $_[0];
    my $name  = $AUTOLOAD;
    $name =~ s/.*://;   # strip fully-qualified portion

    # A DB row proxy method call.
    if (exists($self->{'DBROW'}->{$name})) {
	return $self->{'DBROW'}->{$name};
    }

    # Local storage slot.
    if ($name =~ /^_.*$/) {
	if (scalar(@_) == 2) {
	    return $self->{'HASH'}->{$name} = $_[1];
	}
	elsif (exists($self->{'HASH'}->{$name})) {
	    return $self->{'HASH'}->{$name};
	}
    }
    carp("No such slot '$name' in $self");
    return undef;
}

# Break circular reference someplace to avoid exit errors.
sub DESTROY {
    my $self = shift;

    $self->{"DBROW"}    = undef;
    $self->{"HASH"}     = undef;
}

#
# Create a new blockstore.
#
sub Create($$;$) {
    my ($class, $argref, $attrs) = @_;

    my ($node_id, $bs_id, $lease_idx, $type, $role, $size, $exported);

    return undef
	if (!ref($argref));

    $node_id   = $argref->{'node_id'};
    $bs_id     = $argref->{'bs_id'};
    $lease_idx = $argref->{'lease_idx'};
    $type      = $argref->{'type'};
    $role      = $argref->{'role'};
    $size      = $argref->{'total_size'};
    $exported  = $argref->{'exported'};

    $lease_idx = 0 if (!defined($lease_idx));
    $size      = 0 if (!defined($size));
    $exported  = 0 if (!defined($exported));
    
    if (!($node_id && $bs_id && $type && $role)) {
	print STDERR "Blockstore->Create: Missing required parameters in argref\n";
	return undef;
    }

    # Sanity checks for incoming arguments
    if (!TBcheck_dbslot($node_id, "blockstores", "node_id")) {
	print STDERR "Blockstore->Create: Bad data for node_id: ".
	    TBFieldErrorString() ."\n";
	return undef;
    }
    if (!TBcheck_dbslot($bs_id, "blockstores", "bs_id")) {
	print STDERR "Blockstore->Create: Bad data for bs_id: ".
	    TBFieldErrorString() ."\n";
	return undef;
    }
    if ($lease_idx != 0) {
	my $lease_obj = Lease->Lookup($lease_idx);
	if (!defined($lease_obj)) {
	    print STDERR "Blockstore->Create: No lease for idx: $lease_idx\n";
	    return undef;
	}
    }
    if (!TBcheck_dbslot($bs_id, "blockstores", "type")) {
	print STDERR "Blockstore->Create: Bad data for type: ".
	    TBFieldErrorString() ."\n";
	return undef;
    }
    # If blockstore types ever grow to be many and complex, then this info will
    # have to come from a DB table instead of a static list in this module.
    if (!grep {/^$role$/} @BLOCKSTORE_ROLES) {
	print STDERR "Blockstore->Create: Unknown blockstore role: $role\n";
	return undef;
    }
    if ($exported > 1) {
	$exported = 1;
    }

    #
    # Get a unique blockstore index.
    #
    # XXX if a blockstore index is specified by the caller, they had better
    # know what they are doing; i.e., no conflicts and they will update
    # next_bsidx as necessary!
    #
    my $bs_idx = $argref->{'bsidx'};
    if ($bs_idx) {
	if ($bs_idx =~ /^(\d+)$/ && $1 > 0) {
	    $bs_idx = $1;
	} else {
	    print STDERR "Blockstore->Create: Bad data for bsidx\n";
	    return undef;
	}
    } else {
	$bs_idx = TBGetUniqueIndex('next_bsidx');
    }

    # Slam this stuff into the DB.
    DBQueryWarn("insert into blockstores set ".
		"bsidx=$bs_idx,".
		"node_id='$node_id',".
		"bs_id='$bs_id',".
		"lease_idx='$lease_idx',".
		"type='$type',".
		"role='$role',".
		"total_size='$size',".
		"exported='$exported',".
		"inception=NOW()")
	or return undef;

    # Now add attributes, if passed in.
    if ($attrs) {
	while (my ($key,$valp) = each %{$attrs}) {
	    my ($val, $type);
	    if (ref($valp) eq "HASH") {
		$val  = DBQuoteSpecial($valp->{'value'});
		$type = $valp->{'type'} || "string";
	    } else {
		$val  = DBQuoteSpecial($valp);
		$type = "string";
	    }
	    DBQueryWarn("insert into blockstore_attributes set ".
			"bsidx=$bs_idx,".
			"attrkey='$key',".
			"attrvalue=$val,".
			"attrtype='$type'")
		or return undef;
	}
    }

    return Lookup($class, $node_id, $bs_id);
}

#
# Delete an existing blockstore.
# XXX this only clears out blockstores and blockstores_attributes right now!
#
sub Delete($) {
    my ($self) = @_;

    return -1
	if (!ref($self));

    my $bsidx = $self->bsidx();

    #
    # If this is a partition, we need to return our capacity to our
    # parent blockstore.
    # XXX maybe partitions should be a seperate blockstore object type?
    #
    if ($self->role() eq "partition") {
	my $query_result =
	    DBQueryWarn("select remaining_capacity from blockstore_state ".
			"where bsidx='$bsidx'");
	if ($query_result && $query_result->numrows) {
	    my ($psize) = $query_result->fetchrow_array();
	    if ($psize > 0) {
		my $qr =
		    DBQueryWarn("select aggidx from blockstore_trees ".
				"where bsidx='$bsidx'");
		if (!$qr || $qr->numrows != 1) {
		    print STDERR
			"Inconsistent state in blockstore_trees for ".
			"partition blockstore idx=$bsidx\n";
		    return -1;
		}
		my ($aggidx) = $qr->fetchrow_array();
		if (!DBQueryWarn("update blockstore_state as f,".
				 "       blockstore_state as t ".
				 "set t.remaining_capacity=t.remaining_capacity+$psize,".
				 "    f.remaining_capacity='0' ".
				 "where t.bsidx=$aggidx and f.bsidx=$bsidx")) {
		    print STDERR
			"Could not transfer capacity $psize from idx=$bsidx to idx=$aggidx\n";
		    return -1;
		}
	    }
	}

    }

    DBQueryWarn("delete from blockstores where bsidx=$bsidx")
	or return -1;
    
    DBQueryWarn("delete from blockstore_attributes where bsidx=$bsidx")
	or return -1;

    DBQueryWarn("delete from blockstore_state where bsidx=$bsidx")
	or return -1;

    DBQueryWarn("delete from blockstore_trees where bsidx=$bsidx")
	or return -1;

    return 0
}

sub GetAttribute($$)
{
    my ($self, $attrkey) = @_;
    my $bsidx = $self->bsidx();
    my $value;

    my $query_result =
	DBQueryWarn("select attrvalue from blockstore_attributes ".
		    "where bsidx='$bsidx' and attrkey='$attrkey'");
    if ($query_result && $query_result->numrows) {
	($value) = $query_result->fetchrow_array();
    }

    return $value;
}

#
# Stringify for output.
#
sub Stringify($)
{
    my ($self) = @_;
    
    my $bsidx   = $self->bsidx();
    my $bs_id   = $self->bs_id();
    my $node_id = $self->node_id();

    return "[BlockStore:$bsidx, $bs_id, $node_id]";
}

#
# Create a partition blockstore using space from the invoking blockstore.
# Returns a new blockstore object.
#
# In addition to atomically updating the base blockstore's blockstore_state
# entry, it creates new blockstores, blockstore_state, and blockstore_trees
# entries for the partition.
#
sub Partition($$$$$)
{
    my ($self, $lease_idx, $pbs_name, $pbs_type, $pbs_size) = @_;
    my $bsidx      = $self->bsidx();
    my $bs_id      = $self->bs_id();
    my $bs_node_id = $self->node_id();
    my $remaining_capacity;
    my $new_bs;

    #
    # Make sure it doesn't already exist
    #
    if (Blockstore->Lookup($bs_node_id, $pbs_name)) {
	print STDERR "Partition blockstore $bs_node_id/$pbs_name already exists\n";
	return undef;
    }

    #
    # Make sure we have an entry for the new blockstore.
    # XXX we do this before we lock the tables since Create accesses
    # other tables (e.g., table_regex) and we don't want to lock those.
    #
    my $args = {
	"node_id"    => $bs_node_id,
	"bs_id"      => $pbs_name,
	"lease_idx"  => $lease_idx,
	"type"       => $pbs_type,
	"role"       => "partition",
	"total_size" => $pbs_size,
	"exported"   => 1
    };
    $new_bs = Blockstore->Create($args);
    return undef
	if (!$new_bs);

    my $new_bsidx = $new_bs->bsidx();

    if (!DBQueryWarn("lock tables blockstores write, ".
		     "            blockstore_trees write, ".
		     "            blockstore_state write, ".
		     "            blockstore_state as f write, ".
		     "            blockstore_state as t write")) {
	$new_bs->Delete();
	return undef;
    }

    #
    # Need the remaining size to make sure we can allocate it.
    #
    my $query_result =
	DBQueryWarn("select remaining_capacity from blockstore_state ".
		    "where bsidx='$bsidx'");
    goto bad
	if (!$query_result);

    #
    # Just in case the state row is missing, okay to create it.
    #
    if (!$query_result->numrows) {
	$remaining_capacity = $self->total_size();

	DBQueryWarn("insert into blockstore_state set ".
		    "  bsidx='$bsidx', node_id='$bs_node_id', bs_id='$bs_id', ".
		    "  remaining_capacity='$remaining_capacity', ready='1'")
	    or goto bad;
    }
    else {
	($remaining_capacity) = $query_result->fetchrow_array();
    }
    if ($pbs_size > $remaining_capacity) {
	print STDERR "Not enough remaining capacity on $self\n";
	goto bad;
    }

    #
    # Establish the relationship between the partition and the base.
    #
    DBQueryWarn("insert into blockstore_trees set ".
		"  bsidx='$new_bsidx', aggidx='$bsidx', hint='PS'")
	or goto bad;

    #
    # Create a state table entry.
    #
    DBQueryWarn("insert into blockstore_state set ".
		"  bsidx='$new_bsidx', node_id='$bs_node_id', ".
		"  bs_id='$pbs_name', remaining_capacity='0', ready='1'")
	or goto bad;

    #
    # Now do an atomic update that changes both rows.
    #
    DBQueryWarn("update blockstore_state as f,blockstore_state as t ".
		"set f.remaining_capacity=f.remaining_capacity-${pbs_size},".
		"    t.remaining_capacity=$pbs_size ".
		"where f.bsidx='$bsidx' and t.bsidx='$new_bsidx'")
	or goto bad;
done:
    DBQueryWarn("unlock tables");
    return $new_bs;
  bad:
    DBQueryWarn("unlock tables");
    $new_bs->Delete();
    return undef;
}

#
# Blockstores are reserved to a pcvm; that is how we do the
# bookkeeping. When a node is released (nfree), we can find
# the reserved blockstores for that node, reset the capacity
# in the blockstore_state table, and delete the row(s).
#
sub Reserve($$$$$)
{
    my ($self, $experiment, $vnode_id, $bs_name, $bs_size) = @_;
    my $exptidx    = $experiment->idx();
    my $pid        = $experiment->pid();
    my $eid        = $experiment->eid();
    my $bsidx      = $self->bsidx();
    my $bs_id      = $self->bs_id();
    my $bs_node_id = $self->node_id();
    my $remaining_capacity;

    DBQueryWarn("lock tables blockstores read, ".
		"            reserved_blockstores write, ".
		"            blockstore_state write")
	or return -1;

    #
    # Need the remaining size to make sure we can allocate it.
    #
    my $query_result =
	DBQueryWarn("select remaining_capacity from blockstore_state ".
		    "where bsidx='$bsidx'");
    goto bad
	if (!$query_result);

    #
    # Just in case the state row is missing, okay to create it.
    #
    if (!$query_result->numrows) {
	$remaining_capacity = $self->total_size();

	DBQueryWarn("insert into blockstore_state set ".
		    "  bsidx='$bsidx', node_id='$bs_node_id', bs_id='$bs_id', ".
		    "  remaining_capacity='$remaining_capacity', 'ready=1'")
	    or goto bad;
    }
    else {
	($remaining_capacity) = $query_result->fetchrow_array();
    }
    if ($bs_size > $remaining_capacity) {
	print STDERR "Not enough remaining capacity on $self\n";
	goto bad;
    }

    #
    # If we do not have a reservation row, create one with a zero
    # size, to indicate nothing has actually been reserved in the
    # blockstore_state table.
    #
    # However, if this is a lease (dataset), then we are just going to
    # stuff the full size of it into the reserved_blockstores table
    # and forgo any other capacity accounting.  Also, its
    # 'remaining_capacity' is always its full size. This allows for
    # simultaneous read-only use (modes enforced elsewhere).
    #
    $query_result =
	DBQueryWarn("select size from reserved_blockstores ".
		    "where exptidx='$exptidx' and bsidx='$bsidx' and ".
		    "       vname='$bs_name'");
    goto bad
	if (!$query_result);

    my $newsize = 0;
    if ($self->lease_idx() > 0) {
	$newsize = $self->total_size();
    } 

    if (! $query_result->numrows) {
	if (! DBQueryWarn("insert into reserved_blockstores set ".
	        "  bsidx='$bsidx', node_id='$bs_node_id', bs_id='$bs_id', ".
	        "  vname='$bs_name', pid='$pid', eid='$eid', ".
		"  size='$newsize', vnode_id='$vnode_id', ".
	        "  exptidx='$exptidx', rsrv_time=now()")) {
	    goto bad;
	}
    }
    else {
	my ($current_size) = $query_result->fetchrow_array();

	#
	# At the moment, I am not going to allow the blockstore
	# to change size. 
	#
	if ($current_size && $current_size != $bs_size) {
	    print STDERR "Not allowed to change size of existing store\n";
	    goto bad;
	}

	#
	# If already have a reservation size, then this is most
	# likely a swapmod, and we can just return without doing
	# anything.
	#
	goto done
	    if ($current_size);
    }

    #
    # Now do an atomic update that changes both tables.
    # Note: leases do not require this.
    #
    if ($self->lease_idx() == 0 &&
	!DBQueryWarn("update blockstore_state,reserved_blockstores set ".
		     "     remaining_capacity=remaining_capacity-${bs_size}, ".
		     "     size='$bs_size' ".
		     "where ".
		     "  blockstore_state.bsidx=reserved_blockstores.bsidx and".
		     "  blockstore_state.bs_id=reserved_blockstores.bs_id and".
		     "  reserved_blockstores.bsidx='$bsidx' and ".
		     "  reserved_blockstores.exptidx='$exptidx' and ".
		     "  reserved_blockstores.vnode_id='$vnode_id'")) {
	goto bad;
    }
done:
    DBQueryWarn("unlock tables");

    #
    # If there is a lease associated with this blockstore, update the
    # last used time since this represents a mapping (aka swapin) of the
    # lease.
    #
    if ($self->lease_idx() != 0) {
	require Lease;

	my $lease = Lease->Lookup($self->lease_idx());
	$lease->BumpLastUsed()
	    if ($lease);
    }

    return 0;
  bad:
    DBQueryWarn("unlock tables");
    return -1;
}

#
# Return the remaining unallocated space
#
sub AvailableCapacity($)
{
    my ($self) = @_;
    my $bsidx = $self->bsidx();

    my $query_result =
	DBQueryWarn("select b.total_size,s.remaining_capacity ".
		    "from blockstores as b left join blockstore_state as s ".
		    "on b.bsidx=s.bsidx where b.bsidx='$bsidx'");
    return -1
	if (!$query_result || !$query_result->numrows);

    #
    # If remaining_capacity is NULL, then the blockstore is unused
    # and we just return the total size.
    #
    my ($size,$avail) = $query_result->fetchrow_array();
    return (defined($avail) ? $avail : $size);
}

# convert_to_mebi
# This takes a data size specifier in the form of <amt><unit> where
# <unit> is any of [B, KB, KiB, MB, MiB, GB, GiB, TB, TiB].  If no
# unit is given then bytes (B) is assumed.  It returns the size
# in Mebibytes.  Data sizes in bits (lowercase b) are not handled (yet).
#
sub ConvertToMebi($)
{
    my ($size) = @_;
    # Default to bytes
    my $unit   = "B";
    
    if ($size =~ /^([\.\d]+)(\w+)$/) {
	$size = $1;
	$unit = $2;
    }
    else {
	return -1;
    }
    SWITCH: for ($unit) {
	/^B$/ && do {
	    $size = int($size / 2**20);
	    last SWITCH;
	};
	/^KB$/ && do {
	    $size = int($size * 10**3 / 2**20);
	    last SWITCH;
	};
	/^KiB$/ && do {
	    $size = int($size / 2**10);
	    last SWITCH;
	};
	/^MB$/ && do {
	    $size = int($size * 10**6 / 2**20);
	    last SWITCH;
	};
	/^MiB$/ && do {
	    $size = int($size);
	    last SWITCH;
	};
	/^GB$/ && do {
	    $size = int($size * 10**9 / 2**20);
	    last SWITCH;
	};
	/^GiB$/ && do {
	    $size = int($size * 2**10);
	    last SWITCH;
	};
	/^TB$/ && do {
	    $size = int($size * 10**12 / 2**20);
	    last SWITCH;
	};
	/^TiB$/ && do {
	    $size = int($size * 2**20);
	    last SWITCH;
	};
	print STDERR "Illegal mebibytes unit: $unit\n";
	return -1;
    };
    return $size;
}

#
# Compute a load time estimate for an image backed dataset.
#
sub LoadEstimate($)
{
    my ($blockstore) = @_;
    my $bsname = $blockstore->vname();
    require OSImage;

    if (!exists($blockstore->{'attributes'}->{"dataset"})) {
	print STDERR "No dataset attribute for $bsname\n";
	return -1;
    }
    my $dataset = $blockstore->{'attributes'}->{"dataset"};
    my $image   = OSImage->Lookup($dataset);
    if (!defined($image)) {
	print STDERR "No image for dataset $dataset for $bsname\n";
	return -1;
    }
    # Bad, but don't want to use bignums to get MBs.
    my $size = int(($image->lba_high() - $image->lba_low()) *
		   ($image->lba_size() / (1024.0 * 1024.0)));
    
    #
    # Temporary approach; look for the size attribute and use that
    # to extend the waittime. Later we will use the amount of actual
    # data.
    #
    my $extratime = int($size / 100);
    return $extratime;
}

############################################################################
#
# Package to describe a specific reservation of a blockstore.
#
package Blockstore::Reservation;
use libdb;
use libtestbed;
use English;
use vars qw($AUTOLOAD);
use overload ('""' => 'Stringify');

#
# Lookup a blockstore reservation.
#
sub Lookup($$$$)
{
    my ($class, $blockstore, $experiment, $vname) = @_;

    return undef
	if (! ($vname =~ /^[-\w]+$/ && ref($blockstore) && ref($experiment)));

    my $exptidx = $experiment->idx();
    my $bsidx   = $blockstore->bsidx();

    my $query_result =
	DBQueryWarn("select * from reserved_blockstores ".
		    "where exptidx='$exptidx' and bsidx='$bsidx' and ".
		    "       vname='$vname'");

    return undef
	if (!$query_result || !$query_result->numrows);

    my $self         = {};
    $self->{"HASH"}  = {};
    $self->{"DBROW"} = $query_result->fetchrow_hashref();

    bless($self, $class);
    return $self;
}

#
# Look for the blockstore associated with a pcvm. At the present
# time, one blockstore is mapped to one pcvm. 
#
sub LookupByNodeid($$)
{
    my ($class, $vnode_id) = @_;

    my $query_result =
	DBQueryWarn("select * from reserved_blockstores ".
		    "where vnode_id='$vnode_id'");

    return undef
	if (!$query_result || !$query_result->numrows);

    if ($query_result->numrows != 1) {
	print STDERR "Too many blockstores for $vnode_id!\n";
	return -1;
    }

    my $self         = {};
    $self->{"HASH"}  = {};
    $self->{"DBROW"} = $query_result->fetchrow_hashref();

    bless($self, $class);
    return $self;
}

# To avoid writing out all the methods.
AUTOLOAD {
    my $self  = $_[0];
    my $name  = $AUTOLOAD;
    $name =~ s/.*://;   # strip fully-qualified portion

    # A DB row proxy method call.
    if (exists($self->{'DBROW'}->{$name})) {
	return $self->{'DBROW'}->{$name};
    }
    carp("No such slot '$name' in $self");
    return undef;
}

#
# Is this reservation RO?
#
sub IsReadOnly($) {
    my ($self) = @_;

    return $self->HowUsed()->{'readonly'};
}

#
# Is this reservation a RW clone?
#
sub IsRWClone($) {
    my ($self) = @_;

    return $self->HowUsed()->{'rwclone'};
}

#
# How is the associated blockstore used in this reservation?
#
sub HowUsed($) {
    my ($self) = @_;
    require VirtExperiment;

    my $rethash = {
	'readonly' => 0,
	'rwclone' => 0,
    };

    my $virtexpt = VirtExperiment->Lookup(Experiment->Lookup($self->exptidx()));
    if (!$virtexpt) {
	print STDERR "Virtual experiment object could not be loaded for ${self}!";
	return undef;
    }

    my @attrs = ($self->vname(), "readonly");
    my $row = $virtexpt->Find("virt_blockstore_attributes", @attrs);
    if ($row) {
	$rethash->{'readonly'} = int($row->attrvalue());
    }

    @attrs = ($self->vname(), "rwclone");
    $row = $virtexpt->Find("virt_blockstore_attributes", @attrs);
    if ($row) {
	$rethash->{'rwclone'} = int($row->attrvalue());
    }

    return $rethash;
}

# Break circular reference someplace to avoid exit errors.
sub DESTROY {
    my $self = shift;

    $self->{"DBROW"}    = undef;
    $self->{"HASH"}     = undef;
}

#
# Stringify for output.
#
sub Stringify($)
{
    my ($self) = @_;
    
    my $bsidx   = $self->bsidx();
    my $bs_id   = $self->bs_id();
    my $node_id = $self->node_id();
    my $vname   = $self->vname();

    return "[BlockStore::Reservation:$bsidx, $bs_id, $node_id ($vname)]";
}

#
# Blockstores are reserved to a pcvm; that is how we do the
# bookkeeping. When a node is released (nfree), we can find
# the reserved blockstore for that node, reset the capacity
# in the blockstore_state table, and delete the row(s).
#
sub Release($)
{
    my ($self)     = @_;
    my $exptidx    = $self->exptidx();
    my $bsidx      = $self->bsidx();
    my $bs_id      = $self->bs_id();
    my $bs_node_id = $self->node_id();
    my $vnode_id   = $self->vnode_id();
    my $size       = $self->size();

    DBQueryWarn("lock tables blockstores read, ".
		"            reserved_blockstores write, ".
		"            blockstore_state write")
	or return -1;

    #
    # Need the remaining size to deallocate.
    #
    my $query_result =
	DBQueryWarn("select remaining_capacity from blockstore_state ".
		    "where bsidx='$bsidx'");
    goto bad
	if (!$query_result);

    if (!$query_result->numrows) {
	print STDERR "No blockstore state for $bsidx\n";
	goto bad;
    }

    #
    # See if there is an associated lease.
    #
    my $lease_idx = 0;
    $query_result =
	DBQueryWarn("select lease_idx from blockstores ".
		    "where bsidx='$bsidx'");
    if ($query_result && $query_result->numrows) {
	$lease_idx = $query_result->fetchrow_array();
    }

    #
    # We want to atomically update remaining_capacity and
    # set the size in the reservation to zero, so that if we fail,
    # nothing has changed.
    # Note: leases do not require this.
    #
    if ($lease_idx == 0 &&
	!DBQueryWarn("update blockstore_state,reserved_blockstores set ".
		     "     remaining_capacity=remaining_capacity+size, ".
		     "     size=0 ".
		     "where ".
		     "  blockstore_state.bsidx=reserved_blockstores.bsidx and".
		     "  blockstore_state.bs_id=reserved_blockstores.bs_id and".
		     "  reserved_blockstores.bsidx='$bsidx' and".
		     "  reserved_blockstores.exptidx='$exptidx' and".
		     "  reserved_blockstores.vnode_id='$vnode_id'")) {
	goto bad;
    }
    # That worked, so now we can delete the reservation row.
    DBQueryWarn("delete from reserved_blockstores ".
		"where reserved_blockstores.bsidx='$bsidx' and ".
		"      reserved_blockstores.exptidx='$exptidx' and ".
		"      reserved_blockstores.vnode_id='$vnode_id'")
	or goto bad;

    DBQueryWarn("unlock tables");

    #
    # If there is a lease associated with this blockstore, update the
    # last used time since this represents an unmapping (aka swapout)
    # of the lease.
    #
    # XXX currently, we also create a new snapshot of the blockstore
    # if the blockstore is marked as "multiuse" and is mapped RW and
    # not a clone.
    #
    if ($lease_idx != 0) {
	require Lease;

	my $lease = Lease->Lookup($lease_idx);
	if ($lease) {
	    $lease->BumpLastUsed();
	    if (!$lease->IsExclusiveUse() &&
		!$self->IsReadOnly() && !$self->IsRWClone() &&
		$lease->CreateResourceSnapshot(1)) {
		print STDERR "Blockstore->Release: ".
		    "Could not create snapshot for $bsidx ($lease); ".
		    "marking as exclusive-use\n";
		$lease->SetExclusiveUse();
	    }
	}
    }

    return 0;
  bad:
    DBQueryWarn("unlock tables");
    return -1;
}

# _Always_ make sure that this 1 is at the end of the file...
1;
