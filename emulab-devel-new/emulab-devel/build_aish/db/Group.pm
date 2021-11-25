#!/usr/bin/perl -wT
#
# Copyright (c) 2005-2020 University of Utah and the Flux Group.
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
package Group;

use strict;
use Exporter;
use vars qw(@ISA @EXPORT);

@ISA    = "Exporter";
@EXPORT = qw ( );

use libdb;
use libtestbed;
use EmulabConstants;
use emutil;
use User;
use English;
use Data::Dumper;
use File::Basename;
use overload ('""' => 'Stringify');
use vars qw($MEMBERLIST_FLAGS_UIDSONLY $MEMBERLIST_FLAGS_ALLUSERS
	    $MEMBERLIST_FLAGS_GETTRUST $MEMBERLIST_FLAGS_EXCLUDE_LEADER);

# Configure variables
my $TB		  = "/users/achauhan/Cloudlab/CloudLabonESI/emulab-devel-new/emulab-devel/build_aish";
my $BOSSNODE      = "boss.cloudlab.umass.edu";
my $CONTROL	  = "ops.cloudlab.umass.edu";
my $TBOPS         = "testbed-ops\@ops.cloudlab.umass.edu";
my $TBAPPROVAL    = "testbed-approval\@ops.cloudlab.umass.edu";
my $TBAUDIT       = "testbed-audit\@ops.cloudlab.umass.edu";
my $TBBASE        = "https://www.cloudlab.umass.edu";
my $TBWWW         = "<https://www.cloudlab.umass.edu/>";
my $MIN_UNIX_GID  = 2000;

# Cache of instances to avoid regenerating them.
my %groups    = ();
BEGIN { use emutil; emutil::AddCache(\%groups); }
my $debug      = 0;

# MemberList flags.
$MEMBERLIST_FLAGS_UIDSONLY	 = 0x01;
$MEMBERLIST_FLAGS_ALLUSERS	 = 0x02;
$MEMBERLIST_FLAGS_GETTRUST	 = 0x04;
$MEMBERLIST_FLAGS_EXCLUDE_LEADER = 0x08;

# Little helper and debug function.
sub mysystem($)
{
    my ($command) = @_;

    print STDERR "Running '$command'\n"
	if ($debug);
    return system($command);
}

#
# Lookup by idx.
#
sub Lookup($$;$)
{
    my ($class, $arg1, $arg2) = @_;
    my $gid_idx;

    #
    # A single arg is either an index or a "pid,gid" or "pid/gid" string.
    #
    if (!defined($arg2)) {
	if ($arg1 =~ /^(\d*)$/) {
	    $gid_idx = $1;
	}
	elsif ($arg1 =~ /^([-\w]*),([-\w]*)$/ ||
	       $arg1 =~ /^([-\w]*)\/([-\w]*)$/) {
	    $arg1 = $1;
	    $arg2 = $2;
	}
	else {
	    return undef;
	}
    }
    elsif (! (($arg1 =~ /^[-\w]*$/) && ($arg2 =~ /^[-\w]*$/))) {
	return undef;
    }

    #
    # Two args means pid/gid lookup instead of gid_idx.
    #
    if (defined($arg2)) {
	my $groups_result =
	    DBQueryWarn("select gid_idx from groups ".
			"where pid='$arg1' and gid='$arg2'");

	return undef
	    if (! $groups_result || !$groups_result->numrows);

	($gid_idx) = $groups_result->fetchrow_array();
    }

    # Look in cache first
    return $groups{"$gid_idx"}
        if (exists($groups{"$gid_idx"}));
    
    my $query_result =
	DBQueryWarn("select * from groups where gid_idx='$gid_idx'");

    return undef
	if (!$query_result || !$query_result->numrows);

    my $self           = {};
    $self->{'GROUP'}   = $query_result->fetchrow_hashref();
    $self->{'PROJECT'} = undef;

    bless($self, $class);
    
    # Add to cache. 
    $groups{"$gid_idx"} = $self;
    
    return $self;
}
# accessors
sub field($$) { return ((! ref($_[0])) ? -1 : $_[0]->{'GROUP'}->{$_[1]}); }
sub pid($)	        { return field($_[0], "pid"); }
sub gid($)	        { return field($_[0], "gid"); }
sub pid_idx($)          { return field($_[0], "pid_idx"); }
sub gid_idx($)          { return field($_[0], "gid_idx"); }
sub leader($)           { return field($_[0], "leader"); }
sub leader_idx($)       { return field($_[0], "leader_idx"); }
sub created($)          { return field($_[0], "created"); }
sub description($)      { return field($_[0], "description"); }
sub unix_gid($)         { return field($_[0], "unix_gid"); }
sub unix_name($)        { return field($_[0], "unix_name"); }
sub expt_count($)       { return field($_[0], "expt_count"); }
sub expt_last($)        { return field($_[0], "expt_last"); }
sub wikiname($)         { return field($_[0], "wikiname"); }
sub mailman_password($) { return field($_[0], "mailman_password"); }

#
# Lookup given pid/gid. For backwards compat.
#
sub LookupByPidGid($$$)
{
    my ($class, $pid, $gid) = @_;

    return Group->Lookup($pid, $gid);
}

#
# Refresh a class instance by reloading from the DB.
#
sub Refresh($)
{
    my ($self) = @_;

    return -1
	if (! ref($self));

    my $gid_idx = $self->gid_idx();
    
    my $query_result =
	DBQueryWarn("select * from groups where gid_idx=$gid_idx");

    return -1
	if (!$query_result || !$query_result->numrows);

    $self->{'GROUP'} = $query_result->fetchrow_hashref();

    return 0;
}

#
# Stringify for output.
#
sub Stringify($)
{
    my ($self) = @_;
    
    my $pid     = $self->pid();
    my $gid     = $self->gid();
    my $gid_idx = $self->gid_idx();
    my $pid_idx = $self->pid_idx();

    return "[Group: $pid/$gid, IDX: $pid_idx/$gid_idx]";
}

#
# Perform some updates ...
#
sub Update($$)
{
    my ($self, $argref) = @_;

    # Must be a real reference. 
    return -1
	if (! ref($self));

    my $gid_idx = $self->gid_idx();

    my $query = "update groups set ".
	join(",", map("$_='" . $argref->{$_} . "'", keys(%{$argref})));

    $query .= " where gid_idx='$gid_idx'";

    return -1
	if (! DBQueryWarn($query));

    return Refresh($self);
}

#
# Class function to create new group and return object.
#
sub Create($$$$$$)
{
    my ($class, $project, $gid, $leader, $description, $unix_name) = @_;
    my $pid;
    my $pid_idx;
    
    #
    # Check that we can guarantee uniqueness of the unix group name.
    # 
    my $query_result =
	DBQueryFatal("select gid from groups ".
		     "where unix_name='$unix_name'");

    if ($query_result->numrows) {
	print "*** Could not form a unique Unix group name: $unix_name!\n";
	return undef;
    }

    # Every group gets a new unique index.
    my $gid_idx = TBGetUniqueIndex('next_gid');

    # If project is not defined, then creating initial project group.
    if (! $project) {
	$pid = $gid;
	$pid_idx = $gid_idx;
    }
    else {
	$pid = $project->pid();
	$pid_idx = $project->pid_idx();
    }

    #
    # Get me an unused unix gid. 
    #
    my $unix_gid;

    #
    # Start here, and keep going if the one picked from the DB just
    # happens to be in use (in the group file). Actually happens!
    #
    my $min_gid = $MIN_UNIX_GID;
    
    while (! defined($unix_gid)) {
	#
	# Get me an unused unix id. Nice query, eh? Basically, find
	# unused numbers by looking at existing numbers plus one, and
	# check to see if that number is taken. The point is to look
	# for holes since the space is only 16 bits, but this is really
	# ineffecient! Not really a problem with smallish number of groups
	# but terrible for 1000s!
	#
	$query_result =
	    DBQueryWarn("select g.unix_gid + 1 as start from groups as g ".
			"left outer join groups as r on ".
			"  g.unix_gid + 1 = r.unix_gid ".
			"where g.unix_gid>=$min_gid and ".
			"      g.unix_gid<50000 and ".
			"      r.unix_gid is null limit 1");

	return undef
	    if (! $query_result);

	my $unused;

	if (! $query_result->numrows) {
	    $unused = $min_gid;
	}
	else {
	    ($unused) = $query_result->fetchrow_array();
	}

	if (getgrgid($unused)) {
	    # Keep going.
	    $min_gid++;
	    if ($min_gid >= 50000) {
		print "*** WARNING: Could not find an unused unix_gid!\n";
		return undef;
	    }
	}
	else {
	    # Break out of loop.
	    $unix_gid = $unused;
	}
    }

    # And a UUID (universally unique identifier).
    my $uuid = NewUUID();
    if (!defined($uuid)) {
	print "*** WARNING: Could not generate a UUID!\n";
	return undef;
    }

    if (!DBQueryWarn("insert into groups set ".
		     " pid='$pid', gid='$gid', ".
		     " leader='" . $leader->uid() . "'," .
		     " leader_idx='" . $leader->uid_idx() . "'," .
		     " created=now(), ".
		     " description='$description', ".
		     " unix_name='$unix_name', ".
		     " gid_uuid='$uuid', ".
		     " gid_idx=$gid_idx, ".
		     " pid_idx=$pid_idx, ".
		     " unix_gid=$unix_gid")) {
	return undef;
    }

    if (! DBQueryWarn("insert into group_stats ".
		      "  (pid, gid, gid_idx, pid_idx, gid_uuid) ".
		      "values ('$pid','$gid',$gid_idx,$pid_idx,'$uuid')")) {
	DBQueryFatal("delete from groups where gid_idx='$gid_idx'");
	return undef;
    }
    my $newgroup = Group->Lookup($gid_idx);
    return undef
	if (! $newgroup);

    return $newgroup;
}

#
# Delete a group. This will eventually change to group archival.
#
sub Delete($)
{
    my ($self) = @_;

    # Must be a real reference. 
    return -1
	if (! ref($self));

    my $gid_idx = $self->gid_idx();

    # Order matters, groups table should be last so we can repeat if failure.
    my @tables = ("group_policies", "group_stats", "groups");

    foreach my $table (@tables) {
	return -1
	    if (!DBQueryWarn("delete from $table where gid_idx='$gid_idx'"));
    }
    
    return 0;
}

#
# Worker class method to edit group membership.
# Makes two passes, first checking consistency, then updating the DB.
#
sub EditGroup($$$$)
{
    my ($class, $group, $this_user, $argref, $usrerr_ref) = @_;

    my %mods;
    my $noreport;

    #
    # The default group membership cannot be changed, but the trust levels can.
    #
    my $defaultgroup = $group->IsProjectGroup();

    #
    # See if user is allowed to add non-members to group.
    # 
    my $grabusers = 0;
    if ($group->AccessCheck($this_user, TB_PROJECT_GROUPGRABUSERS())) {
	$grabusers = 1;
    }

    #
    # See if user is allowed to bestow group_root upon members of group.
    # 
    my $bestowgrouproot = 0;
    if ($group->AccessCheck($this_user, TB_PROJECT_BESTOWGROUPROOT())) {
	$bestowgrouproot = 1;
    }

    #
    # Grab the user list for the group. Provide a button selection of people
    # that can be removed. The group leader cannot be removed!
    # Do not include members that have not been approved
    # to main group either! This will force them to go through the approval
    # page first.
    #
    my @curmembers;
    if ($group->MemberList(\@curmembers, 
			   $MEMBERLIST_FLAGS_GETTRUST |
			   $MEMBERLIST_FLAGS_EXCLUDE_LEADER)) {
	$$usrerr_ref = "Error: Could not get member list for $group";
	return undef;
    }

    #
    # Grab the user list from the project. These are the people who can be
    # added. Do not include people in the above list, obviously! Do not
    # include members that have not been approved to main group either! This
    # will force them to go through the approval page first.
    #
    my @nonmembers;
    if ($group->NonMemberList(\@nonmembers)) {
	$$usrerr_ref = "Error: Could not get nonmember list for $group";
	return undef;
    }

    #
    # First pass does checks. Second pass does the real thing. 
    #
    my $g_pid = $group->pid();
    my $g_gid = $group->gid();
    my $target_user;
    my $target_idx;
    my $target_uid;
    my $oldtrust;
    my $newtrust;
    my $foo;
    my $bar;
    my $cmd;
    my $cmd_out;

    #
    # Go through the list of current members. For each one, check to see if
    # the checkbox for that person was checked. If not, delete the person
    # from the group membership. Otherwise, look to see if the trust level
    # has been changed.
    #
    if ($#curmembers>=0) {
	foreach $target_user (@curmembers) {
	    $target_uid = $target_user->uid();
	    $target_idx = $target_user->uid_idx();
	    $oldtrust   = $target_user->GetTempData();
	    $foo        = "change_$target_idx";

	    #
	    # Is member to be deleted?
	    # 
	    if (!$defaultgroup && !exists($argref->{$foo})) {
		# Yes.
		next;
	    }

	    #
	    # There should be a corresponding trust variable in the POST vars.
	    # Note that we construct the variable name and indirect to it.
	    #
	    $foo      = "U${target_idx}\$\$trust";
	    if (!exists($argref->{$foo}) || $argref->{$foo} eq "") {
		$$usrerr_ref = "Error: finding trust(1) for $target_uid";
		return undef;
	    }
	    $newtrust = $argref->{$foo};

	    if ($newtrust ne $Group::MemberShip::TRUSTSTRING_USER &&
		$newtrust ne $Group::MemberShip::TRUSTSTRING_LOCALROOT &&
		$newtrust ne $Group::MemberShip::TRUSTSTRING_GROUPROOT) {
		$$usrerr_ref = "Error: Invalid trust $newtrust for $target_uid";
		return undef;
	    }

	    #
	    # If the user is attempting to bestow group_root on a user who 
	    # did not previously have group_root, check to see if the operation is
	    # permitted.
	    #
	    if ($newtrust ne $oldtrust &&
		$newtrust eq $Group::MemberShip::TRUSTSTRING_GROUPROOT && 
		!$bestowgrouproot) {
		$$usrerr_ref = "Group: You do not have permission to bestow".
		    " group root trust to users in $g_pid/$g_gid!";
	    }

	    $group->Group::MemberShip::CheckTrustConsistency($target_user, 
							     $newtrust, 1);
	}
    }

    #
    # Go through the list of non members. For each one, check to see if
    # the checkbox for that person was checked. If so, add the person
    # to the group membership, with the trust level specified.
    # Only do this if user has permission to grab users. 
    #

    if ($grabusers && !$defaultgroup && $#nonmembers>=0) {
	foreach $target_user (@nonmembers) {
	    $target_uid = $target_user->uid();
	    $target_idx = $target_user->uid_idx();
	    $foo        = "add_$target_idx";

	    if (exists($argref->{$foo}) && $argref->{$foo} eq "permit"){
		#
		# There should be a corresponding trust variable in the POST vars.
		# Note that we construct the variable name and indirect to it.
		#
		$bar = "U${target_idx}\$\$trust";
		if (!exists($argref->{$bar}) || $argref->{$bar} eq "") {
		    $$usrerr_ref = "Error: finding trust(2) for $target_uid";
		    return undef;
		}
		$newtrust = $argref->{$bar};

		if ($newtrust ne $Group::MemberShip::TRUSTSTRING_USER &&
		    $newtrust ne $Group::MemberShip::TRUSTSTRING_LOCALROOT &&
		    $newtrust ne $Group::MemberShip::TRUSTSTRING_GROUPROOT) {
		    $$usrerr_ref = "Error: " .
			"Invalid trust $newtrust for $target_uid";
		    return undef;
		}

		if ($newtrust eq $Group::MemberShip::TRUSTSTRING_GROUPROOT
		    && !$bestowgrouproot) {
		    $$usrerr_ref = "Error: You do not have permission to".
			" bestow group root trust to users in $g_pid/$g_gid!";
		    return undef;
		}
		$group->Group::MemberShip::CheckTrustConsistency($target_user,
								 $newtrust, 1);
	    }
	}
    }

    #
    # Now do the second pass, which makes the changes. 
    #

    ### STARTBUSY("Applying group membership changes");

    #
    # Go through the list of current members. For each one, check to see if
    # the checkbox for that person was checked. If not, delete the person
    # from the group membership. Otherwise, look to see if the trust level
    # has been changed.
    #
    if ($#curmembers>=0) {
	foreach $target_user (@curmembers) {
	    $target_uid = $target_user->uid();
	    $target_idx = $target_user->uid_idx();
	    $oldtrust   = $target_user->GetTempData();
	    $foo        = "change_$target_idx";

	    if (!$defaultgroup && !exists($argref->{$foo})) {
		$cmd = "modgroups -r $g_pid:$g_gid $target_uid";
		##print $cmd . "\n";
		$cmd_out = `$cmd`;
		if ($?) {
		    $$usrerr_ref = "Error: " . $cmd_out;
		    return undef;
		}
	    }
	    #
	    # There should be a corresponding trust variable in the POST vars.
	    # Note that we construct the variable name and indirect to it.
	    #
	    $foo      = "U${target_idx}\$\$trust";
	    $newtrust = $argref->{$foo};

	    if ($oldtrust ne $newtrust) {
		$cmd = "modgroups -m $g_pid:$g_gid:$newtrust $target_uid";
		##print $cmd . "\n";
		$cmd_out = `$cmd`;
		if ($?) {		
		    $$usrerr_ref = "Error: " . $cmd_out;
		    return undef;
		}
	    }
	}
    }

    #
    # Go through the list of non members. For each one, check to see if
    # the checkbox for that person was checked. If so, add the person
    # to the group membership, with the trust level specified.
    #

    if ($grabusers && !$defaultgroup && $#nonmembers>=0) {
	foreach $target_user (@nonmembers) {
	    $target_uid = $target_user->uid();
	    $target_idx = $target_user->uid_idx();
	    $foo        = "add_$target_idx";    

	    if (exists($argref->{$foo}) && $argref->{$foo} eq "permit"){
		#
		# There should be a corresponding trust variable in the POST vars.
		# Note that we construct the variable name and indirect to it.
		#
		$bar      = "U${target_idx}\$\$trust";
		$newtrust = $argref->{$bar};

		$cmd = "modgroups -a $g_pid:$g_gid:$newtrust $target_uid";
		##print $cmd . "\n";
		$cmd_out = `$cmd`;
		if ($?) {
		    $$usrerr_ref = "Error: " . $cmd_out;
		    return undef;
		}

	    }
	}
    }

    return 1;
}

#
# Generic function to look up some table values given a set of desired
# fields and some conditions. Pretty simple, not widely useful, but it
# helps to avoid spreading queries around then we need to. 
#
sub TableLookUp($$$;$)
{
    my ($self, $table, $fields, $conditions) = @_;

    # Must be a real reference. 
    return -1
	if (! ref($self));
    
    my $gid_idx = $self->gid_idx();

    if (defined($conditions) && "$conditions" ne "") {
	$conditions = "and ($conditions)";
    }
    else {
	$conditions = "";
    }

    return DBQueryWarn("select distinct $fields from $table ".
		       "where gid_idx='$gid_idx' $conditions");
}

#
# Ditto for update.
#
sub TableUpdate($$$;$)
{
    my ($self, $table, $sets, $conditions) = @_;

    # Must be a real reference. 
    return -1
	if (! ref($self));

    if (ref($sets) eq "HASH") {
	$sets = join(",", map("$_='" . $sets->{$_} . "'", keys(%{$sets})));
    }
    my $gid_idx = $self->gid_idx();

    if (defined($conditions) && "$conditions" ne "") {
	$conditions = "and ($conditions)";
    }
    else {
	$conditions = "";
    }

    return 0
	if (DBQueryWarn("update $table set $sets ".
			"where gid_idx='$gid_idx' $conditions"));
    return -1;
}

#
# The basis of access permissions; what is the users trust level in the group.
#
sub Trust($$)
{
    my ($self, $user) = @_;
    
    #
    # User must be active to be trusted.
    #
    return PROJMEMBERTRUST_NONE()
	if ($user->status() ne USERSTATUS_ACTIVE());

    #
    # Must be a member of the group.
    #
    my $membership = $self->LookupUser($user);

    #
    # No membership is the same as no trust. True? Maybe an error instead?
    #
    return PROJMEMBERTRUST_NONE()
	if (!defined($membership));
    
    return TBTrustConvert($membership->trust());
}

#
# Check permissions.
#
sub AccessCheck($$$)
{
    my ($self, $user, $access_type) = @_;
    my $mintrust;
    
    # Must be a real reference. 
    return 0
	if (! ref($self));

    my $pid = $self->pid();
    my $gid = $self->gid();
    my $uid = $user->uid();

    if ($access_type < TB_PROJECT_MIN() ||
	$access_type > TB_PROJECT_MAX()) {
	print "*** Invalid access type: $access_type!\n";
	return 0;
    }
    # Admins do whatever they want. Treat leadgroup special though since
    # the user has to actually be a member of the project, not just an admin.
    return 1
	if ($user->IsAdmin() && $access_type != TB_PROJECT_LEADGROUP());

    if ($access_type == TB_PROJECT_READINFO()) {
	$mintrust = PROJMEMBERTRUST_USER();
    }
    elsif ($access_type == TB_PROJECT_MAKEGROUP() ||
	   $access_type == TB_PROJECT_DELGROUP()) {
	#
	# Project leader can always do this
	#
	if ($access_type == TB_PROJECT_DELGROUP()) {
	    my $project = $self->GetProject();
	    my $leader  = $self->GetLeader();
	    return 1
		if ($user->SameUser($leader));
	}
	$mintrust = PROJMEMBERTRUST_GROUPROOT();
    }
    elsif ($access_type == TB_PROJECT_LEADGROUP()) {
	#
	# Allow mere user (in default group) to lead a subgroup.
	# 
	$mintrust = PROJMEMBERTRUST_USER();
    }
    elsif ($access_type == TB_PROJECT_MAKEOSID() ||
	   $access_type == TB_PROJECT_MAKEIMAGEID() ||
	   $access_type == TB_PROJECT_CREATEEXPT() ||
	   $access_type == TB_PROJECT_CREATELEASE()) {
	$mintrust = PROJMEMBERTRUST_LOCALROOT();
    }
    elsif ($access_type == TB_PROJECT_ADDUSER() ||
	   $access_type == TB_PROJECT_EDITGROUP()) {
	#
	# If user is project_root or group_root in default group, 
	# allow them to add/edit/remove users in any group.
	#
	if (TBMinTrust($self->Trust($user), PROJMEMBERTRUST_GROUPROOT())) {
	    return 1;
	}
	#
	# Otherwise, editing a group requires group_root 
	# in that group.
	#	
	$mintrust = PROJMEMBERTRUST_GROUPROOT();
    }
    elsif ($access_type == TB_PROJECT_BESTOWGROUPROOT()) {
	#
	# If user is project_root, 
	# allow them to bestow group_root in any group.
	#
	if (TBMinTrust($self->Trust($user), PROJMEMBERTRUST_PROJROOT())) {
	    return 1;
	}

	if ($gid eq $pid)  {
	    #
	    # Only project_root can bestow group_root in default group, 
	    # and we already established that they are not project_root,
	    # so fail.
	    #
	    return 0;
	}
	else {
	    #
	    # Non-default group.
	    # group_root in default group may bestow group_root.
	    #
	    if (TBMinTrust($self->Trust($user), PROJMEMBERTRUST_GROUPROOT())) {
		return 1;
	    }

	    #
	    # group_root in the group in question may also bestow
	    # group_root.
	    #
	    $mintrust = PROJMEMBERTRUST_GROUPROOT();
	}
    }
    elsif ($access_type == TB_PROJECT_GROUPGRABUSERS()) {
	#
	# Only project_root or group_root in default group
	# may grab (involuntarily add) users into groups.
	#
	if (! $self->IsProjectGroup()) {
	    return $self->GetProject()->AccessCheck($user, $access_type);
	}
	$mintrust = PROJMEMBERTRUST_GROUPROOT();
    }
    elsif ($access_type == TB_PROJECT_DELUSER()) {
	$mintrust = PROJMEMBERTRUST_GROUPROOT();
    }
    else {
	print "*** Invalid access type: $access_type!\n";
	return 0;
    }
    return TBMinTrust($self->Trust($user), $mintrust);
}

#
# Change the leader for a group.
#
sub ChangeLeader($$)
{
    my ($self, $leader) = @_;

    # Must be a real reference. 
    return -1
	if (! (ref($self) && ref($leader)));

    my %args = ();
    $args{'leader'}     = $leader->uid();
    $args{'leader_idx'} = $leader->uid_idx();
    return $self->Update(\%args);
}

#
# Add a user to the group
#
sub AddMemberShip($$;$)
{
    my ($self, $user, $trust) = @_;

    # Must be a real reference. 
    return -1
	if (! (ref($self) && ref($user)));

    my $membership = $self->LookupUser($user);

    if (defined($membership)) {
	print "*** AddMemberShip: $user is already a member of $self!\n";
	return -1;
    }
    return Group::MemberShip->NewMemberShip($self, $user, $trust);
}

#
# Remove a user from a group
#
sub DeleteMemberShip($$)
{
    my ($self, $user) = @_;

    # Must be a real reference. 
    return -1
	if (! (ref($self) && ref($user)));

    return Group::MemberShip->DeleteMemberShip($self, $user);
}

#
# Send email notification of user joining a group.
#
sub SendJoinEmail($$)
{
    my ($self, $user) = @_;
    # Must be a real reference. 
    return -1
	if (! (ref($self) && ref($user)));

    #
    # Grab user info.
    #
    my $usr_email   = $user->email();
    my $usr_URL     = $user->URL();
    my $usr_addr    = $user->addr();
    my $usr_addr2   = $user->addr2();
    my $usr_city    = $user->city();
    my $usr_state   = $user->state();
    my $usr_zip	    = $user->zip();
    my $usr_country = $user->country();
    my $usr_name    = $user->name();
    my $usr_phone   = $user->phone();
    my $usr_title   = $user->title();
    my $usr_affil   = $user->affil();
    my $uid_idx     = $user->uid_idx();
    my $uid         = $user->uid();
    my $wanted_sslcert = (defined($user->initial_passphrase()) ?
			  "Yes" : "No");

    # And leader info
    my $leader      = $self->GetLeader();
    my $leader_name = $leader->name();
    my $leader_email= $leader->email();
    my $leader_uid  = $leader->uid();
    my $allleaders  = $self->LeaderMailList();
    my $pid         = $self->pid();
    my $gid         = $self->gid();

    $usr_addr2 = ""
	if (!defined($usr_addr2));
    $usr_URL = ""
	if (!defined($usr_URL));

    my $project = $self->GetProject();
    my $from    = "$usr_name '$uid' <$usr_email>";
    my $message =
	"$usr_name is trying to join your group $gid in project $pid.".
	"\n".
	"\n".
	"Contact Info:\n".
	"Name:            $usr_name\n".
	"Login ID:        $uid\n".
	"Email:           $usr_email\n".
	"Affiliation:     $usr_affil\n".
	"Address 1:       $usr_addr\n".
	"Address 2:       $usr_addr2\n".
	"City:            $usr_city\n".
	"State:           $usr_state\n".
	"ZIP/Postal Code: $usr_zip\n".
	"Country:         $usr_country\n";

    if ($project->isAPT() || $project->isCloud() ||
	$project->isPNet() || $project->isPowder()) {
	my $url = $project->wwwBase() . "/approveuser.php?uid=$uid&pid=$pid";
	    
	$message .=
	    "\n".
	    "You can approve or reject this user:\n\n".
	    "Approve:  ${url}&action=approve\n".
	    "or\n".
	    "Deny:     ${url}&action=deny\n".
	    "\n".
	    "Thanks\n";
	$from = $project->ApprovalEmailAddress();
    }
    else {
	$message .= 
	    "Phone:           $usr_phone\n".
	    "User URL:        $usr_URL\n".
	    "Job Title:       $usr_title\n".
	    "SSL Cert:        $wanted_sslcert\n".
	    "\n".
	    "Please return to $TBWWW,\n".
	    "log in, select the 'New User Approval' page, and enter your\n".
	    "decision regarding ${usr_name}'s membership in your project.\n".
	    "\n".
	    "Thanks,\n".
	    "Testbed Operations\n";
    }
    $project->SendEmail("$leader_name '$leader_uid' <$leader_email>",
			"$uid $pid Project Join Request",
			$message, $from, "CC: $allleaders");

    return 0;
}

#
# Send email notifying of initial approval testbed approval in a group.
#
sub SendApprovalEmail($$$)
{
    my ($self, $this_user, $target_user) = @_;

    # Must be a real reference. 
    return -1
	if (! (ref($self) && ref($this_user) && ref($target_user)));

    my $usr_email   = $target_user->email();
    my $usr_name    = $target_user->name();
    my $usr_uid     = $target_user->uid();
    my $this_name   = $this_user->name();
    my $this_email  = $this_user->email();
    my $pid         = $self->pid();
    my $gid         = $self->gid();
    my $allleaders  = $self->LeaderMailList();
    my $membership  = $self->LookupUser($target_user);
    my $project     = $self->GetProject();

    return -1
	if (!defined($membership));

    my $trust = $membership->trust();
    my $message = "This message is to notify you that you have been approved\n".
	"as a member of ";
    my $subject = "Membership Approved in '$pid/$gid'";

    if ($project->isAPT() || $project->isCloud() ||
	$project->isPNet() || $project->isPowder()) {
	my $helpurl  = $project->Brand()->UsersGroupURL();
	
	$message .= "project $pid.\n\n";
	$message .= "Please be sure to join the Help Forum at $helpurl";
	$subject  = "Membership Approved in Project $pid";
    }
    else {
	$message .= "$pid/$gid with '$trust' permission.";
    }
    $project->SendEmail("$usr_name '$usr_uid' <$usr_email>",
			$subject,
			"$message\n".
			"\n".
			"Thanks\n",
			$project->ApprovalEmailAddress(),
			"CC: $allleaders\n".
			"Bcc: $TBAUDIT");

    return 0;
}

sub SendTrustChangeEmail($$$)
{
    my ($self, $this_user, $target_user) = @_;

    # Must be a real reference. 
    return -1
	if (! (ref($self) && ref($this_user) && ref($target_user)));

    my $usr_email   = $target_user->email();
    my $usr_name    = $target_user->name();
    my $usr_uid     = $target_user->uid();
    my $this_name   = $this_user->name();
    my $this_email  = $this_user->email();
    my $pid         = $self->pid();
    my $gid         = $self->gid();
    my $allleaders  = $self->LeaderMailList();
    my $membership  = $self->LookupUser($target_user);

    return -1
	if (!defined($membership));

    my $trust = $membership->trust();

    SENDMAIL("$usr_name '$usr_uid' <$usr_email>",
             "Membership Change in '$pid/$gid' ",
	     "\n".
	     "This message is to notify you that your permission in $pid/$gid".
	     "\n".
	     "has been changed to '$trust'\n".
             "\n\n".
             "Thanks,\n".
             "Testbed Operations\n",
             "$this_name <$this_email>",
	     "CC: $allleaders\n".
	     "Bcc: $TBAUDIT");

    return 0;
}

#
# Lookup user membership in this group
#
sub LookupUser($$)
{
    my ($self, $user) = @_;

    # Must be a real reference. 
    return undef
	if (! (ref($self) && ref($user)));

    return Group::MemberShip->LookupUser($self, $user);
}

#
# Is this group the default project group. Returns boolean.
#
sub IsProjectGroup($)
{
    my ($self) = @_;

    # Must be a real reference. 
    return 0
	if (! ref($self));

    return $self->pid_idx() == $self->gid_idx();
}

#
# Return (and cache) the project for a group.
#
sub GetProject($)
{
    my ($self) = @_;
    require Project;

    # Must be a real reference. 
    return undef
	if (! ref($self));

    return $self->{'PROJECT'}
        if (defined($self->{'PROJECT'}));

    $self->{'PROJECT'} = Project->Lookup($self->pid_idx());
    return $self->{'PROJECT'};
}

#
# Is the user the group leader.
#
sub IsLeader($$)
{
    my ($self, $user) = @_;

    # Must be a real reference. 
    return 0
	if (! (ref($self) && ref($user)));

    return $self->leader_idx() == $user->uid_idx();
}

#
# Return user object for leader.
#
sub GetLeader($)
{
    my ($self) = @_;

    # Must be a real reference. 
    return undef
	if (! ref($self));

    return User->Lookup($self->leader_idx());
}

#
# Return a list of leaders (proj/group roots) in the format of an
# email address list.
#
sub LeaderMailList($)
{
    my ($self) = @_;

    # Must be a real reference. 
    return undef
	if (! ref($self));

    my $gid_idx   = $self->gid_idx();
    my $projroot  = $Group::MemberShip::TRUSTSTRING_PROJROOT;
    my $grouproot = $Group::MemberShip::TRUSTSTRING_GROUPROOT;
    my $mailstr   = "";
    
    my $query_result =
	DBQueryFatal("select distinct usr_name,u.uid,usr_email ".
		     "  from users as u ".
		     "left join group_membership as gm on ".
		     "     gm.uid_idx=u.uid_idx ".
		     "where gid_idx='$gid_idx' and ".
		     "      (trust='$projroot' or trust='$grouproot')");

    while (my ($name,$uid,$email) = $query_result->fetchrow_array()) {
	$mailstr .= ", "
	    if ($mailstr ne "");

	$mailstr .= '"' . $name . " (". $uid . ")\" <". $email . ">";
    }
    return $mailstr;
}

#
# Return list of members in this group, by specific trust.
#
sub MemberList($$;$$)
{
    my ($self, $prval, $flags, $desired_trust) = @_;

    # Must be a real reference. 
    return -1
	if (! ref($self));

    $flags = 0
	if (!defined($flags));

    my $gid_idx    = $self->gid_idx();
    my $pid_idx    = $self->pid_idx();
    my @result     = ();
    my $uids_only  = ($flags & $MEMBERLIST_FLAGS_UIDSONLY ? 1 : 0);
    my $gettrust   = ($flags & $MEMBERLIST_FLAGS_GETTRUST ? 1 : 0);
    my $exclude_leader = ($flags & $MEMBERLIST_FLAGS_EXCLUDE_LEADER ? 1 : 0);
    my $trust_clause;

    my $leader	    = $self->GetLeader();
    my $leader_idx;
    # There will be no leader during approveproject/Destroy.
    if (defined($leader)) {
	$leader_idx = $leader->uid_idx();
    }

    if (defined($desired_trust)) {
	$trust_clause = "and trust='$desired_trust'"
    }
    elsif ($flags & $MEMBERLIST_FLAGS_ALLUSERS) {
	$trust_clause = "";
    }
    else {
	$trust_clause = "and trust!='none'"
    }

    my $query_result =
	DBQueryWarn("select distinct m.uid_idx,m.uid,m.trust ".
		    "   from group_membership as m ".
		    "where m.pid_idx='$pid_idx' and ".
		    "      m.gid_idx='$gid_idx' $trust_clause");

    return -1
	if (!$query_result);

    while (my ($uid_idx, $uid, $trust) = $query_result->fetchrow_array()) {

	if ($exclude_leader && defined($leader) && $leader_idx == $uid_idx) {
	    next;
	}
	
	if ($uids_only) {
	    push(@result, $uid);
	    next;
	}
	
	my $user = User->Lookup($uid_idx);
	if (!defined($user)) {
	    print "Group::Memberlist: Could not map $uid_idx to object\n";
	    return undef;
	}
	if ($gettrust) {
	    # So caller can get this with GetTempData.
	    $user->SetTempData($trust);
	}
	push(@result, $user);
    }
    @$prval = @result;
    return 0;
}

#
# Grab the user list from the project. These are the people who can be
# added. Do not include people in the above list, obviously! Do not
# include members that have not been approved to main group either! This
# will force them to go through the approval page first.
#
sub NonMemberList($$;$)
{
    my ($self, $prval, $flags) = @_;

    # Must be a real reference. 
    return -1
	if (! ref($self));

    $flags = 0
	if (!defined($flags));

    my $gid_idx    = $self->gid_idx();
    my $pid_idx    = $self->pid_idx();
    my @result     = ();
    my $uids_only  = ($flags & $MEMBERLIST_FLAGS_UIDSONLY ? 1 : 0);

    my $query_result =
	DBQueryFatal("select m.uid_idx from group_membership as m ".
		     "left join group_membership as a on ".
		     "     a.uid_idx=m.uid_idx and ".
		     "     a.pid_idx=m.pid_idx and a.gid_idx='$gid_idx' ".
		     "where m.pid_idx='$pid_idx' and ".
		     "      m.gid_idx=m.pid_idx and a.uid_idx is NULL ".
		     "      and m.trust!='none'");

    return -1
	if (!$query_result);

    while (my ($uid_idx, $uid, $trust) = $query_result->fetchrow_array()) {
	if ($uids_only) {
	    push(@result, $uid);
	    next;
	}
	
	my $user = User->Lookup($uid_idx);
	if (!defined($user)) {
	    print "Group::NonMemberList: Could not map $uid_idx to object\n";
	    return undef;
	}
	push(@result, $user);
    }
    @$prval = @result;
    return 0;
}

#
# Update the aggregate stats.
#
sub UpdateStats($$$$$)
{
    my ($self, $mode, $duration, $pnodes, $vnodes) = @_;
	
    # Must be a real reference. 
    return -1
	if (! ref($self));

    my $gid_idx = $self->gid_idx();

    DBQueryWarn("update group_stats ".
		"set expt${mode}_count=expt${mode}_count+1, ".
		"    expt${mode}_last=now(), ".
		"    allexpt_duration=allexpt_duration+${duration}, ".
		"    allexpt_vnodes=allexpt_vnodes+${vnodes}, ".
		"    allexpt_pnodes=allexpt_pnodes+${pnodes}, ".
		"    allexpt_vnode_duration=".
		"        allexpt_vnode_duration+($vnodes * ${duration}), ".
		"    allexpt_pnode_duration=".
		"        allexpt_pnode_duration+($pnodes * ${duration}) ".
		"where gid_idx='$gid_idx'");

    if ($mode eq TBDB_STATS_SWAPIN() || $mode eq TBDB_STATS_START()) {
	DBQueryWarn("update groups set ".
		    " expt_last=now(),expt_count=expt_count+1 ".
		    "where gid_idx='$gid_idx'");
    }
    $self->Refresh();

    return 0;
}

#
# Bump last activity
#
sub BumpActivity($)
{
    my ($self) = @_;
	
    # Must be a real reference. 
    return -1
	if (! ref($self));

    my $gid_idx = $self->gid_idx();
    
    DBQueryWarn("update group_stats set last_activity=now() ".
		"where gid_idx='$gid_idx'");

    return 0;
}

#
# Check to see if a gid is valid.
#
sub ValidGID($$)
{
    my ($class, $gid) = @_;

    return TBcheck_dbslot($gid, "groups", "gid",
			  TBDB_CHECKDBSLOT_WARN()|
			  TBDB_CHECKDBSLOT_ERROR());
}

############################################################################

package Group::MemberShip;
use libdb;
use libtestbed;
use EmulabConstants;
use English;
use overload ('""' => 'Stringify');
use vars qw($TRUSTSTRING_NONE $TRUSTSTRING_USER
	    $TRUSTSTRING_LOCALROOT $TRUSTSTRING_GROUPROOT
	    $TRUSTSTRING_PROJROOT
	    @EXPORT_OK);

# Constants for membership.
$TRUSTSTRING_NONE		= "none";
$TRUSTSTRING_USER		= "user";
$TRUSTSTRING_LOCALROOT		= "local_root";
$TRUSTSTRING_GROUPROOT		= "group_root";
$TRUSTSTRING_PROJROOT		= "project_root";

# Why, why, why?
@EXPORT_OK = qw($TRUSTSTRING_NONE $TRUSTSTRING_USER
		$TRUSTSTRING_LOCALROOT $TRUSTSTRING_GROUPROOT
		$TRUSTSTRING_PROJROOT);

my @alltrustvals = ($TRUSTSTRING_NONE, $TRUSTSTRING_USER,
		    $TRUSTSTRING_LOCALROOT, $TRUSTSTRING_GROUPROOT,
		    $TRUSTSTRING_PROJROOT);

# Cache of instances to avoid regenerating them.
my %membership = ();

#
# Lookup user membership in a group. Group and User are references. Hmm ...
#
sub LookupUser($$$)
{
    my ($class, $group, $user) = @_;

    # Must be a real reference. 
    return -1
	if (! (ref($group) && ref($user)));

    my $pid_idx = $group->pid_idx();
    my $gid_idx = $group->gid_idx();
    my $uid_idx = $user->uid_idx();

    # Look in cache first
    return $membership{"$uid_idx:$gid_idx"}
        if (exists($membership{"$uid_idx:$gid_idx"}));
    
    my $query_result =
	DBQueryWarn("select * from group_membership ".
		    "where uid_idx=$uid_idx and gid_idx=$gid_idx");

    return undef
	if (!$query_result || !$query_result->numrows);

    my $self              = {};
    $self->{'MEMBERSHIP'} = $query_result->fetchrow_hashref();
    $self->{'GROUP'}      = $group;
    $self->{'USER'}       = $user;

    bless($self, $class);
    
    # Add to cache. 
    $membership{"$uid_idx:$gid_idx"} = $self;
    
    return $self;
}
# accessors
sub field($$) { return ((! ref($_[0])) ? -1 : $_[0]->{'MEMBERSHIP'}->{$_[1]});}
sub uid($)	        { return field($_[0], "uid"); }
sub pid($)	        { return field($_[0], "pid"); }
sub gid($)	        { return field($_[0], "gid"); }
sub uid_idx($)          { return field($_[0], "uid_idx"); }
sub pid_idx($)          { return field($_[0], "pid_idx"); }
sub gid_idx($)          { return field($_[0], "gid_idx"); }
sub trust($)            { return field($_[0], "trust"); }
sub date_applied($)     { return field($_[0], "date_applied"); }
sub date_approved($)    { return field($_[0], "date_approved"); }
sub group($)            { return $_[0]->{'GROUP'}; }
sub user($)             { return $_[0]->{'USER'}; }
sub IsApproved($)       { return $_[0]->trust() eq $TRUSTSTRING_NONE ? 0 : 1; }
    
#
# Is user trust in the group at least equal to the supplied trust
#
sub MinTrust($$)
{
    my ($self, $trust) = @_;

    return TBMinTrust(TBTrustConvert($self->trust()), TBTrustConvert($trust));
}

#
# Refresh a class instance by reloading from the DB.
#
sub Refresh($)
{
    my ($self) = @_;

    return -1
	if (! ref($self));

    my $uid_idx = $self->uid_idx();
    my $gid_idx = $self->gid_idx();

    my $query_result =
	DBQueryWarn("select * from group_membership ".
		    "where uid_idx=$uid_idx and gid_idx=$gid_idx");

    return -1
	if (!$query_result || !$query_result->numrows);

    $self->{'MEMBERSHIP'} = $query_result->fetchrow_hashref();

    return 0;
}

#
# Stringify for output.
#
sub Stringify($)
{
    my ($self) = @_;
    
    my $uid     = $self->uid();
    my $pid     = $self->pid();
    my $gid     = $self->gid();
    my $uid_idx = $self->uid_idx();
    my $pid_idx = $self->pid_idx();
    my $gid_idx = $self->gid_idx();
    my $trust   = $self->trust();

    return "[MemberShip: $uid/$trust/$pid/$gid]";
}

#
# Perform some updates ...
#
sub Update($$)
{
    my ($self, $argref) = @_;

    # Must be a real reference. 
    return -1
	if (! ref($self));

    my $uid_idx = $self->uid_idx();
    my $gid_idx = $self->gid_idx();

    my $query = "update group_membership set ".
	join(",", map("$_='" . $argref->{$_} . "'", keys(%{$argref})));

    $query .= " where gid_idx='$gid_idx' and uid_idx='$uid_idx'";

    return -1
	if (! DBQueryWarn($query));

    return Refresh($self);
}

#
# Create new membership in a group. This is a "class" method.
#
sub NewMemberShip($$$;$)
{
    my ($class, $group, $user, $trust) = @_;
    my $clause = "";
    
    # Must be a real reference. 
    return -1
	if (! (ref($group) && ref($user)));

    my $uid     = $user->uid();
    my $pid     = $group->pid();
    my $gid     = $group->gid();
    my $uid_idx = $user->uid_idx();
    my $pid_idx = $group->pid_idx();
    my $gid_idx = $group->gid_idx();

    $trust = $TRUSTSTRING_NONE
	if (!defined($trust));
    
    # Sanity check.
    if (! grep {$_ eq $trust} @alltrustvals) {
	print STDERR "*** NewMemberShip: Not a valid trust: $trust\n";
	return -1;
    }

    # If current trust is none, then requesting membership.
    $clause = ", date_approved=now() "
	if ($trust ne $TRUSTSTRING_NONE);

    DBQueryWarn("insert into group_membership set ".
		"     uid='$uid', uid_idx=$uid_idx, ".
		"     pid='$pid', pid_idx=$pid_idx, ".
		"     gid='$gid', gid_idx=$gid_idx, ".
		"     trust='$trust', ".
		"     date_applied=now() $clause ")
	or return -1;

    # Mark as needing an update.
    $user->BumpModified();

    return 0;
}

#
# Delete membership from a group. This is a "class" method.
#
sub DeleteMemberShip($$$)
{
    my ($class, $group, $user) = @_;
    my $clause = "";
    
    # Must be a real reference. 
    return -1
	if (! (ref($group) && ref($user)));

    my $uid     = $user->uid();
    my $pid     = $group->pid();
    my $gid     = $group->gid();
    my $uid_idx = $user->uid_idx();
    my $pid_idx = $group->pid_idx();
    my $gid_idx = $group->gid_idx();

    # Remove from cache.
    delete($membership{"$uid_idx:$gid_idx"})
	if (exists($membership{"$uid_idx:$gid_idx"}));

    DBQueryWarn("delete from group_membership ".
		"where gid_idx='$gid_idx' and uid_idx='$uid_idx'")
	or return -1;

    # Mark as needing an update.
    $user->BumpModified();

    return 0;
}

#
# Modify a membership trust value.
#
sub ModifyTrust($$)
{
    my ($self, $trust) = @_;
    my $clause = "";

    # Must be a real reference. 
    return -1
	if (! ref($self));

    # Sanity check.
    if (! grep {$_ eq $trust} @alltrustvals) {
	print STDERR "*** ModifyTrust: Not a valid trust: $trust\n";
	return -1;
    }

    my $uid_idx = $self->uid_idx();
    my $gid_idx = $self->gid_idx();

    # If current trust is none, then also update date_approved.
    $clause  = ", date_approved=now() "
	if ($self->trust() eq $TRUSTSTRING_NONE);

    DBQueryWarn("update group_membership set trust='$trust' $clause ".
		"where gid_idx='$gid_idx' and uid_idx='$uid_idx'")
	or return -1;

    # Mark as needing an update.
    $self->user()->BumpModified();

    return Refresh($self);
}

#
# Trust consistency.
#
sub CheckTrustConsistency($$$$)
{
    my ($self, $user, $newtrust, $fail) = @_;
    my $uid	   = $user->uid();
    my $pid	   = $self->pid();
    my $gid	   = $self->gid();
    my $uid_idx	   = $user->uid_idx();
    my $pid_idx	   = $self->pid_idx();
    my $gid_idx	   = $self->gid_idx();
    my $trust_none = $TRUSTSTRING_NONE;
    my $project	   = $self->Group::GetProject();

    # 
    # set $newtrustisroot to 1 if attempting to set a rootful trust,
    # 0 otherwise.
    #
    my $newtrustisroot = TBTrustConvert($newtrust) > PROJMEMBERTRUST_USER() ? 1 : 0;

    #
    # If changing subgroup trust level, then compare levels.
    # A user may not have root privs in the project and user privs
    # in the subgroup; it makes no sense to do that and can violate trust.
    #
    my $projtrustisroot;
    if ($pid_idx != $gid_idx) {
	#
	# Setting non-default "sub"group.
	# Verify that if user has root in project,
	# we are setting a rootful trust for him in 
	# the subgroup as well.
	#
	$projtrustisroot =
	    ($project->Trust($user) > PROJMEMBERTRUST_USER() ? 1 : 0);

	if ($projtrustisroot > $newtrustisroot) {
	    print("*** User $uid may not have a root trust level in ".
		    "the default group of $pid, ".
		    "yet be non-root in subgroup $gid!\n");
	    return 0;
	}
    }
    else {
	#
	# Setting default group.
	# Do not verify anything (yet.)
	#
	my $projtrustisroot = $newtrustisroot;
    }

    #
    # Get all the subgroups not equal to the subgroup being changed.
    # 
    my $query_result =
	DBQueryFatal("select trust,gid from group_membership ".
		     "where uid_idx='$uid_idx' and ".
		     "      pid_idx='$pid_idx' and ".
		     "      gid_idx!=pid_idx and ".
		     "      gid_idx!='$gid_idx' and ".
		     "      trust!='$trust_none'");

    while (my ($grptrust, $ogid) = $query_result->fetchrow_array()) {

	# 
	# Get what the users trust level is in the 
	# current subgroup we are looking at.
	#
	my $grptrustisroot = 
	    TBTrustConvert($grptrust) > PROJMEMBERTRUST_USER() ? 1 : 0;

	#
	# If users trust level is higher in the default group than in the
	# subgroup we are looking at, this is wrong.
	#
	if ($projtrustisroot > $grptrustisroot) {
	    print("*** User $uid may not have a root trust level in ".
		    "the default group of $pid, ".
		    "yet be non-root in subgroup $ogid!/n");
	    return 0;

	}

	if ($pid_idx != $gid_idx) {
	    #
	    # Iff we are modifying a subgroup, 
	    # Make sure that the trust we are setting is as
	    # rootful as the trust we already have set in
	    # every other subgroup.
	    # 
	    if ($newtrustisroot != $grptrustisroot) { 
		print("*** User $uid may not mix root and ".
			"non-root trust levels in ".
			"different subgroups of $pid!/n");
		return 0;
	    }
	}
    }
    return 1;
}

#
# Return group_exports info, as a plain hash.
#
sub PeerExports($$)
{
    my ($self, $pref) = @_;
    my $pid_idx = $self->pid_idx();
    my $gid_idx = $self->gid_idx();
    my $result  = {};

    my $query_result =
	DBQueryWarn("select e.*,p.* from group_exports as e ".
		    "left join emulab_peers as p on p.name=e.peer ".
		    "where e.pid_idx='$pid_idx' and e.gid_idx='$gid_idx'");

    while (my $row = $query_result->fetchrow_hashref()) {
	my $peer = $row->{'name'};
	$result->{$peer} = $row;
    }
    $$pref = $result;
    return 0;
}

# _Always_ make sure that this 1 is at the end of the file...
1;

