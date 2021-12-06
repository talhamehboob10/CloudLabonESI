#!/usr/bin/perl -wT
#
# Copyright (c) 2013 University of Utah and the Flux Group.
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
# Emulab wrapper class for the IP range buddy allocator.  Handles all of the
# Emulab-specific goo around allocating address ranges.
#
# Note:  Currently this class only supports a single global address range
#        type.  It really should be augmented to support multiple.
#
package IPBuddyWrapper;

use strict;
use Exporter;
use vars qw(@ISA @EXPORT);

@ISA = qw(Exporter);
@EXPORT = qw ( );

use English;
use emdb;
use emutil qw( TBGetUniqueIndex );
use libtestbed;
use libtblog_simple;
use Experiment;
use IPBuddyAlloc;
use Socket;

# Constants
my $BUDDYRESLOCK = "reserved_addresses";

# Prototypes


#
# Create a new IPBuddyAlloc wrapper object.  Pass in a string specifying
# the type of address reservations to target.
#
sub new($$) {
    my ($class, $intype) = @_;
    my $self = {};

    return undef
	unless defined($intype);

    # Get the address range corresponding to this type from the database.
    # Currently this only supports one type, and one range for that type.
    my $qres =
	DBQueryWarn("select * from address_ranges where type='$intype'");
    return undef
	if (!$qres);
    if ($qres->numrows() != 1) {
	tberror("More than one range entry found for this address ".
		"type in the DB: $intype\n");
	return undef;
    }

    my ($baseaddr, $prefix, $type, $role) = $qres->fetchrow();

    # IPBuddyAlloc throws exceptions.
    my $buddy = eval { IPBuddyAlloc->new("$baseaddr/$prefix") };
    if ($@) {
	tberror("Could not allocate a new IP Buddy Allocator object: $@\n");
	return undef;
    }

    $self->{'TYPE'}  = $type;
    $self->{'ROLE'}  = $role;
    $self->{'BUDDY'} = $buddy;
    $self->{'ALLOC_RANGES'} = {};
    $self->{'NEWLIST'} = [];
    
    bless($self, $class);
    return $self;
}

# Internal Accessors
sub _getbuddy($)   { return $_[0]->{'BUDDY'}; }
sub _gettype($)    { return $_[0]->{'TYPE'}; }
sub _getrole($)    { return $_[0]->{'ROLE'}; }
sub _allranges($)  { return $_[0]->{'ALLOC_RANGES'}; }
sub _allnew($)     { return $_[0]->{'NEWLIST'}; }
sub _getrange($$)  { return $_[0]->_allranges()->{$_[1]}; }
sub _putrange($$$) { $_[0]->_allranges()->{$_[1]} = $_[2]; }
sub _newrange($$$) { $_[0]->_putrange($_[1],$_[2]); 
		     push @{$_[0]->_allnew()}, $_[2]; }

#
# Grab the reserved address lock.
#
sub lock($) {
    my $self = shift;

    # Use a file lock instead of a table lock since we don't know what
    # other tables might be used while this is locked.
    TBScriptLock($BUDDYRESLOCK) == TBSCRIPTLOCK_OKAY()
	or return 0;

    return 1;
}

#
# Release the lock.
#
sub unlock($) {
    my $self = shift;

    TBScriptUnlock();

    return 1;
}

#
# Load ranges into this object from the Emulab database.  Also, optionally
# add the subnets for a specified experiment to the set of reservations.
#
# $self   - Reference to class instance.
# $vexperiment - (optional) VirtExperiment object reference.  virtlans
#                that are a member of this experiment will be added to the
#                set of reserved address ranges.
#
sub loadReservedRanges($;$) {
    my ($self, $experiment) = @_;

    my $bud      = $self->_getbuddy();
    my $ranges   = $self->_allranges();
    my $addrtype = $self->_gettype();

    my $qres =
	DBQueryWarn("select * from reserved_addresses where type='$addrtype'");
    return -1
	if (!$qres);

    # Go through each row in the reserved addresses table for the type
    # specified, and add the ranges to the internal buddy allocator.
    # Create and stash an object for other bookkeeping.
    while (my ($ridx, $pid, $eid, $exptidx, $rtime, 
	       $baseaddr, $prefix, $type, $role) = $qres->fetchrow()) 
    {
	my $rval = eval { $bud->embedAddressRange("$baseaddr/$prefix") };
	if ($@) {
	    tberror("Error while embedding reserved address range: $@\n");
	    return -1
	}
	$self->_putrange("$baseaddr/$prefix",
			 IPBuddyWrapper::Allocation->new($exptidx, 
							 "$baseaddr/$prefix"));
    }

    # Add an experiment's virtlans if that parameter was passed in.
    if (defined($experiment)) {
	if (!ref($experiment)) {
	    tberror("Experiment argument is not an object!\n");
	    return -1;
	}
	my $exptidx    = $experiment->idx();
	my $virtexpt   = $experiment->GetVirtExperiment();
	my $virtlans   = $virtexpt->Table("virt_lans");
	foreach my $vlrow ($virtlans->Rows()) {
	    my $ip     = inet_aton($vlrow->ip());
	    my $mask   = inet_aton($vlrow->mask());
	    my $prefix = unpack('%32b*', $mask);
	    my $base   = inet_ntoa($ip & $mask);
	    next if $self->_getrange("$base/$prefix");
	    my $rval   = eval { $bud->embedAddressRange("$base/$prefix") };
	    if ($@) {
		# Just skip if the current range isn't in the base
		# address range or conflicts with an existing
		# range. We only care about adding new ranges within
		# the base range considered for allocation.
		next if $@ =~ /must belong to base range/;
		next if $@ =~ /found conflicting node/;
		tberror("Error while embedding experiment lan range: $@\n");
		return -1;
	    }
	    $self->_putrange("$base/$prefix",
			     IPBuddyWrapper::Allocation->new($exptidx,
							     "$base/$prefix"));
	}
    }

    return 0;
}

#
# Request an address range from the buddy IP address pool given the
# input (dotted quad) mask and a virt experiment to stash away for
# later when the code needs to push the reservations into the
# database.
#
sub requestAddressRange($$$) {
    my ($self, $experiment, $mask) = @_;

    return undef unless 
	ref($experiment) &&
	defined($mask);

    # Check mask argument to see if it is a dotted-quad mask or a CIDR
    # prefix.  Convert dotted-quad masks to CIDR prefixes.
    my $prefix;
    if ($mask =~ /^\d+\.\d+\.\d+\.\d+$/) {
	$prefix = unpack('%32b*', inet_aton($mask));
    } elsif ($mask =~ /^\d+$/) {
	$prefix = $mask;
    } else {
	tberror("Invalid mask or prefix: $mask\n");
	return undef;
    }

    my $exptidx = $experiment->idx();
    my $bud     = $self->_getbuddy();

    # IPBuddyAlloc throws exceptions.
  again:
    my $base = eval { $bud->requestAddressRange($prefix) };
    if ($@) {
	tberror("Error while requesting address range: $@");
	return undef;
    }
    if (!defined($base)) {
	tberror("Could not get a free address range!\n");
	return undef;
    }
    # Throw away any ranges where all the bits are set in the quad.
    # We want to avoid confusion and potential issues with broadcast
    # addresses.
    foreach my $quad (split(/\./, $base)) {
	if ($quad == 255) {
	    goto again;
	}
    }
    my $range = "$base/$prefix";
    # Push the new range onto the new range list.  This also puts it
    # into the "allocated" hash.
    $self->_newrange($range, IPBuddyWrapper::Allocation->new($exptidx,
							     $range));

    return $range;
}

#
# Request the next address from the input range.  It should have been
# previously allocated with requestAddressRange().
#
sub getNextAddress($$) {
    my ($self, $range) = @_;

    return undef
	unless defined($range);

    my $robj = $self->_getrange($range);
    if (!defined($robj)) {
	tberror("Can't find allocation object for range: $range!\n");
	return undef
    }
    return $robj->getNextAddress();
}

sub DESTROY($) {
    my $self = shift;

    $self->{'TYPE'} = undef;
    $self->{'ROLE'} = undef;
    $self->{'BUDDY'} = undef;
    $self->{'ALLOC_RANGES'} = undef;
    $self->{'NEWLIST'} = undef;
}

#
# Splat the list of newly allocated address ranges into the database.
#
sub commitReservations($) {
    my ($self) = @_;
    my $type = $self->_gettype();
    my $role = $self->_getrole();

    foreach my $alloc (@{$self->_allnew()}) {
	my $exptidx = $alloc->exptidx();
	my ($base, $prefix) = split(/\//, $alloc->getrange());
	my $expt    = Experiment->Lookup($exptidx);
	return -1
	    if !$expt;
	my $pid = $expt->pid();
	my $eid = $expt->eid();
	# Other IPBuddyWrapper objects should already be blocked on
	# our lock on the "reserved_addresses" table.
	my $nolock = 1;
	my $idxinitval = 1;
	my $ridx = TBGetUniqueIndex("next_resvaddridx",$idxinitval,$nolock);
	
	DBQueryWarn("insert into reserved_addresses ".
		    "values ('$ridx','$pid','$eid','$exptidx',".
		    "NOW(),'$base','$prefix','$type','$role')")
	    || return -1;
    }

    return 0;
}

##############################################################################
#
# Internal module to keep track of address range allocations.
#
package IPBuddyWrapper::Allocation;
use strict;
use English;
use Net::IP;
use libtblog_simple;

sub new($$$) {
    my ($class, $exptidx, $range) = @_;
    my $self = {};

    return undef unless 
	defined($exptidx) && 
	defined($range);

    my $ipobj = Net::IP->new($range);
    if (!defined($ipobj)) {
	tberror(Net::IP::Error() . "\n");
	return undef;
    }
    
    $self->{'EXPTIDX'} = $exptidx;
    $self->{'RANGE'} = $range;
    $self->{'IPOBJ'} = $ipobj;
    
    bless($self, $class);
    return $self;
}

# accessors
sub getrange($) { return $_[0]->{'RANGE'}; }
sub exptidx($) { return $_[0]->{'EXPTIDX'}; }

#
# Get next available address in the range. ('+' is overloaded in Net::IP).
#
sub getNextAddress($) {
    my ($self) = @_;

    if (++$self->{'IPOBJ'}) {
	return $self->{'IPOBJ'}->ip();
    }
    
    return undef;
}

#
# Reset back to base address from this object's range.
#
sub resetAddress($) {
    my $self = shift;

    my $ipobj = Net::IP->new($self->getrange());
    $self->{'IPOBJ'} = $ipobj;
}


sub DESTROY($) {
    my $self = shift;

    $self->{'EXPTIDX'} = undef;
    $self->{'RANGE'} = undef;
    $self->{'IPOBJ'} = undef;
}

# Required by perl
1;
