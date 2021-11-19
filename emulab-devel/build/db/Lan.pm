#!/usr/bin/perl -wT
#
# Copyright (c) 2007-2021 University of Utah and the Flux Group.
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
package Lan;

use strict;
use Exporter;
use vars qw(@ISA @EXPORT);

@ISA    = "Exporter";
@EXPORT = qw ( );

# Must come after package declaration!
use libdb;
use libtestbed;
use Node;
# Doesn't seem to be used presently...
# use Port;
use English;
use Data::Dumper;
use overload ('""' => 'Stringify');
use vars qw(@EXPORT_OK);

# Configure variables
my $TB		= "/test";
my $BOSSNODE    = "boss.cloudlab.umass.edu";
my $CONTROL	= "ops.cloudlab.umass.edu";
my $TBOPS       = "testbed-ops\@ops.cloudlab.umass.edu";

# Why, why, why?
@EXPORT_OK = qw();

# Cache of instances to avoid regenerating them.
my %lans   = ();
BEGIN { use emutil; emutil::AddCache(\%lans); }

my $debug  = 0;
sub debugging() {return $debug; }

# Set during initial crossover.
my $initialize = 0;

my %LanTables = ("lans"           => ["lanid"],
		 "lan_attributes" => ["lanid", "attrkey"],
		 "lan_members"    => ["lanid", "memberid"],
		 "lan_member_attributes" => ["lanid", "memberid", "attrkey"],
		 "ifaces"         => ["lanid", "ifaceid"]);

#
# Initialize Openflow attributes in lan_attributes table.
#
sub InitOpenflowAttributes($$$$)
{
    my ($class, $exptidx, $vname, $lanid) = @_;

    my $ofenabled = 0;
    my $ofcontroller = "";
    my $safe_val;
    
    # Add openflow arrtibutes:
    my $query_result =
	DBQueryWarn("select ofenabled, ofcontroller from virt_lans ".
		    "where exptidx='$exptidx' and vname='$vname'");
    return 0
	if (!$query_result);	
    ($ofenabled, $ofcontroller) = $query_result->fetchrow_array()
	if ($query_result->numrows);
    $ofcontroller = ""
	if (!$ofenabled || !defined($ofcontroller));
    return 1
	if (!$ofenabled);
	
    #
    # Firstly check if the attribuets are there, if no values, 
    # insert them. This is because the vlan may be created
    # by Lookup many times. The values can be overwritten by
    # the later creation.
    #
    # Process 'ofenabled':
    $query_result =
	DBQueryWarn("select attrvalue from lan_attributes ".
		    "where lanid='$lanid' and attrkey='ofenabled'");
    return 0
	if (!$query_result);
    if (!$query_result->numrows)
    {
	$safe_val = DBQuoteSpecial($ofenabled);
	$query_result =
	    DBQueryWarn("replace into lan_attributes set ".
			"  lanid='$lanid', ".
			"  attrkey='ofenabled', ".
			"  attrvalue=$safe_val, ".
			"  attrtype='integer'");
	return 0
	    if (!defined($query_result));	  
    }
    
    # Process 'ofcontroller':
    $query_result =
	DBQueryWarn("select attrvalue from lan_attributes ".
		    "where lanid='$lanid' and attrkey='ofcontroller'");
    return 0
	if (!$query_result);
    if (!$query_result->numrows)
    {
	$safe_val = DBQuoteSpecial($ofcontroller);
	$query_result =
	    DBQueryWarn("replace into lan_attributes set ".
			"  lanid='$lanid', ".
			"  attrkey='ofcontroller', ".
			"  attrvalue=$safe_val, ".
			"  attrtype='string'");
	return 0
	    if (!defined($query_result));	  
    }

    # Process 'oflistener':
    $query_result =
	DBQueryWarn("select attrvalue from lan_attributes ".
		    "where lanid='$lanid' and attrkey='oflistener'");
    return 0
	if (!$query_result);
    if (!$query_result->numrows)
    {
	$safe_val = DBQuoteSpecial("");
	$query_result =
	    DBQueryWarn("replace into lan_attributes set ".
			"  lanid='$lanid', ".
			"  attrkey='oflistener', ".
			"  attrvalue=$safe_val, ".
			"  attrtype='string'");
	return 0
	    if (!defined($query_result));	  
    }
    
    return 1;
}


#
# Lookup and create a class instance to return.
#
sub Lookup($$;$$)
{
    my ($class, $arg1, $arg2, $linkokay) = @_;
    my $lanid;
    my $experiment;

    #
    # A single arg is a lanid. Two args is exptidx and vname (lan name).
    #
    if (!defined($arg2)) {
	if ($arg1 =~ /^(\d*)$/) {
	    $lanid = $1;
	}
	else {
	    return undef;
	}
    }
    elsif (ref($arg1) && ($arg2 =~ /^[-\w]*$/)) {
	# Assumed to be an experiment object.
	$experiment = $arg1;
	$arg1 = $experiment->idx();
    }
    elsif (! (($arg1 =~ /^\d*$/) && ($arg2 =~ /^[-\w]*$/))) {
	return undef;
    }

    #
    # Two args means lookup by exptidx,vname.
    #
    if (defined($arg2)) {
	my $clause = (!defined($linkokay) ? "and link is null" : "");
	my $result =
	    DBQueryWarn("select lanid from lans ".
			"where exptidx='$arg1' and vname='$arg2' $clause");

	return undef
	    if (! $result || !$result->numrows);

	($lanid) = $result->fetchrow_array();
    }

    # Look in cache first
    return $lans{"$lanid"}
        if (exists($lans{"$lanid"}));
    
    my $query_result =
	DBQueryWarn("select * from lans where lanid='$lanid'");

    return undef
	if (!$query_result || !$query_result->numrows);

    my $self         = {};
    $self->{'LAN'}   = $query_result->fetchrow_hashref();
    $self->{"ATTRS"} = {};
    $self->{"EXPT"}  = $experiment;

    return undef
    	if (!Lan->InitOpenflowAttributes($self->{'LAN'}->{'exptidx'}, $self->{'LAN'}->{'vname'}, $lanid));

    #
    # Grab the attributes for this lan now.
    #
    $query_result =
	DBQueryWarn("select * from lan_attributes where lanid='$lanid'");
    return undef
	if (!$query_result);

    while (my $rowref = $query_result->fetchrow_hashref()) {
	my $key = $rowref->{'attrkey'};
	
	$self->{"ATTRS"}->{$key} = $rowref;
    }

    bless($self, $class);
    
    # Add to cache. 
    $lans{"$lanid"} = $self;

    return $self;
}

# accessors
sub field($$)     { return ((! ref($_[0])) ? -1 : $_[0]->{'LAN'}->{$_[1]}); }
sub pid($)	  { return field($_[0], 'pid'); }
sub eid($)	  { return field($_[0], 'eid'); }
sub exptidx($)	  { return field($_[0], 'exptidx'); }
sub lanid($)	  { return field($_[0], 'lanid'); }
sub vname($)	  { return field($_[0], 'vname'); }
sub vidx($)	  { return field($_[0], 'vidx'); }
sub ready($)	  { return field($_[0], 'ready'); }
sub link($)	  { return field($_[0], 'link'); }
sub type($)	  { return field($_[0], 'type'); }
sub locked($)	  { return field($_[0], 'locked'); }

#
# Lookup an internal vlan (in the vlan-holding experiment).
#
sub LookupInternal($$)
{
    my ($class, $vname) = @_;

    require Experiment;
    my $experiment = Experiment->Lookup(VLAN_PID(), VLAN_EID());
    return undef
	if (!defined($experiment));

    return Lan->Lookup($experiment, $vname);
}

#
# Create a new (empty) lan. Ready bit is set to zero. 
#
sub Create($$$;$$$)
{
    my ($class, $experiment, $vname, $type, $id, $link) = @_;

    return undef
	if (ref($class) || !ref($experiment));

    my $pid     = $experiment->pid();
    my $eid     = $experiment->eid();
    my $exptidx = $experiment->idx();
    my $safe_vname = DBQuoteSpecial($vname);
    my $linkid  = (defined($link) ? $link->lanid() : "NULL");
    my $vidx    = 0;

    # Allow for the caller to specify the ID, as when converting from
    # existing vlans table.
    $id = "NULL"
	if (!defined($id));

    # We need the idx from the virt_lan_lans table.
    my $query_result =
	DBQueryWarn("select idx from virt_lan_lans ".
		    "where exptidx=$exptidx and vname='$vname'");
    return undef
	if (!$query_result);
    ($vidx) = $query_result->fetchrow_array()
	if ($query_result->numrows);

    $query_result =
	DBQueryWarn("insert into lans set ".
		    "   lanid=$id, ".
		    "   exptidx='$exptidx', ".
		    "   pid='$pid', eid='$eid', ".
		    "   vname=$safe_vname, ".
		    "   type='$type', ".
		    "   vidx='$vidx', ".
		    "   link=$linkid, ".
		    "   ready=0");
    return undef
	if (!defined($query_result));

    # Need the newly minted ID
    my $lanid = $query_result->insertid();
    my $lan   = Lan->Lookup($lanid);
    	
    print "Created lan: $lan\n"
	if ($debug && $lan);
    return $lan;
}

#
# Destroy a lan and its attributes. 
#
sub Destroy($)
{
    my ($self) = @_;

    return -1
	if (!ref($self));

    my $lanid = $self->lanid();
    my $type  = $self->type();

    #
    # List of members to destroy.
    #
    my @members;
    if ($self->MemberList(\@members) != 0) {
	print STDERR "Destroy: Could not get member list\n";
	return -1;
    }
    foreach my $member (@members) {
	#
	# Delete all members and interfaces and attributes.
	#
	my $memberid = $member->memberid();

	return -1
	    if (!DBQueryWarn("delete from lan_member_attributes ".
			     "where lanid='$lanid' and memberid='$memberid'"));
	return -1
	    if (!DBQueryWarn("delete from ifaces ".
			     "where lanid='$lanid' and ifaceid='$memberid'"));
	return -1
	    if (!DBQueryWarn("delete from lan_members ".
			     "where lanid='$lanid' and memberid='$memberid'"));
    }

    # Must delete attributes after above vlan removal but before lan removal.
    return -1
	if (!DBQueryWarn("delete from lan_attributes ".
			 "where lanid='$lanid'"));

    return -1
	if (!DBQueryWarn("delete from lans ".
			 "where lanid='$lanid'"));

    # From the cache. 
    delete($lans{"$lanid"});
    
    return 0;
}

#
# Class method to destroy all lans for an experiment.
# XXX Purge flag is for protogeni tunnels.
#
sub DestroyExperimentLans($$$)
{
    my ($class, $experiment, $purge) = @_;

    return -1
	if (! ref($experiment));

    my $exptidx = $experiment->idx();

    my $query_result =
	DBQueryWarn("select lanid from lans where exptidx='$exptidx'");
    return -1
	if (! $query_result);

    while (my ($lanid) = $query_result->fetchrow_array()) {
	my $lan = Lan->Lookup($lanid);
	return -1
	    if (!$lan);
	
	if (!$purge && $lan->type() eq "tunnel") {
	    #
	    # XXX Terrible hack; Skip protogeni tunnels unless purging.
	    #
	    my $protogeni_tunnel;
	    next 
		if ($lan->GetAttribute("protogeni_tunnel",
				       \$protogeni_tunnel) == 0);
	}
	$lan->Destroy() == 0 or return -1;
    }
    return 0;
}

#
# Class method to backup all lans for an experiment.
#
sub BackupExperimentLans($$$)
{
    my ($class, $experiment, $pstatedir) = @_;
    my @lanids = ();

    return -1
	if (! ref($experiment));

    my $exptidx = $experiment->idx();

    my $query_result =
	DBQueryWarn("select lanid from lans where exptidx='$exptidx'");
    return -1
	if (! $query_result);
    return 0
	if (! $query_result->numrows);

    while (my ($lanid) = $query_result->fetchrow_array()) {
	push(@lanids, $lanid);
    }
    foreach my $table ("lans", "lan_attributes", "lan_members",
		       "lan_member_attributes", "ifaces") {
	# This ordering is for wrapper/mapper regression testing. 
	my $orderby = "";
	if (exists($LanTables{$table}) &&
	    defined($LanTables{$table})) {
	    $orderby = "order by " . join(",", @{$LanTables{$table}});
	}
	DBQueryWarn("select * from $table where ".
		      join(" or ", map("lanid='$_'", @lanids)) . " " .
		    "$orderby into outfile '$pstatedir/$table'")
	    or return -1;
    }
    
    return 0;
}

#
# Class method to restore all lans for an experiment.
#
sub RestoreExperimentLans($$$)
{
    my ($class, $experiment, $pstatedir) = @_;

    return -1
	if (! ref($experiment));

    foreach my $table ("lans", "lan_attributes", "lan_members",
		       "lan_member_attributes", "ifaces") {
	if (-e "$pstatedir/$table") {
	    DBQueryWarn("load data infile '$pstatedir/$table' ".
			"into table $table")
		or return -1;
	}
    }
    return 0;
}

#
# Compare current vlans with pre-modify vlans to see which ones changed.
# These are the ones we will delete from the switches. The ones that do not
# change can be left alone. In the common case, this should save on the
# amount of vlan churning we do for swapmod.
#
# We return two lists of vlan ids; ones that have changed and need to be
# deleted, and the rest.
#
sub CompareVlansWithSwitches($$$)
{
    my ($class, $experiment, $pdiff, $psame) = @_;

    my $exptidx = $experiment->idx();
    my @changed = ();
    my @same    = ();

    #
    # Grab the existing vlans from the vlans table (managed by snmpit).
    #
    my $query_result =
	DBQueryWarn("select id,`virtual`,members,tag from vlans ".
		    "where exptidx='$exptidx'");
    return -1
	if (!$query_result);
    
    while (my ($oldid,$vname,$oldmembers,$tag) =
	   $query_result->fetchrow_array()) {

	my $vlan = VLan->Lookup($experiment, $vname);
	if (!defined($vlan) || $vlan->type ne "vlan") {
	    print STDERR "$vname is not a vlan!\n"
		if (defined($vlan));
	    push(@changed, $oldid);
	    next;
	}
	my $newid = $vlan->lanid();

	#print STDERR "$newid, $vlan\n";

	#
	# Compare the members list.
	#
	my @oldportlist = split(/\s/, $oldmembers);
	my @newportlist;
	if ($vlan->PortList(\@newportlist) != 0) {
	    print STDERR "Could not get portlist for $vlan\n";
	    return -1;
	}
	#print "$oldmembers\n";
	#print join(" ", @newportlist) . "\n";
	if (scalar(@oldportlist) != scalar(@newportlist)) {
	    push(@changed, $oldid);
	    next;
	}
	my $diff = 0;
	foreach my $port (@oldportlist) {
	    if (! grep {$_ eq $port} @newportlist) {
		$diff++;
	    }
	}
	if ($diff) {
	    push(@changed, $oldid);
	    next;
	}
	push(@same, $oldid);

	#
	# Change the new lan (and its partner entries) to have the old id
	# number, so that it matches what is on the switch, as told by
	# the vlans table. 
	#
	# This is bad; if one of these updates fails, we are screwed.
	#
	foreach my $table ("lans", "lan_attributes", "lan_members",
			   "lan_member_attributes", "ifaces",
			   "reserved_vlantags") {
	    DBQueryWarn("update $table set lanid=$oldid ".
			"where lanid='$newid'")
		or return -1;
	}
    }
    @$pdiff = @changed;
    @$psame = @same;
    return 0;
}

#
# New version to coexist with syncVlansFromTables() in snmpit. Adding or
# subtracting ports to an existing vlan is not considered a change now,
# since syncVlansFromTables() can deal with that. The point of this function
# then is to compare the vlan names and update the lanids of the newly
# created lans.
# 
#
sub CompareVlansWithSwitches2($$)
{
    my ($class, $experiment) = @_;

    my $exptidx = $experiment->idx();

    #
    # Grab the existing vlans from the vlans table (managed by snmpit).
    #
    my $query_result =
	DBQueryWarn("select id,`virtual`,members,tag from vlans ".
		    "where exptidx='$exptidx'");
    return -1
	if (!$query_result);
    
    while (my ($oldid,$vname,$oldmembers,$tag) =
	   $query_result->fetchrow_array()) {

	my $vlan = VLan->Lookup($experiment, $vname);
	if (!defined($vlan) ||
	    ($vlan->type ne "vlan" && $vlan->type ne "wire")) {
	    #
	    # The vlan was deleted.
	    #
	    print STDERR "$vname is not a vlan!\n"
		if (defined($vlan));
	    next;
	}
	#
	# Old vlan exists by the same name in the new set. We can just
	# change the port membership on the switches.
	#
	my $newid = $vlan->lanid();

	#
	# Change the new lan (and its partner entries) to have the old id
	# number, so that it matches what is on the switch, as told by
	# the vlans table. 
	#
	# This is bad; if one of these updates fails, we are screwed.
	#
	foreach my $table ("lans", "lan_attributes", "lan_members",
			   "lan_member_attributes", "ifaces",
			   "reserved_vlantags") {
	    DBQueryWarn("update $table set lanid=$oldid ".
			"where lanid='$newid'")
		or return -1;
	}
	# From the cache. 
	delete($lans{"$newid"});
	delete($lans{"$oldid"});
    
	# XXX we should not use this slot anymore.
	$vlan = VLan->Lookup($oldid);
	$vlan->SetAttribute("vlantag", $tag);	
    }
    return 0;
}

#
# Class method to see if an experiment has any active trunks. If it does,
# do not optimize vlan setup/teardown (see above function) when doing a
# swapmod. Too difficult to deal with right now; the problem is that the
# trunked interface is potentially a shared resource for multiple vlans,
# and the bookkeeping does not support dealing with it.
#
sub GotTrunks($$)
{
    my ($class, $experiment) = @_;
    my $exptidx = $experiment->idx();

    my $query_result =
	DBQueryWarn("select distinct r.node_id,i.iface from reserved as r " .
		    "left join interfaces as i on i.node_id=r.node_id " .
		    "where r.exptidx='$exptidx' and i.trunk!=0");

    return $query_result->numrows;
}

#
# Get the set of lans that are linked to this lan. Optionally provide the
# type, say to look for just vlans.
#
sub GetLinkedTo($$;$)
{
    my ($class, $lan, $type) = @_;

    if (! ref($lan)) {
	$lan = Lan->Lookup($lan);
	return ()
	    if (!defined($lan));
    }
    my $exptidx = $lan->exptidx();
    my $lanid   = $lan->lanid();
    my @result  = ();

    my $query_result =
	DBQueryWarn("select lanid from lans ".
		    "where link='$lanid' ".
		    (defined($type) ? "and type='$type'" : ""));
    return ()
	if (!$query_result || !$query_result->numrows);

    while (my ($id) = $query_result->fetchrow_array()) {
	my $vlan = Lan->Lookup($id);
	return undef
	    if (!defined($vlan));
	push(@result, $vlan);
    }
    return @result;
}

#
# Stringify for output.
#
sub Stringify($)
{
    my ($self) = @_;
    
    my $pid   = $self->pid();
    my $eid   = $self->eid();
    my $vname = $self->vname();
    my $id    = $self->lanid();

    return "[Lan ${id}: $pid/$eid/$vname]";
}

#
# Refresh a class instance by reloading from the DB.
#
sub Refresh($)
{
    my ($self) = @_;

    return -1
	if (! ref($self));

    my $lanid = $self->lanid();

    # Delete from the cache to force lookup.
    delete($lans{"$lanid"});

    my $newref = Lan->Lookup($lanid);
    return -1
	if (!defined($newref));

    $self->{'LAN'}   = $newref->{'LAN'};
    $self->{"ATTRS"} = $newref->{'ATTRS'};

    # Add back to cache. 
    $lans{"$lanid"} = $self;

    return 0;
}

#
# Get value of an attribute.
#
sub GetAttribute($$$;$)
{
    my ($self, $key, $pvalue, $ptype) = @_;

    return -1
	if (!exists($self->{'ATTRS'}->{$key}));

    $$pvalue = $self->{'ATTRS'}->{$key}->{'attrvalue'};
    $$ptype  = $self->{'ATTRS'}->{$key}->{'attrtype'}
        if (defined($ptype));
    
    return 0;
}

#
# Set value of an attribute.
#
sub SetAttribute($$$;$)
{
    my ($self, $key, $value, $type) = @_;

    return -1
	if (!ref($self));

    $type = "string"
	if (!defined($type));

    return -1
	if ($type ne "string" && $type ne "integer" &&
	    $type ne "float"  && $type ne "boolean");

    my $lanid = $self->lanid();
    my $safe_key = DBQuoteSpecial($key);
    my $safe_val = DBQuoteSpecial($value);

    return -1
	if (!DBQueryWarn("replace into lan_attributes set ".
			 "  lanid='$lanid', ".
			 "  attrkey=$safe_key, ".
			 "  attrvalue=$safe_val, ".
			 "  attrtype='$type'"));

    $self->{'ATTRS'}->{$key}->{'attrkey'}   = $key;
    $self->{'ATTRS'}->{$key}->{'attrvalue'} = $value;
    $self->{'ATTRS'}->{$key}->{'attrtype'}  = $type;
    
    return 0;
}

#
# Delete an attribute.
#
sub DelAttribute($$)
{
    my ($self, $key) = @_;

    return -1
	if (!ref($self));

    if (exists($self->{'ATTRS'}->{$key})) {
	delete($self->{'ATTRS'}->{$key});
    }
    my $lanid    = $self->lanid();
    my $safe_key = DBQuoteSpecial($key);

    return -1
	if (!DBQueryWarn("delete from lan_attributes ".
			 "where lanid='$lanid' and attrkey=$safe_key"));

    return 0;
}

#
# Shorthand
#
sub SetRole($$)
{
    my ($self, $role) = @_;

    return -1
	if (!ref($self));

    return $self->SetAttribute("role", $role);
}
sub GetRole($;$)
{
    my ($self, $prole) = @_;
    my $role;

    return -1
	if ($self->GetAttribute("role", \$role) != 0);

    if (defined($prole)) {
	$$prole = $role;
	return 0;
    }
    return $role;
}

#
# Get the experiment object for a lan.
#
sub GetExperiment($)
{
    my ($self) = @_;
    require Experiment;

    return -1
	if (!ref($self));

    return $self->{"EXPT"}
        if (defined($self->{"EXPT"}));

    $self->{"EXPT"} = Experiment->Lookup($self->exptidx());
    return $self->{"EXPT"};
}

#
# Get the linked lan as a lan object.
#
sub GetLinkedLan($)
{
    my ($self) = @_;

    return -1
	if (!ref($self));

    return Lan->Lookup($self->link());
}

#
# Add an Interface to a Lan. This interface always corresponds to a virtual
# interface on link or lan.
#
sub AddInterface($$$$;$$)
{
    my ($self, $node, $vnode, $vport, $iface, $member) = @_;

    if (!ref($node)) {
	$node = Node->Lookup($node);
	return undef
	    if (!defined($node));
    }
    my $interface = Lan::Interface->Create($self, $node,
					   $vnode, $vport, $member);
    return undef
	if (!defined($interface));

    #print "fee $interface\n";

    #
    # Set the attribute for the physical interface.
    # If a member was provided, then the physical interface
    # is already set. Do not overwrite it.
    #
    if (!defined($member)) {
	if (defined($iface) &&
	    $interface->SetAttribute("iface", $iface) != 0) {
	    $interface->Destroy();
	    return undef;
	}
	# And the node
	if ($interface->SetAttribute("node_id", $node->node_id()) != 0) {
	    $interface->Destroy();
	    return undef;
	}
    }
    return $interface;
}

#
# Add a member to a lan
#
sub AddMember($$;$)
{
    my ($self, $node, $iface) = @_;

    return undef
	if (!ref($self));

    if (!ref($node)) {
	$node = Node->Lookup($node);
	if (!defined($node)) {
	    return undef;
	}
    }

    my $member = Lan::Member->Create($self, $node);

    # And the node attribute. 
    if ($member->SetAttribute("node_id", $node->node_id()) != 0) {
	$member->Destroy();
	return undef;
    }
    # Set the attribute for the physical interface.
    if (defined($iface) &&
	$member->SetAttribute("iface", $iface) != 0) {
	$member->Destroy();
	return undef;
    }
    return $member;
}

#
# Check membership.
#
sub IsMember($$$)
{
    my ($self, $node, $iface) = @_;

    if (!ref($node)) {
	$node = Node->Lookup($node);
	return 0
	    if (!defined($node));
    }
    my $nodeid = $node->node_id();
    my $lanid  = $self->lanid();

    my $query_result =
	DBQueryWarn("select lma1.memberid from lan_member_attributes as lma1 ".
		    "left join lan_member_attributes as lma2 on ".
		    "     lma1.lanid=lma2.lanid and ".
		    "     lma1.memberid=lma2.memberid ".
		    "where lma1.lanid='$lanid' and ".
		    "      ((lma1.attrkey='node_id' and ".
		    "        lma1.attrvalue='$nodeid') and ".
		    "      (lma2.attrkey='iface' and ".
		    "       lma2.attrvalue='$iface'))");

    return 0
	if (!$query_result || $query_result->numrows != 1);

    return 1;
}

#
# Check membership.
#
sub FindMember($$$)
{
    my ($self, $node, $iface) = @_;

    if (!ref($node)) {
	$node = Node->Lookup($node);
	return undef
	    if (!defined($node));
    }
    my $nodeid = $node->node_id();
    my $lanid  = $self->lanid();

    my $query_result =
	DBQueryWarn("select lma1.memberid from lan_member_attributes as lma1 ".
		    "left join lan_member_attributes as lma2 on ".
		    "     lma1.lanid=lma2.lanid and ".
		    "     lma1.memberid=lma2.memberid ".
		    "where lma1.lanid='$lanid' and ".
		    "      ((lma1.attrkey='node_id' and ".
		    "        lma1.attrvalue='$nodeid') and ".
		    "      (lma2.attrkey='iface' and ".
		    "       lma2.attrvalue='$iface'))");

    return undef
	if (!$query_result || $query_result->numrows != 1);
    
    my ($memberid) = $query_result->fetchrow_array();

    return Lan::Member->Lookup($self, $memberid);
}

#
# Find lans by membership.
#
sub FindLansByMember($$$)
{
    my ($class, $node, $iface_id) = @_;
    my @result = ();

    if (!ref($node)) {
	$node = Node->Lookup($node);
	return ()
	    if (!defined($node));
    }
    my $node_id = $node->node_id();

    my $query_result =
	DBQueryWarn("select lma1.lanid from lan_member_attributes as lma1, " .
		    "   lan_member_attributes as lma2 ".
		    "where lma1.lanid = lma2.lanid and ".
		    "      lma1.memberid=lma2.memberid and ".
		    "      lma1.attrkey='node_id' and " .
		    "      lma1.attrvalue='$node_id' and " .
		    "      lma2.attrkey='iface' and " .
		    "      lma2.attrvalue='$iface_id'");
	
    return ()
	if (!$query_result || !$query_result->numrows);

    while (my ($lanid) = $query_result->fetchrow_array()) {
	my $lan = Lan->Lookup($lanid);
	push(@result, $lan)
	    if (defined($lan));
    }
    return @result;
}

#
# Remove a member from a lan.
#
sub DelMember($$)
{
    my ($self, $member) = @_;

    #
    # We do not cache the members, so just delete it.
    #
    return $member->Destroy();
}

#
# Return a list of members for a lan.
#
sub MemberList($$)
{
    my ($self, $plist) = @_;

    return -1
	if (! (ref($self) && ref($plist)));

    my $lanid = $self->lanid();

    my $query_result =
	DBQueryWarn("select memberid from lan_members where lanid='$lanid'");
    return -1
	if (!defined($query_result));

    my @result = ();
    while (my ($memberid) = $query_result->fetchrow_array()) {
	my $member = Lan::Member->Lookup($self, $memberid);
	return -1
	    if (!defined($member));
	push(@result, $member);
    }
    @$plist = @result;
    return 0;
}

#
# List of all experiment lans. This is a class method.
#
sub ExperimentLans($$$)
{
    my ($class, $experiment, $plist) = @_;

    return -1
	if (! (ref($plist) && ref($experiment)));
    my $exptidx = $experiment->idx();

    my $query_result =
	DBQueryWarn("select l.lanid from lans as l ".
		    "where l.exptidx='$exptidx'");
    return -1
	if (!defined($query_result));

    my @result = ();
    while (my ($lanid) = $query_result->fetchrow_array()) {
	my $lan = Lan->Lookup($lanid);
	return -1
	    if (!defined($lan));
	push(@result, $lan);
    }
    @$plist = @result;
    return 0;
}

#
# Find a lan by looking an interface in the member list
#
sub FindLanByInterface($$$)
{
    my ($class, $experiment, $interface) = @_;
    my $exptidx = $experiment->idx();
    my $iface   = $interface->iface();
    my @lans   = ();

    #
    # We do not do this often, so worry about optimizing later.
    #
    return undef
	if (Lan->ExperimentLans($experiment, \@lans) != 0);

    foreach my $lan (@lans) {
	return $lan
	    if ($lan->IsMember($interface->node_id(), $interface->iface()));
    }
    return undef;
}

#
# Initialize from vlans table. Used when converting from old vlans table.
#
# XXX Need to deal with vlan encapsulation ...
#
sub Initialize($)
{
    my ($self)     = @_;
    my %delays     = ();
    my %elabinelab = ();
    my %vinterfaces= ();
    require Experiment;

    # Prevent vlan insertion above.
    $initialize = 1;

    DBQueryFatal("delete from lans");
    DBQueryFatal("delete from lan_attributes");
    DBQueryFatal("delete from lan_members");
    DBQueryFatal("delete from lan_member_attributes");
    DBQueryFatal("delete from ifaces");

    my $query_result =
	DBQueryFatal("select node_id,iface0,iface1,vname from delays");
    while (my ($node_id,$iface0,$iface1,$vname) =
	   $query_result->fetchrow_array()) {
	$delays{"$node_id:$iface0"} = $vname;
	$delays{"$node_id:$iface1"} = $vname;

	print "$node_id:$iface0, $node_id:$iface1\n";
    }

    $query_result =
	DBQueryFatal("select exptidx,outer_id from elabinelab_vlans");
    while (my ($exptidx,$outer_id) = $query_result->fetchrow_array()) {
	$elabinelab{"$outer_id"} = $exptidx;

	print "$exptidx,$outer_id\n";
    }

    # vinterfaces
    $query_result =
	DBQueryFatal("select node_id,iface,vnode_id from vinterfaces ".
		     "where iface is not null and iface!=''");
    while (my ($node_id,$iface,$vnode_id) = $query_result->fetchrow_array()) {
	$vinterfaces{"$node_id:$iface"} = $vnode_id;

	print "veth: $node_id:$iface,$vnode_id\n";
    }

    $query_result =
	DBQueryWarn("select * from vlans");

    while (my $rowref = $query_result->fetchrow_hashref()) {
	my $exptidx    = $rowref->{'exptidx'};
	my $experiment = Experiment->Lookup($exptidx);
	if (!defined($experiment)) {
	    print STDERR "*** Initialize: No such experiment $exptidx\n";
	    return -1;
	}

	my $id      = $rowref->{'id'};
	my $tag     = $rowref->{'tag'};
	my $vname   = $rowref->{'virtual'};
	my $vlan    = VLan->Lookup($id);
	if ($vlan) {
	    print STDERR "*** Initialize: ".
		"Duplicate vlan $vname in $experiment\n";
	    return -1;
	}

	print "VLAN: $vname ($id) $experiment\n";

	# Create a new VLAN.
	$vlan = VLan->Create($experiment, $vname, $id);
	if (!defined($vlan)) {
	    print STDERR "*** Initialize: ".
		"Could not create vlan $vname ($id) in $experiment\n";
	    return -1;
	}
	$vlan->ReserveVlanTag($tag);

	#
	# Split apart the space-separated list of members
	#
	my @members = split /\s+/, $rowref->{'members'};

	#
	# See if this vlan is for a delay link or lan.
	#
	foreach my $member (@members) {
	    if (exists($delays{$member})) {
		if ($vlan->SetRole("delay") != 0) {
		    print STDERR "*** Initialize: ".
			"Could not set role to delay on $vlan\n";
		    return -1;
		}
		foreach my $memb (@members) {
		    my ($nodeid, $iface) = split /:/, $memb;
		    my $node = Node->Lookup($nodeid);
		    if (!$node) {
			print STDERR "*** Initialize: ".
			    "No such node $nodeid in $vlan in $experiment\n";
			return -1;
		    }
		    print "Delay: $memb\n";
	    
		    #
		    # Instead of interfaces, we just add members to the lan
		    # since they do not correspond to interfaces in the
		    # virtual topo.
		    #
		    $vlan->AddMember($node, $iface);
		}
		goto again;
	    }
	}

	#
	# Or for elabinelab.
	#
	if (exists($elabinelab{"$id"})) {
	    if ($vlan->SetRole("elabinelab") != 0) {
		print STDERR "*** Initialize: ".
		    "Could not set role to delay on $vlan\n";
		return -1;
	    }
	    #
	    # Instead of interfaces, we just add members to the lan since
	    # they do not correspond to interfaces in the virtual topo.
	    #
	    foreach my $member (@members) {
		my ($nodeid, $iface) = split /:/, $member;
		my $node = Node->Lookup($nodeid);
		if (!$node) {
		    print STDERR "*** Initialize: ".
			"No such node $nodeid in vlan $vname in $experiment\n";
		    return -1;
		}
		$vlan->AddMember($node, $iface);
	    }
	    next;
	}

	if ($vlan->SetRole("link/lan") != 0) {
	    print STDERR "*** Initialize: ".
		"Could not set role to link/lan on $vlan\n";
	    return -1;
	}
	foreach my $member (@members) {
	    my ($nodeid, $iface) = split /:/, $member;
	    my $node = Node->Lookup($nodeid);
	    if (!$node) {
		print STDERR "*** Initialize: ".
		    "No such node $nodeid in vlan $vname in $experiment\n";
		return -1;
	    }

	    # Look to see if its a multiplexed link (used by veths). If
	    # so do not create Interfaces, but just members.
	    if (exists($vinterfaces{"$nodeid:$iface"})) {
		my $memb = $vlan->AddMember($node, $iface);
		
		if (!defined($memb)) {
		    print STDERR "*** Initialize: ".
			"Cannot insert multiplexed $member into vlan ".
			"$vlan in $experiment\n";
		    return -1;
		}
		next;
	    }

	    # Correlate the interface with the virtual port.
	    my $iresult =
		DBQueryWarn("select vl.vnode,vl.vname,vl.vport,vl.ip ".
			    "  from virt_lans as vl ".
			    "left join interfaces as i on i.IP=vl.ip and ".
			    "     i.node_id='$nodeid' ".
			    "where exptidx='$exptidx' and i.iface='$iface'");
	    return -1
		if (!$iresult);
	    if ($iresult->numrows() != 1) {
		print STDERR "*** Initialize: ".
		    "Bad rows for $member in vlan $vlan\n";
		return -1;
	    }
	    my ($vnode,$check_vname,$vport) = $iresult->fetchrow_array();

	    #print "foo: $node, $vnode, $vname, $vport, $iface\n";

	    my $interface = $vlan->AddInterface($node, $vnode, $vport, $iface);
	    if (!defined($interface)) {
		print STDERR "*** Initialize: ".
		    "Cannot insert $member into vlan $vlan in $experiment\n";
		return -1;
	    }
	}
      again:
    }
    return 0;
}

#
# Look for a shared vlan by token. Just return the row reference.
# Be fancy later if needed.
#
sub LookupSharedVLanByToken($$)
{
    my ($class, $token) = @_;

    my $query_result =
	DBQueryWarn("select * from shared_vlans ".
		    "where token='$token'");
    return undef
	if (!$query_result || !$query_result->numrows);

    return $query_result->fetchrow_hashref();
}

#
# Is this lan shared?
#
sub IsShared($)
{
    my ($self) = @_;
    my $lanid  = $self->lanid();
    
    my $query_result =
	DBQueryWarn("select * from shared_vlans ".
		    "where lanid='$lanid'");
    return undef
	if (!$query_result);

    return $query_result->numrows();
}

#
# Try to lock this lan. Optional timeout in seconds. 
#
sub Lock($;$)
{
    my ($self, $timeout) = @_;
    my $lockmsg = 0;

    # Must be a real reference. 
    return -1
	if (! ref($self));

    my $lanid = $self->lanid();

    if (!defined($timeout)) {
	$timeout = 0;
    }
    elsif ($timeout == 0) {
	$timeout = 999999; 
    }
    while ($timeout >= 0) {
	my $query_result =
	    DBQueryWarn("update lans set locked=now() ".
			"where lanid='$lanid' and locked is null");

	return -1
	    if (!$query_result);

	return 0
	    if ($query_result->numrows);

	$timeout -= 2;
	if (!$lockmsg && $timeout >= 0) {
	    print "$self is locked by another; ".
		"will keep trying for another $timeout seconds\n";
	    $lockmsg++;
	}
	sleep(2);
    }
    return -1;
}

sub Unlock($)
{
    my ($self) = @_;

    # Must be a real reference. 
    return -1
	if (! ref($self));

    my $lanid = $self->lanid();

    my $query_result =
	DBQueryWarn("update lans set locked=NULL where lanid='$lanid'");

    if (! $query_result ||
	$query_result->numrows == 0) {
	return -1;
    }
    return 0;
}

############################################################################
#
# Lan::Member is just a set of attributes in the DB associated with an
# endpoint of a Lan. It may or may not map one-to-one with an Interface
# on an an actual node.
#
package Lan::Member;
use libdb;
use libtestbed;
use English;
use overload ('""' => 'Stringify');

# Cache of instances to avoid regenerating them.
my %members   = ();
BEGIN { use emutil; emutil::AddCache(\%members); }

#
# Lookup and create a class instance to return.
#
sub Lookup($$$)
{
    my ($class, $lan, $memberid) = @_;
    my $lanid = (ref($lan) ? $lan->lanid() : $lan);

    return undef
	if (! ($memberid =~ /^\d*$/));

    # Look in cache first
    return $members{"${lanid}:${memberid}"}
        if (exists($members{"${lanid}:${memberid}"}));
    
    my $query_result =
	DBQueryWarn("select * from lan_members ".
		    "where lanid='$lanid' and memberid='$memberid'");

    return undef
	if (!$query_result || !$query_result->numrows);

    my $self             = {};
    $self->{'LAN'}       = $lan;
    $self->{'MEMBERID'}  = $memberid;
    $self->{"ATTRS"}     = {};

    #
    # Grab the attributes for this member.
    #
    $query_result =
	DBQueryWarn("select * from lan_member_attributes ".
		    "where lanid='$lanid' and memberid='$memberid'");
    return undef
	if (!$query_result);

    while (my $rowref = $query_result->fetchrow_hashref()) {
	my $key = $rowref->{'attrkey'};
	
	$self->{"ATTRS"}->{$key} = $rowref;
    }

    bless($self, $class);
    
    # Add to cache. 
    $members{"${lanid}:${memberid}"} = $self;
    
    return $self;
}

# accessors
sub pid($)	{ return $_[0]->GetLan()->pid(); }
sub eid($)	{ return $_[0]->GetLan()->eid(); }
sub exptidx($)	{ return $_[0]->GetLan()->exptidx(); }
sub lanid($)    { return $_[0]->GetLan()->lanid(); }
sub vname($)	{ return $_[0]->GetLan()->vname(); }
sub GetLan($)   { return $_[0]->{'LAN'}; }
sub memberid($) { return $_[0]->{'MEMBERID'}; }
sub attributes($) { return $_[0]->{'ATTRS'}; }

#
# Stringify for output.
#
sub Stringify($)
{
    my ($self) = @_;
    
    my $pid      = $self->pid();
    my $eid      = $self->eid();
    my $memberid = $self->memberid();
    my $lanid    = $self->lanid();

    return "[Lan::Member ${memberid}, Lan ${lanid}: $pid/$eid]";
}

#
# Create a new Lan::Member object (on a specific lan) and return it.
#
sub Create($$$)
{
    my ($class, $lan, $node) = @_;

    if (!ref($node)) {
	$node = Node->Lookup($node);
	return 0
	    if (!defined($node));
    }
    my $nodeid = $node->node_id(); 
    my $lanid  = $lan->lanid();

    my $query_result = 
	DBQueryWarn("insert into lan_members set ".
		    "  lanid='$lanid', memberid=NULL, node_id='$nodeid'");
    return undef
	if (!$query_result);

    # Need the newly minted memberid.
    my $memberid = $query_result->insertid();

    return Lan::Member->Lookup($lan, $memberid);
}

#
# Destroy a lan member and its attributes.
#
sub Destroy($)
{
    my ($self) = @_;

    return -1
	if (!ref($self));

    my $lanid    = $self->lanid();
    my $memberid = $self->memberid();

    # Must delete attributes first.
    return -1
	if (!DBQueryWarn("delete from lan_member_attributes ".
			 "where lanid='$lanid' and memberid='$memberid'"));
    
    return -1
	if (!DBQueryWarn("delete from lan_members ".
			 "where lanid='$lanid' and memberid='$memberid'"));

    # Delete from cache too.
    delete($members{"${lanid}:${memberid}"});

    return 0;
}

#
# Called directly to remove a member from its lan and then destroy itself.
#
sub Delete($)
{
    my ($self) = @_;

    return -1
	if (!ref($self));

    return $self->GetLan()->DelMember($self);
}

#
# Refresh a class instance by reloading from the DB.
#
sub Refresh($)
{
    my ($self) = @_;

    return -1
	if (! ref($self));

    my $newref = Lan::Member->Lookup($self->lanid(), $self->memberid());
    return -1
	if (!defined($newref));

    $self->{"ATTRS"} = $newref->{'ATTRS'};

    return 0;
}

#
# Get value of an attribute.
#
sub GetAttribute($$$;$)
{
    my ($self, $key, $pvalue, $ptype) = @_;

    return -1
	if (!exists($self->{'ATTRS'}->{$key}));

    $$pvalue = $self->{'ATTRS'}->{$key}->{'attrvalue'};
    $$ptype  = $self->{'ATTRS'}->{$key}->{'attrtype'}
        if (defined($ptype));
    
    return 0;
}

#
# Set value of an attribute.
#
sub SetAttribute($$$;$)
{
    my ($self, $key, $value, $type) = @_;

    return -1
	if (!ref($self));

    $type = "string"
	if (!defined($type));

    return -1
	if ($type ne "string" && $type ne "integer" &&
	    $type ne "float"  && $type ne "boolean");

    my $lanid    = $self->lanid();
    my $memberid = $self->memberid();
    my $safe_key = DBQuoteSpecial($key);
    my $safe_val = DBQuoteSpecial($value);

    return -1
	if (!DBQueryWarn("replace into lan_member_attributes set ".
			 "  lanid='$lanid', ".
			 "  memberid='$memberid', ".
			 "  attrkey=$safe_key, ".
			 "  attrvalue=$safe_val, ".
			 "  attrtype='$type'"));

    $self->{'ATTRS'}->{$key}->{'attrkey'}   = $key;
    $self->{'ATTRS'}->{$key}->{'attrvalue'} = $value;
    $self->{'ATTRS'}->{$key}->{'attrtype'}  = $type;
    
    return 0;
}

#
# Return node and iface for a member. Needed all over the place.
#
sub GetNodeIface($$$)
{
    my ($self, $pnode, $piface) = @_;
    
    return -1
	if (! (ref($self) && ref($pnode) && ref($piface)));

    my $nodeid;
    my $iface;

    return -1
	if ($self->GetAttribute("node_id", \$nodeid) != 0 ||
	    $self->GetAttribute("iface", \$iface) != 0);

    my $node = Node->Lookup($nodeid);
    return -1
	if (!defined($node));

    $$pnode  = $node;
    $$piface = $iface;
    return 0;
}

#
# Get the Interface structure.
#
sub GetInterface($)
{
    my ($self) = @_;
    my $node;
    my $iface;

    require Interface;

    return undef
	if ($self->GetNodeIface(\$node, \$iface));

    return Interface->LookupByIface($node, $iface);
}

############################################################################
#
# Interfaces correspond one-to-one with the virtual ports (vports) of the
# virtual topology, but are really just lan members underneath. The interfaces
# table stores the mapping between them.
#
package Lan::Interface;
use libdb;
use libtestbed;
use English;
use overload ('""' => 'Stringify');

# Cache of instances to avoid regenerating them.
my %interfaces   = ();
BEGIN { use emutil; emutil::AddCache(\%interfaces); }

# accessors
sub field($$)     { return ((! ref($_[0])) ? -1 : $_[0]->{'IFACE'}->{$_[1]}); }
sub pid($)	  { return field($_[0], 'pid'); }
sub eid($)	  { return field($_[0], 'eid'); }
sub exptidx($)	  { return field($_[0], 'exptidx'); }
sub node_id($)	  { return field($_[0], 'node_id'); }
sub ifaceid($)	  { return field($_[0], 'ifaceid'); }
sub vnode($)	  { return field($_[0], 'vnode'); }
sub vname($)	  { return field($_[0], 'vname'); }
sub vport($)	  { return field($_[0], 'vport'); }
sub GetLan($)     { return $_[0]->{'LAN'}; }
sub GetMember($)  { return $_[0]->{'MEMBER'}; }

#
# Lookup and create a class instance to return.
#
sub Lookup($$$;$)
{
    my ($class, $lan, $arg1, $arg2) = @_;
    my $ifaceid;

    return undef
	if (!ref($lan));
    my $lanid = $lan->lanid();

    #
    # A single arg is an ifaceid. Two args is vnode and vport.
    #
    if (!defined($arg2)) {
	if ($arg1 =~ /^(\d*)$/) {
	    $ifaceid = $1;
	}
	else {
	    return undef;
	}
    }
    elsif (! (($arg1 =~ /^[-\w]*$/) && ($arg2 =~ /^[-\w]*$/))) {
	return undef;
    }

    #
    # Two args means lookup by vnode,vport
    #
    if (defined($arg2)) {
	my $result =
	    DBQueryWarn("select ifaceid from ifaces ".
			"where lanid='$lanid' and vnode='$arg1' and ".
			"      vport='$arg2'");

	return undef
	    if (! $result || !$result->numrows);

	($ifaceid) = $result->fetchrow_array();
    }

    # Look in cache first
    return $interfaces{"$lanid:$ifaceid"}
        if (exists($interfaces{"$lanid:$ifaceid"}));
    
    my $query_result =
	DBQueryWarn("select * from ifaces ".
		    "where lanid='$lanid' and ifaceid='$ifaceid'");

    return undef
	if (!$query_result || !$query_result->numrows);

    my $self          = {};
    $self->{'IFACE'}  = $query_result->fetchrow_hashref();
    $self->{'LAN'}    = $lan;
    $self->{'MEMBER'} = Lan::Member->Lookup($lan, $ifaceid);

    return undef
	if (!defined($self->{'MEMBER'}));

    bless($self, $class);
    
    # Add to cache. 
    $interfaces{"$lanid:$ifaceid"} = $self;
    
    return $self;
}

#
# Create a new Interface object and return it
#
sub Create($$$$$;$)
{
    my ($class, $lan, $node, $vnode, $vport, $member) = @_;

    return undef
	if (! ref($lan));

    my $lanid   = $lan->lanid();
    my $vname   = $lan->vname();
    my $pid     = $lan->pid();
    my $eid     = $lan->eid();
    my $exptidx = $lan->exptidx();
    my $node_id = $node->node_id();

    # We need the idx from the virt_lan_lans table.
    my $query_result =
	DBQueryWarn("select idx from virt_lan_lans ".
		    "where exptidx=$exptidx and vname='$vname'");
    return undef
	if (!$query_result || !$query_result->numrows);
    my ($vidx) = $query_result->fetchrow_array();

    # Use supplied member (which provides the ifaceid) or generate a
    # new one.
    if (!defined($member)) {
	$member = Lan::Member->Create($lan, $node);
	return undef
	    if (!defined($member));
    }
    my $ifaceid = $member->memberid();

    return undef
	if (!DBQueryWarn("insert into ifaces set ".
			 "   lanid='$lanid', ".
			 "   ifaceid='$ifaceid', ".
			 "   exptidx='$exptidx', ".
			 "   pid='$pid', ".
			 "   eid='$eid', ".
			 "   node_id='$node_id', ".
			 "   vnode='$vnode', ".
			 "   vname='$vname', ".
			 "   vidx='$vidx', ".
			 "   vport='$vport'"));

    return Lan::Interface->Lookup($lan, $ifaceid);
}

#
# Destroy an interface and the underlying lan_member.
#
sub Destroy($)
{
    my ($self) = @_;

    return -1
	if (!ref($self));

    my $lanid   = $self->lanid();
    my $ifaceid = $self->ifaceid();
    
    # Delete the member first in case of failure.
    return -1
	if ($self->GetMember() && !$self->GetMember()->Destroy());

    $self->{'MEMBER'} = undef;

    return -1
	if (!DBQueryWarn("delete from ifaces ".
			 "where lanid='$lanid' and ifaceid='$ifaceid'"));

    # Remove from cache. 
    delete($interfaces{"$lanid:$ifaceid"});
    
    return 0;
}

#
# Stringify for output.
#
sub Stringify($)
{
    my ($self) = @_;
    
    my $pid     = $self->pid();
    my $eid     = $self->eid();
    my $vnode   = $self->vnode();
    my $vname   = $self->vname();
    my $vport   = $self->vport();
    my $ifaceid = $self->ifaceid();
    my $lanid   = $self->GetLan()->lanid();

    return "[Interface ${ifaceid}, ".
	"Lan ${lanid}: $pid/$eid/$vnode/$vname/$vport]";
}

#
# Refresh a class instance by reloading from the DB.
#
sub Refresh($)
{
    my ($self) = @_;

    return -1
	if (! ref($self));

    my $newref = Interface->Lookup($self->GetLan(), $self->ifaceid());
    return -1
	if (!defined($newref));

    $self->{'IFACE'}  = $newref->{'IFACE'};
    $self->{'MEMBER'} = $newref->{'MEMBER'};

    return 0;
}

#
# Get value of an attribute.
#
sub GetAttribute($$$;$)
{
    my ($self, $key, $pvalue, $ptype) = @_;

    return $self->GetMember()->GetAttribute($key, $pvalue, $ptype);
}

#
# Set value of an attribute.
#
sub SetAttribute($$$;$)
{
    my ($self, $key, $value, $type) = @_;

    return $self->GetMember()->SetAttribute($key, $value, $type);
}

sub memberid($)
{
    my ($self) = @_;

    return $self->GetMember()->memberid();
}

############################################################################
#
# A protolan is for creating a lan without sending it to the DB until
# later. Used from assign_wraper.
#
package ProtoLan;
use libdb;
use libtestbed;
use English;
use Lan;
use overload ('""' => 'Stringify');

# Keep track of protolans to prevent duplicates.
my %protolans = ();

sub Lookup($$$)
{
    my ($class, $experiment, $vname) = @_;
    
    return undef
	if (!ref($experiment));

    my $exptidx = $experiment->idx();

    return undef
	if (! exists($protolans{"$exptidx:$vname"}));
    
    return $protolans{"$exptidx:$vname"};
}

#
# Create a new ProtoLan object and return it. 
#
sub Create($$$$;$)
{
    my ($class, $experiment, $vname, $impotent, $link) = @_;

    return undef
	if (!ref($experiment));

    my $exptidx = $experiment->idx();

    #
    # Make sure no existing lan ...
    #
    if (!$impotent && Lan->Lookup($experiment, $vname)) {
	print STDERR "*** Protolan Create: ".
	    "Duplicate lan $vname in $experiment\n";
	return undef;
    }
    # Or protolan ...
    if (exists($protolans{"$exptidx:$vname"})) {
	print STDERR "*** Protolan Create: ".
	    "Duplicate protolan $vname in $experiment\n";
	return undef;
    }
	
    my $self              = {};
    $self->{"ATTRS"}      = {};
    $self->{"MEMBERS"}    = {};
    $self->{"IFACES"}     = {};
    $self->{"EXPT"}       = $experiment;
    $self->{"VNAME"}      = $vname;
    $self->{"LINK"}       = $link;
    $self->{"TYPE"}       = '';
    $self->{"ROLE"}       = '';
    $self->{"ENCAPSTYLE"} = '';
    $self->{"IDX"}        = undef; # used in regression mode.
    $self->{"INSTANCE"}   = undef;

    bless($self, $class);
    
    # Add to cache. 
    $protolans{"$exptidx:$vname"} = $self;

    return $self;
}
sub vname($)		{ return $_[0]->{"VNAME"}; }
sub link($)		{ return $_[0]->{"LINK"}; }
sub type($)		{ return $_[0]->{"TYPE"}; }
sub role($)		{ return $_[0]->{"ROLE"}; }
sub encapstyle($)	{ return $_[0]->{"ENCAPSTYLE"}; }

#
# Destroy a protolan before it gets instantiated. 
#
sub Destroy($)
{
    my ($self) = @_;

    return -1
	if (!ref($self));

    my $exptidx = $self->{"EXPT"}->idx();
    my $vname   = $self->{"VNAME"};

    # Remove from cache. 
    delete($protolans{"$exptidx:$vname"});
    return 0;
}

#
# Return the list of protolans.
#
sub ProtoLanList($)
{
    my ($class) = @_;

    return values(%protolans);
}

#
# Instantiate into the DB.
#
sub Instantiate($)
{
    my ($self) = @_;

    my $experiment = $self->{'EXPT'};
    my $vname      = $self->{'VNAME'};
    my $type       = $self->{'TYPE'};
    my $idx        = $self->{'IDX'};  # defaults to undef when not regression.
    my $link       = undef;

    # Already created.
    return 0
	if (defined($self->{'INSTANCE'}));

    if (defined($self->{'LINK'})) {
	my $link_protolan = $self->{'LINK'};
	$link = $link_protolan->{'INSTANCE'};
	
	if (!defined($link)) {
	    $link_protolan->Instantiate();
	    $link = $link_protolan->{'INSTANCE'};
	}
    }

    #
    # Check to see if there is an entry in reserved_vlantags table.
    # If so, use that lanid instead of generating a new one. This is
    # mostly for the benefit of ProtoGeni stitching, but is also handy
    # for swapmod so we can reuse existing vlan tags and lanids.
    #
    if (!defined($idx)) {
	my $exptidx = $experiment->idx();

	my $query_result =
	    DBQueryWarn("select lanid from reserved_vlantags ".
			"where exptidx='$exptidx' and vname='$vname'");

	return -1
	    if (!defined($query_result));

	if ($query_result->numrows) {
	    ($idx) = $query_result->fetchrow_array();
	}
    }

    # The new lan has the 'ready' bit set to zero.
    my $lan = Lan->Create($experiment, $vname, $type, $idx, $link);
    return -1
	if (!defined($lan));

    # Insert the attributes.
    foreach my $key (keys(%{ $self->{"ATTRS"} })) {
	my $pattr = $self->{"ATTRS"}->{$key};

	if ($lan->SetAttribute($pattr->{'attrkey'}, $pattr->{'attrvalue'},
			       $pattr->{'attrtype'}) != 0) {
	    $lan->Destroy();
	    return -1;
	}
    }
    #
    # These are always class=Experimental if not specified. Note that
    # we support experimental vlans on the control network via trunk
    # links. Thus the stack and the class can actually be different.
    #
    if (! exists($self->{"ATTRS"}->{'class'})) {
	if ($lan->SetAttribute("class", "Experimental")) {
	    $lan->Destroy();
	    return -1;
	}
    }

    # Members ...
    foreach my $key (sort(keys(%{ $self->{"MEMBERS"} }))) {
	my $protomember = $self->{"MEMBERS"}->{$key};
	my $node        = $protomember->{'node'};
	my $iface       = $protomember->{'iface'};
	my $attributes  = $protomember->{'attrs'};
	my $member      = $lan->AddMember($node, $iface);
	
	if (!defined($member)) {
	    $lan->Destroy();
	    return -1;
	}

	if (defined($attributes)) {
	    foreach my $attrkey (keys(%{$attributes})) {
		my $attrvalue = $attributes->{$attrkey};

		$member->SetAttribute($attrkey, $attrvalue);
	    }
	}
    }

    # Interfaces ...
    foreach my $key (sort(keys(%{ $self->{"IFACES"} }))) {
	my $protomember = $self->{"IFACES"}->{$key};
	my $node        = $protomember->{'node'};
	my $vnode       = $protomember->{'vnode'};
	my $vport       = $protomember->{'vport'};
	my $iface       = $protomember->{'iface'};
	my $pport       = $protomember->{'pport'};
	my $attributes  = $protomember->{'attrs'};
	my $member;

	if (defined($pport)) {
	    $member = $lan->AddMember($node, $pport);
	    
	    if (!defined($member)) {
		$lan->Destroy();
		return -1;
	    }
	}
	my $interface =
	    $lan->AddInterface($node, $vnode, $vport, $iface, $member);
	
	if (!defined($interface)) {
	    $lan->Destroy();
	    return -1;
	}
	if (defined($attributes)) {
	    foreach my $attrkey (keys(%{$attributes})) {
		my $attrvalue = $attributes->{$attrkey};

		$interface->SetAttribute($attrkey, $attrvalue);
	    }
	}
    }
    $self->{'INSTANCE'} = $lan;
    return 0;
}

#
# Instantiate all protolans
#
sub InstantiateAll($$)
{
    my ($class, $regression) = @_;

    if ($regression) {
	#
	# Need to make sure the id numbers will compare exactly. At some
	# point a few years from now, this will fail.
	#
	my $idx = 999990000;
	
	foreach my $protolan (values(%protolans)) {
	    $protolan->{'IDX'} = $idx++;
	}
    }

    foreach my $protolan (values(%protolans)) {
	if ($protolan->Instantiate() != 0) {
	    print STDERR "*** Could not instantiate protolan: " .
		$protolan->Dump() . "\n";
	    return -1;
	}
    }
    %protolans = ();
    return 0;
}

#
# Dump all protolans
#
sub DumpAll($)
{
    my ($class) = @_;

    foreach my $protolan (values(%protolans)) {
	print STDERR $protolan->Dump() . "\n";
    }
    return 0;
}

#
# Stringify for output.
#
sub Stringify($)
{
    my ($self) = @_;

    my $vname      = $self->{'VNAME'};
    my $experiment = $self->{'EXPT'};

    return "[Protolan: $vname, $experiment]";
}

#
# Display for debug.
#
sub Dump($)
{
    my ($self) = @_;

    my $vname  = $self->{'VNAME'};
    my $type   = (defined($self->{'TYPE'}) ? "type:" . $self->{'TYPE'} : "");
    my $link   = (defined($self->{'LINK'}) ?
		  "(" . $self->{'LINK'}->vname() . ") " : "");
    my $string = "ProtoLan: $vname $type,$link";

    foreach my $key (sort(keys(%{ $self->{"ATTRS"} }))) {
	my $pattr = $self->{"ATTRS"}->{$key};
	my $val   = $pattr->{'attrvalue'};

	$string .= "$key:$val,";
    }
    $string .= ", ";

    foreach my $key (sort(keys(%{ $self->{"MEMBERS"} }))) {
	my $member = $self->{"MEMBERS"}->{$key};
	my $nodeid = $member->{'node'}->node_id();
	my $iface  = $member->{'iface'};

	$string .= "$nodeid:$iface, ";
    }

    foreach my $key (sort(keys(%{ $self->{"IFACES"} }))) {
	my $interface = $self->{"IFACES"}->{$key};
	my $nodeid = $interface->{'node'}->node_id();
	my $vnode  = $interface->{'vnode'};
	my $vport  = $interface->{'vport'};
	my $iface  = $interface->{'iface'};
	my $pport  = $interface->{'pport'};

	$string .= "$vnode:$vport:$nodeid:$iface";
	$string .= ":$pport"
	    if (defined($pport));
	$string .= ", ";
    }
    return $string;
}

#
# Add an interface to a protolan.
#
sub AddInterface($$$$$;$$)
{
    my ($self, $node, $vnode, $vport, $iface, $pport, $attributes) = @_;

    if (!ref($node)) {
	$node = Node->Lookup($node);
	return -1
	    if (!defined($node));
    }

    if (exists($self->{'IFACES'}->{"$vnode:$vport"})) {
	print STDERR "*** Protolan AddInterface: ".
	    "Duplicate $vport ($iface) on $node ($self)\n";
	return -1;
    }

    $self->{'IFACES'}->{"$vnode:$vport"} = { "node"  => $node,
					     "vnode" => $vnode,
					     "vport" => $vport,
					     "iface" => $iface,
					     "pport" => $pport,
					     "attrs" => $attributes,
					    };
    return 0;
}

#
# Add a member to a vlan, as for delay node links and tagged vlans.
#
sub AddMember($$$;$)
{
    my ($self, $node, $iface, $attributes) = @_;

    if (!ref($node)) {
	$node = Node->Lookup($node);
	return -1
	    if (!defined($node));
    }
    my $nodeid = $node->node_id();

    if (exists($self->{'MEMBERS'}->{"$nodeid:$iface"})) {
	print STDERR "*** Protolan AddMember: ".
	    "Duplicate $iface on $node\n";
	return -1;
    }
    
    $self->{'MEMBERS'}->{"$nodeid:$iface"} = { "node"  => $node,
					       "iface" => $iface,
					       "attrs" => $attributes,
					     };
    return 0;
}

#
# Does member already exists in protolan.
#
sub IsMember($$$)
{
    my ($self, $node, $iface) = @_;

    if (!ref($node)) {
	$node = Node->Lookup($node);
	return 0
	    if (!defined($node));
    }
    my $nodeid = $node->node_id();

    return exists($self->{'MEMBERS'}->{"$nodeid:$iface"});
}

#
# Return the memberlist.
#
sub MemberList($)
{
    my ($self) = @_;

    return keys(%{ $self->{'MEMBERS'} });
}

#
# Return member node.
#
sub MemberNode($$)
{
    my ($self, $member) = @_;
    
    return undef
	if (! exists($self->{'MEMBERS'}->{$member}));

    return $self->{'MEMBERS'}->{$member}->{'node'};
}

#
# Return the ifacelist
#
sub IfaceList($)
{
    my ($self) = @_;

    return keys(%{ $self->{'IFACES'} });
}

#
# Return member node.
#
sub IfaceNode($$)
{
    my ($self, $member) = @_;
    
    return undef
	if (! exists($self->{'IFACES'}->{$member}));

    return $self->{'IFACES'}->{$member}->{'node'};
}

#
# Set value of an attribute for a member;
#
sub SetAttribute($$$;$)
{
    my ($self, $key, $value, $type) = @_;

    $type = "string"
	if (!defined($type));

    $self->{"ATTRS"}->{$key} = {"attrkey"   => $key,
				"attrvalue" => $value,
				"attrtype"  => $type };

    return 0;
}
sub GetAttribute($$)
{
    my ($self, $key) = @_;

    return undef
	if (!exists($self->{"ATTRS"}->{$key}));

    return $self->{"ATTRS"}->{$key}->{"attrvalue"};
}
sub SetRole($$)
{
    my ($self, $role) = @_;

    $self->{"ROLE"} = $role;
    
    return $self->SetAttribute("role", $role);
}
sub SetEncapStyle($$)
{
    my ($self, $style) = @_;

    $self->{"ENCAPSTYLE"} = $style;
    
    return $self->SetAttribute("encapstyle", $style);
}
sub SetType($$)
{
    my ($self, $type) = @_;

    $self->{"TYPE"} = $type;
    return 0;
}
sub SetLink($$)
{
    my ($self, $link) = @_;

    $self->{"LINK"} = $link;
    return 0;
}

############################################################################
#
# The most common kind of Lan is a Vlan, so lets create a package/object
# for it.
#
package VLan;
use libdb;
use libtestbed;
use English;
use Lan;
use Interface;
use overload ('""' => 'Stringify');

my $SNMPIT = "$TB/bin/snmpit";

# Cache of instances to avoid regenerating them.
my %vlans   = ();
BEGIN { use emutil; emutil::AddCache(\%vlans); }

#
# Lookup and create a class instance to return.
#
sub Lookup($$;$)
{
    my ($class, $arg1, $arg2) = @_;
    my $lan;

    #
    # Lan->Lookup() does not do exactly what I want in two arg case.
    #
    if (!defined($arg2)) {
	$lan = Lan->Lookup($arg1);
    }
    elsif (!ref($arg1)) {
	# Two args means lookup by $experiment,$vname
	#print STDERR "VLan->Lookup(): Bad first argument: $arg1\n";
	return undef;
    }
    elsif (! ($arg2 =~ /^[-\w\/]*$/)) {
	#print STDERR "VLan->Lookup(): Bad second argument: $arg2\n";
	return undef;
    }
    else {
	my $exptidx = $arg1->idx();
	my $result = 
	    DBQueryWarn("select lanid from lans ".
			"where exptidx='$exptidx' and vname='$arg2' and ".
			"      type='vlan'");
	return undef
	    if (!defined($result) || !$result->numrows);
	my ($lanid) = $result->fetchrow_array();
	$lan = Lan->Lookup($lanid);
    }
    return undef
	if (!defined($lan));

    my $lanid = $lan->lanid();

    # Look in cache first
    return $vlans{"$lanid"}
        if (exists($vlans{"$lanid"}));

    my $self        = {};
    $self->{'LAN'}  = $lan;

    bless($self, $class);
    
    # Add to cache. 
    $vlans{"$lanid"} = $self;
    
    return $self;
}

# accessors
sub pid($)	{ return $_[0]->GetLan()->pid(); }
sub eid($)	{ return $_[0]->GetLan()->eid(); }
sub exptidx($)	{ return $_[0]->GetLan()->exptidx(); }
sub lanid($)    { return $_[0]->GetLan()->lanid(); }
sub id($)       { return $_[0]->GetLan()->lanid(); }
sub vname($)	{ return $_[0]->GetLan()->vname(); }
sub ready($)	{ return $_[0]->GetLan()->ready(); }
sub type($)	{ return $_[0]->GetLan()->type(); }
sub link($)	{ return $_[0]->GetLan()->link(); }
sub GetLan($)   { return $_[0]->{'LAN'}; }
sub GetExperiment($) { return $_[0]->GetLan()->GetExperiment(); }
sub vlanid($)   { return $_[0]->lanid(); }

#
# Lookup a vlan in the internal holding experiment.
#
#
# Lookup an internal vlan (in the vlan-holding experiment).
#
sub LookupInternal($$)
{
    my ($class, $vname) = @_;

    require Experiment;
    my $experiment = Experiment->Lookup(VLAN_PID(), VLAN_EID());
    return undef
	if (!defined($experiment));

    my $lan = Lan->Lookup($experiment, $vname);
    return undef
	if (!defined($lan));

    return VLan->Lookup($lan->lanid());
}

#
# Create a new VLan object and return it. No members yet ... which means
# it has to be locked so that snmpit does not try to do anything with it.
# For now lets use a 'ready' bit unless it becomes annoying.
#
sub Create($$$;$)
{
    my ($class, $experiment, $vname, $id) = @_;

    # The new lan has the 'ready' bit set to zero.
    my $lan = Lan->Create($experiment, $vname, "vlan", $id);
    return undef
	if (!defined($lan));

    my $vlan = VLan->Lookup($lan->lanid());
    return undef
	if (!defined($vlan));

    $vlan->SetClass("Experimental") == 0
	or return undef;

    return $vlan;
}

#
# Destroy.
#
sub Destroy($)
{
    my ($self) = @_;

    return $self->GetLan()->Destroy();
}

#
# Equality
#
sub SameVlan($$)
{
    my ($self, $other) = @_;

    return $self->id() == $other->id();
}

#
# Refresh underyling object.
#
sub Refresh($)
{
    my ($self) = @_;

    return $self->GetLan()->Refresh();
}

#
# Stringify for output.
#
#
# Stringify for output.
#
sub Stringify($)
{
    my ($self) = @_;
    
    my $pid   = $self->pid();
    my $eid   = $self->eid();
    my $vname = $self->vname();
    my $id    = $self->lanid();
    my $tag   = $self->GetTag();
    $tag = (defined($tag) ? ":${tag}" : "");

    return "[VLan ${id}${tag}: $pid/$eid/$vname]";
}

#
# Add an interface to a vlan. Hand this off to Lan->AddInterface().
# Local lans/links map to vlans directly. 
#
sub AddInterface($$$$$)
{
    my ($self, $node, $vnode, $vport, $iface) = @_;
    
    return $self->GetLan()->AddInterface($node, $vnode, $vport, $iface);
}

#
# Add a member to a vlan, as for delay node links and tagged vlans.
#
sub AddMember($;$$)
{
    my ($self, $node, $iface) = @_;
    
    return $self->GetLan()->AddMember($node, $iface);
}

#
# Remove a member from a vlan.
#
sub DelMember($$)
{
    my ($self, $member) = @_;
    
    return $self->GetLan()->DelMember($member);
}

#
# Find a member
#
sub FindMember($$$)
{
    my ($self, $node, $iface) = @_;
    
    return $self->GetLan()->FindMember($node, $iface);
}

#
# Use Port class
#
sub AddPort($$)
{
    my ($self, $port) = @_;

    my $member = $self->FindMember($port->node_id(), $port->iface());
    return $member
	if (defined($member));
				   
    return $self->GetLan()->AddMember($port->node_id(), $port->iface());
}

#
# Delete a member, use Port class
#
sub DelPort($$)
{
    my ($self, $port) = @_;
    my $member = $self->FindMember($port->node_id(), $port->iface());
    return 0
	if (!defined($member));
				   
    return $self->DelMember($member);
}


#
# Does member already exists in protolan.
#
sub IsMember($$$)
{
    my ($self, $node, $iface) = @_;

    return $self->GetLan()->IsMember($node, $iface);
}

#
# Return a list of interfaces for a vlan.
#
sub InterfaceList($$)
{
    my ($self, $plist) = @_;

    return -1
	if (! (ref($self) && ref($plist)));

    my $lanid = $self->lanid();

    my $query_result =
	DBQueryWarn("select ifaceid from ifaces where lanid='$lanid'");
    return -1
	if (!defined($query_result));

    my @result = ();
    while (my ($ifaceid) = $query_result->fetchrow_array()) {
	my $interface = Lan::Interface->Lookup($self->GetLan(), $ifaceid);
	return -1
	    if (!defined($interface));
	push(@result, $interface);
    }
    @$plist = @result;
    return 0;
}

#
# Return a list of members for a vlan.
#
sub MemberList($$)
{
    my ($self, $plist) = @_;

    return $self->GetLan()->MemberList($plist);
}

sub PortList($$)
{
    my ($self, $pref) = @_;
    my @members;
    my @ports  = ();

    return -1
	if ($self->MemberList(\@members) != 0);

    foreach my $member (@members) {
	my $nodeid;
	my $iface;
	my $trivial;

	return -1
	    if ($member->GetAttribute("node_id", \$nodeid) != 0 ||
		$member->GetAttribute("iface", \$iface) != 0);

	#
	# A lan that is a mix of real ports and trivial ports, is type vlan
	# (so it gets built on the switches), but will include those
	# trivial ports in the member list, but they need to be ignored
	# when operating on it as a vlan. libvtop sets this attribute when
	# it happens, and we watch for it here, pruning out those trivial
	# interfaces. A better way might be to remove them completely in
	# libvtop, but thats a bigger change with more side effects.
	#
	next
	    if ($member->GetAttribute("trivial", \$trivial) == 0);
	
	push(@ports, "$nodeid:$iface");
    }
    @$pref = @ports;
    return 0;
}

#
# Get value of an attribute.
#
sub GetAttribute($$$;$)
{
    my ($self, $key, $pvalue, $ptype) = @_;

    return $self->GetLan()->GetAttribute($key, $pvalue, $ptype);
}

#
# Set value of an attribute.
#
sub SetAttribute($$$;$)
{
    my ($self, $key, $value, $type) = @_;

    return $self->GetLan()->SetAttribute($key, $value, $type);
}
sub SetRole($$)
{
    my ($self, $role) = @_;

    return $self->GetLan()->SetRole($role);
}
sub GetRole($;$)
{
    my ($self, $prole) = @_;
    my $role;

    return -1
	if ($self->GetAttribute("role", \$role) != 0);

    if (defined($prole)) {
	$$prole = $role;
	return 0;
    }
    return $role;
}
sub GetTag($$)
{
    my ($self, $ptag) = @_;
    my $lanid = $self->lanid();

    #
    # Go to vlans table for this, since that ensures that things are
    # consistent.
    #
    my $query_result =
	DBQueryWarn("select tag from vlans where id='$lanid'");

    return -1
	if (! (defined($query_result) || $query_result->numrows));
    
    my ($tag) = $query_result->fetchrow_array();

    if (defined($ptag)) {
	$$ptag = $tag;
	return 0;
    }
    return $tag;
	
}
sub SetClass($$)
{
    my ($self, $class) = @_;

    return $self->GetLan()->SetAttribute("class", $class);
}
sub GetClassNoDefault($) {
    my ($self) = @_;
    my $class;

    return $class
	if ($self->GetAttribute("class", \$class) == 0);
    return undef;
}
sub GetClass($)
{
    my ($self) = @_;
    my $class = $self->GetClassNoDefault();
    return $class if (defined($class));

    # Assume experimental LAN
    return "Experimental";
}
sub GetSwitchPath($) {
    my ($self) = @_;
    my $path;

    return $path
	if ($self->GetAttribute("switchpath", \$path) == 0);
    return undef;
}
sub SetSwitchPath($$) {
    my ($self, $path) = @_;

    return $self->GetLan()->SetAttribute("switchpath", $path);
}
sub ClrSwitchPath($) {
    my ($self) = @_;

    return $self->GetLan()->DelAttribute("switchpath");
}

# VLan reservation for a specific lan in an experiment.
sub ReserveVlanTag($$;$$)
{
    my ($self, $tag, $checkonly, $force) = @_;
    my $lanid   = $self->lanid();
    my $vname   = $self->vname();
    my $pid     = $self->pid();
    my $eid     = $self->eid();
    my $exptidx = $self->exptidx();
    $checkonly  = 0 if (!defined($checkonly));
    $force      = 0 if (!defined($force));

    DBQueryWarn("lock tables lan_attributes write, lans write, ".
		"            reserved_vlantags write, vlans read, ".
		"            vlantag_history write")
	or return undef;

    #
    # Use global table for all reservations.
    #
    my $query_result =
	DBQueryWarn("select lanid from reserved_vlantags where tag='$tag'");

    goto inuse
	if (!$query_result || $query_result->numrows);

    #
    # But because of swapmod and syncvlansfromtables, must also check
    # the vlans table since that is what is currently on the switches.
    #
    # Skip the vlans check when we want to force consistency.
    #
    if (!$force) {
	$query_result =
	    DBQueryWarn("select id from vlans where tag='$tag'");

	goto inuse
	    if (!$query_result || $query_result->numrows);

	# Just checking ...
	goto isfree
	    if ($checkonly);
    }
    goto inuse
	if (!DBQueryWarn("insert into reserved_vlantags set ".
			 "  lanid='$lanid', tag='$tag', vname='$vname', ".
			 "  pid='$pid', eid='$eid', exptidx='$exptidx', ".
			 "  reserve_time=now()"));
    #
    # Insert a history record.
    #
    DBQueryWarn("insert into vlantag_history set history_id=NULL, ".
		"  lanid='$lanid', tag='$tag', lanname='$vname', ".
		"  exptidx='$exptidx', allocated=UNIX_TIMESTAMP(now())");
  isfree:
    DBQueryWarn("unlock tables");
    return $tag;
 inuse:
    DBQueryWarn("unlock tables");
    return undef;
}

#
# We sometimes need to call this with just a vlanid since the vlan object
# is no longer in the DB.
#
sub ClearReservedVlanTag($;$)
{
    my ($arg, $tag) = @_;
    my $lanid  = (ref($arg) ? $arg->lanid() : $arg);
    my $clause = (defined($tag) ? "and tag='$tag'" : "");

    #
    # Update history record(s), but if not told the tag, have to
    # modify records for all of them. The only time there would be
    # more then one tag in the table, is when doing a block allocate
    # for Protogeni stitching.
    #
    DBQueryWarn("update vlantag_history set released=UNIX_TIMESTAMP(now()) ".
		"where lanid='$lanid' $clause")
	or return -1;

    DBQueryWarn("delete from reserved_vlantags where lanid='$lanid' $clause")
	or return -1;

    return 0;
}

sub DeleteReservedVlanTag($$)
{
    my ($class, $lanid) = @_;

    DBQueryWarn("delete from reserved_vlantags where lanid='$lanid'")
	or return -1;
    return 0;
}

sub GetReservedVlanTags($)
{
    my ($self) = @_;
    my $lanid  = $self->lanid();
    my @result = ();

    my $query_result =
	DBQueryWarn("select tag from reserved_vlantags ".
		    "where lanid='$lanid'");

    return ()
	if (!$query_result || !$query_result->numrows);

    while (my ($tag) = $query_result->fetchrow_array()) {
	push(@result, $tag);
    }
    return @result;
}
# Lots of different ways to call this one. 
sub GetReservedVlanTag($;$)
{
    my ($arg, $linkname) = @_;
    my $clause;

    if (ref($arg) eq "Experiment") {
	my $exptidx = $arg->idx();
	$clause = "exptidx='$exptidx' and vname='$linkname'";
    }
    else {
	my $lanid = $arg->lanid();
	$clause = "lanid='$lanid'";
    }

    my $query_result =
	DBQueryWarn("select tag from reserved_vlantags where $clause");

    return undef
	if (!$query_result || !$query_result->numrows);
    
    my ($tag) = $query_result->fetchrow_array();
    return $tag;
}

sub HasVlanTagReserved($$)
{
    my ($arg, $tag) = @_;
    my $lanid  = (ref($arg) ? $arg->lanid() : $arg);

    my $query_result =
	DBQueryWarn("select tag from reserved_vlantags ".
		    "where lanid='$lanid' and tag='$tag'");

    return 0
	if (!$query_result);

    return $query_result->numrows;
}

sub VlanTagAvailable($$)
{
    my ($class, $tag) = @_;

    my $query_result =
	DBQueryWarn("select tag from reserved_vlantags where tag='$tag'");

    return 0
	if (!$query_result || $query_result->numrows);

    $query_result =
	DBQueryWarn("select id from vlans where tag='$tag'");
    
    return 0
	if (!$query_result || $query_result->numrows);

    return 1;
}

#
# Who has a vlan tag reserved.
#
sub FindVlanByTag($$)
{
    my ($class, $tag) = @_;

    my $query_result =
	DBQueryWarn("select lanid from reserved_vlantags where tag='$tag'");

    return undef
	if (!$query_result);

    if ($query_result->numrows) {
	my ($lanid) = $query_result->fetchrow_array();
	return VLan->Lookup($lanid);
    }
    
    $query_result =
	DBQueryWarn("select id from vlans where tag='$tag'");
    
    return undef
	if (!$query_result || !$query_result->numrows);
    
    my ($lanid) = $query_result->fetchrow_array();
    return VLan->Lookup($lanid);
}

# Gack, make this an object!
sub ReservedVlanArrayByTag($$)
{
    my ($class, $tag) = @_;

    my $query_result =
	DBQueryWarn("select * from reserved_vlantags where tag='$tag'");

    return undef
	if (!$query_result || !$query_result->numrows);

    return $query_result->fetchrow_hashref();
}

# Find out which stack a VLAN resides on
sub GetStack($) {
    my ($self) = @_;

    my $query_result =
	DBQueryWarn("select stack from vlans  ".
		    "where id='" . $self->lanid() . "'");
    if (!$query_result || !$query_result->numrows) {
        warn "VLan::GetStack(): Tried to get stack for " . $self->lanid() .
            ", but missing vlans table entry";
        return undef;
    }
    my ($stack) = $query_result->fetchrow_array();
    if (!$stack) {
        return undef;
    } else {
        return $stack;
    }
}
# Set the stack that the VLAN resides on
sub SetStack($$) {
    my ($self, $stack) = @_;

    my $query_result =
	DBQueryWarn("select stack from vlans  ".
		    "where id='" . $self->lanid() . "'");
    if (!$query_result || !$query_result->numrows) {
        warn "VLan::SetStack(): Tried to set for " . $self->lanid() .
            ", but missing vlans table entry";
        return -1;
    }
    DBQueryWarn("update vlans set stack='$stack' ".
                "where id='" . $self->lanid() . "'") or return -1;
    return 0;
}

#
# Mark/Get the "manually created" (command line) bit on a vlan.
#
sub MarkManual($)
{
    my ($self) = @_;

    return $self->GetLan()->SetAttribute("cmdline_created", "1");
}
sub IsManual($)
{
    my ($self) = @_;
    my $flag;

    return $flag
	if ($self->GetAttribute("cmdline_created", \$flag) == 0);
    return 0;
}

#
# Mark/Get the "internal" bit on a vlan. These are special vlans
# not associated with an experiment.
#
sub MarkInternal($)
{
    my ($self) = @_;

    return $self->GetLan()->SetAttribute("internal", "1");
}
sub IsInternal($)
{
    my ($self) = @_;
    my $flag;

    return $flag
	if ($self->GetAttribute("internal", \$flag) == 0);
    return 0;
}

#
# Mark/Get the "alias" bit on a vlan. These are vlans that are
# an alias of another vlan. This happens cause different switch
# have internal names for the same vlan tag. For example, vlan
# tag 1 is default and DEFAULT_VLAN. But only one can have an
# entry in the reserved_vlantags ans vlans table, since they assume
# that the tag is a unique key (and this is how it should be). 
#
sub SetAlias($$)
{
    my ($self, $vlan) = @_;

    return $self->GetLan()->SetAttribute("alias", $vlan->lanid());
}
sub IsAlias($)
{
    my ($self) = @_;
    my $lanid;

    return $lanid
	if ($self->GetAttribute("alias", \$lanid) == 0);
    return 0;
}
sub GetAliases($)
{
    my ($self) = @_;
    my $lanid  = $self->lanid();
    my @aliases = ();

    my $query_result =
	DBQueryWarn("select lanid from lan_attributes ".
		    "where attrkey='alias' and attrvalue='$lanid'");
    return undef
	if (!$query_result);
    
    while (my ($alias) = $query_result->fetchrow_array()) {
	my $vlan = VLan->Lookup($alias);
	# What happens if its gone?
	push(@aliases, $vlan)
	    if (defined($vlan));
    }
    return @aliases;
}

#
# Check to see if we think the VLAN actually exists on any switches at the
# moment (ie. has a vlans table entry). 
#
sub CreatedOnSwitches() {
    my ($self) = @_;
    my $query_result =
        DBQueryWarn("select * from vlans where id='" . $self->lanid() . "'");
    if (!$query_result || !$query_result->numrows) {
        return 0;
    } else {
        return 1;
    }
}

#
# List of all vlans. This is a class method.
#
sub AllVLans($$)
{
    my ($class, $plist) = @_;

    return -1
	if (! ref($plist));

    my $query_result =
	DBQueryWarn("select l.lanid from lans as l ".
		    "where l.type='vlan'");
    return -1
	if (!defined($query_result));

    my @result = ();
    while (my ($lanid) = $query_result->fetchrow_array()) {
	my $vlan = VLan->Lookup($lanid);
	return -1
	    if (!defined($vlan));
	push(@result, $vlan);
    }
    @$plist = @result;
    return 0;
}

#
# List of all experiment vlans. This is a class method.
#
sub ExperimentVLans($$$)
{
    my ($class, $experiment, $plist) = @_;

    return -1
	if (! (ref($plist) && ref($experiment)));
    my $exptidx = $experiment->idx();

    my $query_result =
	DBQueryWarn("select l.lanid from lans as l ".
		    "left join lan_attributes as la on ".
		    "  la.lanid=l.lanid and la.attrkey='class' ".
		    "where (l.type='vlan' or l.type='wire') ".
                    " and l.exptidx='$exptidx' and ".
		    "      (la.attrvalue='Experimental' or ".
		    "       la.attrvalue is null)");
    return -1
	if (!defined($query_result));

    my @result = ();
    while (my ($lanid) = $query_result->fetchrow_array()) {
	my $vlan = VLan->Lookup($lanid);
	return -1
	    if (!defined($vlan));
	push(@result, $vlan);
    }
    @$plist = @result;
    return 0;
}

#
# Find a vlan by looking an interface in the vlan.
#
sub FindVlanByInterface($$$)
{
    my ($class, $experiment, $interface) = @_;
    my $exptidx = $experiment->idx();
    my $iface   = $interface->iface();
    my @vlans   = ();

    #
    # We do not do this often, so worry about optimizing later.
    #
    return undef
	if (VLan->ExperimentVLans($experiment, \@vlans) != 0);

    foreach my $vlan (@vlans) {
	return $vlan
	    if ($vlan->IsMember($interface->node_id(), $interface->iface()));
    }
    return undef;
}

#
# Utility function to add a vlan to the switch infrastructure. 
#
sub Instantiate($;$)
{
    my ($self, $quiet) = @_;

    return -1
	if (! ref($self));
    $quiet = 0
	if (!defined($quiet));

    my $experiment = $self->GetExperiment();
    return -1
	if (!defined($experiment));

    my $pid    = $experiment->pid();
    my $eid    = $experiment->eid();
    my $vname  = $self->vname();
    my $lanid  = $self->lanid();
    my $opt    = ($quiet ? "-q" : "");
    my $class  = $self->GetClass();

    #print "Setting up VLAN $vname ($lanid) in $pid/$eid\n";
    system("$SNMPIT $opt -t $pid $eid $lanid");
    return -1
	if ($?);
    return 0;
}

sub GetVlanSwitchPath($)
{
    my ($self) = @_;
    my $lanid  = $self->lanid();

    my $query_result =
        DBQueryWarn("select switchpath from vlans where id='$lanid'");
    return undef
	if (!$query_result || !$query_result->numrows);

    my ($path) = $query_result->fetchrow_array();
    return $path;
}

sub SetVlanSwitchPath($$)
{
    my ($self, $path) = @_;
    my $lanid = $self->lanid();
    my $set   = defined($path) ? "switchpath='$path'" : "switchpath=null";

    DBQueryWarn("update vlans set $set ".
		"where id='$lanid'")
	or return -1;

    return 0;
}

#
# Some vlans are not kept sync with the DB; too difficult. Might
# reexamine this later. For sure, keeping the default vlan and the
# control vlan in sync would be really hard since these tend to
# get mucked with on the switch console instead of through snmpit.
#
sub KeepInSync($)
{
    my ($self) = @_;
    my $tag    = $self->GetReservedVlanTag();

    return 0
	if ($self->IsInternal() && $tag <= 10);

    return 1;
}

#
# Utility function to remove a vlan from the switch infrastructure.
#
sub UnInstantiate($;$)
{
    my ($self, $quiet) = @_;

    return -1
	if (! ref($self));
    $quiet = 0
	if (!defined($quiet));

    my $experiment = $self->GetExperiment();
    return -1
	if (!defined($experiment));

    my $pid    = $experiment->pid();
    my $eid    = $experiment->eid();
    my $vname  = $self->vname();
    my $lanid  = $self->lanid();
    my $opt    = ($quiet ? "-q" : "");

    #print "Removing VLAN $vname ($lanid) from $pid/$eid\n";
    system("$SNMPIT $opt -r $pid $eid $lanid");
    return -1
	if ($?);
    return 0;
}

#
# Class methods to maintain the backup vlans table, which records what
# is on the switches. 
#
sub RecordVlanInsertion($$$)
{
    my ($class, $vlan, $stack) = @_;

    if (!ref($vlan)) {
	$vlan   = VLan->Lookup($vlan);
    }
    return -1
	if (!defined($vlan));

    my $pid       = $vlan->pid();
    my $eid       = $vlan->eid();
    my $exptidx   = $vlan->exptidx();
    my $lanid     = $vlan->lanid();
    my $vname     = $vlan->vname();
    my $vclass    = $vlan->GetClass();
    my $tag       = $vlan->GetReservedVlanTag();
    if (!defined($tag)) {
	print STDERR "No reserved vlan tag for $vlan!\n";
	return -1;
    }
    my $path      = $vlan->GetSwitchPath();

    my @portlist;
    $vlan->PortList(\@portlist) == 0
	or return -1;

    # Watch for duplicates
    my %portlist = ();
    foreach my $port (@portlist) {
	$portlist{$port} = $port
	    if (!exists($portlist{$port}));
    }
    
    my $members = join(" ", keys(%portlist));

    #
    # Not all vlans have the path set. Only intraswitch vlans do. In
    # addition, internal, manual, elabinelab, etc. do not have a path.
    #
    $path = (defined($path) ? ", switchpath='$path'" : "");

    DBQueryWarn("replace into vlans set ".
		"  id='$lanid', pid='$pid', eid='$eid', exptidx='$exptidx', ".
		"  `virtual`='$vname', members='$members', tag='$tag', ".
		"  stack='$stack', class='$vclass' $path")
	or return -1;

    return 0;
}

sub RecordVLanDeletion($$)
{
    my ($class, $id) = @_;

    DBQueryWarn("delete from vlans where id='$id'")
	or return -1;

    return 0;
}

sub RecordVLanModification($$$$)
{
    my ($class, $vlan, $added, $removed) = @_;
    my %current = ();

    if (!ref($vlan)) {
	$vlan   = VLan->Lookup($vlan);
    }
    return -1
	if (!defined($vlan));
    my $lanid = $vlan->lanid();

    my $query_result =
	DBQueryWarn("select members from vlans where id='$lanid'");
    return -1
	if (!$query_result);
    
    my ($current) = $query_result->fetchrow_array();
    if (defined($current) && $current ne "") {
	%current = map { $_ => $_ } split(/\s+/, $current);
    }
    print "RecordVLanModification: $vlan - @$removed\n";
    print "RecordVLanModification: $vlan - " . join(" ", keys(%current)) . "\n";

    if ($added) {
	foreach my $port (@$added) {
	    $current{$port} = $port
		if (!exists($current{$port}));
	}
    }
    if ($removed) {
	foreach my $port (@$removed) {
	    print "  $port\n";
	    
	    delete($current{$port})
		if (exists($current{$port}));
	}
    }
    my $members = join(" ", keys(%current));

    print "RecordVLanModification (after): $vlan - $members\n";

    DBQueryWarn("update vlans set members='$members' ".
		"where id='$lanid'")
	or return -1;

    return 0;
}

#
# Is a node within a vlan, any vlan. Used for sanity checking nfree.
#
sub IsNodeInAVlan($$)
{
    my ($class, $nodeid) = @_;

    if (ref($nodeid)) {
	$nodeid = $nodeid->node_id();
    }
    my $query_result =
	DBQueryWarn("select id from vlans where members like '%${nodeid}:%'");

    return -1
	if (!$query_result);

    return $query_result->numrows;
}

#
# See if there is a vlans table entry for a tag.
#
sub FindTableEntryByTag($$)
{
    my ($class, $tag) = @_;

    my $query_result =
	DBQueryWarn("select * from vlans where tag='$tag'");

    return undef
	if (!$query_result || !$query_result->numrows);

    return $query_result->fetchrow_hashref();
}
sub FindTableEntryByLanid($$)
{
    my ($class, $lanid) = @_;

    my $query_result =
	DBQueryWarn("select * from vlans where id='$lanid'");

    return undef
	if (!$query_result || !$query_result->numrows);

    return $query_result->fetchrow_hashref();
}

#
# Refactored with Port class
#
sub FindVlanByPort($$$)
{
    my ($class, $experiment, $port) = @_;
    my $clause = "";
    
    my $ifacestr = $port->toIfaceString();
    if (defined($experiment)) {
	my $exptidx = $experiment->idx();
	$clause = "exptidx='$exptidx' and";
    }

    my $query_result =
	DBQueryWarn("select id from vlans  ".
		    "where $clause members like '%${ifacestr}%'");

    return undef
	if (!$query_result || !$query_result->numrows);

    my ($lanid) = $query_result->fetchrow_array();

    return VLan->Lookup($lanid);
}

#
# Return a list of stale vlans for an experiment; vlans in the vlans
# table that need to be removed from the switches. This happens when a
# swapmod fails badly cause we try to optimize swapmod by not tearing
# down vlans until the swapin phase, so as not churn vlans that have not
# changed.
#
sub StaleVlanList($$$)
{
    my ($class, $experiment, $pref) = @_;

    my $pid     = $experiment->pid();
    my $eid     = $experiment->pid();
    my $exptidx = $experiment->idx();
    my @result  = ();

    #
    # We want to find all experiment lans, but we now support experiment
    # vlans on the control stack (using vlan encap). So the stack no longer
    # tells, we need to look at the "class" of the lan.
    #
    my $query_result =
	DBQueryWarn("select id,class from vlans where exptidx=$exptidx");
    return -1
	if (!$query_result);

    while (my ($id,$class) = $query_result->fetchrow_array()) {
	# No class means Experimental; we were not setting this properly
	# for a long time.
	push(@result, $id)
	    if (!defined($class) || $class eq "" || $class eq "Experimental");
    }
    @$pref = @result;
    return 0;
}

#
# Get the set of lans that are linked to this lan. Optionally provide the
# type, say to look for just vlans.
#
sub GetLinkedTo($$;$)
{
    my ($class, $lan, $type) = @_;

    my @result = Lan->GetLinkedTo($lan, $type);
    return @result
	if (!@result);

    # Convert to VLan;
    my @tmp = ();
    foreach my $lan (@result) {
	my $vlan = VLan->Lookup($lan->lanid());
	push(@tmp, $vlan);
    }
    return @tmp;
}

sub Lock($;$)
{
    my ($self, $timeout) = @_;

    return $self->GetLan()->Lock($timeout);
}
sub Unlock($)
{
    my ($self) = @_;

    return $self->GetLan()->Unlock();
}

#
# Is this vlan shared?
#
sub IsShared($)
{
    my ($self) = @_;

    return $self->GetLan()->IsShared();
}

############################################################################
#
# Another convenience package, for tunnels.
#
package Tunnel;
use libdb;
use libtestbed;
use English;
use Lan;
use overload ('""' => 'Stringify');

# Cache of instances to avoid regenerating them.
my %tunnels   = ();
BEGIN { use emutil; emutil::AddCache(\%tunnels); }

#
# Lookup and create a class instance to return.
#
sub Lookup($$;$)
{
    my ($class, $arg1, $arg2) = @_;

    my $lan = Lan->Lookup($arg1, $arg2);
    return undef
	if (!defined($lan));

    my $lanid = $lan->lanid();

    # Look in cache first
    return $tunnels{"$lanid"}
        if (exists($tunnels{"$lanid"}));

    my $self        = {};
    $self->{'LAN'}  = $lan;

    bless($self, $class);
    
    # Add to cache. 
    $tunnels{"$lanid"} = $self;
    
    return $self;
}

# accessors
sub pid($)	{ return $_[0]->GetLan()->pid(); }
sub eid($)	{ return $_[0]->GetLan()->eid(); }
sub exptidx($)	{ return $_[0]->GetLan()->exptidx(); }
sub lanid($)    { return $_[0]->GetLan()->lanid(); }
sub id($)       { return $_[0]->GetLan()->lanid(); }
sub vname($)	{ return $_[0]->GetLan()->vname(); }
sub GetLan($)   { return $_[0]->{'LAN'}; }
sub GetExperiment($) { return $_[0]->{'EXPT'}; }

#
# Create a new Tunnel object and return it. No members yet ... 
#
sub Create($$$$$;$$)
{
    my ($class, $experiment, $vname, $secretkey, $style, $mask, $port) = @_;
    my $exptidx = $experiment->idx();

    # The new lan has the 'ready' bit set to zero.
    my $lan = Lan->Create($experiment, $vname, "tunnel");
    return undef
	if (!defined($lan));

    #
    # We need an index to use for a unit number. Just look to see
    # how many tunnels 
    #
    my $query_result =
	DBQueryWarn("select count(*) from lans ".
		    "where exptidx='$exptidx' and type='tunnel'");
    if (!$query_result || !$query_result->numrows) {
	$lan->Destroy();
	return undef;
    }
    my ($tunnel_number) = $query_result->fetchrow_array();
    if ($lan->SetAttribute("tunnel_number", $tunnel_number) != 0) {
	$lan->Destroy();
	return undef;
    }
    # Set the secret key for the tunnel.
    if ($lan->SetAttribute("secretkey", $secretkey) != 0) {
	$lan->Destroy();
	return undef;
    }
    if ($lan->SetAttribute("style", $style) != 0) {
	$lan->Destroy();
	return undef;
    }
    if (defined($port) &&
	$lan->SetAttribute("serverport", $port) != 0) {
	$lan->Destroy();
	return undef;
    }
    if (defined($mask) &&
	$lan->SetAttribute("ipmask", $mask) != 0) {
	$lan->Destroy();
	return undef;
    }
    return Tunnel->Lookup($lan->lanid());
}

#
# Destroy.
#
sub Destroy($)
{
    my ($self) = @_;

    return $self->GetLan()->Destroy();
}

#
# Refresh underyling object.
#
sub Refresh($)
{
    my ($self) = @_;

    return $self->GetLan()->Refresh();
}

#
# Stringify for output.
#
sub Stringify($)
{
    my ($self) = @_;

    return "T" . $self->GetLan()->Stringify();
}

#
# Add an interface to a tunnel. Hand this off to Lan->AddInterface().
#
sub AddInterface($$$$;$$)
{
    my ($self, $node, $vnode, $vport) = @_;

    if (!ref($node)) {
	$node = Node->Lookup($node);
	return undef
	    if (!defined($node));
    }
    my $member = $self->AddMember($node);
    return undef
	if (!defined($member));
    
    my $interface = $self->GetLan()->AddInterface($node, $vnode,
						  $vport, undef, $member);
    return undef
	if (!defined($interface));

    return $interface;
}

#
# Add a member to a tunnel. The caller needs to a bunch of stuff.
#
sub AddMember($$)
{
    my ($self, $node) = @_;

    if (!ref($node)) {
	$node = Node->Lookup($node);
	return undef
	    if (!defined($node));
    }
    my $member = $self->GetLan()->AddMember($node);
    return undef
	if (!defined($member));

    return $member;
}

#
# Return a list of members for a vlan.
#
sub MemberList($$)
{
    my ($self, $plist) = @_;

    return $self->GetLan()->MemberList($plist);
}

#
# Get value of an attribute.
#
sub GetAttribute($$$;$)
{
    my ($self, $key, $pvalue, $ptype) = @_;

    return $self->GetLan()->GetAttribute($key, $pvalue, $ptype);
}

#
# Set value of an attribute.
#
sub SetAttribute($$$;$)
{
    my ($self, $key, $value, $type) = @_;

    return $self->GetLan()->SetAttribute($key, $value, $type);
}
sub SetRole($$)
{
    my ($self, $role) = @_;

    return $self->GetLan()->SetRole($role);
}

############################################################################
#
# Another convenience package, for external references.
#
package ExternalNetwork;
use libdb;
use libtestbed;
use English;
use Lan;
use overload ('""' => 'Stringify');

#
# Lookup by either the node or the network name. 
#
sub Lookup($$)
{
    my ($class, $arg) = @_;
    require GeniHRN;

    my $query_result;
    if (GeniHRN::IsValid($arg)) {
	# If it is a URN, lookup by external_interface
	$query_result =
	    DBQueryWarn("select * from external_networks ".
			"where external_interface='$arg'");
    } elsif ($arg =~ /^[-\w]*$/) {
	# Otherwise it must be a node or network id
	$query_result =
	    DBQueryWarn("select * from external_networks ".
			"where node_id='$arg' or network_id='$arg'");
    } else {
	return undef;
    }

    return undef
	if (!$query_result || !$query_result->numrows);

    # This would be unusual;
    if ($query_result->numrows > 1) {
	print STDERR "*** Multiple rows in external_networks for $arg\n";
	return undef;
    }
    my $self          = {};
    $self->{'DBROW'}  = $query_result->fetchrow_hashref();
    $self->{'VLANSET'} = {};
    bless($self, $class);
    $self->CalculateVlans();
    
    return $self;
}

# accessors
sub field($$)     { return ((! ref($_[0])) ? -1 : $_[0]->{'DBROW'}->{$_[1]}); }
sub node_id($)	  { return field($_[0], 'node_id'); }
sub node_type($)  { return field($_[0], 'node_type'); }
sub network_id($) { return field($_[0], 'network_id'); }
sub vlans($)      { return field($_[0], 'vlans'); }
sub mode($)       { return field($_[0], 'mode'); }

#
# Stringify for output.
#
sub Stringify($)
{
    my ($self) = @_;

    my $node_id = $self->node_id();
    my $network_id = $self->network_id();

    return "[External Network: $network_id,$node_id]";
}

#
# All external networks.
#
sub LookupAll($$)
{
    my ($class, $pref) = @_;
    my @result  = ();

    my $query_result =
	DBQueryWarn("select network_id from external_networks");
    return -1
	if (!$query_result);

    while (my ($network_id) = $query_result->fetchrow_array()) {
	my $network = ExternalNetwork->Lookup($network_id);
	return -1
	    if (!defined($network));
	push(@result, $network);
    }
    @$pref = @result;
    return 0;
}

#
# Given a vlan tag, is it okay (in the range).
#
sub VlanTagOkay($$)
{
    my ($self, $tag) = @_;
    if (exists($self->{'VLANSET'}->{$tag})) {
	return 1;
    } else {
	return 0;
    }
}

sub VlanToSet($$)
{
    my ($self, $vlanString) = @_;
    my %result = ();
    if ($vlanString =~ /(([0-9]+)(-[0-9]+)?)+/) {
	# vlans is a comma-delimited list
	my @vlans = split(",", $vlanString);
	foreach my $range (@vlans) {
	    # Each range is either a single vlan number or min-max inclusive.
	    my ($min, $max) = split("-", $range);
	    if (! defined($max)) {
		$max = $min;
	    }
	    my $i = $min;
	    for ($i = $min; $i <= $max; $i += 1) {
		$result{$i} = 1;
	    }
	}
    }
    return \%result;
}

sub CalculateVlans($)
{
    my ($self) = @_;
    $self->{'VLANSET'} = $self->VlanToSet($self->vlans());

    # vlans is a comma-delimited list
#    my @vlans = split(",", $self->vlans());
#    foreach my $range (@vlans) {
#	# Each range is either a single vlan number or min-max inclusive.
#	my ($min, $max) = split("-", $range);
#	if (! defined($max)) {
#	    $max = $min;
#	}
#	my $i = $min;
#	for ($i = $min; $i <= $max; $i += 1) {
#	    $self->{'VLANSET'}->{$i} = 1;
#	}
#    }
}

# Return a list of vlans from the VLANSET, but only those which are
# also included in the restrictionString
sub GetRestrictedVlans($$)
{
    my ($self, $restrictionString) = @_;
    $restrictionString =~ s/^\s*//g;
    $restrictionString =~ s/\s*$//g;
    my %result = ();
    if ($restrictionString eq "" || $restrictionString eq "any") {
	%result = %{ $self->{'VLANSET'} };
    } else {
	my %restriction = %{ $self->VlanToSet($restrictionString) };
	foreach my $candidate (keys(%{ $self->{'VLANSET'} })) {
	    if ($restriction{$candidate}) {
		$result{$candidate} = 1;
	    }
	}
    }
    return \%result;
}

# Return the list calculated above.
sub VlanTagList($$)
{
    my ($self, $pref) = @_;
    my @result  = ();

    foreach my $tag (keys(%{ $self->{'VLANSET'} })) {
	push(@result, $tag);
    }
    @$pref = @result;
    return 0;
}

# _Always_ make sure that this 1 is at the end of the file...
1;
