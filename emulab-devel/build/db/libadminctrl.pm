#!/usr/bin/perl -w
#
# Copyright (c) 2000-2017 University of Utah and the Flux Group.
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
# Admission control policies. These are the ones I could think of, although
# not all of these are implemented.
#
#  * Number of experiments per type/class (only one expt using robots).
#
#  * Number of experiments per project
#  * Number of experiments per subgroup
#  * Number of experiments per user
#
#  * Number of nodes per project      (nodes really means pc testnodes)
#  * Number of nodes per subgroup
#  * Number of nodes per user
#
#  * Number of nodes of a class per project
#  * Number of nodes of a class per group
#  * Number of nodes of a class per user
#
#  * Number of nodes of a type per project
#  * Number of nodes of a type per group
#  * Number of nodes of a type per user
#
#  * Number of nodes with attribute(s) per project
#  * Number of nodes with attribute(s) per group
#  * Number of nodes with attribute(s) per user
#
# So we have group (pid/gid) policies and user policies. These are stored
# into two different tables, group_policies and user_policies, indexed in
# the obvious manner. Each row of the table defines a count (experiments,
# nodes, etc) and a type of thing being counted (experiments, nodes, types,
# classes, etc). When we test for admission, we look for each matching row
# and test each condition. All conditions must pass. No conditions means a
# pass. There is also some "auxdata" which holds extra information needed
# for the policy (say, the type of node being restricted). 
#
#      uid:     a uid
#   policy:     'experiments', 'nodes', 'type', 'class', 'attribute'
#    count:     a number
#  auxdata:     a string (optional)
#
# Example: A user policy of ('mike', 'nodes', 10) says that poor mike is
# not allowed to have more 10 nodes at a time, while ('mike', 'type',
# '10', 'pc850') says that mike cannot allocate more than 10 pc850s.
#
# The group_policies table:
#
#      pid:     a pid
#      gid:     a gid
#   policy:     'experiments', 'nodes', 'type', 'class', 'attribute'
#    count:     a number
#  auxdata:     a string (optional)
#
# Example: A project policy of ('testbed', 'testbed', 'experiments', 10)
# says that the testbed project may not have more then 10 experiments
# swapped in at a time, while ('testbed', 'TG1', 'nodes', 10) says that the
# TG1 subgroup of the testbed project may not use more than 10 nodes at time.
#
# In addition to group and user policies (which are policies that apply to
# specific users/projects/subgroups), we also need policies that apply to
# all users/projects/subgroups (ie: do not want to specify a particular
# restriction for every user!). To indicate such a policy, we use a special
# tag in the tables (for the user or pid/gid):
#
#      '+'  -  The policy applies to all users (or project/groups).
#
# Example: ('+','experiments',10) says that no user may have more then 10
# experiments swapped in at a time. The rule overrides anything more
# specific (say a particular user is restricted to 20 experiments; the above
# rule overrides that and the user (all users) is restricted to 10.
#
# Sometimes, you want one of these special rules to apply to everyone, but
# *allow* it to be overridden by a more specific rule. For that we use:
#
#      '-'  -  The policy applies to all users (or project/groups),
#              but can be overridden by a more specific rule.
#
# Example: The rules:
#
#	('-','type',0, 'garcia')
#       ('testbed', 'testbed', 'type', 10, 'garcia')
#
# says that no one is allowed to allocate garcias, unless there is specific
# rule that allows it; in this case the testbed project can allocate them.
#
# There are other global policies we would like to enforce. For example,
# "only one experiment can be using the robot testbed." Encoding this kind
# of policy is harder, and leads down a path that can get arbitrarily
# complex. Tha path leads to ruination, and so we want to avoid it at
# all costs.
#
# Instead we define a simple global policies table that applies to all
# experiments currently active on the testbed:
#
#   policy:     'nodes', 'type', 'class', 'attribute'
#     test:     'max', others I cannot think of right now ...
#    count:     a number
#  auxdata:     a string
#
# Example: A global policy of ('nodes', 'max', 10, '') say that the maximum
# number of nodes that may be allocated across the testbed is 10. Thats not
# a very realistic policy of course, but ('type', 'max', 1, 'garcia') says
# that a max of one garcia can be allocated across the testbed, which
# effectively means only one experiment will be able to use them at once.
# This is of course very weak, but I want to step back and give it some
# more thought before I redo this part. 
#
# Is that clear? Hope so, cause it gets more complicated. Some admission
# control tests can be done early in the swap phase, before we really do
# anything (before assign_wrapper). Others (type and class) tests cannot
# be done here; only assign can figure out how an experiment is going to map
# to physical nodes (remember virtual types too), and in that case we need
# to tell assign what the "constraints" are and let it figure out what is
# possible.
#
# So, in addition to the simple checks we can do, we also generate an array
# to return to assign_wrapper with the maximum counts of each node type and
# class that is limited by the policies. assign_wrapper will dump those
# values into the ptop file so that assign can enforce those maximum values
# regardless of what hardware is actually available to use. As per discussion
# with Rob, that will look like:
#
#	set-type-limit <type> <limit>
#
# and assign will spit out a new type of violation that assign_wrapper will
# parse. 
#
# NOTES:
#
#  * The system is not hierarchical; it is flat. That is, user rules do not
#    override group rules and group rules do not override project rules, etc.
#  * Admission control is skipped in admin mode; returns okay.
#  * Admission control is skipped when the pid is emulab-ops; returns okay.
#  * When calculating current usage, nodes reserved to emulab-ops are
#    ignored.
#  * The sitevar "swap/use_admission_control" controls the use of admission
#    control; defaults to 1 (on).
#  * The current policies can be viewed in the web interface. See
#    https://www.emulab.net/showpolicies.php3
#  * The global policy stuff is weak. I plan to step back and think about it
#    some more before redoing it, but it will tide us over for now.
#
#####
# Regarding the nodetypeXpid_permissions table ...
#
# My original thought when I started this was that I would be able to replace
# the existing nodetypeXpid_permissions table with this new stuff. Well, it
# turns out that this was not a good thing to do, for a couple of reasons:
#
#  * Engineering: We access the nodetypeXpid_permissions table from three
#    different languages, and no way I wanted to rewrite this library in
#    in python and php!
#
#  * Performance: We access the nodetypeXpid_permissions from the web
#    interface, on every single page load. In fact, we access it twice if
#    if you count the FreePCs() count that we put at the top of the menu.
#    Going through this library on each page load would be a serious drag.
#
# So, rather then actually get rid of the nodetypeXpid_permissions table, I
# decided to keep it as a "cache" of permissions stored in the group
# policies table. Each time you update the policy tables, we need to run
# the update_permissions script which will call into this library (see the
# TBUpdateNodeTypeXpidPermissions() routine) to reconstruct the permissions
# table. I have whacked the grantnodetype script to do exactly that.
#
# Note that we could proably do the same thing for users by creating an
# equivalent nodetypeXuid_permissions table, mapping users to types they
# are allowed to use. That would be a lot rows, but the amount of data in
# the table is small. That would give us very fine grained control of what
# we show people in the web interface. Not sure it is worth it though.
#
# Bottom line: Do not update the nodetypeXpid_permissions table by hand
# anymore! Update the group_policies table and then run the script to
# update the permissions table (sbin/update_permissions). 
#

package libadminctrl;
use strict;
use Exporter;
use vars qw(@ISA @EXPORT);
@ISA = "Exporter";
@EXPORT =
    qw ( TBAdmissionControlCheck TBUpdateNodeTypeXpidPermissions );

# Must come after package declaration!
use English;
use Data::Dumper;
use libdb;
use libtestbed;
use libtblog_simple;
use Experiment;
use User;
use Group;

# Configure variables
my $TB		= "/test";

# Locals
my $debug         = 0;
my $expt_min;
my $expt_max;
my $expt_cur      = 0;;
my %virt_types    = ();  # Indexed by virt type, gives number desired
my %virt_classes  = ();  # Indexed by virt class, gives number desired
my %node_types    = ();	 # Indexed by type, gives class
my %node_classes  = ();	 # Indexed by class, gives class
my $assignflag    = 0;
my %assign_classes= ();  # For assign (wrapper).
# Policy tables.
my %user_policies   = ();
my %group_policies  = ();
my %global_policies = ();

# Constants.
sub TBADMINCTRL_TYPE_USER()		{ "user"; }
sub TBADMINCTRL_TYPE_PROJECT()		{ "project"; }
sub TBADMINCTRL_TYPE_GROUP()		{ "group"; }

sub TBADMINCTRL_POLICY_EXPT()		{ "experiments"; }
sub TBADMINCTRL_POLICY_NODES()		{ "nodes"; }
sub TBADMINCTRL_POLICY_TYPE()		{ "type"; }
sub TBADMINCTRL_POLICY_CLASS()		{ "class"; }
sub TBADMINCTRL_POLICY_ATTR()		{ "attribute"; }
sub TBADMINCTRL_POLICY_MEMBERSHIP()	{ "membership"; }

my $MINUS_GIDIDX	= 0;
my $PLUS_GIDIDX		= 999999;

#
# The current usage data structure, filled in below.
#
my %curusage = ();

# Output useful info.
sub Declare($)
{
    my ($msg) = @_;
    
    tberror({cause => 'user'}, "Admission Control: $msg\n");
}

# Debug stuff
sub Debug($)
{
    my ($msg) = @_;
    
    if ($debug) {
	print "*** - $msg\n";
    }
}

# We can call this mulitple times from the mapper, need to make
# sure global state is clean.
sub InitVars()
{
    %assign_classes = ();
    
    %curusage = ("experiments"	=> {"user"    =>  0,
				    "project" =>  0,
				    "group"   =>  0},
		 "nodes"    	=> {"user"    =>  0,
				    "project" =>  0,
				    "group"   =>  0,
				    "expt"   =>   0},
		 # Arrays of user/project/group counts, indexed by
		 # type and class.
		 "class"	=> {},
		 "type"		=> {},
	);
}
InitVars();

# Update assign number.
sub UpdateForAssign($$$$)
{
    my ($policy, $typeclass, $maximum, $current) = @_;
    my $count;

    #
    # Check for current usage by the experiment (we are a swapmod).
    # They were allowed to swap in, but we do not want to yank them
    # just cause a policy changed, that would be unfriendly.
    #
    if (exists($curusage{$policy}->{$typeclass}) &&
	$curusage{$policy}->{$typeclass}->{'expt'}) {
	$count = max($maximum, $curusage{$policy}->{$typeclass}->{'expt'});
    }
    else {
	$count = $maximum - $current;
    }
    $count = 0
	if ($count < 0);

    $assign_classes{$typeclass} = 999999
	if (!defined($assign_classes{$typeclass}));
    
    # Max for assign is the global minus current number
    $assign_classes{$typeclass} = $count
	if ($count < $assign_classes{$typeclass});
}

#
# Test a user policy.
#
sub TestUserPolicy($$$$$)
{
    my ($uid, $policy, $count, $auxdata, $global) = @_;
    my $query_result;
    my $current = 0;
    my $gstring = ($global ? "global" : "user");

    if ($policy eq TBADMINCTRL_POLICY_EXPT()) {
	#
	# Simple check first.
	#
	if (!$count) {
	    Declare("$uid is not allowed to swap any experiments in!");
	    return 0;
	}
	$current = $curusage{"experiments"}->{'user'};

	Debug("$uid has $current active experiments; ".
	      "${gstring} limit is $count");
	
	if ($current >= $count) {
	    Declare("$uid has too many experiments swapped in!");
	    return 0;
	}
    }
    elsif ($policy eq TBADMINCTRL_POLICY_NODES()) {
	#
	# Simple check first.
	#
	if (!$count) {
	    Declare("$uid is not allowed to allocate any nodes!");
	    return 0;
	}
	$current = $curusage{"nodes"}->{'user'};
	
	Debug("$uid has $current nodes allocated; ".
	      "${gstring} limit is $count");
	
	if ($current + $expt_min > $count) {
	    Declare("$uid has too many nodes allocated! ".
		    "Needs $expt_min more.");
	    return 0;
	}
    }
    elsif ($policy eq TBADMINCTRL_POLICY_CLASS()) {
	$current = $curusage{"class"}->{$auxdata}->{'user'}
	    if (exists($curusage{"class"}->{$auxdata}));
	
	if ($assignflag) {
	    UpdateForAssign($policy, $auxdata, $count, $current);
	    return 1;
	}
	
	#
	# Check first to see if the experiment even wants this class.
	#
	return 1
	    if (! $virt_classes{$auxdata});

	#
	# If it does, then simple check first.
	# 
	if (!$count) {
	    Declare("$uid is not allowed to allocate any nodes of ".
		    "class $auxdata!");
	    return 0;
	}
	Debug("$uid has $current nodes of class $auxdata allocated; ".
	      "${gstring} limit is $count");
	
	if ($current + $virt_classes{$auxdata} > $count) {
	    Declare("$uid has too many nodes of class $auxdata allocated! ".
		    "Needs ". $virt_classes{$auxdata} ." more.");
	    return 0;
	}
    }
    elsif ($policy eq TBADMINCTRL_POLICY_TYPE()) {
	$current = $curusage{"type"}->{$auxdata}->{'user'}
	    if (exists($curusage{"type"}->{$auxdata}));

	if ($assignflag) {
	    UpdateForAssign($policy, $auxdata, $count, $current);
	    return 1;
	}
	
	#
	# Check first to see if the experiment even wants this class.
	#
	return 1
	    if (! $virt_types{$auxdata});

	#
	# If it does, then simple check first.
	# 
	if (!$count) {
	    Declare("$uid is not allowed to allocate any nodes of ".
		    "type $auxdata!");
	    return 0;
	}
	
	Debug("$uid has $current nodes of type $auxdata allocated; ".
	      "${gstring} limit is $count");
	
	if ($current + $virt_types{$auxdata} > $count) {
	    Declare("$uid has too many nodes of type $auxdata allocated! ".
		    "Needs ". $virt_types{$auxdata} ." more.");
	    return 0;
	}
    }
    else {
	warn("*** WARNING: Unknown user policy '$policy'!\n");
    }

    return 1;
}

#
# Test a group policy.
#
sub TestGroupPolicy($$$$$$)
{
    my ($pid, $gid, $policy, $count, $auxdata, $global) = @_;
    my $query_result;
    my $current = 0;
    my $gstring = ($global ? "global" : "group");

    if ($policy eq TBADMINCTRL_POLICY_EXPT()) {
	#
	# Simple check first.
	#
	if (!$count) {
	    Declare("$pid/$gid is not allowed to swap any experiments in!");
	    return 0;
	}
	$current = ($pid eq $gid ?
		    $curusage{"experiments"}->{'project'} :
		    $curusage{"experiments"}->{'group'});

	Debug("$pid/$gid has $current active experiments; ".
	      "${gstring} limit is $count");
	
	if ($current >= $count) {
	    Declare("$pid/$gid has too many experiments swapped in!");
	    return 0;
	}
    }
    elsif ($policy eq TBADMINCTRL_POLICY_NODES()) {
	#
	# Simple check first.
	#
	if (!$count) {
	    Declare("$pid/gid is not allowed to allocate any nodes!");
	    return 0;
	}
	$current = ($pid eq $gid ?
		    $curusage{"nodes"}->{'project'} :
		    $curusage{"nodes"}->{'group'});
	
	Debug("$pid/$gid has $current nodes allocated; ".
	      "${gstring} limit is $count");
	
	if ($current + $expt_min > $count) {
	    Declare("$pid/$gid has too many nodes allocated! ".
		    "Needs $expt_min more.");
	    return 0;
	}
    }
    elsif ($policy eq TBADMINCTRL_POLICY_CLASS()) {
	$current = ($pid eq $gid ?
		    $curusage{"class"}->{$auxdata}->{'project'} :
		    $curusage{"class"}->{$auxdata}->{'group'})
	    if (exists($curusage{"class"}->{$auxdata}));
	
	if ($assignflag) {
	    UpdateForAssign($policy, $auxdata, $count, $current);
	    return 1;
	}
	
	#
	# Check first to see if the experiment even wants this class.
	#
	return 1
	    if (! $virt_classes{$auxdata});

	#
	# If it does, then simple check first.
	# 
	if (!$count) {
	    Declare("$pid/$gid is not allowed to allocate any nodes of ".
		    "class $auxdata!");
	    return 0;
	}
	
	Debug("$pid/$gid has $current nodes of class $auxdata allocated; ".
	      "${gstring} limit is $count");
	
	if ($current + $virt_classes{$auxdata} > $count) {
	    Declare("$pid/$gid has too many nodes of class $auxdata ".
		    "allocated! Needs ". $virt_classes{$auxdata} ." more.");
	    return 0;
	}
    }
    elsif ($policy eq TBADMINCTRL_POLICY_TYPE()) {
	$current = ($pid eq $gid ?
		    $curusage{"type"}->{$auxdata}->{'project'} :
		    $curusage{"type"}->{$auxdata}->{'group'})
	    if (exists($curusage{"type"}->{$auxdata}));

	if ($assignflag) {
	    UpdateForAssign($policy, $auxdata, $count, $current);
	    return 1;
	}
	
	#
	# Check first to see if the experiment even wants this type
	#
	return 1
	    if (! $virt_types{$auxdata});

	#
	# If it does, then simple check first.
	# 
	if (!$count) {
	    Declare("$pid/$gid is not allowed to allocate any nodes of ".
		    "type $auxdata!");
	    return 0;
	}
	Debug("$pid/$gid has $current nodes of type $auxdata allocated; ".
	      "${gstring} limit is $count");
	
	if ($current + $virt_types{$auxdata} > $count) {
	    Declare("$pid/$gid has too many nodes of type $auxdata ".
		    "allocated! Needs ". $virt_types{$auxdata} ." more.");
	    return 0;
	}
    }
    else {
	warn("*** WARNING: Unknown group policy '$policy'!\n");
    }

    return 1;
}

#
# Test a Global policy.
#
sub TestGlobalPolicy($$$$$)
{
    my ($policy, $test, $count, $auxdata, $uid) = @_;
    my $current = 0;

    if ($policy eq TBADMINCTRL_POLICY_MEMBERSHIP()) {
	#
	# HACK! $uid must be a member of the comma separated list of projects.
	#
	my @pidlist = split(",", $auxdata);

	my $query_result =
	    DBQueryWarn("select uid from group_membership ".
			"where uid='$uid' and trust!='none' and (".
			join(" or ", map("pid='$_'", @pidlist)) . ")");
	
	return -1
	    if (!$query_result);

	if (! $query_result->numrows) {
	    Declare("You are not a member of a project with permission to ".
		    "swapin experiments.");
	    return 0;
	}
    }
    elsif ($policy eq TBADMINCTRL_POLICY_EXPT()) {
	#
	# Simple check first.
	#
	if (!$count) {
	    Declare("No one is allowed to swap any experiments in!");
	    return 0;
	}

	#
	# Get number of current experiments.
	#
	my $query_result =
	    DBQueryWarn("select count(eid) from experiments ".
			"where (state='" . EXPTSTATE_ACTIVE() . "' or ".
			"       state='" . EXPTSTATE_ACTIVATING() . "') and ".
			"       pid!='" . TBOPSPID() . "'");

	return -1
	    if (!$query_result);
	
	$current = ($query_result->fetchrow_array())[0];

	Debug("There are $current active experiments; ".
	      "global limit is $count");
	
	if ($current >= $count) {
	    Declare("There are too many experiments swapped in!");
	    return 0;
	}
    }
    elsif ($policy eq TBADMINCTRL_POLICY_NODES()) {
	#
	# Simple check first.
	#
	if (!$count) {
	    Declare("No one is allowed to allocate any more nodes!");
	    return 0;
	}

	my $query_result =
	    DBQueryFatal("select count(r.node_id) from reserved as r ".
		     "left join nodes as n on n.node_id=r.node_id ".
		     "left join node_types as nt on nt.type=n.type ".
		     "where r.pid!='" . TBOPSPID() . "' and ".
		     "      n.role='testnode'");
	
	return -1
	    if (!$query_result);
	
	$current = ($query_result->fetchrow_array())[0];
	
	Debug("The testbed has $current nodes allocated; ".
	      "global limit is $count");
	
	if ($current + $expt_min > $count) {
	    Declare("The testbed has too many nodes allocated! ".
		    "Needs $expt_min more.");
	    return 0;
	}
    }
    elsif ($policy eq TBADMINCTRL_POLICY_CLASS()) {
	#
	# Get current count.
	#
	my $query_result =
	    DBQueryFatal("select count(r.node_id) from reserved as r ".
			 "left join nodes as n on n.node_id=r.node_id ".
			 "left join node_types as nt on nt.type=n.type ".
			 "where r.pid!='" . TBOPSPID() . "' and ".
			 "      nt.class='$auxdata' and ".
			 "      n.role='testnode'");
	
	return -1
	    if (!$query_result);
	$current = ($query_result->fetchrow_array())[0];

	Debug("The testbed has $current nodes of class $auxdata allocated; ".
	      "global limit is $count");
	
	if ($assignflag) {
	    UpdateForAssign($policy, $auxdata, $count, $current);
	    return 1;
	}
	
	#
	# Check to see if the experiment even wants this class.
	#
	return 1
	    if (! $virt_classes{$auxdata});

	#
	# If it does, then simple check first.
	# 
	if (!$count) {
	    Declare("No one is allowed to allocate any nodes of ".
		    "class $auxdata!");
	    return 0;
	}

	if ($current + $virt_classes{$auxdata} > $count) {
	    Declare("The testbed has too many nodes of class $auxdata ".
		    "allocated! Needs ". $virt_classes{$auxdata} ." more.");
	    return 0;
	}
    }
    elsif ($policy eq TBADMINCTRL_POLICY_TYPE()) {
	#
	# Get current count.
	#
	my $query_result =
	    DBQueryFatal("select count(r.node_id) from reserved as r ".
			 "left join nodes as n on n.node_id=r.node_id ".
			 "left join node_types as nt on nt.type=n.type ".
			 "where r.pid!='" . TBOPSPID() . "' and ".
			 "      nt.type='$auxdata' and ".
			 "      n.role='testnode'");
	
	return -1
	    if (!$query_result);
	$current = ($query_result->fetchrow_array())[0];

	Debug("The testbed has $current nodes of type $auxdata allocated; ".
	      "global limit is $count");
	
	if ($assignflag) {
	    UpdateForAssign($policy, $auxdata, $count, $current);
	    return 1;
	}
	
	#
	# Check first to see if the experiment even wants this class.
	#
	return 1
	    if (! $virt_types{$auxdata});

	#
	# If it does, then simple check first.
	# 
	if (!$count) {
	    Declare("No one is allowed to allocate any nodes of ".
		    "type $auxdata!");
	    return 0;
	}

	if ($current + $virt_types{$auxdata} > $count) {
	    Declare("The testbed has too many nodes of type $auxdata ".
		    "allocated! Needs ". $virt_types{$auxdata} ." more.");
	    return 0;
	}
    }
    else {
	warn("*** WARNING: Unknown global policy '$policy'!\n");
    }

    return 1;
}

#
# Load the policies.
#
sub LoadPolicies($$$)
{
    my ($uid, $pid, $gid) = @_;

    #
    # Get the global policies. 
    #
    my $query_result =
	DBQueryWarn("select * from global_policies");

    return -1
	if (!$query_result);

    while (my $rowref = $query_result->fetchrow_hashref()) {
	my $policy  = $rowref->{'policy'};
	my $auxdata = $rowref->{'auxdata'};
	my $count   = $rowref->{'count'};
	my $test    = $rowref->{'test'};

	if ($debug) {
	    print "Global Policy: $policy, $test, $count, $auxdata\n";
	}

	$global_policies{"$policy:$test:$auxdata"} = $rowref;
    }

    #
    # Get user policies that apply. Ordering by uid will put the global
    # policies last, which makes it easier in the loop below.
    #
    if (defined($uid)) {
	$query_result =
	    DBQueryWarn("select * from user_policies ".
			"where uid='$uid' or uid='+' or uid='-' ".
			"order by uid desc");
	return -1
	    if (!$query_result);

	while (my $rowref = $query_result->fetchrow_hashref()) {
	    my $puid    = $rowref->{'uid'};
	    my $policy  = $rowref->{'policy'};
	    my $auxdata = $rowref->{'auxdata'};
	    my $count   = $rowref->{'count'};

	    if ($debug) {
		print "User Policy: $puid, $policy, $count, $auxdata\n";
	    }

	    if ($puid eq "+") {
		$user_policies{"$policy:$auxdata"} = $rowref;
	    }
	    elsif ($puid eq "-") {
		# Allow existing user policy to override this.
		$user_policies{"$policy:$auxdata"} = $rowref
		    if (!exists($user_policies{"$policy:$auxdata"}));
	    }
	    else {
		$user_policies{"$policy:$auxdata"} = $rowref;
	    }
	}
    }
    my $gidclause = "pid=gid or gid='*'";
    if (defined($gid)) {
	$gidclause .= "or gid='$gid'";
    }
    $query_result =
	DBQueryWarn("select distinct * from group_policies ".
		    "where (pid='$pid' and ($gidclause)) or ".
		    "      pid='' or pid='-' ".
		    "order by pid,gid desc");
    return -1
	if (!$query_result);

    while (my $rowref = $query_result->fetchrow_hashref()) {
	my $ppid    = $rowref->{'pid'};
	my $policy  = $rowref->{'policy'};
	my $auxdata = $rowref->{'auxdata'};
	my $count   = $rowref->{'count'};

	if ($debug) {
	    print "Group Policy: $pid, ".
		(defined($gid) ? "$gid" : "") . ", $policy, $count, $auxdata\n";
	}
	
	if ($ppid eq "+") {
	    $group_policies{"$policy:$auxdata"} = $rowref;
	}
	elsif ($ppid eq "-") {
	    # Allow existing policy to override this.
	    $group_policies{"$policy:$auxdata"} = $rowref
		if (!exists($group_policies{"$policy:$auxdata"}));
	}
	else {
	    $group_policies{"$policy:$auxdata"} = $rowref;
	}
    }
    return 0;
}

#
# Test policies that apply.
#
sub TestPolicies($$$)
{
    my ($uid, $pid, $gid) = @_;
    my $failcount       = 0;

    LoadPolicies($uid, $pid, $gid);

    #
    # Now test the policies. Test them all so that we get feedback on
    # all policies that fail.
    #
    foreach my $key (keys(%global_policies)) {
	my $pref    = $global_policies{$key};
	my $test    = $pref->{'test'};
	my $policy  = $pref->{'policy'};
	my $count   = $pref->{'count'};
	my $auxdata = $pref->{'auxdata'};

	my $result = TestGlobalPolicy($policy, $test, $count, $auxdata, $uid);
	    
	$failcount++
	    if (!$result);
    }

    #
    # For node type permission checks, want to do project based checks
    # first so that user restrictions can override project based restrictions.
    # This is cause people can be in multiple projects and trying to get
    # permission checks in this case is totally bogus to begin with, but
    # we like to tell people how many nodes are available and they have
    # permission to use, across all projects they are members of, which is a
    # silly and meaningless number if you are in multiple projects.
    # 
    foreach my $key (keys(%group_policies)) {
	my $pref    = $group_policies{$key};
	my $ppid    = $pref->{'pid'};
	my $pgid    = $pref->{'gid'};
	my $policy  = $pref->{'policy'};
	my $count   = $pref->{'count'};
	my $auxdata = $pref->{'auxdata'};
	my $global  = ($ppid eq $pid ? 0 : 1);
	my $result;

	# If the group is a wildcard, then we want the project limit.
	if ($pgid eq "*") {
	    $gid = $pid;
	}
	$result = TestGroupPolicy($pid, $gid,
				  $policy, $count, $auxdata, $global);
	
	$failcount++
	    if (!$result);
    }
    
    foreach my $key (keys(%user_policies)) {
	my $pref    = $user_policies{$key};
	my $puid    = $pref->{'uid'};
	my $policy  = $pref->{'policy'};
	my $count   = $pref->{'count'};
	my $auxdata = $pref->{'auxdata'};
	my $global  = ($puid eq $uid ? 0 : 1);
	my $result;

	$result = TestUserPolicy($uid, $policy,
				 $count, $auxdata, $global);

	$failcount++
	    if (!$result);
    }
    return 0
	if ($failcount);
    return 1;
}

#
# For the reservation system, check to see if a node type has a maximum
# allowed allocation value in a given project or user.
#
sub MaximumAllowed($$)
{
    my ($project, $type) = @_;
    my $pid = $project->pid();

    return -1
	if (LoadPolicies(undef, $pid, undef));

    foreach my $key (keys(%group_policies)) {
	my $pref    = $group_policies{$key};
	my $ppid    = $pref->{'pid'};
	my $policy  = $pref->{'policy'};
	my $count   = $pref->{'count'};
	my $auxdata = $pref->{'auxdata'};

	next if
	    ($policy ne TBADMINCTRL_POLICY_TYPE());

	return $count
	    if ($ppid eq $pid && $auxdata eq $type);
    }
    return undef;
}

#
# Update nodetypeXpid_permissions table.
#
sub UpdateNodeTypeXpidPermissions()
{
    my %minus_policies  = ();
    my %plus_policies   = ();
    my %permissions     = ();

    my $defgroup = Group->Lookup(TBOPSPID(), TBOPSPID());
    if (!defined($defgroup)) {
	Declare("Could not get operations group\n");
	return -1;
    }

    #
    # For non-zero defaults, we have to explicitly grant permission
    # to everyone. It will get revoked below if there is a group
    # policy.
    #
    my $query_result =
	DBQueryWarn("select pid_idx from projects");
    return -1
	if (!$query_result);
    my @allprojects = ();
    while (my ($pid_idx) = $query_result->fetchrow_array()) {
	push(@allprojects, $pid_idx);
	$permissions{$pid_idx} = {};
    }

    #
    # Get global policies
    # 
    $query_result =
	DBQueryWarn("select * from group_policies ".
		    "where pid='+' or pid='-' ".
		    "order by pid,gid desc");
    return -1
	if (!$query_result);

    while (my $rowref = $query_result->fetchrow_hashref()) {
	my $ppid    = $rowref->{'pid'};
	my $pgid    = $rowref->{'gid'};
	my $policy  = $rowref->{'policy'};
	my $auxdata = $rowref->{'auxdata'};
	my $count   = $rowref->{'count'};

	next
	    if (! ($policy eq TBADMINCTRL_POLICY_TYPE()));

	if ($debug) {
	    print "Type Perm: $ppid, $pgid, $count, $auxdata\n";
	}
	
	if ($ppid eq "+") {
	    $plus_policies{$auxdata} = $count;
	}
	elsif ($ppid eq "-") {
	    $minus_policies{$auxdata} = $count;
	}

	#
	# Anything that has a default must be in the table for it to
	# work right. At some point, this table must go away, but for
	# now the use emulab-ops for the default cause emulab-ops always
	# has access to everything.
	#
	$permissions{$defgroup->gid_idx()}->{$auxdata} = $count;

	#
	# And if the number is positive, must insert an entry for
	# everyone, which might get removed below.
	#
	if ($count) {
	    foreach my $pid_idx (@allprojects) {
		$permissions{$pid_idx}->{$auxdata} = $count;
	    }
	}
    }

    #
    # Get all group specific policies. 
    #
    $query_result =
	DBQueryWarn("select * from group_policies ".
		    "where pid!='+' and pid!='-' ".
		    "order by pid,gid desc");
    return -1
	if (!$query_result);

    while (my $rowref = $query_result->fetchrow_hashref()) {
	my $pid_idx = $rowref->{'pid_idx'};
	my $gid_idx = $rowref->{'gid_idx'};
	my $ppid    = $rowref->{'pid'};
	my $pgid    = $rowref->{'gid'};
	my $policy  = $rowref->{'policy'};
	my $auxdata = $rowref->{'auxdata'};
	my $count   = $rowref->{'count'};

	next
	    if (! ($policy eq TBADMINCTRL_POLICY_TYPE()));

	if ($debug) {
	    print "Type Perm: $ppid ($pid_idx), $pgid ($gid_idx), ".
		"$count, $auxdata\n";
	}

	if ($pgid eq "*") {
	    $pgid    = $ppid;
	    $gid_idx = $pid_idx;
	}

	my $group = Group->Lookup($gid_idx);
	next
	    if (!defined($group) || !$group->IsProjectGroup());

	$permissions{"$gid_idx"} = {}
	    if (!exists($permissions{"$gid_idx"}));
	
	if ($count == 0 ||
	    (exists($plus_policies{$auxdata}) &&
	     plus_policies{$auxdata} == 0)) {

	    delete($permissions{"$gid_idx"}->{$auxdata})
		if (exists($permissions{"$gid_idx"}->{$auxdata}));
	    
	    next;
	}
	$permissions{"$gid_idx"}->{$auxdata} = 1;
    }
    if ($debug) {
	print Dumper(\%permissions);
	return -1;
    }

    #
    # Generate the nodetypeXpid_permissions table (pid, type). We want to
    # do this atomically though, so create a temporary table and load that.
    # Then do a rename to swap the tables around.
    #
    return -1
	if (! (DBQueryWarn("select get_lock('libadminctrl', 999999)") &&
	       DBQueryWarn("drop table if exists libadminctrl_backup") &&
	       DBQueryWarn("drop table if exists libadminctrl_table")));

    $query_result = DBQueryWarn("show CREATE TABLE nodetypeXpid_permissions");
    return -1
	if (!$query_result);

    my $create_def = ($query_result->fetchrow_array())[1];
    $create_def =~ s/nodetypeXpid_permissions/libadminctrl_table/ig;

    return -1
	if (!DBQueryWarn($create_def));
    
    foreach my $gid_idx (keys(%permissions)) {
	my @typelist = keys(%{ $permissions{$gid_idx} });
	my $group    = Group->Lookup($gid_idx);
	my $pid      = $group->pid();

	foreach my $type (@typelist) {
	    return -1
		if (! DBQueryWarn("insert into libadminctrl_table ".
				  " (pid_idx, pid, type)".
				  "  values ($gid_idx, '$pid', '$type')"));
	}
    }
    $query_result = 
	DBQueryWarn("rename table ".
		    "  nodetypeXpid_permissions TO libadminctrl_backup, ".
		    "  libadminctrl_table TO nodetypeXpid_permissions ");

    DBQueryWarn("drop table if exists libadminctrl_table");
    DBQueryWarn("drop table if exists libadminctrl_backup");
    DBQueryWarn("select release_lock('libadminctrl')");
    return -1
	if (!$query_result);
    
    return 1;
}

#
# This is the primary interface to this library. Given a uid/pid/gid/eid,
# test all of the policies against the current experiment count, and the
# current node count plus the minimum number of nodes needed by the
# experiment.
# 
sub TBAdmissionControlCheck($$$)
{
    my ($user, $experiment, $ptypearray) = @_;
    my $gid = $experiment->gid();
    InitVars();

    $assignflag = 1
	if (defined($ptypearray));

    $user = User->ThisUser()
	if (!defined($user));
    my $uid  = $user->uid();
    my $pid  = $experiment->pid();
    my $eid  = $experiment->eid();

    #
    # Check to see if admin control is even on.
    #
    return 1
	if (! TBGetSiteVar("swap/use_admission_control"));
    
    #
    # Admin people do not get checks (when in admin mode of course).
    #
    return 1
	if (TBAdmin($uid));

    #
    # Nothing in emulab-ops should get admission control either.
    #
    return 1
	if ($pid eq TBOPSPID());

    $debug = 1
	if (TBGetSiteVar("swap/admission_control_debug"));

    #
    # Now we need the number of nodes needed by the experiment.
    #
    return -1
	if (!TBExptMinMaxNodes($pid, $eid, \$expt_min, \$expt_max));

    # Watch for update, see how many nodes this experiment is using now.
    $expt_cur  = scalar($experiment->NodeList(1));
    $expt_cur  = 0 if (!defined($expt_cur));
    $expt_min -= $expt_cur;

    LoadNodeTypes();
    LoadVirtNodeTypes($pid, $eid);
    LoadCurrent($uid, $pid, $gid, $eid);

    my $rval = TestPolicies($uid, $pid, $gid);
    
    if ($debug && $assignflag) {
	print "Assign type/class max counts:\n";
	foreach my $typeclass (keys(%assign_classes)) {
	    my $count = $assign_classes{$typeclass};

	    printf("%10s: %d\n", $typeclass, $count);
	}
    }
    %$ptypearray = %assign_classes
	if ($assignflag);

    return $rval;
}

#
# This is the secondary interface; this just gets a type restriction table.
# For each project the user is a member of, list the node types the user is
# not allowed to use. No mention in this table implies the user is allowed
# to use the type. No mention in a list for a specific project means the
# user is allowed to use the node type in that project (but might be
# restricted in another project). So silly. Once we figure out the project
# restrictions, apply the user restrictions to the table. 
# 
sub TBUpdateNodeTypeXpidPermissions()
{
    $debug = 1
	if (TBGetSiteVar("swap/admission_control_debug"));

    return UpdateNodeTypeXpidPermissions();
}
   
#
# Load the real types.
# 
sub LoadNodeTypes()
{
    my $query_result =
	DBQueryWarn("select type,class from node_types");

    return -1
	if (!$query_result);

    while (my ($type, $class) = $query_result->fetchrow_array()) {
	$node_types{$type}    = $class;
	$node_classes{$class} = $class;
    }
}
sub nodetypeistype($)   { return exists($node_types{$_[0]}); }
sub nodetypeclass($)	{ return $node_types{$_[0]}; }
sub nodeclassisclass($) { return exists($node_classes{$_[0]}); }

#
# Load the types this experiment wants, from the virt_nodes table.
# Might be a virtual type, which screws everything up!
#
sub LoadVirtNodeTypes($$)
{
    my ($pid, $eid) = @_;
    
    my $query_result =
	DBQueryWarn("select type from virt_nodes as vn ".
		    "where vn.pid='$pid' and vn.eid='$eid'");

    return -1
	if (!$query_result);

    # XXX Delay nodes!
    if ($expt_min > $query_result->numrows) {
	$virt_classes{"pc"} = $expt_min - $query_result->numrows;
    }

    while (my ($type) = $query_result->fetchrow_array()) {
	if (nodeclassisclass($type)) {
	    $virt_classes{$type} = 0
		if (!exists($virt_classes{$type}));
	    $virt_classes{$type} += 1;
	}
	else {
	    # Type counts.
	    $virt_types{$type} = 0
		if (!exists($virt_types{$type}));
	    $virt_types{$type} += 1;

	    # Class counts
	    if (nodetypeistype($type)) {
		my $class = nodetypeclass($type);

		$virt_classes{$class} = 0
		    if (!exists($virt_classes{$class}));
		$virt_classes{$class} += 1;
	    }
	}
    }
    if ($debug) {
	print "Experiment Desires:\n";
	print "  Classes:\n";
	foreach my $class (keys(%virt_classes)) {
	    my $count = $virt_classes{$class};
	    
	    print "    $class $count\n";
	}
	print "  Types:\n";
	foreach my $type (keys(%virt_types)) {
	    my $count = $virt_types{$type};
	    
	    print "    $type $count\n";
	}
    }
}

#
# Load Current physical usage. 
#
sub LoadCurrent($$$$)
{
    my ($uid, $pid, $gid, $eid) = @_;

    #
    # Experiment counts,
    # 
    my $query_result =
	DBQueryWarn("select expt_swap_uid,pid,gid from experiments ".
		    "where (state='" . EXPTSTATE_ACTIVE() . "' or ".
		    "       state='" . EXPTSTATE_ACTIVATING() . "') and ".
		    "      (expt_swap_uid='$uid' or ".
		    "       pid='$pid' or gid='$gid')");

    return undef
	if (!$query_result);

    while (my ($c_uid,$c_pid,$c_gid) = $query_result->fetchrow_array()) {
	if ($c_uid eq $uid) {
	    $curusage{"experiments"}->{'user'} += 1;
	}
	if ($c_pid eq $pid) {
	    $curusage{"experiments"}->{'project'} += 1;
	}
	if ($c_gid eq $gid) {
	    $curusage{"experiments"}->{'group'} += 1;
	}
    }

    if ($debug) {
	printf("Experiment usage: user:%d, project:%d, group:%d\n",
	       $curusage{"experiments"}->{'user'},
	       $curusage{"experiments"}->{'project'},
	       $curusage{"experiments"}->{'group'});
    }

    #
    # Node stuff.
    #
    $query_result =
	DBQueryFatal("select e.expt_swap_uid,e.pid,e.gid,n.type,nt.class, ".
		     "  r.eid from reserved as r ".
		     "left join nodes as n on n.node_id=r.node_id ".
		     "left join node_types as nt on nt.type=n.type ".
		     "left join experiments as e on ".
		     "     e.pid=r.pid and e.eid=r.eid ".
		     "where (e.expt_swap_uid='$uid' or r.pid='$pid') and ".
		     "      r.pid!='" . TBOPSPID() . "' and ".
		     "      n.role='testnode'");
    return undef
	if (!$query_result);

    while (my ($c_uid,$c_pid,$c_gid,$c_type,$c_class,$r_eid) =
	   $query_result->fetchrow_array()) {
	if (!exists($curusage{"class"}->{$c_class})) {
	    $curusage{"class"}->{$c_class} = {"user"    =>  0,
					      "project" =>  0,
					      "group"   =>  0,
					      "expt"    =>  0};
	}
	if (!exists($curusage{"type"}->{$c_type})) {
	    $curusage{"type"}->{$c_type} = {"user"    =>  0,
					    "project" =>  0,
					    "group"   =>  0,
					    "expt"    =>  0};
	}
	if ($c_uid eq $uid) {
	    $curusage{"nodes"}->{'user'} += 1;
	    $curusage{"class"}->{$c_class}->{'user'} += 1;
	    $curusage{"type"}->{$c_type}->{'user'} += 1;
	}
	if ($c_pid eq $pid) {
	    $curusage{"nodes"}->{'project'} += 1;
	    $curusage{"class"}->{$c_class}->{'project'} += 1;
	    $curusage{"type"}->{$c_type}->{'project'} += 1;
	}
	if ($c_gid eq $gid) {
	    $curusage{"nodes"}->{'group'} += 1;
	    $curusage{"class"}->{$c_class}->{'group'} += 1;
	    $curusage{"type"}->{$c_type}->{'group'} += 1;
	}
	if ($r_eid eq $eid) {
	    $curusage{"nodes"}->{'expt'} += 1;
	    $curusage{"class"}->{$c_class}->{'expt'} += 1;
	    $curusage{"type"}->{$c_type}->{'expt'} += 1;
	}
    }
    if ($debug) {
	printf("Node usage: user:%d, project:%d, group:%d, expt:%d\n",
	       $curusage{"nodes"}->{'user'},
	       $curusage{"nodes"}->{'project'},
	       $curusage{"nodes"}->{'group'},
	       $curusage{"nodes"}->{'expt'});
	foreach my $class (keys(%{$curusage{"class"}})) {
	    printf("Node class usage: ".
		   "$class user:%d, project:%d, group:%d, expt:%d\n",
		   $curusage{"class"}->{$class}->{'user'},
		   $curusage{"class"}->{$class}->{'project'},
		   $curusage{"class"}->{$class}->{'group'},
		   $curusage{"class"}->{$class}->{'expt'});
	}
	foreach my $type (keys(%{$curusage{"type"}})) {
	    printf("Node type usage: ".
		   "$type user:%d, project:%d, group:%d, expt:%d\n",
		   $curusage{"type"}->{$type}->{'user'},
		   $curusage{"type"}->{$type}->{'project'},
		   $curusage{"type"}->{$type}->{'group'},
		   $curusage{"type"}->{$type}->{'expt'});
	}
    }
    
    return \%curusage;
}

# _Always_ make sure that this 1 is at the end of the file...

1;
