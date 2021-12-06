#!/usr/bin/perl -wT
#
# Copyright (c) 2014-2020 University of Utah and the Flux Group.
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
# Common Emulab taint handling code.  These functions are meant to
# work with DB object abstractions, such as 'OSinfo' and 'Node'
# objects.  For an object abstraction to be compatible with this
# library, it needs to have a 'taint_states' DB column.  This column
# must then be accessible via a taint_states() method, and must be
# defined as a SQL set with the same set member options as in the
# "nodes" and "os_info" tables.  Finally, the object abstraction must
# have an Update() method, with the same semantics as those found in
# the Node and OSinfo objects.
#

package libTaintStates;

use strict;
use Exporter;
use vars qw(@ISA @EXPORT);
@ISA = qw(Exporter);
@EXPORT = qw();

use EmulabConstants;
use English;

# Function prototypes
sub GetTaintStates($);
sub IsTainted($;$);
sub TaintIs($@);
sub SetTaintStates($@);
sub AddTaint($$);
sub RemoveTaint($;$);

#
# Return the current set of taint states as an array.
#
sub GetTaintStates($)
{
    my ($obj) = @_;

    if (!ref($obj)) {
	warn "First argument is not an object!\n";
	return undef;
    }

    my $taint_states = $obj->taint_states();
    return ()
	if (!defined($taint_states) || $taint_states eq "");

    return split(',', $taint_states);
}

#
# Check to see if the object is tainted, or tainted in a
# particular way.
#
sub IsTainted($;$)
{
    my ($obj, $taint) = @_;

    if (!ref($obj)) {
	warn "First argument is not an object!\n";
	return -1;
    }

    my @taint_states = GetTaintStates($obj);
    return 0
	if (!@taint_states);

    # Just looking to see if any taint is applied?
    return 1
	if (!defined($taint));

    # Looking for a specific taint.
    return grep {$_ eq $taint} @taint_states;
}

#
# Check to see if the object has the exact taint list provided.
#
sub TaintIs($@)
{
    my ($obj, @taint_states) = @_;
    my @current = GetTaintStates($obj);

    return 0
	if (scalar(@taint_states) != scalar(@current));

    foreach my $state (@taint_states) {
	return 0
	    if (! grep {$_ eq $state} @current);
    }
    return 1;
}

#
# Explicitly set the taint states based on an input array of states.
# Squash any duplicates or empty/undefined entries.
#
sub SetTaintStates($@)
{
    my ($obj, @taint_states) = @_;

    if (!ref($obj)) {
	warn "First argument is not an object!\n";
	return -1;
    }

    my %newtstates = ();
    my %validtstates = map {$_ => 1} TB_TAINTSTATE_ALL();

    foreach my $tstate (@taint_states) {
	next if (!$tstate);
	if (!exists($validtstates{$tstate})) {
	    warn "Invalid taint state: $tstate\n";
	    return -1;
	}
	$newtstates{$tstate} = 1;
    }

    my $upd_str = scalar(keys %newtstates) ? 
	join(',', keys %newtstates) : "NULL";
    return $obj->Update({"taint_states" => $upd_str});
}

#
# Add a taint state to the object.
#
sub AddTaintState($$)
{
    my ($obj, $taint) = @_;

    if (!ref($obj)) {
	warn "First argument is not an object!\n";
	return -1;
    }

    return -1
	if (!defined($taint));

    if (!grep {$_ eq $taint} TB_TAINTSTATE_ALL()) {
	warn "Invalid taint state: $taint\n";
	return -1;
    }

    return 0
	if (IsTainted($obj, $taint));

    my @taint_states = GetTaintStates($obj);
    push @taint_states, $taint;

    return SetTaintStates($obj, @taint_states);
}

#
# Remove a taint state (or all taint states).
#
sub RemoveTaintState($;$)
{
    my ($obj, $taint) = @_;

    if (!ref($obj)) {
	warn "First argument is not an object!\n";
	return -1;
    }

    my @taint_states = GetTaintStates($obj);
    return 0
	if (!@taint_states);

    my @ntstates = ();
    if (defined($taint)) {
	@ntstates = grep {$_ ne $taint} @taint_states;
    }

    return SetTaintStates($obj, @ntstates);
}

#
# Inherit the taint states from an OS.  Take the union with whatever
# taint states are already set for the node.
#
sub InheritTaintStates($$)
{
    my ($obj, $osimage) = @_;
    require OSImage;

    if (!ref($osimage)) {
	my $tmp = OSImage->Lookup($osimage);
	if (!defined($tmp)) {
	    warn "Cannot lookup OSImage for $osimage\n";
	    return -1;
	}
	$osimage = $tmp;
    }

    my @taint_states = GetTaintStates($osimage);
    return 0
	if (!@taint_states);
    push @taint_states, GetTaintStates($obj);

    return SetTaintStates($obj, @taint_states);
}

# Next line required by perl for modules
1;
