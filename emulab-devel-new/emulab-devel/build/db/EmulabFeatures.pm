#!/usr/bin/perl -wT
#
# Copyright (c) 2009-2011, 2018 University of Utah and the Flux Group.
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
package EmulabFeatures;

use strict;
use Exporter;
use vars qw(@ISA @EXPORT $debug $verbose);

@ISA    = "Exporter";
@EXPORT = qw();

# Configure variables
my $TB		= "/users/mshobana/emulab-devel/build";
my $BOSSNODE    = "boss.cloudlab.umass.edu";
my $TBDOCBASE   = "http://www.cloudlab.umass.edu";
my $MAINSITE    = 0;

$debug   = 0;
$verbose = 0;

use emdb;

#
# Lookup a feature by its name.
#
sub Lookup($$)
{
    my ($class, $token) = @_;

    if (! ($token =~ /^[-\w]+$/)) {
	return undef;
    }
    my $query_result =
	DBQueryWarn("select * from emulab_features where feature='$token'");
    return undef
	if (! ($query_result && $query_result->numrows));

    my $self            = {};
    $self->{"DBROW"}    = $query_result->fetchrow_hashref();
    
    bless($self, $class);
    return $self;
}
sub feature($)		{ return $_[0]->{'DBROW'}->{'feature'}; }
sub description($)      { return $_[0]->{'DBROW'}->{'description'}; }
# Global disable flag.
sub disabled($)         { return $_[0]->{'DBROW'}->{'disabled'}; }
# Global enable flag.
sub enabled($)          { return $_[0]->{'DBROW'}->{'enabled'}; }
sub added($)            { return $_[0]->{'DBROW'}->{'added'}; }

#
# Make a new feature.
#
sub Create($$$)
{
    my ($class, $featurename, $description) = @_;

    my $feature = EmulabFeatures->Lookup($featurename);
    return $feature
	if (defined($feature));

    my $safe_description = DBQuoteSpecial($description);

    DBQueryWarn("replace into emulab_features set ".
		" feature='$featurename', added=now(), ".
		" description=$safe_description")
	or return undef;

    return EmulabFeatures->Lookup($featurename);
}

#
# Delete a feature.
#
sub Delete($)
{
    my ($self) = @_;
    my $featurename = $self->feature();

    DBQueryWarn("delete from user_features where feature='$featurename'")
	or return -1;
    DBQueryWarn("delete from group_features where feature='$featurename'")
	or return -1;
    DBQueryWarn("delete from experiment_features where feature='$featurename'")
	or return -1;
    DBQueryWarn("delete from emulab_features where feature='$featurename'")
	or return -1;

    return 0;
}

#
# Set/Clear the global enable and disable flags
#
sub SetGlobalEnable($$)
{
    my ($self, $value) = @_;
    my $featurename = $self->feature();

    $value = ($value ? 1 : 0);
    
    DBQueryWarn("update emulab_features set enabled='$value' ".
		"where feature='$featurename'")
	or return -1;

    return 0;
}
sub SetGlobalDisable($$)
{
    my ($self, $value) = @_;
    my $featurename = $self->feature();

    $value = ($value ? 1 : 0);
    
    DBQueryWarn("update emulab_features set disabled='$value' ".
		"where feature='$featurename'")
	or return -1;

    return 0;
}

#
# Add a feature to a group or user.
#
sub Enable($$)
{
    my ($self, $target) = @_;
    my $featurename = $self->feature();

    if (ref($target) eq "User") {
	my $uid_idx = $target->uid_idx();
	my $uid     = $target->uid();
	
	my $query_result =
	    DBQueryWarn("select * from user_features ".
			"where feature='$featurename' and uid_idx='$uid_idx'");
	return -1
	    if (!$query_result);
	return 0
	    if ($query_result->numrows);
	DBQueryWarn("replace into user_features set ".
		    " feature='$featurename', added=now(), ".
		    " uid='$uid', uid_idx='$uid_idx'")
	    or return -1;
	
	return 0;
    }
    elsif (ref($target) eq "Group" || ref($target) eq "Project") {
	if (ref($target) eq "Project") {
	    $target = $target->GetProjectGroup();
	}
	my $pid_idx = $target->pid_idx();
	my $gid_idx = $target->gid_idx();
	my $pid     = $target->pid();
	my $gid     = $target->gid();
	
	my $query_result =
	    DBQueryWarn("select * from group_features ".
			"where feature='$featurename' and gid_idx='$gid_idx'");
	return -1
	    if (!$query_result);
	return 0
	    if ($query_result->numrows);
	DBQueryWarn("replace into group_features set ".
		    " feature='$featurename', added=now(), ".
		    " gid='$gid', gid_idx='$gid_idx', ".
		    " pid='$pid', pid_idx='$pid_idx'")
	    or return -1;
	
	return 0;
    }
    elsif (ref($target) eq "Experiment") {
	my $exptidx = $target->idx();
	my $pid     = $target->pid();
	my $eid     = $target->eid();
	
	my $query_result =
	    DBQueryWarn("select * from experiment_features ".
			"where feature='$featurename' and exptidx='$exptidx'");
	return -1
	    if (!$query_result);
	return 0
	    if ($query_result->numrows);
	DBQueryWarn("replace into experiment_features set ".
		    " feature='$featurename', added=now(), ".
		    " eid='$eid', pid='$pid', exptidx='$exptidx'")
	    or return -1;
	
	return 0;
    }
    return -1;
}

#
# Remove a feature from a group or user.
#
sub Disable($$)
{
    my ($self, $target) = @_;
    my $featurename = $self->feature();

    if (ref($target) eq "User") {
	my $uid_idx = $target->uid_idx();
	my $uid     = $target->uid();
	
	DBQueryWarn("delete from user_features ".
		    "where feature='$featurename' and uid_idx='$uid_idx'")
	    or return -1;
	return 0;
    }
    elsif (ref($target) eq "Group" || ref($target) eq "Project") {
	if (ref($target) eq "Project") {
	    $target = $target->GetProjectGroup();
	}
	my $pid_idx = $target->pid_idx();
	my $gid_idx = $target->gid_idx();
	my $pid     = $target->pid();
	my $gid     = $target->gid();
	
	DBQueryWarn("delete from group_features ".
		    "where feature='$featurename' and gid_idx='$gid_idx'")
	    or return -1;
	
	return 0;
    }
    elsif (ref($target) eq "Experiment") {
	my $exptidx = $target->idx();
	
	DBQueryWarn("delete from experiment_features ".
		    "where feature='$featurename' and exptidx='$exptidx'")
	    or return -1;
	
	return 0;
    }
    return -1;
}

#
# Delete all features for a target, as when that target is deleted.
#
sub DeleteAll($$)
{
    my ($class, $target) = @_;

    if (ref($target) eq "User") {
	my $uid_idx = $target->uid_idx();
	
	DBQueryWarn("delete from user_features where uid_idx='$uid_idx'")
	    or return -1;
	return 0;
    }
    elsif (ref($target) eq "Group") {
	my $gid_idx = $target->gid_idx();
	
	DBQueryWarn("delete from group_features where gid_idx='$gid_idx'")
	    or return -1;

	return 0;
    }
    elsif (ref($target) eq "Project") {
	my $pid_idx = $target->pid_idx();
	
	DBQueryWarn("delete from group_features where pid_idx='$pid_idx'")
	    or return -1;

	return 0;
    }
    elsif (ref($target) eq "Experiment") {
	my $exptidx = $target->idx();
	
	DBQueryWarn("delete from experiment_features where exptidx='$exptidx'")
	    or return -1;
	
	return 0;
    }
    return -1;
}

sub FeatureEnabled($$$$)
{
    my ($class, $featurename, $user, $group, $experiment) = @_;

    print STDERR "Checking for feature $featurename.\n"
	if ($verbose);

    #
    # See if feature is globally disabled;
    #
    my $feature = EmulabFeatures->Lookup($featurename);
    # A non existent feature is always disabled.
    # Do not warn; not all sites will have the same set.
    if (!defined($feature)) {
	print STDERR "*** WARNING: ".
	    "Checking for non-existent Emulab Feature: $featurename\n"
	    if ($MAINSITE || $debug);
	return 0;
    }
    # Globally disabled.
    if ($feature->disabled()) {
	print STDERR "  Feature is globally disabled\n"
	    if ($debug);
	return 0;
    }
    # Globally enabled.
    if ($feature->enabled()) {
	print STDERR "  Feature is globally enabled\n"
	    if ($debug);
	return 1;
    }
    my $enabled = 0;

    if (defined($user)) {
	my $uid_idx = $user->uid_idx();
	
	my $query_result =
	    DBQueryWarn("select * from user_features ".
			"where feature='$featurename' and uid_idx='$uid_idx'");

	return 0
	    if (!$query_result);

	print STDERR "  Feature is " .
	    ($query_result->numrows ? "enabled" : "disabled") . " for $user\n"
	    if ($debug);

	$enabled += $query_result->numrows;
    }

    if (defined($group)) {
	my $pid_idx = $group->pid_idx();
	my $gid_idx = $group->gid_idx();
	
	my $query_result =
	    DBQueryWarn("select * from group_features ".
			"where feature='$featurename' and ".
			"      pid_idx='$pid_idx' and gid_idx='$gid_idx'");

	return 0
	    if (!$query_result);

	print STDERR "  Feature is " .
	    ($query_result->numrows ? "enabled" : "disabled") . " for $group\n"
	    if ($debug);

	$enabled += $query_result->numrows;
    }

    if (defined($experiment)) {
	my $exptidx = $experiment->idx();
	
	my $query_result =
	    DBQueryWarn("select * from experiment_features ".
			"where feature='$featurename' and ".
			"      exptidx='$exptidx'");

	return 0
	    if (!$query_result);

	print STDERR "  Feature is " .
	    ($query_result->numrows ? "enabled" : "disabled") .
	    " for $experiment\n"
	    if ($debug);

	$enabled += $query_result->numrows;
    }
    print STDERR "  Feature is " . ($enabled ? "enabled\n" : "disabled\n")
	if ($verbose);
    
    return $enabled;
}

#
# List of all current features.
#
sub List($)
{
    my ($class)   = @_;
    my @features  = ();

    my $query_result =
	DBQueryWarn("select feature from emulab_features order by feature");
    return undef
	if (!defined($query_result));

    while (my ($featurename) = $query_result->fetchrow_array()) {
	my $feature = EmulabFeatures->Lookup($featurename);
	push(@features, $feature)
	    if (defined($feature));
    }
    return @features;
}

#
# List users and groups a feature is enabled for.
#
sub ListEnabled($$$$)
{
    my ($self, $pusers, $pgroups, $pexp) = @_;
    my $featurename = $self->feature();
    my @users  = ();
    my @groups = ();
    my @experiments = ();
    require Group;
    require User;
    require Experiment;

    my $query_result =
	DBQueryWarn("select uid_idx from user_features ".
		    "where feature='$featurename' ".
		    "order by uid");
    return -1
	if (!defined($query_result));

    while (my ($uid_idx) = $query_result->fetchrow_array()) {
	my $user = User->Lookup($uid_idx);
	push(@users, $user)
	    if (defined($user));
    }

    $query_result =
	DBQueryWarn("select gid_idx from group_features ".
		    "where feature='$featurename' ".
		    "order by pid,gid");
    return -1
	if (!defined($query_result));

    while (my ($gid_idx) = $query_result->fetchrow_array()) {
	my $group = Group->Lookup($gid_idx);
	push(@groups, $group)
	    if (defined($group));
    }

    $query_result =
	DBQueryWarn("select exptidx from experiment_features ".
		    "where feature='$featurename' ".
		    "order by pid,eid");
    return -1
	if (!defined($query_result));

    while (my ($idx) = $query_result->fetchrow_array()) {
	my $experiment = Experiment->Lookup($idx);
	push(@experiments, $experiment)
	    if (defined($experiment));
    }

    @$pusers  = @users;
    @$pgroups = @groups;
    @$pexp    = @experiments;
    return 0;
}

1;
