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
package Project;

use strict;
use Exporter;
use vars qw(@ISA @EXPORT @PROJDIRECTORIES @GROUPDIRECTORIES);

@ISA    = "Exporter";
@EXPORT = qw ();

use libdb;
use libtestbed;
use Brand;
use libEmulab;
use User;
use Group;
use English;
use Data::Dumper;
use File::Basename;
use overload ('""' => 'Stringify');

# Configure variables
my $TB		= "/users/achauhan/Cloudlab/CloudLabonESI/emulab-devel-new/emulab-devel/build_aish";
my $BOSSNODE    = "boss.cloudlab.umass.edu";
my $CONTROL	= "ops.cloudlab.umass.edu";
my $TBOPS       = "testbed-ops\@ops.cloudlab.umass.edu";
my $TBAPPROVAL  = "testbed-approval\@ops.cloudlab.umass.edu";
my $TBAUDIT	= "testbed-audit\@ops.cloudlab.umass.edu";
my $TBBASE      = "https://www.cloudlab.umass.edu";
my $TBWWW       = "<https://www.cloudlab.umass.edu/>";
my $OURDOMAIN   = "cloudlab.umass.edu";
my $PGENISUPPORT= 1;
my $WIKISUPPORT = 0;
my $WITHZFS     = 1;
my $WITHAMD     = 1;
my $ZFS_NOEXPORT= 1;
my $MAILMANSUPPORT = 0;
my $ADDPROJADMINLIST = "$TB/sbin/addprojadminlist";
my $EXPORTS_SETUP    = "$TB/sbin/exports_setup";

# These are duplicated in account/accountsetup.in ...
@PROJDIRECTORIES  = ("exp", "images", "logs", "deltas", "tarfiles", "rpms",
		     "groups", "tiplogs", "images/sigs", "templates");
@GROUPDIRECTORIES = ("exp", "images", "logs", "tarfiles", "rpms", "tiplogs");

# Cache of instances to avoid regenerating them.
my %projects   = ();
BEGIN { use emutil; emutil::AddCache(\%projects); }

my $debug      = 0;

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
sub Lookup($$)
{
    my ($class, $token) = @_;
    my $query_result;

    # Look in cache first
    return $projects{"$token"}
        if (exists($projects{"$token"}));

    #
    # For backwards compatability, look to see if the token is numeric
    # or alphanumeric. If numeric, assumes its an idx, otherwise a name.
    #
    if ($token =~ /^\d*$/) {
	$query_result =
	    DBQueryWarn("select * from projects where pid_idx='$token'");
    }
    elsif ($token =~ /^[-\w]*$/) {
	$query_result =
	    DBQueryWarn("select * from projects where pid='$token'");
    }
    else {
	return undef;
    }
    
    return undef
	if (!$query_result || !$query_result->numrows);

    my $self           = {};
    $self->{'PROJECT'} = $query_result->fetchrow_hashref();
    $self->{'GROUP'}   = Group->Lookup($self->{'PROJECT'}->{'pid_idx'});

    return undef
	if (!defined($self->{'GROUP'}));

    bless($self, $class);
    $self->{'BRAND'}   = Brand->Create($self->portal());
    
    # Add to cache. 
    $projects{$self->{'PROJECT'}->{'pid_idx'}} = $self;
    
    return $self;
}
# accessors
sub field($$) { return ((! ref($_[0])) ? -1 : $_[0]->{'PROJECT'}->{$_[1]}); }
sub pid($)	        { return field($_[0], "pid"); }
sub gid($)	        { return field($_[0], "pid"); }
sub pid_idx($)          { return field($_[0], "pid_idx"); }
sub gid_idx($)          { return field($_[0], "pid_idx"); }
sub head_uid($)         { return field($_[0], "head_uid"); }
sub head_idx($)         { return field($_[0], "head_idx"); }
sub created($)          { return field($_[0], "created"); }
sub description($)      { return field($_[0], "name"); }
sub why($)		{ return field($_[0], "why"); }
sub addr($)		{ return field($_[0], "addr"); }
sub URL($)		{ return field($_[0], "URL"); }
sub funders($)		{ return field($_[0], "funders"); }
sub num_members($)      { return field($_[0], "num_members"); }
sub num_pcs($)		{ return field($_[0], "num_pcs"); }
sub num_pcplab($)       { return field($_[0], "num_pcplab"); }
sub num_ron($)		{ return field($_[0], "num_ron"); }
sub public($)		{ return field($_[0], "public"); }
sub public_whynot($)    { return field($_[0], "public_whynot"); }
sub linked_to_us($)     { return field($_[0], "linked_to_us"); }
sub expt_count($)       { return field($_[0], "expt_count"); }
sub expt_last($)        { return field($_[0], "expt_last"); }
sub approved($)         { return field($_[0], "approved"); }
sub disabled($)         { return field($_[0], "disabled"); }
sub wikiname($)         { return field($_[0], "wikiname"); }
sub mailman_password($) { return field($_[0], "mailman_password"); }
sub allow_workbench($)  { return field($_[0], "allow_workbench"); }
sub hidden($)		{ return field($_[0], "hidden"); }
sub IsLocal($)		{ return (defined($_[0]->nonlocal_id()) ? 0 : 1); };
sub IsNonLocal($)	{ return (defined($_[0]->nonlocal_id()) ? 1 : 0); };
sub nonlocal_id($)	{ return field($_[0], "nonlocal_id"); }
sub nonlocal_type($)	{ return field($_[0], "nonlocal_type"); }
sub manager_urn($)	{ return field($_[0], "manager_urn"); }
sub portal($)		{ return field($_[0], "portal"); }
sub expert_mode($)	{ return field($_[0], "expert_mode"); }
sub Brand($)		{ return $_[0]->{'BRAND'}; }
sub isAPT($)	        { return $_[0]->Brand()->isAPT() ? 1 : 0; }
sub isCloud($)	        { return $_[0]->Brand()->isCloud() ? 1 : 0; }
sub isPNet($)	        { return $_[0]->Brand()->isPNet() ? 1 : 0; }
sub isPowder($)	        { return $_[0]->Brand()->isPowder() ? 1 : 0; }
sub isEmulab($)         { return $_[0]->Brand()->isEmulab() ? 1 : 0; }

# These come from the group not the project.
sub unix_gid($)         { return $_[0]->{'GROUP'}->unix_gid(); }
sub unix_name($)        { return $_[0]->{'GROUP'}->unix_name(); }

# Branding.
sub ApprovalEmailAddress($)  { return $_[0]->Brand()->ApprovalEmailAddress(); }
sub OpsEmailAddress($)       { return $_[0]->Brand()->OpsEmailAddress(); }
sub LogsEmailAddress($)      { return $_[0]->Brand()->LogsEmailAddress(); }
sub EmailTag($)              { return $_[0]->Brand()->EmailTag(); }
sub wwwBase($)               { return $_[0]->Brand()->wwwBase(); }
sub SignupURL($)             { return $_[0]->Brand()->SignupURL($_[0]); }
# So we can localize MAILTAG variable.
sub SendEmail($$$$;$$@)
{
    my ($self, $e, $s, $b, $f, $h, @files) = @_;
    
    return $self->Brand()->SendEmail($e, $s, $b, $f, $h, @files);
}

#
# Lookup given pid For backwards compat.
#
sub LookupByPid($$)
{
    my ($class, $pid) = @_;

    my $query_result =
	DBQueryWarn("select pid_idx from projects where pid='$pid'");

    return undef
	if (! $query_result || !$query_result->numrows);

    my ($pid_idx) = $query_result->fetchrow_array();

    return Project->Lookup($pid_idx);
}

#
# Lookup a nonlocal project.
#
sub LookupNonLocal($$)
{
    my ($class, $urn) = @_;
    my $safe_urn = DBQuoteSpecial($urn);

    my $query_result =
	DBQueryFatal("select pid_idx from projects ".
		     "where nonlocal_id=$safe_urn");

    return undef
	if (! $query_result || !$query_result->numrows);

    my ($pid_idx) = $query_result->fetchrow_array();

    return Project->Lookup($pid_idx);
}

#
# Refresh a class instance by reloading from the DB.
#
sub Refresh($)
{
    my ($self) = @_;

    return -1
	if (! ref($self));

    my $pid_idx = $self->pid_idx();
    
    my $query_result =
	DBQueryWarn("select * from projects where pid_idx=$pid_idx");

    return -1
	if (!$query_result || !$query_result->numrows);

    $self->{'PROJECT'} = $query_result->fetchrow_hashref();

    return $self->{'GROUP'}->Refresh();
}

#
# Stringify for output.
#
sub Stringify($)
{
    my ($self) = @_;
    
    my $pid     = $self->pid();
    my $pid_idx = $self->pid_idx();

    return "[Project: $pid, IDX: $pid_idx]";
}

sub DESTROY {
    my $self = shift;

    $self->{'PROJECT'}  = undef;
    $self->{'GROUP'}    = undef;
    $self->{'BRAND'}    = undef; 
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

    my $pid_idx = $self->pid_idx();

    my $query = "update projects set ".
	join(",", map("$_='" . $argref->{$_} . "'", keys(%{$argref})));

    $query .= " where pid_idx='$pid_idx'";

    return -1
	if (! DBQueryWarn($query));

    return Refresh($self);
}

#
# Class function to create new project and return object.
#
sub Create($$$$)
{
    my ($class, $pid, $leader, $argref) = @_;
    my $unix_gname = $pid;
    my $nonlocal   = (exists($argref->{'nonlocal_id'}) ? 1 : 0);
	
    #
    # The array of inserts is assumed to be safe already. Generate
    # a list of actual insert clauses to be joined below.
    #
    my @insert_data = (!defined($argref) ? () :
		       map("$_=" . DBQuoteSpecial($argref->{$_}),
			   keys(%{$argref})));

    # Form a proper unix group name, which is limited to 16 chars.
    if (length($pid) > 16) {
	$unix_gname  = substr($pid, 0, 16);
	my $maxtries = 9;
	my $count    = 0;
	while ($count < $maxtries) {
	    my $query_result =
		DBQueryFatal("select gid from groups ".
			     "where unix_name='$unix_gname'");
	    last
		if (!$query_result->numrows);

	    $count++;
	    $unix_gname = substr($pid, 0, 15) . "$count";
	}
	if ($count == $maxtries) {
	    print STDERR "Project->Create: ".
		"Could not form a unique Unix group name!";
	    return undef;
	}
    }

    # First create the underlying default group for the project.
    my $newgroup =
	Group->Create(undef, $pid, $leader, 'Default Group', $unix_gname);
    return undef
	if (!defined($newgroup));

    # Every project gets a new unique index, which comes from the group.
    my $pid_idx = $newgroup->gid_idx();

    # Now tack on other stuff we need.
    push(@insert_data, "pid='$pid'");
    push(@insert_data, "pid_idx='$pid_idx'");
    push(@insert_data, "head_uid='" . $leader->uid() . "'");
    push(@insert_data, "head_idx='" . $leader->uid_idx() . "'");
    push(@insert_data, "created=now()");

    # Insert into DB. 
    if (! DBQueryWarn("insert into projects set " . join(",", @insert_data))) {
	$newgroup->Delete();
	return undef;
    }

    if (! DBQueryWarn("insert into project_stats (pid, pid_idx) ".
		      "values ('$pid', $pid_idx)")) {
	$newgroup->Delete();
	DBQueryFatal("delete from projects where pid_idx='$pid_idx'");
	return undef;
    }
    my $newproject = Project->Lookup($pid_idx);
    return undef
	if (! $newproject);

    #
    # The creator of a group is not automatically added to the group,
    # but we do want that for a new project. 
    #
    if ($newgroup->AddMemberShip($leader) < 0) {
	$newgroup->Delete();
	DBQueryWarn("delete from project_stats where pid_idx=$pid_idx");
	DBQueryWarn("delete from projects where pid_idx=$pid_idx");
	return undef;
    }

    #
    # Now create the per-project Admin List
    #
    if (0 && $MAILMANSUPPORT && !$nonlocal) {
	my $res = system("$ADDPROJADMINLIST $pid");
	if ($res != 0) {
	    SENDMAIL($TBOPS, "Addprojadminlist failed!", 
		     "\"$ADDPROJADMINLIST $pid\" failed.\n".
		     "Details most likely in testbed-logs mail with \"suexec: webnewproj\"\n".
		     "in the subject.\n");
	}
    }

    return $newproject;
}

#
# Delete newly added project, as for errors.
#
sub Delete($)
{
    my ($self) = @_;
    my $pid_idx = $self->pid_idx();
    my $group   = $self->GetProjectGroup();

    $group->Delete()
	if (!defined($group));
    
    DBQueryWarn("delete from project_nsf_awards where pid_idx=$pid_idx")
	or return -1;
    DBQueryWarn("delete from project_stats where pid_idx=$pid_idx")
	or return -1;
    DBQueryWarn("delete from projects where pid_idx=$pid_idx")
	or return -1;

    return 0;
}

#
# Equality test for two projects. Not necessary in perl, but good form.
#
sub SameProject($$)
{
    my ($self, $other) = @_;

    # Must be a real reference. 
    return -1
	if (! (ref($self) && ref($other)));

    return $self->pid_idx() == $other->pid_idx();
}

#
# The basis of access permissions; what is the users trust level in the project
#
sub Trust($$)
{
    my ($self, $user) = @_;

    # Must be a real reference. 
    return PROJMEMBERTRUST_NONE()
	if (! ref($self));

    my $group = $self->GetProjectGroup();
    # Should not happen!
    return PROJMEMBERTRUST_NONE()
	if (!defined($group));

    return $group->Trust($user);
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

    my $group = $self->GetProjectGroup();
    # Should not happen!
    return 0
	if (!defined($group));

    return $group->AccessCheck($user, $access_type);
}

#
# Send newproject email; separate function so email can be resent.
#
sub SendNewProjectEmail($;$)
{
    my ($self, $firstproject) = @_;

    # Must be a real reference. 
    return -1
	if (! ref($self));

    $firstproject = 0
	if (!defined($firstproject));

    my $leader             = $self->GetLeader();
    my $usr_uid            = $leader->uid();
    my $usr_idx            = $leader->uid_idx();
    my $usr_title	   = $leader->title() || "";
    my $usr_name	   = $leader->name();
    my $usr_affil	   = $leader->affil();
    my $usr_email	   = $leader->email();
    my $usr_addr	   = $leader->addr() || "";
    my $usr_addr2	   = $leader->addr2();
    my $usr_city	   = $leader->city();
    my $usr_state	   = $leader->state();
    my $usr_zip	           = $leader->zip() || "";
    my $usr_country        = $leader->country();
    my $usr_phone	   = $leader->phone() || "";
    my $usr_URL            = $leader->URL();
    my $wikiname           = $leader->wikiname();
    my $returning          = $leader->status() ne $User::USERSTATUS_NEWUSER;
    my $usr_returning      = ($returning ? "Yes" : "No");
    my $wanted_sslcert     = (defined($leader->initial_passphrase()) ?
			      "Yes" : "No");
    my $proj_desc	   = $self->description();
    my $proj_URL           = $self->URL();
    my $proj_funders       = $self->funders();
    my $proj_public        = ($self->public() ? "Yes" : "No");
    my $proj_linked        = ($self->linked_to_us() ? "Yes" : "No");
    my $proj_whynotpublic  = $self->public_whynot();
    my $proj_members       = $self->num_members();
    my $proj_pcs           = $self->num_pcs();
    my $proj_plabpcs       = $self->num_pcplab();
    my $proj_ronpcs        = $self->num_ron();
    my $proj_why	   = $self->why();
    my $unix_gid           = $self->unix_gid();
    my $unix_name          = $self->unix_name();
    my $pid                = $self->pid();
    my $pid_idx            = $self->pid_idx();
    my $gid                = $self->pid();

    $usr_addr2 = ""
	if (!defined($usr_addr2));
    $usr_URL = ""
	if (!defined($usr_URL));
    $proj_whynotpublic = ""
	if (!defined($proj_whynotpublic));

    if ($returning || $firstproject) {
	SendProjAdminMail
	    ($self, "$usr_name '$usr_uid' <$usr_email>", "ADMIN",
	     "New Project '$pid' ($usr_uid)",
	     "'$usr_name' wants to start project '$pid'.\n".
	     "\n".
	     "Name:            $usr_name ($usr_uid/$usr_idx)\n".
	     "Project IDX:     $pid_idx\n".
	     "Returning User?: $usr_returning\n".
	     "Email:           $usr_email\n".
	     "User URL:        $usr_URL\n".
	     "Description:     $proj_desc\n".
	     "Project URL:     $proj_URL\n".
	     "Public URL:      $proj_public\n".
	     "Why Not Public:  $proj_whynotpublic\n".
	     "Link to Us?:     $proj_linked\n".
	     "Funders:         $proj_funders\n".
	     "Job Title:       $usr_title\n".
	     "Affiliation:     $usr_affil\n".
	     "Address 1:       $usr_addr\n".
	     "Address 2:       $usr_addr2\n".
	     "City:            $usr_city\n".
	     "State:           $usr_state\n".
	     "ZIP/Postal Code: $usr_zip\n".
	     "Country:         $usr_country\n".
	     "Phone:           $usr_phone\n".
	     "SSL Cert:        $wanted_sslcert\n".
	     "Members:         $proj_members\n".
	     "PCs:             $proj_pcs\n".
	     "Planetlab PCs:   $proj_plabpcs\n".
	     "RON PCs:         $proj_ronpcs\n".
	     "Unix GID:        $unix_name ($unix_gid)\n".
	     "Reasons:\n$proj_why\n\n".
	     "Please review the application and when you have made a \n".
	     "decision, go to $TBWWW and\n".
	     "select the 'Project Approval' page.");
    }
    else {
	SendProjAdminMail
	    ($self, "$usr_name '$usr_uid' <$usr_email>", "ADMIN",
	     "New Project '$pid' ($usr_uid)",
	     "'$usr_name' wants to start project '$pid'.\n".
	     "\n".
	     "Name:            $usr_name ($usr_uid/$usr_idx)\n".
	     "Project IDX:     $pid_idx\n".
	     "Email:           $usr_email\n".
	     "Returning User?: No\n".
	     "\n".
	     "No action is necessary until the user has verified the ".
	     "account.\n");
    }
    
    return 0;
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

    return User->Lookup($self->head_idx());
}

#
# Is the user the project leader.
#
sub IsLeader($$)
{
    my ($self, $user) = @_;

    # Must be a real reference. 
    return 0
	if (! (ref($self) && ref($user)));

    return $user->SameUser($self->GetLeader());
}

sub IsManager($$)
{
    my ($self, $user) = @_;

    # Must be a real reference. 
    return 0
	if (! (ref($self) && ref($user)));

    return TBMinTrust($self->Trust($user), PROJMEMBERTRUST_GROUPROOT());
}

sub IsMember($$)
{
    my ($self, $user) = @_;

    # Must be a real reference. 
    return 0
	if (! (ref($self) && ref($user)));

    return TBMinTrust($self->Trust($user), PROJMEMBERTRUST_USER());
}

#
# Return project group.
#
sub GetProjectGroup($)
{
    my ($self) = @_;

    # Must be a real reference. 
    return undef
	if (! ref($self));

    return $self->{'GROUP'};
}

#
# Generate a URN.
#
sub urn($)
{
    my ($self) = @_;
    my $pid  = $self->pid();

    return undef
	if (!$PGENISUPPORT);
    require GeniHRN;

    my $domain = "${OURDOMAIN}:${pid}";
    return GeniHRN->new(GeniHRN::Generate($domain, "project", $pid));
}
sub nonlocalurn($)
{
    my ($self) = @_;
    
    return undef
	if (!$PGENISUPPORT);
    require GeniHRN;

    if ($self->IsNonLocal()) {
	return GeniHRN->new($self->nonlocal_id());
    }
    return $self->urn();
}

#
# Return membership for user in the default group
#
sub LookupUser($$)
{
    my ($self, $user) = @_;

    # Must be a real reference. 
    return undef
	if (! (ref($self) && ref($user)));

    return $self->{'GROUP'}->LookupUser($user);
}

#
# Change the leader for a project.
#
sub ChangeLeader($$)
{
    my ($self, $leader) = @_;

    # Must be a real reference. 
    return -1
	if (! (ref($self) && ref($leader)));

    # Default group fits.
    $self->{'GROUP'}->ChangeLeader($leader) == 0
	or return -1;

    # Then the project
    my %args = ();
    $args{'head_uid'} = $leader->uid();
    $args{'head_idx'} = $leader->uid_idx();
    return $self->Update(\%args);
}

#
# Set the approval bit,
#
sub SetApproved($$)
{
    my ($self, $approved) = @_;

    # Must be a real reference. 
    return -1
	if (! (ref($self)));

    my %args = ("approved" => ($approved ? 1 : 0));
    return $self->Update(\%args);
}

#
# Delete a user from the project (and all subgroups of course). No checks
# are made; that should be done higher up. Optionally return list of groups
# from which the user was deleted.
#
sub DeleteUser($$;$)
{
    my ($self, $user, $plist) = @_;
    my @grouplist = ();

    # Must be a real reference. 
    return -1
	if (! (ref($self) && ref($user)));

    my $uid_idx = $user->uid_idx();
    my $pid_idx = $self->pid_idx();
    my $gid_idx = $pid_idx;

    # Need a list of all groups for the user in this project.
    # Should probably use a "class" method in the Groups module.
    my $query_result =
	DBQueryWarn("select gid_idx from group_membership ".
		    "where pid_idx=$pid_idx and uid_idx=$uid_idx");
    return -1
	if (! $query_result);
    return 0
	if (! $query_result->numrows);

    while (my ($idx) = $query_result->fetchrow_array()) {
	# Do main group last.
	next
	    if ($idx == $gid_idx);

	my $group = Group->Lookup($idx);
	return -1
	    if (!defined($group));

	return -1
	    if ($group->DeleteMemberShip($user) < 0);

	push(@grouplist, $group);
    }

    my $group = Group->Lookup($gid_idx);
    return -1
	if (!defined($group));

    return -1
	if ($group->DeleteMemberShip($user) < 0);

    if (defined($plist)) {
	@$plist = (@grouplist, $group);
    }
    return 0;
}

#
# List of subgroups for a project member (not including default group).
#
sub GroupList($$)
{
    my ($self, $plist) = @_;
    my @grouplist = ();

    # Must be a real reference. 
    return -1
	if (! (ref($self)));

    my $pid_idx = $self->pid_idx();

    my $query_result =
	DBQueryWarn("select gid_idx from groups ".
		    "where pid_idx=$pid_idx and pid_idx!=gid_idx");
    return -1
	if (! $query_result);
    
    return 0
	if (! $query_result->numrows);

    while (my ($idx) = $query_result->fetchrow_array()) {
	my $group = Group->Lookup($idx);
	return -1
	    if (!defined($group));

	push(@grouplist, $group);
    }
    @$plist = @grouplist;
    return 0;
}

#
# Find specific group in project.
#
sub LookupGroup($$)
{
    my ($self, $gid) = @_;
    my @grouplist = ();

    # Must be a real reference. 
    return -1
	if (! (ref($self)));

    my $pid_idx = $self->pid_idx();
    my $clause;

    if ($gid =~ /^\d*$/) {
	$clause = "gid_idx='$gid'";
    }
    elsif ($gid =~ /^[-\w]*$/) {
	$clause = "gid='$gid'";
    }
    else {
	return undef;
    }

    my $query_result =
	DBQueryWarn("select gid_idx from groups ".
		    "where pid_idx=$pid_idx and $clause");
    return undef
	if (! $query_result);
    
    return undef
	if (! $query_result->numrows);

    my ($gid_idx) = $query_result->fetchrow_array();
    return Group->Lookup($gid_idx);
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

    my $pid_idx = $self->pid_idx();

    DBQueryWarn("update project_stats ".
		"set expt${mode}_count=expt${mode}_count+1, ".
		"    expt${mode}_last=now(), ".
		"    allexpt_duration=allexpt_duration+${duration}, ".
		"    allexpt_vnodes=allexpt_vnodes+${vnodes}, ".
		"    allexpt_pnodes=allexpt_pnodes+${pnodes}, ".
		"    allexpt_vnode_duration=".
		"        allexpt_vnode_duration+($vnodes * ${duration}), ".
		"    allexpt_pnode_duration=".
		"        allexpt_pnode_duration+($pnodes * ${duration}) ".
		"where pid_idx='$pid_idx'");

    if ($mode eq TBDB_STATS_SWAPIN() || $mode eq TBDB_STATS_START()) {
	DBQueryWarn("update projects set ".
		    " expt_last=now(),expt_count=expt_count+1 ".
		    "where pid_idx='$pid_idx'");
    }

    $self->Refresh();

    return 0;
}

#
# Return last activity as a unix timestamp.
#
sub GetActivity($)
{
    my ($self) = @_;
    my $stamp;

    # Must be a real reference. 
    return undef
	if (! ref($self));

    my $pid_idx = $self->pid_idx();
    my $query_result =
	DBQueryWarn("select UNIX_TIMESTAMP(last_activity) from project_stats ".
		    "where pid_idx='$pid_idx'");
    if ($query_result->numrows) {
	($stamp) = $query_result->fetchrow_array();
    }

    return $stamp;
}

sub SetActivity($$)
{
    my ($self,$stamp) = @_;
	
    # Must be a real reference. 
    return -1
	if (! ref($self));

    if ($stamp !~ /^\d+$/ || $stamp < 0 || $stamp > time()) {
	return -1;
    }

    my $pid_idx = $self->pid_idx();
    DBQueryWarn("update project_stats set last_activity=FROM_UNIXTIME($stamp)".
		" where pid_idx='$pid_idx'");

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

    my $pid_idx = $self->pid_idx();
    
    DBQueryWarn("update project_stats set last_activity=now() ".
		"where pid_idx='$pid_idx'");

    return 0;
}

#
# Check to see if a pid is valid.
#
sub ValidPID($$)
{
    my ($class, $pid) = @_;

    return TBcheck_dbslot($pid, "projects", "newpid",
			  TBDB_CHECKDBSLOT_WARN()|
			  TBDB_CHECKDBSLOT_ERROR());
}

#
# Add a user to the Project
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
    return $self->{'GROUP'}->AddMemberShip($user, $trust);    
}

#
# Add an NSF award
#
sub AddNSFAward($$$)
{
    my ($self, $award, $supplement) = @_;
    my $pid_idx = $self->pid_idx();
    my $pid     = $self->pid();

    DBQueryWarn("replace into project_nsf_awards set ".
		"  idx=null,pid='$pid',pid_idx='$pid_idx', ".
		"  award='$award',supplement='$supplement'")
	or return -1;

    return 0;
}

#
# Return group_exports info, as a plain hash.
#
sub PeerExports($$)
{
    my ($self, $pref) = @_;

    return $self->{'GROUP'}->PeerExports($pref);
}

#
# Do an exports setup if needed (ZFS). See exports_setup, when ZFS is on
# we do not export all projects, only recently active ones. 
#
sub UpdateExports($)
{
    my ($self) = @_;
    my $pid_idx = $self->pid_idx();

    return 0
	if (! ($WITHZFS && ($ZFS_NOEXPORT || !$WITHAMD)));
    my $exports_limit = GetSiteVar("general/export_active");
    return 0
	if (!$exports_limit);

    my $query_result =
	DBQueryWarn("select UNIX_TIMESTAMP(last_activity) from project_stats ".
		    "where pid_idx='$pid_idx'");
    # Hmm.
    return 0
	if (!$query_result->numrows);

    my ($lastactivity) = $query_result->fetchrow_array();

    # Update last_activity first so exports_setup will do something
    # and to mark the project as active, to keep the mount active.
    DBQueryWarn("update project_stats set last_activity=now() ".
		"where pid_idx='$pid_idx'")
	or return -1;

    if (!defined($lastactivity) ||
	time() - $lastactivity > ((($exports_limit * 24) - 12) * 3600)) {
	if ($ZFS_NOEXPORT) {
	    mysystem($EXPORTS_SETUP);
	}
	elsif (!$WITHAMD) {
	    mysystem($EXPORTS_SETUP . " -B");
	}

	# failed, reset the timestamp
	if ($?) {
	    my $set = (defined($lastactivity) ?
		       "FROM_UNIXTIME($lastactivity)" : "null");
	    
	    DBQueryWarn("update project_stats set last_activity=$set ".
			"where pid_idx='$pid_idx'");
	    return -1;
	}
    }
    return 0;
}

#
# Return usage records for experiments that have terminated (were running)
# between two dates.
#
sub Usage($$$)
{
    my ($self, $start, $end) = @_;
    my $pid_idx = $self->pid_idx();
    my @results = ();

    my $query_result =
	DBQueryWarn("(select e.eid,s.rsrcidx,s.nonlocal_id,s.slice_uuid, ".
		    "       s.nonlocal_user_id, ".
		    "       UNIX_TIMESTAMP(s.swapin_last),0,".
		    "       e.swapper_idx,n.type,r.node_id ".
		    " from experiments as e ".
		    "left join experiment_stats as s on ".
		    "     s.exptidx=e.idx  ".
		    "left join reserved as r on r.exptidx=e.idx ".
		    "left join nodes as n on n.node_id=r.node_id ".
		    "where e.pid_idx='$pid_idx' and e.state='active' ".
		    "      and UNIX_TIMESTAMP(s.swapin_last) < $end ".
		    "order by s.swapin_last desc) ".
		    "union ".
		    "(select s.eid,r.idx,s.nonlocal_id,s.slice_uuid, ".
		    "       s.nonlocal_user_id, ".
		    "       r.swapin_time,r.swapout_time, ".
		    "       h.uid_idx,n.type,h.node_id ".
		    "  from experiment_resources as r ".
		    "left join experiment_stats as s on ".
		    "     s.exptidx=r.exptidx  ".
		    "left join experiments as e on ".
		    "     e.idx=r.exptidx  ".
		    "left join node_history as h on ".
		    "     h.exptidx=r.exptidx and h.op='alloc' and ".
		    "     h.stamp >= r.swapin_time - 120 and ".
		    "     (r.swapout_time=0 or ".
		    "      h.stamp < r.swapout_time) ".
		    "left join nodes as n on n.node_id=h.node_id ".
		    "where s.pid_idx='$pid_idx' and ".
		    "     r.swapin_time!=0 and r.swapout_time!=0 and ".
		    "    ((r.swapin_time >= $start and ".
		    "      r.swapin_time <= $end) or ".
		    "     (r.swapout_time > $start and ".
		    "      r.swapout_time < $end)) ".
		    "order by r.swapin_time desc) "
	);

    return undef
	if (!defined($query_result));

    my @summary = ();
    my $lastin  = 0;

    while (my ($eid,$idx,$urn,$slice_uuid,$user_urn,
	       $swapin_time,$swapout_time,$swapper_idx,$type,$node_id) =
	   $query_result->fetchrow_array()) {
	# In the emulab-ops project, we nalloc nodes to experiments that
	# have never been swapped in (like hwdown).
	next
	    if (!defined($swapin_time));
	# No phys nodes.
	next
	    if (!defined($type) || !defined($node_id));

	my ($swapper_urn, $swapper_uid, $user);
	#
	# A slice created by a local user uses the real local user identity,
	# but for a nonlocal user we have to find nonlocal identity.
	#
	if (defined($slice_uuid)) {
	    require GeniHRN;
	    my $hrn = GeniHRN->new($user_urn);
	    if ($hrn->domain() eq $OURDOMAIN) {
		$user = User->Lookup($hrn->id());
	    }
	    else {
		$user = User->LookupNonLocal($user_urn);
	    }
	}
	else {
	    $user = User->Lookup($swapper_idx);
	}
	if (defined($user)) {
	    $swapper_urn = $user->nonlocalurn()->asString();
	    $swapper_uid = $user->uid();
	}
	
	# The order by clause is important.
	if ($swapin_time != $lastin) {
	    unshift(@summary, {"eid"    => $eid,
			       "urn"    => $urn || "",
			       "slice_uuid" => $slice_uuid || "",
			       "start"  => $swapin_time,
			       "end"    => $swapout_time || "",
			       "user_uid" => $swapper_uid,
			       "user_urn" => $swapper_urn,
			       "types"  => {$type => {"count"  => 1}},
			       "nodes"  => {$node_id => 1}});
	    $lastin = $swapin_time;
	    next;
	}
	my $blob = $summary[0];
	if (!exists($blob->{"types"}->{$type})) {
	    $blob->{"types"}->{$type} = {"count" => 0};
	}
	$blob->{"types"}->{$type}->{"count"} += 1;
	$blob->{"nodes"}->{$node_id} = 1;
    }
    return \@summary;
}

#
# Return count of how many nodes of a type in use.
#
sub TypeInUseCount($$)
{
    my ($self, $type) = @_;
    my $pid = $self->pid();

    my $result =
	DBQueryWarn("select count(n.type) from reserved as r ".
		    "left join nodes as n on n.node_id=r.node_id ".
		    "where pid='$pid' and type='$type' ".
		    "group by type");
    return 0
	if (!defined($result) || !$result->numrows);

    my ($count) = $result->fetchrow_array();
    return $count;
}

#
# Lookup all experiments and leases for a project.
#
sub Experiments($)
{
    my ($self) = @_;
    my $pid_idx = $self->pid_idx();
    my @result  = ();
    require Experiment;

    my $query_result =
	DBQueryWarn("select idx from experiments where pid='$pid_idx'");
    if (!$query_result) {
	return undef;
    }
    while (my ($idx) = $query_result->fetchrow_array()) {
	my $experiment = Experiment->Lookup($idx);
	if ($experiment) {
	    push(@result, $experiment);
	}
    }
    return \@result;
}

sub Leases($)
{
    my ($self) = @_;
    my $pid = $self->pid();
    my @result  = ();
    require Lease;

    my $query_result =
	DBQueryWarn("select lease_idx from project_leases where pid='$pid'");
    if (!$query_result) {
	return undef;
    }
    while (my ($lease_idx) = $query_result->fetchrow_array()) {
	my $lease = Lease->Lookup($lease_idx);
	if ($lease) {
	    push(@result, $lease);
	}
    }
    return \@result;
}

# _Always_ make sure that this 1 is at the end of the file...
1;
