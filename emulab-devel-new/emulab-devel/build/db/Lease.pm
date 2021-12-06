#!/usr/bin/perl -wT
#
# Copyright (c) 2012-2020 University of Utah and the Flux Group.
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
package Lease;

use strict;
use Exporter;
use vars qw(@ISA @EXPORT);

@ISA    = "Exporter";
@EXPORT = qw ( );

# Configure variables
use vars qw($TB $BSCONTROL);
$TB        = "/users/mshobana/emulab-devel/build";
$BSCONTROL = "$TB/sbin/bscontrol";
my $PGENISUPPORT  = 1;
my $OURDOMAIN     = "cloudlab.umass.edu";

use libdb;
use libtestbed;
use EmulabConstants;
use User;
use Group;
use Project;
use Blockstore;
use English;
use Date::Parse;
use Data::Dumper;
use overload ('""' => 'Stringify');

my @LEASE_TYPES  = ("stdataset", "ltdataset");

#
# Per-type Lease sitevars:
#
# maxsize	Max size (MiB) of a dataset
#		(0 == unlimited)
# maxlease	Max time (days) from creation before lease is marked expired
#		(0 == unlimited)
# maxidle	Max time (days) from last use before lease is marked expired
#		(0 == unlimited)
# graceperiod	Time (days) before an expired dataset will be destroyed
#		(0 == no grace period, unlimited makes no sense here)
# autodestroy	If non-zero, destroy expired datasets after grace period
#		otherwise lock them
# usequotas	If non-zero, enforce per-project dataset quotas
# maxextend	Number of times a user can extend the lease
#		(0 == unlimited)
# extendperiod	Length (days) of each user-requested extension
#		(0 == do not allow extensions)
#
my @LEASE_VARS = (
    "maxsize",
    "maxlease",
    "maxidle",
    "graceperiod",
    "autodestroy",
    "usequotas",
    "maxextend",
    "extendperiod"
);

#
# Plausible defaults:
#
# Short-term datasets. Allow large datasets but with short lease and grace
# periods. They are not quota-controlled and there is not an idle limit.
# Users can extend their leases by small amounts for a little while.
# After the grace period, these are automatically destroyed.
#
# Long-term datasets. Allow any-sized dataset that fits within the quota.
# These are generally expired based on idle time but may have a really long
# lease time as well. They are quota-controlled and users cannot extend
# their leases. After the grace period, these are are just marked as locked
# and unavailable.
#
my %LEASE_VAR_DEFAULTS = (
    "stdataset/maxsize"      => 1048576,# 1 TiB
    "stdataset/maxlease"     => 7,	# 7 days
    "stdataset/maxidle"      => 0,	# none
    "stdataset/graceperiod"  => 1,	# 1 day
    "stdataset/autodestroy"  => 1,	# yes
    "stdataset/usequotas"    => 0,	# no
    "stdataset/maxextend"    => 2,	# 2 user extensions
    "stdataset/extendperiod" => 1,	# 1 day per extension

    "ltdataset/maxsize"      => 0,	# none
    "ltdataset/maxlease"     => 0,	# none, use idle time
    "ltdataset/maxidle"      => 180,	# 6 months
    "ltdataset/graceperiod"  => 180,	# 6 months
    "ltdataset/autodestroy"  => 0,	# no
    "ltdataset/usequotas"    => 1,	# yes
    "ltdataset/maxextend"    => 1,	# ignored because...
    "ltdataset/extendperiod" => 0,	# ...means no user extension
);

#
# Lease states.
#
# "unapproved".
#    All leases are in this state when they are created. No resources are
#    allocated in this state, but the desired resources may count against
#    a quota. A lease in this state can not be accessed other than to
#    destroy or approve it. The latter moves it to the valid state, a step
#    that triggers resource allocation. If the allocation fails, the lease
#    instead moves to the failed state.
#
# "valid"
#    A valid lease can be mapped into an experiment. A lease remains valid
#    unless it is explicitly or implicitly freed. Explicit would be if the
#    user deletes the lease, implicit if the lease reaches its expiration
#    date or has exceeded the "idle" limit. In the case of expiration or
#    idleness, a lease moves to the "grace" state. This transition may or
#    may not revoke permission from any experiment which has it mapped;
#    resources remain allocated. A valid lease may also transition into
#    the locked state if an admin administratively decides to prohibit
#    access to a resource. Again, it is not clear what happens if the
#    lease is currently mapped.
#
# "failed"
#    If resource allocation fails while approving a lease, the lease winds
#    up here. In the failed state, a lease has no resources assigned and
#    it can only transition back to the unapproved state (to try again) or
#    it can be destroyed. 
#
# "grace"
#    A lease in the grace state may still make resources available to
#    experiments, but in a "read-only" mode. For example, for storage
#    leases, the storage would be exported without write permissions.
#    When the grace period expires (or immediately if there was no grace
#    period), the lease will transition to either the "expired" or "locked"
#    state. The former is for resources where the policy is to immediately
#    reclaim and reuse the resources, suitable for an automatic reclamation
#    policy. The latter is for policies where a human should make the
#    reclamation decision. From here a lease can also go back into the
#    valid state (if the lease is extended).
#
# "locked"
#    In the locked state, a lease may not be mapped. Resources are still
#    allocated, and the lease may return to the valid state. The lease may
#    also be moved to the "expired" state so that the resources can be
#    reclaimed.
#
# "expired"
#    This is the "roach motel" for leases, they check in but they never
#    check out. Once in this state, a reaper will reclaim the resources
#    and destroy the lease.
#
my @LEASE_STATES = (
    "unapproved",
    "valid",
    "failed",
    "grace",
    "locked",
    "expired");

# Valid transitions for each state.
my %LEASE_TRANSITIONS = (
    "unapproved" => { "valid" => 1, "failed" => 1, "DEAD" => 1 },
    "valid"      => { "grace" => 1, "locked" => 1 },
    "failed"     => { "unapproved" => 1, "DEAD" => 1 },
    "grace"      => { "valid" => 1, "expired" => 1, "locked" => 1 },
    "locked"     => { "valid" => 1, "expired" => 1 },
    "expired"    => { "unapproved" => 1, "DEAD" => 1 },
);
    

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
# Accessors
#
sub lease_id($)        {return $_[0]->{'DBROW'}->{'lease_id'}; }
sub uuid($)            {return $_[0]->{'DBROW'}->{'uuid'}; }
sub pid($)             {return $_[0]->{'DBROW'}->{'pid'}; }
sub gid($)             {return $_[0]->{'DBROW'}->{'gid'}; }
sub idx($)             {return $_[0]->{'DBROW'}->{'lease_idx'}; }
sub lease_idx($)       {return $_[0]->idx(); }
sub owner($)           {return $_[0]->{'DBROW'}->{'owner_uid'}; }
sub owner_uid($)       {return $_[0]->{'DBROW'}->{'owner_uid'}; }
sub owner_urn($)       {return $_[0]->{'DBROW'}->{'owner_urn'}; }
sub type($)            {return $_[0]->{'DBROW'}->{'type'}; }
sub inception($)       {return str2time($_[0]->{'DBROW'}->{'inception'}); }
sub lease_end($)       {return str2time($_[0]->{'DBROW'}->{'lease_end'}); }
sub expiration($)      {return $_[0]->lease_end(); }
sub last_used($)       {return str2time($_[0]->{'DBROW'}->{'last_used'}); }
sub last_checked($)    {return str2time($_[0]->{'DBROW'}->{'last_checked'}); }
sub origin_urn($)      {return $_[0]->{'DBROW'}->{'origin_urn'}; }
sub origin_uuid($)     {return $_[0]->{'DBROW'}->{'origin_uuid'}; }
sub state($)           {return $_[0]->{'DBROW'}->{'state'}; }
sub statestamp($)      {return str2time($_[0]->{'DBROW'}->{'statestamp'}); }
sub renewals($)	       {return $_[0]->{'DBROW'}->{'renewals'}; }
sub locktime($)        {return str2time($_[0]->{'DBROW'}->{'locked'}); }
sub locked($)          {return $_[0]->{'DBROW'}->{'locked'}; }
sub lockpid($)         {return $_[0]->{'DBROW'}->{'locker_pid'}; }
sub allow_modify($;$)  {if (defined($_[1])) {$_[0]->{'allow_modify'} = $_[1];}
			return $_[0]->{'allow_modify'}; }

#
# Lookup a lease in the DB and return an object representing it.
#
sub Lookup($$;$$)
{
    my ($class, $arg1, $arg2, $arg3) = @_;
    my ($wclause);

    if (!defined($arg2)) {
	# idx, or pid/lease or pid/gid/lease
	if ($arg1 =~ /^\d+$/) {
	    $wclause = "lease_idx='$arg1'";
	}
	elsif ($arg1 =~ /^([-\w]+)\/([-\w]+)$/) {
	    $wclause = "pid='$1' and gid='$1' and lease_id='$2'";	
	}
	elsif ($arg1 =~ /^([-\w]+)\/([-\w]+)\/([-\w]+)$/) {
	    $wclause = "pid='$1' and gid='$2' and lease_id='$3'";	
	}
	else {
	    return undef;
	}
    }
    elsif (!defined($arg3)) {
	# arg2 is the lease id.
	return undef
	    if ($arg2 !~ /^[-\w]+$/);

	# arg1 is pid or pid/gid
	if ($arg1 =~ /^[-\w]+$/) {
	    $wclause = "pid='$arg1' and gid='$arg1' and lease_id='$arg2'";	
	}
	elsif ($arg1 =~ /^([-\w]+)\/([-\w]+)$/) {
	    $wclause = "pid='$1' and gid='$2' and lease_id='$arg2'";	
	}
	else {
	    return undef;
	}
    }
    else {
	# arg3 is the lease id.
	return undef
	    if ($arg3 !~ /^[-\w]+$/);
	# arg1 is pid and arg2 is gid
	return undef
	    if ($arg1 !~ /^[-\w]+$/ || $arg2 !~ /^[-\w]+$/);

	$wclause = "pid='$arg1' and gid='$arg2' and lease_id='$arg3'";	
    }
    
    my $self              = {};
    $self->{"LOCKED"}     = 0;
    $self->{"LOCKER_PID"} = 0;
    $self->{"ATTRS"}      = undef;  # load lazily

    # Load lease from DB, if it exists. Otherwise, return undef.
    my $query_result =
	DBQueryWarn("select * from project_leases where $wclause");

    return undef
	if (!$query_result || !$query_result->numrows);

    $self->{'DBROW'} = $query_result->fetchrow_hashref();;
    bless($self, $class);

    return $self;
}

#
# Force a reload of the data.
#
sub LookupSync($$;$$) {
    my ($class, $arg1, $arg2, $arg3) = @_;

    return Lookup($class, $arg1, $arg2, $arg3);
}

#
# explicit object destructor to ensure we get rid of circular refs.
#
sub DESTROY($) {
    my ($self) = @_;

    $self->{'LOCKED'} = undef;
    $self->{'LOCKER_PID'} = undef;
    $self->{'ATTRS'} = undef;
    $self->{'DBROW'} = undef;
}

#
# Create a new lease.
#
sub Create($$;$) {
    my ($class, $argref, $attrs) = @_;

    my ($lease_id, $pid, $gid, $uid, $type, $lease_end, $state, $group);

    return undef
	if (!ref($argref));

    $lease_id  = $argref->{'lease_id'};
    $pid       = $argref->{'pid'};
    $gid       = $argref->{'gid'};
    $uid       = $argref->{'uid'};
    $type      = $argref->{'type'};
    $lease_end = $argref->{'lease_end'};
    $state     = $argref->{'state'};
    
    if (!($lease_id && $pid && $type &&
	  defined($lease_end) && $state)) {
	print STDERR "Lease->Create: Missing required parameters in argref\n";
	return undef;
    }

    # Sanity checks for incoming arguments
    if (!TBcheck_dbslot($lease_id, "project_leases", "lease_id")) {
	print STDERR "Lease->Create: Bad data for lease id: ".
	    TBFieldErrorString() ."\n";
	return undef;
    }

    if (ref($pid) eq "Project") {
	$group = $pid->GetProjectGroup();
	$pid   = $gid = $group->pid();
    }
    elsif (ref($pid) eq "Group") {
	$group = $pid;
	$gid   = $group->gid();
	$pid   = $group->pid();
    }
    else {
	if (!defined($gid)) {
	    $gid = $pid;
	}
	$group = Group->Lookup("$pid/$gid");
	if (!defined($group)) {
	    print STDERR "Lease->Create: Bad/Unknown project: $pid/$gid\n";
	    return undef;
	}
    }

    if (ref($uid) ne "User") {
	my $nuid = User->Lookup($uid);
	if (!defined($nuid)) {
	    print STDERR "Lease->Create: Bad/unknown owner: $uid\n";
	    return undef;
	}
	$uid = $nuid
    }

    # User must belong to incoming project.  The code calling into Create()
    # should have already checked to be sure that the caller has permission
    # to create the lease in the first place.
    if (!$group->LookupUser($uid)) {
	print STDERR
	    "Lease->Create: Owner $uid is not a member of project $pid/$gid\n";
	return undef;
    }
    
    # If lease types ever grow to be many and complex, then this info will
    # have to come from a DB table instead of a static list in this module.
    if (!grep {/^$type$/} @LEASE_TYPES) {
	print STDERR "Lease->Create: Unknown lease type: $type\n";
	return undef;
    }

    if ($lease_end !~ /^\d+$/) {
	print "Lease->Create: Invalid lease end time: $lease_end\n";
	return undef;
    }
    if ($lease_end && $lease_end < time()) {
	print STDERR "Lease->Create: Lease end cannot be in the past\n";
	return undef;
    }

    if (!grep {/^$state$/} @LEASE_STATES) {
	print STDERR "Lease->Create: Unknown lease state: $state\n";
	return undef;
    }

    #
    # Get a unique lease index and slam this stuff into the DB.
    # Note that lease_end == 0 means unlimited, for which we use the
    # DB default value of 2037-01-19 03:14:07, one year before the
    # (Unix) universe ends.
    #
    my $lease_idx = TBGetUniqueIndex('next_leaseidx');
    DBQueryWarn("insert into project_leases set ".
		"lease_idx=$lease_idx,".
		"lease_id='$lease_id',".
		"pid='$pid',gid='$gid', ".
		"owner_uid='". $uid->uid() ."',".
		"type='$type',".
		($lease_end ? "lease_end=FROM_UNIXTIME($lease_end)," : "").
		"state='$state',".
		"uuid=uuid(), ".
		"statestamp=NOW(),".
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
	    DBQueryWarn("insert into lease_attributes set ".
			"lease_idx=$lease_idx,".
			"attrkey='$key',".
			"attrval=$val,".
			"attrtype='$type'")
		or return undef;
	}
    }
    return Lookup($class, $group->pid(), $group->gid(), $lease_id);
}

#
# Delete an existing lease.
#
sub Delete($) {
    my ($self) = @_;

    return LEASE_ERROR_FAILED()
	if (!ref($self));

    my $idx  = $self->idx();
    my $uuid = $self->uuid();

    DBQueryWarn("delete from web_tasks where object_uuid='$uuid'")
	or return LEASE_ERROR_FAILED();

    DBQueryWarn("delete from project_leases where lease_idx=$idx")
	or return LEASE_ERROR_FAILED();
    
    DBQueryWarn("delete from lease_attributes where lease_idx=$idx")
	or return LEASE_ERROR_FAILED();

    DBQueryWarn("delete from lease_permissions where lease_idx=$idx")
	or return LEASE_ERROR_FAILED();

    return 0
}

sub urn($)
{
    my ($self) = @_;

    return undef
	if (! $PGENISUPPORT);    

    require GeniHRN;
    my $pid    = $self->pid();
    my $gid    = $self->gid();
    my $name   = $self->lease_id();
    my $domain = $OURDOMAIN;
    $domain .= ":${pid}";
    $domain .= ":${gid}" if ($pid ne $gid);
	
    return GeniHRN::Generate($domain, $self->type(), $name);
}    

#
# Is the underlying blockstore resource mapped in RW currently?
# XXX: blockstore-specific lease function.  Should be in a subclass.
#
sub InUseReadWrite() {
    my ($self) = @_;

    my $rw = 0;

    return LEASE_ERROR_FAILED()
	if (!ref($self));

    my $resvref = $self->GetReservations();
    if ($resvref) {
	foreach my $ref (@$resvref) {
	    if (!$ref->IsReadOnly() && !$ref->IsRWClone()) {
		$rw = 1;
		last;
	    }
	}
    }

    return $rw;
}

sub InUse($) {
    my ($self) = @_;

    return LEASE_ERROR_FAILED()
	if (!ref($self));

    my $lref = $self->GetReservations();
    if (!$lref) {
	return 0;
    }

    return ((@$lref > 0) ? 1 : 0);
}

sub IsExclusiveUse($) {
    my ($self) = @_;

    # Every lease is exclusive use unless sitevar is set non-zero
    if (!TBSiteVarExists("storage/simultaneous_ro_datasets") ||
	TBGetSiteVar("storage/simultaneous_ro_datasets") == 0) {
	return 1;
    }

    # Otherwise, no lease is exclusive use unless attribute is set non-zero
    my $rv = $self->GetAttribute("exclusive_use");
    return $rv ? 1 : 0;
}

sub SetExclusiveUse($) {
    my ($self) = @_;

    return $self->SetAttribute("exclusive_use", 1, "integer");
}

sub ClearExclusiveUse($) {
    my ($self) = @_;

    return $self->SetAttribute("exclusive_use", 0, "integer");
}

#
# Returns a list of blockstore reservations that are currently using the
# resources associated with this lease. XXX: this is a blockstore-specific
# function.
#
sub GetReservations($) {
    my ($self) = @_;

    return undef
	if (!ref($self));

    my @resvlist = ();

    #
    # Before doing a big honkin query, see if the lease has resources
    # allocated to it.
    #
    if ($self->type() =~ /dataset$/ &&
	!($self->state() eq "unapproved" || $self->state() eq "failed")) {
	my $lidx = $self->lease_idx();

	my $query_result =
	    DBQueryWarn("select r.vnode_id from blockstores as b,".
			"   reserved_blockstores as r,project_leases as l ".
			"where b.bsidx=r.bsidx ".
			"   and b.lease_idx=l.lease_idx ".
			"   and l.lease_idx='$lidx'");
	return undef 
	    if (!$query_result);

	while (my ($vnode_id,) = $query_result->fetchrow_array()) {
	    next if (!$vnode_id);
	    push(@resvlist, 
		 Blockstore::Reservation->LookupByNodeid($vnode_id));
	}
    }

    return \@resvlist;
}

#
# Allocate resources to a lease and transition to the indicated state.
# Note that this could take a long time. It is up to the caller to lock
# the lease if atomicity is a concern.
#
sub AllocResources($;$$) {
    my ($self,$state,$interruptable) = @_;

    $state = "valid"
	if (!defined($state));

    return LEASE_ERROR_FAILED()
	if (!ref($self));

    #
    # Lease must be in the unapproved state to allocate resources.
    # Any other state implies that resources have been allocated already.
    #
    if ($self->state() ne "unapproved") {
	print STDERR "$self: AllocResources: must be in state 'unapproved'.\n";
	return LEASE_ERROR_FAILED();
    }
    if (!$self->ValidTransition($state)) {
	print STDERR "$self: AllocResources: cannot transition to state '$state' from unapproved.\n";
	return LEASE_ERROR_FAILED();
    }

    #
    # Force allocation of storage for dataset leases.
    # XXX this should be in Lease::Blockstore object!
    #
    if ($self->type() =~ /dataset$/) {
	#
	# Must be an associated size attribute.
	#
	my $size = $self->GetAttribute("size");
	if ($size == 0 || $size !~ /^\d+$/) {
	    print STDERR "$self: AllocResources: no valid 'size' attribute\n";
	    return LEASE_ERROR_FAILED();
	}

	#
	# There may also be an associated fstype attribute.
	# Note: we let caller or bscontrol do checking on the vaildity
	# of the type.
	#
	my $fstype = $self->GetAttribute("fstype");
	if (defined($fstype) && $fstype ne "") {
	    $fstype = "-f $fstype";
	} else {
	    $fstype = "";
	}

	#
	# If there is a "copyfrom" attribute then we are creating a copy
	# of an existing blockstore.
	#
	my $srcbs = $self->GetAttribute("copyfrom");

	#
	# XXX hack, hack
	# XXX this doesn't belong here
	#
	if ($fstype || $srcbs) {
	    print STDERR "NOTE: " .
		($srcbs ? "Dataset copy" : "FS creation") .
		" could take 5 minutes or longer, ";
	    if ($interruptable) {
		print STDERR "please be patient!\n";
	    } else {
		print STDERR "disabling SIGINT.\n";
	    }
	}

	#
	# Call the blockstore control program to handle all things
	# blockstore related (e.g., the actual allocation of storage
	# on the storage servers).
	#
	my $idx = $self->lease_idx();
	my $cmd = defined($srcbs) ?
	    "$BSCONTROL copy $srcbs lease-$idx" :
	    "$BSCONTROL -l $idx -s $size $fstype create lease-$idx";

	my $rv;
	if (!$interruptable) {
	    local $SIG{INT} = "IGNORE";
	    $rv = system($cmd);
	} else {
	    $rv = system($cmd);
	}
	if ($rv) {
	    print STDERR "$self: AllocResources: could not allocate storage.\n";
	    # XXX why is this here? Should already be unapproved.
	    # XXX perhaps because of the potential long duration of bscontrol
	    #     and non-atomicity allowing for a change of state? Seems
	    #     like that should be the caller's concern.
	    $self->UpdateState("unapproved");

	    return LEASE_ERROR_ALLOCFAILED();
	}

	#
	# XXX create an initial snapshot too. If this fails, we just warn;
	# a snapshot can always be created with bscontrol later.
	#
	if (!$self->IsExclusiveUse()) {
	    my $tstamp = time();
	    $rv = system("$BSCONTROL snapshot lease-$idx $tstamp");
	    if ($rv) {
		print STDERR "$self: AllocResources: ".
		    "WARNING: could not create initial snapshot.\n";
	    } else {
		$self->SetAttribute("last_snapshot", $tstamp, "integer");
	    }
	}

	# Clear the "copyfrom" attribute as an indicator we are done
	if (defined($srcbs)) {
	    $self->DeleteAttribute("copyfrom");
	}
    }

    # It all worked!
    $self->UpdateState($state);

    return 0;
}

sub DeallocResources($) {
    my ($self) = @_;

    return LEASE_ERROR_FAILED()
	if (!ref($self));

    #
    # If lease is unapproved or failed, assume there is nothing to do.
    #
    if ($self->state() eq "unapproved" || $self->state eq "failed") {
	return 0;
    }

    #
    # For a dataset lease, we must free up the server storage.
    # XXX this should be in Lease::Blockstore object!
    #
    if ($self->type() =~ /dataset$/) {
	my $idx = $self->lease_idx();
	my $sarg = "";

	#
	# For efficiency, lookup the server in the blockstores table.
	# Saves gathering info from every storage server.
	#
	my $bstore = Blockstore->LookupByLease($idx);
	if ($bstore) {
	    $sarg = "-S " . $bstore->node_id();
	}

	#
	# Call the blockstore control program to handle all things blockstore
	# related (e.g., the actual deallocation of storage on the servers).
	#
	if (system("$BSCONTROL $sarg destroy lease-$idx")) {
	    print STDERR
		"$self: DeallocResources: could not deallocate storage.\n";
	    return LEASE_ERROR_FAILED();
	}
    }

    $self->UpdateState("unapproved");
    $self->SetLastUsedTime(0);
    return 0;
}

sub CreateResourceSnapshot($$) {
    my ($self,$exclusive) = @_;

    return LEASE_ERROR_FAILED()
	if (!ref($self));

    #
    # If lease is unapproved or failed, assume there is nothing to do.
    #
    if ($self->state() eq "unapproved" || $self->state eq "failed") {
	return 0;
    }

    my $tstamp = time();

    #
    # For a dataset lease, we call over to the server to take a snapshot
    # XXX this should be in Lease::Blockstore object!
    #
    if ($self->type() =~ /dataset$/) {
	my $idx = $self->lease_idx();
	my $sarg = "";

	#
	# For efficiency, lookup the server in the blockstores table.
	# Saves gathering info from every storage server.
	#
	my $bstore = Blockstore->LookupByLease($idx);
	if ($bstore) {
	    $sarg = "-S " . $bstore->node_id();
	}

	#
	# If we want an "exclusive" snapshot, we remove all others.
	# We don't return any errors, this is just best effort.
	#
	if (system("$BSCONTROL $sarg desnapshot lease-$idx")) {
	    print STDERR "$self: CreateResourceSnapshot: ".
		"WARNING! Could not remove all old storage snapshots\n";
	}

	#
	# Call the blockstore control program to handle all things blockstore
	# related (e.g., the actual deallocation of storage on the servers).
	#
	if (system("$BSCONTROL $sarg snapshot lease-$idx $tstamp")) {
	    print STDERR "$self: CreateResourceSnapshot: ".
		"Could not snapshot storage.\n";
	    return LEASE_ERROR_FAILED();
	}
    }

    $self->SetAttribute("last_snapshot", $tstamp, "integer");
    return 0;
}

sub DestroyResourceSnapshot($$) {
    my ($self,$tstamp) = @_;

    return LEASE_ERROR_FAILED()
	if (!ref($self));

    #
    # If lease is unapproved or failed, assume there is nothing to do.
    #
    if ($self->state() eq "unapproved" || $self->state eq "failed") {
	return 0;
    }

    #
    # For a dataset lease, we call over to the server to take a snapshot
    # XXX this should be in Lease::Blockstore object!
    #
    if ($self->type() =~ /dataset$/) {
	my $idx = $self->lease_idx();
	my $sarg = "";

	#
	# For efficiency, lookup the server in the blockstores table.
	# Saves gathering info from every storage server.
	#
	my $bstore = Blockstore->LookupByLease($idx);
	if ($bstore) {
	    $sarg = "-S " . $bstore->node_id();
	}

	# If tstamp is not set, then clear all snapshots
	$tstamp = ""
	    if (!defined($tstamp));

	#
	# Call the blockstore control program to handle all things blockstore
	# related (e.g., the actual deallocation of storage on the servers).
	#
	# Note that we only fail if bscontrol fails to remove a specific
	# snapshot. Otherwise it may have failed due to snapshots that
	# were still in use.
	#
	if (system("$BSCONTROL $sarg desnapshot lease-$idx $tstamp") &&
	    $tstamp ne "") {
	    print STDERR
		"$self: DestroySnapshot: could not remove storage snapshot(s).\n";
	    return LEASE_ERROR_FAILED();
	}
    }

    $self->DeleteAttribute("last_snapshot");
    return 0;
}

sub LastResourceSnapshot($) {
    my ($self) = @_;

    # XXX we don't call over to the server to get a list--too expensive
    my $tstamp = $self->GetAttribute("last_snapshot");

    return (defined($tstamp) ? int($tstamp) : 0);
}

sub HasResourceSnapshot($) {
    my ($self) = @_;

    return ($self->LastResourceSnapshot() != 0);
}

#
# Extend (renew) a lease by the indicated amount.
# Also increments the renewal count and transitions the lease back into
# the valid state. Returns 0 on success, non-zero otherwise.
#
# N.B. The caller is responsible for locking the lease during this operation.
#
sub Extend($$)
{
    my ($self,$addtime) = @_;

    #
    # Lease must be in some state other than unapproved/valid but that
    # can transition to valid.
    #
    my $cstate = $self->state();
    if ($cstate eq "unapproved" || $cstate eq "failed" || $cstate eq "valid" ||
	!$self->ValidTransition("valid")) {
	print STDERR
	    "$self: Extend: cannot transition from '$cstate' -> 'valid'\n";
	return LEASE_ERROR_FAILED();
    }

    #
    # If the expiration time has been reached, extend it by the
    # indicated time (from the current time).
    #
    if ($self->IsExpired()) {
	if ($self->SetEndTime(time() + $addtime)) {
	    print STDERR
		"$self: Extend: could not extend lease\n";
	    return LEASE_ERROR_FAILED();
	}
    }
    #
    # Otherwise we assume that the lease went idle and we bump
    # the last_used time so it is no longer idle.
    #
    else {
	if ($self->BumpLastUsed()) {
	    print STDERR
		"$self: Extend: could not extend lease\n";
	    return LEASE_ERROR_FAILED();
	}
    }

    #
    # Increment the renewal count and put lease back into the valid state.
    #
    my $idx = $self->idx();
    DBQueryWarn("update project_leases set renewals=renewals+1 ".
		"where lease_idx=$idx")
	or return LEASE_ERROR_FAILED();
    if ($self->UpdateState("valid")) {
	print STDERR
	    "$self: Extend: could not extend lease\n";
	return LEASE_ERROR_FAILED();
    }

    return 0;
}

#
# Return a hashref of sitevars for the indicated lease type.
# Why not let the caller make individual GetSiteVar calls? Well, efficiency
# mostly. There are a lot of em, and they are generally needed all together.
#
# XXX by having them all fetched from here, I can also avoid putting these
# into the database until we decide for sure on the right set; i.e., by using
# LEASE_VAR_DEFAULTS.
#
sub SiteVars($$) {
    my ($class, $ltype) = @_;
    my %vars = ();

    if (!grep {/^$ltype$/} @LEASE_TYPES) {
	return undef;
    }

    # XXX tmp til sitevariables are settled upon
    foreach my $var (@LEASE_VARS) {
	if (exists($LEASE_VAR_DEFAULTS{"$ltype/$var"})) {
	    $vars{$var} = $LEASE_VAR_DEFAULTS{"$ltype/$var"};
	}
    }

    my $hdr = "storage/$ltype";
    my $query = DBQueryWarn("select name,value,defaultvalue ".
			    "from sitevariables where name like '$hdr/%%'");
    return undef
	if (!$query);

    while (my ($var,$val,$defval) = $query->fetchrow_array()) {
	if ($var =~ /^$hdr\/([-\w]+)$/) {
	    $vars{$1} = defined($val) ? $val : $defval;
	}
    }

    # Convert day values to seconds
    foreach my $n ("maxlease", "maxidle", "graceperiod", "extendperiod") {
	if (exists($vars{$n})) {
	    $vars{$n} = int($vars{$n} * (24 * 60 * 60));
	}
    }

    return \%vars;
}

#
# Check to see if a lease type is a valid one
#
sub _validLeaseType($) {
    my ($type) = @_;

    # Make sure something was actually passed in.
    if (!defined($type) || !$type) {
	return 0;
    }

    if (grep {/^$type$/} @LEASE_TYPES) {
	return 1;
    }

    # Not valid (not found in @LEASE_TYPES).
    return 0;
}

#
# Return a list of all leases (optionally of a particular type).
#
sub AllLeases($;$)
{
    my ($class, $type)  = @_;
    my @pleases = ();

    my $tclause = "";
    if (defined($type)) {
	if (_validLeaseType($type)) {
	    $tclause = "where type='$type'";
	} else {
	    print STDERR "Lease->AllLeases: Invalid lease type: $type\n";
	    return undef;
	}
    }
    
    my $query_result =
	DBQueryWarn("select lease_idx from project_leases $tclause".
		    " order by lease_idx");
    
    return ()
	if (!$query_result || !$query_result->numrows);

    while (my ($lease_idx) = $query_result->fetchrow_array()) {
	my $lease = Lookup($class, $lease_idx);

	# Something went wrong?
	return ()
	    if (!defined($lease));
	
	push(@pleases, $lease);
    }
    return @pleases;
}

#
# Return a list of all leases belonging to a particular project.
# Optionally, only those of the given type.
# The list will be ordered by increasing lease_idx.
#
sub AllProjectLeases($$;$)
{
    my ($class, $pid, $type)  = @_;
    my @pleases = ();
    
    return undef
	if !defined($pid);

    if (ref($pid) eq "Project") {
	$pid = $pid->pid();
    }
    
    my $tclause = "";
    if (defined($type)) {
	if (_validLeaseType($type)) {
	    $tclause = "and type='$type'";
	} else {
	    print STDERR "Lease->AllProjectLeases: Invalid lease type: $type\n";
	    return undef;
	}
    }

    my $query_result =
	DBQueryWarn("select lease_idx from project_leases where ".
		    "pid='$pid' $tclause order by lease_idx");
    
    return ()
	if (!$query_result || !$query_result->numrows);

    while (my ($lease_idx) = $query_result->fetchrow_array()) {
	my $lease = Lookup($class, $lease_idx);

	# Something went wrong?
	return ()
	    if (!defined($lease));
	
	push(@pleases, $lease);
    }
    return @pleases;
}

#
# Return a list of all leases belonging to a particular group.
# Optionally, only those of the given type.
# The list will be ordered by increasing lease_idx.
#
sub AllGroupLeases($$;$)
{
    my ($class, $group, $type)  = @_;
    my @gleases = ();
    
    return undef
	if !defined($group);

    if (ref($group) ne "Group") {
	print STDERR "Lease->AllGroupLeases: Input object must be of type \"Group\"";
	return undef;
    }
    
    my $pid = $group->pid();
    my $gid = $group->gid();

    my $tclause = "";
    if (defined($type)) {
	if (_validLeaseType($type)) {
	    $tclause = "and type='$type'";
	} else {
	    print STDERR "Lease->AllGroupLeases: Invalid lease type: $type\n";
	    return undef;
	}
    }

    my $query_result =
	DBQueryWarn("select lease_idx from project_leases where ".
		    "pid='$pid' and gid='$gid' $tclause order by lease_idx");
    
    return ()
	if (!$query_result || !$query_result->numrows);

    while (my ($lease_idx) = $query_result->fetchrow_array()) {
	my $lease = Lookup($class, $lease_idx);

	# Something went wrong?
	return ()
	    if (!defined($lease));
	
	push(@gleases, $lease);
    }
    return @gleases;
}


#
# Grab all leases belonging to a particular user
#
sub AllUserLeases($$;$)
{
    my ($class, $uid, $type)  = @_;
    my @uleases = ();
    
    return undef
	if !defined($uid);

    # If uid is a User object extract the user name
    if (ref($uid) eq "User") {
	$uid = $uid->uid();
    }

    my $tclause = "";
    if (defined($type)) {
	if (_validLeaseType($type)) {
	    $tclause = "and type='$type'";
	} else {
	    print STDERR "Lease->AllUserLeases: Invalid lease type: $type\n";
	    return undef;
	}
    }
    
    my $query_result =
	DBQueryWarn("select lease_idx from project_leases".
		    " where owner_uid='$uid' $tclause");
    
    return ()
	if (!$query_result || !$query_result->numrows);

    while (my ($lease_idx) = $query_result->fetchrow_array()) {
	my $lease = Lookup($class, $lease_idx);

	# Something went wrong?
	return ()
	    if (!defined($lease));
	
	push(@uleases, $lease);
    }
    return @uleases;
}

#
# Return a list of leases for which a user OR group has access.  
#
# Permissions are determined as follows:
# * The owner of a lease always has full (RW) access
# * Users in a project with group_root or above trust always have full (RW) 
#   access to leases associated with that project.
# * Explicitly granted per-user and per-project permissions are extracted 
#   from the lease_permissions tables.
# * Global permissions (only RO).
#
# Note: Greatest privilege is returned when a principle matches more than
#       one lease permissions condition.
#
# Note: Non-local users will only be allowed access to leases that have
#       global "anonymous read-only" permissions enabled on them.
#
# Arguments:
# * principal - User OR Group object to lookup lease access for.
# * type - Optional lease type selector.  Restrict results to this type 
#          of lease.
#
# Returns: Array of lease objects the given principal (user or group) has 
#          access to.  To each of these lease objects, an "allow_modify"
#          boolean is set, accessible via $leaseobj->allow_modify().
#
sub AllowedLeases($$;$) {
    my ($class, $principal, $type)  = @_;
    my $wclause = "";
    my %lease_indexes = ();
    my @leases = ();

    # Gather up lease permissions for Users and Groups.  The logic for users
    # is much more complicated...
    if (ref($principal) eq "User") {
	my $uid = $principal->uid();
	my $uid_idx = $principal->uid_idx();
	my @ugroups = ();
	my $gid_idx_list = "";
	my %admin_pids = ();
	my $admin_pid_list = "";

	# Get group information for input User.
	if ($principal->GroupMembershipList(\@ugroups) == 0 && 
	    int(@ugroups) > 0) {
	    # Determine set of projects for which the input User has
	    # group_root or above trust.
	    foreach my $group (@ugroups) {
		if ($group->IsProjectGroup() &&
		    TBMinTrust($group->Trust($principal),
			       PROJMEMBERTRUST_GROUPROOT())) {
		    $admin_pids{$group->pid()} = 1;
		}
	    }
	    if (@ugroups) {
		$gid_idx_list = join "','", map {$_->gid_idx()} @ugroups;
		$gid_idx_list = "'" . $gid_idx_list . "'";
	    }
	    if (keys %admin_pids) {
		$admin_pid_list = join "','", keys %admin_pids;
		$admin_pid_list = "'" . $admin_pid_list . "'";
	    }
	} else {
	    print STDERR "Lease->AllowedLeases: Failed to lookup ".
		"group membership for user: $principal\n";
	    return undef;
	}

	# Local user stuff.
	# XXX: This needs revision based on how we should handle non-local
	#      Geni-type users.
	if ($principal->IsLocal()) {
	    # Users have full access to leases they own, and for leases in
	    # projects that they have group_root (or above) trust in.
	    my $uclause = "where owner_uid='$uid'";
	    if ($admin_pid_list) {
		$uclause .= " or pid in ($admin_pid_list)";
	    }
	    my $query_result =
		DBQueryWarn("select lease_idx from project_leases".
			    " $uclause order by lease_idx"); 
	    if ($query_result) {
		while (my ($lease_idx) = $query_result->fetchrow_array()) {
		    $lease_indexes{$lease_idx} = 1; # "modify rights" == 1
		}
	    }

	    # Conjure "where" clause for lease_permissions table query below.
	    #
	    # User is local to site - look for several conditions:
	    # * Any global permissions.
	    # * Leases with user permissions matching input user.
	    # * Leases with group permissions matching any group user is in.
	    $wclause = "where (permission_type='global'".
		       " or (permission_type='user' and".
		       "     permission_idx='$uid_idx')";
	    if ($gid_idx_list) {
		$wclause .=
		       " or (permission_type='group' and".
		       "     permission_idx in ($gid_idx_list))";
	    }
	    $wclause .= ")";
	} else {
	    # User is non-local - only look for anonymous RO permissions.
	    my $idxstr = GLOBAL_PERM_ANON_RO_IDX();
	    $wclause = "where (permission_type='global' and".
		       " permission_idx='$idxstr')";
	}
    }
    # The case for Group principals is easy: just construct a "where"
    # clause for the lease_permissions table query below.
    elsif (ref($principal) eq "Group") {
	my $gid_idx = $principal->gid_idx();
	$wclause = "where (permission_type='global'".
	           " or (permission_type='group' and".
		   "     permission_idx='$gid_idx'))";
    }
    # Input principal argument must be either a User or Group object.
    else {
	print STDERR "Lease->AllowedLeases: Unknown access object: ".
	             "$principal\n";
	return undef;
    }

    # Build up type selector clause, if requested.
    my $tclause = "";
    if (defined($type)) {
	if (_validLeaseType($type)) {
	    $tclause = "and pl.type='$type'";
	} else {
	    print STDERR "Lease->AllowedLeases: Invalid lease type: $type\n";
	    return undef;
	}
    }

    # Grab all lease permissions entries that pertain to the user or project
    my $query_result =
	DBQueryWarn("select lease_idx, allow_modify".
		    " from lease_permissions".
		    " $wclause $tclause order by lease_idx");
    
    # Loop through result set and process.  Augment permissions for
    # lease owners and users with group_root in lease's owning project.
    # There will be duplicate lease_idx values in the results if there
    # are multiple entries for the lease in the lease_permissions table.
    # Handle this by storing the result set in a hash table.
    if ($query_result) {
	while (my ($lease_idx, $modify) = $query_result->fetchrow_array()) {
	    if (!exists($lease_indexes{$lease_idx})) {
		$lease_indexes{$lease_idx} = 0;
	    }
	    # If _any_ permissions found for a lease allow for
	    # modification, then it is allowed (greatest privilege for
	    # the same lease wins out).
	    $modify = ($modify || $lease_indexes{$lease_idx}) ? 1 : 0;
	    $lease_indexes{$lease_idx} = $modify;
	}
    }

    # Fetch all of the leases and send them back to caller.
    while (my ($lease_idx, $modify) = each %lease_indexes) {
	my $lease = Lookup($class, $lease_idx);
	if (!$lease) {
	    print STDERR "Lease->AllowedLeases: unable to lookup lease with index $lease_idx!\n";
	    next;
	}
	$lease->allow_modify($modify);
	push (@leases, $lease);
    }

    return @leases;
}

#
# Update fields in the project_leases table, as requested.
#
sub Update($$)
{
    my ($self, $argref) = @_;

    # Must be a real reference. 
    return LEASE_ERROR_FAILED()
	if (! ref($self));

    my $idx = $self->idx();
    my @sets   = ();

    foreach my $key (keys(%{$argref})) {
	my $val = $argref->{$key};

	# Don't let caller update the lease's index - that would be bad.
	return LEASE_ERROR_FAILED()
	    if ($key eq "lease_idx");

	# Treat NULL special.
	push (@sets, "${key}=" . ($val eq "NULL" ?
				  "NULL" : DBQuoteSpecial($val)));
    }

    my $query = "update project_leases set " . join(",", @sets) .
	" where lease_idx='$idx'";

    return LEASE_ERROR_FAILED()
	if (! DBQueryWarn($query));

    return Refresh($self);
}

#
# Refresh a class instance by reloading from the DB.
#
sub Refresh($)
{
    my ($self) = @_;

    return LEASE_ERROR_FAILED()
	if (! ref($self));

    my $idx = $self->idx();

    my $query_result =
	DBQueryWarn("select * from project_leases".
		    " where lease_idx='$idx'");

    return LEASE_ERROR_FAILED()
	if (!$query_result);
    return LEASE_ERROR_GONE()
	if (!$query_result->numrows);

    $self->{"DBROW"}    = $query_result->fetchrow_hashref();
    $self->{"ATTRS"}    = undef;

    return 0;
}

#
# Flush from our little cache, as for the lease daemon.
#
sub Flush($)
{
}

sub FlushAll($)
{
}

#
# Update to the given state and bump timestamp.
#
sub UpdateState($$) {
    my ($self, $state) = @_;

    return LEASE_ERROR_FAILED()
	if (!ref($self));

    return LEASE_ERROR_FAILED()
	if (!defined($state));

    if (!grep {/^$state$/} @LEASE_STATES) {
	print STDERR "Lease->UpdateState: Invalid state: $state\n";
	return LEASE_ERROR_FAILED();
    }

    my $idx = $self->idx();
    DBQueryWarn("update project_leases set state='$state',statestamp=NOW() ".
		"where lease_idx=$idx")
	or return LEASE_ERROR_FAILED();

    $self->Refresh();
    return 0;
}

#
# Bump last_used column
#
sub BumpLastUsed($) {
    my ($self) = @_;

    return LEASE_ERROR_FAILED()
	if (!ref($self));

    my $idx = $self->idx();
    DBQueryWarn("update project_leases set last_used=NOW() where lease_idx=$idx");
    $self->Refresh();
    return 0;
}

#
# Set last_used to a specific time
#
sub SetLastUsedTime($$) {
    my ($self, $ntime) = @_;

    return LEASE_ERROR_FAILED()
	if (!ref($self));

    if ($ntime > time()) {
	print STDERR "Lease->SetLastUsedTime: Can't set lease last-used time in the future.\n";
	return LEASE_ERROR_FAILED();
    }
    my $estr;
    if ($ntime == 0 || $ntime < $self->inception()) {
	$estr = "DEFAULT(last_used)";
    } else {
	$estr = "FROM_UNIXTIME($ntime)";
    }

    my $idx = $self->idx();
    DBQueryWarn("update project_leases set last_used=$estr where lease_idx=$idx")
	or return LEASE_ERROR_FAILED();

    $self->Refresh();
    return 0;
}

#
# Bump last_checked column
#
sub BumpLastChecked($) {
    my ($self) = @_;

    return LEASE_ERROR_FAILED()
	if (!ref($self));

    my $idx = $self->idx();
    DBQueryWarn("update project_leases set last_checked=NOW() where lease_idx=$idx");
    $self->Refresh();
    return 0;
}

#
# Add time to an existing lease
#
sub AddTime($$) {
    my ($self, $ntime) = @_;

    return LEASE_ERROR_FAILED()
	if (!ref($self));

    if ($ntime !~ /^\d+$/ || $ntime < 1) {
	print STDERR "Lease->AddTime: Time to add must be a positive number of seconds.\n";
	return LEASE_ERROR_FAILED()
    }

    my $idx = $self->idx();
    my $newend = $self->lease_end() + $ntime;
    DBQueryWarn("update project_leases set lease_end=FROM_UNIXTIME($newend) where lease_idx=$idx")
	or return LEASE_ERROR_FAILED();

    $self->Refresh();
    return 0;
}

#
# Set a specific lease end time.
# A value of zero means "unlimited" which is represented by a very large
# value in the DB (the default value).
#
sub SetEndTime($$) {
    my ($self, $ntime) = @_;

    return LEASE_ERROR_FAILED()
	if (!ref($self));

    if ($ntime != 0 && $ntime < time()) {
	print STDERR "Lease->SetEndTime: Can't move lease end time into the past.\n";
	return LEASE_ERROR_FAILED();
    }

    my $estr;
    if ($ntime == 0) {
	$estr = "DEFAULT(lease_end)";
    } else {
	$estr = "FROM_UNIXTIME($ntime)";
    }

    my $idx = $self->idx();
    DBQueryWarn("update project_leases set lease_end=$estr where lease_idx=$idx")
	or return LEASE_ERROR_FAILED();

    $self->Refresh();
    return 0;
}

#
# Deterimines if a lease can transtion into the indicated state.
# Returns 1 if so, 0 otherwise.
#
sub ValidTransition($$) {
    my ($self,$nstate) = @_;

    return 0
	if (!ref($self));

    my $state = $self->state();
    return (exists($LEASE_TRANSITIONS{$state}{$nstate}) ? 1 : 0);
}

#
# Check to see if the lease has expired.
#
sub IsExpired($) {
    my ($self) = @_;
    
    if ($self->lease_end() <= time()) {
	return 1;
    }

    return 0;
}

#
# Check Lease permissions for a specific user.
#
sub AccessCheck($$$) {
    my ($self, $user, $access_type) = @_;
    my $user_access = 0;

    if (ref($user) ne "User") {
	print STDERR "Lease->AccessCheck: 'user' argument must be a valid User object.\n";
	return 0;
    }

    if ($access_type < LEASE_ACCESS_MIN() || 
	$access_type > LEASE_ACCESS_MAX()) {
	print STDERR "Lease->AccessCheck: Invalid access type: $access_type\n";
	return 0;
    }

    # Testbed admins have all privs.
    if ($user->IsAdmin() || $UID == 0 || $UID eq "root") {
	return 1;
    }

    # Some special cases
    if ($user->uid() eq $self->owner()) {
	# Owning UID has all permissions.
	return 1;
    }

    # Need this for trust checks below.
    my $pid = $self->pid();
    my $gid = $self->gid();
    $gid = $pid
	if ($gid eq "");
    my $group = Group->Lookup($pid, $gid);
    if (!$group) {
	print STDERR "Could not find group $pid/$gid!\n";
	return 0;
    }

    # Members of the owning project have some implicit permissions, depending
    # on their project trust.
    my $gtrust = $group->Trust($user);
    if (TBMinTrust($gtrust, PROJMEMBERTRUST_GROUPROOT())) {
	return 1;
    }
    elsif (TBMinTrust($gtrust, PROJMEMBERTRUST_LOCALROOT())) {
    	$user_access = LEASE_ACCESS_READ();
    }
    elsif (TBMinTrust($gtrust, PROJMEMBERTRUST_USER())) {
	$user_access = LEASE_ACCESS_READINFO();
    }

    my $idx = $self->idx();
    my $qres = DBQueryWarn("select permission_type,permission_idx,allow_modify from lease_permissions where lease_idx=$idx");
    return 0
	if (!defined($qres));

    # If nothing was returned, just pass back the result based on the
    # special checks above.
    return (TBMinTrust($user_access, $access_type) ? 1 : 0)
	if (!$qres->numrows);

    while (my ($perm_type, $perm_idx, $modify) = $qres->fetchrow_array()) {
	if ($perm_type eq "global") {
	    # A lease with anonymous global read-only access is available
	    # to everyone.  Force entry to be read-only.
	    if ($perm_idx == GLOBAL_PERM_ANON_RO_IDX()) {
		$modify = 0; # Force!
	    }
	    # A lease with global read-only access for registered users
	    # requires that the incoming user be a "real" user.  I.e.,
	    # not the geni user.  Force entry to be read-only.
	    elsif ($perm_idx == GLOBAL_PERM_USER_RO_IDX()) {
		next unless $user->IsLocal();
		$modify = 0; # Force!
	    }
	    else {
		# Unknown global permissions entry - skip!
		print STDERR "Lease->AccessCheck: Unknown global permission type: $perm_idx\n";
		next;
	    }
	} elsif ($perm_type eq "group") {
	    # If the user is a member of this group and has a minimum of
	    # trust, then give them the access listed in the db.
	    my $dbgroup = Group->Lookup($perm_idx);
	    next unless (defined($dbgroup) && 
			 TBMinTrust($dbgroup->Trust($user), 
				    PROJMEMBERTRUST_LOCALROOT()));
	} elsif ($perm_type eq "user") {
	    # If this is a user permission, and the incoming user arg matches,
	    # then give them the privileges listed in this entry.
	    my $dbusr = User->Lookup($perm_idx);
	    next unless (defined($dbusr) && $dbusr->SameUser($user));
	} else {
	    print STDERR "Lease->AccessCheck: Unknown permission type in DB for lease index $idx: $perm_type\n";
	    return 0;
	}

	# Take the greater of the access found.
	my $this_access = 
	    $modify ? LEASE_ACCESS_MODIFY() : LEASE_ACCESS_READ();
	$user_access = $this_access
	    if ($this_access > $user_access);
    }

    return (TBMinTrust($user_access, $access_type) ? 1 : 0);
}

#
# Grant permission to access a Lease.
#
sub GrantAccess($$$)
{
    my ($self, $target, $modify) = @_;
    $modify = ($modify ? 1 : 0);

    my $idx      = $self->idx();
    my $lease_id = $self->lease_id();
    my ($perm_idx, $perm_id, $perm_type);

    if (ref($target) eq "User") {
	$perm_idx  = $target->uid_idx();
	$perm_id   = $target->uid();
	$perm_type = "user";
    } 
    elsif (ref($target) eq "Group") {
	$perm_idx  = $target->gid_idx();
	$perm_id   = $target->pid() . "/" . $target->gid();
	$perm_type = "group";
    } 
    elsif (ref($target) eq "Project") {
	$perm_idx  = $target->gid_idx();
	$perm_id   = $target->pid() . "/" . $target->gid();
	$perm_type = "group";
    } 
    elsif ($target eq GLOBAL_PERM_ANON_RO()) {
	$perm_idx  = GLOBAL_PERM_ANON_RO_IDX();
	$perm_id   = GLOBAL_PERM_ANON_RO();
	$perm_type = "global";
	$modify = 0; # Force
    }
    elsif ($target eq GLOBAL_PERM_USER_RO()) {
	$perm_idx  = GLOBAL_PERM_USER_RO_IDX();
	$perm_id   = GLOBAL_PERM_USER_RO();
	$perm_type = "global";
	$modify = 0; # Force
    }
    else {
	print STDERR "Lease->GrantAccess: Bad target: $target\n";
	return LEASE_ERROR_FAILED();
    }

    return LEASE_ERROR_FAILED()
	if (!DBQueryWarn("replace into lease_permissions set ".
			 "  lease_idx=$idx, lease_id='$lease_id', ".
			 "  permission_type='$perm_type', ".
			 "  permission_id='$perm_id', ".
			 "  permission_idx='$perm_idx', ".
			 "  allow_modify='$modify'"));
    return 0;
}


#
# Revoke permission for a lease.
#
sub RevokeAccess($$)
{
    my ($self, $target) = @_;

    my $idx        = $self->idx();
    my ($perm_idx, $perm_type);

    if (ref($target) eq "User") {
	$perm_idx  = $target->uid_idx();
	$perm_type = "user";
    }
    elsif (ref($target) eq "Group") {
	$perm_idx  = $target->gid_idx();
	$perm_type = "group";
    }
    elsif (ref($target) eq "Project") {
	$perm_idx  = $target->gid_idx();
	$perm_type = "group";
    }
    elsif ($target eq GLOBAL_PERM_ANON_RO()) {
	$perm_idx  = GLOBAL_PERM_ANON_RO_IDX();
	$perm_type = "global";
    }
    elsif ($target eq GLOBAL_PERM_USER_RO()) {
	$perm_idx  = GLOBAL_PERM_USER_RO_IDX();
	$perm_type = "global";
    }
    else {
	print STDERR "Lease->RevokeAccess: Bad target: $target\n";
	return LEASE_ERROR_FAILED();
    }

    return LEASE_ERROR_FAILED()
	if (!DBQueryWarn("delete from lease_permissions ".
			 "where lease_idx=$idx and ".
			 "  permission_type='$perm_type' and ".
			 "  permission_idx='$perm_idx'"));
    return 0;
}

# Convience functions for Geni interface.
sub IsPermRO($)
{
    my ($self) = @_;
    my $idx       = $self->idx();
    my $perm_idx  = GLOBAL_PERM_ANON_RO_IDX();
    my $perm_type = "global";

    my $qres =
	DBQueryWarn("select * from lease_permissions ".
		    "where lease_idx=$idx and permission_idx='$perm_idx' and ".
		    "      permission_type='$perm_type'");
    return 0
	if (!$qres || !$qres->numrows);
    return 1;
}
sub IsAnonRO($)
{
    my ($self) = @_;
    my $idx       = $self->idx();
    my $perm_idx  = GLOBAL_PERM_USER_RO_IDX();
    my $perm_type = "global";

    my $qres =
	DBQueryWarn("select * from lease_permissions ".
		    "where lease_idx=$idx and permission_idx='$perm_idx' and ".
		    "      permission_type='$perm_type'");
    return 0
	if (!$qres || !$qres->numrows);
    return 1;
}
#
# Load attributes if not already loaded.
#
sub LoadAttributes($)
{
    my ($self) = @_;

    return LEASE_ERROR_FAILED()
	if (!ref($self));

    return 0
	if (defined($self->{"ATTRS"}));

    #
    # Get the attribute array.
    #
    my $idx = $self->idx();
    
    my $query_result =
	DBQueryWarn("select attrkey,attrval,attrtype".
		    "  from lease_attributes ".
		    "  where lease_idx='$idx'");

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
    
    my $lease_id  = $self->lease_id();
    my $pid = $self->pid();
    my $gid = $self->gid();
    my $uid = $self->owner();

    return "[Lease: $pid/$gid/$lease_id/$uid]";
}

#
# Look for an attribute.
#
sub GetAttribute($$;$$$)
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
	$$pattrtype = undef
	    if (defined($pattrtype));
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
    $$pattrtype = undef
	if (defined($pattrtype));
    return LEASE_ERROR_FAILED();
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


#
# Set the value of an attribute
#
sub SetAttribute($$$;$)
{
    my ($self, $attrkey, $attrvalue, $attrtype) = @_;
    
    return LEASE_ERROR_FAILED()
	if (!ref($self));

    $self->LoadAttributes() == 0
	or return LEASE_ERROR_FAILED();

    $attrtype = "string"
	if (!defined($attrtype));
    my $safe_attrvalue = DBQuoteSpecial($attrvalue);
    my $idx = $self->idx();

    DBQueryWarn("replace into lease_attributes set ".
		"  lease_idx='$idx', attrkey='$attrkey', ".
		"  attrtype='$attrtype', attrval=$safe_attrvalue")
	or return LEASE_ERROR_FAILED();

    $self->{"ATTRS"}->{$attrkey} = {
	"key" => $attrkey,
	"value" => $attrvalue,
	"type" => $attrtype
    };

    return 0;
}

#
# Remove an attribute
#
sub DeleteAttribute($$) {
    my ($self, $attrkey) = @_;

    return LEASE_ERROR_FAILED()
	if (!ref($self));

    my $idx = $self->idx();
    DBQueryWarn("delete from lease_attributes where lease_idx=$idx and attrkey='$attrkey'");

    delete($self->{"ATTRS"}->{$attrkey})
	if (exists($self->{"ATTRS"}->{$attrkey}));

    return 0;
}

#
# Lock and Unlock
#
sub Lock($)
{
    my ($self) = @_;

    # Must be a real reference. 
    return LEASE_ERROR_FAILED()
	if (! ref($self));

    # Already locked?
    if ($self->GotLock()) {
	return 0;
    }

    return LEASE_ERROR_FAILED()
	if (!DBQueryWarn("lock tables project_leases write"));

    my $idx = $self->idx();

    my $query_result =
	DBQueryWarn("update project_leases set locked=now(),locker_pid=$PID " .
		    "where lease_idx=$idx and locked is null");

    if (! $query_result ||
	$query_result->numrows == 0) {
	DBQueryWarn("unlock tables");
	return LEASE_ERROR_FAILED();
    }
    DBQueryWarn("unlock tables");
    $self->{'LOCKED'} = time();
    $self->{'LOCKER_PID'} = $PID;
    return 0;
}

sub Unlock($)
{
    my ($self) = @_;

    # Must be a real reference. 
    return LEASE_ERROR_FAILED()
	if (! ref($self));

    my $idx   = $self->idx();

    return LEASE_ERROR_FAILED()
	if (! DBQueryWarn("update project_leases set locked=null,locker_pid=0 " .
			  "where lease_idx=$idx"));
    
    $self->{'LOCKED'} = 0;
    $self->{'LOCKER_PID'} = 0;
    return 0;
}

sub GotLock($)
{
    my ($self) = @_;

    return 1
	if ($self->{'LOCKED'} &&
	    $self->{'LOCKER_PID'} == $PID);
    
    return 0;
}

#
# Wait to get lock.
#
sub WaitLock($$;$)
{
    my ($self, $seconds, $verbose) = @_;
    my $forever = 0;
    my $interval = 5;

    # Must be a real reference. 
    return LEASE_ERROR_FAILED()
	if (! ref($self));

    $forever = 1
	if ($seconds <= 0);
    $verbose = 0
	if (!defined($verbose));
    $interval = $seconds
	if (!$forever && $seconds < $interval);

    while ($forever || $seconds > 0) {
	return 0
	    if ($self->Lock() == 0);

	# Sleep and try again.
	print STDERR
	    "$self: locked, waiting $interval seconds and trying again...\n"
	    if ($verbose);
	sleep($interval);
	$seconds -= $interval;

	#
	# Refresh our state since we slept for a non-trivial amount of time.
	# If there is an error, it probably means that the lease has been
	# deleted.
	#
	my $rv = $self->Refresh();
	return $rv
	    if ($rv);
    }
    # One last try.
    return $self->Lock();
}

sub TakeLock($)
{
    my ($self) = @_;
    my $idx    = $self->idx();

    my $query_result =
	DBQueryWarn("update project_leases set locked=now(),locker_pid=$PID " .
		    "where lease_idx=$idx");
    return -1
	if (!$query_result);

    $self->{'LOCKED'} = time();
    $self->{'LOCKER_PID'} = $PID;
    return 0;
}

#
# Load the project.
#
sub GetProject($)
{
    my ($self) = @_;

    # Must be a real reference. 
    return undef
	if (! ref($self));

    my $project = Project->Lookup($self->pid());
    
    if (! defined($project)) {
	print("*** WARNING: Could not lookup project object for $self!\n");
	return undef;
    }
    return $project;
}

#
# Load the Creator
#
sub GetCreator($)
{
    my ($self) = @_;

    # Must be a real reference. 
    return undef
	if (! ref($self));

    my $creator = User->Lookup($self->owner_uid());
    
    if (! defined($creator)) {
	print("*** WARNING: Could not lookup creator object for $self!\n");
	return undef;
    }
    return $creator;
}

#
# Lookup by origin, as for portal created leases.
#
sub LookupByAuthorityURN($$)
{
    my ($class, $urn) = @_;

    return undef
	if (! $PGENISUPPORT);    

    require GeniHRN;
    return undef
	if (!GeniHRN::IsValid($urn));
    
    my $safe_urn = DBQuoteSpecial($urn);
    
    my $query_result =
	DBQueryWarn("select lease_idx from lease_attributes ".
		    "where attrkey='authority_urn' and attrval=$safe_urn");
    return undef
	if (!$query_result || !$query_result->numrows);

    my ($lease_idx) = $query_result->fetchrow_array();
    return Lease->Lookup($lease_idx);
}

package Lease::Blockstore;
use base qw(Lease);

use libdb;
use libtestbed;
use English;
use Data::Dumper;
use overload ('""' => 'Stringify');

# _Always_ make sure that this 1 is at the end of the file...

1;
