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
package Node;
use strict;
use Exporter;
use SelfLoader ();
use vars qw(@ISA @EXPORT $AUTOLOAD @EXPORT_OK);
@ISA = qw(Exporter SelfLoader);
@EXPORT = qw();

# Configure variables
use vars qw($TB $BOSSNODE $USERNODE $WWWHOST $WOL $OSSELECT $IPOD $ISUTAH
	    $CONTROL_NETMASK $TBOPS $JAILIPMASK $TBBASE $TBADB 
            $BROWSER_CONSOLE_PROXIED $BROWSER_CONSOLE_WEBSSH);

$TB	     = "/users/achauhan/Cloudlab/CloudLabonESI/emulab-devel-new/emulab-devel/build_aish";
$BOSSNODE    = "boss.cloudlab.umass.edu";
$USERNODE    = "ops.cloudlab.umass.edu";
$WWWHOST     = "www.cloudlab.umass.edu";
$TBOPS       = "testbed-ops\@ops.cloudlab.umass.edu";
$WOL         = "$TB/sbin/whol";
$OSSELECT    = "$TB/bin/os_select";
$IPOD	     = "$TB/sbin/ipod";
$TBADB       = "$TB/bin/tbadb";
# XXX stinky hack detection
$ISUTAH	     = 0;
# Need this for jail ip assignment.
$CONTROL_NETMASK = "255.255.255.0";
$JAILIPMASK  = "255.240.0.0";
$TBBASE      = "https://www.cloudlab.umass.edu";
# Need these for the console object.
$BROWSER_CONSOLE_PROXIED = 0;
$BROWSER_CONSOLE_WEBSSH  = 1;

use libdb;
use libtestbed;
use emutil;
use English;
use Socket;
use Data::Dumper;
use overload ('""' => 'Stringify');

use vars qw($NODEROLE_TESTNODE $MFS_INITIAL $STATE_INITIAL
	    %nodes @cleantables);

# Exported defs
$NODEROLE_TESTNODE	= 'testnode';

# Why, why, why?
@EXPORT = qw($NODEROLE_TESTNODE);

# Cache of instances to avoid regenerating them.
%nodes = ();
BEGIN { use emutil; emutil::AddCache(\%nodes); }

# Little helper and debug function.
sub mysystem($)
{
    my ($command) = @_;

    print STDERR "Running '$command'\n"
	if (0);
    return system($command);
}

# To avoid writing out all the methods.
AUTOLOAD {
#    print STDERR "$AUTOLOAD $_[0]\n";

    if (!ref($_[0])) {
	$SelfLoader::AUTOLOAD = $AUTOLOAD;
	return SelfLoader::AUTOLOAD(@_);
    }
    my $self  = $_[0];
    my $name  = $AUTOLOAD;
    $name =~ s/.*://;   # strip fully-qualified portion

    # A DB row proxy method call.
    if (exists($self->{'DBROW'}->{$name})) {
	return $self->{'DBROW'}->{$name};
    }

    # The method is possibly for a SelfLoader method after __DATA__
    # Or it is for a local storage slot.
    if ($name =~ /^_.*$/) {
	if (scalar(@_) == 2) {
	    return $self->{'HASH'}->{$name} = $_[1];
	}
	elsif (exists($self->{'HASH'}->{$name})) {
	    return $self->{'HASH'}->{$name};
	}
    }
    $SelfLoader::AUTOLOAD = $AUTOLOAD;
    my $ref = \&SelfLoader::AUTOLOAD;
    goto &$ref;
}

#
# The list of table we have to clear if anything goes wrong when
# creating a new node.
# 
@cleantables = ("nodes", "node_hostkeys", "node_status",
		"node_activity", "node_utilization",
		"node_auxtypes", "reserved", "widearea_nodeinfo");


#
# Lookup a (physical) node and create a class instance to return.
#
sub Lookup($$)
{
    my ($class, $token) = @_;
    my $nodeid;

    if ($token =~ /^\w{8}\-\w{4}\-\w{4}\-\w{4}\-\w{12}$/) {
	my $query_result =
	    DBQueryWarn("select node_id from nodes ".
			"where uuid='$token'");
	    return undef
		if (! $query_result || !$query_result->numrows);

	    ($nodeid) = $query_result->fetchrow_array();
    }
    elsif ($token =~ /^[-\w]+$/) {
	$nodeid = $token;
    }
    else {
	return undef;
    }

    # Look in cache first
    return $nodes{$nodeid}
        if (exists($nodes{$nodeid}));

    my $query_result =
	DBQueryWarn("select * from nodes as n ".
		    "where n.node_id='$nodeid'");

    return undef
	if (!$query_result || !$query_result->numrows);

    return LookupRow($class, $query_result->fetchrow_hashref());
}

#
# Lookup a (physical) node based on an existing row from the database.
# Useful for bulk lookups.
#
sub LookupRow($$)
{
    my ($class, $row) = @_;

    my $self            = {};
    $self->{"DBROW"}    = $row;
    $self->{"RSRV"}     = undef;
    $self->{"TYPEINFO"} = undef;
    $self->{"ATTRS"}    = undef;
    $self->{"FEATURES"} = undef;
    $self->{"IFACES"}   = undef;
    $self->{"WAROW"}    = undef;
    $self->{"HASH"}     = {};
    bless($self, $class);

    $nodes{$row->{'node_id'}} = $self;
    return $self;
}

#
# Force a reload of the data.
#
sub LookupSync($$)
{
    my ($class, $nodeid) = @_;

    # delete from cache
    delete($nodes{$nodeid});

    return Lookup($class, $nodeid);
}

# Break circular reference someplace to avoid exit errors.
sub DESTROY {
    my $self = shift;

    $self->{"DBROW"}    = undef;
    $self->{"RSRV"}     = undef;
    $self->{"TYPEINFO"} = undef;
    $self->{"ATTRS"}    = undef;
    $self->{"FEATURES"} = undef;
    $self->{"IFACES"}   = undef;
    $self->{"HASH"}     = undef;
    $self->{"WAROW"}    = undef;
}

#
# Stringify for output.
#
sub Stringify($)
{
    my ($self) = @_;
    
    my $nodeid = $self->node_id();

    return "[Node: $nodeid]";
}

# Local lookup for an Experiment, to avoid dragging in the module.
sub LocalExpLookup(@)
{
    require Experiment;

    return Experiment->Lookup(@_);
}

1;


#
# Create a fake object, as for the mapper (assign_wrapper) during debugging.
#
sub MakeFake($$$$)
{
    my ($class, $nodeid, $dbrow, $rsrvrow) = @_;

    my $self            = {};
    $self->{"DBROW"}    = $dbrow;
    $self->{"RSRV"}     = $rsrvrow;
    $self->{"TYPEINFO"} = undef;
    $self->{"ATTRS"}    = undef;
    $self->{"FEATURES"} = undef;
    $self->{"IFACES"}   = undef;
    $self->{"WAROW"}    = undef;
    $self->{"HASH"}     = {};
    bless($self, $class);

    # Add to cache.
    $nodes{$nodeid} = $self;
    return $self;
}

#
# Bulk lookup of nodes reserved to an experiment. More efficient.
#
sub BulkLookup($$$)
{
    my ($class, $experiment, $pref) = @_;
    my %nodelist = ();
    my $exptidx  = $experiment->idx();

    my $query_result =
	DBQueryWarn("select n.* from reserved as r ".
		    "left join nodes as n on n.node_id=r.node_id ".
		    "where r.exptidx=$exptidx");

    return -1
	if (!defined($query_result));

    while (my $row = $query_result->fetchrow_hashref()) {
	my $nodeid = $row->{'node_id'};
	my $node;

	if (exists($nodes{$nodeid})) {
	    $node = $nodes{$nodeid};
	    $node->{"DBROW"} = $row;
	}
	else {
	    $node               = {};
	    $node->{"DBROW"}    = $row;
	    bless($node, $class);

	    # Add to cache.
	    $nodes{$nodeid} = $node;
	}
	$node->{"RSRV"}     = undef;
	$node->{"TYPEINFO"} = undef;
	$node->{"ATTRS"}    = undef;
	$node->{"FEATURES"} = undef;
	$node->{"IFACES"}   = undef;
	$node->{"WAROW"}    = undef;
	$node->{"HASH"}     = {};
	
	$nodelist{$nodeid} = $node;
    }

    $query_result =
	DBQueryWarn("select r.* from reserved as r ".
		    "where r.exptidx=$exptidx");
    return -1
	if (!defined($query_result));
    
    while (my $row = $query_result->fetchrow_hashref()) {
	my $nodeid = $row->{'node_id'};
	my $node   = $nodelist{$nodeid};

	return -1
	    if (!defined($node));

	$node->{"RSRV"} = $row;
    }

    $query_result =
	DBQueryWarn("select a.* from reserved as r ".
		    "left join node_attributes as a on a.node_id=r.node_id ".
		    "where r.exptidx=$exptidx and a.node_id is not null");
    return -1
	if (!defined($query_result));
    
    while (my $row = $query_result->fetchrow_hashref()) {
	my $nodeid = $row->{'node_id'};
	my $key    = $row->{'attrkey'};
	my $node   = $nodelist{$nodeid};

	return -1
	    if (!defined($node));

	$node->{"ATTRS"}->{$key} = $row;
    }
	
    @$pref = values(%nodelist);
    return 0;
}

#
# Lookup all nodes of a type
#
sub LookupByType($$)
{
    my ($class, $type) = @_;
    my @result = ();

    my $query_result =
	DBQueryWarn("select node_id from nodes as n where n.type='$type'");
    return ()
	if (!$query_result);

    while (my ($node_id) = $query_result->fetchrow_array()) {
	my $node = Node->Lookup($node_id);
	if (!defined($node)) {
	    print STDERR "No such node $node_id\n";
	    next;
	}
	push(@result, $node);
    }
    return @result;
}

#
# Do we have regular nodes? Class method.
#
sub HaveExperimentNodes()
{
    my $query_result =
	DBQueryWarn("select count(node_id) from nodes as n ".
		    "left join node_types as t on t.type=n.type ".
		    "where t.class='pc'");
    return 0
	if (!$query_result);
    
    my ($count) = $query_result->fetchrow_array();
    return $count;
}

sub Create($$$$)
{
    my ($class, $node_id, $experiment, $argref) = @_;
    my ($control_iface,$virtnode_capacity,$adminmfs,$adminmfs_osid);
    my ($priority, $osid, $osid_vers, $opmode, $state);
    require OSImage;
    require NodeType;

    # Defaults. Leave these here to avoid startup costs of libdb.
    #
    # MFS to boot the nodes into initially
    my $MFS_INITIAL   = TB_OSID_FREEBSD_MFS();
    # Initial event system state to put the nodes into
    my $STATE_INITIAL = TBDB_NODESTATE_SHUTDOWN();

    my $type = $argref->{'type'};
    my $role = $argref->{'role'};
    my $uuid;

    if (exists($argref->{'uuid'})) {
	$uuid = $argref->{'uuid'};
    }
    else {
	$uuid = NewUUID();
	if (!defined($uuid)) {
	    print STDERR "Could not generate a UUID!\n";
	    return undef;
	}
    }
    $uuid = DBQuoteSpecial($uuid);

    my $typeinfo = NodeType->Lookup($type);
    return undef
	if (!defined($typeinfo));

    my $isremote = $typeinfo->isremotenode();
    $osid_vers   = 0;

    if ($role eq "testnode") {
	if ($typeinfo->virtnode_capacity(\$virtnode_capacity)) {
	    print STDERR "*** No virtnode_capacity for $type! Using zero.\n";
	    $virtnode_capacity = 0;
	}
	if ($isremote || $typeinfo->isfakenode() || $typeinfo->isblackbox()) {
	    $osid   = "NULL";
	    $opmode = "";

	    if (defined($typeinfo->default_osid())) {
		$osid = $typeinfo->default_osid();
		
		my $osimage = OSImage->Lookup($osid);
		if (!defined($osimage)) {
		    print STDERR
			"*** Could not find OSImage object for $osid!\n";
		    return undef;
		}
		$osid      = $osimage->osid();
		$osid_vers = $osimage->version();
		$opmode    = $osimage->op_mode();
	    }
	}
	else {
	    if ($typeinfo->adminmfs_osid(\$adminmfs_osid) == 0) {
		# Find object for the adminfs.
		if (defined($adminmfs_osid)) {
		    $adminmfs = OSImage->Lookup($adminmfs_osid);
		}
		else {
		    $adminmfs = OSImage->Lookup(TBOPSPID(), $MFS_INITIAL);
		}
		if (!defined($adminmfs)) {
		    print STDERR
			"*** Could not find OSImage object for adminmfs!\n";
		    return undef;
		}
		$osid      = $adminmfs->osid();
		$osid_vers = $adminmfs->version();
		$opmode    = $adminmfs->op_mode();
	    }
	    elsif ($typeinfo->isswitch()) {
		$osid   = "NULL";
		$opmode = "ALWAYSUP";
	    }
	    else {
		print STDERR "*** No adminmfs osid for $type!\n";
		return undef;
	    }
	}
    }
    else {
	$osid   = "NULL";
	$opmode = "";
    }
    if (exists($argref->{'initial_eventstate'})) {
	$state = $argref->{'initial_eventstate'};
    }
    else {
	$state  = $STATE_INITIAL;
    }

    #
    # Lock the tables to prevent concurrent creation
    #
    DBQueryWarn("lock tables nodes write, widearea_nodeinfo write, ".
		"node_hostkeys write, node_status write, ".
		"node_utilization write, ".
		"node_activity write, reserved write, node_auxtypes write")
	or return undef;

    #
    # Make up a priority (just used for sorting)
    #
    if ($node_id =~ /^(.*\D)(\d+)$/) {
	$priority = $2;
    }
    else {
	$priority = 1;
    }

    #
    # See if we have a record; if we do, we can stop now and get the
    # existing record.
    #
    my $query_result =
	DBQueryWarn("select node_id from nodes where node_id='$node_id'");
    if ($query_result->numrows) {
	DBQueryWarn("unlock tables");
	return Node->Lookup($node_id);
    }

    if (!DBQueryWarn("insert into nodes set ".
		     "  node_id='$node_id', type='$type', " .
		     "  phys_nodeid='$node_id', role='$role', ".
		     "  priority=$priority, " .
		     "  eventstate='$state', op_mode='$opmode', " .
		     "  def_boot_osid=$osid, def_boot_osid_vers='$osid_vers',".
		     "  inception=now(), uuid=$uuid, ".
		     "  state_timestamp=unix_timestamp(NOW()), " .
		     "  op_mode_timestamp=unix_timestamp(NOW())")) {
	DBQueryWarn("unlock tables");
	return undef;
    }
    if ($isremote) {
	my $hostname = $argref->{'hostname'};
	my $external = $argref->{'external_node_id'};
	my $IP       = $argref->{'IP'};

	# Hmm, wanodecreate already does this.
	my $wa_result =
	    DBQueryWarn("select node_id from widearea_nodeinfo ".
			"where node_id='$node_id'");
	goto bad
	    if (!$wa_result);
	
	if ($wa_result->numrows == 0 &&
	    !DBQueryWarn("replace into widearea_nodeinfo ".
			 " (node_id, contact_uid, contact_idx, hostname," .
			 "  external_node_id, IP) ".
			 " values ('$node_id', 'nobody', '0', ".
			 "         '$hostname', '$external', '$IP')")) {
	    DBQueryWarn("delete from nodes where node_id='$node_id'");
	    DBQueryWarn("unlock tables");
	    return undef;
	}
    }

    if ($role eq "testnode") {
	DBQueryWarn("insert into node_hostkeys (node_id) ".
		    "values ('$node_id')")
	    or goto bad;
	
	DBQueryWarn("insert into node_status ".
		    "(node_id, status, status_timestamp) ".
		    "values ('$node_id', 'down', now()) ")
	    or goto bad;
    
	DBQueryWarn("insert into node_activity ".
		    "(node_id) values ('$node_id')")
	    or goto bad;
	
	DBQueryWarn("insert into node_utilization ".
		    "(node_id) values ('$node_id')")
	    or goto bad;
    }

    if (defined($experiment)) {
	my $exptidx = $experiment->idx();
	my $pid     = $experiment->pid();
	my $eid     = $experiment->eid();

	# Reserve node to hold it from being messed with.
	print STDERR
	    "*** Reserving new node $node_id to $pid/$eid\n";

	DBQueryWarn("insert into reserved ".
		    "(node_id, exptidx, pid, eid, rsrv_time, vname) ".
		    "values ('$node_id', $exptidx, ".
		    "        '$pid', '$eid', now(), '$node_id')")
	    or goto bad;
    }

    #
    # Add vnode counts.
    #
    if ($role eq $Node::NODEROLE_TESTNODE && $virtnode_capacity) {
	my $vtype;
	
	if (exists($argref->{'vtype'})) {
	    $vtype = $argref->{'vtype'};
	}
	else  {
	    $vtype = $type;
	    if (!($vtype =~ s/pc/pcvm/)) {
		$vtype = "$vtype-vm";
	    }
	}
	
	DBQueryWarn("insert into node_auxtypes set node_id='$node_id', " .
		    "type='$vtype', count=$virtnode_capacity")
	    or goto bad;
    }
    DBQueryWarn("unlock tables");
    return Node->Lookup($node_id);
    
  bad:
    foreach my $table (@cleantables) {
	DBQueryWarn("delete from $table where node_id='$node_id'");
    }
    DBQueryWarn("unlock tables");
    return undef;
}

#
# Only use this for Create() errors.
#
sub Delete($)
{
    my ($self)  = @_;
    my $node_id = $self->node_id();

    foreach my $table (@cleantables) {
	DBQueryWarn("delete from $table where node_id='$node_id'");
    }
    return 0;
}

#
# Refresh a class instance by reloading from the DB.
#
sub Refresh($)
{
    my ($self) = @_;

    return -1
	if (! ref($self));

    my $nodeid = $self->node_id();

    my $query_result =
	DBQueryWarn("select * from nodes as n ".
		    "where n.node_id='$nodeid'");

    return -1
	if (!$query_result || !$query_result->numrows);

    $self->{"DBROW"}  = $query_result->fetchrow_hashref();
    # Force reload
    $self->{"RSRV"}     = undef;
    $self->{"TYPEINFO"} = undef;
    $self->{"ATTRS"}    = undef;
    $self->{"FEATURES"} = undef;
    $self->{"IFACES"}   = undef;
    $self->{"WAROW"}    = undef;
    return 0;
}

#
# Flush from our little cache, as for the expire daemon.
#
sub Flush($)
{
    my ($self) = @_;

    delete($nodes{$self->node_id()});
}
sub FlushAll($)
{
    my ($class) = @_;
    
    %nodes = ();
}

#
# Convenience access method for widearea info
#
sub WideAreaInfo($$)
{
    my ($self, $slot) = @_;
    my $node_id = $self->node_id();

    if (!defined($self->{'WAROW'})) {
	my $query_result =
	    DBQueryWarn("select * from widearea_nodeinfo ".
			"where node_id='$node_id'");

	if (!$query_result || !$query_result->numrows) {
	    print STDERR "*** $node_id is not a widearea node\n";
	    return undef;
	}
	$self->{'WAROW'} = $query_result->fetchrow_hashref();
    }
    if (!exists($self->{'WAROW'}->{$slot})) {
	print STDERR
	    "*** Nonexistent slot '$slot' request for widearea node $node_id\n";
	return undef;
    }
    return $self->{'WAROW'}->{$slot};
}

#
# Check permissions. Allow for either uid or a user ref until all code
# updated.
#
sub AccessCheck($$$)
{
    my ($self, $user, $access_type) = @_;

    print "Printed 711\n";
    # Must be a real reference. 
    return 0
	if (! ref($self));

    print "Printed $access_type\n";
    if ($access_type < TB_NODEACCESS_MIN ||
	$access_type > TB_NODEACCESS_MAX) {
	print STDERR "*** Invalid access type: $access_type!\n";
	return 0;
    }
    # Admins do whatever they want.
    return 1
	if ($user->IsAdmin());

    my $mintrust;

    if ($access_type == TB_NODEACCESS_READINFO) {
	$mintrust = PROJMEMBERTRUST_USER;
    }
    else {
	$mintrust = PROJMEMBERTRUST_LOCALROOT;
    }

    # Get the reservation for this node. Only admins can mess with free nodes.
    my $experiment = $self->Reservation();
    return 0
	if (!defined($experiment));

    my $group = $experiment->GetGroup();
    return 0
	if (!defined($group));
    my $project = $experiment->GetProject();
    return 0
	if (!defined($project));

    #
    # Either proper permission in the group, or group_root in the
    # project. This lets group_roots muck with other people's
    # nodes, including those in groups they do not belong to.
    #
    return TBMinTrust($group->Trust($user), $mintrust) ||
	TBMinTrust($project->Trust($user), PROJMEMBERTRUST_GROUPROOT);
}

#
# Lazily load the reservation info.
#
sub IsReserved($)
{
    my ($self) = @_;

    return 0
	if (! ref($self));

    if (! defined($self->{"RSRV"})) {
	my $nodeid = $self->node_id();
	
	my $query_result =
	    DBQueryWarn("select * from reserved " .
			"where node_id='$nodeid'");
	return 0
	    if (!$query_result);
	return 0
	    if (!$query_result->numrows);

	$self->{"RSRV"} = $query_result->fetchrow_hashref();
	return 1;
    }
    return 1;
}

#
# Set reserved member based on a database row. Useful for bulk lookups.
#
sub SetReservedRow($$)
{
    my ($self, $reserved) = @_;
    if ($reserved->{"node_id"} eq $self->node_id()) {
	$self->{"RSRV"} = $reserved;
    }
}

sub GetSubboss($$)
{
    my ($self, $service, $subboss_id) = @_;

    return 0
	if (! ref($self));

    my $ref;

    if (defined $self->{"SUBBOSSES"}) {
	my $ref = $self->{"SUBBOSSES"}->{$service};
    }

    if (!defined $ref) {
	my $nodeid = $self->node_id();

	my $query_result =
	    DBQueryWarn("select * from subbosses " .
			"where node_id='$nodeid' and " .
			"service = '$service'");

	return 0
	    if (!$query_result);
	return 0
	    if (!$query_result->numrows);

	if (!defined($self->{"SUBBOSSES"})) {
	    $self->{"SUBBOSSES"} = {};
	}

	$ref = $self->{"SUBBOSSES"}->{$service} =
	    $query_result->fetchrow_hashref();
    }

    $$subboss_id = $ref->{'subboss_id'};

    return 0;
}

#
# Flush the reserve info so it reloads.
#
sub FlushReserved($)
{
    my ($self) = @_;

    $self->{"RSRV"} = undef;
    return 0;
}

#
# Is node up.
#
sub IsUp($)
{
    my ($self) = @_;

    return 0
	if (! ref($self));

    return $self->eventstate() eq TBDB_NODESTATE_ISUP;
}

#
# Determine if a node can be allocated to a project.
#
sub NodeAllocCheck($$)
{
    my ($self, $pid) = @_;

    # Must be a real reference. 
    return 0
	if (! ref($self));

    my $node_id = $self->node_id();

    #
    # Hmm. The point of this join is to find rows in the permissions table
    # with the corresponding type of the node. If no rows come back, its
    # a non-existent node! If the values are NULL, then there are no rows
    # with that type/class, and thus the type/class is free to be allocated
    # by anyone. Otherwise we get the list of projects that are allowed,
    # and so we have to look at those.
    # Note: nodetypeXpid_permissions has the pid_idx in addition to the pid -
    # presumably, the Right Thing would be to use that, but this function
    # is only passed the pid right now.
    #
    my $query_result =
	DBQueryFatal("select distinct p.type, p.pid_idx from nodes as n ".
		     "left join node_types as nt on n.type=nt.type ".
		     "left join nodetypeXpid_permissions as p on ".
		     "     (p.type=nt.type or p.type=nt.class) ".
		     "where node_id='$node_id'");

    if (!$query_result->numrows) {
	print STDERR "NodeAllocCheck: No such node $node_id!\n";
	return 0;
    }
    my ($ptype,$pid_idx) = $query_result->fetchrow_array();

    # No rows, or a pid match.
    if (!defined($ptype) || $pid_idx eq $pid->pid_idx()) {
	return 1;
    }

    # Okay, must be rows in the permissions table. Check each pid for a match.
    while (my ($ptype,$pid_idx) = $query_result->fetchrow_array()) {
	if ($pid_idx eq $pid->pid_idx()) {
	    return 1;
	}
    }
    return 0;
}

# Naming confusion.
sub AllocCheck($$)
{
    my ($self, $pid) = @_;

    return $self->NodeAllocCheck($pid);
}

#
# Set alloc state for a node.
#
sub SetAllocState($$)
{
    my ($self, $state) = @_;

    return -1
	if (! (ref($self)));
    
    my $now = time();
    my $node_id = $self->node_id();

    DBQueryWarn("update nodes set allocstate='$state', " .
		"    allocstate_timestamp=$now where node_id='$node_id'")
	or return -1;

    return Refresh($self);
}

#
# Get alloc state for a node.
#
sub GetAllocState($$)
{
    my ($self, $pref) = @_;

    return -1
	if (! (ref($self) && ref($pref)));
    
    my $allocstate = $self->allocstate();
    
    if (defined($allocstate)) {
	$$pref = $allocstate;
    }
    else {
	$$pref = TBDB_ALLOCSTATE_UNKNOWN;
    }
    return 0;
}

#
# We do this cause we always want to go to the DB.
#
sub GetEventState($;$$$)
{
    my ($self, $pstate, $popmode, $pstamp) = @_;
    my $node_id = $self->node_id();

    my $query_result =
	DBQueryWarn("select eventstate,op_mode,state_timestamp from nodes ".
		    "where node_id='$node_id'");
    return -1
	if (!$query_result || !$query_result->numrows);

    my ($state,$op_mode,$stamp) = $query_result->fetchrow_array();
    $state = TBDB_NODESTATE_UNKNOWN
	if (!defined($state));
    $op_mode = TBDB_NODEOPMODE_UNKNOWN
	if (!defined($op_mode));

    $self->{'DBROW'}->{'eventstate'} = $state
	if (defined($self->{'DBROW'}));
    $$pstate = $state
     	if (defined($pstate));
    $$popmode= $op_mode
 	if (defined($popmode));
    $$pstamp= $stamp
 	if (defined($pstamp));
    return 0;
}

#
# Equality test for two experiments.
# Not strictly necessary in perl, but good form.
#
sub SameExperiment($$)
{
    my ($self, $other) = @_;

    # Must be a real reference. 
    return -1
	if (! (ref($self) && ref($other)));

    return $self->idx() == $other->idx();
}

#
# Get the experiment this node is reserved too, or null.
#
sub Reservation($)
{
    my ($self) = @_;

    return undef
	if (! ref($self));

    return undef
	if (! $self->IsReserved());

    return LocalExpLookup($self->{"RSRV"}->{'exptidx'});
}

#
# Return just the ID of the reservation experiment. Avoids locking problems
# within nalloc and nfree. 
#
sub ReservationID($)
{
    my ($self) = @_;

    return undef
	if (! ref($self));

    return undef
	if (! $self->IsReserved());

    return $self->{"RSRV"}->{'exptidx'};
}

#
# Get the NEXT experiment this node is reserved too, or null.
#
sub NextReservation($)
{
    my ($self) = @_;

    return undef
	if (! ref($self));

    my $node_id = $self->node_id();
    
    my $query_result =
	DBQueryFatal("select pid,eid from next_reserve ".
		     "where node_id='$node_id'");

    return undef
	if (!$query_result || !$query_result->numrows);

    my ($pid,$eid) = $query_result->fetchrow_array();

    return LocalExpLookup($pid, $eid);
}

#
# Move a node from its experiment to another. Must treat oldreserved special.
#
sub MoveReservation($$)
{
    my ($self, $newexperiment) = @_;
    
    return -1
	if (! (ref($self) && ref($newexperiment)));

    my $node_id    = $self->node_id();
    my $newpid     = $newexperiment->pid();
    my $neweid     = $newexperiment->eid();
    my $newidx     = $newexperiment->idx();
    my $oldpid     = "";
    my $oldeid     = "";
    my $oldidx     = 0;
    
    # Must remember old reservation when moving to new oldreserved.
    if ($newpid eq OLDRESERVED_PID() && $neweid eq OLDRESERVED_EID()) {	
        #
	# Cannot do an experiment Lookup cause reserved table may be locked.
	# IsReserved() will load the reserved table entry only.
	#
	return -1
	    if (!$self->IsReserved());
	
	$oldpid     = $self->{"RSRV"}->{'pid'};
	$oldeid     = $self->{"RSRV"}->{'eid'};
	$oldidx     = $self->{"RSRV"}->{'exptidx'};
    }
    my $sets = "rsrv_time=now(), ".
	" vname='$node_id', ".
	" exptidx=$newidx, ".
	" pid='$newpid', ".
	" eid='$neweid', ".
	" old_exptidx=$oldidx, ".
	" old_pid='$oldpid', ".
	" old_eid='$oldeid' ";

    if ($self->IsReserved()) {
	DBQueryWarn("update reserved set $sets where node_id='$node_id'")
	    or return -1;
    }
    else {
	DBQueryWarn("insert into reserved set $sets, node_id='$node_id'")
	    or return -1;
    }

    # Force this to reload.
    $self->{"RSRV"} = undef;
    return 0;
}

#
# Change reservation table for a node.
#
sub ModifyReservation($$)
{
    my ($self, $argref) = @_;
    
    return -1
	if (! (ref($self) && ref($argref)));

    return -1
	if (! $self->IsReserved());
    
    my $node_id = $self->node_id();
    my @sets    = ();
    foreach my $key (keys(%{$argref})) {
	my $val = $argref->{$key};

	push(@sets, "$key=" . ("$val" eq "NULL" ? "NULL" : "'$val'"));
    }

    my $query = "update reserved set ".	join(",", @sets);
    $query .= " where node_id='$node_id'";

    return -1
	if (! DBQueryWarn($query));

    foreach my $key (keys(%{$argref})) {
	my $val = $argref->{$key};
	
	$self->{'DBROW'}->{$key} = $val;
    }
    return 0;
}

#
# Map nodeid to its pid/eid in the oldreserved holding reservation
#
sub OldReservation($)
{
    my ($self) = @_;

    return undef
	if (! ref($self));

    my $nodeid          = $self->node_id();
    my $oldreserved_pid = OLDRESERVED_PID;
    my $oldreserved_eid = OLDRESERVED_EID;
    
    my $query_result =
	DBQueryWarn("select old_pid,old_eid from reserved ".
		    "where node_id='$nodeid' and pid='$oldreserved_pid' ".
		    "and eid='$oldreserved_eid'");

    return undef
	if (! $query_result || !$query_result->num_rows);

    my ($pid,$eid) = $query_result->fetchrow_array();
    
    return LocalExpLookup($pid, $eid);
}

sub OldReservationID($)
{
    my ($self) = @_;

    return undef
	if (! ref($self));

    my $nodeid          = $self->node_id();
    my $oldreserved_pid = OLDRESERVED_PID;
    my $oldreserved_eid = OLDRESERVED_EID;
    
    my $query_result =
	DBQueryWarn("select old_exptidx from reserved ".
		    "where node_id='$nodeid' and pid='$oldreserved_pid' ".
		    "and eid='$oldreserved_eid'");

    return undef
	if (! $query_result || !$query_result->num_rows);

    my ($idx) = $query_result->fetchrow_array();
    
    return $idx;
}

#
# Return the tip server (and tipname) for a node.
#
sub TipServer($$;$$$)
{
    my ($self, $pserver, $ptipname, $pportnum, $pkeydata) = @_;

    return -1
	if (! ref($self));

    $$pserver  = undef;
    $$ptipname = undef
	if (defined($ptipname));

    my $nodeid = $self->node_id();
	
    my $query_result =
	DBQueryWarn("select server,tipname,portnum,keydata from tiplines " .
		    "where node_id='$nodeid'");
    return -1
	if (!$query_result);
    
    return 0
	if (!$query_result->numrows);

    my ($server,$tipname,$portnum,$keydata) = $query_result->fetchrow_array();
    $$pserver  = $server;
    $$ptipname = $tipname
	if (defined($ptipname));
    $$pkeydata = $keydata
	if (defined($pkeydata));
    $$pportnum = $portnum
	if (defined($pportnum));

    return 0;
}

#
# Get the raw reserved table info and return it, or null if no reservation
#
sub ReservedTableEntry($)
{
    my ($self) = @_;

    return undef
	if (! ref($self));

    return undef
	if (! $self->IsReserved());

    return $self->{"RSRV"};
}

#
# Return a list of virtual nodes on the given physical node.
#
sub VirtualNodes($$)
{
    my ($self, $plist) = @_;

    return -1
	if (! ref($self));

    @$plist         = ();

    my $reservation = $self->Reservation();
    return 0
	if (!defined($reservation));

    my $node_id     = $self->node_id();
    my $exptidx     = $reservation->idx();
    my @result      = ();

    my $query_result = 
	DBQueryWarn("select r.node_id from reserved as r ".
		    "left join nodes as n ".
		    "on r.node_id=n.node_id ".
		    "where n.phys_nodeid='$node_id' and ".
		    "      n.node_id!=n.phys_nodeid and exptidx='$exptidx'");

    return -1
	if (!$query_result);
    return 0
	if (!$query_result->numrows);

    while (my ($node_id) = $query_result->fetchrow_array()) {
	my $node = Node->Lookup($node_id);
	if (!defined($node)) {
	    print STDERR "*** VirtualNodes: no such virtual node $node_id!\n";
	    return -1;
	}
	push(@result, $node);
    }
    @$plist = @result;
    return 0;
}

#
# Does a node have any virtual nodes on it. Table might be locked.
#
sub HasVirtualNodes($)
{
    my ($self) = @_;

    return -1
	if (! ref($self));

    my $node_id = $self->node_id();

    my $query_result = 
	DBQueryWarn("select nodes.node_id from nodes ".
		    "left join reserved on reserved.node_id=nodes.node_id ".
		    "where nodes.phys_nodeid='$node_id' and ".
		    "      nodes.node_id!=nodes.phys_nodeid and ".
		    "      reserved.node_id is not null");
    return -1
	if (!$query_result);
    
    return $query_result->numrows;
}

#
# Access methods for the reservation.
#
sub L__reservation($$)
{
    my ($self, $slotname) = @_;

    return undef
	if (! ref($self));
    return undef
	if (! $self->IsReserved());
    return undef
	if (! exists($self->{"RSRV"}->{$slotname}));

    return $self->{"RSRV"}->{$slotname};
}
sub vname($)		{ return L__reservation($_[0], 'vname'); }
sub sharing_mode($)	{ return L__reservation($_[0], 'sharing_mode'); }
sub erole($)		{ return L__reservation($_[0], 'erole'); }
sub eid($)              { return L__reservation($_[0], 'eid'); }
sub pid($)              { return L__reservation($_[0], 'pid'); }
sub exptidx($)          { return L__reservation($_[0], 'exptidx'); }
sub genisliver_idx($)   { return L__reservation($_[0], 'genisliver_idx'); }
sub external_resource_index($) {
    return L__reservation($_[0], 'external_resource_index'); }
sub external_resource_id($) {
    return L__reservation($_[0], 'external_resource_id'); }
sub external_resource_key($) {
    return L__reservation($_[0], 'external_resource_key'); }
sub inner_elab_role($) {
    return L__reservation($_[0], 'inner_elab_role'); }
sub inner_elab_boot($) {
    return L__reservation($_[0], 'inner_elab_boot'); }
sub OnSharedNode($) {
    my ($self) = @_;
    my $sharing_mode = $self->sharing_mode();
    return 1
	if (defined($sharing_mode) && $sharing_mode eq "using_shared_local");
    return 0;
}

#
# This function takes the user-provided values for root key distribution
# from virt_nodes and adjusts them according to system restrictions, putting
# the result into the reserved table. The Get/Set accessor functions below
# use the values from reserved.
#
# If the user-provided value is -1 for any nodes/keys, then we use the given
# default value if provided or sitevar general/root_keypair (0 == don't
# distribute either key to any nodes, 1 == distribute both keys to all nodes)
# otherwise. However, if the default value is -1 then the mechanism is
# disabled entirely and we do not distribute any keys to anyone regardless
# of what the user says.
#
# The current "policy" restrictions are that we do *not* distribute a root
# pubkey to tainted nodes (as it opens a path to root on a node where no one
# should be root) or any keys to firewall nodes, virtnode hosts, delay nodes,
# subbosses, storagehosts, etc. which are not really part of the user
# topology. We also do not distribute to non "PC" nodes as they might not
# support ssh anyway.
#
sub InitKeyDist($;$$)
{
    my ($self,$experiment,$def) = @_;
    my ($priv,$pub);

    return -1
	if (!ref($self) || !$self->IsReserved());

    if (!$experiment) {
	$experiment = $self->Reservation();
	return -1
	    if (!$experiment);
    }
    
    # If no default is specified, use the system default
    if (!defined($def)) {
	if (!TBGetSiteVar("general/root_keypair", \$def)) {
	    $def = -1;
	}
    }

    # If the system default is "disabled", no key distribution
    if ($def == -1) {
	$priv = $pub = 0;
	goto done;
    }

    # XXX only PC class nodes for now, since we have to ssh to it
    if ($self->class() ne "pc" && $self->class() ne "pcvm") {
	$priv = $pub = 0;
	goto done;
    }

    # XXX blockstore vnodes are not real nodes
    if ($self->type() eq "blockstore") {
	$priv = $pub = 0;
	goto done;
    }
    
    # XXX beware the blackbox nodes
    if ($self->isblackbox()) {
	$priv = $pub = 0;
	goto done;
    }

    my $node_id = $self->node_id();

    # Get user-supplied values from virt_nodes
    my $result =
	DBQueryWarn("select v.rootkey_private,v.rootkey_public ".
		    " from virt_nodes as v, reserved as r ".
		    " where v.exptidx=r.exptidx and v.vname=r.vname ".
		    "  and r.node_id='$node_id'");

    if ($result && $result->numrows > 0) {
	($priv, $pub) = $result->fetchrow_array();
	my $fwnode;
	
	# start with default if user didn't specify
	$priv = $def if ($priv == -1);
	$pub = $def if ($pub == -1);

	# tainted node: no pub key
	if ($self->IsTainted()) {
	    $pub = 0;
	}

	# special hosts: no keys at all
	elsif ($self->erole() ne TBDB_RSRVROLE_NODE()) {
	    $priv = $pub = 0;
	}

	# firewall node for an experiment: no keys at all
	elsif ($experiment->IsFirewalled(\$fwnode) && $fwnode eq $node_id) {
	    $priv = $pub = 0;
	}
    }

  done:
    return $self->SetKeyDist($priv, $pub);
}

sub GetKeyDist($$$)
{
    my ($self,$privref,$pubref) = @_;
    
    return -1
	if (!ref($self));
    return -1
	if (! $self->IsReserved());

    if ($privref) {
	$$privref = ($self->{"RSRV"}->{'rootkey_private'} ? 1 : 0);
    }
    if ($pubref) {
	$$pubref = ($self->{"RSRV"}->{'rootkey_public'} ? 1 : 0);
    }

    return 0;
}

sub SetKeyDist($$$)
{
    my ($self,$privval,$pubval) = @_;
    
    return -1
	if (!ref($self));
    return -1
	if (! $self->IsReserved());

    my $clause = "";
    if (defined($privval)) {
	$privval = 1
	    if ($privval != 0);
	$clause = "rootkey_private=$privval";
    }
    if (defined($pubval)) {
	$pubval = 1
	    if ($pubval != 0);
	$clause .= ","
	    if ($clause);
	$clause .= "rootkey_public=$pubval";
    }
    if ($clause) {
	my $node_id = $self->node_id();
	DBQueryWarn("update reserved set $clause where node_id='$node_id'")
	    or return -1;
	$self->FlushReserved();
    }
    return 0;
}

#
# Load all attributes from the node_attributes table, 
#
sub LoadNodeAttributes($)
{
    my ($self) = @_;
    
    return -1
	if (!ref($self));

    my $node_id = $self->node_id();

    if (!defined($self->{"ATTRS"})) {
	my $query_result =
	    DBQueryWarn("select * from node_attributes ".
			"where node_id='$node_id'");

	return -1
	    if (!defined($query_result));

       	$self->{"ATTRS"} = {};
	while (my $row = $query_result->fetchrow_hashref()) {
	    my $key = $row->{'attrkey'};

	    $self->{"ATTRS"}->{$key} = $row;
	}
    }

    return 0;
}

# Iterate through rows adding node attributes. Each row is a hashref.
sub PreloadNodeAttributes($$)
{
    my ($self, $rows) = @_;
    $self->{"ATTRS"} = {};
    foreach my $row (@{ $rows }) {
	my $key = $row->{'attrkey'};
	$self->{"ATTRS"}->{$key} = $row;
    }
}

#
# Lookup a specific attribute in the node_attributes table, 
#
sub NodeAttribute($$$;$)
{
    my ($self, $attrkey, $pattrvalue, $pattrtype) = @_;
    
    return -1
	if (!ref($self));

    my $node_id = $self->node_id();

    if (!defined($self->{"ATTRS"})) {
	if ($self->LoadNodeAttributes()) {
	    return -1;
	}
    }
    
    if (!exists($self->{"ATTRS"}->{$attrkey})) {
	$$pattrvalue = undef;
	return 0;
    }
    my $ref = $self->{"ATTRS"}->{$attrkey};

    $$pattrvalue = $ref->{'attrvalue'};
    $$pattrtype  = $ref->{'attrtype'}
        if (defined($pattrtype));

    return 0;
}

#
# Return a hash of the node attributes for this node.
#
sub GetNodeAttributes($)
{
    my ($self) = @_;
    
    return undef
	if (!ref($self));

    my $node_id = $self->node_id();

    if (!defined($self->{"ATTRS"})) {
	if ($self->LoadNodeAttributes()) {
	    return undef;
	}
    }

    return $self->{"ATTRS"};
}

#
# Set an attribute for a node, overwriting the same attribute if it
# already exists.
#
sub SetNodeAttribute($$$;$) {
    my ($self, $attrkey, $attrval, $hidden) = @_;
    my $node_id = $self->node_id();
    $hidden  = (defined($hidden) && $hidden ? 1 : 0);

    return -1
	if (!$attrkey || !$attrval);

    $attrkey = DBQuoteSpecial($attrkey);
    $attrval = DBQuoteSpecial($attrval);

    return -1
	if (!DBQueryWarn("replace into node_attributes set".
			 "  node_id='$node_id',".
			 "  attrkey=$attrkey,".
			 "  attrvalue=$attrval,".
			 "  hidden='$hidden'"));

    if (!defined($self->{"ATTRS"})) {
	if ($self->LoadNodeAttributes()) {
	    return -1;
	}
    }
    $self->{"ATTRS"}->{$attrkey} = $attrval;

    return 0;
}
sub ClearNodeAttribute($$)
{
    my ($self, $attrkey) = @_;
    my $node_id = $self->node_id();

    return -1
	if (!$attrkey);

    my $safe_key = DBQuoteSpecial($attrkey);

    return -1
	if (!DBQueryWarn("delete from node_attributes ".
			 "where node_id='$node_id' and attrkey=$safe_key"));
	    
    if (defined($self->{"ATTRS"})) {
	delete($self->{"ATTRS"}->{$attrkey});
    }
    return 0;
}

#
# Return a hash of the node features for this node.
#
sub GetNodeFeatures($)
{
    my ($self) = @_;
    
    return undef
	if (!ref($self));

    my $node_id = $self->node_id();

    if (!defined($self->{"FEATURES"})) {
	my $query_result =
	    DBQueryWarn("select * from node_features ".
			"where node_id='$node_id'");

	return undef
	    if (!defined($query_result));

       	$self->{"FEATURES"} = {};
	while (my $row = $query_result->fetchrow_hashref()) {
	    my $feature = $row->{'feature'};
	    my $weight  = $row->{'weight'};

	    $self->{"FEATURES"}->{$feature} = $weight;
	}
    }
    return $self->{"FEATURES"};
}

#
# Set a feature for a node, overwriting the same feature if it
# already exists.
#
sub SetNodeFeature($$$) {
    my ($self, $feature, $weight) = @_;
    my $node_id = $self->node_id();

    return -1
	if (!defined($feature) || !defined($weight));

    return -1
	if ($weight !~ /^\d+(\.\d+)?$/);

    $feature = DBQuoteSpecial($feature);

    return -1
	if (!DBQueryWarn("replace into node_features set".
			 "  node_id='$node_id',".
			 "  feature=$feature,".
			 "  weight=$weight"));

    if (!defined($self->{"FEATURES"}) && !$self->GetNodeFeatures()) {
	return -1;
    }
    $self->{"FEATURES"}->{$feature} = $weight;

    return 0;
}

sub ClearNodeFeature($$)
{
    my ($self, $feature) = @_;
    my $node_id = $self->node_id();

    return -1
	if (!$feature);

    my $safe_feature = DBQuoteSpecial($feature);

    return -1
	if (!DBQueryWarn("delete from node_features ".
			 "where node_id='$node_id' and feature=$safe_feature"));
	    
    if (defined($self->{"FEATURES"})) {
	delete($self->{"FEATURES"}->{$feature});
    }
    return 0;
}

#
# Return type info. We cache this in the instance since node_type stuff
# does not change much.
#
sub NodeTypeInfo($)
{
    my ($self) = @_;
    require NodeType;
    
    return undef
	if (! ref($self));

    return $self->{"TYPEINFO"}
        if (defined($self->{"TYPEINFO"}));

    my $type = $self->type();
    my $nodetype = NodeType->Lookup($type);
    
    $self->{"TYPEINFO"} = $nodetype
	if (defined($nodetype));
    
    return $nodetype;
}

sub SetNodeTypeInfo($$)
{
    my ($self, $nodetype) = @_;
    if ($self->type() eq $nodetype->type()) {
	$self->{"TYPEINFO"} = $nodetype;
    }
}

#
# Lookup a specific attribute in the nodetype info. 
#
sub NodeTypeAttribute($$$;$)
{
    my ($self, $attrkey, $pattrvalue, $pattrtype) = @_;
    
    return -1
	if (!ref($self));

    my $typeinfo = $self->NodeTypeInfo();

    return -1
	if (!defined($typeinfo));

    return $typeinfo->GetAttribute($attrkey, $pattrvalue, $pattrtype);
}

#
# Returns a hash of node type attributes in the nodetype info. 
#
sub GetNodeTypeAttributes($)
{
    my ($self) = @_;
    
    return undef
	if (!ref($self));

    my $typeinfo = $self->NodeTypeInfo();

    return undef
	if (!defined($typeinfo));

    return $typeinfo->GetAttributes();
}

#
# Shortcuts to "common" type information.
# Later these might be overriden by node attributes.
#
sub class($)          { return NodeTypeInfo($_[0])->class(); }
sub isvirtnode($)     { return NodeTypeInfo($_[0])->isvirtnode(); }
sub isjailed($)       { return NodeTypeInfo($_[0])->isjailed(); }
sub isdynamic($)      { return NodeTypeInfo($_[0])->isdynamic(); }
sub isremotenode($)   { return NodeTypeInfo($_[0])->isremotenode(); }
sub issubnode($)      { return NodeTypeInfo($_[0])->issubnode(); }
sub isplabdslice($)   { return NodeTypeInfo($_[0])->isplabdslice(); }
sub isplabphysnode($) { return NodeTypeInfo($_[0])->isplabphysnode(); }
sub issimnode($)      { return NodeTypeInfo($_[0])->issimnode(); }
sub isgeninode($)     { return NodeTypeInfo($_[0])->isgeninode(); }
sub isfednode($)      { return NodeTypeInfo($_[0])->isfednode(); }
sub isdedicatedremote($) { return NodeTypeInfo($_[0])->isdedicatedremote(); }
sub isswitch($)       { return NodeTypeInfo($_[0])->isswitch(); }
sub isblackbox($)     { return NodeTypeInfo($_[0])->isblackbox(); }

#
# Later has arrived...
# Look for node_attributes settings first and if none, fall back on
# node_type_attributes info.
#
sub default_osid($;$) {
    my ($self,$stuff) = @_;
    my $val = undef;

    if (NodeAttribute($self, "default_osid", \$val) == 0 && defined($val)) {
	$$stuff = $val if (defined($stuff));
	return $val;
    }
    return NodeTypeInfo($self)->default_osid($stuff);
}

sub adminmfs_osid($;$) {
    my ($self,$stuff) = @_;
    my $val = undef;
    require OSImage;

    if (NodeAttribute($self, "adminmfs_osid", \$val) == 0 && defined($val)) {
	$$stuff = $val if (defined($stuff));
	return $val;
    }
    if (NodeTypeAttribute($self, "adminmfs_osid", \$val) == 0 &&
	defined($val)) {
	$$stuff = $val if (defined($stuff));
	return $val;
    }
    return OSImage->Lookup(TBOPSPID(), TB_OSID_FREEBSD_MFS())->osid();
}

sub recoverymfs_osid($;$) {
    my ($self,$stuff) = @_;
    my $val = undef;
    require OSImage;

    if (NodeAttribute($self, "recoverymfs_osid", \$val) == 0 &&
	defined($val)) {
	$$stuff = $val if (defined($stuff));
	return $val;
    }
    if (NodeTypeAttribute($self, "recoverymfs_osid", \$val) == 0 &&
	defined($val)) {
	$$stuff = $val if (defined($stuff));
	return $val;
    }
    return undef;
}

sub diskloadmfs_osid($;$) {
    my ($self,$stuff) = @_;
    my $val = undef;
    require OSImage;

    if (NodeAttribute($self, "diskloadmfs_osid", \$val) == 0 &&
	defined($val)) {
	$$stuff = $val if (defined($stuff));
	return $val;
    }
    if (NodeTypeAttribute($self, "diskloadmfs_osid", \$val) == 0 &&
	defined($val)) {
	$$stuff = $val if (defined($stuff));
	return $val;
    }
    return OSImage->Lookup(TBOPSPID(), TB_OSID_FRISBEE_MFS())->osid();
}

sub default_imageid($;$) {
    my ($self,$stuff) = @_;
    my $val = undef;

    if (NodeAttribute($self, "default_imageid", \$val) == 0 && defined($val)) {
	$$stuff = $val if (defined($stuff));
	return $val;
    }
    return NodeTypeInfo($self)->default_imageid($stuff);
}

sub default_pxeboot($) {
    my ($self) = @_;
    my $val = undef;

    if (NodeAttribute($self, "pxe_boot_path", \$val) == 0 && defined($val)) {
	return $val;
    }

    return NodeTypeAttribute($self, "pxe_boot_path", undef);
}

sub boot_method($) {
    my ($self) = @_;
    my $val = undef;

    if (NodeAttribute($self, "boot_method", \$val) == 0 && defined($val)) {
	return $val;
    }
    $val = NodeTypeAttribute($self, "boot_method", undef);

    # XXX need a mechanism for setting default values for attributes
    $val = "pxeboot"
	if (!$val);

    return $val;
}

sub disksize($;$) {
    my ($self,$stuff) = @_;
    my $val = undef;

    if (NodeAttribute($self, "disksize", \$val) == 0 && defined($val)) {
	$$stuff = $val if (defined($stuff));
	return $val;
    }
    return NodeTypeInfo($self)->disksize($stuff);
}

sub disktype($;$) {
    my ($self,$stuff) = @_;
    my $val = undef;

    if (NodeAttribute($self, "disktype", \$val) == 0 && defined($val)) {
	$$stuff = $val if (defined($stuff));
	return $val;
    }
    return NodeTypeInfo($self)->disktype($stuff);
}

sub bootdisk_unit($;$) {
    my ($self,$stuff) = @_;
    my $val = undef;

    if (NodeAttribute($self, "bootdisk_unit", \$val) == 0 && defined($val)) {
	$$stuff = $val if (defined($stuff));
	return $val;
    }
    return NodeTypeInfo($self)->bootdisk_unit($stuff);
}

sub cyclewhenoff($;$) {
    my ($self,$stuff) = @_;
    my $val = undef;

    if (NodeAttribute($self, "cyclewhenoff", \$val) == 0 && defined($val)) {
	$$stuff = $val if (defined($stuff));
	return $val;
    }
    return NodeTypeInfo($self)->cyclewhenoff($stuff);
}

sub brokenipmi($;$) {
    my ($self,$stuff) = @_;
    my $val = undef;

    if (NodeAttribute($self, "brokenipmi", \$val) == 0 && defined($val)) {
	$$stuff = $val if (defined($stuff));
	return $val;
    }
    return NodeTypeInfo($self)->brokenipmi($stuff);
}

sub rebootable($;$) {
    my ($self,$stuff) = @_;
    my $val = undef;

    if (NodeAttribute($self, "rebootable", \$val) == 0 && defined($val)) {
	$$stuff = $val if (defined($stuff));
	return $val;
    }
    return NodeTypeInfo($self)->rebootable($stuff);
}

sub delayreloadtillalloc($;$) {
    my ($self,$stuff) = @_;
    my $val = undef;

    if (NodeAttribute($self, "delayreloadtillalloc", \$val) == 0 &&
	defined($val)) {
	$$stuff = $val if (defined($stuff));
	return $val;
    }
    return NodeTypeInfo($self)->delayreloadtillalloc($stuff);
}

sub powercycleafterreload($;$) {
    my ($self,$stuff) = @_;
    my $val = undef;

    if (NodeAttribute($self, "powercycleafterreload", \$val) == 0 &&
	defined($val)) {
	$$stuff = $val if (defined($stuff));
	return $val;
    }
    return NodeTypeInfo($self)->powercycleafterreload($stuff);
}

sub requires_reservation($;$) {
    my ($self,$stuff) = @_;
    my $val = undef;

    if (NodeAttribute($self, "requires_reservation", \$val) == 0 &&
	defined($val)) {
	$$stuff = $val if (defined($stuff));
	return $val;
    }
    return $val;
}

sub root_password($) {
    my ($self) = @_;
    my $val = undef;

    NodeAttribute($self, "root_password", \$val);
    return $val;
}

#
# And these are the less common attributes, but still common enough to
# warrant shortcuts.
#
sub delay_osid($;$) {
    return NodeTypeInfo($_[0])->delay_osid($_[1]);
}
sub jail_osid($;$) {
    return NodeTypeInfo($_[0])->jail_osid($_[1]);
}
sub imageable($;$) {
    return NodeTypeInfo($_[0])->imageable($_[1]);
}
sub control_iface($;$) {
    return NodeTypeInfo($_[0])->control_iface($_[1]);
}
sub isfakenode($;$) {
    return NodeTypeInfo($_[0])->isfakenode($_[1]);
}
sub bios_waittime($;$) {
    return NodeTypeInfo($_[0])->bios_waittime($_[1]);
}
sub memory($;$) {
    return NodeTypeInfo($_[0])->memory($_[1]);
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

    my $nodeid = $self->node_id();
    my @sets   = ();

    foreach my $key (keys(%{$argref})) {
	my $val = $argref->{$key};

	# Treat NULL special.
	push (@sets, "${key}=" . ($val eq "NULL" ?
				  "NULL" : DBQuoteSpecial($val)));
    }

    my $query = "update nodes set " . join(",", @sets) .
	" where node_id='$nodeid'";

    return -1
	if (! DBQueryWarn($query));

    return Refresh($self);
}

#
# Insert a Log entry for a node.
#
sub InsertNodeLogEntry($$$$)
{
    my ($self, $user, $type, $message) = @_;

    # Must be a real reference. 
    return -1
	if (! ref($self));

    return -1
	if (! grep {$_ eq $type} TB_NODELOGTYPES());

    # XXX Eventually this should change, but it uses non-existent uids!
    my $dbid    = (defined($user) ? $user->uid_idx() : 0);
    my $dbuid   = (defined($user) ? $user->uid()     : "root");
    my $node_id = $self->node_id();
    $message    = DBQuoteSpecial($message);

    return -1
	if (! DBQueryWarn("insert into nodelog values ".
			  "('$node_id', NULL, '$type', '$dbuid', '$dbid', ".
			  " $message, now())"));
    return 0;
}

#
# Clear a bunch of stuff from the nodes tale entry so boot is clean.
#
sub ClearBootAttributes($)
{
    my ($self) = @_;
    my $node_id = (ref($self) ? $self->node_id() : $self);
    my $allocFreeState = TBDB_ALLOCSTATE_FREE_DIRTY();

    DBQueryWarn("update nodes set ".
		"startupcmd='',startstatus='none',rpms='',deltas='', ".
		"tarballs='',failureaction='fatal', routertype='none', ".
		"def_boot_cmd_line='',next_boot_cmd_line='', ".
		"temp_boot_osid=NULL,next_boot_osid=NULL, ".
		"temp_boot_osid_vers=0,next_boot_osid_vers=0, ".
		"update_accounts=0,ipport_next=ipport_low,rtabid=0, ".
		"sfshostid=NULL,allocstate='$allocFreeState',boot_errno=0, ".
		"destination_x=NULL,destination_y=NULL, ".
		"destination_orientation=NULL,reserved_memory=0,".
		"nonfsmounts=0,nfsmounts=NULL ".
		"where node_id='$node_id'")
	or return -1;

    my $node = (ref($self) ? $self : Node->Lookup($node_id));
    if ($node->boot_method() eq "pxelinux") {
	TBPxelinuxConfig($node);
    }

    return 0;
}

#
# Clear the experimental interfaces for a node.
#
sub ClearInterfaces($)
{
    my ($self) = @_;

    # Must be a real reference. 
    return -1
	if (! ref($self));

    my $node_id = $self->node_id();

    DBQueryWarn("update interfaces set IP='',IPaliases=NULL,mask=NULL,".
		"       rtabid='0',vnode_id=NULL,current_speed='0',trunk='0' ".
		"where node_id='$node_id' and ".
		"  role='" . TBDB_IFACEROLE_EXPERIMENT() . "'")
	or return -1;

    DBQueryWarn("update interface_state,interfaces set ".
		"       remaining_bandwidth=0 ".
		"where interface_state.node_id=interfaces.node_id and ".
		"      interface_state.iface=interfaces.iface and ".
		"      interfaces.node_id='$node_id' and ".
		"  role='" . TBDB_IFACEROLE_EXPERIMENT() . "'")
	or return -1;

    return 0;
}

#
# Clear the shared bandwidth being used by a (virtual) node.
#
sub ReleaseSharedBandwidth($)
{
    my ($self) = @_;

    # Must be a real reference. 
    return -1
	if (! ref($self));

    my $node_id  = $self->node_id();

    DBQueryWarn("lock tables vinterfaces write, interface_state write")
	or return -1;

    #
    # A negative BW is not reserved yet.
    #
    my $query_result =
	DBQueryWarn("select iface,unit from vinterfaces ".
		    "where vnode_id='$node_id' and ".
		    "      iface is not null and ".
		    "      bandwidth>0");	    
    if (!$query_result) {
	DBQueryWarn("unlock tables");
	return -1;
    }
    goto done
	if (!$query_result->numrows);

    #
    # For each vinterface indicating reserved bandwidth, atomically
    # update interface_state adding back the bandwidth, and decrementing
    # vinterface to indicate the bandwidth has been released.
    #
    while (my ($iface,$unit) = $query_result->fetchrow_array()) {
	if (!DBQueryWarn("update interface_state,vinterfaces set ".
		    "     remaining_bandwidth=remaining_bandwidth+bandwidth, ".
		    "     bandwidth=0-bandwidth ".
		    "where interface_state.node_id=vinterfaces.node_id and ".
		    "      interface_state.iface=vinterfaces.iface and ".
		    "      vinterfaces.vnode_id='$node_id' and ".
		    "      vinterfaces.iface='$iface' and ".
		    "      vinterfaces.unit='$unit'")) {
	    DBQueryWarn("unlock tables");
	    return -1;
	}
    }
  done:
    DBQueryWarn("unlock tables");
    return 0;
}

#
# Relase the reserved blockstore, which requires updating the
# remaining_capacity on the underyling store. At the present
# time, one blockstore is mapped to one pcvm. 
#
sub ReleaseBlockStore($)
{
    my ($self) = @_;

    require Blockstore;

    # Must be a real reference. 
    return -1
	if (! ref($self));

    my $node_id    = $self->node_id();
    my $blockstore = Blockstore::Reservation->LookupByNodeid($node_id);
    return 0
	if (!defined($blockstore));
    return -1
	if (!ref($blockstore));

    return $blockstore->Release();
}

#
# Look up all interfaces for a node, return list of objects.
#
sub AllInterfaces($$)
{
    my ($self, $pref) = @_;
    require Interface;

    # Must be a real reference. 
    return -1
	if (! (ref($self) && ref($pref)));

    return Interface->LookupAll($self->node_id(), $pref);
}

#
# Load the interfaces for a node, which we then access by name.
#
sub LoadInterfaces($)
{
    my ($self) = @_;
    require Interface;

    # Must be a real reference. 
    return -1
	if (! ref($self));

    if (!defined($self->{'IFACES'})) {
	my @interfaces;
	return -1
	    if (Interface->LookupAll($self->node_id(), \@interfaces) != 0);

	$self->{'IFACES'} = {};

	foreach my $interface (@interfaces) {
	    $self->{'IFACES'}->{$interface->iface()} = $interface;
	}
    }
    return 0;
}
sub GetInterface($$$)
{
    my ($self, $iface, $pref) = @_;
    my $interface;

    # Must be a real reference. 
    return -1
	if (! (ref($self) && ref($pref)));

    if (exists($self->{'IFACES'}->{$iface})) {
	# Might be undef if we already tried.
	$interface = $self->{'IFACES'}->{$iface};
    }
    else {
	$interface = Interface->LookupByIface($self, $iface);
	$self->{'IFACES'}->{$iface} = $interface;
    }
    $$pref = $interface;    
    return -1
	if (!defined($interface));
    return 0;
}

#
# Mark a node for an update.
#
sub MarkForUpdate($)
{
    my ($self) = @_;

    # Must be a real reference. 
    return -1
	if (! ref($self));

    my $node_id = $self->node_id();

    return -1
	if (! DBQueryWarn("update nodes set ".
			  "update_accounts=GREATEST(update_accounts,1) ".
			  "where node_id='$node_id'"));

    return Refresh($self);
}
sub CancelUpdate($)
{
    my ($self) = @_;

    # Must be a real reference. 
    return -1
	if (! ref($self));

    my $node_id = $self->node_id();

    return -1
	if (! DBQueryWarn("update nodes set update_accounts=0 ".
			  "where node_id='$node_id'"));

    return Refresh($self);
}
sub IsUpdated($)
{
    my ($self) = @_;

    # Must be a real reference. 
    return -1
	if (! ref($self));

    my $node_id = $self->node_id();
    my $query_result =
	DBQueryWarn("select update_accounts from nodes ".
		    "where node_id='$node_id'");
    return -1
	if (! $query_result);
    return 1
	if (!$query_result->numrows);
    my ($update_accounts) = $query_result->fetchrow_array();

    return ($update_accounts ? 0 : 1);
}
# Class method!
sub CheckUpdateStatus($$$@)
{
    my ($class, $pdone, $pnotdone, @nodelist) = @_;
    my @done = ();
    my @notdone = ();

    my $where = join(" or ",
		     map("node_id='" . $_->node_id() . "'", @nodelist));

    my $query_result =
	DBQueryWarn("select node_id,update_accounts from nodes ".
		    "where ($where)");

    return -1
	if (! $query_result);

    while (my ($node_id,$update_accounts) = $query_result->fetchrow_array) {
	my $node = Node->Lookup($node_id);
	if (! $update_accounts) {
	    Refresh($node);
	    push(@done, $node);
	}
	else {
	    push(@notdone, $node);
	}
    }
    
    @$pdone = @done;
    @$pnotdone = @notdone;
    return 0;
}

#
# Clear the bootlog.
#
sub ClearBootLog($)
{
    my ($self) = @_;

    # Must be a real reference. 
    return -1
	if (! ref($self));

    my $node_id = $self->node_id();

    return -1
	if (! DBQueryWarn("delete from node_bootlogs ".
			  "where node_id='$node_id'"));
    return 0;
}

#
# Get the bootlog.
#
sub GetBootLog($$)
{
    my ($self, $pref) = @_;

    # Must be a real reference. 
    return -1
	if (! ref($self));

    $$pref = undef;

    my $node_id = $self->node_id();

    my $query_result =
	DBQueryWarn("select bootlog from node_bootlogs ".
		    "where node_id='$node_id'");
    return -1
	if (! $query_result);

    if ($query_result->numrows) {
	my ($bootlog) = $query_result->fetchrow_array();
	$$pref = $bootlog;
    } else {
	$$pref = "";
    }
    return 0;
}

#
# Set event state for a node. Note that we do not change the DB here,
# but let stated do that. If stated dies ...
#
sub SetEventState($$;$)
{
    my ($self, $state, $fatal) = @_;
    my $rval;
    require event;

    # Must be a real reference. 
    return -1
	if (! ref($self));

    my $node_id = $self->node_id();

    if (!defined($fatal) || $fatal) {
	$rval = event::EventSendFatal(objtype   => TBDB_TBEVENT_NODESTATE,
				      objname   => $node_id,
				      eventtype => $state,
				      host      => $BOSSNODE);
    }
    else {
	$rval = event::EventSendWarn(objtype   => TBDB_TBEVENT_NODESTATE,
				     objname   => $node_id,
				     eventtype => $state,
				     host      => $BOSSNODE);
    }
    return ($rval == 1 ? 0 : -1);
}

sub ResetStartStatus($)
{
    my ($self) = @_;

    #
    # Do not do this on certain node types.
    #
    return 0
	if ($self->type() eq "blockstore");
    
    $self->{"DBROW"}->{'startstatus'} = 'none';
    return $self->Update({"startstatus" => 'none'});
}

#
# Return the node startupcmd and status fields.
#
sub GetStartupCmd($)
{
    my ($self) = @_;

    my $oldcmd = $self->startupcmd();
    my $oldstatus = $self->startstatus();

    return ($oldcmd, $oldstatus);
}

#
# Set the node startupcmd field to the given value or the value
# in the virt_nodes table entry if no value is given.
#
sub SetStartupCmd($$$)
{
    my ($self, $cmd, $status) = @_;
    $status = 'none' if (!defined($status));
    my $node_id = $self->node_id();

    if (!$cmd) {
	# Get value from virt_nodes
	my $result =
	    DBQueryWarn("select v.startupcmd ".
			" from virt_nodes as v, reserved as r ".
			" where v.exptidx=r.exptidx and v.vname=r.vname ".
			"  and r.node_id='$node_id'");
	if ($result && $result->numrows > 0) {
	    ($cmd) = $result->fetchrow_array();
	}
    }
    if ($cmd) {
	$self->Update({'startupcmd' => $cmd, 'startstatus' => $status});
    }
}

#
# Clear the node startupcmd and status fields.
# Returns the old command and status.
#
sub ClearStartupCmd($)
{
    my ($self) = @_;

    my $oldcmd = $self->startupcmd();
    my $oldstatus = $self->startstatus();

    $self->Update({'startupcmd' => '', 'startstatus' => 'none'});
    return ($oldcmd, $oldstatus);
}

#
# Create new vnodes. The argument is a reference; to a a hash of options to
# be used when creating the new node(s). A list of the node names is
# returned.
#
sub CreateVnodes($$$)
{
    my ($class, $rptr, $options) = @_;
    my @created   = ();
    my @ifaceargs = ();
    my @interfaces= ();
    my @tocreate  = ();
    my @vlist     = ();
    my $query_result;
    require Interface;
    require NodeType;
    
    if (!defined($options->{'pid'})) {
	print STDERR "*** CreateVnodes: Must supply a pid!\n";
	return -1;
    }
    if (!defined($options->{'eid'})) {
	print STDERR "*** CreateVnodes: Must supply a eid!\n";
	return -1;
    }
    if (!defined($options->{'count'})) {
	print STDERR "*** CreateVnodes: Must supply a count!\n";
	return -1;
    }
    if (!defined($options->{'vtype'})) {
	print STDERR "*** CreateVnodes: Must supply a vtype!\n";
	return -1;
    }
    if (!defined($options->{'nodeid'})) {
	print STDERR "*** CreateVnodes: Must supply a pnode!\n";
	return -1;
    }
    
    my $debug   = defined($options->{'debug'}) && $options->{'debug'};
    my $impotent= defined($options->{'impotent'}) && $options->{'impotent'};
    my $verbose = defined($options->{'verbose'}) && $options->{'verbose'};
    my $regression = defined($options->{'regression'}) &&
	$options->{'regression'};
    my $sharedokay = defined($options->{'sharedokay'}) &&
	$options->{'sharedokay'};
    my $user    = $options->{'user'} if (exists($options->{'user'}));
    my $pid     = $options->{'pid'};
    my $eid     = $options->{'eid'};
    my $count   = $options->{'count'};
    my $vtype   = $options->{'vtype'};
    my $pnode   = $options->{'nodeid'};
    # Caller can specify uuids, otherwise we make them up.
    my @uuids   = @$rptr;

    my $node = Node->Lookup($pnode);
    if (!defined($node)) {
	print STDERR "*** CreateVnodes: No such node $pnode!\n";
	return -1;
    }

    my $experiment = LocalExpLookup($pid, $eid);
    if (!defined($experiment)) {
	print STDERR "*** CreateVnodes: No such experiment $pid/$eid!\n";
	return -1;
    }
    my $exptidx = $experiment->idx();

    #
    # Need the vtype node_type info. 
    #
    my $nodetype = NodeType->Lookup($vtype);
    if (! defined($nodetype)) {
	print STDERR "*** CreateVnodes: No such node type '$vtype'\n";
	return -1;
    }
    if (!$nodetype->isdynamic()) {
	print STDERR "*** CreateVnodes: Not a dynamic node type: '$vtype'\n";
	return -1;
    }
    my $isremote  = $nodetype->isremotenode();
    my $isjailed  = $nodetype->isjailed();
    my $isfednode = $nodetype->isfednode();

    #
    # Make up a priority (just used for sorting). We need the name prefix
    # as well for consing up the node name.
    #
    my $nodeprefix;
    my $nodenum;
    my $ipbase;

    if ($isfednode) {
	$nodeprefix = $nodetype->type();
	$nodenum    = "";
	$ipbase     = 0;
    }
    elsif ($pnode =~ /^(.*)-r(\d+)-(\d+)$/) {
	# Cloudlab Wisconsin naming.
	$nodeprefix = $1;
	$nodenum    = "$2$3";
	$ipbase     = $nodenum;
    }
    elsif ($pnode =~ /^(.*\D)(\d{1,3})$/) {
	$nodeprefix = $1;
	$nodenum    = $2;
	$ipbase     = $nodenum;
    }
    else {
	$nodeprefix = $pnode;
	$nodenum    = "";
	$ipbase     = 0;

	if ($isjailed) {
	    #
	    # Determine ipbase from the control IP (jailed nodes).
	    #
	    my $interface = Interface->LookupControl($node);
	    if (!defined($interface)) {
		print STDERR
		    "*** CreateVnodes: No control interface for $node\n";
		return -1;
	    }
	    my $ctrlip = $interface->IP();
	    if (!defined($ctrlip) || $ctrlip eq "") {
		print STDERR
		    "*** CreateVnodes: No control IP for $interface\n";
		return -1;
	    }
	    my $tmp = ~inet_aton($CONTROL_NETMASK) & inet_aton($ctrlip);
	    $ipbase = unpack("N", $tmp);
	    if ($ipbase == 0 || $ipbase < 0 || $ipbase > 0x3fff) {
		print STDERR
		    "*** CreateVnodes: Bad ipbase '$ipbase' for $interface\n";
		return -1;
	    }
	}
    }

    #
    # Need the opmode, which comes from the OSID, which is in the node_types
    # table. 
    #
    my $osid = $nodetype->default_osid();
    my $osimage = OSImage->Lookup($osid);
    if (!defined($osimage)) {
	print STDERR "*** CreateVnodes: No such OSID '$osid'\n";
	return -1;
    }
    my ($opmode)  = $osimage->op_mode();
    my $osid_vers = $osimage->version();

    #
    # Need IP for jailed nodes.
    # 
    my $IPBASE = TBDB_JAILIPBASE();
    my $IPBASE1;
    my $IPBASE2;
    if ($IPBASE =~ /^(\d+).(\d+).(\d+).(\d+)/) {
	$IPBASE1 = $1;
	$IPBASE2 = $2;
    }
    else {
	print STDERR "*** CreateVnodes: Bad IPBASE '$IPBASE'\n";
	return -1;
    }

    # Need this below.
    my $total_memory    = $node->memory();
    my $node_attributes = $node->GetNodeAttributes();
    if (defined($node_attributes) &&
	exists($node_attributes->{"physical_ram"})) {
	$total_memory = $node_attributes->{"physical_ram"};
    }

    #
    # Assign however many we are told to (typically by assign). Locally
    # this is not a problem since nodes are not shared; assign always
    # does the right thing and we do what it says. In the remote case,
    # nodes are shared and so it is harder to make sure that nodes are not
    # over committed. I am not going to worry about this right now though
    # cause it would be too hard. For RON nodes this is fine; we just
    # tell people to log in and use them. For plab nodes, this is more
    # of a problem, but I am going to ignore that for now too since we do
    # not ever allocate enough to worry; must revisit this at some point.
    # 
    # Look to see what nodes are already allocated on the node, and skip
    # those. Must do this with tables locked, of course.
    #
    DBQueryFatal("lock tables nodes write, reserved write, ".
		 "node_attributes write, node_idlestats write, ".
		 "iface_counters write, ".
		 "node_status write, node_hostkeys write, node_activity write,".
		 "virt_node_public_addr write, virt_node_attributes read");

    #
    # Reload the reservation status now that tables are locked and confirm
    # that the shared node is still reserved. See nfree, which checks shared
    # nodes after locking reserved table.
    #
    $node->FlushReserved();
    my $sharing_mode = $node->sharing_mode();
    
    if (! ($impotent || $isfednode)) {
	if (!$node->IsReserved()) {
	    print STDERR "*** CreateVnodes: no reservation for $node!\n";
	    DBQueryFatal("unlock tables");
	    return -1;
	}

	#
	# The only time that the reservation can be different then the
	# the experiment we are creating for, is if the sharedokay flag
	# is on and the pnode is in sharedmode. Locking in nfree and in
	# the pool daemon prevents the race. 
	#
	# Cause of locking above, we need to make the comparison directly
	# using the slot data in the node.
	#
	if (! ($experiment->pid() eq $node->pid() &&
	       $experiment->eid() eq $node->eid())) {
	    if (! ($sharedokay && $sharing_mode)) {
		print STDERR "*** CreateVnodes: $node is not shared!\n";
		DBQueryFatal("unlock tables");
		return -1;
	    }
	}
    }

    if (0 && !$isremote) {
	for (my $i = 1; $i <= $count; $i++) {
	    push(@tocreate, $i);
	}
    }
    else {
	my $n = 1;
	my $i = 0;

	while ($i < $count) {
	    my $vnodeid = $nodeprefix . "vm" . $nodenum . "-" . $n;
	    
	    $query_result =
		DBQueryWarn("select node_id from nodes ".
			     "where node_id='$vnodeid'");
	    goto bad
		if (!$query_result);

	    if (!$query_result->numrows) {
		push(@tocreate, [$n, $options->{'vlist'}->[$i]]);
		$i++;
	    }
	    $n++;
	}
    }

    # See below.
    my $eventstate = TBDB_NODESTATE_SHUTDOWN();
    $eventstate = TBDB_NODESTATE_ISUP()
	if ($opmode eq "ALWAYSUP");
    my $allocstate = TBDB_ALLOCSTATE_FREE_CLEAN();

    #
    # Check memory constraints before we create anything. 
    #
    my %reserved_memory = ();

    if (defined($total_memory)) {
	foreach my $ref (@tocreate) {
	    my ($n, $vname) = @{ $ref };
	    my $vm_memsize;

	    #
	    # Look to see if the container can actually get the memory it
	    # needs. This really only matters on a shared node. On a
	    # dedicated node, assign will never violate this, but on a
	    # shared node it could happen if two swapins are running
	    # at the same time. Like bandwidth.
	    #
	    $experiment->GetVirtNodeAttribute($vname,
					      "VM_MEMSIZE", \$vm_memsize)
		== 0 or goto bad;

	    if ($vm_memsize) {
		if ($verbose) {
		    print STDERR
			"$vname is reserving $vm_memsize MB on $node\n";
		}
		if ($total_memory < $vm_memsize) {
		    print STDERR "*** CreateVnodes: ".
			"no free memory for $vname on $pnode\n";
		    goto bad;
		}
		$total_memory -= $vm_memsize;
		# remember for below.
		$reserved_memory{$vname} = $vm_memsize;
	    }
	}
    }

    #
    # Create a bunch.
    #
    foreach my $ref (@tocreate) {
	my ($n, $vname) = @{ $ref };
	my $vpriority = 10000000 + ($ipbase * 1000) + $n;
	my $vnodeid   = $nodeprefix . "vm" . $nodenum . "-" . $n;
	my ( $jailip, $jailmask );

	if ($isjailed) {
	    my $routable_control_ip;

	    $experiment->GetVirtNodeAttribute($vname, "routable_control_ip",
					      \$routable_control_ip)
		== 0 or goto bad;

	    if ($routable_control_ip &&
		$routable_control_ip eq "true") {
		#
		# Grab a public IP address from the free pool, if there
		# is one.
		#
		$query_result =
		    DBQueryWarn( "SELECT IP, mask FROM virt_node_public_addr ".
				 "WHERE node_id IS NULL AND eid IS NULL" );

		if (!$query_result || !$query_result->numrows ) {
		    print STDERR "*** CreateVnodes: no free public address\n";
		    goto bad;
		}

		( $jailip, $jailmask ) = $query_result->fetchrow_array();

		DBQueryFatal( "UPDATE virt_node_public_addr SET " .
			      "node_id='$vnodeid' " .
			      "WHERE IP='$jailip'" )
		    if (!$impotent);
	    } else {
		#
		# Construct a vnode private IP.  The general form is:
		#	<IPBASE1>.<IPBASE2>.<pnode>.<vnode>
		# but if <pnode> is greater than 254 we have to increment
		# IPBASE2.
		#
		# XXX at Utah our second big cluster of nodes starts at
		# nodenum=201 and I would like our vnode IPs to align
		# at that boundary, so 254 becomes 200.
		#
		my $nodenumlimit = $ISUTAH ? 200 : 254;
		my $pnet = $IPBASE2;
		my $pnode2 = int($ipbase);
		while ($pnode2 > $nodenumlimit) {
		    $pnet++;
		    $pnode2 -= $nodenumlimit;
		}
		$jailip = "${IPBASE1}.${pnet}.${pnode2}.${n}";
		$jailmask = $JAILIPMASK;
	    }
	}

	# Need to keep the UUIDs consistent across regression mode.
	my $uuid;
	if ($regression) {
	    $uuid = "0000${n}-1111-2222-3333-44444444";
	}
	else {
	    $uuid = (@uuids ? shift(@uuids) : NewUUID());
	}
	if (!defined($uuid)) {
	    print STDERR "Could not generate a UUID!\n";
	    goto bad;
	}

	if ($verbose) {
	    print STDERR "Jail IP for $vnodeid is $jailip\n"
		if ($jailip);
	    
	    if ($impotent) {
		print STDERR
		    "Would allocate $vnodeid on $pnode ($vtype, $osid)\n";
	    }
	    else {
		print STDERR
		    "Allocating $vnodeid on $pnode ($vtype, $osid)\n";
	    }
	}
	my %nodesets = ("node_id" => $vnodeid,
			"uuid" => $uuid,
			"type" => $vtype,
			"phys_nodeid" => $pnode,
			"role" => "virtnode",
			"priority" => $vpriority,
		        "op_mode" => $opmode,
			"op_mode_timestamp" => time(),
			"eventstate" => $eventstate,
			"state_timestamp" => time(),
			"allocstate" => $allocstate,
			"def_boot_osid" => $osid,
			"def_boot_osid_vers" => $osid_vers,
			"update_accounts" => 1,
			"jailflag" => $isjailed);

	if (exists($reserved_memory{$vname})) {
	    $nodesets{"reserved_memory"} = $reserved_memory{$vname};
	}	    
	my $statement = "insert into nodes set inception=now(), ".
	    join(",", map("$_='" . $nodesets{$_} . "'", keys(%nodesets)));

	print STDERR "$statement\n"
	    if ($debug);

	if (!$impotent && !DBQueryWarn($statement)) {
	    print STDERR "*** CreateVnodes: Could not create nodes entry\n";
	    goto bad;
	}

	#
	# Also reserve the node.
	#
	my %rsrvsets = ("node_id" => $vnodeid,
			"exptidx" => $exptidx, 
			"pid"     => $pid, 
			"eid"     => $eid,
			"vname"   => $vnodeid,
			"old_pid" => "",
			"old_eid" => "");

	# This is temporary for prototyping the shared local node support.
	# Not sure how this will shake out yet.
	$rsrvsets{"sharing_mode"} = "using_shared_local"
	    if (defined($sharing_mode));
			
	$statement = "insert into reserved set ".
	    join(",", map("$_='" . $rsrvsets{$_} . "'", keys(%rsrvsets)));

	print STDERR "$statement\n"
	    if ($debug);

	if (!$impotent && !DBQueryWarn($statement)) {
	    print STDERR "*** CreateVnodes: Could not create reserved entry\n";
	    goto bad;
	}

	$statement =
	         "insert into node_status set ".
		 "       node_id='$vnodeid', " .
		 "       status='up', ".
		 "       status_timestamp=now()";

	print STDERR "$statement\n"
	    if ($debug);

	if (!$impotent && !DBQueryWarn($statement)) {
	    print STDERR "*** CreateVnodes: Could not create status entry\n";
	    goto bad;
	}

	$statement =
	         "insert into node_hostkeys set ".
		 "       node_id='$vnodeid'";

	print STDERR "$statement\n"
	    if ($debug);

	if (!$impotent && !DBQueryWarn($statement)) {
	    print STDERR "*** CreateVnodes: Could not create hostkeys entry\n";
	    goto bad;
	}

	$statement =
	         "insert into node_activity set ".
		 "       node_id='$vnodeid'";

	print STDERR "$statement\n"
	    if ($debug);

	if (!$impotent && !DBQueryWarn($statement)) {
	    print STDERR "*** CreateVnodes: Could not create activity entry\n";
	    goto bad;
	}

	Node->MakeFake($vnodeid, \%nodesets, \%rsrvsets)
	    if ($impotent);

	push(@created, $vnodeid);

	#
	# Save up interfaces we need to create after table unlock.
	#
	if ($isjailed && !$isremote) {
	    my $ifaceargs = {
		"node_id"   => $vnodeid,
		"iface"     => "eth0",
		"role"      => TBDB_IFACEROLE_CONTROL(),
		"MAC"       => "genfake",
		"IP"        => $jailip,
		"mask"      => $jailmask,
		"type"      => "generic",
		"logical"   => 1,
	    };
	    push(@ifaceargs, $ifaceargs);
	}
    }
    DBQueryFatal("unlock tables");

    #
    # Now create a control network interface for local jailed nodes.
    # Now that tables are unlocked. 
    #
    foreach my $ifaceargs (@ifaceargs) {
	my $vnodeid = $ifaceargs->{'node_id'};
	my $node    = Node->Lookup($vnodeid);
	if (!defined($node)) {
	    print STDERR
		"*** CreateVnodes: Could not lookup node object for $vnodeid\n";
	    goto bad;
	}
	my $interface = ($impotent ?
			 Interface->MakeFake($node, $ifaceargs) :
			 Interface->Create($node, $ifaceargs));
	if (!defined($interface)) {
	    print STDERR
		"*** CreateVnodes: Could not create interface for $vnodeid\n";
	    goto bad;
	}
	print STDERR Dumper($interface)
	    if ($debug);

	push(@interfaces, $interface);
    }
    #
    # Finally, add the history records.
    #
    if (!$impotent) {
	foreach my $vnodeid (@created) {
	    my $node = Node->Lookup($vnodeid);
	    if (!defined($node)) {
		print STDERR
		    "*** CreateVnodes: Could not lookup $vnodeid\n";
		next;
	    }
	    $node->SetNodeHistory(TB_NODEHISTORY_OP_CREATE(),
				   $user, $experiment);
	    #
	    # Always, generate a new root password so that tmcd can
	    # return it in the jail config call. Safer if all nodes have
	    # different root passwords.
	    #
	    $node->NewRootPasswd();
	}
    }
    @$rptr = @created;
    return 0;

  bad:
    if (!$impotent) {
	foreach my $interface (@interfaces) {
	    $interface->Delete();
	}
	foreach my $vnodeid (@created) {
	    DBQueryWarn("update virt_node_public_addr set ".
			"  node_id=NULL ".
			"where node_id='$vnodeid'");
	    DBQueryWarn("delete from reserved where node_id='$vnodeid'");
	    DBQueryWarn("delete from nodes where node_id='$vnodeid'");
	    DBQueryWarn("delete from node_hostkeys where node_id='$vnodeid'");
	    DBQueryWarn("delete from node_status where node_id='$vnodeid'");
	    DBQueryWarn("delete from node_activity where node_id='$vnodeid'");
	    DBQueryWarn("delete from node_idlestats where node_id='$vnodeid'");
	    DBQueryWarn("delete from iface_counters where node_id='$vnodeid'");
	    DBQueryWarn("delete from node_attributes where node_id='$vnodeid'");
	}
    }
    DBQueryFatal("unlock tables");
    return -1;
}

#
# Delete vnodes created in above step.
# 
sub DeleteVnodes(@)
{
    my (@vnodes) = @_;

    DBQueryWarn("lock tables nodes write, reserved write");
    foreach my $vnodeid (@vnodes) {
	DBQueryWarn("delete from reserved where node_id='$vnodeid'");
	DBQueryWarn("delete from nodes where node_id='$vnodeid'");
    }
    DBQueryFatal("unlock tables");
    
    foreach my $vnodeid (@vnodes) {
	my $interface = Interface->LookupControl($vnodeid);
	if (defined($interface)) {
	    $interface->Delete();
	}
	DBQueryWarn("update virt_node_public_addr set ".
		    "  node_id=NULL ".
		    "where node_id='$vnodeid'");
	
	DBQueryWarn("delete from node_bootlogs where node_id='$vnodeid'");
	DBQueryWarn("delete from node_hostkeys where node_id='$vnodeid'");
	DBQueryWarn("delete from node_status where node_id='$vnodeid'");
	DBQueryWarn("delete from node_rusage where node_id='$vnodeid'");
	DBQueryWarn("delete from node_attributes where node_id='$vnodeid'");
	# Need to clean out some additional tables since some vnodes can be
	# reimaged now!
	DBQueryWarn("delete from current_reloads where node_id='$vnodeid'");
	DBQueryWarn("delete from `partitions` where node_id='$vnodeid'");
	# Slothd updates/creates these records.
	DBQueryWarn("delete from node_activity where node_id='$vnodeid'");
	DBQueryWarn("delete from node_idlestats where node_id='$vnodeid'");
	DBQueryWarn("delete from iface_counters where node_id='$vnodeid'");
	# We do this for XEN VMs.
	DBQueryWarn("delete from tiplines where node_id='$vnodeid'");
    }

    return 0;
}

sub SetNodeHistory($$$$)
{
    my ($self, $op, $user, $experiment) = @_;

    my $exptidx = $experiment->idx();
    my $nodeid  = $self->node_id();
    my $cnet_ip;
    my $cnet_mac;
    my $phys_nodeid;
    my $now     = time();
    my $uid;
    my $uid_idx;

    if (!defined($user)) {
	# Should this be elabman instead?
	$uid = "root";
	$uid_idx = 0;
    }
    else {
	$uid = $user->uid();
	$uid_idx = $user->uid_idx();
    }
    if ($op eq TB_NODEHISTORY_OP_MOVE() || $op eq TB_NODEHISTORY_OP_FREE()) {
	# Summary info. We need the last entry made.
	my $query_result =
	    DBQueryWarn("select exptidx,stamp from node_history ".
			"where node_id='$nodeid' ".
			"order by stamp desc limit 1");

	if ($query_result && $query_result->numrows) {
	    my ($lastexptidx,$stamp) = $query_result->fetchrow_array();
	    my $checkexp;

	    if ($op eq TB_NODEHISTORY_OP_FREE()) {
		$checkexp = $experiment;
	    }
	    else {
		$checkexp = LocalExpLookup($lastexptidx);
	    }
	    if (defined($checkexp)) {
		if ($checkexp->pid() eq NODEDEAD_PID() &&
		    $checkexp->eid() eq NODEDEAD_EID()) {
		    my $diff = $now - $stamp;

		    DBQueryWarn("update node_utilization set ".
				" down=down+$diff ".
				"where node_id='$nodeid'")
		    }
		else {
		    my $diff = $now - $stamp;

		    DBQueryWarn("update node_utilization set ".
				" allocated=allocated+$diff ".
				"where node_id='$nodeid'");
		}
	    }
	}
    }
    elsif ($op eq TB_NODEHISTORY_OP_CREATE()) {
	#
	# No need to waste space on cnet_IP for phys nodes, or on
	# the destroy op. Ditto the phys_nodeid. 
	#
	require Interface;

	# Lets make sure no one calls this for a real node.
	if (! $self->isvirtnode()) {
	    print STDERR
		"*** SetNodeHistory: '$op' issued for phys node $self\n";
	    return -1;
	}
	
	my $interface = Interface->LookupControl($self);
	if (!defined($interface)) {
	    print STDERR
		"*** SetNodeHistory: No control interface for $self\n";
	}
	else {
	    $cnet_ip  = $interface->IP();
	    $cnet_mac = $interface->mac()
		if (defined($interface->mac()));
	    
	    if (!defined($cnet_ip) || $cnet_ip eq "") {
		print STDERR
		    "*** SetNodeHistory: No control IP for $interface\n";
		$cnet_ip  = undef;
	    }
	}
	$phys_nodeid = $self->phys_nodeid();
    }
    elsif ($op eq TB_NODEHISTORY_OP_DESTROY()) {
	# Lets make sure no one calls this for a real node.
	if (! $self->isvirtnode()) {
	    print STDERR
		"*** SetNodeHistory: '$op' issued for phys node $self\n";
	    return -1;
	}
    }

    return DBQueryWarn("insert into node_history set ".
	       "  history_id=0, node_id='$nodeid', op='$op', ".
	       "  uid='$uid', uid_idx='$uid_idx', ".
	       (defined($cnet_ip)  ? "cnet_IP='$cnet_ip'," : "").
	       (defined($cnet_mac) ? "cnet_mac='$cnet_mac'," : "").
	       (defined($phys_nodeid) ? "phys_nodeid='$phys_nodeid'," : "").
	       "  stamp=$now, exptidx=$exptidx");
}

#
# Set the scheduled_reloads for a node. Type is optional and defaults to
# testbed default load type. See above.
#
# No image version info; we always reload the most current image. 
#
sub SetSchedReload($$;$)
{
    my ($self, $imageid, $type) = @_;

    # Must be a real reference. 
    return -1
	if (! ref($self));

    my $node_id = $self->node_id();

    $type = TB_DEFAULT_RELOADTYPE
	if (!defined($type));

    return -1
	if (! DBQueryWarn("replace into scheduled_reloads ".
			  "(node_id, image_id, reload_type) values ".
			  "('$node_id', '$imageid', '$type')"));

    return 0;
}

sub GetSchedReload($)
{
    my ($self) = @_;

    my $node_id = $self->node_id();

    my $query_result =
	DBQueryWarn("select image_id,reload_type from scheduled_reloads " .
		    "where node_id='$node_id'");

    return ()
	if (! (defined($query_result) && $query_result->numrows));
    
    return $query_result->fetchrow_array();
}

sub ClearSchedReload($)
{
    my ($self) = @_;

    # Must be a real reference. 
    return -1
	if (! ref($self));

    my $node_id = $self->node_id();

    DBQueryWarn("delete from scheduled_reloads where node_id='$node_id'");

    return 0;
}

sub ClearCurrentReload($)
{
    my ($self) = @_;

    # Must be a real reference. 
    return -1
	if (! ref($self));

    my $node_id = $self->node_id();

    DBQueryWarn("delete from current_reloads where node_id='$node_id'");

    return 0;
}

sub ClearPartitions($)
{
    my ($self) = @_;

    # Must be a real reference. 
    return -1
	if (! ref($self));

    my $node_id = $self->node_id();

    DBQueryWarn("delete from `partitions` where node_id='$node_id'");

    return 0;
}

# Boolean, does the node have any partitions setup.
sub HasPartitions($)
{
    my ($self) = @_;
    my $node_id = $self->node_id();

    my $query_result = 
	DBQueryWarn("select * from `partitions` where node_id='$node_id'");

    return 0
	if (!$query_result);

    return $query_result->numrows;
}

sub ClearReservation($)
{
    my ($self) = @_;

    # Must be a real reference. 
    return -1
	if (! ref($self));

    my $node_id = $self->node_id();

    if (DBQueryWarn("delete from reserved where node_id='$node_id'")) {
	$self->FlushReserved();
    }
    if ($self->boot_method() eq "pxelinux") {
	TBPxelinuxConfig($self);
    }
    return 0;
}

#
# Mark a node as down. We schedule a next reservation for it so that it
# remains in the users experiment through the termination so that there
# are no permission errors (say, from snmpit).
#
sub MarkAsDown($)
{
    my ($self) = @_;
    my $nodeid = (ref($self) ? $self->node_id() : $self);

    if (ClearBootAttributes($nodeid)) {
	print STDERR "*** WARNING: Could not clear boot attributes: $self!\n";
    }
    my $pid = NODEDEAD_PID();
    my $eid = NODEDEAD_EID();
    my $experiment = LocalExpLookup($pid, $eid);
    if (!defined($experiment)) {
	print STDERR "*** WARNING: No such experiment $pid/$eid!\n";
	return -1;
    }
    my $exptidx = $experiment->idx();

    my $query_result =
	DBQueryWarn("replace into next_reserve " .
		     "(node_id, exptidx, pid, eid) " .
		     "values ('$nodeid', '$exptidx', '$pid', '$eid')");
    if (!$query_result || !$query_result->num_rows) {
	print STDERR "*** WARNING: Could not mark $self as down\n";
	return -1;
    }
    return 0;
}
sub MarkAsIll($)
{
    my ($self) = @_;
    my $nodeid = (ref($self) ? $self->node_id() : $self);

    if (ClearBootAttributes($nodeid)) {
	print STDERR "*** WARNING: Could not clear boot attributes: $self!\n";
    }
    my $pid = NODEILL_PID();
    my $eid = NODEILL_EID();
    my $experiment = LocalExpLookup($pid, $eid);
    if (!defined($experiment)) {
	print STDERR "*** WARNING: No such experiment $pid/$eid!\n";
	return -1;
    }
    my $exptidx = $experiment->idx();

    my $query_result =
	DBQueryWarn("replace into next_reserve " .
		     "(node_id, exptidx, pid, eid) " .
		     "values ('$nodeid', '$exptidx', '$pid', '$eid')");
    if (!$query_result || !$query_result->num_rows) {
	print STDERR "*** WARNING: Could not mark $self as ill\n";
	return -1;
    }
    return 0;
}

#
# Set the boot status for a node. We also update the fail stamp/count
# as appropriate.
#
sub SetBootStatus($$)
{
    my ($self, $bstat) = @_;
    my $nodeid = (ref($self) ? $self->node_id() : $self);

    return -1
	if (!DBQueryWarn("update nodes set bootstatus='$bstat'  ".
			 "where node_id='$nodeid'"));

    return 0;
}

#
# Do a normal wakeonlan after power cycle. This is for laptops that like
# to go to sleep (especially while in PXEWAIT).
#
sub SimpleWOL($)
{
    my ($self) = @_;

    # Must be a real reference. 
    return -1
	if (! ref($self));

    my $node_id = $self->node_id();

    # XXX Must know the outgoing interface. Using the whol flag. Ick.
    my $query_result =
	DBQueryFatal("select iface from interfaces ".
		     "where node_id='boss' and whol=1");
    if ($query_result->numrows != 1) {
	warn "SimpleWOL: Could not get outgoing interface for boss node.\n";
	return -1;
    }
    my ($iface) = $query_result->fetchrow_array();

    #
    # Grab the control interface MAC for the node.
    #
    $query_result =
	DBQueryFatal("select mac from interfaces  ".
		     "where node_id='$node_id' and ".
		     "      role='" . TBDB_IFACEROLE_CONTROL() . "'");

    if ($query_result->numrows != 1) {
	warn "SimpleWOL: Could not get control interface MAC for $node_id.\n";
	return -1;
    }
    my ($mac) = $query_result->fetchrow_array();

    print "Doing a plain WOL to $node_id ($mac) via interface $iface\n";

    #
    # Do this a few times since the packet could get lost and
    # it seems to take a couple of packets to kick it.
    #
    for (my $i = 0; $i < 5; $i++) {
	system("$WOL $iface $mac");
	select(undef, undef, undef, 0.1);
    }
    select(undef, undef, undef, 5.0);
    return 0;
}

sub NewRootPasswd($)
{
    my ($self) = @_;

    # Must be a real reference. 
    return -1
	if (! ref($self));

    my $node_id = $self->node_id();
    my $hash    = TBGenSecretKey();

    # But only part of it.
    $hash = substr($hash, 0, 12);

    DBQueryWarn("replace into node_attributes set ".
		"  node_id='$node_id',".
		"  attrkey='root_password',attrvalue='$hash'")
	or return -1;

    return 0;
}

#
# Invoke OS selection. Currently we use this to reset to default boot,
# but might change later to take an argument.
#
sub SelectOS($;$)
{
    my ($self, $osid) = @_;

    # Must be a real reference. 
    return -1
	if (! ref($self));

    my $node_id = $self->node_id();
    my $args    = (defined($osid) ? "$osid" : "-b");

    system("$OSSELECT $args $node_id");
    return -1
	if ($?);
    return 0;
}

#
# Set geni sliver idx,tmcd for the node. Called out of the geni libraries
# when the sliver that corresponds to the node has been created.
#
sub SetGeniSliverInfo($$;$)
{
    my ($self, $idx, $tmcd_redirect) = @_;

    return -1
	if (! (ref($self)));

    my $args = {"genisliver_idx" => $idx};
    if (defined($tmcd_redirect)) {
	$args->{'tmcd_redirect'} =
	    ($tmcd_redirect eq "" ? "NULL" : $tmcd_redirect);
    }
    return $self->ModifyReservation($args);
}

#
# Get the geni info for a node.
#
sub GetGeniSliverInfo($$;$)
{
    my ($self, $idx, $tmcd_redirect) = @_;

    return -1
	if (! (ref($self)));

    my $reservation = $self->ReservedTableEntry();
    return -1
	if (!defined($reservation));

    $$idx = $reservation->{'genisliver_idx'};
    $$tmcd_redirect = $reservation->{'tmcd_redirect'}
        if defined($tmcd_redirect);

    return 0;
}

#
# Set the status slot for a node.
#
sub SetStatus($$)
{
    my ($self, $status) = @_;
    my $node_id = $self->node_id();

    return -1
	if (! DBQueryWarn("update node_status set status='$status' ".
			  "where node_id='$node_id'"));
    $self->{"DBROW"}->{'node_status'} = $status;
    return 0;
}

#
# Get the status slot for a node.
#
sub GetStatus($)
{
    my ($self) = @_;
    my $node_id = $self->node_id();

    my $query_result =
	DBQueryWarn("select status,unix_timestamp(status_timestamp) ".
		    "  from node_status ".
		    "where node_id='$node_id'");
    return undef
	if (! (defined($query_result) && $query_result->numrows));

    my ($status,$stamp) = $query_result->fetchrow_array();
    $self->{"DBROW"}->{'node_status'} = $status;
    return ($status,$stamp);
}

#
#
#
sub OSSelect($$$$)
{
    my ($self, $osimage, $field, $debug) = @_;
    my $nodeid  = $self->node_id();
    my $curmode = $self->op_mode();
    require OSImage;

    # Why? When will this happen?
    return 0
	if (!$curmode);

    # Special token, sorry.
    if (defined($osimage) && "$osimage" eq "<DEFAULT>") {
	$osimage = OSImage->Lookup($self->default_osid());
	if (!defined($osimage)) {
	    print STDERR "Could not map default_osid for $nodeid\n";
	    return -1;
	}
	my $nextosimage = $osimage->ResolveNextOSID();
	if (!defined($nextosimage)) {
	    print STDERR "Could not resolve nextosid for $osimage\n";
	    return -1;
	}
	$osimage = $nextosimage;
    }

    # Make sure the node is tainted if the OS selected is tainted.
    if (defined($osimage) && $osimage->IsTainted()) {
	if ($self->InheritTaintStates($osimage) != 0) {
	    print STDERR "Could not inherit taint states from $osimage\n";
	    return -1;
	}
    }
    
    if (defined($osimage) && !defined($field)) {
	print STDERR "No field specified for OSSelect on $nodeid\n";
	return -1;
    }

    if (defined($osimage) && $osimage->isImage()) {
	$osimage->GetProject()->BumpActivity();
    }

    if ($debug) {
	print STDERR "Current opmode for $nodeid is $curmode.\n";
	if (defined($osimage)) {
	    print STDERR "Setting $field for $nodeid to $osimage\n";
	} elsif (defined($field)) {
	    print STDERR "Clearing $field for $nodeid.\n";
	} else {
	    print STDERR "Clearing all boot_osids for $nodeid.\n";
	}
    }

    if (!defined($field)) {
	# Clear all osids.
	DBQueryWarn("update nodes set ".
		    "def_boot_osid=NULL,next_boot_osid=NULL,".
		    "temp_boot_osid=NULL, ".
		    "def_boot_osid_vers=0,next_boot_osid_vers=0,".
		    "temp_boot_osid_vers=0 ".
		    "where node_id='$nodeid'")
	    or return -1;
    } else {
	# Set/Clear the osid.
	my $osid = (defined($osimage) ? "'" . $osimage->osid() . "'" : "NULL");
	my $vers = (defined($osimage) ? "'" . $osimage->version() . "'" : "'0'");
	
	DBQueryWarn("update nodes set ${field}=$osid,${field}_vers=$vers ".
		    "where node_id='$nodeid'")
	    or return -1;

	return -1 
	    if ($self->ResetNextOpMode($debug) < 0);
    }

    if ($self->boot_method() eq "pxelinux") {
	TBPxelinuxConfig($self);
    }

    return Refresh($self);
}

#
#
#
sub PXESelect($$$$$)
{
    my ($self, $path, $field, $debug, $changedp) = @_;
    my $nodeid  = $self->node_id();
    my $didit = 0;

    print STDERR "Setting $field for $nodeid to '$path'.\n"
	if ($debug && $path);

    my $cur = ($field eq "pxe_boot_path") ?
	$self->pxe_boot_path() : $self->next_pxe_boot_path();
    $cur = "" if (!$cur);
    if ($cur ne $path) {
	DBQueryWarn("update nodes set ${field}=".
		    ($path ? "'$path'" : "NULL") .
		    " where node_id='$nodeid'")
	    or return -1;
	$didit = 1;
    }
    $$changedp = $didit
	if (defined($changedp));

    return Refresh($self);
}

sub ResetNextOpMode($$)
{
    my ($self,$debug) = @_;
    my $nodeid  = $self->node_id();
    my $curmode = $self->op_mode();

    # Why? When will this happen?
    return 0
	if (!$curmode);

    #
    # Determine what osid the node will now boot. We need to know this so we
    # can set the next opmode. This call has to return *something* or we are
    # screwed since we will not be able to figure out the opmode.
    #
    my ($bootosid, $bootopmode) = TBBootWhat($nodeid, $debug);
    if (!defined($bootosid)) {
	print STDERR "Bootwhat query failed for $nodeid!\n";
	return -1;
    }
    #
    # If it returned 0 the node is in PXEWAIT.
    # For the node to do anything useful going forward, someone will
    # have to first set one of the osids with os_select.
    #
    if ($bootosid == 0) {
	return 0;
    }
    #
    # XXX this has only ever happened once, when a newnode failed to boot
    # up properly, but since it will cause stated to die, let's check for it.
    # I have no idea if this is the correct thing to set it to, but we do
    # this below as well, so I am going with it...
    #
    if (!defined($bootopmode)) {
	$bootopmode = "";
    }

    print STDERR "Bootwhat says: $nodeid => $bootosid,$bootopmode\n"
	if ($debug);

    #
    # If its different then what the node is currently booting, then
    # set up a transition in stated. If no change, be sure to clear
    # is since stated does not like a transition to be specified when
    # none is actually going to be made.
    #
    if ($curmode eq $bootopmode) {
	$bootopmode = "";
    }
    DBQueryWarn("update nodes set next_op_mode='$bootopmode' ".
		 "where node_id='$nodeid'")
	or return -1;

    return 0;
}

#
# Get the next rtabid for a shared node. Need locking in this case
# since multiple mappers can be running at once.
#
# We only need to do this on the physical node. On the virtual node, use
# the same slot to store what rtabid was assigned to the vnode.
#
sub Nextrtabid($)
{
    my ($self) = @_;
    my $rtabid = undef;

    my $node_id = $self->node_id();
    
    DBQueryWarn("lock tables nodes write")
	or return undef;

    DBQueryWarn("update nodes set rtabid=rtabid+1 ".
		"where node_id='$node_id'")
	or goto bad;
    my $query_result =
	DBQueryWarn("select rtabid from nodes ".
		    "where node_id='$node_id'");
    goto bad
	if (!$query_result || !$query_result->numrows);
    ($rtabid) = $query_result->fetchrow_array();
  bad:
    DBQueryWarn("unlock tables");
    return $rtabid;
}

#
# Set rtabid for a node.
#
sub Setrtabid($$)
{
    my ($self, $rtabid) = @_;

    return -1
	if (! (ref($self)));
    
    my $node_id = $self->node_id();
    
    DBQueryWarn("update nodes set rtabid='$rtabid' where node_id='$node_id'")
	or return -1;

    return Refresh($self);
}

#
# Set nonfsmounts for a node.
#
sub NoNFSMounts($)
{
    my ($self) = @_;

    return -1
	if (! (ref($self)));
    
    my $node_id = $self->node_id();
    
    DBQueryWarn("update nodes set nonfsmounts='1',nfsmounts='none' ".
		"where node_id='$node_id'")
	or return -1;

    return 0;
}

#
# Get the max share count for a node. This is actually the pcvm count
# from the aux table, but might change someday, I hope.
#
sub MaxShareCount($)
{
    my ($self) = @_;

    return -1
	if (! (ref($self)));
    
    my $node_id = $self->node_id();

    my $query_result =
	DBQueryWarn("select count from node_auxtypes ".
		     "where node_id='$node_id' and type='pcvm'");
    return -1
	if (!$query_result);
    return 10
	if (!$query_result->numrows);

    my ($count) = $query_result->fetchrow_array();
    return $count;
}

sub IsVirtHost($)
{
    my $self = shift;
    return 1
	if ($self->{"DBROW"}{"role"} eq 'virthost');
    return 0;
}

sub GetPhysHost($) {
    my $self = shift;
    my $phys_nodeid = $self->{"DBROW"}{"phys_nodeid"};
    if (defined($phys_nodeid) && $phys_nodeid ne '') {
	return Node->Lookup($phys_nodeid);
    }
    return undef;
}

sub GetOsids($) {
    my $self = shift;
    return ($self->{"DBROW"}{"def_boot_osid"},
	    $self->{"DBROW"}{"temp_boot_osid"},
	    $self->{"DBROW"}{"next_boot_osid"});
}

sub ClearOsids($) {
    my $self = shift;

    my $node_id = $self->node_id();
    
    DBQueryWarn("update nodes set ".
		"  def_boot_osid=NULL,".
		"  next_boot_osid=NULL,".
		"  temp_boot_osid=NULL, ".
		"  def_boot_osid_vers=0,".
		"  next_boot_osid_vers=0,".
		"  temp_boot_osid_vers=0 ".
		"where node_id='$node_id'")
	or return -1;

    $self->{"DBROW"}{"def_boot_osid"}  = undef;
    $self->{"DBROW"}{"temp_boot_osid"} = undef;
    $self->{"DBROW"}{"next_boot_osid"} = undef;
    $self->{"DBROW"}{"def_boot_osid_vers"}  = 0;
    $self->{"DBROW"}{"temp_boot_osid_vers"} = 0;
    $self->{"DBROW"}{"next_boot_osid_vers"} = 0;
    
    if ($self->boot_method() eq "pxelinux") {
	TBPxelinuxConfig($self);
    }

    return 0;
}

#
# Look for a widearea node by its external node id.
#
sub LookupWideArea($$)
{
    my ($class, $external_node_id) = @_;
    my $safe_id = DBQuoteSpecial($external_node_id);

    my $query_result =
	DBQueryWarn("select node_id from widearea_nodeinfo ".
		    "where external_node_id=$safe_id");

    return undef
	if (!defined($query_result) || !$query_result->numrows);

    my ($node_id) = $query_result->fetchrow_array();

    return Node->Lookup($node_id);
}

#
# Return the partition that an OSID is loaded on. 
#
sub IsOSLoaded($$)
{
    my ($self, $osimage) = @_;
    require OSImage;

    if (!ref($osimage)) {
	my $tmp = OSImage->Lookup($osimage);
	if (!defined($tmp)) {
	    print STDERR "Cannot lookup osimage for $osimage\n";
	    return -1;
	}
	$osimage = $tmp;
    }
    my $osid   = $osimage->osid();
    my $vers   = $osimage->version();
    my $nodeid = $self->node_id();

    my $query_result =
	DBQueryWarn("select osid from `partitions` as p ".
		    "where p.node_id='$nodeid' and p.osid='$osid' and ".
		    "      p.osid_vers='$vers'");
    return -1
	if (!$query_result);

    return $query_result->numrows;
}

#
# Determine an IP address for a jail node. Lifted from CreateVnodes() above.
#
sub GetJailIP($;$)
{
    my ($self, $num) = @_;
    my $ipbase;

    $num = 2
	if (!defined($num));
    
    #
    # Need IP for jailed nodes.
    # 
    my $IPBASE = TBDB_JAILIPBASE();
    my $IPBASE1;
    my $IPBASE2;
    if ($IPBASE =~ /^(\d+).(\d+).(\d+).(\d+)/) {
	$IPBASE1 = $1;
	$IPBASE2 = $2;
    }
    else {
	print STDERR "*** GetJailIP: Bad IPBASE '$IPBASE'\n";
	return undef;
    }

    #
    # Determine ipbase from the control IP (jailed nodes).
    #
    my $interface = Interface->LookupControl($self);
    if (!defined($interface)) {
	print STDERR "*** GetJailIP: No control interface for $self\n";
	return undef;
    }
    my $ctrlip = $interface->IP();
    if (!defined($ctrlip) || $ctrlip eq "") {
	print STDERR "*** GetJailIP: No control IP for $interface\n";
	return undef;
    }
    if ($self->node_id() =~ /^(.*\D)(\d+)$/) {
	$ipbase     = $2;
    }
    else {
	my $tmp = ~inet_aton($CONTROL_NETMASK) & inet_aton($ctrlip);
	$ipbase = unpack("N", $tmp);
	if ($ipbase == 0 || $ipbase < 0 || $ipbase > 0x3fff) {
	    print STDERR "*** GetJailIP: Bad ipbase '$ipbase' for $interface\n";
	    return undef;
	}
    }

    my $nodenumlimit = $ISUTAH ? 200 : 254;
    my $pnet = $IPBASE2;
    my $pnode2 = int($ipbase);
    while ($pnode2 > $nodenumlimit) {
	$pnet++;
	$pnode2 -= $nodenumlimit;
    }
    return ("${IPBASE1}.${pnet}.${pnode2}.${num}", $JAILIPMASK);
}

#
# Another variant of above, this one looks in the virt_node_attributes
# table of the vnode assigned to the pnode.
#
sub SetJailIPFromVnode($$$)
{
    my ($self, $experiment, $vnode_id) = @_;
    my ($jailip, $jailipmask);

    return -1
	if ($experiment->GetVirtNodeAttribute($vnode_id,
					      "jailip", \$jailip) < 0 ||
	    $experiment->GetVirtNodeAttribute($vnode_id,
					      "jailipmask", \$jailipmask)  < 0);

    if (defined($jailip)) {
	if (!defined($jailipmask)) {
	    print STDERR
		"*** $vnode_id has a jailip attribute but no jailipmask.\n";
	    return -1;
	}
	#
	# We now create interface entries for local jailed nodes, so have
	# to update the entry. We still use jailip under some circumstances.
	#
	if (!$self->isremotenode() && !defined($self->jailip())) {
	    my $interface = Interface->LookupControl($self);
	    if (!defined($interface)) {
		print STDERR "*** $vnode_id does not have a control interface\n";
		return -1;
	    }
	    $interface->Update({"IP"   => $jailip,
				"mask" => $jailipmask})
		== 0 or return -1;
	}
	else {
	    return $self->Update({"jailip" => $jailip,
				  "jailipmask" => $jailipmask});
	}
    }
    return 0;
}

#
# Check for, and update a node pre reservation.
#
sub CheckPreReserve($$$)
{
    my ($self, $isfree, $quiet) = @_;
    my $result = undef;

    #
    # Look for a pre-reserve request.
    #
    my $type = $self->type();
    my $node_id = $self->node_id();
    
    DBQueryWarn("lock tables project_reservations as pr write, nodes write, ".
		"            node_reservations as pnr write, reserved read")
	or return undef;

    #
    # isfree is a flag that says we are coming from nfree or stated,
    # and the node is going into the free pool. When not set (as from
    # prereserve) we have to check the reserved table to see if it is
    # free; we do not mess with an allocated node. We do this here with
    # the rest of the locked tables.
    #
    if (!$isfree) {
	my $query_result =
	    DBQueryWarn("select pid,eid from reserved ".
			"where node_id='$node_id'");
	goto done
	    if (!$query_result || $query_result->numrows);
    }

    #
    # Need to check for existing reserved_pid, but have to go to the DB,
    # not look in the object ($self) since it might be stale.
    #
    # There is a builtin assumption that we get back a row if the
    # node still exists, although it will be a row of nulls if there
    # is no prereserve marking. 
    #
    my $query_result =
	DBQueryWarn("select reserved_pid,reservation_name, ".
		    "  count,active,terminal,approved from nodes ".
		    "left join project_reservations as pr on ".
		    "     pr.pid=nodes.reserved_pid and ".
		    "     pr.name=nodes.reservation_name ".
		    "where nodes.node_id='$node_id'");

    # numrows would be zero if the node was suddenly deleted.
    goto done
	if (!defined($query_result) || !$query_result->numrows);

    #
    # If there is a reserved pid already set for this node, check to see
    # if the reservation request is still active. If not, we can clear it,
    # which will allow it to be set again below, if needed.
    #
    my ($pid,$resname,$count,$active,$terminal,$approved) =
	$query_result->fetchrow_array();
    if (defined($pid)) {
	# There is an active pre-reserve for this node.
	goto done
	    if (defined($count) && $active && !$terminal);
	# If the reservation_name is null, the node was prereserved
	# via the web page, not by a prereserve command line. Do not
	# mess with it.
	goto done
	    if (!defined($resname));
	
	DBQueryWarn("update nodes set reserved_pid=null, ".
		    "  reservation_name=null ".
		    "where node_id='$node_id'");

	if (!$quiet) {
	    print "Clearing pre reserve for $node_id\n";
	}
    }

    #
    # Prereserves are very different now, since they look like reservations
    # for a single specific node and so there can only be one (active)
    # prereserve for this node. Also, the reservation system will not allow
    # the current holder to extend beyond the start of prereservation. So this
    # stuff is mostly a holdover from the old best effort prereserve system
    # which was waiting until the node was released and then sucking it up.
    # But we still need to set reserved_pid, to avoid chainging a bunch of
    # other stuff (ptopgen, web UI, etc). 
    #
    $query_result =
	DBQueryWarn("select pr.pid,pr.count,pr.name ".
		    "  from project_reservations as pr ".
		    "left join node_reservations as pnr on ".
		    "     pr.pid=pnr.pid and ".
		    "     pr.name=pnr.reservation_name ".
		    "where pnr.node_id='$node_id' and pr.terminal=0 and ".
		    "      pr.active=1");
    
    goto done
	if (! ($query_result && $query_result->numrows));

    ($pid,$count,$resname) = $query_result->fetchrow_array();

    if (DBQueryWarn("update nodes set reserved_pid='$pid', ".
		    "    reservation_name='$resname' ".
		    "where node_id='$node_id'") &&
	DBQueryWarn("update project_reservations as pr set count=count-1 ".
		    "where pid='$pid' and name='$resname'")) {
	
	$result = $pid;

	if ($count == 1) {
	    SENDMAIL($TBOPS,
		     "Pre Reservation $pid,$resname has completed",
		     "The pre reservation request for project ".
		     "$pid,$resname has been fullfilled\n", $TBOPS);
	}
    }
  done:
    DBQueryWarn("unlock tables");
    if (defined($result) && !$quiet) {
	print "Setting pre-reserve for $node_id to $result\n";
    }
    return $result;
}

#
# Add an outlet entry. Optional authorization info.
#
sub AddOutlet($$$$)
{
    my ($self, $powerid, $outlet, $authinfo) = @_;

    my $safe_powerid = DBQuoteSpecial($powerid);
    my $safe_outlet  = DBQuoteSpecial($outlet);
    my $node_id      = $self->node_id();

    DBQueryWarn("replace into outlets set ".
		"  node_id='$node_id', power_id=$safe_powerid, ".
		"  outlet=$safe_outlet")
	or return -1;

    if (defined($authinfo)) {
	my $key_type = DBQuoteSpecial($authinfo->{"key_type"});
	my $key_role = DBQuoteSpecial($authinfo->{"key_role"});
	my $key_uid  = DBQuoteSpecial($authinfo->{"key_uid"});
	my $key      = DBQuoteSpecial($authinfo->{"key"});
	
	DBQueryWarn("replace into outlets_remoteauth set ".
		    "  node_id='$node_id', key_type=$key_type, ".
		    "  key_role=$key_role, key_uid=$key_uid, mykey=$key")
	    or return -1;
    }
    return 0;
}

sub DeleteOutlet($)
{
    my ($self) = @_;
    my $node_id = $self->node_id();

    DBQueryWarn("delete from outlets_remoteauth where node_id='$node_id'")
	or return -1;

    DBQueryWarn("delete from outlets where node_id='$node_id'")
	or return -1;

    return 0;
}

sub GetOutletAuthInfo($$)
{
    my ($self, $keytype) = @_;
    my $node_id = $self->node_id();

    my $query_result =
	DBQueryWarn("select key_uid,mykey from outlets_remoteauth ".
		    "where node_id='$node_id' and key_role='$keytype'");
    return undef
	if (!defined($query_result) || !$query_result->numrows);

    my ($login,$auxinfo) = $query_result->fetchrow_array();

    return ($login, $auxinfo);
}

sub HasOutlet($)
{
    my ($self) = @_;
    my $node_id = $self->node_id();

    my $query_result =
	DBQueryWarn("select node_id from outlets ".
		    "where node_id='$node_id'");
    return 0
	if (!defined($query_result) || !$query_result->numrows);

    return 1;
}

#
# Get the currently running os/image for a node.
#
sub RunningOsImage($)
{
    require OSImage;

    my ($self)  = @_;
    my $nodeid  = $self->node_id();
    my $osid    = $self->def_boot_osid();
    my $vers    = $self->def_boot_osid_vers();
    
    my $osimage = OSImage->Lookup($osid, $vers);
    return ()
	if (!defined($osimage));

    # Backwards compatibility; callers want old osinfo and image separately.
    return ($osimage, $osimage);
}

#
# Send an authenticated ipod to the node.
# Return 0 on success, non-zero otherwise.
#
sub SendApod($$)
{
    my ($self,$tryipod)  = @_;
    return -1
	if (! ref($self));

    my $nodeid = $self->node_id();

    my $query_result =
	DBQueryFatal("select ipodhash from nodes where node_id='$nodeid'");
    if ($query_result && $query_result->numrows == 1) {
	my ($hash) = $query_result->fetchrow_array();
	if ($hash) {
	    #
	    # It is okay to put this hash on the command line in the
	    # Emulab context. These are one-time passwords, and for that
	    # one time, if someone sees it on the command line the worst
	    # they can do is reboot the node. And that is what we are trying
	    # to do anyway!
	    #
	    # Also, note there we do not quote the hash, we don't want
	    # perl to invoke an extra level of shell. The hash had better
	    # not have any spaces or shell metachars!
	    #
	    if (system("$IPOD -h $hash $nodeid") == 0) {
		return 0;
	    }
	}
    }

    # no hash or authenticated version failed, try plain ole ipod
    if ($tryipod && system("$IPOD $nodeid") == 0) {
	return 0;
    }

    return -1;
}

#
# Generate a hash value to store in the tiplines table for the node,
# The hash can only be used once and is valid for a short time
# (say, 30 seconds). 
#
sub GenTipAclUrl($;$$)
{
    my ($self,$expstamp,$reuseurl) = @_;
    my $node_id = $self->node_id();
    my $hash = TBGenSecretKey();
    if (!defined($hash)) {
	print STDERR "Error creating new hash code\n";
	return undef;
    }

    my $now = time();
    if (!defined($expstamp)) {
	# note: nodetipacl.php3 used 300, not 30
	$expstamp = $now + 300;
    } elsif ($expstamp && $expstamp < $now) {
	print STDERR "Invalid expiration for tip URL\n";
	return undef;
    }

    if (!defined($reuseurl)) {
	$reuseurl = 0;
    } elsif ($reuseurl != 0 && $reuseurl != 1) {
	print STDERR "Invalid value for 'reuseurl': $reuseurl\n";
	return undef;
    }

    DBQueryWarn("update tiplines set urlhash='$hash', ".
		"  urlstamp=$expstamp, reuseurl=$reuseurl ".
		"where node_id='$node_id'")
	or return undef;

    return "$TBBASE/nodetipacl.php3?node_id=$node_id&key=$hash";
}
sub CheckTipAcl($$)
{
    my ($self,$hash) = @_;
    my $node_id   = $self->node_id();
    my $safe_hash = DBQuoteSpecial($hash);
    
    my $query_result =
	DBQueryWarn("select node_id from tiplines ".
		    "where node_id='$node_id' and urlhash=$safe_hash and ".
		    "      UNIX_TIMESTAMP(now())<=urlstamp");
    return -1
	if (!$query_result || !$query_result->numrows);

    return 0;
}
sub ClrTipAclUrl($)
{
    my ($self) = @_;
    my $node_id = $self->node_id();
    
    DBQueryWarn("update tiplines set urlhash=NULL,urlstamp=0,reuseurl=0 ".
		"where node_id='$node_id'")
	or return -1;

    return 0;
}

#
# Generate an authentication object to pass to the browser that
# is passed to the web server on ops. This is used to grant
# permission to the user to invoke tip to the console. 
#
sub ConsoleAuthObject($$)
{
    my ($self, $uid) = @_;
    my $node_id = $self->node_id();
    my $capfile = "$TB/etc/capture.fingerprint";
    my $keyfile = "$TB/etc/sshauth.key";
    my $version = "1.0";
    my $baseurl;
    require JSON;
    require Digest::HMAC_SHA1;

    #
    # We need the secret that is shared with ops.
    #
    my $key = emutil::ReadFile($keyfile);
    if (!defined($key)) {
	print STDERR "Could not read key from $keyfile\n";
	return undef;
    }
    chomp($key);

    #
    # Also need the cert hash to put in,
    #
    my $certhash = emutil::ReadFile($capfile);
    if (!defined($certhash)) {
	print STDERR "Could not get Fingerprint from $capfile\n";
	return undef;
    }
    if ($certhash =~ /Fingerprint=([\w:]+)$/) {
	$certhash = $1;
    }
    else {
	print STDERR "Could not find hash in Fingerprint\n";
	return undef;
    }
    my $stuff = TBGenSecretKey();
    if (!$stuff) {
	print STDERR "Could not generate random data\n";
	return undef;
    }
    my $now   = time();
    if ($BROWSER_CONSOLE_PROXIED) {
	$baseurl = "https://${WWWHOST}";
    }
    else {
	$baseurl = "https://${USERNODE}";
    }
    if ($BROWSER_CONSOLE_WEBSSH) {
	$baseurl .= "/webssh";
    }
    #
    # And the tipline stuff.
    #
    my ($server, $portnum, $conkey, $keylen);
    
    if ($self->TipServer(\$server, undef, \$portnum, \$conkey)) {
	print STDERR "No console info for $node_id\n";
	return undef;
    }
    $keylen = length($conkey);
	
    my $console = {
	"server"   => $server,
	"portnum"  => $portnum,
	"keydata"  => $conkey,
	"keylen"   => $keylen,
	"certhash" => $certhash,
	
    };
    my $sigstuff = $uid . $stuff . $node_id . $now . " " .
	$server . "," . $portnum . "," . $keylen . "," . $conkey .
	"," . $certhash;
	
    my $authobj = {
	'uid'       => $uid,
	'console'   => $console,
	'stuff'     => $stuff,
	'nodeid'    => $node_id,
	'timestamp' => $now,
	'webssh'    => $BROWSER_CONSOLE_WEBSSH,
        'baseurl'   => $baseurl,
        'signature_method' => 'HMAC-SHA1',
        'api_version' => $version,
	'signature'   => Digest::HMAC_SHA1::hmac_sha1_hex($sigstuff, $key)
    };
    my $json = eval { JSON::encode_json($authobj); };
    if ($@) {
	print STDERR "Could not encode auth object: $@\n";
	return undef;
    }
    return $json;
}

# Stubs for calling "libTaintStates" common taint handling code
sub GetTaintStates($) {
    my ($self) = @_;
    require libTaintStates;

    return libTaintStates::GetTaintStates($self);
}
sub IsTainted($;$) {
    my ($self, $taint) = @_;
    require libTaintStates;

    return libTaintStates::IsTainted($self, $taint);
}
sub TaintIs($@) {
    my ($self, @taint_states) = @_;
    require libTaintStates;

    return libTaintStates::TaintIs($self, @taint_states);
}
sub SetTaintStates($@) {
    my ($self, @taint_states) = @_;
    require libTaintStates;

    my $rv = libTaintStates::SetTaintStates($self, @taint_states);
    if (!$rv && libTaintStates::IsTainted($self)) {
	$self->SetKeyDist(undef, 0);
    }
    return $rv;
}
sub AddTaintState($$) {
    my ($self, $taint) = @_;
    require libTaintStates;

    my $rv = libTaintStates::AddTaintState($self, $taint);
    if (!$rv && libTaintStates::IsTainted($self)) {
	$self->SetKeyDist(undef, 0);
    }
    return $rv;
}
sub RemoveTaintState($;$) {
    my ($self, $taint) = @_;
    require libTaintStates;

    return libTaintStates::RemoveTaintState($self, $taint);
}
sub InheritTaintStates($$) {
    my ($self, $osimage) = @_;
    require libTaintStates;

    my $rv = libTaintStates::InheritTaintStates($self, $osimage);
    if (!$rv && libTaintStates::IsTainted($self)) {
	$self->SetKeyDist(undef, 0);
    }
    return $rv;
}


#
# Synchornize the node's taint states based on the OSes listed
# for its partitions.  Existing taint states on the node are
# maintainted.
#
sub SyncDiskPartitionTaintStates($)
{
    my ($self) = @_;
    my $error = 0;
    require OSImage;

    my $node_id = $self->node_id();

    my $query_result =
	DBQueryWarn("select osid,osid_vers from `partitions` ".
		    "where node_id='$node_id' and osid is not null");
    return -1
	if (!$query_result);

    while (my ($osid, $vers) = $query_result->fetchrow_array()) {
	my $osimage = OSImage->Lookup($osid, $vers);
	if (defined($osimage) && $osimage->IsTainted()) {
	    $error += $self->InheritTaintStates($osimage);
	}
    }

    return $error ? -1 : 0;
}

#
# We have a problem with pcvms on remoteded machines. The typing is
# messed up, not sure what to do yet. Might not be worth fixing since
# Utah is the only site that does this stuff.
#
sub OnRemoteNode($)
{
    my ($self) = @_;
    my $physhost = $self->GetPhysHost();
    return 0
	if (!defined($physhost));
    return $physhost->isremotenode();
}

#
# Quick check to see if we have routable IPs addresses free.
#
sub HaveRoutableIPs($$)
{
    my ($class, $needed) = @_;

    my $query_result =
	DBQueryWarn("select count(ip) from virt_node_public_addr ".
		    "where node_id is null and eid is null");
    return 0
	if (!$query_result || $query_result->numrows < 1);

    my( $count ) = $query_result->fetchrow_array();
    return 0
	if( $count < $needed );

    return 1;
}

#
# For performing a bit of early UE (mobile) device configuration
#
sub UEConfig($) {
    my ($self) = @_;

    my $node_id = $self->node_id();
    my $experiment = $self->Reservation();

    if (!$experiment) {
	print STDERR "*** Cannot call UEConfig() unless node is in an ".
	             "experiment!\n";
	return -1;
    }

    if ($self->class() ne "ue") {
	print STDERR "*** DO NOT call UEConfig() for nodes that are not of class 'ue'!\n";
	return -1;
    }

    # Request forwarding port if adb_host virt_node_attribute is set.
    my $adb_target;
    $self->FlushReserved();
    $experiment->GetVirtNodeAttribute($self->vname(), "adb_target", 
				      \$adb_target);
    if ($adb_target) {
	my $tnode = $experiment->VnameToNode($adb_target);
	if ($tnode) {
	    my $c_iface = Interface->LookupControl($tnode);
	    if ($c_iface && $c_iface->IP()) {
		$adb_target = $c_iface->IP();
	    } else {
		print STDERR "*** Could not find control network interface for $tnode!\n";
		return -1;
	    }
	}
	if (system("$TBADB -n $node_id resvport $adb_target") != 0) {
	    print STDERR "*** Failed to reserve ADB port for $node_id!\n";
	    return -1;
	}
    }

    # Get current USIM sequence number, increment and save, and add
    # as virt_node_attribute to be picked up and put in manifest.
    my $seqdef;
    my $seqincr;
    TBGetSiteVar("ue/sim_sequence_default", \$seqdef);
    TBGetSiteVar("ue/sim_sequence_increment", \$seqincr);
    if (!$seqdef || !$seqincr) {
	print STDERR "*** Could not get UE sequence number site variables!\n";
    } else {
	my $seqnum;
	$self->NodeAttribute("sim_sequence_number", \$seqnum);
	if (!$seqnum) {
	    print STDERR "Warning: No sequence number for UE $node_id.  Setting to sitevar default: $seqdef\n";
	    $self->SetNodeAttribute("sim_sequence_number", $seqdef);
	} else {
	    $seqnum += int($seqincr);
	    $self->SetNodeAttribute("sim_sequence_number", $seqnum);
	}
    }

    return 0;
}

#
# Return the idle data (idletime,staleness) for a node.
#
sub IdleData($)
{
    my ($self)  = @_;
    my $node_id = $self->node_id();
    my $clause  =
	"greatest(last_tty_act,last_net_act,last_cpu_act,last_ext_act)";

    my $query_result =
	DBQueryWarn("select (unix_timestamp(now()) - ".
		    "        unix_timestamp($clause)), ".
		    "       (unix_timestamp(now()) - ".
		    "        unix_timestamp(last_report)) ".
		    "  from node_activity ".
		    "where node_id='$node_id' and ".
		    "      UNIX_TIMESTAMP(last_report)!=0");
    return ()
	if (! ($query_result && $query_result->numrows));
    my ($idle_time,$staleness) = $query_result->fetchrow_array();
    # if it is less than 5 minutes, it is not idle at all...
    if ($idle_time < 300) {
	$idle_time = 0;
    }
    my $stale = ($staleness > 600 ? 1 : 0);
    return ($idle_time, $staleness, $stale);
}

sub RusageData($)
{
    my ($self)  = @_;
    my $node_id = $self->node_id();

    my $query_result =
	DBQueryWarn("select *,UNIX_TIMESTAMP(status_timestamp) as tstamp ".
		    "  from node_rusage ".
		    "where node_id='$node_id'");
    return undef
	if (! ($query_result && $query_result->numrows));

    my $row  = $query_result->fetchrow_hashref();
    my $blob = {"timestamp" => $row->{"tstamp"},
		"load"      => {"60"   => $row->{"load_1min"},
				"300"  => $row->{"load_5min"},
				"900"  => $row->{"load_15min"}}};
    return $blob;
}

sub HasStartupAgent($)
{
    my ($self)  = @_;
    my $vname   = $self->vname();
    my $exptidx = $self->exptidx();
    my $query_result =
	DBQueryWarn("select arguments from eventlist ".
		    "where exptidx='$exptidx' and vnode='$vname' and time=0");
    return 0
	if (!$query_result);

    return $query_result->numrows;
}

#
# Check and see if the node is currently in the admin MFS or would be at
# the next reboot (i.e., someone has done "node_admin -n on").
#
# This is for nodes where we need to construct or grant access to a
# node-specific admin MFS instance. Currently this is only used for NFS-based
# admin MFSes on the Moonshot nodes.
#
sub NeedsAdminMFS($)
{
    my ($self)  = @_;

    # currently in admin MFS
    if ($self->op_mode() eq "PXEFBSD") {
	return 1;
    }

    # scheduled to go into admin MFS next
    if ($self->next_op_mode() && $self->next_op_mode() eq "PXEFBSD") {
	return 1;
    }

    # set to go into admin MFS after one-time boot
    # XXX needs more work, MFS never gets created in this case
    #     only comes up if we turn on node_admin while a frisbee is scheduled
    if (0 && $self->next_boot_osid() && $self->temp_boot_osid()) {
	require OSImage;
	
	if (OSImage->Lookup($self->temp_boot_osid)->IsNfsMfs()) {
	    return 1;
	}
    }
    return 0;
}

#
# Spectrum stuff.
#
sub AddSpectrum($$$)
{
    my ($self, $spectrum, $iface) = @_;
    my $node_id = $self->node_id();
    my @ifaces = ();
    require EmulabConstants;

    if (defined($iface)) {
	@ifaces = ($iface);
    }
    else {
	if (Interface->LookupAll($self, \@ifaces)) {
	    return -1;
	}
    }
    foreach $iface (@ifaces) {
	my $iface_id = $iface->iface();

	next
	    if ($iface->role() ne EmulabConstants::TBDB_IFACEROLE_EXPERIMENT());

	# Check to see if this is an OTA interface.
	my $ota;
	next
	    if (! ($iface->TypeCapability("overtheair", \$ota) == 0 && $ota));

	foreach my $request (@{$spectrum}) {
	    my $frequency_low  = DBQuoteSpecial($request->{"frequency_low"});
	    my $frequency_high = DBQuoteSpecial($request->{"frequency_high"});
	    my $power          = DBQuoteSpecial($request->{"power"});

	    #
	    # Lets not worry about duplicates across the three different,
	    # we insert global first, then per-node, then per-interface.
	    #
	    return -1
		if (!DBQueryWarn("replace into interfaces_rf_limit set ".
				 "  node_id='$node_id', iface='$iface_id', ".
				 "  freq_low=$frequency_low, ".
				 "  freq_high=$frequency_high, ".
				 "  power=$power"));
	}
    }
    return 0;
}

#
# Is a node in recovery
#
sub InRecovery($)
{
    my ($self) = @_;

    return 1
	if ($self->recoverymfs_osid() && $self->temp_boot_osid() &&
	    $self->recoverymfs_osid() == $self->temp_boot_osid());

    return 0;
}

# _Always_ make sure that this 1 is at the end of the file...
1;
