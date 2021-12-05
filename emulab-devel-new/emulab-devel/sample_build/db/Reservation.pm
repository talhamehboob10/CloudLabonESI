#!/usr/bin/perl -wT
#
# Copyright (c) 2016-2021 University of Utah and the Flux Group.
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
package Reservation;

use strict;
use Exporter;
use vars qw(@ISA @EXPORT);

@ISA    = "Exporter";
@EXPORT = qw ( );

use English;
use Date::Parse;
use Data::Dumper;
use emdb;
use libtestbed;
use emutil;
use EmulabConstants;
use Project;
use User;
use Experiment;
use Node;
use NodeType;
use POSIX qw(strftime);
use overload ('""' => 'Stringify');

# Configure variables
my $TB		= "/users/mshobana/CloudLabonESI/emulab-devel-new/emulab-devel/sample_build";
my $PGENISUPPORT= 1;

my %cache = ();
BEGIN { use emutil; emutil::AddCache(\%cache); }

sub FlushAll($)
{
    my ($class) = @_;

    %cache = ();
}

sub CreateCommon($$$$$$$$)
{
    my ($class, $pid, $eid, $uid, $start, $end, $type, $nodes) = @_;
    my $uid_idx;
    my $project;
    
    if( defined( $pid ) ) {
	$project = Project->Lookup( $pid );
	if( !defined( $project ) ) {
	    print STDERR "Res->CreateCommon: no DB record for project: $pid\n";
	    return undef;
	}
    }

    if( defined( $uid ) ) {
	my $user = User->Lookup( $uid );
	if (!defined($user)) {
	    print STDERR "Res->CreateCommon: no DB record for user: $uid\n";
	    return undef;
	}
	$uid_idx = $user->uid_idx();
    }
    
    my $self               = {};
    $self->{'PID'}         = $pid;
    $self->{'PID_IDX'}     = defined( $pid ) ? $project->pid_idx() : undef;
    $self->{'EID'}         = $eid;
    $self->{'START'}       = $start;
    $self->{'END'}         = $end;
    $self->{'TYPE'}        = $type;
    $self->{'NODES'}       = $nodes;
    $self->{'UID'}         = $uid,
    $self->{'UID_IDX'}     = $uid_idx,
    $self->{'NOTES'}       = undef;
    $self->{'ADMIN_NOTES'} = undef;
    $self->{'APPROVED'}    = undef;
    $self->{'APPROVER'}    = undef;
    $self->{'UUID'}        = undef;
    $self->{'CANCEL'}      = undef;
	
    bless($self, $class);
    
    return $self;
}

#
# Return an object representing a hypothetical future reservation.
#
# This DOES NOT actually check the feasibility of, guarantee,
# or record the reservation.
#
sub Create($$$$$$$)
{
    my ($class, $pid, $uid, $start, $end, $type, $nodes) = @_;

    return CreateCommon( $class, $pid, undef, $uid, $start, $end, $type,
			 $nodes );
}

#
# Return an object representing a hypothetical existing experiment.    
#
# This DOES NOT actually check the feasibility of, guarantee,
# or record the reservation.
#
sub CreateExisting($$$$$$$)
{
    my ($class, $pid, $eid, $uid, $end, $type, $nodes) = @_;

    return CreateCommon( $class, $pid, $eid, $uid, 0, $end, $type, $nodes );
}
    
#
# Return an object representing a hypothetical immediate experiment.    
#
# This DOES NOT actually check the feasibility of, guarantee,
# or record the reservation.
#
sub CreateImmediate($$$$$$$)
{
    my ($class, $pid, $eid, $uid, $end, $type, $nodes) = @_;

    return CreateCommon( $class, $pid, $eid, $uid, time(), $end, $type,
			 $nodes );
}
    
sub Lookup($$;$$$$)
{
    my ($class, $pid, $start, $end, $type, $nodes) = @_;
    my $query_result;
    
    if( defined( $start ) ) {
	# Look up by time and project.
	my $project = Project->Lookup( $pid );
	if( !defined( $project ) ) {
	    return undef;
	}

	my $pid_idx = $project->pid_idx();
    
	$query_result = DBQueryWarn( "SELECT *, UNIX_TIMESTAMP(start) AS s, " .
				     "UNIX_TIMESTAMP(end) AS e, " .
				     "UNIX_TIMESTAMP(created) AS c, " .
				     "UNIX_TIMESTAMP(approved) AS a, " .
				     "UNIX_TIMESTAMP(cancel) AS d " .
				     "FROM future_reservations " .
				     "WHERE pid_idx='$pid_idx' AND " .
				     "nodes='$nodes' AND " .
				     "type='$type' AND " .
				     "start=FROM_UNIXTIME($start) AND " .
				     "end=FROM_UNIXTIME($end)" );

	return undef
	    if (!$query_result || !$query_result->numrows);
    } else {
	# Look up by ID or UUID
	my $token = $_[ 1 ];
	my $clause;
	if ($token =~ /^\d*$/) {
	    $clause = "idx='$token'";
	}
	elsif (ValidUUID($token)) {
	    $clause = "uuid='$token'";
	}
	else {
	    return undef;
	}
	$query_result = DBQueryWarn( "SELECT *, UNIX_TIMESTAMP(start) AS s, " .
				     "UNIX_TIMESTAMP(end) AS e, " .
				     "UNIX_TIMESTAMP(created) AS c, " .
				     "UNIX_TIMESTAMP(approved) AS a, " .
				     "UNIX_TIMESTAMP(cancel) AS d " .
				     "FROM future_reservations " .
				     "WHERE $clause" );

	return undef
	    if (!$query_result || !$query_result->numrows);
    }
    
    my $record = $query_result->fetchrow_hashref();
    
    my $self               = {};
    $self->{'IDX'}         = $record->{'idx'};
    $self->{'PID'}         = $record->{'pid'};
    $self->{'PID_IDX'}     = $record->{'pid_idx'};
    $self->{'EID'}         = undef;
    $self->{'START'}       = $record->{'s'};
    $self->{'END'}         = $record->{'e'};
    $self->{'CREATED'}     = $record->{'c'};
    $self->{'CANCEL'}      = $record->{'d'};
    $self->{'TYPE'}        = $record->{'type'};
    $self->{'NODES'}       = $record->{'nodes'};
    $self->{'UID'}         = $record->{'uid'};
    $self->{'UID_IDX'}     = $record->{'uid_idx'};
    $self->{'NOTES'}       = $record->{'notes'};
    $self->{'ADMIN_NOTES'} = $record->{'admin_notes'};
    $self->{'APPROVED'}    = $record->{'a'};
    $self->{'APPROVER'}    = $record->{'approver'};
    $self->{'UUID'}        = $record->{'uuid'};
    $self->{'NOTIFIED'}    = $record->{'notified'};
    $self->{'NOTIFIED_UNUSED'} = $record->{'notified_unused'};
    $self->{'OVERRIDE_UNUSED'} = $record->{'override_unused'};
    # For compat with history entries.
    $self->{'DELETED'}     = undef;
    # Local temp datastore
    $self->{'DATA'}        = {};
	
    bless($self, $class);
    
    return $self;
}

sub idx($)         { return $_[0]->{"IDX"}; }
sub pid($)         { return $_[0]->{"PID"}; }
sub pid_idx($)     { return $_[0]->{"PID_IDX"}; }
sub eid($)         { return $_[0]->{"EID"}; }
sub start($)       { return $_[0]->{"START"}; }
sub end($)         { return $_[0]->{"END"}; }
sub cancel($)      { return $_[0]->{"CANCEL"}; }
sub created($)     { return $_[0]->{"CREATED"}; }
sub type($)        { return $_[0]->{"TYPE"}; }
sub nodes($)       { return $_[0]->{"NODES"}; }
sub uid($)         { return $_[0]->{"UID"}; }
sub uid_idx($)     { return $_[0]->{"UID_IDX"}; }
sub notes($)       { return $_[0]->{"NOTES"}; }
sub admin_notes($) { return $_[0]->{"ADMIN_NOTES"}; }
sub approved($)    { return $_[0]->{"APPROVED"}; }
sub approver($)    { return $_[0]->{"APPROVER"}; }
sub uuid($)        { return $_[0]->{"UUID"}; }
sub notified($)    { return $_[0]->{"NOTIFIED"}; }
sub notified_unused($) { return $_[0]->{"NOTIFIED_UNUSED"}; }
sub override_unused($) { return $_[0]->{"OVERRIDE_UNUSED"}; }
# For compat with history entries.
sub deleted($)     { return $_[0]->{"DELETED"}; }
# Get/Set some temporary extra data.
sub data($$;$)
{
    my ($self, $key, $val) = @_;

    if (defined($val)) {
	return $self->{'DATA'}->{$key} = $val;
    }
    if (exists($self->{'DATA'}->{$key})) {
	return $self->{'DATA'}->{$key};
    }
    return undef;
}

sub Stringify($)
{
    my ($self) = @_;

    my $idx = $self->idx();
    $idx = "xxx" if (!defined($idx));
    my $uid = $self->uid();
    my $pid = $self->pid();
    $pid = "(free)" if( !defined( $pid ) );
    
    if( defined( $self->eid() ) ) {
	$pid = $pid . "/" . $self->eid();
    }
    my $nodes = $self->nodes();
    my $type = $self->type();
    my $start = (defined( $self->start() ) ?
		 POSIX::strftime("%m/%d/20%y %H:%M:%S",
				 localtime($self->start())) : "epoch");
    my $end = (defined( $self->end() ) ?
		 POSIX::strftime("%m/%d/20%y %H:%M:%S",
				 localtime($self->end())) : "forever");
    return "[Reservation:$idx $pid/$uid, ${nodes}x${type}, ${start}-${end}]";
}

sub SetStart($$)
{
    my ($self, $start) = @_;

    $self->{'START'} = $start;
}  

sub SetEnd($$)
{
    my ($self, $end) = @_;

    $self->{'END'} = $end;
}  

sub SetNodes($$)
{
    my ($self, $nodes) = @_;

    $self->{'NODES'} = $nodes;
}  

sub SetNotes($$)
{
    my ($self, $notes) = @_;

    $self->{'NOTES'} = $notes;
}

sub SetAdminNotes($$)
{
    my ($self, $notes) = @_;

    $self->{'ADMIN_NOTES'} = $notes;
}

# Mark the reservation as approved.  This DOES NOT update the database
# state: to do so requires an admission control check!  See BeginTransaction(),
# IsFeasible(), Book(), etc.
sub Approve($;$)
{
    my ($self, $user) = @_;

    $user = User->ThisUser() if( !defined( $user ) );

    $self->{'APPROVED'} = time();
    $self->{'APPROVER'} = $user->uid() if defined( $user );
}

# Retrieve the current reservation database version.  This version must
# be retrieved and saved before validity checks on attempted updates,
# and then the same version supplied to BeginTransaction() before making
# any changes.
sub GetVersion($)
{
    my $query_result = DBQueryFatal( "SELECT * FROM reservation_version" );
    my $version;
    
    if( ($version) = $query_result->fetchrow_array() ) {
	return $version;
    }

    # Nothing in the reservation_version table.  The db update scripts
    # populated it, but I forgot to add the version when doing a db init
    # from scratch.  Rather than fix it there, it's better to cope with
    # the situation right here, because this will work no matter what
    # convoluted history the db has been through.
    DBQueryFatal( "LOCK TABLES reservation_version WRITE" );
    # Check existence again, with locking this time, to avoid race.
    $query_result = DBQueryFatal( "SELECT * FROM reservation_version" );    
    unless( ($version) = $query_result->fetchrow_array() ) {
	DBQueryFatal( "INSERT INTO reservation_version SET version=0" );
    }
    DBQueryFatal( "UNLOCK TABLES" );
    
    return 0;
}

# Attempt to commit database changes.  GetVersion() must have been called
# previously, and whatever version was obtained supplied as the parameter
# here.  Any necessary availability checks must have been performed
# after GetVersion() and BeginTransaction().  If BeginTransaction()
# returned undef, then concurrent modifications have been detected,
# possibly invalidating the checks already made, and the entire operation
# must be retried from the beginning.  Otherwise, the caller is free
# to proceed with the updates and then complete with EndTransaction().
sub BeginTransaction($$;@)
{
    my ($self, $old_version, @tables) = @_;
    my $moretables = "";

    if (@tables) {
	@tables = join(", ", map {"$_ write"} @tables);
	$moretables = ", @tables";
    }
    DBQueryFatal( "LOCK TABLES future_reservations WRITE, " .
		  "reservation_version WRITE $moretables" );
    
    my $version = GetVersion( $self );

    if( $old_version != $version ) {
	# Reservations have been altered by a concurrent operation.
	# Can't continue: the caller will have to retry.
	DBQueryFatal( "UNLOCK TABLES" );
	return undef;
    }

    # Eagerly update the version.  This isn't always strictly necessary,
    # but it is always safe.  And doing it now instead of at EndTransaction
    # time guards against undetected inconsistencies in the case where a
    # process applies persistent updates while it has the tables locked, but
    # then dies for some reason before it can EndTransaction.
    DBQueryFatal( "UPDATE reservation_version SET version=version+1" );
    
    # We're good.
    return 0;
}

sub EndTransaction($)
{
    DBQueryFatal( "UNLOCK TABLES" );
}

# Add a reservation record to the database (therefore committing ourselves
# to the guarantee it represents).  Because of the consequences and
# consistency requirements, this is permitted ONLY inside a
# BeginTransaction()/EndTransaction() pair, following either
# admission control satisfaction or admin override.
sub Book($;$)
{
    my ($self,$idx) = @_;

    my $pid = $self->pid();
    my $pid_idx = $self->pid_idx();
    my $nodes = $self->nodes();
    my $type = $self->type();
    my $start = $self->start();
    my $end = $self->end();
    my $uid = $self->uid();
    my $uid_idx = $self->uid_idx();
    my $notes = DBQuoteSpecial( $self->notes() );
    my $admin_notes = DBQuoteSpecial( $self->admin_notes() );
    my $approved = $self->approved();
    my $approver = $self->approver();

    my $base_query = "SET pid='$pid', " .
		     "pid_idx='$pid_idx', " .
		     "nodes='$nodes', " .
		     "type='$type', " .
		     "start=FROM_UNIXTIME($start), " .
		     "end=FROM_UNIXTIME($end), " .
		     "uid='$uid', " .
		     "uid_idx='$uid_idx' " .
		     ( defined($idx) ? "" : ", uuid=uuid()" ) .
		     ( defined( $notes ) ? ", notes=$notes" : "" ) .
		     ( defined( $admin_notes ) ?
		       ", admin_notes=$admin_notes" : "" ) .
		     ( defined( $approved ) ?
		       ", approved=FROM_UNIXTIME($approved)" : "" ) .
		     ( defined( $approver ) ? ", approver='$approver'" : "" );

    my $query_result =
	DBQueryWarn( defined( $idx ) ? "UPDATE future_reservations " .
		     $base_query . " WHERE idx='$idx'" :
		     "INSERT INTO future_reservations " . $base_query )
        or return -1;

    $self->{'IDX'} = $query_result->insertid();
    $self->{'CREATED'} = time();

    delete $cache{$type};
    
    return 0;
}

# Cancel a future reservation.  This could be enclosed within a transaction,
# but since cancellations can never cause concurrent operations to fail,
# the transaction is not mandatory.
sub Cancel($)
{
    my ($self) = @_;

    my $idx = $self->idx();
    my $type = $self->type();

    if (defined($self->approved())) {
 	DBQueryFatal("INSERT INTO reservation_history ".
		     "  (uuid, pid, pid_idx, nodes, type, deleted, canceled, " .
		     "   created, start, end, uid, uid_idx, ".
		     "   notes, admin_notes) " .
		     "SELECT uuid, pid, pid_idx, nodes, type, now(), ".
		     "  cancel, created,".
		     "  start, end, uid, uid_idx, notes, admin_notes ".
		     "FROM future_reservations WHERE idx='$idx'");
    }
    DBQueryWarn( "DELETE FROM future_reservation_attributes WHERE " . 
		 "reservation_idx=$idx" )
	or return -1;

    DBQueryWarn( "DELETE FROM future_reservations WHERE idx=$idx" )
	or return -1;

    delete $cache{$type};
    
    return 0;
}

sub SetAttribute($$$)
{
    my ($self, $key, $value) = @_;

    my $idx = $self->idx();
    $key = DBQuoteSpecial( $key );
    $value = DBQuoteSpecial( $value );
    
    DBQueryWarn( "REPLACE INTO future_reservation_attributes SET " .
		 "reservation_idx='$idx', " .
		 "attrkey='$key', " .
		 "attrvalue='$value'" )
	or return -1;

    return 0;
}

sub GetAttribute($$)
{
    my ($self, $key) = @_;

    my $idx = $self->idx();
    $key = DBQuoteSpecial( $key );

    my $query_result = DBQueryWarn( "SELECT attrvalue FROM " .
				    "future_reservation_attributes WHERE " .
				    "reservation_idx='$idx' AND " .
				    "attrkey='$key'" );
    return undef
	if( !$query_result || !$query_result->numrows );

    my ($value) = $query_result->fetchrow_array();

    return $value;
}

#
# Archive any reservations whose times have passed.  This should be
# called occasionally to maintain performance (avoid clogging up the
# future_reservations table with things that don't matter any more, and
# to keep proper records in the reservation_history table), but isn't
# actually required for correctness.
#
sub Tidy($)
{
    my ($class) = @_;

    my $query_result = DBQueryWarn( "SELECT now()" );
    return undef
	if( !$query_result || !$query_result->numrows );

    my ($stamp) = $query_result->fetchrow_array();
    
    $query_result = DBQueryWarn( "SELECT COUNT(*) FROM " .
				    "future_reservations WHERE " .
				    "end < '$stamp'" );
    return undef
	if( !$query_result || !$query_result->numrows );

    my ($count) = $query_result->fetchrow_array();

    if( !$count ) {
	# no tidying required
	return 0;
    }

    DBQueryFatal( "LOCK TABLES future_reservations WRITE, " .
		  "reservation_history WRITE, " .
		  "future_reservation_attributes AS a WRITE, " .
		  "future_reservations AS r READ" );
    DBQueryFatal( "INSERT INTO reservation_history( uuid, pid, pid_idx, ".
		  "nodes, type, deleted, canceled, " .
		  "created, start, end, uid, uid_idx, notes, admin_notes ) " .
		  "SELECT uuid, pid, pid_idx, nodes, type, null, ".
		  "cancel, created, start, end, uid, uid_idx, " .
		  "notes, admin_notes FROM future_reservations WHERE " .
		  "end < '$stamp' and approved is not null" );
    DBQueryFatal( "DELETE FROM future_reservations WHERE " .
		  "end < '$stamp'" );
    DBQueryFatal( "DELETE a FROM future_reservation_attributes AS a " .
		  "LEFT OUTER JOIN future_reservations AS r ON " .
		  "a.reservation_idx=r.idx WHERE r.idx IS NULL" );
    DBQueryFatal( "UNLOCK TABLES" );

    return 1;
}

sub LookupAll($$;$$)
{
    my ($class, $type, $include_pending, $details) = @_;

    $include_pending = 0 if( !defined( $include_pending ) );
    my $cachekey = $type . ":" . $include_pending;
    
    return $cache{$cachekey} if( exists( $cache{$cachekey} ) &&
				 !ref( $details ) );

    Tidy( $class );

    # Mysql 5.7 group by nonsense. Revisit later, like when hell freezes. 
    DBQueryWarn("SET SESSION sql_mode=(SELECT REPLACE(\@\@sql_mode,".
		"'ONLY_FULL_GROUP_BY',''))");
    
    my @reservations = ();

    my $query = $PGENISUPPORT ? "SELECT COUNT(*), e.pid, e.eid, " .
				"e.expt_swap_uid, " .
				"UNIX_TIMESTAMP( e.expt_expires ), ".
				"e.autoswap, " .
				"nr.pid, UNIX_TIMESTAMP( s.expires ), " .
				"s.lockdown as slice_lockdown, ".
				"n.reserved_pid, " .
				"UNIX_TIMESTAMP( pr.end ), ".
				"e.lockdown, e.swappable " .
				"FROM nodes AS n " .
				"LEFT OUTER JOIN " .
				"reserved AS r ON n.node_id=r.node_id " .
				"LEFT OUTER JOIN " .
				"node_attributes AS a ON ".
	                        "   n.node_id=a.node_id and " .
	                        "   a.attrkey='not_reservable' " .
				"LEFT OUTER JOIN experiments AS e ON " .
				"r.pid=e.pid AND r.eid=e.eid " .
				"LEFT OUTER JOIN experiment_stats AS stats ON ".
				"e.idx=stats.exptidx LEFT " .
				"OUTER JOIN next_reserve AS nr ON " .
				"n.node_id=nr.node_id LEFT OUTER JOIN " .
				"project_reservations AS pr ON " .
				"n.reserved_pid=pr.pid AND " .
				"n.reservation_name=pr.name AND " .
	                        "pr.approved is not null ".
				"LEFT OUTER JOIN" .
				"`geni-cm`.geni_slices AS s ON " .
				"e.eid_uuid=s.uuid " .
				"WHERE ((n.reservable=0 and n.type='$type') or ".
				"      (n.reservable=1 and n.node_id='$type')) ".
	                        "  and a.attrvalue is null ".
				"GROUP BY " .
				"e.pid, e.eid, n.reserved_pid, nr.pid, " .
				"UNIX_TIMESTAMP( pr.end )" :
				"SELECT COUNT(*), e.pid, e.eid, " .
				"e.expt_swap_uid, " .
				"UNIX_TIMESTAMP( e.expt_expires ), " .
				"e.autoswap, " .
				"nr.pid, NULL, " .
				"NULL, n.reserved_pid, " .
				"UNIX_TIMESTAMP( pr.end ), " .
				"e.lockdown, e.swappable " .
				"FROM nodes AS n " .
				"LEFT OUTER JOIN " .
				"reserved AS r ON n.node_id=r.node_id " .
				"LEFT OUTER JOIN " .
				"node_attributes AS a ON ".
	                        "   n.node_id=a.node_id and " .
	                        "   a.attrkey='not_reservable' " .
				"LEFT OUTER JOIN experiments AS e ON " .
				"r.pid=e.pid AND r.eid=e.eid " .
				"LEFT OUTER JOIN experiment_stats AS stats ON ".
				"r.pid=stats.pid AND r.eid=stats.eid LEFT " .
				"OUTER JOIN next_reserve AS nr ON " .
				"n.node_id=nr.node_id " .
				"LEFT OUTER JOIN " .
				"project_reservations AS pr ON " .
				"n.reserved_pid=pr.pid AND " .
				"n.reservation_name=pr.name AND " .
	                        "pr.approved is not null ".
				"WHERE ((n.reservable=0 and n.type='$type') or ".
				"      (n.reservable=1 and n.node_id='$type')) ".
	                        "  and a.attrvalue is null ".
				"GROUP BY e.pid, e.eid, n.reserved_pid, " .
				"nr.pid, UNIX_TIMESTAMP( pr.end )";
    my $query_result = DBQueryWarn( $query );

    $$details = "--- Node usage:\n" if( ref( $details ) );
    
    while( my($count, $pid, $eid, $uid, $end, $autoswap, $next_reserve,
	      $slice_expire, $slice_lockdown, $reserved_pid, $pr_end,
	      $expt_lockdown, $swappable) =
	   $query_result->fetchrow_array() ) {
	my $endtime;

	if( ref( $details ) ) {
	    no warnings 'uninitialized';
	    $$details = $$details . "$count, $pid, $eid, $uid, $end, " .
		"$autoswap, $next_reserve, $slice_expire, $slice_lockdown, " .
		"$reserved_pid, $pr_end, $expt_lockdown, $swappable\n";
	}

	if( defined( $slice_expire ) ) {
	    # Node(s) allocated to a GENI slice.  Treat as unavailable
	    # if locked down, otherwise assume released at slice expiry
	    # time.
	    $endtime = $slice_lockdown ? undef : $slice_expire;
	} else {
	    # A non-GENI slice.  Use the computed autoswap duration,
	    # if autoswap is enabled.
	    $endtime = ($expt_lockdown || !$swappable ? undef :
			$autoswap ? $end : undef);
	}

	# If next_reserve is set, assume unavailable indefinitely.
	# FIXME can we obtain more precise predictions by doing a
	# CreateExisting() for the current experiment then something
	# else at $endtime?
	if( defined( $next_reserve ) ) {
	    $endtime = undef;
	}

	# If reserved_pid is set, assume the node is assigned to the
	# project forever, unless there's an end time in a corresponding
	# project_reservations entry.
	if( defined( $reserved_pid ) &&
	    ( !defined( $pr_end ) || !defined( $endtime ) ||
	      $pr_end > $endtime ) ) {
	    $endtime = $pr_end;
	}

	# Consider nodes in reloading to be available.  One important
	# reason for doing so is that if a project has a current reservation
	# and swaps one experiment out and a replacement in, then during
	# the transition period, sufficient nodes must be considered available
	# for assignment to that project.
	if( defined( $pid ) && ( $pid ne "emulab-ops" ||
				 ( $eid ne "reloading" &&
				   $eid ne "reloadpending" ) ) ) {
	    # Handle the case where an experiment is swapped in.  The
	    # nodes aren't free right now, but at some time in the
	    # future they could become so.
	    my $res = CreateExisting( $class, $pid, $eid, $uid, $endtime,
				      $type, $count );
	    push( @reservations, $res );
	} elsif( !defined( $reserved_pid ) ) {
	    # Physical nodes with no reservations whatsoever... treat
	    # them as free since the beginning of time.
	    my $res = CreateCommon( $class, undef, undef, undef, 0, undef,
				    $type, $count );
	    push( @reservations, $res );
	} elsif( defined( $endtime ) ) {
	    # The nodes have a reserved_pid, but there's a known	    
	    # end time (the current experiment end, or the
	    # project_reservations end, whichever is later)... mark
	    # them as available after that.
	    my $res = CreateCommon( $class, $pid, $eid, $uid, 0, $endtime,
				    $type, $count );
	    push( @reservations, $res );	    
	}
    }

    $$details = $$details . "\n--- Reservations:\n" if( ref( $details ) );
    
    $query_result = DBQueryWarn( "SELECT pid, uid, UNIX_TIMESTAMP( start ), " .
				 "UNIX_TIMESTAMP( end ), nodes, idx, approved ".
				 "FROM future_reservations WHERE type='$type'" .
				 ( $include_pending ? "" :
				   " AND approved IS NOT NULL" ) );

    while( my ($pid, $uid, $start, $end, $nodes, $idx, $approved) =
	   $query_result->fetchrow_array() ) {
	my $res = Create( $class, $pid, $uid, $start, $end, $type, $nodes );
	$res->{'IDX'} = $idx;
	$res->{'APPROVED'} = $approved;
	push( @reservations, $res );
	
	if( ref( $details ) ) {
	    no warnings 'uninitialized';
	    $$details = $$details . "$pid, $uid, $start, $end, $nodes, $idx\n";
	}
    }

    $cache{$cachekey} = \@reservations;
    
    return $cache{$cachekey};
}

sub IsFeasible($$;$$$$$$)
{
    my ($class, $reservations, $error, $conflicttime, $conflictcount,
	$projlist, $forecast, $dounapproved) = @_;

    my @timeline = ();
    my $free = 0;
    my %used = ();
    my %reserved = ();
    my %unapproved = ();
    my $answer = 1;
    my $now = time();
    $dounapproved = 0 if (!defined($dounapproved));
    
    foreach my $reservation ( @$reservations ) {
	my $pid = $reservation->pid();
	my $start;
	my $end;

	if( defined( $reservation->eid() ) ) {
	    if( $reservation->start() ) {
		# An unmapped experiment.  Not yet using physical nodes.
		$start = { 'pid' => $reservation->pid(),
			   't' => $reservation->start(),
			   'used' => $reservation->nodes(),
			   'reserved' => 0,
			   'unapproved' => 0,
		};
	    } else {
		# A mapped experiment.  Using physical nodes now.
		if( defined( $used{ $pid } ) ) {
		    $used{ $pid } += $reservation->nodes();
		} else {
		    $used{ $pid } = $reservation->nodes();
		}
	    }
	    
	    # Will later release real nodes.
	    $end = { 'pid' => $reservation->pid(),
		     't' => $reservation->end(),
		     'used' => -$reservation->nodes(),
		     'reserved' => 0,
		     'unapproved' => 0,
	    };
	} elsif( defined( $reservation->pid() ) ) {
	    # A reservation.  Uses then releases reserved nodes.

	    # Ignore reservations for listed projects.
	    next if( grep( $_ eq $reservation->pid(), @$projlist ) );

	    # Ignore past reservations.
	    next if( $reservation->end() < $now );
	    
	    my $starttime = $reservation->start();
	    $starttime = $now if( $starttime < $now );
	    
	    $start = { 'pid' => $reservation->pid(),
		       't' => $starttime,
		       'used' => 0,
	    };
	    $end = { 'pid' => $reservation->pid(),
		     't' => $reservation->end(),
		     'used' => 0,
	    };
	    if ($reservation->approved() || !$dounapproved) {
		$start->{'reserved'}   = $reservation->nodes();
		$start->{'unapproved'} = 0;
		$end->{'reserved'}     = -$reservation->nodes();
		$end->{'unapproved'}   = 0;
	    }
	    else {
		$start->{'reserved'}   = 0;
		$start->{'unapproved'} = $reservation->nodes();
		$end->{'reserved'}     = 0;
		$end->{'unapproved'}   = -$reservation->nodes();
	    }
	} else {
	    # Available resources.  Provides nodes for all time.
	    $free += $reservation->nodes();
	}

	push( @timeline, $start ) if( defined( $start->{'t'} ) );
	push( @timeline, $end ) if( defined( $end->{'t'} ) );
    }

    if( defined( $forecast ) ) {
	my %origin = (
	    t => 0,
	    free => $free
	    );
	push( @$forecast, \%origin );
    }

    my @events = sort {
	if ($a->{'t'} == $b->{'t'}) {
	    return $a->{'reserved'} <=> $b->{'reserved'};
	}
	else {
	    return $a->{'t'} <=> $b->{'t'};
	}
    } @timeline;

    foreach my $event ( @events ) {
	my $pid = $event->{'pid'};

	$used{ $pid } = 0 if( !exists( $used{ $pid } ) );
	$reserved{ $pid } = 0 if( !exists( $reserved{ $pid } ) );
	$unapproved{ $pid } = 0 if( !exists( $unapproved{ $pid } ) );

	my $oldsum = $used{ $pid } > $reserved{ $pid } ? $used{ $pid } :
	    $reserved{ $pid };

	$used{ $pid } += $event->{ 'used' };
	$reserved{ $pid } += $event->{ 'reserved' };
	$unapproved{ $pid } += $event->{ 'unapproved' };

	my $newsum = $used{ $pid } > $reserved{ $pid } ? $used{ $pid } :
	    $reserved{ $pid };

	$free += $oldsum - $newsum;

	if( defined( $forecast ) ) {
	    my %used_ = %used;
	    my %reserved_ = %reserved;
	    my %unapproved_ = %unapproved;
	    my %stamp = (
		t => $event->{'t'},
		used => \%used_,
		reserved => \%reserved_,
		unapproved => \%unapproved_,
		free => $free
		);
	    push( @$forecast, \%stamp );
	}
	
	if( $free < 0 ) {
	    # Insufficient resources.
	    if( ref( $error ) ) {
		my $time = localtime( $event->{'t'} );
		my $needed = -$free;
		my $string = "Insufficient free nodes at $time " .
		    "($needed more needed).";
		if (ref($error) eq "HASH") {
		    $error->{'error'}  = $string;
		    $error->{'time'}   = $event->{'t'};
		    $error->{'needed'} = $needed;
		}
		else {
		    $$error = $string;
		}
	    }
	    if( ref( $conflicttime ) ) {
		$$conflicttime = $event->{'t'};
	    }
	    if( ref( $conflictcount ) ) {
		$$conflictcount = -$free;
	    }

	    if( defined( $forecast ) ) {
		$answer = 0;
	    } else {
		return 0;
	    }
	}
    }
    
    return $answer;
}

#
# Generate a heuristic "count" of free nodes of a given type.  For each
# "free forever" physical node (i.e., a node never required for future
# reservations), the count is incremented by one.  Each node currently
# assigned to an experiment is ignored (doesn't affect the count).  Each
# node currently free but later required for a reservation increments the
# count by some fractional value depending how far into the future the
# reservation is.
#
# Reservation->FreeCount( $type, $projlist )
#
# $type must be a valid node type.
# $projlist is an optional reference to a list of PIDs, and reservations
#     for any projects in the list will be ignored (i.e., the nodes are
#     assumed free -- useful if a user wants to consider nodes reserved
#     to their own projects as available).
sub FreeCount($$;$) {
    my ($class, $type, $projlist) = @_;

    my $reservations = LookupAll( $class, $type );
    my @forecast = ();
    my $t = time();    
    
    IsFeasible( $class, $reservations, undef, undef, undef, $projlist,
		\@forecast );

    my $free = $forecast[ 0 ]->{'free'};
    my $answer = $free;

    foreach my $f ( @forecast ) {
	if( $f->{'free'} < $free ) {
	    my $deltat = $f->{'t'} - $t;

	    $deltat = 0 if( $deltat < 0 );

	    # Weight the nodes based on how far into the future the
	    # reservation is.  The 0x10000 is chosen so that a node available
	    # for the next 24 hours only is worth about half a node available
	    # indefinitely.
	    $answer -= ( ( $free - $f->{'free'} ) * exp( -$deltat / 0x10000 ) );
	    
	    $free = $f->{'free'};
	}
    }

    return $answer;
}

# Generate a time series of counts of nodes of a given type.
#
# The result is a list of (t, unavailable, held, free) tuples, where:
#
# * 't' is the timestamp at which the state in the remainder of the
# tuple becomes valid.
#
# * 'unavailable' is a count of nodes unavailable for allocation, either
# because they're already in use (including both those in use
# by experiments in the projects specified and those used by others),
# or because they're required for reservations to other projects.
#
# * 'held' is a count of nodes reserved to the project(s) queried, but
# NOT yet allocated to any experiment.  They could potentially be used by the
# user asking, but not to those outside the proper projects.  Since these
# resources are currently idle, the user (or one of their project partners)
# should try to use them ASAP!
#
# * 'free' is the number of nodes not allocated and not needed
# for reservations; available for general use subject to other constraints.
sub Forecast($$;$$) {
    my ($class, $type, $projlist, $details, $dounapproved) = @_;

    my $reservations = LookupAll( $class, $type, $dounapproved, $details );
    my @forecast = ();
    my @answer = ();
    my $t = time();

    IsFeasible( $class, $reservations, undef, undef, undef, undef,
		\@forecast, $dounapproved );

    if ($dounapproved && $details) {
	print Dumper(\@forecast);
    }
    
    foreach my $f ( @forecast ) {
	my $unavailable = 0;
	my $unapproved = 0;
	my $held = 0;
	my $free = $f->{'free'};

	foreach my $pid ( keys( %{$f->{'used'}} ) ) {
	    $unavailable += $f->{'used'}->{$pid};
	}
	foreach my $pid ( keys( %{$f->{'unapproved'}} ) ) {
	    $unapproved += $f->{'unapproved'}->{$pid};
	}
	
	foreach my $pid ( keys( %{$f->{'reserved'}} ) ) {
	    my $r = $f->{'reserved'}->{$pid};
	    my $u = $f->{'used'}->{$pid};

	    if( $r > $u ) {
		if( grep( $_ eq $pid, @$projlist ) ) {
		    $held += $r - $u;
		} else {
		    $unavailable += $r - $u;
		}
	    }
	}
	
	my %r = (
	    t => $f->{'t'},
	    unavailable => $unavailable,
	    unapproved => $unapproved,
	    held => $held,
	    free => $free
	    );

	if( $r{'t'} < $t ) {
	    # event in the past; overwrite initial result in list but do
	    # not append
	    $r{'t'} = $t;
	    $answer[ 0 ] = \%r;
	} else {
	    push( @answer, \%r );
	}
    }
    
    return @answer;
}

#
# Find any future periods with smaller predicted availability than the
# present.
sub FuturePressure($$;$) {
    my ($class, $typelist, $projlist) = @_;

    my @reservations = ();
    
    foreach my $type ( @$typelist ) {
	my $typeres = LookupAll( $class, $type );

	push( @reservations, @$typeres );
    }

    my @forecast = ();
    my @answer = ();
    my $t = time();
    my $maxused = 0;    
    my $under_pressure = 0;
    my $period;
    
    IsFeasible( $class, \@reservations, undef, undef, undef, undef,
		\@forecast );

    foreach my $f ( @forecast ) {
	my $unavailable = 0;
	my $held = 0;
	my $free = $f->{'free'};

	foreach my $pid ( keys( %{$f->{'used'}} ) ) {
	    $unavailable += $f->{'used'}->{$pid};
	}
	
	foreach my $pid ( keys( %{$f->{'reserved'}} ) ) {
	    my $r = $f->{'reserved'}->{$pid};
	    my $u = $f->{'used'}->{$pid};

	    if( $r > $u ) {
		if( grep( $_ eq $pid, @$projlist ) ) {
		    $held += $r - $u;
		} else {
		    $unavailable += $r - $u;
		}
	    }
	}

	if( $f->{'t'} <= $t ) {
	    $maxused = $unavailable if( $unavailable > $maxused );
	} elsif( $under_pressure ) {
	    if( $unavailable <= $maxused ) {
		$under_pressure = 0;
		push( @answer, [ $period, $f->{'t'} ] );
	    }
	} else {
	    if( $unavailable > $maxused ) {
		$under_pressure = 1;
		$period = $f->{'t'};
	    }
	}
    }

    return @answer;
}

#
# Find the earliest unfulfilled reservation for any of the specified projects.
# (If a project is using at least as many nodes as it has reserved,
# reservation(s) will be considered fulfilled and ignored as a possible
# result.)  Optionally limited to particular node type(s), otherwise
# reservations for any node type are returned.
#
# Returns a timestamp if any unfulfilled reservation exists, otherwise undef.
sub OutstandingReservation($$;$) {
    my ($class, $projlist, $typelist ) = @_;
    my $earliest = undef;
    
    foreach ( @$projlist ) {
	# reject illegal PIDs
	return undef unless /^[-\w]+$/;
    }
    
    my $query_result = DBQueryFatal( "SELECT DISTINCT(type) FROM " .
				     "future_reservations WHERE pid IN ('" .
				     join( "','", @$projlist ) . "')" );

    while( my($type) = $query_result->fetchrow_array() ) {
	next if( defined( $typelist ) && !grep( $_ eq $type, @$typelist ) );
	
	my $reservations = LookupAll( $class, $type );

	my @forecast = ();
    
	IsFeasible( $class, $reservations, undef, undef, undef, undef,
		    \@forecast );

	foreach my $f ( @forecast ) {
	    foreach my $pid ( keys ( %{$f->{'reserved'}} ) ) {
		if( grep( $_ eq $pid, @$projlist ) &&
		    ( !exists( $f->{'used'}->{$pid} ) ||
		      $f->{'used'}->{$pid} < $f->{'reserved'}->{$pid} ) ) {
		    # Found an unfulfilled reservation.
		    my $t = $f->{'t'};

		    $earliest = $t if( !defined( $earliest ) ||
				       $t < $earliest );
		}
	    }
	}
    }

    return $earliest;
}

# Return a list of (pid, nodetype, reserved, used) hashes for any currently
# active reservations belonging to a listed project.
sub CurrentReservations($;$$) {
    my ($class, $projlist, $activeonly) = @_;
    my @answer = ();
    my $pclause = "";
    $activeonly = 0 if (!defined($activeonly));

    if (defined($projlist) && @$projlist) {
	foreach ( @$projlist ) {
	    # reject illegal PIDs
	    return undef unless /^[-\w]+$/;
	}
	$pclause = "r.pid IN ('" . join( "','", @$projlist ) .	"') AND ";
    }

    my $query_result = DBQueryFatal(
	"SELECT r.pid, r.type, SUM( r.nodes ), " .
	    "(SELECT COUNT(*) FROM reserved AS res, nodes AS n ".
            "WHERE res.pid=r.pid AND res.node_id=n.node_id AND ".
	    "      ((n.reservable=0 and n.type=r.type) or ".
	    "       (n.reservable=1 and n.node_id=r.type))), ".
	    "(SELECT COUNT(*) FROM nodes AS n LEFT OUTER JOIN reserved " .
	    "AS res ON n.node_id=res.node_id ".
	    "WHERE ((n.reservable=0 and n.type=r.type) or ".
	    "       (n.reservable=1 and n.node_id=r.type)) and ".
	    "      res.pid IS NULL)," .
	    "(SELECT COUNT(*) FROM nodes AS n, reserved AS res " .
	    "WHERE n.node_id=res.node_id AND res.pid='emulab-ops' AND " .
	    "res.eid IN ('reloading', 'reloadpending')) " .
	"FROM future_reservations AS r WHERE $pclause ".
             "r.approved IS NOT NULL ".
	     ($activeonly ? 
	      "AND r.start < NOW() AND r.end > NOW() " : " ") .
        "GROUP BY r.pid, r.type" );

    while( my($pid, $type, $reserved, $used, $ready, $reloading) =
	   $query_result->fetchrow_array() ) {
	push( @answer, { 'pid' => $pid, 'nodetype' => $type,
			 'reserved' => $reserved, 'used' => $used,
			 'ready' => $ready, 'reloading' => $reloading } );
    }
    
    return @answer;
}

# Return a list of (pid, nodetype, nodecount, starttime, endtime) hashes
# for any reservations belonging to a listed project starting within the
# next 24 hours.
sub UpcomingReservations($$) {
    my ($class, $projlist) = @_;
    my @answer = ();
    
    foreach ( @$projlist ) {
	# reject illegal PIDs
	return undef unless /^[-\w]+$/;
    }

    my $query_result = DBQueryFatal( "SELECT pid, type AS nodetype, " .
				     "nodes AS nodecount, " .
				     "UNIX_TIMESTAMP(start) AS starttime, " .
				     "UNIX_TIMESTAMP(end) AS endtime FROM " .
				     "future_reservations WHERE " .
				     "approved IS NOT NULL AND " .
				     "start > NOW() AND " .
				     "start <= ADDDATE( NOW(), 1 ) AND " .
				     "pid IN ('" .
				     join( "','", @$projlist ) . "')" );

    while( my $record = $query_result->fetchrow_hashref() ) {
	push( @answer, $record );
    }

    return @answer;
}

#
# Return a list of project reservations. Optional type and activeonly.
# Type can be a single type or a list reference of types.
#
sub ProjectReservations($$$;$$) {
    my ($class, $project, $user, $type, $activeonly) = @_;
    my $typeclause   = "";
    my $activeclause = "";
    my $userclause   = "";
    my $pidclause    = "";
    my @answer = ();

    if (defined($type)) {
	if (ref($type)) {
	    my @types = @{$type};
	    $typeclause = "AND type IN ('" . join( "','", @types ) . "')" ;
	}
	else {
	    $typeclause = "AND type='$type'";
	}
    }
    if (defined($activeonly) && $activeonly) {
	$activeclause = "AND start < NOW() AND end > NOW()";
    }
    if (defined($user)) {
	my $uid = $user->uid();
	$userclause = "AND uid='$uid'";
    }
    if (defined($project)) {
	my $pid = ref($project) ? $project->pid() : $project;
	$pidclause = "AND pid='$pid'";
    }
    my $query_result =
	DBQueryFatal("select idx from future_reservations ".
		     "where approved IS NOT NULL $pidclause ".
		     "  $typeclause $activeclause $userclause ".
		     "order by created desc");

    while (my ($idx) = $query_result->fetchrow_array()) {
	my $res = Reservation->Lookup($idx);
	push(@answer, $res)
	    if (defined($res));
    }
    return @answer;
}

#
# Fake up an object for a historical reservation entry.
#
sub LookupHistorical($$) {
    my ($class, $uuid) = @_;

    my $query_result =
	DBQueryWarn("select *,UNIX_TIMESTAMP(start) AS s, " .
		     "       UNIX_TIMESTAMP(end) AS e, ".
		     "       UNIX_TIMESTAMP(created) AS c, " .
		     "       UNIX_TIMESTAMP(canceled) AS d, " .
		     "       UNIX_TIMESTAMP(deleted) AS k " .
		     "  from reservation_history ".
		     "where uuid='$uuid'");

    return undef
	if (!defined($query_result) || !$query_result->numrows);

    my $record = $query_result->fetchrow_hashref();
    my $self               = {};
    $self->{'IDX'}         = undef;
    $self->{'PID'}         = $record->{'pid'};
    $self->{'PID_IDX'}     = $record->{'pid_idx'};
    $self->{'EID'}         = undef;
    $self->{'START'}       = $record->{'s'};
    $self->{'END'}         = $record->{'e'};
    $self->{'CREATED'}     = $record->{'c'};
    $self->{'DELETED'}     = $record->{'k'};
    $self->{'CANCEL'}      = $record->{'d'};
    $self->{'TYPE'}        = $record->{'type'};
    $self->{'NODES'}       = $record->{'nodes'};
    $self->{'UID'}         = $record->{'uid'};
    $self->{'UID_IDX'}     = $record->{'uid_idx'};
    $self->{'NOTES'}       = $record->{'notes'};
    $self->{'ADMIN_NOTES'} = $record->{'admin_notes'};
    $self->{'APPROVED'}    = undef;
    $self->{'APPROVER'}    = undef;
    $self->{'UUID'}        = $record->{'uuid'};
    $self->{'NOTIFIED'}    = undef;
    $self->{'NOTIFIED_UNUSED'} = undef;
    $self->{'OVERRIDE_UNUSED'} = 0;
    bless($self, $class);
    # Local temp datastore
    $self->{'DATA'}        = {};

    return $self;
}

#
# Return a list of historical project reservations. Optional type.
# Type can be a single type or a list reference of types.
#
sub HistoricalReservations($$$;$) {
    my ($class, $project, $user, $type) = @_;
    my $pid;
    my @clauses = ();
    my @answer  = ();

    if (defined($type)) {
	if (ref($type)) {
	    my @types = @{$type};
	    push(@clauses,
		 "type IN ('" . join( "','", @types ) . "')");
	}
	else {
	    push(@clauses, "type='$type'");
	}
    }
    if (defined($user)) {
	my $uid = $user->uid();
	push(@clauses, "uid='$uid'");
    }
    if (defined($project)) {
	my $pid = $project->pid();
	push(@clauses, "pid='$pid'");
    }
    my $query_result =
	DBQueryWarn("select uuid from reservation_history ".
		    "where " . join(" AND ", @clauses) . " " .
		    "order by start asc");

    return ()
	if (!defined($query_result) || !$query_result->numrows);

    while (my ($uuid) = $query_result->fetchrow_array()) {
	my $record = Reservation->LookupHistorical($uuid);
	push(@answer, $record)
	    if (defined($record));
    }
    return @answer;
}

sub ExptTypes($) {
    my ($exptidx) = @_;

    my $query_result =
	DBQueryFatal("(SELECT DISTINCT( n.type ) FROM " .
		     " reserved AS r, nodes AS n WHERE " .
		     " r.node_id=n.node_id AND n.reservable=0 AND " .
		     " r.exptidx='$exptidx') ".
		     "union ".
		     "(SELECT n.node_id FROM " .
		     " reserved AS r, nodes AS n WHERE " .
		     " r.node_id=n.node_id AND n.reservable=1 AND " .
		     " r.exptidx='$exptidx')");

    my @types;
    while( my($type) = $query_result->fetchrow_array() ) {
	push( @types, $type );
    }

    return @types;
}

#
# Attempt to adjust the expiration time of an existing slice.
#
# Reservation->ExtendSlice( $slice, $new_expire, $error, $impotent, $force )
#
# $slice must be a reference to a GeniSlice object.
# $new_expire is a Unix time_t for the requested new expiration time
# (can be earlier or later than the current expiration time -- in principle
# an earlier time will always succeed, but a later time might fail
# depending on resource availability).
# $error (if defined) is a reference to a scalar; if defined and extension is
# not possible, a reason will be given here.
# $impotent (if defined and true) will attempt a hypothetical extension and
# return success or failure, but make no actual change to any state.
# $force (if defined and true) will make the change to the slice expiration
# even if it violates admission control constraints.
sub ExtendSlice($$$;$$$) {

    my ($class, $slice, $new_expire, $error, $impotent, $force) = @_;

    if( $new_expire <= str2time( $slice->expires() ) ) {
	if( $impotent ) {
	    return 0;
	} else {
	    my $result = $slice->SetExpiration( $new_expire );

	    if( $result < 0 && ref( $error ) ) {
		$$error = "Couldn't update slice expiration";
	    }

	    return $result;
	}
    }

    my $exptidx = $slice->exptidx();
    my $expt = Experiment->Lookup( $exptidx );
	
    my @types = ExptTypes( $exptidx );
    
    while( 1 ) {
	my $version = GetVersion( $class );
	foreach my $type ( @types ) {
	    my $reservations = LookupAll( $class, $type );
	    my $conflicttime;
	    foreach my $res ( @$reservations ) {
		if( defined( $res->pid() ) && defined( $res->eid() ) &&
		    $res->pid() eq $expt->pid() &&
		    $res->eid() eq $expt->eid() ) {
		    $res->{'END'} = $new_expire;
		    last;
		}
	    }
	    if( !$force && !IsFeasible( $class, $reservations, $error,
		\$conflicttime ) && $conflicttime < $new_expire ) {
		return -1;
	    }
	}
	return 0
	    if( $impotent );
	next if( !defined( BeginTransaction( $class, $version,
					     "`geni-cm`.geni_slices" ) ) );

	my $result = $slice->SetExpirationRes( $new_expire, emdb::DBNumber() );

	if( $result < 0 && ref( $error ) ) {
	    $$error = "Couldn't update slice expiration";
	}
	
	EndTransaction( $class );
	
	return $result;
    }
}

#
# This is similar to above, but for experiment autoswap.
#
sub AutoSwapTimeout($$$;$$$) {

    my ($class, $expt, $minutes, $error, $impotent, $force) = @_;

    #
    # So if the timeout is smaller then current, it is okay to just
    # change it: If autoswap is currently on, then this is safe. If
    # autoswap is currently off (and expt not locked down), then we
    # are going from no expiration set, so clearly that is safe too.
    #
    if ($minutes <= $expt->autoswap_timeout() || !$expt->autoswap()) {
	if ($impotent) {
	    return 0;
	}
	else {
	    my $expires;

	    if ($expt->state() eq EXPTSTATE_ACTIVATING()) {
		$expires = $expt->tstamp();
	    }
	    else {
		$expires = str2time($expt->swapin_last());
	    }
	    $expires += ($minutes * 60);
	    
	    if ($expt->SetExpiration($expires) ||
		$expt->SetAutoswapTimeout($minutes) ||
		$expt->SetAutoswap(1)) {
		if (ref($error)) {
		    $$error = "Could not update experiment autoswap_timeout";
		}
		return -1;
	    }
	    return 0;
	}
    }
    my @types = ExptTypes( $expt->idx() );

    #
    # We need a new expiration time, based on when the experiment actually
    # started. swapin_last does not work since it is set at the end of
    # swapin, which can take an arbitrary amount of time. We know that
    # autoswap() was already on (see above) so we can use the current
    # expiration time to compute a new expiration.
    #
    my $expires = $expt->expt_expires();
    if (!defined($expires)) {
	if (ref($error)) {
	    $$error = "experiment does not have expiration set";
	}
	return -1;
    }
    $expires = str2time($expires);
    # Add difference in autoswap_timeout to expiration;
    $expires += (($minutes - $expt->autoswap_timeout()) * 60);
    
    while( 1 ) {
	my $version = GetVersion( $class );
	foreach my $type ( @types ) {
	    my $reservations = LookupAll( $class, $type );
	    foreach my $res ( @$reservations ) {
		if( defined( $res->pid() ) && defined( $res->eid() ) &&
		    $res->pid() eq $expt->pid() &&
		    $res->eid() eq $expt->eid() ) {
		    $res->{'END'} = $expires;
		    last;
		}
	    }
	    if( !$force && !IsFeasible( $class, $reservations, $error ) ) {
		return -1;
	    }
	}
	return 0
	    if( $impotent );
	next if( !defined( BeginTransaction( $class, $version, "experiments")));

	if ($expt->SetExpiration($expires) ||
	    # This must be after above line.
	    $expt->SetAutoswapTimeout($minutes) ||
	    $expt->SetAutoswap(1)) {
	    if (ref($error)) {
		$$error = "Couldn't update experiment autoswap_timeout";
	    }
	    EndTransaction($class);
	    return -1;
	}
	EndTransaction( $class );
	
	return 0;
    }
}

#
# Estimate an upper bound for permissible expiry times on a slice.
#
# Reservation->MaxSliceExtension( $slice, $max, $error, $granularity )
#
# Will put the unix time stamp in $$max and return 0 if the slice can be
# extended, or -1 with $$error set.  If $granularity is set, the returned
# time will be lowered to a multiple of $granularity (e.g.,
# $granularity = 3600 would give a time on an hour boundary).
#
# Of course, this comes with no guarantees... for instance, somebody else
# could make a conflicting reservation/extension before this call returns,
# or before the caller has a chance to do anything useful with the result...
sub MaxSliceExtension($$$;$$) {

    my ($class, $slice, $max, $error, $granularity) = @_;

    my $cur_expire = str2time( $slice->expires() );
    my $max_expire = $cur_expire + 60 * 60 * 24 * 180;

    my $expt = $slice->GetExperiment();
    if (!defined($expt)) {
	if( ref( $error ) ) {
	    $$error = "No experiment for slice, cannot compute max.";
	}
	return -1;
    }
    if (! $expt->NodeList(1)) {
	if( ref( $error ) ) {
	    $$error = "No physical nodes, no max to compute.";
	}
	return -1;
    }
    my $exptidx = $expt->idx();
    my @types = ExptTypes( $exptidx );
    
    foreach my $type ( @types ) {
	my $reservations = LookupAll( $class, $type );
	foreach my $res ( @$reservations ) {
	    if( defined( $res->pid() ) && defined( $res->eid() ) &&
		$res->pid() eq $expt->pid() &&
		$res->eid() eq $expt->eid() ) {
		$res->{'END'} = $max_expire;
		last;
	    }
	}
	IsFeasible( $class, $reservations, undef, \$max_expire );
    }

    if( $max_expire <= $cur_expire ) {
	if( ref( $error ) ) {
	    $$error = "No extension possible.";
	}
	return -1;
    } else {
	$$max = $max_expire;

	if( defined( $granularity ) && $granularity > 1 ) {
	    $$max--;
	    $$max -= $$max % $granularity;
	}
	
	return 0;
    }
}

#
# Attempt to lock down an existing slice or experiment.
#
# Reservation->Lockdown( $target, $error, $impotent, $force )
#
# $target must be a reference to a GeniSlice object or Experiment object.
# $error (if defined) is a reference to a scalar; if defined and lockdown is
# not possible, a reason will be given here.
# $impotent (if defined and true) will attempt a hypothetical lockdown and
# return success or failure, but make no actual change to any state.
# $force (if defined and true) will turn on lockdown even if it violates
# admission control constraints.
sub Lockdown($$;$$$) {

    my ($class, $target, $error, $impotent, $force) = @_;
    my $expt;
    
    # It's always a successful no-op if already locked down.
    if (ref($target) eq "GeniSlice") {
	return 0 if( $target->lockdown() );
	$expt = Experiment->Lookup( $target->exptidx() );
	return -1
	    if (!defined($expt));
    }
    elsif (ref($target) eq "Experiment") {
	return 0 if( $target->lockdown() );
	$expt = $target;
    }
    else {
	$$error = "Do not know how to lockdown $target" if (defined($error));
	return -1;
    }

    my $coderef = sub {
	my ($error) = @_;
	my $result;
	
	if (ref($target) eq "GeniSlice") {
	    $result = $target->SetLockdown( 0 );
	}
	else {
	    $result = $target->LockDown( 1 );
	}
	if( $result < 0 && ref( $error ) ) {
	    $$error = "Couldn't update slice or experiment lockdown";
	}
	return $result;
    };
    return LockdownAux($class, $expt, $coderef, $error, $impotent, $force);
}

#
# Ditto swappable and autoswap. We can use the same support function below.
#
sub DisableSwapping($$;$$$)
{
    my ($class, $experiment, $error, $impotent, $force) = @_;

    my $coderef = sub {
	my ($error) = @_;
	my $result;

	$result = $experiment->SetSwappable(0);

	if( $result < 0 && ref( $error ) ) {
	    $$error = "Couldn't update swappable";
	}
	return $result;
    };
    return LockdownAux($class, $experiment,
		       $coderef, $error, $impotent, $force);
}
sub DisableAutoSwap($$;$$$)
{
    my ($class, $experiment, $error, $impotent, $force) = @_;

    my $coderef = sub {
	my ($error) = @_;
	my $result;

	if ($experiment->SetAutoswap(0) || $experiment->SetExpiration(undef)) {
	    if (ref($error)) {
		$$error = "Couldn't update autoswap";
	    }
	    return -1;
	}
	return 0;
    };
    return LockdownAux($class, $experiment,
		       $coderef, $error, $impotent, $force);
}

#
# Support for above.
#
sub LockdownAux($$$$$$)
{
    my ($class, $expt, $coderef, $error, $impotent, $force) = @_;
    my $exptidx = $expt->idx();
    my @types = ExptTypes( $exptidx );

    while( 1 ) {
	my $version = GetVersion( $class );
	foreach my $type ( @types ) {
	    my $reservations = LookupAll( $class, $type );
	    foreach my $res ( @$reservations ) {
		if( defined( $res->pid() ) && defined( $res->eid() ) &&
		    $res->pid() eq $expt->pid() &&
		    $res->eid() eq $expt->eid() ) {
		    $res->{'END'} = undef; # lockdowns last forever
		    last;
		}
	    }
	    if( !$force && !IsFeasible( $class, $reservations, $error ) ) {
		return -1;
	    }
	}
	return 0
	    if( $impotent );
	next if (!defined(BeginTransaction($class, $version, "experiments")));

	my $result = &$coderef($error);
	
	EndTransaction( $class );
	
	return $result;
    }    
}

#
# Strictly for admission control in the mapper. For geni experiments,
# LookupAll uses the current slice expiration to determine when the
# experiment ends. But for mapper admission control we use experiment
# expires, since on the geni path you can both modify an expriment and
# change its expiration at the same time. We do not want to change the
# slice expiration until we confirm that the mapper allows it. 
#
sub ExpectedEnd($$) {
    
    my ($class, $experiment) = @_;

    #
    # Geni experiments are locked down and not swappable, so we want
    # to use the expt_expires instead.
    #
    if (($experiment->lockdown() || !$experiment->swappable()) &&
	!$experiment->geniflags()) {
	return undef;
    }
    elsif ($experiment->geniflags()) {
	if (!defined($experiment->expt_expires())) {
	    print STDERR "ExpectedEnd: No expiration for $experiment\n";
	    return undef;
	}
	return str2time($experiment->expt_expires());
    }
    elsif (defined($experiment->expt_expires())) {
	return str2time($experiment->expt_expires());
    }
    #
    # This should not happen, execpt that we sometimes run the mapper in
    # debugging mode. So if we are here and the experiment is swapped, use
    # the current time.
    #
    print STDERR "ExpectedEnd: No expiration for $experiment\n";
    if ($experiment->state() eq EXPTSTATE_SWAPPED() &&
	$experiment->autoswap()) {
	return time() + ($experiment->autoswap_timeout() * 60);
    }
    return undef;
}

#
# Estimate an upper bound for node type count available for an experiment.
#
# Reservation->MaxSwapIn( $experiment, $type )
#
# Will return estimated number of available nodes.
sub MaxSwapIn($$$) {

    my ($class, $experiment, $type) = @_;
    my $MAX = 10000;
    my $overflow;
    my $details;

    DBQueryFatal("lock tables reserved write, users read, groups read, projects read, future_reservations read, nodes as n read, reserved as r read, experiments as e read, experiment_stats as stats read, next_reserve as nr read, `geni-cm`.geni_slices as s read, project_reservations as pr read, reservation_version write, node_attributes as a read");        
    
    my $reservations = LookupAll( $class, $type, undef, \$details );
    #print $details . "\n" if ($type eq "d430");

    foreach my $res ( @$reservations ) {
	if( defined( $res->pid() ) && defined( $res->eid() ) &&
	    $res->pid() eq $experiment->pid() &&
	    $res->eid() eq $experiment->eid() ) {
	    # Found existing nodes already reserved to the experiment we're
	    # trying to allocate.  In this context, they should be considered
	    # as available.
	    $res->{'PID'} = undef;
	    $res->{'EID'} = undef;
	    $res->SetStart( 0 );
	    $res->SetEnd( undef );
	}
    }

    my $reservation = CreateImmediate( $class, $experiment->pid(),
				       $experiment->eid(),
				       $experiment->swapper(),
				       ExpectedEnd( $class, $experiment ),
				       $type, $MAX );

    push( @$reservations, $reservation );

    while( $reservation->nodes() > 0 &&
	   !IsFeasible( $class, $reservations, undef, undef, \$overflow ) ) {
	$reservation->SetNodes( $reservation->nodes() - $overflow );
    }
    DBQueryFatal("unlock tables");

    my $avail = $reservation->nodes() > 0 ? $reservation->nodes() : 0;

    # Now consider nodes prereserved to the project but currently unused.
    my $query_result = DBQueryFatal( "SELECT COUNT(*) FROM nodes AS n " .
				     "LEFT OUTER JOIN reserved AS r " .
				     "ON n.node_id=r.node_id " .
				     "WHERE r.pid IS NULL AND n.type='" .
				     $type . "' AND n.reserved_pid='" .
				     $experiment->pid() . "'" );
    my ($extra) = $query_result->fetchrow_array();
    
    return $avail + $extra;
}

#
# Estimate an upper bound for node counts (by type) available for an experiment.
#
# Reservation->MaxSwapInMap( $experiment )
#
# Will return a hash of estimated number of available nodes, keyed by type.
sub MaxSwapInMap($$) {

    my ($class, $experiment) = @_;
    my %counts = ();

    my $query_result = DBQueryFatal( "SELECT DISTINCT( type ) FROM " .
				     "future_reservations" );
    while( my ($type) = $query_result->fetchrow_array() ) {
	$counts{ $type } = MaxSwapIn( $class, $experiment, $type );
    }

    return \%counts;
}

#
# Reservable types for reservation system. Class Method.
#
sub ReservableTypes($)
{
    my ($class)  = @_;
    my @result   = ();
    my @alltypes = NodeType->AllTypes();
    
    foreach my $type (@alltypes) {
	#
	# In general only class=pc types are reservable, but we allow
	# for override using a type attribute.
	#
	next
	    if ($type->class() ne "pc" && !$type->reservable());

	my $typename = $type->type();
	
	#
	# Skip if no physical testnodes of this type.
	#
	my $query_result =
	    DBQueryWarn("select count(n.node_id) from nodes as n ".
			"left join node_attributes as a on ".
			"     a.node_id=n.node_id and ".
			"     a.attrkey='not_reservable' ".
			"where n.type='$typename' and ".
			"      n.role='" . $Node::NODEROLE_TESTNODE . "' and ".
			"      n.reservable=0 and ".
			"      a.attrvalue is null");
	return ()
	    if (!$query_result);
	next
	    if (!$query_result->numrows);
	
	my ($count) = $query_result->fetchrow_array();
	next
	    if (!$count);
	push(@result, $type);
    }
    return @result;
}

#
# Reservable nodes for reservation system. Class Method.
#
sub ReservableNodes($)
{
    my ($class)  = @_;
    my @result   = ();
	
    #
    # Skip if no physical testnodes of this type.
    #
    my $query_result =
	DBQueryWarn("select node_id from nodes ".
		    "where reservable=1");
    return ()
	if (!$query_result || !$query_result->numrows);

    while (my ($node_id) = $query_result->fetchrow_array()) {
	my $node = Node->Lookup($node_id);
	push(@result, $node)
	    if (defined($node));
    }
    return @result;
}

#
# Mark the reservation for cancellation because it has not been used.
# We also mark the notified_unused flag so that we do not interefere
# with command line cancellation (and cancel cancellation).
#
# We are wrapped in a transaction by the caller. 
#
sub MarkUnused($$)
{
    my ($self, $when) = @_;
    my $idx = $self->idx();

    if ($when) {
	DBQueryWarn("update future_reservations set ".
		    "  cancel=FROM_UNIXTIME($when), notified_unused=now() ".
		    "where idx='$idx'")
	    or return -1;
    }
    else {
	DBQueryWarn("update future_reservations set ".
		    "  cancel=null, notified_unused=null ".
		    "where idx='$idx'")
	    or return -1;
    }
    $self->{'CANCEL'} = $when;
    $self->{'NOTIFIED_UNUSED'} = $when;
    return 0
}
sub ClearUnused($) { Reservation::MarkUnused($_[0], undef); }

#
# Similiar operation for cancel.
#
sub MarkCancel($$)
{
    my ($self, $when) = @_;
    my $idx = $self->idx();

    if ($when) {
	DBQueryWarn("update future_reservations set ".
		    "  cancel=FROM_UNIXTIME($when), ".
		    "    notified_unused=null ".
		    "where idx='$idx'")
	    or return -1;
    }
    else {
	DBQueryWarn("update future_reservations set ".
		    "  cancel=null, notified_unused=null ".
		    "where idx='$idx'")
	    or return -1;
    }
    $self->{'CANCEL'} = $when;
    $self->{'NOTIFIED_UNUSED'} = undef;
    return 0;
}
sub ClearCancel($) { Reservation::MarkCancel($_[0], undef); }

#
# Mark/Clear the override_unused flag to prevent idle detection
#
sub EnableIdleDetection($)
{
    my ($self) = @_;
    my $idx = $self->idx();

    DBQueryWarn("update future_reservations set ".
		"  override_unused=0 ".
		"where idx='$idx'")
	or return -1;

    $self->{'OVERRIDE_UNUSED'} = 0;
    return 0;
}
sub DisableIdleDetection($)
{
    my ($self) = @_;
    my $idx = $self->idx();

    DBQueryWarn("update future_reservations set ".
		"  override_unused=1 ".
		"where idx='$idx'")
	or return -1;

    $self->{'OVERRIDE_UNUSED'} = 1;
    return 0;
}

# _Always_ make sure that this 1 is at the end of the file...
1;
