#!/usr/bin/perl -w
#
# Copyright (c) 2000-2019 University of Utah and the Flux Group.
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

#
# This is a module so it can be used from the fast RPC path.
#
package ResUtil;
use Exporter;

@ISA = "Exporter";
@EXPORT = qw (CollectReservations CreateTimeline ComputeCounts
              ReservationUtilization);

# After package decl.
use strict;
use English;
use Date::Parse;
use Data::Dumper;
use POSIX qw(strftime);

# Emulab
use Reservation;
use Project;
use emutil;

# Debugging.
my $debug = 0;
sub DebugOn() { $debug = 2; };

#
# Collect the reservations we are interested in.
#
sub CollectReservations($$$)
{
    my ($project, $useronly, $allres) = @_;
    
    #
    # By default we look at all current reservations for a specific project.
    # Optionally add all historical reservations for the project.
    # Optionally look at reservations for a specific user in the project.
    #
    my @reservations = Reservation->ProjectReservations($project, $useronly,
							undef, 1);
    if ($allres) {
	#
	# Grab all of the historical reservations and append.
	#
	my @more = Reservation->HistoricalReservations($project,
						       $useronly, undef);
	@reservations = (@reservations, @more);
    }
    if (!@reservations) {
	return ();
    }
    if ($debug) {
	print "There are " . scalar(@reservations) . " reservations\n";
    }
    # Sort to make sure the earliest is first.
    @reservations = sort {$a->start() <=> $b->start()} @reservations;
    return @reservations;
}

#
# Create a timeline of alloc/free operations, using the project usage
# since the earliest reservation.
#

sub CreateTimeline($@)
{
    my ($project, @reservations) = @_;

    #
    # Remember all the types we care about; when computing the counts
    # do not bother with nodes that are not in the set of types reserved.
    #
    my %typesinuse = ();
    
    foreach my $res (@reservations) {
	my $type  = $res->type();	
	$typesinuse{$type} = $type;
    }
    
    # We want the earliest/latest reservation for getting project usage();
    my $earliest  = $reservations[0];
    if ($debug) {
	print "The earliest reservation start is " .
	    POSIX::strftime("%m/%d/20%y %H:%M:%S",
			    localtime($earliest->start())) . " \n";
    }
    #
    # We want to bound the end of the search to the latest end if we
    # have only historial reservations.
    #
    # We have to watch for reservations that are deleted before they
    # expire; that is the actual end time for the reservation.
    #
    my $sortfunc = sub {
	my $a  = $_[0];
	my $b  = $_[1];
	my $s1 = (defined($a->deleted()) ? $a->deleted() : $a->end());
	my $s2 = (defined($b->deleted()) ? $b->deleted() : $b->end());
	return $s1 <=> $s2;
    };
    my @tmp = sort $sortfunc @reservations;
    my $latest = $tmp[-1];
    my $end = (defined($latest->deleted()) ?
	       $latest->deleted() : $latest->end());
    $end = time() if ($end > time());

    if ($debug) {
	print "The latest reservation end is " .
	    POSIX::strftime("%m/%d/20%y %H:%M:%S", localtime($end)) . " \n";
    }
    
    # Get the usage since the beginning of the earliest reservation.
    my $usage = $project->Usage($earliest->start(), $end);
    if ($debug) {
	print "There are " . scalar(@$usage) . " usage records\n";
    }

    @tmp = ();
    foreach my $ref (@$usage) {
	foreach my $type (keys(%typesinuse)) {
	    if (exists($ref->{'nodes'}->{$type})) {
	        $ref->{'types'}->{$type} = {"count" => 1};
	    }
	}
	foreach my $type (keys(%{$ref->{'types'}})) {
	    if (exists($typesinuse{$type})) {
		push(@tmp, $ref);
		last;
	    }
	}
    }
    if (!scalar(@tmp)) {
	print STDERR "There are no usage records left to process\n"
	    if ($debug);
	return ();
    }
    if ($debug > 1) {
	print Dumper(@tmp);
    }
    
    # Form a timeline of changes in allocation.
    my @timeline = ();

    foreach my $ref (@tmp) {
	push(@timeline, 
	     {"t" => $ref->{'start'}, "details" => $ref, "op" => "alloc"});

	# Experiment ended so nodes are now free.
	push(@timeline, 
	     {"t" => $ref->{'end'}, "details" => $ref, "op" => "free"})
	    if ($ref->{'end'} ne "");
    }
    # And sort the new list.
    @timeline = sort {$a->{'t'} <=> $b->{'t'}} @timeline;

    #
    # Correlate the reservations with the sorted list using the start/end
    # of the reservation and the timestamps in the timeline. This tells us
    # what reservations are active at each point in the timeline.
    #
    foreach my $ref (@timeline) {
	my $stamp   = $ref->{'t'};
	my @reslist = ();

	#print Dumper($ref);

	#
	# This will eventually be too inefficient ...
	#
	foreach my $res (@reservations) {
	    my $resStart = $res->start();
	    my $resEnd   = $res->end();

	    if ($stamp >= $resStart && $stamp <= $resEnd) {
		push(@reslist, $res);
		next;
	    }
	    #
	    # But what if this usage record is for an experiment that started
	    # prior to the beginning of the reservation, and one of two cases
	    # is true: 1) The experiment is still running. 2) The end of the
	    # experiment is during the reservation.
	    #
	    # In both these cases the reservation is overlaps with the
	    # experiment.
	    #
	    if ($ref->{'op'} eq "alloc" && $stamp <= $resStart &&
		($ref->{'details'}->{'end'} eq "" ||
		 ($ref->{'details'}->{'end'} >= $resStart &&
		  $ref->{'details'}->{'end'} <= $resEnd))) {
		push(@reslist, $res);
		print "$res is active for $stamp\n" if ($debug);
	    }
	}
	next
	    if (!@reslist);
    
	# Each timestamp gets a list of active reservations.
	$ref->{'reservations'} = \@reslist;

	# Count up number of node/types reserved by the project and
	# by each user.
	my $pid = $project->pid();
	my $reserved = {$pid => {}};
	foreach my $res (@reslist) {
	    my $type  = $res->type();
	    my $nodes = $res->nodes();
	    my $uid   = $res->uid();

	    # Remember that we care about this type for later when doing
	    # allocated counts.
	    $typesinuse{$type} = $type;

	    if (!exists($reserved->{$pid}->{$type})) {
		$reserved->{$pid}->{$type} = 0;
	    }
	    $reserved->{$pid}->{$type} += $nodes;
	    
	    if (!exists($reserved->{$uid})) {
		$reserved->{$uid} = {};
	    }
	    if (!exists($reserved->{$uid}->{$type})) {
		$reserved->{$uid}->{$type} = 0;
	    }
	    $reserved->{$uid}->{$type} += $nodes;
	}
	$ref->{'reserved'} = $reserved;
    }
    # Hmm, this happens.
    return ()
	if (!@timeline);
	
    #
    # Now compute the node counts for each entry in the timeline.
    #
    my @counts = ComputeCounts($project, \%typesinuse, @timeline);

    return @counts
	if (1);

    #
    # We want to add additional entrys for the start of each reservation.
    #
    @tmp = ();
    
    foreach my $ref (@counts) {
	#
	# If this entry is after the timestamp for the first
	# reservation on the list (which is also sorted), then
	# create a new timeline entry for the very start of
	# the reservation so we have counts in use at the very
	# start (since often nodes will not be allocated till
	# sometime later).
	#
	while (@reservations &&
	       $ref->{'t'} >= $reservations[0]->start()) {
	    # Shallow copy.
	    my $new = { %{$ref} };
	    $new->{'t'} = $reservations[0]->start();
	    push(@tmp, $new);
	    shift(@reservations);
	}
	push(@tmp, $ref)
    }
    return @tmp;
}

#
# Now compute total number of nodes of each type in use at each stamp,
# starting with the counts in the first one. This gives us a timeline
# of nodes allocated and released by the project. We also compute counts
# for each user who is active during the timeline.
#
sub ComputeCounts($$@)
{
    my ($project, $typelist, @timeline) = @_;
    my $pid = $project->pid();

    #
    # This is the initial count, which is a copy of the type count array.
    # We also calculate nodes in use for each user, so the initial count 
    # is the starting point for the user in the initial record.
    #
    my %counts = map { $_ => 0 } keys(%{$typelist});
    foreach my $type (keys(%{$timeline[0]->{'details'}->{'types'}})) {
	# Skip types that are not in the set of reserved types.
	next
	    if (!exists($typelist->{$type}));
	    
	$counts{$type} =
	    $timeline[0]->{'details'}->{'types'}->{$type}->{'count'};
    }
    
    $timeline[0]->{'allocated'} = {
	$pid => \%counts,
	# Counts for the user in the first record.
	$timeline[0]->{'details'}->{'user_uid'} => { %counts },
    };

    #
    # Now loop over the rest of the timeline entries.
    #
    for (my $i = 1; $i < scalar(@timeline); $i++) {
	my $ref = $timeline[$i];
	my $types    = $ref->{'details'}->{'types'};
	my $user_uid = $ref->{'details'}->{'user_uid'};
	# Copy (shallow) of previous counts.
	my $allocated = { %{$timeline[$i - 1]->{'allocated'}} };
	# Copy (shallow) of previous project counts.
	my $pcounts = { %{$allocated->{$pid}} };
	# Copy (shallow) of previous user counts or new entry
	# if this is the first allocation by the user.
	my $ucounts = {};
	if (exists($allocated->{$user_uid})) {
	    $ucounts = { %{$allocated->{$user_uid}} };
	}

	# Now update the counts based on current entry.
	foreach my $type (keys(%$types)) {
	    # Skip types that are not in the set of reserved types.
	    next
		if (!exists($typelist->{$type}));
	    
	    my $count = $types->{$type}->{'count'};
	    # If this is a free, we want to subtract the count
	    if ($ref->{'op'} eq "free") {
		$count = 0 - $count;
	    }
	    if (exists($pcounts->{$type})) {
		$pcounts->{$type} += $count;
	    }
	    else {
		$pcounts->{$type} = $count;
	    }
	    if (exists($ucounts->{$type})) {
		$ucounts->{$type} += $count;
	    }
	    else {
		$ucounts->{$type} = $count;
	    }
	}
	$allocated->{$pid} = $pcounts;
	$allocated->{$user_uid} = $ucounts;
	$ref->{'allocated'} = $allocated;
    }
    #
    # OK, now we have the project timeline
    #
    my @bypid = map { {"t"         => $_->{'t'},
		       "allocated" => $_->{'allocated'},
		       "reserved"  => $_->{'reserved'},
		       "reslist"   => $_->{'reservations'}
	} } @timeline;

    if ($debug) {
	foreach my $ref (@bypid) {
	    my @counts = ();
	
	    print POSIX::strftime("%m/%d/20%y %H:%M:%S",
				  localtime($ref->{'t'}));
	    print "\n";
	    foreach my $res (@{$ref->{'reslist'}}) {
		print " " . $res . "\n";
	    }
	    foreach my $who (keys(%{$ref->{'reserved'}})) {
		my $clist = $ref->{'reserved'}->{$who};
		my @clist = map {$_ . ":" . $clist->{$_}} keys(%$clist);
		print "   $who: " . join(",", @clist) . "\n";
	    }
	    foreach my $who (keys(%{$ref->{'allocated'}})) {
		my $clist = $ref->{'allocated'}->{$who};
		my @clist = map {$_ . ":" . $clist->{$_}} keys(%$clist);
		print " $who: " . join(",", @clist) . "\n";
	    }
	}
    }
    return @bypid;
}

#
# Given a reservation details hash, calculate a utilization number
# from the history array.
#
sub ReservationUtilization($@)
{
    my ($res, @records) = @_;
    my $count      = $res->nodes();
    my $active     = defined($res->idx()) ? 1 : 0;
    my $resstart   = $res->start();
    my $resend     = ($active ? time() :
		      (defined($res->deleted()) ?
		       $res->deleted() : $res->end()));
    my $reshours   = (($resend - $resstart) / 3600) * $count;
    my $usedhours  = 0;
    my $inuse      = 0;
    my $laststamp  = $resstart;
    my $type       = $res->type();
    my $uid        = $res->uid();
    my @tmp        = @records;

    # Init for caller.
    $res->data('reshours', $reshours);
    $res->data('usedhours', undef);
    $res->data('utilization', undef);

    #
    # Scan past timeline entries that are *before* the start of the
    # reservation; these are experiments that were running when the
    # reservation started, and provide the number of nodes allocated
    # at the time the reservation starts.
    #
    while (@tmp) {
	my $ref       = $tmp[0];
	my $stamp     = $ref->{'t'};
	my $allocated = $ref->{'allocated'};
	$ref->{'tt'}  = TBDateStringGMT($ref->{'t'});

	last
	    if ($stamp >= $resstart);
	    
	# Watch for nothing allocated by the user at this time stamp
	my $using = 0;
	if (exists($allocated->{$uid})) {
	    $using = $allocated->{$uid}->{$type};
	}
	$inuse = $using;
	$inuse = $count if ($inuse > $count);
	shift(@tmp);
    }
    foreach my $ref (@tmp) {
	my $stamp     = $ref->{'t'};
	my $reserved  = $ref->{'reserved'};
	my $allocated = $ref->{'allocated'};
	$ref->{'tt'}  = TBDateStringGMT($ref->{'t'});

	# If this stamp is after the reservation, we can stop. The
	# last entry will be the current number of nodes used till
	# the end of the reservation. This entry is typically for the
	# end of an experiment start before the end of the reservation.
	last
	    if ($stamp > $resend);

	# Watch for nothing allocated by the user at this time stamp
	my $using = 0;
	if (exists($allocated->{$uid})) {
	    $using = $allocated->{$uid}->{$type};
	}
	$usedhours += (($stamp - $laststamp) / 3600) * $inuse;
	$laststamp  = $stamp;
	$inuse      = $using;
	$inuse      = $count if ($inuse > $count);
    }
    # And then a final entry for usage until the end of the reservation.
    if ($laststamp) {
	$usedhours += (($resend - $laststamp) / 3600) * $inuse;
    }
    $res->data('reshours', $reshours);
    $res->data('usedhours', $usedhours);
    my $utilization = POSIX::ceil(($usedhours/$reshours) * 100.0);
    $utilization = 100 if ($utilization > 100);
    $res->data('utilization', $utilization);

    return 0;
}

1;
