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
package Experiment;

use strict;
use Exporter;
use SelfLoader ();
use vars qw(@ISA @EXPORT $AUTOLOAD);
@ISA    = qw(Exporter SelfLoader);
@EXPORT = qw ( );

use libdb;
use EmulabConstants;
use libtestbed;
use Socket;
use Node;
use emutil;
use Logfile;
use English;
use Data::Dumper;
use File::Basename;
use File::Temp;
use overload ('""' => 'Stringify');
use libtblog_simple;
# In case we need to load snmpit_lib below.
use lib '/users/mshobana/CloudLabonESI/emulab-devel-new/emulab-devel/sample_build/lib/snmpit';

use vars qw($EXPT_PRELOAD $EXPT_START $EXPT_SWAPIN $EXPT_SWAPUPDATE
	    $EXPT_SWAPOUT $EXPT_SWAPMOD %physicalTables @virtualTables
	    $EXPT_FLAGS_NAMESONLY $EXPT_FLAGS_INCLUDEVIRT
	    $EXPT_FLAGS_LOCALONLY $EXPT_FLAGS_FIXRESOURCES
	    $EXPT_GENIFLAGS_EXPT $EXPT_GENIFLAGS_COOKED
	    @nodetable_fields %experiments
	    $EXPT_STARTCLOCK $EXPT_RESOURCESHOSED 
	    @EXPORT_OK
	    $TB $BOSSNODE $CONTROL $TBOPS $PROJROOT $STAMPS $TBBASE  
	    $TEVC $DBCONTROL $RSYNC $MKEXPDIR $TBPRERUN $TBSWAP   
	    $TBREPORT $TBEND $DU $MD5 $OPENSSL $SSHKEYGEN
	    $EXPT_ACCESS_READINFO $EXPT_ACCESS_MODIFY $EXPT_ACCESS_DESTROY
	    $EXPT_ACCESS_UPDATE $EXPT_ACCESS_MIN $EXPT_ACCESS_MAX);
	  
# Configure variables
$TB	     = "/users/mshobana/CloudLabonESI/emulab-devel-new/emulab-devel/sample_build";
$BOSSNODE    = "boss.cloudlab.umass.edu";
$CONTROL     = "ops.cloudlab.umass.edu";
$TBOPS       = "testbed-ops\@ops.cloudlab.umass.edu";
$PROJROOT    = "/proj";
$STAMPS      = 0;
$TBBASE      = "https://www.cloudlab.umass.edu";
$TEVC	     = "$TB/bin/tevc";
$DBCONTROL   = "$TB/sbin/opsdb_control";
$RSYNC	     = "/usr/local/bin/rsync";
$MKEXPDIR    = "$TB/libexec/mkexpdir";
$TBPRERUN    = "$TB/bin/tbprerun";
$TBSWAP      = "$TB/bin/tbswap";
$TBREPORT    = "$TB/bin/tbreport";
$TBEND       = "$TB/bin/tbend";
$DU          = "/usr/bin/du";
$MD5         = "/sbin/md5";
$RSYNC       = "/usr/local/bin/rsync";
$OPENSSL     = "/usr/bin/openssl";
$SSHKEYGEN   = "/usr/bin/ssh-keygen";

# To avoid writting out all the methods.
AUTOLOAD {
    #print STDERR "$AUTOLOAD\n";

    if (!ref($_[0])) {
	$SelfLoader::AUTOLOAD = $AUTOLOAD;
	return SelfLoader::AUTOLOAD(@_);
    }
    my $self  = $_[0];
    my $name  = $AUTOLOAD;
    $name =~ s/.*://;   # strip fully-qualified portion

    # canceled is a special case.
    if ($name eq "canceled") {
	return Canceled($self);
    }
    # Ditto paniced
    elsif ($name eq "paniced") {
	return Paniced($self);
    }
    # A DB row proxy method call.
    elsif (exists($self->{'EXPT'}->{$name})) {
	return $self->{'EXPT'}->{$name};
    }
    elsif (exists($self->{'STATS'}->{$name})) {
	return $self->{'STATS'}->{$name};
    }
    elsif (exists($self->{'RSRC'}->{$name})) {
	return $self->{'RSRC'}->{$name};
    }
    $SelfLoader::AUTOLOAD = $AUTOLOAD;
    my $ref = \&SelfLoader::AUTOLOAD;
    goto &$ref;
}

# Swap Actions
$EXPT_PRELOAD		= TBDB_STATS_PRELOAD();
$EXPT_START		= TBDB_STATS_START();
$EXPT_SWAPIN		= TBDB_STATS_SWAPIN();
$EXPT_SWAPOUT		= TBDB_STATS_SWAPOUT();
$EXPT_SWAPMOD		= TBDB_STATS_SWAPMODIFY();
$EXPT_SWAPUPDATE	= TBDB_STATS_SWAPUPDATE();

# Experiment Access.
$EXPT_ACCESS_READINFO   = TB_EXPT_READINFO();
$EXPT_ACCESS_MODIFY     = TB_EXPT_MODIFY();
$EXPT_ACCESS_DESTROY    = TB_EXPT_DESTROY();
$EXPT_ACCESS_UPDATE     = TB_EXPT_UPDATE();
$EXPT_ACCESS_MIN	= $EXPT_ACCESS_READINFO;
$EXPT_ACCESS_MAX	= $EXPT_ACCESS_UPDATE;

# Other flags.
$EXPT_FLAGS_LOCALONLY    = 0x01;
$EXPT_FLAGS_NAMESONLY    = 0x02;
$EXPT_FLAGS_INCLUDEVIRT  = 0x04;
$EXPT_FLAGS_FIXRESOURCES = 0x10;

$EXPT_GENIFLAGS_EXPT    = 0x01;
$EXPT_GENIFLAGS_COOKED  = 0x02;

# For stats gathering code.
$EXPT_STARTCLOCK        = undef;
$EXPT_RESOURCESHOSED    = 0;

# Why, why, why?
@EXPORT_OK = qw($EXPT_PRELOAD $EXPT_START $EXPT_SWAPUPDATE
		$EXPT_SWAPIN $EXPT_SWAPOUT $EXPT_SWAPMOD
		$EXPT_GENIFLAGS_EXPT $EXPT_GENIFLAGS_COOKED
		%physicalTables  @virtualTables);

#
# List of tables used for experiment removal/backup/restore.
#
@virtualTables  = ("virt_nodes",
		   "virt_lans",
		   "virt_lan_lans",
		   "virt_lan_settings",
		   "virt_lan_member_settings",
		   "virt_trafgens",
		   "virt_agents",
		   "virt_routes",
		   "virt_vtypes",
		   "virt_programs",
		   "virt_node_attributes",
		   "virt_node_disks",
		   "virt_node_desires",
		   "virt_node_startloc",
		   "virt_simnode_attributes",
		   "virt_user_environment",
		   "virt_parameters",
		   "virt_paths",
		   "virt_bridges",
		   # vis_nodes is locked during update in prerender, so we
		   # will get a consistent dataset when we backup.
		   "vis_nodes",
		   "vis_graphs",
		   "nseconfigs",
		   "eventlist",
		   "event_groups",
		   "virt_firewalls",
		   "firewall_rules",
		   "elabinelab_attributes",
		   "virt_tiptunnels",
		   "ipsubnets",
		   "virt_blobs",
		   "virt_client_service_ctl",
		   "virt_client_service_hooks",
		   "virt_client_service_opts",
		   "virt_blockstores",
		   "virt_blockstore_attributes",
		   "virt_address_allocation",
		   "virt_profile_parameters");

%physicalTables = ("delays"     => ["node_id", "vname", "vnode0", "vnode1"],
		   "v2pmap"        => ["node_id", "vname"],
		   "linkdelays"    => ["node_id", "vlan", "vnode"],
		   "traces"        => ["node_id", "idx"],
		   "portmap"       => undef,
		   "bridges"       => ["node_id", "bridx", "iface"],
                   "reserved_addresses" => undef); 

# These are slots in the node table that need to be restored. 
@nodetable_fields = ("def_boot_osid",
		        "def_boot_osid_vers",
			"def_boot_path",
			"def_boot_cmd_line",
			"temp_boot_osid",
			"temp_boot_osid_vers",
			"next_boot_osid",
			"next_boot_osid_vers",
			"next_boot_path",
			"next_boot_cmd_line",
			"pxe_boot_path",
			"bootstatus",
			"ready",
			"rpms",
			"deltas",
			"tarballs",
			"startupcmd",
			"startstatus",
			"failureaction",
			"routertype",
			"op_mode",
			"op_mode_timestamp",
			"allocstate",
			"allocstate_timestamp",
			"next_op_mode",
			"osid",
			"ipport_low",
			"ipport_next",
			"ipport_high",
			"sshdport",
			"rtabid");

# Cache of instances to avoid regenerating them.
%experiments   = ();
BEGIN { use emutil; emutil::AddCache(\%experiments); }

# Little helper and debug function.
sub mysystem($)
{
    my ($command) = @_;

    if (0) {
	my $cwd;
	chomp($cwd = `/bin/pwd`);
	print STDERR "Running '$command' in $cwd\n";
    }
    return system($command);
}

#
# Lookup an experiment and create a class instance to return.
#
sub Lookup($$;$)
{
    my ($class, $arg1, $arg2) = @_;
    my $idx;

    #
    # A single arg is either an index or a "pid,eid" or "pid/eid" string.
    #
    if (!defined($arg2)) {
	if ($arg1 =~ /^(\d*)$/) {
	    $idx = $1;
	}
	elsif ($arg1 =~ /^([-\w]*),([-\w]*)$/ ||
	       $arg1 =~ /^([-\w]*)\/([-\w]*)$/) {
	    $arg1 = $1;
	    $arg2 = $2;
	}
	elsif ($arg1 =~ /^\w+\-\w+\-\w+\-\w+\-\w+$/) {
	    my $result =
		DBQueryWarn("select idx from experiments ".
			    "where eid_uuid='$arg1'");

	    return undef
		if (! $result || !$result->numrows);

	    ($idx) = $result->fetchrow_array();
	}
	else {
	    return undef;
	}
    }
    elsif (! (($arg1 =~ /^[-\w]*$/) && ($arg2 =~ /^[-\w]*$/))) {
	return undef;
    }

    #
    # Two args means lookup by pid,eid instead of exptidx.
    #
    if (defined($arg2)) {
	my $result =
	    DBQueryWarn("select idx from experiments ".
			"where pid='$arg1' and eid='$arg2'");

	return undef
	    if (! $result || !$result->numrows);

	($idx) = $result->fetchrow_array();
    }

    # Look in cache first
    return $experiments{"$idx"}
        if (exists($experiments{"$idx"}));
    
    my $query_result =
	DBQueryWarn("select e.*,i.parent_guid,t.guid from experiments as e ".
		    "left join experiment_templates as t on ".
		    "     t.exptidx=e.idx ".
		    "left join experiment_template_instances as i on ".
		    "     i.exptidx=e.idx ".
		    "where e.idx='$idx'");

    return undef
	if (!$query_result || !$query_result->numrows);

    my $self         = {};
    $self->{'EXPT'}  = $query_result->fetchrow_hashref();
    # An Instance?
    $self->{'ISINSTANCE'} = defined($self->{'EXPT'}->{'parent_guid'});
    # The experiment underlying a template.
    $self->{'ISTEMPLATE'} = defined($self->{'EXPT'}->{'guid'});

    $query_result =
	DBQueryWarn("select * from experiment_stats where exptidx='$idx'");
	
    return undef
	if (!$query_result || !$query_result->numrows);
    
    $self->{'STATS'} = $query_result->fetchrow_hashref();
    
    my $rsrcidx = $self->{'STATS'}->{'rsrcidx'};

    $query_result =
	DBQueryWarn("select * from experiment_resources ".
		    "where idx='$rsrcidx'");
	
    return undef
	if (!$query_result || !$query_result->numrows);
    
    $self->{'RSRC'} = $query_result->fetchrow_hashref();

    # Virt Experiment; load lazy.
    $self->{'VIRTEXPT'} = undef;

    bless($self, $class);
    
    # Add to cache. 
    $experiments{"$idx"} = $self;
    
    return $self;
}

# Break circular reference someplace to avoid exit errors.
sub DESTROY {
    my $self = shift;

    $self->{"EXPT"}     = undef;
    $self->{"STATS"}    = undef;
    $self->{"RSRC"}     = undef;
    $self->{'VIRTEXPT'} = undef;
}

#
# Flush from our little cache, as for the expire daemon.
#
sub Flush($)
{
    my ($self) = @_;

    delete($experiments{$self->idx()});
}
sub FlushAll($)
{
    my ($class) = @_;

    %experiments = ();
}

#
# Stringify for output.
#
sub Stringify($)
{
    my ($self) = @_;
    
    my $pid   = $self->pid();
    my $eid   = $self->eid();

    return "[Experiment: $pid/$eid]";
}
# Keep this above  ... elabinelab is a slot in
# the stats stats record, but was not being updated
sub elabinelab($) { return $_[0]->elab_in_elab(); }

# Convenience function.
sub pideid($)
{
    my ($self) = @_;
    
    my $pid   = $self->pid();
    my $eid   = $self->eid();

    return "$pid/$eid";
}

#
# For canceled, goto to the DB. See AUTOLOAD above.
#
sub Canceled($)
{
    my ($self) = @_;
    
    my $idx = $self->idx();

    my $query_result =
	DBQueryWarn("select canceled from experiments where idx='$idx'");

    if (! $query_result ||
	$query_result->numrows == 0) {
	return 0;
    }
    my ($canceled) = $query_result->fetchrow_array();
    $self->{'EXPT'}->{'canceled'} = $canceled;
    return $canceled;
}
# Ditto the panic flag.
sub Paniced($)
{
    my ($self) = @_;
    my $idx = $self->idx();

    my $query_result =
	DBQueryWarn("select paniced from experiments where idx='$idx'");

    if (! $query_result ||
	$query_result->numrows == 0) {
	return 0;
    }
    my ($paniced) = $query_result->fetchrow_array();
    $self->{'EXPT'}->{'paniced'} = $paniced;
    return $paniced;
}

1;


sub dbrow($$)     { return $_[0]->{'EXPT'}; }
sub locked($)     { return $_[0]->expt_locked(); }
sub description($){ return $_[0]->expt_name(); }
sub creator($)    { return $_[0]->expt_head_uid(); }
sub created($)	  { return $_[0]->expt_created(); }
sub swapper($)	  { return $_[0]->expt_swap_uid(); }

#
# Lookup an experiment given an experiment index.
#
sub LookupByIndex($$)
{
    my ($class, $exptidx) = @_;

    return Experiment->Lookup($exptidx);
}

#
# Equality test. Not strictly necessary in perl, but good form.
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
# All active experiments.
#
sub AllActive($)
{
    my ($class) = @_;
    my @result  = ();
    
    my $query_result =
	DBQueryFatal("select idx from experiments where state='active'");

    while (my ($idx) = $query_result->fetchrow_array()) {
	my $experiment = Experiment->Lookup($idx);

	if (!defined($experiment)) {
	    print STDERR "Experiment::AllActive: No object for $idx!\n";
	}
	push(@result, $experiment);
    }
    return @result;
}

#
# All experiments for a particular user. Class method.
#
sub UserExperimentList($$$)
{
    my ($class, $user, $plist) = @_;
    my @result  = ();
    my $uid_idx = $user->uid_idx();
    
    my $query_result =
	DBQueryWarn("select idx from experiments ".
		    "where creator_idx='$uid_idx' or ".
		    "      (swapper_idx='$uid_idx' and ".
		    "       state!='" . EXPTSTATE_SWAPPED() . "')");
    return -1
	if (! $query_result);

    while (my ($idx) = $query_result->fetchrow_array()) {
	my $experiment = Experiment->Lookup($idx);

	if (!defined($experiment)) {
	    print STDERR "Experiment::UserExperimentList: ".
		"No object for $idx!\n";
	    return -1;
	}
	push(@result, $experiment);
    }
    @$plist = @result;
    return 0;
}

#
# All experiments, Class method.
#
sub AllExperimentList($$)
{
    my ($class, $plist) = @_;
    my @result  = ();
    
    my $query_result =
	DBQueryWarn("select idx from experiments ".
		    "where state!='" . EXPTSTATE_SWAPPED() . "'");
    return -1
	if (! $query_result);

    while (my ($idx) = $query_result->fetchrow_array()) {
	my $experiment = Experiment->Lookup($idx);

	if (!defined($experiment)) {
	    print STDERR "Experiment::AllExperimentList: ".
		"No object for $idx!\n";
	    return -1;
	}
	push(@result, $experiment);
    }
    @$plist = @result;
    return 0;
}

# This is needed a lot.
sub unix_gid($)
{
    my ($self) = @_;

    # Must be a real reference. 
    return -1
	if (! ref($self));

    my $group = $self->GetGroup();
    return -1
	if (!defined($group));

    return $group->unix_gid();
}

#
# LockTables simple locks the given tables, and then refreshes the
# experiment instance (thereby getting the data from the DB after
# the tables are locked).
#
sub LockTables($;$)
{
    my ($self, $spec) = @_;

    # Must be a real reference. 
    return -1
	if (! ref($self));

    $spec  = "experiments write"
	if (!defined($spec));
    $spec .= ", experiment_stats read";
    $spec .= ", experiment_resources read";
    
    DBQueryWarn("lock tables $spec")
	or return -1;
	
    return $self->Refresh();
}
sub UnLockTables($)
{
    my ($self) = @_;

    # Must be a real reference. 
    return -1
	if (! ref($self));

    DBQueryWarn("unlock tables")
	or return -1;
    return 0;
}

#
# Create a new experiment. This installs the new record in the DB,
# and returns an instance. There is some bookkeeping along the way.
#
sub Create($$$$)
{
    my ($class, $group, $eid, $argref) = @_;
    my $exptidx;
    my $uuid;
    my $now = time();

    return undef
	if (ref($class) || !ref($group));

    my $pid     = $group->pid();
    my $gid     = $group->gid();
    my $pid_idx = $group->pid_idx();
    my $gid_idx = $group->gid_idx();

    #
    # The pid/eid has to be unique, so lock the table for the check/insert.
    #
    DBQueryWarn("lock tables experiments write, ".
		"            experiment_stats write, ".
		"            experiment_resources write, ".
		"            emulab_indicies write, ".
		"            testbed_stats read")
	or return undef;

    my $query_result =
	DBQueryWarn("select pid,eid from experiments ".
		    "where eid='$eid' and pid='$pid'");

    if ($query_result->numrows) {
	DBQueryWarn("unlock tables");
	tberror("Experiment $eid in project $pid already exists!");
	return undef;
    }

    #
    # Grab the next highest index to use. We used to use an auto_increment
    # field in the table, but if the DB is ever "dropped" and recreated,
    # it will reuse indicies that are crossed referenced in the other two
    # tables.
    #
    $query_result = 
	DBQueryWarn("select idx from emulab_indicies ".
		    "where name='next_exptidx'");

    if (!$query_result) {
	DBQueryWarn("unlock tables");
	return undef;
    }

    # Seed with a proper value.
    if (! $query_result->num_rows) {
	$query_result =
	    DBQueryWarn("select MAX(exptidx) + 1 from experiment_stats");

	if (!$query_result) {
	    DBQueryWarn("unlock tables");
	    return undef;
	}
	($exptidx) = $query_result->fetchrow_array();

	# First ever experiment!
	$exptidx = 1
	    if (!defined($exptidx));

	if (! DBQueryWarn("insert into emulab_indicies (name, idx) ".
			  "values ('next_exptidx', $exptidx)")) {
	    DBQueryWarn("unlock tables");
	    return undef;
	}

    }
    else {
	($exptidx) = $query_result->fetchrow_array();
    }
    my $nextidx = $exptidx + 1;
    
    if (! DBQueryWarn("update emulab_indicies set idx='$nextidx' ".
		      "where name='next_exptidx'")) {
	DBQueryWarn("unlock tables");
	return undef;
    }

    #
    # Lets be really sure!
    #
    foreach my $table ("experiments", "experiment_stats",
		       "experiment_resources", "testbed_stats") {

	my $slot = (($table eq "experiments") ? "idx" : "exptidx");
	
	$query_result =
	    DBQueryWarn("select * from $table where ${slot}=$exptidx");

	if (! $query_result) {
	    DBQueryWarn("unlock tables");
	    return undef;
	}
	if ($query_result->numrows) {
	    DBQueryWarn("unlock tables");
	    tberror("Experiment index $exptidx exists in $table; ".
		    "this is bad!");
	    return undef;
	}
    }

    # And a UUID (universally unique identifier).
    if (exists($argref->{'eid_uuid'})) {
	$uuid = $argref->{'eid_uuid'};
	delete($argref->{'eid_uuid'});

	if (! ($uuid =~ /^\w+\-\w+\-\w+\-\w+\-\w+$/)) {
	    DBQueryWarn("unlock tables");
	    print "*** WARNING: Bad format in UUID!\n";
	    return undef;
	}
    }
    else {
	$uuid = NewUUID();
	if (!defined($uuid)) {
	    DBQueryWarn("unlock tables");
	    print "*** WARNING: Could not generate a UUID!\n";
	    return undef;
	}
    }

    #
    # Lets be real sure that the UUID is really unique.
    #
    $query_result =
	DBQueryWarn("select pid,eid from experiments ".
		    "where eid_uuid='$uuid'");
    if (! $query_result) {
	DBQueryWarn("unlock tables");
	return undef;
    }
    if ($query_result->numrows) {
	DBQueryWarn("unlock tables");
	tberror("Experiment uuid $uuid already exists; ".
		"this is bad!");
	return undef;
    }

    #
    # Insert the record. This reserves the pid/eid for us. 
    #
    # Some fields special cause of quoting.
    #
    my $description = DBQuoteSpecial($argref->{'expt_name'});
    delete($argref->{'expt_name'});
    my $noswap_reason = DBQuoteSpecial($argref->{'noswap_reason'});
    delete($argref->{'noswap_reason'});
    my $noidleswap_reason = DBQuoteSpecial($argref->{'noidleswap_reason'});
    delete($argref->{'noidleswap_reason'});

    # we override this below
    delete($argref->{'idx'})
	if (exists($argref->{'idx'}));

    my $query = "insert into experiments set ".
	join(",", map("$_='" . $argref->{$_} . "'", keys(%{$argref})));

    # Append the rest
    $query .= ",expt_created=FROM_UNIXTIME('$now')";
    $query .= ",expt_locked=now(),pid='$pid',eid='$eid',eid_uuid='$uuid'";
    $query .= ",pid_idx='$pid_idx',gid='$gid',gid_idx='$gid_idx'";
    $query .= ",expt_name=$description";
    $query .= ",noswap_reason=$noswap_reason";
    $query .= ",noidleswap_reason=$noidleswap_reason";
    $query .= ",idx=$exptidx";

    if (! DBQueryWarn($query)) {
	DBQueryWarn("unlock tables");
	tberror("Error inserting experiment record for $pid/$eid!");	
	return undef;
    }

    my $creator_uid = $argref->{'expt_head_uid'};
    my $creator_idx = $argref->{'creator_idx'};
    my $batchmode   = $argref->{'batchmode'};

    #
    # Create an experiment_resources record for the above record.
    #
    $query_result =
	DBQueryWarn("insert into experiment_resources ".
		    "(tstamp, exptidx, uid_idx) ".
		    "values (FROM_UNIXTIME('$now'), $exptidx, $creator_idx)");

    if (!$query_result) {
	DBQueryWarn("delete from experiments where pid='$pid' and eid='$eid'");
	DBQueryWarn("unlock tables");
	tberror("Error inserting experiment resources record for $pid/$eid!");
	return undef;
    }
    my $rsrcidx     = $query_result->insertid;
    
    #
    # Now create an experiment_stats record to match.
    #
    if (! DBQueryWarn("insert into experiment_stats ".
		      "(eid, pid, creator, creator_idx, gid, created, ".
		      " batch, exptidx, rsrcidx, pid_idx, gid_idx, eid_uuid, ".
		      " last_activity) ".
		      "values('$eid', '$pid', '$creator_uid', '$creator_idx',".
		      "       '$gid', FROM_UNIXTIME('$now'), ".
		      "        $batchmode, $exptidx, $rsrcidx, ".
		      "        $pid_idx, $gid_idx, '$uuid', ".
		      "        FROM_UNIXTIME('$now'))")) {
	DBQueryWarn("delete from experiments where pid='$pid' and eid='$eid'");
	DBQueryWarn("delete from experiment_resources where idx=$rsrcidx");
	DBQueryWarn("unlock tables");
	tberror("Error inserting experiment stats record for $pid/$eid!");
	return undef;
    }

    #
    # Safe to unlock; all tables consistent.
    #
    if (! DBQueryWarn("unlock tables")) {
	DBQueryWarn("delete from experiments where pid='$pid' and eid='$eid'");
	DBQueryWarn("delete from experiment_resources where idx=$rsrcidx");
	DBQueryWarn("delete from experiment_stats where exptidx=$exptidx");
	tberror("Error unlocking tables!");
	return undef
    }

    return Experiment->Lookup($pid, $eid);
}

#
# Delete experiment. Optional purge argument says to remove all trace
# (typically, the stats are kept).
#
sub Delete($;$)
{
    my ($self, $purge) = @_;

    return -1
	if (! ref($self));

    my $pid     = $self->pid();
    my $eid     = $self->eid();
    my $exptidx = $self->idx();
    my $workdir = $self->WorkDir();
    my $userdir = $self->UserDir();

    $purge = 0
	if (!defined($purge));

    $self->UnBindNonLocalUsers();

    #
    # Try to remove experiment directory. We allow for it not being there
    # cause we often run the tb programs directly. We also allow for not
    # having permission, in the case that an admin type is running this,
    # in which case it won't be allowed cause of directory permissions. Thats
    # okay since admin types should rarely end experiments in other projects.
    #
    print "Removing experiment directories ... \n";
    if (defined($userdir) && system("/bin/rm -rf $userdir")) {
	print "*** WARNING: Not able to remove $userdir\n";
	print "             Someone will need to do this by hand.\n";

	# Try to move the directory.
	my $moved = (system("/bin/mv -f $userdir ${userdir}.$$") == 0);

	# NFS errors usually the result. Sometimes its cause there is
	# someone in the directory, so its being held open.
        libtestbed::SENDMAIL($TBOPS,
			     "Experiment::Delete: Could not remove directory",
			     "Could not remove $userdir. ".
			     ($moved ?
			      "Renamed to ${userdir}.$$ ..." : "") . "\n" .
			     "Someone will need to do this by hand.\n");
    }
    if (system("/bin/rm -rf $workdir")) {
	print "*** WARNING: Not able to remove $workdir\n";
	print "             Someone will need to do this by hand.\n";
    }
    # Yuck.
    if ($pid ne $self->gid()) {
	my $eidlink = "$PROJROOT/$pid/exp/$eid";
	unlink($eidlink)
	    if (-l $eidlink);
    }
    my $logfile = $self->GetLogFile();
    if (defined($logfile)) {
	$logfile->Delete();
    }
    libArchive::TBDeleteExperimentArchive($pid, $eid);

    DBQueryWarn("DELETE from experiment_keys ".
		"WHERE eid='$eid' and pid='$pid'");

    DBQueryWarn("DELETE from experiments ".
		"WHERE eid='$eid' and pid='$pid'");

    # Delete from cache. 
    delete($experiments{"$exptidx"});

    #
    # Mark experiment destroyed. This is a backup to End() below.
    #
    if (! defined($self->destroyed())) {
	DBQueryWarn("update experiment_stats set ".
		    "   destroyed=now() ".
		    "where exptidx=$exptidx");
	$self->Refresh();
    }
    return 0
	if (! $purge);
    
    #
    # Now we can clean up the stats and resource records. 
    #
    my $rsrcidx = $self->rsrcidx();

    $self->DeleteInputFiles();

    DBQueryWarn("DELETE from experiment_pmapping ".
		"WHERE rsrcidx=$rsrcidx")
	if (defined($rsrcidx) && $rsrcidx);

    DBQueryWarn("DELETE from experiment_resources ".
		"WHERE idx=$rsrcidx")
	if (defined($rsrcidx) && $rsrcidx);

    DBQueryWarn("DELETE from testbed_stats ".
		"WHERE exptidx=$exptidx");

    # This must be last cause it provides the unique exptidx above.
    DBQueryWarn("DELETE from experiment_stats ".
		"WHERE eid='$eid' and pid='$pid' and exptidx=$exptidx");

    return 0;
}

#
# Add an input file to the template. The point of this is to reduce
# duplication by taking an md5 of the input file, and sharing that
# record/file.
# 
sub AddInputFile($$;$)
{
    my ($self, $inputfile, $isnsfile) = @_;
    my $input_data_idx;
    my $isnew = 0;

    # Must be a real reference. 
    return -1
	if (! ref($self));

    $isnsfile = 0
	if (! defined($isnsfile));

    return -1
	if (! -r $inputfile);

    my $data_string = `cat $inputfile`;
    return -1
	if ($?);

    my $exptidx  = $self->idx();
    my $rsrcidx  = $self->rsrcidx();

    if ($data_string) {
	# As you can see, we md5 the raw data.
	$data_string = DBQuoteSpecial($data_string);
	if (length($data_string) >= DBLIMIT_NSFILESIZE()) {
	    tberror("Input file is too big (> " . DBLIMIT_NSFILESIZE() . ")!");
	    return -1;
	}

	#
	# Grab an MD5 of the file to see if we already have a copy of it.
	# Avoids needless duplication.
	#
	my $md5 = `$MD5 -q $inputfile`;
	chomp($md5);

	DBQueryWarn("lock tables experiment_input_data write, ".
		    "            experiment_inputs write, ".
		    "            experiment_resources write")
	    or return -1;

	my $query_result =
	    DBQueryWarn("select idx from experiment_input_data ".
			"where md5='$md5'");

	if (!$query_result) {
	    DBQueryWarn("unlock tables");
	    return -1;
	}

	if ($query_result->numrows) {
	    ($input_data_idx) = $query_result->fetchrow_array();
	    $isnew = 0;
	}
	else {
	    $query_result =
		DBQueryWarn("insert into experiment_input_data ".
			    "(idx, md5, input) ".
			    "values (NULL, '$md5', $data_string)");
	    
	    if (!$query_result) {
		DBQueryWarn("unlock tables");
		return -1;
	    }
	    $input_data_idx = $query_result->insertid;
	    $isnew = 1;
	}
	if (! DBQueryWarn("insert into experiment_inputs ".
			  " (rsrcidx, exptidx, input_data_idx) values ".
			  " ($rsrcidx, $exptidx, '$input_data_idx')")) {
	    DBQueryWarn("delete from experiment_input_data ".
			"where idx='$input_data_idx'")
		if ($isnew);
	    DBQueryWarn("unlock tables");
	    return -1;
	}
	if ($isnsfile &&
	    $self->TableUpdate("experiment_resources",
			       "input_data_idx='$input_data_idx'",
			       "idx='$rsrcidx'") != 0) {
	    DBQueryWarn("unlock tables");
	    return -1;
	}
	DBQueryWarn("unlock tables");
    }
    return 0;
}

#
# Delete the input files, but only if not in use.
#
sub DeleteInputFiles($)
{
    my ($self) = @_;

    # Must be a real reference. 
    return -1
	if (! ref($self));

    my $rsrcidx = $self->rsrcidx();
    my $nsidx   = $self->input_data_idx();

    DBQueryWarn("lock tables experiment_input_data write, ".
		"            experiment_resources write, ".
		"            experiment_inputs write")
	or return -1;

    #
    # Get all input files for this rsrc record.
    #
    my $query_result =
	DBQueryWarn("select input_data_idx from experiment_inputs ".
		    "where rsrcidx='$rsrcidx'");
    goto bad
	if (! $query_result);
    goto done
	if (! $query_result->numrows);

    while (my ($input_data_idx) = $query_result->fetchrow_array()) {
	#
	# Delete but only if not in use.
	#
	my $query_result =
	    DBQueryWarn("select count(rsrcidx) from experiment_inputs ".
			"where input_data_idx='$input_data_idx' and ".
			"      rsrcidx!='$rsrcidx'");
	goto bad
	    if (! $query_result);

	DBQueryWarn("delete from experiment_inputs ".
		    "where input_data_idx='$input_data_idx'")
	    or goto bad;

	if (defined($nsidx) && $nsidx == $input_data_idx) {
	    DBQueryWarn("update experiment_resources set input_data_idx=NULL ".
			"where idx='$rsrcidx'")
		or goto bad;
	}
	next
	    if ($query_result->numrows);

	DBQueryWarn("delete from experiment_input_data ".
		    "where idx='$input_data_idx'")
	    or goto bad;
    }
  done:
    DBQueryWarn("unlock tables");
    return 0;

  bad:
    DBQueryWarn("unlock tables");
    return 1;
}

#
# Grab an input file.
#
sub GetInputFile($$$)
{
    my ($self, $idx, $pref) = @_;

    # Must be a real reference. 
    return -1
	if (! ref($self));

    my $query_result =
	DBQueryWarn("select input from experiment_input_data ".
		    "where idx='$idx'");
    return -1
	if (! $query_result || !$query_result->numrows);

    my ($nsfile) = $query_result->fetchrow_array();
    $$pref = $nsfile;
    return 0;
}

#
# Get the virt experiment object;
#
sub GetVirtExperiment($)
{
    my ($self) = @_;
    require VirtExperiment;

    return undef
	if (! ref($self));

    return $self->{'VIRTEXPT'}
        if (defined($self->{'VIRTEXPT'}));

    require VirtExperiment;

    my $virtexperiment = VirtExperiment->Lookup($self);
    if (!defined($virtexperiment)) {
	print STDERR "*** Could not get virtual experiment object for $self\n";
	return undef;
    }
    $self->{'VIRTEXPT'} = $virtexperiment;
    return $virtexperiment;
}

#
# Refresh a class instance by reloading from the DB.
#
sub Refresh($)
{
    my ($self) = @_;

    return -1
	if (! ref($self));

    my $idx = $self->idx();

    my $query_result =
	DBQueryWarn("select * from experiments where idx=$idx");

    return -1
	if (!$query_result || !$query_result->numrows);

    $self->{'EXPT'}       = $query_result->fetchrow_hashref();
    $self->{'VIRTEXPT'}   = undef;
    $self->{'ISINSTANCE'} = undef;
    $self->{'ISTEMPLATE'} = undef;

    $query_result =
	DBQueryWarn("select * from experiment_stats where exptidx='$idx'");
	
    return -1
	if (!$query_result || !$query_result->numrows);
    
    $self->{'STATS'} = $query_result->fetchrow_hashref();

    my $rsrcidx = $self->rsrcidx();

    $query_result =
	DBQueryWarn("select * from experiment_resources ".
		    "where idx='$rsrcidx'");
	
    return -1
	if (!$query_result || !$query_result->numrows);
    
    $self->{'RSRC'} = $query_result->fetchrow_hashref();
    return 0;
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

    my $pid = $self->pid();
    my $eid = $self->eid();

    my $query = "update experiments set ".
	join(",", map("$_=" . DBQuoteSpecial($argref->{$_}), keys(%{$argref})));

    $query .= " where pid='$pid' and eid='$eid'";

    return -1
	if (! DBQueryWarn($query));

    return Refresh($self);
}

#
# Worker class method to change experiment info.
# Assumes most argument checking was done elsewhere.
#
sub EditExp($$$$$$)
{
    my ($class, $experiment, $user, $doemail, $argref, $usrerr_ref) = @_;

    my %mods;
    my $noreport;
    my %updates;

    #
    # Converting the batchmode is tricky, but we can let the DB take care
    # of it by requiring that the experiment not be locked, and it be in
    # the swapped state. If the query fails, we know that the experiment
    # was in transition.
    #

    if (exists($argref->{"batchmode"}) && $experiment->batchmode() != $argref->{"batchmode"}) {
	my $success  = 0;

	my $batchmode;
	if ($argref->{"batchmode"} ne "1") {
	    $batchmode = 0;
	    $argref->{"batchmode"} = 0;
	}
	else {
	    $batchmode = 1;
	    $argref->{"batchmode"} = 1;
	}

	if ($experiment->SetBatchMode($batchmode) != 0) {
	    $$usrerr_ref = "Batch Mode: Experiment is running or in transition; ".
		"try again later";
	    return undef;
	}
	$mods{"batchmode"} = $batchmode;
    }

    #
    # Now update the rest of the information in the DB.
    #

    # Name change for experiment description.
    if (exists($argref->{"description"})) {
	$updates{"expt_name"} = ($mods{"description"} = $argref->{"description"});
    }

    # Note that timeouts are in hours in the UI, but in minutes in the DB. 
    if (exists($argref->{"idleswap_timeout"})) {
	$updates{"idleswap_timeout"} = 60 * 
	    ($mods{"idleswap_timeout"} = $argref->{"idleswap_timeout"});
    }
    if (exists($argref->{"autoswap_timeout"})) {
	$updates{"autoswap_timeout"} = 60 * 
	    ($mods{"autoswap_timeout"} = $argref->{"autoswap_timeout"});
    }

    foreach my $col ("idle_ignore", "noswap_reason",
		     "idleswap", "noidleswap_reason", "savedisk",
		     "cpu_usage", "mem_usage", "linktest_level") {
	# Copy args we want so that others can't get through.
	if (exists($argref->{$col})) {
	    $updates{$col} = $mods{$col} = $argref->{$col};
	}
    }

    # Save state before change for the email message below.
    my $olds = ($experiment->swappable() ? "Yes" : "No");
    my $oldsr= $experiment->noswap_reason();
    my $oldi = ($experiment->idleswap() ? "Yes" : "No");
    my $oldit= $experiment->idleswap_timeout() / 60.0;
    my $oldir= $experiment->noidleswap_reason();
    my $olda = ($experiment->autoswap() ? "Yes" : "No");
    my $oldat= $experiment->autoswap_timeout() / 60.0;

    if (keys %updates) {
	if ($experiment->Update(\%updates)) {
	    return undef;
	}
    }
    my $creator = $experiment->creator();
    my $swapper = $experiment->swapper();
    my $uid = $user->uid();
    my $pid = $experiment->pid();
    my $eid = $experiment->eid();

    if (!keys %mods) {
	return 1;
    }
    # Do not send this email if the user is an administrator
    # (adminmode does not matter), and is changing an expt he created
    # or swapped in. Pointless email.
    elsif ( $doemail &&
	     ! ($user->admin() &&
		($uid eq $creator || $uid eq $swapper)) ) {

	# Send an audit e-mail reporting what is being changed.
	my $target_creator = $experiment->GetCreator();
	my $target_swapper = $experiment->GetSwapper();

	my $user_name  = $user->name();
	my $user_email = $user->email();
	my $cname      = $target_creator->name();
	my $cemail     = $target_creator->email();
	my $sname      = $target_swapper->name();
	my $semail     = $target_swapper->email();

	my $s    = ($experiment->swappable() ? "Yes" : "No");
	my $sr   = $experiment->noswap_reason();
	my $i    = ($experiment->idleswap() ? "Yes" : "No");
	my $it   = $experiment->idleswap_timeout() / 60.0;
	my $ir   = $experiment->noidleswap_reason();
	my $a    = ($experiment->autoswap() ? "Yes" : "No");
	my $at   = $experiment->autoswap_timeout() / 60.0;

	my $msg = "\n".
	    "The swap settings for $pid/$eid have changed\n".
	    "\nThe old settings were:\n".
	    "Swappable:\t$olds\t($oldsr)\n".
	    "Idleswap:\t$oldi\t(after $oldit hrs)\t($oldir)\n".
	    "MaxDuration:\t$olda\t(after $oldat hrs)\n".
	    "\nThe new settings are:\n".
	    "Swappable:\t$s\t($sr)\n".
	    "Idleswap:\t$i\t(after $it hrs)\t($ir)\n".
	    "MaxDuration:\t$a\t(after $at hrs)\n".
	    "\nCreator:\t$creator ($cname <$cemail>)\n".
	    "Swapper:\t$swapper ($sname <$semail>)\n".
            "\nDifferences were:\n";
	my @report = 
	    ("Description:description", "Idle Ignore:idle_ignore",
	     "Swappable:swappable", "Noswap Reason:noswap_reason",
	     "Idleswap:idleswap", "Idleswap Timeout:idleswap_timeout",
	     "Noidleswap Reason:noidleswap_reason", "Autoswap:autoswap",
	     "Autoswap timeout:autoswap_timeout", "Savedisk:savedisk",
	     "Cpu Usage:cpu_usage", "Mem Usage:mem_usage",
	     "Batch Mode:batchmode", "Linktest Level:linktest_level");
	foreach my $line (@report) {
	    my ($label, $field) = split /:/, $line;
	    if (exists($mods{$field})) {
		$msg .= sprintf "%-20s%s\n", $label .":", $mods{$field};
	    }
	}
	$msg .= "\n".
	   "\nIf it is necessary to change these settings, ".
	   "please reply to this message \nto notify the user, ".
	   "then change the settings here:\n\n".
	   "$TBBASE/showexp.php3?pid=$pid&eid=$eid\n\n".
	   "Thanks,\nTestbed WWW\n";

	SENDMAIL("$user_name <$user_email>",
		 "$pid/$eid swap settings changed",
		 $msg, TBMAIL_OPS(), sprintf("Bcc: %s\nErrors-To:%s", 
					     TBMAIL_AUDIT(), TBMAIL_WWW()));
    }
    return 1;
}

sub SetBatchMode($$) {
    my ($self, $mode) = @_;

    my $reqstate = EXPTSTATE_SWAPPED();
    my $idx      = $self->idx();
    $mode        = ($mode ? 1 : 0);

    DBQueryFatal("lock tables experiments write");

    my $query_result =
	DBQueryFatal("update experiments set ".
		     "   batchmode=$mode ".
		     "where idx='$idx' and ".
		     "     expt_locked is NULL and state='$reqstate'");

    my $success = $query_result->numrows;    # XXX Was DBAffectedRows().
    DBQueryFatal("unlock tables");

    return ($success ? 0 : -1);
}

#
# We use this for admission control of geni slices and classic
 # experiments that have an autoswap set.
#
sub SetExpiration($$)
{
    my ($self, $expires) = @_;
    my $idx = $self->idx();

    if (!defined($expires)) {
	$expires = "NULL";
    }
    elsif ($expires =~ /^\d+$/) {
	$expires = "FROM_UNIXTIME($expires)";
    }
    else {
	$expires = "'$expires'";
    }
    my $query_result =
	DBQueryWarn("update experiments set expt_expires=$expires " .
		    "where idx='$idx'");
    return -1
	if (!$query_result);

    # Has to be in the correct format.
    $query_result =
	DBQueryWarn("select expt_expires from experiments ".
		    "where idx='$idx'");
    return -1
	if (!$query_result || !$query_result->numrows);
    ($expires) = $query_result->fetchrow_array();
    
    $self->{'EXPT'}->{'expt_expires'} = $expires;
    return 0;
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
    
    my $exptidx = $self->idx();

    if (defined($conditions) && "$conditions" ne "") {
	$conditions = "and ($conditions)";
    }
    else {
	$conditions = "";
    }

    return DBQueryWarn("select distinct $fields from $table ".
		       "where exptidx='$exptidx' $conditions");
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
	$sets = join(",",
		     map("$_=" . DBQuoteSpecial($sets->{$_}), keys(%{$sets})));
    }
    my $exptidx = $self->idx();

    if (defined($conditions) && "$conditions" ne "") {
	$conditions = "and ($conditions)";
    }
    else {
	$conditions = "";
    }

    return 0
	if (DBQueryWarn("update $table set $sets ".
			"where exptidx='$exptidx' $conditions"));
    return -1;
}

#
# Check permissions. Allow for either uid or a user ref until all code
# updated.
#
sub AccessCheck($$$)
{
    my ($self, $user, $access_type) = @_;

    # Must be a real reference. 
    return 0
	if (! ref($self));

    if ($access_type < $EXPT_ACCESS_MIN ||
	$access_type > $EXPT_ACCESS_MAX) {
	die("*** Invalid access type: $access_type!");
    }

    # Admins do whatever they want.
    return 1
	if ($user->IsAdmin());

    my $group = $self->GetGroup();
    return 0
	if (!defined($group));
    my $project = $self->GetProject();
    return 0
	if (!defined($project));

    #
    # An experiment may be destroyed by the experiment creator or the
    # project/group leader.
    #
    my $mintrust;
    
    if ($access_type == $EXPT_ACCESS_READINFO) {
	$mintrust = PROJMEMBERTRUST_USER();
    }
    else {
	$mintrust = PROJMEMBERTRUST_LOCALROOT();
    }

    #
    # Either proper permission in the group, or group_root in the project.
    # This lets group_roots muck with other people's experiments, including
    # those in groups they do not belong to.
    #
    return TBMinTrust($group->Trust($user), $mintrust) ||
	TBMinTrust($project->Trust($user), PROJMEMBERTRUST_GROUPROOT());
}

#
# Create the directory structure. A template_mode experiment is the one
# that is created for the template wrapper, not one created for an
# instance of the experiment. The path changes slightly, although that
# happens down in the mkexpdir script.
#
sub CreateDirectory($)
{
    my ($self) = @_;

    # Must be a real reference. 
    return -1
	if (! ref($self));

    my $idx = $self->idx();

    mysystem("$MKEXPDIR $idx");
    return -1
	if ($?);
    # mkexpdir sets the path in the DB. 
    return Refresh($self)
}

#
# Load the project object for an experiment.
#
sub GetProject($)
{
    my ($self) = @_;
    require Project;

    # Must be a real reference. 
    return undef
	if (! ref($self));

    my $project = Project->Lookup($self->pid_idx());
    
    if (! defined($project)) {
	print("*** WARNING: Could not lookup project object for $self!\n");
	return undef;
    }
    return $project;
}

#
# Load the group object for an experiment.
#
sub GetGroup($)
{
    my ($self) = @_;
    require Group;

    # Must be a real reference. 
    return undef
	if (! ref($self));

    my $group = Group->Lookup($self->gid_idx());
    
    if (! defined($group)) {
	print("*** WARNING: Could not lookup group object for $self!\n");
	return undef;
    }
    return $group;
}

#
# Return the user and work directories. The workdir in on boss and where
# scripts chdir to when they run. The userdir is across NFS on ops, and
# where files are copied to. 
#
sub WorkDir($)
{
    my ($self) = @_;

    # Must be a real reference. 
    return -1
	if (! ref($self));

    my $pid = $self->pid();
    my $eid = $self->eid();

    return TBDB_EXPT_WORKDIR() . "/${pid}/${eid}";
}
sub UserDir($)
{
    my ($self) = @_;

    # Must be a real reference. 
    return -1
	if (! ref($self));

    return $self->path();
}
# Long term storage.
sub InfoDir($)
{
    my ($self) = @_;

    # Must be a real reference. 
    return -1
	if (! ref($self));

    my $pid = $self->pid();
    my $eid = $self->eid();
    my $idx = $self->idx();

    return TBDB_EXPT_INFODIR() . "/$pid/$eid/$idx";
}

# Event/Web key filenames.
sub EventKeyPath($)
{
    my ($self) = @_;

    # Must be a real reference. 
    return -1
	if (! ref($self));

    return UserDir($self) . "/tbdata/eventkey"; 
}
sub WebKeyPath($)
{
    my ($self) = @_;

    # Must be a real reference. 
    return -1
	if (! ref($self));

    return UserDir($self) . "/tbdata/webkey"; 
}

#
# Add an environment variable.
#
sub AddEnvVariable($$$;$)
{
    my ($self, $name, $value, $index) = @_;

    # Must be a real reference. 
    return -1
	if (! ref($self));

    my $pid = $self->pid();
    my $eid = $self->eid();
    my $exptidx = $self->idx();

    if (defined($value)) {
	$value = DBQuoteSpecial($value);
    }
    else {
	$value = "''";
    }

    #
    # Look to see if the variable exists, since a replace will actually
    # create a new row cause there is an auto_increment in the table that
    # is used to maintain order of the variables as specified in the NS file.
    #
    my $query_result =
	DBQueryWarn("select idx from virt_user_environment ".
		    "where name='$name' and pid='$pid' and eid='$eid'");

    return -1
	if (!$query_result);

    if ($query_result->numrows) {
	my $idx = (defined($index) ? $index :
		   ($query_result->fetchrow_array())[0]);
	    
	DBQueryWarn("replace into virt_user_environment set ".
		    "   name='$name', value=$value, idx=$idx, ".
		    "   exptidx='$exptidx', pid='$pid', eid='$eid'")
	    or return -1;
    }
    else {
	DBQueryWarn("insert into virt_user_environment set ".
		    "   name='$name', value=$value, idx=NULL, ".
		    "   exptidx='$exptidx', pid='$pid', eid='$eid'")
	    or return -1;
    }
    
    return 0;
}

#
# Write the environment strings into a little script in the user directory.
#
sub WriteEnvVariables($)
{
    my ($self) = @_;

    # Must be a real reference. 
    return -1
	if (! ref($self));

    my $pid = $self->pid();
    my $eid = $self->eid();

    my $query_result =
	DBQueryWarn("select name,value from virt_user_environment ".
		    "where  pid='$pid' and eid='$eid' order by idx");
    return -1
	if (!defined($query_result));

    my $userdir = $self->UserDir();
    my $envfile = "$userdir/tbdata/environment";

    if (!open(FP, "> $envfile")) {
	print "Could not open $envfile for writing: $!\n";
	return -1;
    }
    while (my ($name,$value) = $query_result->fetchrow_array()) {
	print FP "${name}=\"$value\"\n";
    }
    if (! close(FP)) {
	print "Could not close $envfile: $!\n";
	return -1;
    }
    
    return 0;
}

#
# Get value of a specific env variable
#
sub GetEnvVariable($$)
{
    my ($self, $var) = @_;

    # Must be a real reference. 
    return -1
	if (! ref($self));

    my $pid = $self->pid();
    my $eid = $self->eid();

    my $query_result =
	DBQueryWarn("select value from virt_user_environment ".
		    "where  pid='$pid' and eid='$eid' and name='$var'");
    return undef
	if (!defined($query_result) || !$query_result->numrows);

    my ($value) = $query_result->fetchrow_array();
    return $value;
}

#
# Experiment locking and state changes.
#
sub Unlock($;$)
{
    my ($self, $newstate) = @_;

    # Must be a real reference. 
    return -1
	if (! ref($self));

    my $pid = $self->pid();
    my $eid = $self->eid();
    my $sclause = (defined($newstate) ? ",state='$newstate' " : "");

    my $query_result =
	DBQueryWarn("update experiments set expt_locked=NULL $sclause ".
		    "where eid='$eid' and pid='$pid'");

    if (! $query_result ||
	$query_result->numrows == 0) {
	return -1;
    }
    
    if (defined($newstate)) {
	require event;
	
	$self->{'EXPT'}->{'state'} = $newstate;

	event::EventSendWarn(objtype   => TBDB_TBEVENT_EXPTSTATE(),
			     objname   => "$pid/$eid",
			     eventtype => $newstate,
			     expt      => "$pid/$eid",
			     host      => $BOSSNODE);
    }
    
    return 0;
}

sub Lock(;$$)
{
    my ($self, $newstate, $unlocktables) = @_;

    # Must be a real reference. 
    return -1
	if (! ref($self));

    my $pid = $self->pid();
    my $eid = $self->eid();
    my $sclause = (defined($newstate) ? ",state='$newstate' " : "");

    # flag to indicate tables should be unlocked. 
    $unlocktables = 0
	if (!defined($unlocktables));

    my $query_result =
	DBQueryWarn("update experiments set expt_locked=now() $sclause ".
		    "where eid='$eid' and pid='$pid'");

    if (! $query_result ||
	$query_result->numrows == 0) {
	$self->UnLockTables()
	    if ($unlocktables);
	return -1;
    }

    #
    # We do this before calling out to the event system to avoid livelock
    # in case the event system goes down.
    #
    $self->UnLockTables()
	if ($unlocktables);
    
    if (defined($newstate)) {
	require event;
	
	$self->{'EXPT'}->{'state'} = $newstate;

	event::EventSendWarn(objtype   => TBDB_TBEVENT_EXPTSTATE(),
			     objname   => "$pid/$eid",
			     eventtype => $newstate,
			     expt      => "$pid/$eid",
			     host      => $BOSSNODE);
    }
    return 0;
}

sub SetState($$)
{
    my ($self, $newstate) = @_;

    # Must be a real reference. 
    return -1
	if (! ref($self));

    my $pid = $self->pid();
    my $eid = $self->eid();

    my $query_result =
	DBQueryWarn("update experiments set state='$newstate' ".
		    "where eid='$eid' and pid='$pid'");

    if (! $query_result ||
	$query_result->numrows == 0) {
	return -1;
    }
    
    if (defined($newstate)) {
	require event;
	
	$self->{'EXPT'}->{'state'} = $newstate;

	event::EventSendWarn(objtype   => TBDB_TBEVENT_EXPTSTATE(),
			     objname   => "$pid/$eid",
			     eventtype => $newstate,
			     expt      => "$pid/$eid",
			     host      => $BOSSNODE);
    }
    
    return 0;
}

sub ResetState($$)
{
    my ($self, $newstate) = @_;

    # Must be a real reference. 
    return -1
	if (! ref($self));

    my $pid = $self->pid();
    my $eid = $self->eid();

    DBQueryWarn("update experiments set state='$newstate' ".
		"where eid='$eid' and pid='$pid'")
	or return -1;

    return 0;
}

#
# Logfiles. This all needs to change.
#
# Open a new logfile and return its name.
#
sub CreateLogFile($$)
{
    my ($self, $prefix) = @_;

    # Must be a real reference. 
    return undef
	if (! ref($self));

    my $pid      = $self->pid();
    my $eid      = $self->eid();
    my $gid_idx  = $self->gid_idx();
    my $logdir   = $self->WorkDir();
    my $linkname = "$logdir/${prefix}.log";
    my $logname  = `mktemp $logdir/${prefix}.XXXXXX`;
    return undef
	if ($?);
    
    # Untaint to avoid silly warnings
    if ($logname =~ /^([-\w\.\/]+)$/) {
	$logname = $1;
    }
    else {
	print STDERR "Bad data in filename: $logname\n";
	return undef;
    }

    # Create a Logfile.
    my $logfile = Logfile->Create($gid_idx, $logname);
    if (!defined($logfile)) {
	unlink($logname);
	return undef;
    }
    # This is untainted.
    $logname = $logfile->filename();

    # So tbops people can read the files ...
    if (!chmod(0664, $logname)) {
	print STDERR "Could not chmod $logname to 0644: $!\n";
	$logfile->Delete();
	unlink($logname);
	return undef;
    }

    # Link it to $prefix.log so that the most recent is well known.
    if (-e $linkname) {
	unlink($linkname);
    }
    if (! link($logname, $linkname)) {
	print STDERR "CreateLogFile: Cannot link $logname,$linkname: $!\n";
	$logfile->Delete();
	unlink($logname);
	return undef;
    }
    return $logfile;
}

#
# Set the experiments NS file using AddInputFile() above
#
sub SetNSFile($$)
{
    my ($self, $nsfile) = @_;

    # Must be a real reference. 
    return -1
	if (! ref($self));

    return $self->AddInputFile($nsfile, 1);
}

sub GetNSFile($$)
{
    my ($self, $pref) = @_;

    # Must be a real reference. 
    return -1
	if (! ref($self));

    # In case there is no NS file stored.
    $$pref = undef;

    my $input_data_idx = $self->input_data_idx();
    return 0
	if (!defined($input_data_idx));

    return $self->GetInputFile($input_data_idx, $pref);
}

#
# Set the experiment to use the logfile. It becomes the "current" spew.
#
sub SetLogFile($$;$)
{
    my ($self, $logfile, $oldlogref) = @_;

    # Must be a real reference. 
    return -1
	if (! ref($self) || !ref($logfile));

    if (defined($oldlogref)) {
	$$oldlogref = $self->GetLogFile();
    }
    else  {
	# Kill the old one. Eventually we will save them.
	my $oldlogfile = $self->GetLogFile();
	if (defined($oldlogfile)) {
	    $oldlogfile->Delete();
	}
    }
    return -1
	if (! $self->Update({'logfile' => $logfile->logid()}));

    return 0;
}

#
# Get the experiment logfile.
#
sub GetLogFile($)
{
    my ($self) = @_;

    # Must be a real reference. 
    return undef
	if (! ref($self));

    # Must do this to catch updates to the logfile variables.
    return undef
	if ($self->Refresh());

    return undef
	if (! $self->logfile());

    return Logfile->Lookup($self->logfile());
}

#
# Mark the log as open so that the spew keeps looking for more output.
# 
sub OpenLogFile($)
{
    my ($self) = @_;

    # Must be a real reference. 
    return -1
	if (! ref($self));

    my $logfile = $self->GetLogFile();
    return -1
	if (!defined($logfile));

    return $logfile->Open();
}

#
# And close it ...
#
sub CloseLogFile($)
{
    my ($self) = @_;

    # Must be a real reference. 
    return -1
	if (! ref($self));

    my $logfile = $self->GetLogFile();
    return -1
	if (!defined($logfile));

    return $logfile->Close();
}

#
# And clear it ...
#
sub ClearLogFile($)
{
    my ($self) = @_;

    # Must be a real reference. 
    return -1
	if (! ref($self));

    my $logfile = $self->GetLogFile();
    return -1
	if (!defined($logfile));

    $logfile->Delete() == 0
	or return -1;

    my $exptidx = $self->idx();
    DBQueryWarn("update experiments set logfile=NULL where idx='$exptidx'")
	or return -1;

    return $self->Refresh();
}

#
# Run scripts over an experiment.
#
sub PreRun($;$$)
{
    my ($self, $nsfile, $options) = @_;

    # Must be a real reference. 
    return -1
	if (! ref($self));

    my $pid = $self->pid();
    my $eid = $self->eid();
    my $idx = $self->idx();

    $nsfile = ""
	if (!defined($nsfile));
    $options = ""
	if (!defined($options));

    print "Running 'tbprerun $options -e $idx $nsfile'\n";
    mysystem("$TBPRERUN $options -e $idx $nsfile");
    return -1
	if ($?);
    return 0;
}

#
# Initialiaize bookkeeping for a swap operation.
#
sub PreSwap($$$$)
{
    my ($self, $swapper, $which, $estate) = @_;
    # We know we need this later.
    require User;

    # Must be a real reference. 
    return -1
	if (! ref($self) && ref($swapper));

    my $exptidx  = $self->idx();
    my $rsrcidx  = $self->rsrcidx();
    my $lastrsrc = $rsrcidx;
    my $uid_idx  = $swapper->uid_idx();
    my $isactive = ($estate eq EXPTSTATE_ACTIVE());

    #
    # We should never get here with a lastrsrc in the stats record; it
    # indicates something went wrong.
    #
    if ($self->lastrsrc()) {
	print STDERR "*** Inconsistent lastrsrc in stats record for $self!\n";
	print STDERR "    But we are going to try to fix it ...\n";

	#
	# Do what was not done during the last swap action. 
	#
	if ($self->SwapFail($swapper, $which, -1, $EXPT_FLAGS_FIXRESOURCES)) {
	    #
	    # Otherwise, we set this so that we leave things alone below
	    # when caller calls SwapFail(). We will need to clean up the DB
	    # state by hand.
	    #
	    $EXPT_RESOURCESHOSED = 1;
	    return -1;
	}
	# Proceed ... 
    }

    #
    # Generate a new resource record, but watch for the unused one that
    # we got when the experiment was first created.
    #
    if ($which eq $EXPT_SWAPMOD || $which eq $EXPT_SWAPIN) {
	#
	# In SWAPIN, copy over the thumbnail. This is temporary; I think
	# the thumbnail is going to end up going someplace else.
	# For swapmod, its gonna get overwritten in tbprerun.
	# Ditto above for input_data_idx.
	#
	my $thumbdata = (defined($self->thumbnail()) ?
			 DBQuoteSpecial($self->thumbnail()) : "NULL");
        my $input_data_idx = (defined($self->input_data_idx()) ?
			      $self->input_data_idx() : "NULL");
	my $byswapmod = ($which eq $EXPT_SWAPMOD ? 1 : 0);
	my $byswapin  = ($which eq $EXPT_SWAPIN  ? 1 : 0);

	my $query_result =
	    DBQueryWarn("insert into experiment_resources ".
			" (idx, uid_idx, tstamp, exptidx, lastidx, ".
			"  byswapmod, byswapin, input_data_idx, thumbnail) ".
			"values (0, '$uid_idx', now(), $exptidx, $rsrcidx,".
			"        $byswapmod, $byswapin, ".
			"        $input_data_idx, $thumbdata)");
	return -1
	    if (! $query_result ||
		! $query_result->insertid);
	
	my $newrsrc = $query_result->insertid;
	
	DBQueryWarn("update experiment_stats set ".
		    "  rsrcidx=$newrsrc,lastrsrc=$rsrcidx ".
		    "where exptidx=$exptidx")
	    or goto failed;

	$self->Refresh() == 0
	    or goto failed;

	$rsrcidx = $newrsrc;
    }

    #
    # Update the timestamps in the current resource record to reflect
    # the official start of the operation.
    #
    if ($which eq $EXPT_SWAPIN || $which eq $EXPT_START) {
	DBQueryWarn("update experiment_resources set ".
		    "  swapin_time=UNIX_TIMESTAMP(now()) ".
		    "where idx='$rsrcidx'")
	    or goto failed;
    }
    elsif ($which eq $EXPT_SWAPOUT && ! $self->swapout_time()) {
	# Do not overwrite it; means a previously failed swapout, but for
	# accounting purposes, we want the original time.
	DBQueryWarn("update experiment_resources set ".
		    "  swapout_time=UNIX_TIMESTAMP(now()) ".
		    "where idx='$rsrcidx'")
	    or goto failed;
    }
    elsif ($which eq $EXPT_SWAPMOD && $isactive) {
	DBQueryWarn("update experiment_resources set ".
		    "  swapin_time=UNIX_TIMESTAMP(now()) ".
		    "where idx='$rsrcidx'")
	    or goto failed;
	#
	# If this swapmod fails, the record is deleted of course.
	# But if it succeeds, we will also change the previous record
	# to reflect the swapmod time. See PostSwap() below.
	#
    }

    #
    # Before we allocate any resources we have to make sure the reservation
    # system and the autoswapper are on the same page wrt when these
    # resources are going to be released. We can no longer wait till the
    # end of swapin (when swapin_last is updated), we need to base it from
    # the current time, or else the res system can get into an overbook
    # situation. As a result, users will see somewhat shorter autoswap then
    # they are used to, depending on how long the experiment takes to
    # swapin. So add a little padding, not worth worrying too much since
    # this is Emulab Classic. Expiration is handled on the geni path so
    # skip.
    #
    if (!$self->geniflags() &&
	($which eq $EXPT_SWAPIN || $which eq $EXPT_START)) {
	if ($self->autoswap() && $self->autoswap_timeout()) {
	    $self->SetExpiration(time() +
				 (($self->autoswap_timeout() + 30) * 60));
	}
	else {
	    $self->SetExpiration(undef);
	}
    }

    # Old swap gathering stuff.
    $self->GatherSwapStats($swapper, $which, 0,
			   TBDB_STATS_FLAGS_START()) == 0
	or goto failed;

    # We do these here since even failed operations implies activity.
    # No worries if they fail; just informational.
    $swapper->BumpActivity();
    $self->GetProject()->BumpActivity();
    $self->GetGroup()->BumpActivity();
    $self->Refresh() == 0
	or goto failed;

    #
    # If swapping out, fire off an event to shutdown SAN-based blockstores.
    #
    # XXX We do this here because it is before the experimental vlans set
    # removed and before vnodes get shutdown.
    #
    if ($which eq $EXPT_SWAPOUT && $self->UsingRemBlockstore() > 0) {
	require event;
	my $pid = $self->pid();
	my $eid = $self->eid();
	
	print "Telling nodes to shutdown remote blockstores\n";
	if (system("$TEVC -e $pid/$eid now rem-bstore stop")) {
	    print "*** WARNING: Could not send blockstore shutdown event!\n";
	}
	# XXX we take down the VLANs immediately after this, so wait a bit
	else {
	    sleep(2);
	}
    }
    
    return 0;

  failed:
    $self->SwapFail($which, 55);
    return -1;
}

#
# Rollback after a failed swap operation; cleans up the stats and resources.
#
sub SwapFail($$$$;$)
{
    my ($self, $swapper, $which, $ecode, $flags) = @_;
    my $exptidx = $self->idx();

    # Must be a real reference. 
    return -1
	if (! ref($self));

    $flags = 0
	if (!defined($flags));

    # Do not proceed if we got here via a hosed resources record.
    return 0
	if ($EXPT_RESOURCESHOSED);

    if (($flags & $EXPT_FLAGS_FIXRESOURCES) == 0) {
	# Old swap gathering stuff.
	$self->GatherSwapStats($swapper, $which, $ecode);

	my $session = libtblog::tblog_session();
	$session = 'NULL' unless defined $session;

	# This is pointless.
	DBQueryWarn("update experiment_stats set ".
		    "  swap_errors=swap_errors+1, ".
		    "  swap_exitcode='$ecode', ".
		    "  last_error=$session ".
		    "where exptidx=$exptidx");
    }
    # Clear this on failed swapin.
    if ($which eq $EXPT_START || $which eq $EXPT_SWAPIN) {
	$self->SetExpiration(undef);
    }
    
    #
    # Get current and last rsrc record direct from DB to avoid local cache.
    #
    my $query_result =
	DBQueryWarn("select rsrcidx,lastrsrc from experiment_stats ".
		    "where exptidx=$exptidx");

    return -1
	if (! $query_result ||
	    ! $query_result->numrows);

    my ($rsrcidx, $lastrsrc) = $query_result->fetchrow_array();

    #
    # Special case; The first swapin does not get a new resource record,
    # and so there will be nothing to delete. So, clear the swapin time.
    # I think we can get rid of this special case, and also the case of
    # creating a new resource record when doing a swapmod to an inactive
    # experiment, but do not want to tackle that at this time
    #
    if (! $lastrsrc && ($which eq $EXPT_START || $which eq $EXPT_SWAPIN)) {
	DBQueryWarn("update experiment_resources set swapin_time=0, ".
		    " vnodes=0,jailnodes=0,plabnodes=0,delaynodes=0 ".
		    "where idx='$rsrcidx'")
	or return -1;
    }
    
    return 0
	if (! $lastrsrc);

    #
    # If there is a lastrsrc record, it means the current one is bogus and
    # needs to be deleted, and the stats record repointed to the last one.
    # If this reset operation fails, lets be sure to set the timestamps in
    # the bogus resource record to 0 so that we have an indication that
    # something went wrong when we later traverse the chain of records. 
    #
    DBQueryWarn("update experiment_resources set ".
		"  swapin_time=0,swapmod_time=0,swapout_time=0 ".
		"where idx='$rsrcidx'")
	or return -1;

    # Delete it.
    DBQueryWarn("delete from experiment_resources ".
		"where idx=$rsrcidx")
	or return -1;

    #
    # This last step clears lastrsrc, which is how we know that the record
    # is consistent and that we can do another swap operation on it.
    #
    DBQueryWarn("update experiment_stats set ".
		"  rsrcidx=$lastrsrc,lastrsrc=NULL ".
		"where exptidx=$exptidx")
	or return -1;

    $self->Refresh();

    #
    # If we fail to clear the lastrsrc record, the next swap operation will
    # fail until the DB is cleaned up.
    #
    return 0;
}

#
# Finalize bookkeeping for a swap operation.
#
sub PostSwap($$$$)
{
    my ($self, $swapper, $which, $flags) = @_;

    # Must be a real reference. 
    return -1
	if (! ref($self));

    $flags = 0
	if (!defined($flags));

    my $exptidx  = $self->idx();
    my $rsrcidx  = $self->rsrcidx();
    my $lastrsrc = $self->lastrsrc();

    # Old swap gathering stuff.
    $self->GatherSwapStats($swapper, $which, 0) == 0
	or return -1;

    #
    # On a swapout/modify complete, update the duration counters. We
    # want to update the aggregates too below, so get the numbers we
    # need for that first. Modify is a bit of a complication since we
    # want to charge for the experiment as it *was* until this point,
    # since the number of nodes has changed.
    #
    my $pnodes       = 0;
    my $vnodes       = 0;
    my $duration     = 0;
    my $timein       = 0;
    my $prev_uid_idx = 0;
    my $prev_swapper = $swapper;
    my $query_result;

    #
    # Need to update the previous record with the swapmod_time.
    #
    if ($which eq $EXPT_SWAPMOD) {
	my $when = "UNIX_TIMESTAMP(now())";
	# unless its active, in which case pick up swapin time.
	$when = $self->swapin_time()
	    if ($self->state() eq EXPTSTATE_ACTIVE());
	
	DBQueryWarn("update experiment_resources set ".
		    "  swapmod_time=$when ".
		    "where idx='$lastrsrc'")
	    or return -1;
    }

    if ($which eq $EXPT_SWAPOUT ||
	($which eq $EXPT_SWAPMOD &&
	 $self->state() eq EXPTSTATE_ACTIVE())) {
	
	#
	# If this is a swapout, we use the current resource record. If this
	# is a swapmod, we have to back to the previous resource record,
	# since the current one reflects usage for the new swap.
	#
	if ($which eq $EXPT_SWAPOUT) {
	    $query_result =
		DBQueryWarn("select r.pnodes,r.vnodes,r.uid_idx, ".
			    "  r.swapout_time - r.swapin_time, ".
			    "  r.swapin_time ".
			    " from experiment_resources as r ".
			    "where r.idx='$rsrcidx'");
	}
	else {
	    $query_result =
		DBQueryWarn("select r.pnodes,r.vnodes,r.uid_idx, ".
			    "  r.swapmod_time - r.swapin_time, ".
			    "  r.swapmod_time ".
			    " from experiment_resources as r ".
			    "where r.idx='$lastrsrc'");
	}
	return -1
	    if (!$query_result);
	
	if ($query_result->numrows) {
	    ($pnodes,$vnodes,$prev_uid_idx,$duration,$timein) =
		$query_result->fetchrow_array;
	    # Might happen if swapin stats got losts.
	    $duration = 0
		if (! defined($duration) || $duration < 0);
	    # Ditto. This happens on the geni path, need to fix it.
	    $duration = 0
		if ($timein == 0);

	    $prev_swapper = User->Lookup($prev_uid_idx);
	    $prev_swapper = $swapper
		if (!defined($prev_swapper));
	}
    }

    # Special case for initial record. Needs to be fixed.
    if ($which eq $EXPT_SWAPIN && !$self->lastidx()) {
	DBQueryWarn("update experiment_resources set byswapin=1 ".
		    "where idx='$rsrcidx'")
	    or return -1;
    }

    #
    # Increment idleswap indicator, but only valid on swapout. Harmless
    # if this fails, so do not worry about it.
    #
    if ($which eq $EXPT_SWAPOUT &&
	$flags & TBDB_STATS_FLAGS_IDLESWAP()) {
	DBQueryWarn("update experiment_stats ".
		    "set idle_swaps=idle_swaps+1 ".
		    "where exptidx=$exptidx");
    }

    #
    # On successful swapin, get the number of pnodes. assign_wrapper
    # has filled in everything else, but until the experiment actually
    # succeeds in swapping, do not set the pnode count. The intent
    # is to avoid counting experiments that ultimately fail as taking
    # up physical resources.
    #
    if ($which eq $EXPT_START ||
	$which eq $EXPT_SWAPIN ||
	($which eq $EXPT_SWAPMOD &&
	 $self->state() eq EXPTSTATE_ACTIVE())) {
	$query_result =
	    DBQueryWarn("select r.node_id,n.type,r.erole,r.vname, ".
			"    n.phys_nodeid,nt.isremotenode,nt.isvirtnode ".
			"  from reserved as r ".
			"left join nodes as n on r.node_id=n.node_id ".
			"left join node_types as nt on nt.type=n.type ".
			"where r.exptidx='$exptidx' and ".
			"      (n.role='testnode' or n.role='virtnode')");

	return -1
	    if (! $query_result);

	# Count up the unique *local* pnodes.
	my %pnodemap = ();
	# Generate the pmapping insert.
	my @mappings = ();

	while (my ($node_id,$type,$erole,$vname,$physnode,$isrem,$isvirt) =
	       $query_result->fetchrow_array()) {
	    push(@mappings,
		 "($rsrcidx, '$vname', '$physnode', '$type', '$erole')");

	    # We want just local physical nodes in this counter.
	    $pnodemap{$physnode} = $physnode
		if (! ($isrem || $isvirt));
	}
	if (@mappings) {
	    DBQueryWarn("insert into experiment_pmapping values ".
			join(",", @mappings))
		or return -1;
	}
	$pnodes = scalar(keys(%pnodemap));

	DBQueryWarn("update experiment_resources set pnodes=$pnodes ".
		    "where idx=$rsrcidx")
	    or return -1;
    }
    
    #
    # Per project/group/user aggregates. These can now be recalculated,
    # so if this fails, do not worry about it.
    #
    if ($which eq $EXPT_PRELOAD ||
	$which eq $EXPT_START ||
	$which eq $EXPT_SWAPOUT ||
	$which eq $EXPT_SWAPIN ||
	$which eq $EXPT_SWAPMOD) {
	$self->GetProject()->UpdateStats($which, $duration, $pnodes, $vnodes);
	$self->GetGroup()->UpdateStats($which, $duration, $pnodes, $vnodes);
	if ($which eq $EXPT_SWAPOUT ||
	    $which eq $EXPT_SWAPMOD) {
	    $prev_swapper->UpdateStats($which, $duration, $pnodes, $vnodes);
	}
	else {
	    $swapper->UpdateStats($which, 0, 0, 0);
	}
	

	#
	# Update the per-experiment record.
	# Note that we map start into swapin.
	#
	if ($which eq $EXPT_SWAPOUT ||
	    $which eq $EXPT_SWAPIN ||
	    $which eq $EXPT_START ||
	    $which eq $EXPT_SWAPMOD) {
	    my $tmp = $which;
	    if ($which eq $EXPT_START) {
		$tmp = $EXPT_SWAPIN;
	    }
	    DBQueryWarn("update experiment_stats ".
			"set ${tmp}_count=${tmp}_count+1, ".
			"    ${tmp}_last=now(), ".
			"    last_activity=${tmp}_last, ".
			"    swapin_duration=swapin_duration+${duration}, ".
			"    swap_exitcode=0, ".
			"    last_error=NULL ".
			"where exptidx=$exptidx");
	}

	# Batch mode info.
	if ($which eq $EXPT_SWAPIN || $which eq $EXPT_START) {
	    my $batchmode = $self->batchmode();
	    
	    DBQueryWarn("update experiment_resources set ".
			"    batchmode=$batchmode ".
			"where idx=$rsrcidx");
	}
    }
    # Lets clear this since a swaped experiment has no expiration.
    # Expiration is handled on the geni path so skip.
    if (!$self->geniflags() && $which eq $EXPT_SWAPOUT) {
	$self->SetExpiration(undef);
    }

    #
    # This last step clears lastrsrc, which is how we know that the record
    # is consistent and that we can do another swap operation on it.
    #
    DBQueryWarn("update experiment_stats set lastrsrc=NULL ".
		"where exptidx=$exptidx");
    
    $self->Refresh();
    
    return 0;
}

#
# Gather Stats. This is the original stats code, which has been partly
# replaced by the code above.
#
sub GatherSwapStats($$$;$$)
{
    my ($self, $user, $mode, $ecode, $flags) = @_;

    # Optional argument to modify the stats gathering.
    $flags = 0
	if (!defined($flags));
    $ecode = 0
	if (!defined($ecode));
    # Perl/mysql sillyness. 
    $ecode = -1
	if ($ecode == 255);

    #
    # If this is a start time marker, then just record the time in a global
    # variable and return. This is cheezy, but the interface I'm providing
    # allows for fancier stuff later if desired.
    #
    if ($flags & TBDB_STATS_FLAGS_START()) {
	$EXPT_STARTCLOCK = time();
	return 0;
    }
    my $session = libtblog::tblog_session();
    $session = 'NULL' unless defined $session;

    my $exptidx   = $self->idx();
    my $rsrcidx   = $self->rsrcidx();
    my $uid       = $user->uid();
    my $uid_idx   = $user->uid_idx();
    my $starttime = (!defined($EXPT_STARTCLOCK) ? "NULL" :
		     "FROM_UNIXTIME($EXPT_STARTCLOCK)");

    #
    # Okay, Jay wants a log file but I am not crazy about that. Instead we
    # have a tiny table of testbed wide stats, which cross indexes with the
    # experiment_stats table via the idx field (which comes from the
    # experiments table of course). For each operation insert a record. We
    # can then construct a complete record of what happened from this
    # table, when correlated with experiment_stats. We could probably not
    # have an errorcode in experiment_stats, but since its a tinyint, not
    # worth worrying about.
    #
    DBQueryWarn("insert into testbed_stats ".
		"(idx, uid, uid_idx, start_time, end_time, exptidx, rsrcidx, ".
		" action, exitcode, log_session) ".
		"values (0, '$uid', '$uid_idx',  $starttime, now(), ".
		"        $exptidx, $rsrcidx, '$mode', '$ecode', $session)")
	or return -1;

    return 0;
}

sub Swap($$;$$)
{
    my ($self, $which, $options, $flags) = @_;

    # Must be a real reference. 
    return -1
	if (! ref($self));

    my $pid = $self->pid();
    my $eid = $self->eid();
    my $idx = $self->idx();
    my $op;

    $options = ""
	if (!defined($options));

    if ($which eq $EXPT_SWAPIN) {
	$op = "in";
    }
    elsif ($which eq $EXPT_SWAPOUT) {
	$op = "out";
    }
    elsif ($which eq $EXPT_SWAPMOD) {
	$op = "modify";
    }
    elsif ($which eq $EXPT_SWAPUPDATE) {
	$op = "update";
    }

    print "Running 'tbswap $op $options $pid $eid'\n";
    mysystem("$TBSWAP $op $options $pid $eid");
    return -1
	if ($?);
    return 0;
}

sub End($;$)
{
    my ($self, $options) = @_;

    # Must be a real reference. 
    return -1
	if (! ref($self));

    my $exptidx = $self->idx();

    $options = ""
	if (!defined($options));

    #
    # If the destroyed field is already set, leave it alone since it means
    # the operation failed the first time.
    #
    if (! defined($self->destroyed())) {
	DBQueryWarn("update experiment_stats set ".
		    "   destroyed=now() ".
		    "where exptidx=$exptidx")
	    or return -1;
	$self->Refresh() == 0
	    or return -1;
    }
    
    print "Running 'tbend $options -e $exptidx'\n";
    mysystem("$TBEND $options -e $exptidx");
    return -1
	if ($?);

    return 0;
}

sub Report($;$$)
{
    my ($self, $filename, $options) = @_;

    # Must be a real reference. 
    return -1
	if (! ref($self));

    my $pid = $self->pid();
    my $eid = $self->eid();

    $options = ""
	if (!defined($options));

    print "Running 'tbreport $options $pid $eid'\n";
    mysystem("$TBREPORT $options $pid $eid 2>&1 > $filename");
    return -1
	if ($?);
    return 0;
}

#
# Return list of local nodes.
# 
sub LocalNodeListNames($$;$)
{
    my ($self, $lref, $physonly) = @_;

    # Must be a real reference. 
    return -1
	if (! ref($self));

    $physonly = 0
	if (!defined($physonly));

    my $pid = $self->pid();
    my $eid = $self->eid();

    @$lref = ExpNodes($pid, $eid, 1, $physonly);
    return 0;
}

#
# Return list of experiment nodes in the old reserved experiment.
# 
sub OldReservedNodeList($$)
{
    my ($self, $plist) = @_;

    # Must be a real reference. 
    return -1
	if (! ref($self));

    @$plist     = ();
    my @result  = ();
    my $exptidx = $self->idx();
    my $oldreserved_pid = OLDRESERVED_PID();
    my $oldreserved_eid = OLDRESERVED_EID();

    my $query_result =
	DBQueryWarn("select r.node_id from reserved as r ".
		    "left join nodes as n on n.node_id=r.node_id ".
		    "where r.pid='$oldreserved_pid' and ".
		    "      r.eid='$oldreserved_eid' and ".
		    "      r.old_exptidx='$exptidx'");

    return -1
	if (!$query_result);

    while (my ($nodeid) = $query_result->fetchrow_array()) {
	my $node = Node->Lookup($nodeid);
	if (!defined($node)) {
	    print STDERR "*** Could not map $nodeid to its object\n";
	    return -1;
	}
	push(@result, $node);
    }
    @$plist = @result;
    return 0;
}

#
# Return list of experiment nodes (objects or just names)
#
sub NodeList($;$$)
{
    my ($self, $namesonly, $includevirtual) = @_;
    my @nodenames = ();

    # Must be a real reference. 
    return undef
	if (! ref($self));
    $includevirtual = 0
	if (!defined($includevirtual));
    $namesonly = 0
	if (!defined($namesonly));

    my $pid = $self->pid();
    my $eid = $self->eid();

    my $query_result =
	DBQueryWarn("select r.node_id,nt.isvirtnode from reserved as r ".
		    "left join nodes as n on n.node_id=r.node_id ".
		    "left join node_types as nt on nt.type=n.type ".
		    "where r.pid='$pid' and r.eid='$eid'");
    return undef
	if (!$query_result);
    return ()
	if (!$query_result->numrows);

    while (my ($nodeid,$isvirt) = $query_result->fetchrow_array()) {
	next
	    if ($isvirt && !$includevirtual);
	push(@nodenames, $nodeid);
    }
    return @nodenames
	if ($namesonly);

    my @nodes = ();

    foreach my $nodeid (@nodenames) {
	my $node = Node->Lookup($nodeid);
	if (!defined($node)) {
	    print STDERR "*** Could not map $nodeid to its object\n";
	    next;
	}
	push(@nodes, $node);
    }
    return @nodes;
}

#
# Return list of experiment nodes (objects or just names)
#
sub VirtNodeList($$)
{
    my ($self, $namesonly) = @_;
    my @nodenames = ();

    # Must be a real reference. 
    return undef
	if (! ref($self));
    $namesonly = 0
	if (!defined($namesonly));

    my $pid = $self->pid();
    my $eid = $self->eid();

    my $query_result =
	DBQueryWarn("select r.node_id,nt.isvirtnode from reserved as r ".
		    "left join nodes as n on n.node_id=r.node_id ".
		    "left join node_types as nt on nt.type=n.type ".
		    "where r.pid='$pid' and r.eid='$eid' and ".
		    "      nt.isvirtnode=1");
    return undef
	if (!$query_result);
    return ()
	if (!$query_result->numrows);

    while (my ($nodeid) = $query_result->fetchrow_array()) {
	push(@nodenames, $nodeid);
    }
    return @nodenames
	if ($namesonly);

    my @nodes = ();

    foreach my $nodeid (@nodenames) {
	my $node = Node->Lookup($nodeid);
	if (!defined($node)) {
	    print STDERR "*** Could not map $nodeid to its object\n";
	    return undef;
	}
	push(@nodes, $node);
    }
    return @nodes;
}

#
# Return list of experiment switches (objects or just names)
#
sub SwitchList($;$$)
{
    my ($self, $namesonly, $includevirtual) = @_;
    my @nodenames = ();

    # Must be a real reference. 
    return undef
	if (! ref($self));
    $includevirtual = 0
	if (!defined($includevirtual));
    $namesonly = 0
	if (!defined($namesonly));

    my $pid = $self->pid();
    my $eid = $self->eid();

    my $query_result =
	DBQueryWarn("select r.node_id,nt.isvirtnode from reserved as r ".
		    "left join nodes as n on n.node_id=r.node_id ".
		    "left join node_types as nt on nt.type=n.type ".
		    "where r.pid='$pid' and r.eid='$eid' and nt.isswitch=1");
    return undef
	if (!$query_result);
    return ()
	if (!$query_result->numrows);

    while (my ($nodeid,$isvirt) = $query_result->fetchrow_array()) {
	next
	    if ($isvirt && !$includevirtual);
	push(@nodenames, $nodeid);
    }
    return @nodenames
	if ($namesonly);

    my @nodes = ();

    foreach my $nodeid (@nodenames) {
	my $node = Node->Lookup($nodeid);
	if (!defined($node)) {
	    print STDERR "*** Could not map $nodeid to its object\n";
	    return undef;
	}
	push(@nodes, $node);
    }
    return @nodes;
}

#
# Copy log files to long term storage.
#
sub SaveLogFiles($)
{
    my ($self) = @_;

    # Must be a real reference. 
    return -1
	if (! ref($self));

    my $pid = $self->pid();
    my $eid = $self->eid();
    my $workdir = $self->WorkDir();
    my $infodir = $self->InfoDir();

    # What the hell is this file! Very annoying.
    if (-e "$workdir/.rnd") {
	mysystem("/bin/rm -f $workdir/.rnd");
    }
    mysystem("$RSYNC -a $workdir/ $infodir");
    return 0;
}

#
# Remove old logfiles from the wordir.
#
sub CleanLogFiles($)
{
    my ($self) = @_;

    # Must be a real reference. 
    return -1
	if (! ref($self));

    my $workdir = $self->WorkDir();
    
    opendir(DIR, $workdir) or
	return -1;
    my @files   = readdir(DIR);
    my @delete  = ();
    closedir(DIR);

    foreach my $file (@files) {
	# Just in case ...
	next
	    if ($file =~ /^.*\.ns$/);
	
	push(@delete, "${workdir}/$1")
	    if ($file =~ /^(.*\.(log|ptop|top|vtop|assign|soln|xml|limits))$/);

	push(@delete, "${workdir}/$1")
	    if ($file =~ /^((swap|start|cancel|newrun).*\..*)$/);
    }
    mysystem("/bin/rm -f @delete") == 0
	or return -1;

    #
    # Whenever we clean the log files, we might as well clear the
    # current log file, cause it no longer is there, but the web
    # interface will not know that.
    #
    $self->ClearLogFile();

    return 0;
}

#
# Copy log files to user visible space. Maybe not such a good idea anymore?
#
sub CopyLogFiles($;@)
{
    my ($self, @files) = @_;

    # Must be a real reference. 
    return -1
	if (! ref($self));

    my $pid = $self->pid();
    my $eid = $self->eid();
    my $workdir = $self->WorkDir();
    my $userdir = $self->UserDir();

    # Specific files, then return.
    if (@files) {
	mysystem("/bin/cp -fp @files $userdir/tbdata");
	return 0;
    }

    opendir(DIR, $workdir) or
	return -1;
    @files  = readdir(DIR);
    closedir(DIR);
    my @copy   = ();

    foreach my $file (@files) {
	push(@copy, "${workdir}/$1")
	    if ($file =~ /^(.*\.(log|report|ns|png))$/);
    }

    mysystem("/bin/cp -fp @copy $userdir/tbdata");
    return 0;
}

#
# Backup the user directory for debugging. 
#
sub BackupUserData($)
{
    my ($self) = @_;
    
    # Must be a real reference. 
    return -1
	if (! ref($self));

    my $userdir = $self->UserDir();
    my $path    = dirname($userdir);
    my $dir     = basename($userdir);
    my $backup  = "${path}/.${dir}-failed";

    if (-e $backup) {
	mysystem("/bin/rm -rf $backup");
    }
    mysystem("/bin/mv $userdir $backup");
    return 0;
}

#
# Swapinfo accounting stuff.
#
sub SetSwapInfo($$)
{
    my ($self, $user) = @_;

    # Must be a real reference. 
    return -1
	if (! ref($self));

    my $pid = $self->pid();
    my $eid = $self->eid();
    
    $self->SetSwapTime();
    $self->SetSwapper($user);
    return $self->Refresh();
}

#
# Just the swap uid.
#
sub SetSwapper($$)
{
    my ($self, $user) = @_;

    # Must be a real reference. 
    return -1
	if (! ref($self));

    my $pid  = $self->pid();
    my $eid  = $self->eid();
    my $uid  = $user->uid();
    my $dbid = $user->dbid();

    DBQueryWarn("update experiments set ".
		"   expt_swap_uid='$uid', swapper_idx='$dbid' ".
		"where pid='$pid' and eid='$eid'");

    return $self->Refresh();
}

#
# Get swapper (user) object.
#
sub GetSwapper($)
{
    my ($self) = @_;
    require User;

    # Must be a real reference. 
    return undef
	if (! ref($self));
    return undef
	if (! defined($self->swapper_idx()));

    return User->Lookup($self->swapper_idx());
}

#
# Get creator (user) object.
#
sub GetCreator($)
{
    my ($self) = @_;
    require User;

    # Must be a real reference. 
    return undef
	if (! ref($self));

    return User->Lookup($self->creator_idx());
}

#
# Just the swap time.
#
sub SetSwapTime($)
{
    my ($self) = @_;

    # Must be a real reference. 
    return -1
	if (! ref($self));

    my $idx = $self->idx();

    return -1
	if (!DBQueryWarn("update experiments set expt_swapped=now() ".
			 "where idx='$idx'"));
    return 0;
}

#
# Set the cancel flag.
#
sub SetCancelFlag($$)
{
    my ($self, $flag) = @_;

    # Must be a real reference. 
    return -1
	if (! ref($self));

    my $pid = $self->pid();
    my $eid = $self->eid();
    
    TBSetCancelFlag($pid, $eid, $flag);
    return $self->Refresh();
}

#
# No NFS Mounts.
#
sub NoNFSMounts($)
{
    my ($self) = @_;

    # Must be a real reference. 
    return -1
	if (! ref($self));

    my $idx   = $self->idx();
    
    return -1
	if (!DBQueryWarn("update experiments set ".
			 "  nonfsmounts=1,nfsmounts='none' ".
			 "where idx='$idx'"));
    return 0;
}

sub HasNoNFSMounts($)
{
    my ($self) = @_;
    my $idx   = $self->idx();
    
    my $query_result = 
	DBQueryWarn("select nonfsmounts,nfsmounts from experiments ".
		    "where idx='$idx' and ".
		    "      (nonfsmounts=1 or nfsmounts='none')");
    return 1
	if (!$query_result);
    return $query_result->numrows;
}

#
# Clear the panic bit.
#
sub SetPanicBit($$)
{
    my ($self, $onoff) = @_;

    # Must be a real reference. 
    return -1
	if (! ref($self));

    my $idx  = $self->idx();
    my $when = ($onoff ? "now()" : "NULL");
    
    return -1
	if (!DBQueryWarn("update experiments set ".
			 "  paniced=$onoff,panic_date=$when ".
			 "where idx='$idx'"));
    return 0;
}

sub SetSwappable($$)
{
    my ($self, $arg) = @_;

    my $idx   = $self->idx();
    my $onoff = ($arg ? 1 : 0);
    
    return -1
	if (!DBQueryWarn("update experiments set ".
			 "  swappable='$onoff' ".
			 "where idx='$idx'"));

    $self->{'EXPT'}->{'swappable'} = $onoff;
    return 0;
}

sub SetLockdown($$)
{
    my ($self, $arg) = @_;

    my $idx   = $self->idx();
    my $onoff = ($arg ? 1 : 0);
    
    return -1
	if (!DBQueryWarn("update experiments set ".
			 "  lockdown='$onoff' ".
			 "where idx='$idx'"));

    $self->{'EXPT'}->{'lockdown'} = $onoff;
    return 0;
}

sub SetAutoswap($$)
{
    my ($self, $arg) = @_;

    my $idx   = $self->idx();
    my $onoff = ($arg ? 1 : 0);
    
    return -1
	if (!DBQueryWarn("update experiments set ".
			 "  autoswap='$onoff' ".
			 "where idx='$idx'"));

    $self->{'EXPT'}->{'lockdown'} = $onoff;
    return 0;
}

sub SetAutoswapTimeout($$)
{
    my ($self, $minutes) = @_;

    my $idx   = $self->idx();
    
    return -1
	if (!DBQueryWarn("update experiments set ".
			 "  autoswap_timeout='$minutes' ".
			 "where idx='$idx'"));

    $self->{'EXPT'}->{'autoswap_timeout'} = $minutes;
    return 0;
}

#
# Is experiment firewalled?
#
sub IsFirewalled($;$$$)
{
    my ($self, $pref1, $pref2, $pref3) = @_;

    # Must be a real reference. 
    return -1
	if (! ref($self));

    my $pid = $self->pid();
    my $eid = $self->eid();

    return TBExptFirewall($pid, $eid, $pref1, $pref2, $pref3);
}

#
# Get the firewall node name and iface for an experiment;
# e.g., for use in an snmpit call.
# Return 1 if successful, 0 on error.
#
sub FirewallAndIface($$$)
{
    my ($self, $fwnodep, $fwifacep) = @_;

    # Must be a real reference. 
    return -1
	if (! ref($self));

    TBExptFirewallAndIface($self->pid(), $self->eid(), $fwnodep, $fwifacep)
	or return -1;
    return 0;
}

#
# Set the firewall info.
#
sub SetFirewallVlan($$$)
{
    my ($self, $fwvlanid, $fwvlan) = @_;

    # Must be a real reference. 
    return -1
	if (! ref($self));

    TBSetExptFirewallVlan($self->pid(), $self->eid(), $fwvlanid, $fwvlan)
	or return -1;
    return 0;
}

#
# Clear the firewall info.
#
sub ClearFirewallVlan($)
{
    my ($self) = @_;

    # Must be a real reference. 
    return -1
	if (! ref($self));

    TBClearExptFirewallVlan($self->pid(), $self->eid());
    return 0;
}

#
# Update the idleswap timeout. Why?
#
sub UpdateIdleSwapTime($$)
{
    my ($self, $newtimeout) = @_;

    # Must be a real reference. 
    return -1
	if (! ref($self));

    my $pid = $self->pid();
    my $eid = $self->eid();

    DBQueryWarn("update experiments set idleswap_timeout='$newtimeout' ".
		"where eid='$eid' and pid='$pid'")
	or return -1;

    return 0;
}

#
# Set the idle swap flags.
#
sub SetIdleSwapFlags($$$)
{
    my ($self, $idleswap, $idleignore) = @_;
    $idleswap   = ($idleswap ? 1 : 0);
    $idleignore = ($idleignore ? 1 : 0);

    return -1
	if (! $self->Update({'idleswap'    => $idleswap,
			     'idle_ignore' => $idleignore}));

    return 0;
}

#
# Experiment tables.
#
sub BackupVirtualState($;$)
{
    my ($self, $directory) = @_;

    # Must be a real reference. 
    return -1
	if (! ref($self));

    my $pid = $self->pid();
    my $eid = $self->eid();
    my $idx = $self->idx();
    my $vstateDir = (defined($directory) ?
		     $directory : $self->WorkDir() . "/vstate");
    my $errors = 0;

    if (! -e $vstateDir) {
	mkdir($vstateDir, 0777)
	    or return -1;

	chmod(0777, $vstateDir)
	    or return -1;
    }

    foreach my $table (@virtualTables) {
	DBQueryWarn("SELECT * FROM $table ".
		    "WHERE exptidx='$idx' ".
		    "INTO OUTFILE '$vstateDir/$table' ")
	    or $errors++;
    }

    return $errors;
}
sub RemoveVirtualState($)
{
    my ($self) = @_;

    # Must be a real reference. 
    return -1
	if (! ref($self));

    my $idx = $self->idx();
    my $pid = $self->pid();
    my $eid = $self->eid();
    my $errors = 0;

    foreach my $table (@virtualTables) {
	DBQueryWarn("DELETE FROM $table WHERE exptidx='$idx'")
	    or $errors++;
    }
    return $errors;
}
sub RestoreVirtualState($)
{
    my ($self) = @_;

    # Must be a real reference. 
    return -1
	if (! ref($self));

    my $pid = $self->pid();
    my $eid = $self->eid();
    my $vstateDir = $self->WorkDir() . "/vstate";
    my $errors    = 0;

    foreach my $table (@virtualTables) {
	DBQueryWarn("LOAD DATA INFILE '$vstateDir/$table' INTO TABLE $table")
	    or $errors++;
    }
    return $errors;
}
sub ClearBackupState($)
{
    my ($self) = @_;

    # Must be a real reference. 
    return -1
	if (! ref($self));

    my $pid = $self->pid();
    my $eid = $self->eid();
    my $workdir   = $self->WorkDir();
    my $pstateDir = $workdir . "/pstate";
    my $vstateDir = $workdir . "/vstate";

    system("/bin/rm -rf $pstateDir")
	if (-e $pstateDir);
    system("/bin/rm -rf $vstateDir")
	if (-e $vstateDir);

    return 0;
}
sub SaveBackupState($)
{
    my ($self) = @_;

    # Must be a real reference. 
    return -1
	if (! ref($self));

    my $pid = $self->pid();
    my $eid = $self->eid();
    my $workdir   = $self->WorkDir();
    my $pstateDir = $workdir . "/pstate";
    my $vstateDir = $workdir . "/vstate";

    system("/bin/rm -rf ${pstateDir}-prev")
	if (-e "${pstateDir}-prev");
    system("/bin/cp -Rfp $pstateDir ${pstateDir}-prev")
	if (-e $pstateDir);
    system("/bin/rm -rf ${vstateDir}-prev")
	if (-e "${vstateDir}-prev");
    system("/bin/cp -Rfp $vstateDir ${vstateDir}-prev")
	if (-e $vstateDir);

    return 0;
}

#
# This data will be saved longterm in the expinfo directory. The problem
# is that mysql dump files have no table metadata, so when the schema
# changes, these files will no longer be loadable. Not that we want to
# load them, but it would be nice if the format allowed for schema changes.
# To do that will require a bunch more work. Some day ... 
#
sub SaveExperimentState($)
{
    my ($self) = @_;

    # Must be a real reference. 
    return -1
	if (! ref($self));

    my $pid = $self->pid();
    my $eid = $self->eid();
    my $workdir   = $self->WorkDir();
    my $vstateDir = `mktemp -d $workdir/vstate.XXXXXX`;

    # Untaint to avoid stupid errors
    if ($vstateDir =~ /^([-\w\.\/]+)$/) {
	$vstateDir = $1;
    }   
    chmod(0777, $vstateDir)
	or return -1;

    $self->BackupVirtualState($vstateDir);

    #
    # Most of these tables are empty, so lets not burn up zillions
    # of inodes for no reason.
    #
    foreach my $table (@virtualTables) {
	my $file = "$vstateDir/$table";

	unlink($file)
	    if (-z $file);
    }

    #
    # Do not backup physical state if the experiment is not active.
    #
    if ($self->state() eq EXPTSTATE_ACTIVE) {
	my $pstateDir = `mktemp -d $workdir/pstate.XXXXXX`;
	# Untaint to avoid stupid errors.
	if ($pstateDir =~ /^([-\w\.\/]+)$/) {
	    $pstateDir = $1;
	}
	chmod(0777, $pstateDir)
	    or return -1;
	
	$self->BackupPhysicalState($pstateDir);

	#
	# Most of these tables are empty, so lets not burn up zillions
	# of inodes for no reason.
	#
	opendir(DIR, $pstateDir) or
	    return -1;
	my @files  = readdir(DIR);
	closedir(DIR);

	foreach my $file (@files) {
	    $file = "$pstateDir/$file";

	    # Untaint to avoid stupid errors.
	    if ($file =~ /^([-\w\.\/]+)$/) {
		$file = $1;
	    }
	    unlink($file)
		if (-z $file);
	}
    }
    
    return 0;
}
sub RemovePhysicalState($;$)
{
    my ($self, $purge) = @_;
    require Lan;
    require Interface;

    # Must be a real reference. 
    return -1
	if (! ref($self));

    $purge = 0
	if (!defined($purge));

    my $pid = $self->pid();
    my $eid = $self->eid();
    my $idx = $self->idx();
    my $errors = 0;
    
    # Need list of node names, partitioned by phys vs virt.
    my @pnodenames = ();
    my @vnodenames = ();
    
    my $query_result =
	DBQueryWarn("select r.node_id,nt.isvirtnode from reserved as r ".
		    "left join nodes as n on n.node_id=r.node_id ".
		    "left join node_types as nt on nt.type=n.type ".
		    "where r.pid='$pid' and r.eid='$eid'");
    return -1
	if (!$query_result);
    while (my ($nodeid,$isvirtnode) = $query_result->fetchrow_array()) {
	if ($isvirtnode) {
	    push(@vnodenames, $nodeid);
	}
	else {
	    push(@pnodenames, $nodeid);
	}
    }
    return -1
	if (Lan->DestroyExperimentLans($self, $purge) != 0);

    return -1
        if (Interface::LogicalWire->RemoveLogicalWires($self) != 0);
    
    if (@pnodenames || @vnodenames) {
	my $clause1 = join(" or ", map("node_id='$_'",  @pnodenames))
	    if (@pnodenames);
	my $clause2 = join(" or ", map("vnode_id='$_'", @vnodenames))
	    if (@vnodenames);
	my $clause = ((defined($clause1) && defined($clause2) ?
		       "$clause1 or $clause2" :
		       (defined($clause1) ? $clause1 : $clause2)));
	;
    }
    if (@pnodenames) {
	my $clause = join(" or ", map("node_id='$_'", @pnodenames));

	# This table are also cleaned in nfree.
	DBQueryWarn("delete from interface_settings where $clause")
	    or $errors++;

	# Interfaces table is special. Also cleaned in nfree.
	DBQueryWarn("update interfaces set IP='',IPaliases=NULL,mask=NULL,".
		    "       rtabid='0',vnode_id=NULL,current_speed='0', " .
		    "       trunk='0',trunk_mode='equal' ".
		    "where ($clause) and ".
		    "       role='" . TBDB_IFACEROLE_EXPERIMENT() . "' ")
	    or $errors++;

	# RF interfaces (also cleaned in nfree).
	DBQueryWarn("DELETE FROM interfaces_rf_limit WHERE $clause")
	    or $errors++;
	DBQueryWarn("delete from node_rf_reports where $clause")
	    or $errors++;
    }
    
    foreach my $table (keys(%physicalTables)) {
	DBQueryWarn("DELETE FROM $table WHERE pid='$pid' AND eid='$eid'")
	    or $errors++;
    }
    # This table are also cleaned in nfree.
    # Why does this table not have pid,eid?
    DBQueryWarn("delete from vinterfaces where exptidx='$idx'")
	or $errors++;
    
    return $errors;
}
sub BackupPhysicalState($;$$)
{
    my ($self, $directory, $regression) = @_;
    require Lan;
    require Interface;

    # Must be a real reference. 
    return -1
	if (! ref($self));

    my $pid = $self->pid();
    my $eid = $self->eid();
    my $idx = $self->idx();
    my $pstateDir = (defined($directory) ?
		     $directory : $self->WorkDir() . "/pstate");
    my $physonly  = (defined($regression) ? undef : 1);
    my $errors = 0;

    if (! -e $pstateDir) {
	mkdir($pstateDir, 0777)
	    or return 1;

	chmod(0777, $pstateDir)
	    or return 1;
    }

    # Need list of node names, partitioned by phys vs virt.
    my @pnodenames = ();
    my @vnodenames = ();
    
    my $query_result =
	DBQueryWarn("select r.node_id,nt.isvirtnode from reserved as r ".
		    "left join nodes as n on n.node_id=r.node_id ".
		    "left join node_types as nt on nt.type=n.type ".
		    "where r.pid='$pid' and r.eid='$eid'");
    return -1
	if (!$query_result);
    while (my ($nodeid,$isvirtnode) = $query_result->fetchrow_array()) {
	if ($isvirtnode) {
	    push(@vnodenames, $nodeid);
	}
	else {
	    push(@pnodenames, $nodeid);
	}
    }
    return -1
	if (Lan->BackupExperimentLans($self, $pstateDir) != 0);

    return -1
	if (Interface::LogicalWire->BackupLogicalWires($self, $pstateDir) != 0);

    if (@pnodenames || @vnodenames) {
	my $clause = join(" or ", map("node_id='$_'",
				      (@pnodenames, @vnodenames)));

	# This ordering is for wrapper/mapper regression testing. 
	DBQueryWarn("select * from nodes where $clause ".
		    "order by node_id ".
		    "into outfile '$pstateDir/nodes' ")
	    or $errors++;
	
	my $clause1 = join(" or ", map("node_id='$_'",  @pnodenames))
	    if (@pnodenames);
	my $clause2 = join(" or ", map("vnode_id='$_'", @vnodenames))
	    if (@vnodenames);
	$clause = ((defined($clause1) && defined($clause2) ?
		    "$clause1 or $clause2" :
		    (defined($clause1) ? $clause1 : $clause2)));
	;
    }
	
    if (@pnodenames) {
	my $clause = join(" or ", map("node_id='$_'", @pnodenames));

	# This ordering is for wrapper/mapper regression testing. 
	DBQueryWarn("select * from interface_settings where $clause ".
		    "order by node_id,iface,capkey ".
		    "into outfile '$pstateDir/interface_settings' ")
	    or $errors++;

	# interfaces table is special, and this is probably wrong to do anyway
	# since we overwrite columns that are fixed.
	DBQueryWarn("select * from interfaces where ($clause) and ".
		    "  role='" . TBDB_IFACEROLE_EXPERIMENT() . "' ".
		    "into outfile '$pstateDir/interfaces' ")
	    or $errors++;
    }

    # Reserved table is special; we do not want to bring it back in during
    # the restore. We just want the info from it.
    foreach my $table (keys(%physicalTables), "reserved") {
	# This ordering is for wrapper/mapper regression testing. 
	my $orderby = "";
	if (exists($physicalTables{$table}) &&
	    defined($physicalTables{$table})) {
	    $orderby = "order by " . join(",", @{$physicalTables{$table}});
	}
	DBQueryWarn("SELECT * FROM $table WHERE pid='$pid' AND eid='$eid' ".
		    "$orderby ".
		    "INTO OUTFILE '$pstateDir/$table' ")
	    or $errors++;
    }
    # This ordering is for wrapper/mapper regression testing. 
    DBQueryWarn("select * from vinterfaces where exptidx='$idx' ".
		"order by node_id,unit ".
		"into outfile '$pstateDir/vinterfaces' ")
	or $errors++;

    # Just for debugging.
    DBQueryWarn("SELECT * FROM vlans WHERE pid='$pid' AND eid='$eid' ".
		"INTO OUTFILE '$pstateDir/vlans' ")
	or $errors++;
    
    return $errors;
}
sub RestorePhysicalState($)
{
    my ($self) = @_;
    require Lan;
    require Interface;

    # Must be a real reference. 
    return -1
	if (! ref($self));

    my $idx = $self->idx();
    my $pid = $self->pid();
    my $eid = $self->eid();
    my $pstateDir = $self->WorkDir() . "/pstate";
    my $errors = 0;

    return -1
	if (Lan->RestoreExperimentLans($self, $pstateDir) != 0);

    return -1
	if (Interface::LogicalWire->RestoreLogicalWires($self, $pstateDir));
    
    foreach my $table (keys(%physicalTables),
		       "vinterfaces", "interface_settings") {
	if (-e "$pstateDir/$table") {
	    DBQueryWarn("LOAD DATA INFILE '$pstateDir/$table' ".
			"INTO TABLE $table")
		or $errors++;
	}
    }
    # interfaces table is special, and this is probably wrong to do anyway
    # since we overwrite columns that are fixed.
    if (-e "$pstateDir/interfaces") {
	DBQueryWarn("load data infile '$pstateDir/interfaces' ".
		    "replace into table interfaces")
	    or $errors++;
    }
    return $errors
	if ($errors);

    #
    # And bits and pieces from the reserved/node table entries, which have to
    # be updated in place.
    #
    DBQueryWarn("create temporary table reserved_${idx} like reserved")
	or return -1;
    DBQueryWarn("load data infile '$pstateDir/reserved' ".
		"into table reserved_${idx}")
	or return -1;
    my $query_result =
	DBQueryWarn("select * from reserved_${idx}");
    return -1
	if (!$query_result);
    while (my $row = $query_result->fetchrow_hashref()) {
	my $node_id = $row->{"node_id"};
	
	delete($row->{"node_id"});
	my $sets = join(",",
			map("$_=" . (defined($row->{$_}) ?
				     "'" . $row->{$_} . "'" : "NULL"),
			    keys(%{$row})));
	    
	my $update_result =
	    DBQueryWarn("update reserved set $sets ".
			"where node_id='$node_id' and exptidx='$idx'");
	return -1
	    if (!$update_result);
	if (!$update_result->numrows) {
	    print STDERR "Failed to reset reserved table entry for $node_id\n";
	    return -1;
	}
    }
    DBQueryWarn("drop table reserved_${idx}");

    #
    # Restore the nodes table info in one shot. 
    #
    DBQueryWarn("create temporary table nodes_${idx} like nodes")
	or return -1;
    DBQueryWarn("load data infile '$pstateDir/nodes' ".
		"into table nodes_${idx}")
	or return -1;

    my $fieldlist = join(",", map("n.$_=ni.$_", @nodetable_fields));

    my $update_result =
	DBQueryWarn("update nodes n, nodes_${idx} ni set $fieldlist ".
		    "where n.node_id=ni.node_id");
    return -1
	if (!$update_result);
    if (!$update_result->numrows) {
	print STDERR "Failed to reset nodes table entries.\n";
	return -1;
    }
    DBQueryWarn("drop table nodes_${idx}");
    return 0;
}

#
# The port registration table is special, and needs to be cleared only
# at certain times. See tbswap.
#
sub ClearPortRegistration($)
{
    my ($self) = @_;

    # Must be a real reference. 
    return -1
	if (! ref($self));

    my $pid = $self->pid();
    my $eid = $self->eid();

    return -1
	if (! DBQueryWarn("delete from port_registration ".
			  "where pid='$pid' and eid='$eid'"));

    return 0;
}

#
# The reserved_vlantags table is special, and needs to be cleared only
# at certain times. See tbswap.
#
sub ClearReservedVlanTags($)
{
    my ($self) = @_;

    # Must be a real reference. 
    return -1
	if (! ref($self));

    my $pid = $self->pid();
    my $eid = $self->eid();

    return -1
	if (! DBQueryWarn("delete from reserved_vlantags ".
			  "where pid='$pid' and eid='$eid'"));

    return 0;
}

#
# This is slightly different then above. Rather then releasing all
# reserved tags, we release only the tags that are "dangling"; these
# are tags in the reserved_vlantags table, but without a corresonding
# entry in the lans table. Used from the Protogeni code, when
# releasing a ticket (which reserved some tags that will not be used).
#
sub ClearUnusedReservedVlanTags($)
{
    my ($self) = @_;

    # Must be a real reference. 
    return -1
	if (! ref($self));

    my $idx = $self->idx();

    return -1
	if (! DBQueryWarn("delete r from reserved_vlantags as r ".
			  "left join lans as l on l.lanid=r.lanid ".
			  "where l.lanid is null and r.exptidx='$idx'"));

    return 0;
}

#
# Does experiment have any program agents.
#
sub HaveProgramAgents($)
{
    my ($self) = @_;

    # Must be a real reference. 
    return -1
	if (! ref($self));

    my $pid = $self->pid();
    my $eid = $self->eid();

    my $query_result =
	DBQueryWarn("select distinct vnode from virt_programs ".
		    "where pid='$pid' and eid='$eid'");

    return -1
	if (!defined($query_result));

    return $query_result->numrows;
}

#
# Setup up phony program agent event agents and groups. This is so we
# can talk to the program agent itself, not to the programs the agent
# is responsible for. 
#
sub SetupProgramAgents($)
{
    my ($self) = @_;

    # Must be a real reference. 
    return -1
	if (! ref($self));

    my $pid = $self->pid();
    my $eid = $self->eid();
    my $idx = $self->idx();

    my $query_result =
	DBQueryWarn("select distinct vnode from virt_programs ".
		    "where pid='$pid' and eid='$eid'");
    
    return -1
	if (!defined($query_result));
    return 0
	if (! $query_result->numrows);

    while (my ($vnode) = $query_result->fetchrow_array()) {
	DBQueryWarn("replace into virt_agents ".
		     " (exptidx, pid, eid, vname, vnode, objecttype) ".
		     " select '$idx', '$pid', '$eid', ".
		     "   '__${vnode}_program-agent', '$vnode', ".
		     "   idx from event_objecttypes where ".
		     "   event_objecttypes.type='PROGRAM'")
	    or return -1;

	DBQueryWarn("replace into event_groups ".
		    " (exptidx, pid, eid, idx, group_name, agent_name) ".
		    " values ('$idx', '$pid', '$eid', NULL, ".
		    "         '__all_program-agents', ".
		    "         '__${vnode}_program-agent')")
	    or return -1;
    }
    return 0;
}

#
# Convert virt_blobs into real blobs.  We go to some pain to keep the same
# filenames associated with the same uuid to make sure caching doesn't get
# needlessly broken on the client (on a modify).
#
sub UploadBlobs($$)
{
    my ($self,$update) = @_;

    # Must be a real reference. 
    return -1
	if (! ref($self));

    my $pid = $self->pid();
    my $eid = $self->eid();
    my $idx = $self->idx();
    my $virtexp = $self->GetVirtExperiment();
    return -1
	if (!defined($virtexp));

    my %blobs = ();
    my %virt_blobs = ();

    #
    # Grab the existing blobs tied to our experiment
    #
    my $qres = DBQueryFatal("select uuid,filename,vblob_id" . 
			    " from blobs where exptidx=$idx");
    if (defined($qres) && $qres->numrows()) {
	while (my ($uuid,$filename,$vblob_id) = $qres->fetchrow_array()) {
	    $blobs{$vblob_id} = [ 0,$uuid,$filename ];
	}
    }

    #
    # Now grab our experiment virt blobs
    #
    my $virt_blobs_table = $virtexp->Table("virt_blobs");
    foreach my $row ($virt_blobs_table->Rows()) {
	my $vblob_id = $row->vblob_id();
	my $filename = $row->filename();

	$virt_blobs{$vblob_id} = $filename;
    }

    #
    # Make sure each virt_blob is in the blobs table!
    #
    foreach my $vblob_id (keys(%virt_blobs)) {
	my $vfilename = $virt_blobs{$vblob_id};

	if (exists($blobs{$vblob_id}) 
	    && $blobs{$vblob_id}->[2] eq $vfilename) {
	    # this one is a keeper, so mark it!
	    $blobs{$vblob_id}->[0] = 1;
	}
	else {
	    my $found = 0;
	    foreach my $rvblob_id (keys(%blobs)) {
		# if this one's a keeper, skip it!
		next 
		    if ($blobs{$rvblob_id}->[0]);

		# if the filenames match, we adjust the vblob_id field
		# in the blobs table to match what we have -- this leaves
		# the uuid<->filename mapping intact
		if ($blobs{$rvblob_id}->[2] eq $vfilename) {
		    my $uuid = $blobs{$rvblob_id}->[1];
		    $blobs{$vblob_id} = [ 1,$blobs{$rvblob_id}->[1],
					  $blobs{$rvblob_id}->[2] ];
		    DBQueryFatal("replace into blobs (uuid,vblob_id)" . 
				 " values ('$uuid','$vblob_id')");
		    $found = 1;
		    last;
		}
	    }

	    if (!$found) {
		# need to add this blob fresh!
		my $swapperuid = $self->swapper();
		DBQueryFatal("insert into blobs" . 
			     " (uuid,filename,owner_uid,vblob_id,exptidx)" . 
			     " values (UUID(),'$vfilename','$swapperuid'," . 
			     "   '$vblob_id',$idx)");
	    }
	}
    }

    #
    # Only remove real blobs if we're done using them (i.e., on a modify)
    #
    if ($update) {
	foreach my $vblob_id (keys(%blobs)) {
	    my ($keep,$uuid,$filename) = @{$blobs{$vblob_id}};
	    if (!$keep) {
		DBQueryFatal("delete from blobs" . 
			     "  where exptidx=$idx and vblob_id='${vblob_id}'");
	    }
	}
    }

    return 0;
}

#
# Remove any real blobs that were a result of a virt blob (i.e., those
# blobs that have our exptidx and a valid vblob_id).
#
sub RemoveBlobs($$)
{
    my ($self) = @_;

    # Must be a real reference. 
    return -1
	if (! ref($self));

    my $idx = $self->idx();

    my $qres = DBQueryFatal("delete from blobs using blobs" . 
			    " left join virt_blobs as vblobs" . 
			    "  on blobs.vblob_id=vblobs.vblob_id" . 
			    " where blobs.exptidx=$idx" . 
			    "  and vblobs.vblob_id is not NULL");

    # XXX: probably should clean out blob_files stuff too!

    return 0;
}

#
# Seed the virt_agents table.  Each lan/link needs an agent to handle
# changes to delays or other link parameters, and that agent (might be
# several) will be running on more than one node. Delay node agent,
# wireless agent, etc. They might be running on a node different then
# where the link is really (delay node). So, just send all link event
# to all nodes, and let them figure out what they should do (what to
# ignore, what to act on). So, specify a wildcard; a "*" for the vnode
# will be treated specially by the event scheduler, and no ipaddr will
# be inserted into the event. Second, add pseudo agents, one for each
# member of the link (or just one if a lan). The objname is lan-vnode,
# and allows us to send an event to just the agent controlling that
# link (or lan node delay). The agents will subscribe to these
# additional names when they start up.
#
sub SetupNetworkAgents($)
{
    my ($self) = @_;

    # Must be a real reference. 
    return -1
	if (! ref($self));

    my $pid = $self->pid();
    my $eid = $self->eid();
    my $idx = $self->idx();
    my $virtexp = $self->GetVirtExperiment();
    return -1
	if (!defined($virtexp));

    my %ethlans = ();  
    
    my $lan_members = $virtexp->Table("virt_lans");
    foreach my $member ($lan_members->Rows()) {
	my $vnode = $member->vnode();
	my $vlanname = $member->vname();
	my $bridgename = $member->bridge_vname();
	my $agentname;

	# A bridge connects two links, so the naming has to reflect that.
	# See libvtop and tmcd for corresponding changes.
	if (defined($bridgename)) {
	    $agentname = "${bridgename}-${vlanname}";
	}
	else {
	    $agentname = "${vlanname}-${vnode}";
	}

	DBQueryFatal("replace into virt_agents ".
		     " (exptidx, pid, eid, vname, vnode, objecttype) ".
		     " select '$idx', '$pid', '$eid', ".
		     "   '$agentname', '*', ".
		     "   idx from event_objecttypes where ".
		     "   event_objecttypes.type='LINK'");

	# I do not understand this.
	$ethlans{$vlanname} = $vlanname
	    if ($member->protocol() ne "ipv4");

	next
	    if (!$member->traced());

	DBQueryFatal("insert into virt_agents ".
		     " (exptidx, pid, eid, vname, vnode, objecttype) ".
		     " select '$idx', '$pid', '$eid', ".
		     "   '${vlanname}-${vnode}-tracemon', '*', ".
		     "   idx from event_objecttypes where ".
		     "   event_objecttypes.type='LINKTRACE'");
	
	DBQueryFatal("insert into event_groups ".
		     " (exptidx, pid, eid, idx, group_name, agent_name) ".
		     " values ('$idx', '$pid', '$eid', NULL, ".
		     "         '__all_tracemon', ".
		     "         '${vlanname}-${vnode}-tracemon')");

	my $groupname;
	if (defined($bridgename)) {
	    $groupname = "${bridgename}-tracemon";
	}
	else {
	    $groupname = "${vlanname}-tracemon";
	}
	DBQueryFatal("insert into event_groups ".
		     " (exptidx, pid, eid, idx, group_name, agent_name) ".
		     " values ('$idx', '$pid', '$eid', NULL, ".
		     "         '$groupname', ".
		     "         '${vlanname}-${vnode}-tracemon')");
    }

    #
    # Bridges have their own naming; each bridge gets a link agent.
    #
    my $bridge_members = $virtexp->Table("virt_bridges");
    foreach my $member ($bridge_members->Rows()) {
	my $bridgename = $member->vname();

	DBQueryFatal("replace into virt_agents ".
		     " (exptidx, pid, eid, vname, vnode, objecttype) ".
		     " select '$idx', '$pid', '$eid', '$bridgename', '*', ".
		     "   idx from event_objecttypes where ".
		     "   event_objecttypes.type='LINK'");
    }    

    my $lans = $virtexp->Table("virt_lan_lans");
    foreach my $lan ($lans->Rows()) {
	my $vlanname = $lan->vname();

	DBQueryFatal("insert into virt_agents ".
		     " (exptidx, pid, eid, vname, vnode, objecttype) ".
		     " select '$idx', '$pid', '$eid', '$vlanname', '*', ".
		     "   idx from event_objecttypes where ".
		     "   event_objecttypes.type='LINK'");

	if (exists($ethlans{$vlanname})) {
	    #
	    # XXX there is no link (delay) agent running on plab nodes
	    # (i.e., protocol==ipv4) currently, so we cannot be sending them
	    # events that they will not acknowledge.
	    #
	    DBQueryFatal("insert into event_groups ".
			 " (exptidx, pid, eid, idx, group_name, agent_name) ".
			 " values ('$idx', '$pid', '$eid', ".
			 "         NULL, '__all_lans', '$vlanname')");
	}
    }
    return 0;
}

#
# Add a program agents to address dynamically add nodes, such as a
# sharedhost node. 
#
sub AddInternalProgramAgent($$)
{
    my ($self, $vhost) = @_;

    # Must be a real reference. 
    return -1
	if (! ref($self));

    my $pid = $self->pid();
    my $eid = $self->eid();
    my $idx = $self->idx();

    #
    # This addresses the agent itself.
    #
    DBQueryWarn("replace into virt_agents ".
		" (exptidx, pid, eid, vname, vnode, objecttype) ".
		" select '$idx', '$pid', '$eid', ".
		"   '__${vhost}_program-agent', '$vhost', ".
		"   idx from event_objecttypes where ".
		"   event_objecttypes.type='PROGRAM'")
	or return -1;

    DBQueryWarn("replace into event_groups ".
		" (exptidx, pid, eid, idx, group_name, agent_name) ".
		" values ('$idx', '$pid', '$eid', NULL, ".
		"         '__all_program-agents', ".
		"         '__${vhost}_program-agent')")
	or return -1;

    #
    # And this is a generic program that can used.
    #
    DBQueryWarn("replace into virt_agents ".
		" (exptidx, pid, eid, vname, vnode, objecttype) ".
		" select '$idx', '$pid', '$eid', ".
		"   '${vhost}_program', '$vhost', ".
		"   idx from event_objecttypes where ".
		"   event_objecttypes.type='PROGRAM'")
	or return -1;

    DBQueryWarn("replace into virt_programs ".
		" (exptidx, pid, eid, vname, vnode, command) ".
		" values ('$idx', '$pid', '$eid', ".
		"         '${vhost}_program', '$vhost', ".
		"         '/bin/echo ready >>& /dev/null')")
	or return -1;

    return 0;
}

sub DeleteInternalProgramAgents($)
{
    my ($self, $vhost) = @_;

    # Must be a real reference. 
    return -1
	if (! ref($self));

    my $pid = $self->pid();
    my $eid = $self->eid();
    my $idx = $self->idx();

    my @nodelist = $self->NodeList();
    return 0
	if (! @nodelist);

    foreach my $node (@nodelist) {
	next
	    if ($node->erole() eq TBDB_RSRVROLE_NODE());

	my $vhost = $node->vname();

	DBQueryWarn("delete from virt_agents ".
		    "where exptidx='$idx' and ".
		    "      vname='__${vhost}_program-agent' and ".
		    "      vnode='$vhost'")
	    or return -1;

	DBQueryWarn("delete from event_groups ".
		    "where exptidx='$idx' and ".
		    "      group_name='__all_program-agents' and ".
		    "      agent_name='__${vhost}_program-agent'")
	    or return -1;

	DBQueryWarn("delete from virt_agents ".
		    "where exptidx='$idx' and ".
		    "      vname='${vhost}_program' and ".
		    "      vnode='$vhost'")
	    or return -1;

	DBQueryWarn("delete from virt_programs ".
		    "where exptidx='$idx' and ".
		    "      vname='${vhost}_program' and ".
		    "      vnode='$vhost'")
	    or return -1;
    }
    return 0;
}

#
# Write the virt program data for the program agent that will run on ops.
# Ops does not speak to tmcd for experiments, so need to get this info
# over another way. 
#
sub WriteProgramAgents($)
{
    my ($self) = @_;

    # Must be a real reference. 
    return -1
	if (! ref($self));

    my $pid = $self->pid();
    my $eid = $self->eid();

    my $query_result =
	DBQueryWarn("select vname,command,dir,timeout,expected_exit_code ".
		    "   from virt_programs ".
		    "where vnode='ops' and pid='$pid' and eid='$eid'");

    return -1
	if (!defined($query_result));
    return 0
	if (! $query_result->numrows);

    my $userdir  = $self->UserDir();
    my $progfile = "$userdir/tbdata/program_agents";

    if (!open(FP, "> $progfile")) {
	print "Could not open $progfile for writing: $!\n";
	return -1;
    }
    while (my ($name,$command,$dir,$timeout,$expected_exit_code) =
	   $query_result->fetchrow_array()) {
	print FP "AGENT=$name";
	print FP " DIR=$dir"
	    if (defined($dir) && $dir ne "");
	print FP " TIMEOUT=$timeout"
	    if (defined($timeout) && $timeout ne "");
	print FP " EXPECTED_EXIT_CODE=$expected_exit_code"
	    if (defined($expected_exit_code) && $expected_exit_code ne "");
	print FP " COMMAND='$command'\n";
    }
    if (! close(FP)) {
	print "Could not close $progfile: $!\n";
	return -1;
    }
    
    return 0;
}

#
# Return node status list for all nodes in the experiment. Status is defined
# as either up or down, which for now is going to be returned as 0,1.
#
sub NodeStatusList($$)
{
    my ($self, $prval) = @_;

    # Must be a real reference. 
    return -1
	if (! ref($self));

    my %results = ();
    my $pid = $self->pid();
    my $eid = $self->eid();

    my $query_result =
	DBQueryWarn("select r.node_id,n.status from reserved as r ".
		    "left join node_status as n on n.node_id=r.node_id ".
		    "where pid='$pid' and eid='$eid'");

    return -1
	if (!defined($query_result));
    
    while (my ($node_id,$status) = $query_result->fetchrow_array()) {
	# Skip nodes with no status info reported. 
	next
	    if (!defined($status) || $status eq "");
	
	$results{$node_id} = (($status eq "up") ? 1 : 0);
    }
    %$prval = %results;
    return 0;
}

#
# Setup the environment variables for a swapin.
#
sub InitializeEnvVariables($)
{
    my ($self) = @_;

    # Must be a real reference. 
    return -1
	if (! ref($self));

    $self->Refresh() == 0
	or return -1;

    if ($self->dpdb() && $self->dpdbname() && $self->dpdbname() ne "") {
	my $dpdbname     = $self->dpdbname();
	my $dpdbpassword = $self->dpdbpassword();
	my $dpdbuser     = "E" . $self->idx();

	$self->AddEnvVariable("DP_DBNAME", $dpdbname) == 0
	    or return -1;
	
	$self->AddEnvVariable("DP_HOST", $CONTROL) == 0
	    or return -1;

	$self->AddEnvVariable("DP_USER", $dpdbuser) == 0
	    or return -1;

	$self->AddEnvVariable("DP_PASSWORD", $dpdbpassword) == 0
	    or return -1;
    }
    
    return 0;
}

#
# Record a stamp event.
#
sub Stamp($$;$$$)
{
    my ($self, $type, $modifier, $aux_type, $aux_data) = @_;

    return 0
	if (! $STAMPS);

    # Must be a real reference. 
    return -1
	if (! ref($self));

    my $exptidx  = $self->idx();
    my $rsrcidx  = $self->rsrcidx();
    $modifier    = (defined($modifier) ? "'$modifier'" : "NULL");

    DBQueryWarn("insert into experiment_stamps set ".
		"  exptidx='$exptidx', id=NULL, rsrcidx='$rsrcidx', ".
		"  stamp_type='$type', modifier=$modifier, ".
		"  stamp=UNIX_TIMESTAMP(now()) ".
		(defined($aux_type) ?
		 ",aux_type='$aux_type',aux_data='$aux_data'" : ""))
	or return -1;

    return 0;
}

#
# DU experiment directory
#
sub DU($$)
{
    my ($self, $prval) = @_;

    # Must be a real reference. 
    return -1
	if (! ref($self));

    $$prval = 0;
    my $userdir = $self->UserDir();
    
    #
    # Start a subprocess that does the du, and then read it back.
    #
    if (!open(DU, "$DU -s -k $userdir |")) {
	print STDERR "DU: Could not start du!\n";
	return -1;
    }
    my $line;
    
    while (<DU>) {
	chomp($_);
	$line = $_;
    }
    return -1
	if (! close(DU));

    if ($line =~ /^(\d+)\s+/) {
	$$prval = $1;
	return 0;
    }
    return -1;
}

#
# Is this experiment a Template instance?
#
sub IsInstance($)
{
    my ($self) = @_;

    # Must be a real reference. 
    return 0
	if (! ref($self));

    if (defined($self->{'ISINSTANCE'})) {
	return $self->{'ISINSTANCE'};
    }
    my $idx = $self->idx();

    my $query_result =
	DBQueryWarn("select parent_guid from experiment_template_instances ".
		    "where exptidx='$idx'");

    return 0
	if (!$query_result);

    $self->{'ISINSTANCE'} = $query_result->numrows;
    return $self->{'ISINSTANCE'};
}

#
# Is this experiment the one underlying a template.
#
sub IsTemplate($)
{
    my ($self) = @_;

    # Must be a real reference. 
    return 0
	if (! ref($self));

    if (defined($self->{'ISTEMPLATE'})) {
	return $self->{'ISTEMPLATE'};
    }
    my $idx = $self->idx();

    my $query_result =
	DBQueryWarn("select guid from experiment_templates ".
		    "where exptidx='$idx'");

    return 0
	if (!$query_result);

    $self->{'ISTEMPLATE'} = $query_result->numrows;
    return $self->{'ISTEMPLATE'};
}

#
# Set the thumbnail for an experiment. Comes in as a binary string, which
# must be quoted before DB insertion. 
#
sub SetThumbNail($$)
{
    my ($self, $bindata) = @_;

    # Must be a real reference. 
    return 0
	if (! ref($self));

    my $rsrcidx = $self->rsrcidx();
    $bindata = DBQuoteSpecial($bindata);

    DBQueryWarn("update experiment_resources set thumbnail=$bindata ".
		"where idx=$rsrcidx") or return -1;
		
    return 0;
}

#
# Check experiment to see if all nodes are linktest capable, returning
# a list of nodes that are not.
#
sub LinkTestCapable($$)
{
    my ($self, $pref) = @_;
    my @result = ();

    # Must be a real reference. 
    return 0
	if (! ref($self));

    my $idx = $self->idx();

    my $query_result =
	DBQueryWarn("select v.vname, FIND_IN_SET('linktest',ov.osfeatures) ".
		    "  from virt_nodes as v ".
		    "left join reserved as r on r.pid=v.pid and ".
		    "     r.eid=v.eid and r.vname=v.vname ".
		    "left join nodes as n on n.node_id=r.node_id ".
		    "left join os_info_versions as ov on ".
		    "     ov.osid=n.def_boot_osid and ".
		    "     ov.vers=n.def_boot_osid_vers ".
		    "where v.exptidx='$idx' and v.role!='bridge'");
    return -1
	if (!defined($query_result));

    while (my ($vname,$gotlinktest) = $query_result->fetchrow_array()) {
	if (! defined($gotlinktest) || !$gotlinktest) {
	    push(@result, $vname);
	}
    }
    @$pref = @result;
    return 0;
}

#
# Map vname to reserved node.
#
sub VnameToNode($$)
{
    my ($self, $vname) = @_;

    # Must be a real reference. 
    return 0
	if (! ref($self));

    my $idx = $self->idx();

    my $query_result =
	DBQueryWarn("select node_id from reserved ".
		    "where exptidx='$idx' and vname='$vname'");

    return undef
	if (! $query_result ||
	    ! $query_result->num_rows);

    my ($node_id) = $query_result->fetchrow_array();    
    return Node->Lookup($node_id);
}

#
# Map vname to reserved node using the v2pmap table.
#
sub VnameToPmap($$)
{
    my ($self, $vname) = @_;

    # Must be a real reference. 
    return 0
	if (! ref($self));

    my $idx = $self->idx();

    my $query_result =
	DBQueryWarn("select node_id from v2pmap ".
		    "where exptidx='$idx' and vname='$vname'");

    return undef
	if (! $query_result ||
	    ! $query_result->num_rows);

    my ($node_id) = $query_result->fetchrow_array();    
    return Node->Lookup($node_id);
}

#
# Insert a virt_nodes entry, as needed when allocating a node to an
# experiment outside the NS file parsing path. Currently using this
# from the Geni sliver provisioning code.
#
sub InsertVirtNode($$;$)
{
    my ($self, $node, $type) = @_;
    my $node_id;

    # Must be a real reference. 
    if (ref($node)) {
	$node_id = $node->node_id();
	$type    = $node->type();
    }
    else {
	$node_id = $node;
	$type    = ""
	    if (!defined($type));
    }
    my $virtexperiment = $self->GetVirtExperiment();
    return -1
	if (!defined($virtexperiment));

    my $virtnode =
	$virtexperiment->NewTableRow("virt_nodes", {"vname" => $node_id});
    return -1
	if (!defined($virtnode));

    $virtnode->type($type);
    $virtnode->ips('');
    $virtnode->cmd_line('');
    $virtnode->startupcmd('');
    $virtnode->osname('');

    return -1
	if ($virtnode->Store() != 0);

    return 0;
}
sub DeleteVirtNode($$)
{
    my ($self, $node) = @_;
    my $node_id;

    if (ref($node)) {
	$node_id = $node->node_id();
    }
    else {
	$node_id = $node;
    }
    my $virtexperiment = $self->GetVirtExperiment();
    return -1
	if (!defined($virtexperiment));

    my $virtnode = $virtexperiment->Find("virt_nodes", $node_id);
    return 0
	if (!defined($virtnode));

    $virtnode->Delete() == 0
	or return -1;
    
    return 0;
}
sub HasVirtNode($$)
{
    my ($self, $node) = @_;
    my $node_id;

    if (ref($node)) {
	$node_id = $node->node_id();
    }
    else {
	$node_id = $node;
    }
    my $virtexperiment = $self->GetVirtExperiment();
    return undef
	if (!defined($virtexperiment));

    return $virtexperiment->Find("virt_nodes", $node_id);
}

#
# Unbind nonlocal users from this experiment.
#
sub UnBindNonLocalUsers($)
{
    my ($self) = @_;

    # Must be a real reference.
    return -1
	if (!ref($self));

    my $idx = $self->idx();

    #
    # Need to delete the pubkeys, so need a list of current bindings.
    #
    my $query_result =
	DBQueryWarn("select uid,uid_idx from nonlocal_user_accounts ".
		    "where exptidx='$idx'");
    return -1
	if (!$query_result);

    while (my ($uid, $uid_idx) = $query_result->fetchrow_array()) {
	DBQueryWarn("delete from nonlocal_user_pubkeys  ".
		    "where uid_idx='$uid_idx'")
	    or return -1;
	DBQueryWarn("delete from nonlocal_user_accounts  ".
		    "where uid_idx='$uid_idx'")
	    or return -1;
    }
    return 0;
}

#
# Bind nonlocal user to experiment (slice, in Geni).
#
sub BindNonLocalUser($$$$$$;$$)
{
    my ($self, $keys, $uid, $urn, $name, $email, $privs, $shell) = @_;

    return -1
	if (! ref($self));

    my $exptidx    = $self->idx();
    my $safe_urn   = DBQuoteSpecial($urn)
	if (defined($urn));
    my $safe_uid   = DBQuoteSpecial($uid);
    my $safe_name  = DBQuoteSpecial($name);
    my $safe_email = DBQuoteSpecial($email);
    my $uid_idx;

    #
    # User may already exist, as for updating keys.
    #
    my $query_result =
	DBQueryWarn("select uid_idx from nonlocal_user_accounts ".
		    "where uid=$safe_uid and exptidx='$exptidx'");
    return -1
	if (!$query_result);
    
    if ($query_result->numrows) {
	($uid_idx) = $query_result->fetchrow_array();

	# Mark for update.
	DBQueryWarn("update nonlocal_user_accounts set updated=now()  ".
		    "where uid_idx='$uid_idx'")
	    or return -1;
    }
    else {
	my @insert_data = ();
	
	$uid_idx = User->NextIDX();
	push(@insert_data, "created=now()");
	push(@insert_data, "updated=now()");
	push(@insert_data, "uid_idx='$uid_idx'");
	push(@insert_data, "unix_uid=NULL");
	push(@insert_data, "exptidx='$exptidx'");
	push(@insert_data, "urn=$safe_urn")
	    if (defined($urn));
	push(@insert_data, "uid=$safe_uid");
	push(@insert_data, "name=$safe_name");
	push(@insert_data, "email=$safe_email");
	push(@insert_data, "uid_uuid=uuid()");
	if (defined($privs)) {
	    my $safe_privs = DBQuoteSpecial($privs);
	    push(@insert_data, "privs=$safe_privs");
	}
	if (defined($shell)) {
	    my $safe_shell = DBQuoteSpecial($shell);
	    push(@insert_data, "shell=$safe_shell");
	}

	# Insert into DB.
	my $insert_result =
	    DBQueryWarn("insert into nonlocal_user_accounts set " .
			join(",", @insert_data));
    }

    #
    # Always replace the entire key set; easier to manage.
    #
    DBQueryWarn("delete from nonlocal_user_pubkeys  ".
		"where uid_idx='$uid_idx'")
	or return -1;

    foreach my $key (@{ $keys }) {
	my $safe_key = DBQuoteSpecial($key);

	DBQueryWarn("insert into nonlocal_user_pubkeys set ".
		    "  uid=$safe_uid, uid_idx='$uid_idx', ".
		    "  idx=NULL, stamp=now(), pubkey=$safe_key")
	    or return -1;
    }
    return 0;
}

sub HasNonLocalUsers($)
{
    my ($self) = @_;
    return 0
	if (! ref($self));

    my $exptidx    = $self->idx();
    my $query_result =
	DBQueryWarn("select count(*) from nonlocal_user_accounts ".
		    "where exptidx='$exptidx'");
    return 0
	if (!$query_result);
    
    if ($query_result->numrows) {
	my ($count) = $query_result->fetchrow_array();
	return $count > 0;
    } else {
	return 0;
    }
}

#
# Nonlocal users for this experiment.
#
sub NonLocalUsers($$)
{
    my ($self, $pref) = @_;
    my @result = ();

    # Must be a real reference.
    return -1
	if (!ref($self));

    my $idx = $self->idx();

    #
    # Need to find the pubkeys, so need a list of current bindings.
    #
    my $query_result =
	DBQueryWarn("select uid,uid_idx,urn from nonlocal_user_accounts ".
		    "where exptidx='$idx'");
    return -1
	if (!$query_result);

    while (my ($uid, $uid_idx, $urn) = $query_result->fetchrow_array()) {
	my $pubkeys_result =
	    DBQueryWarn("select pubkey from nonlocal_user_pubkeys ".
			"where uid_idx='$uid_idx'");
	return -1
	    if (!$pubkeys_result);

	my @pubkeys = ();
	while (my ($pubkey) = $pubkeys_result->fetchrow_array()) {
	    push(@pubkeys, {'type'   => 'ssh',
			    'key'    => $pubkey});
	}
	push(@result, {"urn"      => $urn,
		       "login"    => $uid,
		       "keys"     => \@pubkeys});
    }
    $$pref = \@result;
    return 0;
}

#
# Return physical interfaces for a link in an experiment.
#
sub LinkInterfaces($$$)
{
    my ($self, $linkname, $pref) = @_;
    my @result = ();
    require Interface;

    my $idx = $self->idx();

    my $query_result =
	DBQueryWarn("select i.node_id,i.uuid from virt_lans as vl ".
		    "left join interfaces as i on i.IP=vl.ip ".
		    "where vl.exptidx=$idx and vl.vname='$linkname'");
    return -1
	if (!$query_result || !$query_result->num_rows);

    while (my ($node_id,$uuid) = $query_result->fetchrow_array()) {
	my $linknode = Node->Lookup($node_id);
	my $linkexp  = $linknode->Reservation();
	return -1
	    if (!defined($linkexp) || !$self->SameExperiment($linkexp));

	my $interface = Interface->LookupByUUID($uuid);
	return -1
	    if (!defined($interface));

	push(@result, $interface);
    }
    @$pref = @result;
    return 0;
}

#
# Does the experiment have any geni nodes. Faster then checking all the nodes.
#
sub HasGeniNodes($)
{
    my ($self) = @_;

    # Must be a real reference.
    return -1
	if (!ref($self));

    my $idx = $self->idx();

    my $query_result =
	DBQueryFatal("select n.node_id from reserved as r ".
		     "left join nodes as n on n.node_id=r.node_id ".
		     "left join node_types as t on t.type=n.type ".
		     "where r.exptidx=$idx and t.isfednode=1");
    return -1
	if (!$query_result);
    return $query_result->num_rows;
}

#
# Does the experiment use any shared nodes.
#
sub HasSharedNodes($)
{
    my ($self) = @_;

    # Must be a real reference.
    return -1
	if (!ref($self));

    my $idx = $self->idx();

    my $query_result =
	DBQueryFatal("select n.node_id from reserved as r ".
		     "left join nodes as n on n.node_id=r.node_id ".
		     "left join node_types as t on t.type=n.type ".
		     "where r.exptidx=$idx and t.isvirtnode=1 and ".
		     "      r.sharing_mode is not null");
    return -1
	if (!$query_result);
    return $query_result->num_rows;
}

sub HasVirtNodes($)
{
    my ($self) = @_;

    # Must be a real reference.
    return -1
	if (!ref($self));

    my $idx = $self->idx();

    my $query_result =
	DBQueryFatal("select n.node_id from reserved as r ".
		     "left join nodes as n on n.node_id=r.node_id ".
		     "left join node_types as t on t.type=n.type ".
		     "where r.exptidx=$idx and t.isvirtnode=1");

    return -1
	if (!$query_result);
    return $query_result->num_rows;
}

sub HasPhysNodes($)
{
    my ($self) = @_;

    # Must be a real reference.
    return -1
	if (!ref($self));

    my $idx = $self->idx();

    my $query_result =
	DBQueryFatal("select n.node_id from reserved as r ".
		     "left join nodes as n on n.node_id=r.node_id ".
		     "left join node_types as t on t.type=n.type ".
		     "where r.exptidx=$idx and t.isvirtnode=0");

    return -1
	if (!$query_result);
    return $query_result->num_rows;
}

sub TypesInUse($)
{
    my ($self) = @_;
    my $idx = $self->idx();

    my $query_result =
	DBQueryFatal("SELECT DISTINCT(n.type) FROM " .
		     "reserved AS r, nodes AS n WHERE " .
		     "r.node_id=n.node_id AND " .
		     "r.exptidx='$idx'");

    my @types = ();
    while( my($type) = $query_result->fetchrow_array() ) {
	push( @types, $type );
    }
    return @types;
}

sub HasVirtInterfaces($)
{
    my ($self) = @_;

    # Must be a real reference.
    return -1
	if (!ref($self));

    my $idx = $self->idx();

    my $query_result =
	DBQueryWarn("select node_id from vinterfaces ".
		     "where exptidx=$idx");

    return -1
	if (!$query_result);
    return $query_result->num_rows;
}

#
# Return 1 if swapped in experiment is using a remote (SAN) blockstore.
# Returns 0 if not, -1 on error.
#
sub UsingRemBlockstore($)
{
    my ($self) = @_;

    # Must be a real reference.
    return -1
	if (!ref($self));

    # Must be swapped in or in the process of swapping out (PreSwap above)
    return -1
	if ($self->state() ne EXPTSTATE_ACTIVE &&
	    $self->state() ne EXPTSTATE_SWAPPING);

    my $idx = $self->idx();
    my $query_result =
	DBQueryWarn("select bs_id from reserved_blockstores ".
		     "where exptidx=$idx and bs_id like 'lease-%'");
    return -1
	if (!$query_result);

    return ($query_result->num_rows > 0);
}

#
# Set/Unset the lockdown bit.
#
sub LockDown($$)
{
    my ($self, $yesno) = @_;

    my $idx = $self->idx();
    my $lockdown = ($yesno ? 1 : 0);

    DBQueryWarn("update experiments set lockdown=$lockdown where idx=$idx")
	or return -1;
    return 0;
}

#
# Set/Get the port range for an experiment.
#
sub SetPortRange($$)
{
    my ($self, $impotent) = @_;
    $impotent = 0
	if (!defined($impotent));
    my $newlow;
    my $newhigh;
    my $lastlow;
    my $lasthigh;

    DBQueryWarn("lock tables ipport_ranges write") or
	return undef;

    my $range_result =
	DBQueryWarn("select low,high from ipport_ranges order by low");
    return undef
	if (!defined($range_result));

    if (!$range_result->num_rows) {
	$newlow = TBDB_LOWVPORT();
    }
    else {
	($lastlow, $lasthigh) = $range_result->fetchrow_array();

	# A hole at the bottom of the range ...
	if ($lastlow >= TBDB_LOWVPORT() + TBDB_PORTRANGE()) {
	    $newlow = TBDB_LOWVPORT();
	}
	# Else, find a free hole. 
	else {
	    while (my ($thislow,$thishigh) = $range_result->fetchrow_array()) {
		if ($thislow != $lasthigh + 1 &&
		    $thislow - $lasthigh > TBDB_PORTRANGE()) {
		    $newlow = $lasthigh + 1;
		    last;
		}
		$lasthigh = $thishigh;
	    }
	}
    }
    if (!defined($newlow)) {
	# No holes, tack onto the end. 
	$newlow = $lasthigh + 1;
    }
    if ($newlow >= TBDB_MAXVPORT()) {
	DBQueryWarn("unlock tables");
	return undef;
    }
    $newhigh = $newlow + TBDB_PORTRANGE() - 1;

    my $idx = $self->idx();
    my $pid = $self->pid();
    my $eid = $self->eid();

    if (! $impotent &&
	! DBQueryWarn("insert into ipport_ranges ".
		      " (exptidx, pid, eid, low, high) ".
		      "values ('$idx','$pid', '$eid', $newlow, $newhigh)")) {
	DBQueryWarn("unlock tables");
	return undef;
    }
    DBQueryWarn("unlock tables");
    return ($newlow, $newhigh);
}
sub GetPortRange($)
{
    my ($self) = @_;
    my $idx = $self->idx();

    my $query_result =
	DBQueryWarn("select low,high from ipport_ranges where exptidx=$idx");
    
    return undef
	if (!defined($query_result) || !$query_result->numrows);

    my ($low,$high) = $query_result->fetchrow_array();
    return ($low, $high);
}
#
# This has to be done at swapout, but not during a swapmod since
# that would mess up the existing port assignments.
# So it is a special case, not in the physicalTables list.
#
sub ClearPortRange($)
{
    my ($self) = @_;
    my $idx = $self->idx();

    DBQueryWarn("delete from ipport_ranges where exptidx=$idx")
	or return -1;

    return 0;
}

#
# Reserve all of the shared BW we need. The vinterfaces table has
# already been filled, and now we want to collect all that up for
# each node, and reserve it in the interface_state table. Locked
# of course.
#
# If this is an update.
#
sub ReserveSharedBandwidth($;$$)
{
    my ($self, $isupdate, $rollback) = @_;
    
    my $idx = $self->idx();
    my $pid = $self->pid();
    my $eid = $self->eid();
    my $pstateDir = $self->WorkDir() . "/pstate";
    my %current  = ();
    my %previous = ();
    my $previous_result;

    $isupdate = 0
	if (!defined($isupdate));
    $rollback = 0
	if (!defined($rollback));

    #
    # If this is an update, grab the old vinterfaces. Unless we are rolling
    # back, in which case we want the current vinterfaces table since it
    # has been restored by tbswap.
    #
    if ($isupdate) {
	DBQueryWarn("create temporary table if not exists ".
		    "vinterfaces_${idx} like vinterfaces")
	    or return -1;

	DBQueryWarn("delete from vinterfaces_${idx}")
	    or return -1;

	if (-e "$pstateDir/vinterfaces") {	
	    DBQueryWarn("load data infile '$pstateDir/vinterfaces' ".
			"into table vinterfaces_${idx}")
		or return -1;

	    $previous_result =
		DBQueryWarn("select node_id,unit,iface,bandwidth ".
			    "  from vinterfaces_${idx} ".
			    "where exptidx=$idx and bandwidth!=0 and ".
			    "      iface is not null ".
			    "order by node_id,unit");

	    return -1
		if (!$previous_result);
	}
    }

    DBQueryWarn("lock tables vinterfaces write, interface_state write ".
		($isupdate ? ", vinterfaces_${idx} write" : ""))
	or return -1;

    my $query_result =
	DBQueryWarn("select node_id,unit,iface,bandwidth from vinterfaces ".
		    "where exptidx=$idx and bandwidth!=0 and ".
		    "      iface is not null ".
		    "order by node_id,unit");
    goto bad
	if (!$query_result);
    goto good
	if (!$query_result->num_rows && !$isupdate);

    # Switcheroo on rollback; want to restore from old table. 
    if ($rollback) {
	my $tmp = $query_result;
	$query_result  = $previous_result;
	$previous_result = $tmp;
    }
    # Need to do this when we want to seek around inside the results.
    $previous_result = $previous_result->WrapForSeek()
	if (defined($previous_result));
    $query_result = $query_result->WrapForSeek();

    #
    # This is how much we need to release.
    #
    if ($isupdate && defined($previous_result)) {
	while (my ($node_id,$unit,$iface,$bw) =
	       $previous_result->fetchrow_array()) {

	    # Negative bw was not reserved.
	    next
		if ($bw <= 0);
	    
	    $previous{"$node_id:$iface"} = 0
		if (!exists($previous{"$node_id:$iface"}));

	    $previous{"$node_id:$iface"} += $bw;
	}
	$previous_result->dataseek(0);
    }

    #
    # Compute the per interface totals from the current table.
    #
    while (my ($node_id,$unit,$iface,$bw) = $query_result->fetchrow_array()) {
	$current{"$node_id:$iface"} = 0
	    if (!exists($current{"$node_id:$iface"}));

	#
	# In a swapin or update situation we are looking for negative values.
	# This is bandwidth we need to reserve from the current table.
	#
	# In a rollback situation, this is really the previous table,
	# and positive numbers mean bandwidth we already have reserved.
	# We do not need to reserve that again.
	#
	$current{"$node_id:$iface"} += (0 - $bw)
	    if ($bw < 0);
    }

    #
    # Now check the interface_state table for all of them to make sure
    # the operation is going to succeed.
    #
    foreach my $tmp (keys(%current)) {
	my ($node_id,$iface) = split(":", $tmp);
	my $bandwidth = $current{$tmp};

	#
	# Then modify the total if we are doing an update. This is how
	# much we really need.
	#
	if (exists($previous{$tmp})) {
	    $bandwidth -= $previous{$tmp};
	}
	# We are giving up more then we want.
	next
	    if ($bandwidth <= 0);

	my $check_result =
	    DBQueryWarn("select node_id,iface from interface_state ".
			"where node_id='$node_id' and iface='$iface' and ".
			"      remaining_bandwidth>=$bandwidth");
	goto bad
	    if (!$check_result);
	
	if (!$check_result->num_rows) {
	    print STDERR "Not enough reserve bandwidth; $bandwidth on $tmp\n";
	    DBQueryWarn("unlock tables");
	    return 1;
	}
    }

    #
    # In update mode, clear the bandwidth we currently have before
    # reserving the new bandwidth. Failure after this point can result
    # in the experiment getting swapped out if someone else picks up
    # the bw after the tables are unlocked. Not much to do about that.
    #
    if ($isupdate) {
	my $table = ($rollback ? "vinterfaces" : "vinterfaces_${idx}");
		     
	if (!DBQueryWarn("update interface_state,$table set ".
		     "     remaining_bandwidth=remaining_bandwidth+bandwidth,".
		     "     bandwidth=0-bandwidth ".
		     "where interface_state.node_id=${table}.node_id and ".
		     "      interface_state.iface=${table}.iface and ".
		     "      ${table}.exptidx='$idx' and ".
		     "      ${table}.iface is not null and ".
		     "      ${table}.bandwidth>0")) {
	    print STDERR "Could not release shared bandwidth\n";
	    goto bad;
	}
	#
	# Now that we have released the bw, replace the backup table
	# cause otherwise we will not know to reallocate the bw if
	# we fail and rollback.
	#
	if (!$rollback && -e $pstateDir) {
	    DBQueryWarn("select * from vinterfaces_${idx} ".
			"where exptidx='$idx' ".
			"order by node_id,unit ".
			"into outfile '$pstateDir/vinterfaces.$$' ")
		or goto bad;

	    if (mysystem("/bin/mv -f ".
			 "$pstateDir/vinterfaces.$$ $pstateDir/vinterfaces")) {
		print STDERR "Could not update $pstateDir/vinterfaces\n";
		goto bad;
	    }
	}
    }

    #
    # Now do it. We are going to process one at a time since we do
    # not have transactional commands with isam tables. Since we did
    # the check above, the only thing that can go wrong is a DB error,
    # in which case we are screwed anyway. 
    #
    $query_result->dataseek(0);
    
    while (my ($node_id,$unit,$iface,$bw) = $query_result->fetchrow_array()) {
	# Positive bw already reserved.
	next
	    if ($bw >= 0);
	
	my $rbw = 0 - $bw;
	my $table = ($rollback ? "vinterfaces_${idx}" : "vinterfaces");
	
	if (!DBQueryWarn("update interface_state,${table} set ".
			 "     remaining_bandwidth=remaining_bandwidth-$rbw, ".
			 "     bandwidth=$rbw ".
			 "where interface_state.node_id=${table}.node_id ".
			 "  and interface_state.iface=${table}.iface and ".
			 "      ${table}.node_id='$node_id' and ".
			 "      ${table}.iface='$iface' and ".
			 "      ${table}.unit='$unit'")) {
	    print STDERR "Could not reserve shared bandwidth $bw ($unit) on ".
		"$node_id:$iface\n";
	    goto bad;
	}
    }

    #
    # If this is a rollback, we have to undo what we did above
    # when we wrote out the modified vinterfaces_${idx} table
    # during the initial update. Otherwise that table will come
    # back in later with negative values (RestorePhysicalState()).
    #
    # A better approach perhaps is to move vinterfaces out of
    # BackupPhysicalState() and RestorePhysicalState() entirely. 
    #
    if ($rollback && -e $pstateDir) {
	DBQueryWarn("select * from vinterfaces_${idx} ".
		    "where exptidx='$idx' ".
		    "order by node_id,unit ".
		    "into outfile '$pstateDir/vinterfaces.$$' ")
	    or goto bad;

	if (mysystem("/bin/mv -f ".
		     "$pstateDir/vinterfaces.$$ $pstateDir/vinterfaces")) {
	    print STDERR "Could not update $pstateDir/vinterfaces\n";
	    goto bad;
	}
    }

  good:
    DBQueryWarn("unlock tables");
    return 0;
  bad:
    DBQueryWarn("unlock tables");
    return -1;
}

#
# Allocate per-experiment public address pools.
#
# Returns 0 on success, -1 on failure.
#
# This is atomic: on success, all addresses are allocated; on failure,
# everything is left unchanged.
#
# Current allocations are retained where appropriate, so this is suitable
# for use by swapmod.
#
sub AllocatePublicAddrPools($)
{
    my ($self) = @_;
    my $pid = $self->pid();
    my $eid = $self->eid();
    my %old_addrs;
    my %new_addrs;
    my %pools= ();
    my $db_result;
    
    DBQueryFatal( "LOCK TABLES virt_node_public_addr WRITE, " .
		  "virt_address_allocation READ" );
	
    $db_result = DBQueryWarn( "SELECT IP,pool_id FROM virt_node_public_addr " .
			      "WHERE pid='$pid' AND eid='$eid'" );
    while( my ($addr,$pool) = $db_result->fetchrow_array() ) {
	$old_addrs{$addr} = $pool;
    }

    $db_result = DBQueryWarn( "SELECT pool_id, count FROM virt_address_allocation " .
			      "WHERE pid='$pid' AND eid='$eid'" );
    while( my($pool,$count) = $db_result->fetchrow_array() ) {
	$pools{$pool} = $count;
    }

    # First, release any addresses we have and no longer need (we do
    # this eagerly, so we will never generate false failures on
    # allocation).
    while( my ($pool,$count) = each %pools ) {
	$db_result = DBQueryWarn( "SELECT COUNT(*) FROM virt_node_public_addr " .
				  "WHERE eid='$eid' AND pid='$pid' AND " .
				  "pool_id='$pool'" );
	my ($n) = $db_result->fetchrow_array();
	    
	if( $n > $count ) {
	    my $spare;

	    $spare = $n - $count;
	    DBQueryWarn( "UPDATE virt_node_public_addr SET eid=NULL, " .
			 "pid=NULL, pool_id=NULL WHERE eid='$eid' " .
			 "AND pid='$pid' AND pool_id='$pool' " .
			 "LIMIT $spare" );
	}
    }
	
    # Next, allocate any addresses we don't have and want.  If this
    # fails, we know the entire request is impossible to satisfy, because
    # we started with the table as close to empty as we could possibly
    # get.
    my $failed;
	
    while( my ($pool,$count) = each %pools ) {
	$db_result = DBQueryWarn( "SELECT COUNT(*) FROM virt_node_public_addr " .
				  "WHERE eid='$eid' AND pid='$pid' AND " .
				  "pool_id='$pool'" );
	my ($n) = $db_result->fetchrow_array();
	    
	if( $n < $count ) {
	    my $extra;

	    $extra = $count - $n;
	    DBQueryWarn( "UPDATE virt_node_public_addr SET eid='$eid', " .
			 "pid='$pid', pool_id='$pool' WHERE " .
			 "node_id IS NULL AND eid IS NULL " .
			 "LIMIT $extra" );
		    
	    $db_result = DBQueryWarn( "SELECT COUNT(*) FROM virt_node_public_addr " .
				      "WHERE eid='$eid' AND pid='$pid' AND " .
				      "pool_id='$pool'" );
	    ($n) = $db_result->fetchrow_array();

	    if( $n != $count ) {
		# Couldn't do it.  Roll back.
		DBQueryWarn( "UPDATE virt_node_public_addr SET " .
			     "eid=NULL, pid=NULL, pool_id=NULL WHERE " .
			     "eid='$eid' AND pid='$pid'" );
	    
		while( my ($addr,$pool) = each %old_addrs ) {
		    DBQueryWarn( "UPDATE virt_node_public_addr SET " .
				 "eid='$eid', pid='$pid', pool_id='$pool' " .
				 "WHERE IP='$addr'" );
		}

		DBQueryFatal( "UNLOCK TABLES" );
		# Return allocation failure to the user.
		return 1;
	    }
	}
    }
	
    $db_result = DBQueryWarn( "SELECT IP,pool_id FROM virt_node_public_addr " .
			      "WHERE pid='$pid' AND eid='$eid'" );
    while( my ($addr,$pool) = $db_result->fetchrow_array() ) {
	$new_addrs{$addr} = $pool;
    }

    DBQueryFatal( "UNLOCK TABLES" );

    # Record any changes made in addr_pool_history
    my $uid = $self->swapper();
    my $uid_idx = $self->swapper_idx();
    my $exptidx = $self->idx();
    
    while( my ($addr,$pool) = each( %old_addrs ) ) {
	if( !exists( $new_addrs{$addr} ) || $new_addrs{$addr} ne $pool ) {
	    DBQueryWarn( "INSERT INTO addr_pool_history SET " .
			 "pool_id='$pool', op='free', uid='$uid', " .
			 "uid_idx='$uid_idx', exptidx='$exptidx', " .
			 "stamp=UNIX_TIMESTAMP(), addr='$addr', " .
			 "version='ipv4'" );
	}
    }
    
    while( my ($addr,$pool) = each( %new_addrs ) ) {
	if( !exists( $old_addrs{$addr} ) || $old_addrs{$addr} ne $pool ) {
	    DBQueryWarn( "INSERT INTO addr_pool_history SET " .
			 "pool_id='$pool', op='alloc', uid='$uid', " .
			 "uid_idx='$uid_idx', exptidx='$exptidx', " .
			 "stamp=UNIX_TIMESTAMP(), addr='$addr', " .
			 "version='ipv4'" );
	}
    }
    
    return 0;
}

#
# Release per-experiment public address pools.
#
sub ReleasePublicAddrPools($)
{
    my ($self) = @_;
    my $pid = $self->pid();
    my $eid = $self->eid();
    my $uid = $self->swapper();
    my $uid_idx = $self->swapper_idx();
    my $exptidx = $self->idx();
    my $db_result;

    $db_result = DBQueryWarn( "SELECT IP,pool_id FROM virt_node_public_addr " .
			      "WHERE pid='$pid' AND eid='$eid'" );
    while( my ($addr,$pool) = $db_result->fetchrow_array() ) {
	DBQueryWarn( "INSERT INTO addr_pool_history SET " .
		     "pool_id='$pool', op='free', uid='$uid', " .
		     "uid_idx='$uid_idx', exptidx='$exptidx', " .
		     "stamp=UNIX_TIMESTAMP(), addr='$addr', " .
		     "version='ipv4'" );
    }
    
    DBQueryWarn( "UPDATE virt_node_public_addr SET pool_id=NULL, " .
		 "pid=NULL, eid=NULL WHERE pid='$pid' AND " .
		 "eid='$eid'" );

    return 0;
}

#
# Get/Set ElabInElab attributes.
#
sub GetElabInElabAttrs($)
{
    my ($self) = @_;
    my $idx = $self->idx();
    my $foo = {};

    my $query_result =
	DBQueryWarn("select * from elabinelab_attributes ".
		    "where exptidx='$idx'");

    return undef
	if (!$query_result);
    return $foo
	if (!$query_result->num_rows);

    while (my $row = $query_result->fetchrow_hashref()) {
	my $key   = $row->{'attrkey'};
	my $value = $row->{'attrvalue'};
	my $role  = $row->{'role'};
	my $order = $row->{'ordering'};

	if (!exists($foo->{$key})) {
	    $foo->{$key} = {};
	}
	if (!exists($foo->{$key}->{$role})) {
	    $foo->{$key}->{$role} = [];
	}
	$foo->{$key}->{$role}->[$order] = $value;
    }
    return $foo;
}

sub SetElabInElabAttr($$$$;$)
{
    my ($self, $role, $attrkey, $attrvalue, $ordering) = @_;
    my $idx = $self->idx();
    my $pid = $self->pid();
    my $eid = $self->eid();

    $ordering = 0
	if (!defined($ordering));

    my $safe_value = DBQuoteSpecial($attrvalue);

    DBQueryWarn("replace into elabinelab_attributes set ".
		"  pid='$pid', eid='$eid', exptidx='$idx', ".
		"  role='$role', attrkey='$attrkey', ".
		"  attrvalue=$safe_value, ordering='$ordering'")
	or return -1;

    return 0;
}

#
# Set the IP for the ops node in an elabinelab, when using a FreeBSD
# jail for ops (OPSVM). We have to do this early on, when boss is a
# XEN VM, since we have have to tell the vhost about the OPS IP so that
# it can adjust the firewall rules. Ick.
#
sub AssignElabInElabOpsIP($)
{
    my ($self) = @_;
    my $bossnode;
    my $ip;

    # Grab the elabinelab attributes for search.
    my $attributes = $self->GetElabInElabAttrs();
    return -1
	if (!defined($attributes) || !keys(%{$attributes}));

    # Only relevant if OPSVM defined.
    return 0
	if (!exists($attributes->{'CONFIG_OPSVM'}));

    #
    # Need to find the boss physical node and see if its a VM.
    #
    my @pnodes = $self->NodeList(0, 1);
    foreach my $pnode (@pnodes) {
	my $elabrole = $pnode->inner_elab_role();
	if (defined($elabrole) && $elabrole =~ /^boss/) {
	    $bossnode = $pnode;
	    last;
	}
    }
    return -1
	if (!defined($bossnode));

    #
    # If we have an address pool for 'opsvm' then allocate the IP
    # from that. Otherwise a jail IP.
    #
    my $ips = $self->LookupAddressPools("opsvm");
    if (@$ips) {
	my ($ref) = @{$ips};
	$ip = $ref->{'ip'};
	# XEN clientside looks at the *virt* attributes. 
	$self->SetVirtNodeAttribute($bossnode->vname(), "XEN_IPALIASES", $ip);
    }
    else {
	($ip) = $bossnode->GetJailIP();
    }
    print "Setting the IP for OPS jail to $ip\n";
    $self->SetElabInElabAttr("boss", "OPSIP", $ip);
    $self->SetElabInElabAttr("ops",  "OPSIP", $ip);
    $self->SetElabInElabAttr("fs",   "OPSIP", $ip);
    
    return 0;
}

#
# Check to see if an eid is valid.
#
sub ValidEID($$)
{
    my ($class, $eid) = @_;

    return TBcheck_dbslot($eid, "experiments", "eid",
			  TBDB_CHECKDBSLOT_WARN()|
			  TBDB_CHECKDBSLOT_ERROR());
}

#
# Mark as nonlocal.
#
sub MarkNonlocal($$$$)
{
    my ($self, $nonlocal_id, $nonlocal_user_id, $nonlocal_type) = @_;

    my $args = {"nonlocal_id"       => $nonlocal_id,
		"nonlocal_user_id"  => $nonlocal_user_id,
		"nonlocal_type"     => $nonlocal_type};

    return -1
	if ($self->Update($args));
    return -1
	if ($self->TableUpdate("experiment_stats", $args));

    return 0;
}

#
# Lookup a key/value pair from the virt_node_attributes table.
#
sub GetVirtNodeAttribute($$$$)
{
    my ($self, $vname, $key, $pval) = @_;
    $$pval = undef;

    my $exptidx  = $self->idx();
    my $safe_key = DBQuoteSpecial($key);

    my $query_result =
	DBQueryWarn("select attrvalue from virt_node_attributes ".
		    "where exptidx='$exptidx' and vname='$vname' and ".
		    "      attrkey=$safe_key");
    return -1
	if (!defined($query_result));
    return 0
	if (! $query_result->numrows);

    my ($val) = $query_result->fetchrow_array();
    $$pval = $val;
    return 0;
}

sub SetVirtNodeAttribute($$$$)
{
    my ($self, $vname, $key, $val) = @_;

    my $exptidx  = $self->idx();
    my $pid      = $self->pid();
    my $eid      = $self->eid();
    my $safe_key = DBQuoteSpecial($key);
    my $safe_val = DBQuoteSpecial($val);

    DBQueryWarn("replace into virt_node_attributes set ".
		"  pid='$pid', eid='$eid', exptidx='$exptidx', ".
		"  vname='$vname', attrkey=$safe_key, attrvalue=$safe_val")
	or return -1;

    return 0;
}

#
# Mark all nodes for (account) update.
#
sub MarkNodesForUpdate($)
{
    my ($self) = @_;

    my @nodelist = $self->NodeList(0, 1);
    return 0
	if (! @nodelist);

    foreach my $node (@nodelist) {
	next
	    if ($node->erole() eq TBDB_RSRVROLE_NODE());

	$node->MarkForUpdate();
    }
    return 0;
}

sub CancelNodeUpdates($)
{
    my ($self) = @_;

    my @nodelist = $self->NodeList(0, 1);
    return 0
	if (! @nodelist);

    foreach my $node (@nodelist) {
	next
	    if ($node->erole() eq TBDB_RSRVROLE_NODE());

	$node->CancelUpdate();
    }
    return 0;
}

#
# Return list of nodes that have not updated yet.
#
sub CheckUpdateStatus($$)
{
    my ($self, $pnotdone) = @_;
    my @tmp = ();

    my @nodelist = $self->NodeList(0, 1);
    return ()
	if (! @nodelist);

    foreach my $node (@nodelist) {
	next
	    if ($node->erole() eq TBDB_RSRVROLE_NODE());

	push(@tmp, $node);
    }
    my @done     = ();
    my @notdone  = ();

    return -1
	if (Node->CheckUpdateStatus(\@done, \@notdone, @tmp));

    return @notdone;
}

#
# Look for a lan with ports in another lan. These are currently labled
# with the incredibly obtuse "portlan" type instead of vlan. If one of
# these exist, then we have to call snmpit on the experiment that holds
# the target vlan so it can update its ports.
#
sub SyncPortLans($)
{
    my ($self) = @_;
    require Lan;

    my @lans;
    if (Lan->ExperimentLans($self, \@lans) != 0) {
	tberror("Could not get list of all lans for $self\n");
	return -1;
    }
    my %portlans = ();
    foreach my $lan (@lans) {
	next
	    if ($lan->type() ne "portlan");

	my $target_lanid;
	$lan->GetAttribute("target_lanid", \$target_lanid) == 0
	    or return -1;

	my $portvlan = Lan->Lookup($target_lanid);
	if (!defined($portvlan)) {
	    tberror("Could not lookup portvlan $target_lanid\n");
	    return -1;
	}

	#
	# Call snmpit once for each lan.
	#
	$portlans{$portvlan->lanid()} = $portvlan;
    }
    #
    # Now do it.
    #
    foreach my $idx (keys(%portlans)) {
	my $portvlan    = $portlans{$idx};
	my $experiment  = $portvlan->GetExperiment();
	return -1
	    if (!defined($experiment));
	
	my $pid = $experiment->pid();
	my $eid = $experiment->eid();

	#
	# The lan is obviously shared, so we have to lock it.
	# It should not spend much time locked though, so the
	# timeout should not be too long; indicates an error if
	# it is.
	#
	if ($portvlan->Lock(180) != 0) {
	    tberror("Could not lock $portvlan for a long time!\n");
	    return -1;
	}

	print "Syncing target vlan $idx in $experiment\n";
	mysystem("$TB/bin/snmpit -f --redirect-err -X $pid $eid $idx");
	if ($?) {
	    $portvlan->Unlock();
	    return -1;
	}
	$portvlan->Unlock();
    }
    return 0;
}

#
# When swapping in an experiment, need to copy the ports to the
# shared lans. 
#
sub SetupPortLans($)
{
    my ($self) = @_;
    require Lan;
    require snmpit_lib;

    my @lans;
    if (Lan->ExperimentLans($self, \@lans) != 0) {
	tberror("Could not get list of all lans for $self\n");
	return -1;
    }
    foreach my $lan (@lans) {
	next
	    if ($lan->type() ne "portlan");

	my $target_lanid;
	$lan->GetAttribute("target_lanid", \$target_lanid) == 0
	    or return -1;

	my $portvlan = Lan->Lookup($target_lanid);
	if (!defined($portvlan)) {
	    tberror("Could not lookup portvlan $target_lanid\n");
	    return -1;
	}

	#
	# The lan is obviously shared, so we have to lock it.
	# It should not spend much time locked though, so the
	# timeout should not be too long; indicates an error if
	# it is.
	#
	if ($portvlan->Lock(180) != 0) {
	    tberror("Could not lock $portvlan for a long time!\n");
	    return -1;
	}
	#
	# Once we get the lock, make sure the lan is actually still
	# shared. 
	#
	if ($portvlan->Refresh() != 0) {
	    tberror("Could not refresh $portvlan after locking!\n");
	    $portvlan->Unlock();
	    return -1;
	}
	if (! $portvlan->IsShared()) {
	    tberror("$portvlan is no longer shared!\n");
	    $portvlan->Unlock();
	    return -1;
	}

	#
	# The idea here is to remove any members for this lan
	# from the target lan, and then add the new ones. This
	# violates update, in that an error after this will not
	# restore the missing ports. Need to fix that.
	#
	my @members;
	if ($portvlan->MemberList(\@members) != 0) {
	    tberror("Could not get member list for $portvlan\n");
	    $portvlan->Unlock();
	    return -1;
	}
	foreach my $member (@members) {
	    my $member_exptidx;
	    my $member_lanname;
	    $member->GetAttribute("portlan_exptidx", \$member_exptidx);
	    $member->GetAttribute("portlan_lanname", \$member_lanname);

	    # Not a port in an external lan; a native port.
	    next
		if (!defined($member_exptidx) && !defined($member_lanname));

	    if (! (defined($member_exptidx) && defined($member_lanname))) {
		tberror("Could not get idx/lanname from $member\n");
		$portvlan->Unlock();
		return -1;
	    }
	    next
		if (! ($member_exptidx == $self->idx() &&
		       $member_lanname eq $lan->vname()));

	    if ($portvlan->DelMember($member)) {
		tberror("Could not delete $member from $portvlan\n");
		$portvlan->Unlock();
		return -1;
	    }
	}
	#
	# Now add new members.
	#
	if ($lan->MemberList(\@members) != 0) {
	    tberror("Could not get member list for $lan\n");
	    $portvlan->Unlock();
	    return -1;
	}
	foreach my $member (@members) {
	    my $nodeid;
	    my $iface;

	    $member->GetNodeIface(\$nodeid, \$iface);
	    my $newmember = $portvlan->AddMember($nodeid, $iface);
	    if (!defined($newmember)) {
		tberror("Could not add $member to $portvlan\n");
		$portvlan->Unlock();
		return -1;
	    }
	    # Mark where the member came from.
	    $newmember->SetAttribute("portlan_exptidx", $self->idx());
	    $newmember->SetAttribute("portlan_lanname", $lan->vname());
	}
	# Need the VLan class for this.
	my $vlan = VLan->Lookup($portvlan->lanid());
	$vlan->ClrSwitchPath();
	snmpit_lib::setSwitchTrunkPath($vlan);
	$portvlan->Unlock();
    }
    return 0;
}

#
# When swapping out an experiment, need to clear the ports from the
# shared lans. 
#
sub ClearPortLans($;$@)
{
    my ($self, $nolock, @lans) = @_;
    $nolock = 0 if (!defined($nolock));
    require Lan;
    require snmpit_lib;

    if (!@lans && Lan->ExperimentLans($self, \@lans) != 0) {
	tberror("Could not get list of all lans for $self\n");
	return -1;
    }
    my %portlans = ();
    foreach my $lan (@lans) {
	next
	    if ($lan->type() ne "portlan");

	my $target_lanid;
	$lan->GetAttribute("target_lanid", \$target_lanid) == 0
	    or return -1;

	my $portvlan = Lan->Lookup($target_lanid);
	if (!defined($portvlan)) {
	    tbinfo("portvlan $target_lanid no longer exists. Skipping ...\n");
	    next;
	}

	#
	# The lan is obviously shared, so we have to lock it.
	# It should not spend much time locked though, so the
	# timeout should not be too long; indicates an error if
	# it is.
	#
	if (!$nolock && $portvlan->Lock(180) != 0) {
	    tberror("Could not lock $portvlan for a long time!\n");
	    return -1;
	}

	#
	# Once we get the lock, make sure the lan is actually still
	# shared. 
	#
	if ($portvlan->Refresh() != 0) {
	    tberror("Could not refresh $portvlan after locking!\n");
	    $portvlan->Unlock()
		if (!$nolock);
	    return -1;
	}
	#
	# This does not need to be a fatal error since snmpit will not
	# allow a shared vlan to removed. The only way to get here is
	# if sharevlan -r -f is called, in which case the port was
	# forcibly yanked out of the target vlan already, so we can just
	# skip it. 
	#
	if (! $portvlan->IsShared()) {
	    $portvlan->Unlock()
		if (!$nolock);
	    next;
	}

	#
	# The idea here is to remove any members for this lan
	# from the target lan. Then sync the target. 
	#
	my @members;
	if ($portvlan->MemberList(\@members) != 0) {
	    tberror("Could not get member list for $portvlan\n");
	    $portvlan->Unlock()
		if (!$nolock);
	    return -1;
	}
	foreach my $member (@members) {
	    my $member_exptidx;
	    my $member_lanname;
	    $member->GetAttribute("portlan_exptidx", \$member_exptidx);
	    $member->GetAttribute("portlan_lanname", \$member_lanname);
	    
	    # Not a port in an external lan; a native port.
	    next
		if (!defined($member_exptidx) && !defined($member_lanname));

	    if (! (defined($member_exptidx) || defined($member_lanname))) {
		tberror("Could not get idx/lanname from $member\n");
		$portvlan->Unlock()
		    if (!$nolock);
		return -1;
	    }
	    next
		if (! ($member_exptidx == $self->idx() &&
		       $member_lanname eq $lan->vname()));

	    # Delete the member.
	    if ($portvlan->DelMember($member)) {
		tberror("Could not delete $member from $portvlan\n");
		$portvlan->Unlock()
		    if (!$nolock);
		return -1;
	    }
	}
	#
	# Call snmpit on the lan.
	#
	my $experiment = $portvlan->GetExperiment();
	if (!defined($experiment)) {
	    $portvlan->Unlock()
		if (!$nolock);
	    return -1;
	}
	if ($experiment->SyncPortLan($portvlan) != 0) {
	    $portvlan->Unlock()
		if (!$nolock);
	    return -1;
	}
	$portvlan->Unlock()
	    if (!$nolock);
    }
    return 0;
}

sub RemoveMembersFromPortlan($;$$@)
{
    my ($self, $nolock, $portvlan, @ports) = @_;
    $nolock = 0 if (!defined($nolock));
    require Lan;
    require snmpit_lib;
    my %portmap = map {$_ => $_} @ports;

    #
    # The lan is obviously shared, so we have to lock it.
    # It should not spend much time locked though, so the
    # timeout should not be too long; indicates an error if
    # it is.
    #
    if (!$nolock && $portvlan->Lock(180) != 0) {
	print STDERR "Could not lock $portvlan for a long time!\n";
	return -1;
    }
    #
    # Once we get the lock, make sure the lan is actually still
    # shared. 
    #
    if ($portvlan->Refresh() != 0) {
	print STDERR "Could not refresh $portvlan after locking!\n";
	$portvlan->Unlock()
	    if (!$nolock);
	return -1;
    }
    
    #
    # This does not need to be a fatal error since snmpit will not
    # allow a shared vlan to removed. The only way to get here is
    # if sharevlan -r -f is called, in which case the port was
    # forcibly yanked out of the target vlan already, so we can just
    # skip it. 
    #
    if (! $portvlan->IsShared()) {
	print STDERR "$portvlan is not a shared lan\n";
	$portvlan->Unlock()
	    if (!$nolock);
	return 0;
    }

    #
    # Remove the ports from the portvlan, then sync the target. 
    #
    my @members;
    if ($portvlan->MemberList(\@members) != 0) {
	print STDERR "Could not get member list for $portvlan\n";
	$portvlan->Unlock()
	    if (!$nolock);
	return -1;
    }
    foreach my $member (@members) {
	my $node;
	my $iface;

	if ($member->GetNodeIface(\$node, \$iface)) {
	    print STDERR "Could not get node/iface for $member\n";
	    $portvlan->Unlock()
		if (!$nolock);
	    return -1;
	}
	my $node_id = $node->node_id();
	
	next
	    if (!exists($portmap{"${node_id}:${iface}"}));

	print "Removing ${node_id}:${iface} from $portvlan\n";
	
	# Delete the member.
	if ($portvlan->DelMember($member)) {
	    print STDERR "Could not delete $member from $portvlan\n";
	    $portvlan->Unlock()
		if (!$nolock);
	    return -1;
	}
    }
    if ($self->SyncPortLan($portvlan) != 0) {
	$portvlan->Unlock()
	    if (!$nolock);
	return -1;
    }
    $portvlan->Unlock()
	if (!$nolock);
    return 0;
}

sub AddMembersToPortlan($;$$@)
{
    my ($self, $nolock, $portvlan, @ports) = @_;
    $nolock = 0 if (!defined($nolock));
    require Lan;
    require snmpit_lib;

    #
    # The lan is obviously shared, so we have to lock it.
    # It should not spend much time locked though, so the
    # timeout should not be too long; indicates an error if
    # it is.
    #
    if (!$nolock && $portvlan->Lock(180) != 0) {
	print STDERR "Could not lock $portvlan for a long time!\n";
	return -1;
    }
    #
    # Once we get the lock, make sure the lan is actually still
    # shared. 
    #
    if ($portvlan->Refresh() != 0) {
	print STDERR "Could not refresh $portvlan after locking!\n";
	$portvlan->Unlock()
	    if (!$nolock);
	return -1;
    }
    
    #
    # This does not need to be a fatal error since snmpit will not
    # allow a shared vlan to removed. The only way to get here is
    # if sharevlan -r -f is called, in which case the port was
    # forcibly yanked out of the target vlan already, so we can just
    # skip it. 
    #
    if (! $portvlan->IsShared()) {
	print STDERR "$portvlan is not a shared lan\n";
	$portvlan->Unlock()
	    if (!$nolock);
	return 0;
    }

    #
    # Add ports to the portvlan, then sync the target. 
    #
    foreach my $port (@ports) {
	my ($nodeid,$iface) = split(":", $port);
	
	if ($portvlan->IsMember($nodeid, $iface)) {
	    print "$port is already a member of lan, skipping addition\n";
	    next;
	}
	my $newmember = $portvlan->AddMember($nodeid, $iface);
	if (!defined($newmember)) {
	    print STDERR "Could not add $port to $portvlan\n";
	    $portvlan->Unlock()
		if (!$nolock);
	    return -1;
	}
    }
    if ($self->SyncPortLan($portvlan) != 0) {
	$portvlan->Unlock()
	    if (!$nolock);
	return -1;
    }
    $portvlan->Unlock()
	if (!$nolock);
    return 0;
}

#
# Call snmpit on a portvlan.
#
sub SyncPortLan($$)
{
    my ($self, $portvlan) = @_;
    require Lan;
    require snmpit_lib;

    my $vlan = VLan->Lookup($portvlan->lanid());
    $vlan->ClrSwitchPath();
    snmpit_lib::setSwitchTrunkPath($vlan);
	
    my $pid   = $self->pid();
    my $eid   = $self->eid();
    my $lanid = $portvlan->lanid();
	
    print "Syncing target vlan $lanid in $self\n";
    mysystem("$TB/bin/snmpit -f --redirect-err -X $pid $eid $lanid");
    if ($?) {
	return -1;
    }
    return 0;
}

#
# Return a list of just the lans that are using a shared vlan.
#
sub PortLanList($$)
{
    my ($self, $pref) = @_;
    my @result = ();
    require Lan;

    my @lans;
    if (Lan->ExperimentLans($self, \@lans) != 0) {
	tberror("Could not get list of all lans for $self\n");
	return -1;
    }
    foreach my $lan (@lans) {
	next
	    if ($lan->type() ne "portlan");

	push(@result, $lan);
    }
    @$pref = @result;
    return 0;
}

#
# Is this experiment sharing any vlans.
#
sub SharingVlans($)
{
    my ($self) = @_;
    my $idx = $self->idx();

    my $query_result =
	DBQueryWarn("select * from shared_vlans ".
		    "where exptidx='$idx'");
    return -1
	if (!$query_result);

    return $query_result->numrows;
}

#
# List of shared vlans
#
sub SharedVlanList($$)
{
    my ($self, $pref) = @_;
    my @result = ();
    my $idx = $self->idx();

    my $query_result =
	DBQueryWarn("select lanid from shared_vlans where exptidx='$idx'");
    return -1
	if (!$query_result);

    while (my ($lanid) = $query_result->fetchrow_array()) {
	my $vlan = VLan->Lookup($lanid);
	if (!defined($vlan)) {
	    tberror("Could not lookup shared vlan $lanid\n");
	    return -1;
	}
	push(@result, $vlan);
    }
    @$pref = @result;
    return 0;
}

#
# Do IP allocation for switch network fabrics that require it.
#
sub SetupNetworkFabrics($)
{
    my ($self)   = @_;
    my $idx      = $self->idx();

    #
    # Find any lans with the fabric setting. Order them for consistent
    # assignment. 
    #
    my $query_result =
	DBQueryWarn("select vname,capval from virt_lan_settings ".
		    "where exptidx='$idx' and ".
		    "      (capkey='network_fabric' or ".
		    "       capkey='switch_fabric') ".
		    "order by vname");

    return -1
	if (!defined($query_result));

    if (!$query_result->numrows) {
	#
	# Be sure to delete stale assignments.
	#
	DBQueryWarn("delete from global_ipalloc where exptidx='$idx'")
	    or return -1;
	return 0;
    }

    #
    # Get the current assignment so we can delete stale ones.
    #
    my %old_ips = ();
    my %new_ips = ();
	
    my $ip_result =
	DBQueryWarn("select ip,lanidx,member from global_ipalloc ".
		    "where exptidx='$idx'");
	
    return -1
	if (!$ip_result);

    while (my ($ip,$lanidx,$member) = $ip_result->fetchrow_array()) {
	$old_ips{"$lanidx:$member"} = $ip;
    }

    # Now get this after we are sure we need it.
    my $virtexp = $self->GetVirtExperiment();

    while (my ($lanname,$fabric) = $query_result->fetchrow_array()) {
	my $safe_fabric = DBQuoteSpecial($fabric);
	
	my $fabric_result =
	    DBQueryWarn("select * from network_fabrics ".
			"where name=$safe_fabric");
	return -1
	    if (!$fabric_result);
	
	if (! $fabric_result->numrows) {
	    print STDERR "*** No such fabric $fabric for $lanname\n";
	    return -1;
	}
	my $rowref = $fabric_result->fetchrow_hashref();
	# See if user is responsible.
	next
	    if (! $rowref->{'ipalloc'});

	my $fabidx  = $rowref->{'idx'};
	my $onenet  = $rowref->{'ipalloc_onenet'};
	my $subnet  = $rowref->{'ipalloc_subnet'};
	my $netmask = $rowref->{'ipalloc_netmask'};
	my $submask = $rowref->{'ipalloc_submask'};

	if (!$onenet) {
	    # Add this later.
	    print STDERR "*** Fabric $fabric is not onenet ipalloc!\n";
	    return -1;
	}

	DBQueryWarn("lock tables global_ipalloc write, ".
		    "            global_ipalloc as u1 write, ".
		    "            global_ipalloc as u2 write")
	    or return -1;

	#
	# This is so simplistic I could just call it moronic.
	#
	my $max = unpack("N", ~inet_aton($netmask)) - 1;

	#
	# Members for this lan.
	#
	my @members = ();

	foreach my $member ($virtexp->Table("virt_lans")->Rows()) {
	    next
		if ($member->vname() ne $lanname);
	    push(@members, $member);
	}

	#
	# Order the rows so that we get consistent allocation.
	#
	@members = sort {$a->vindex() <=> $b->vindex()} @members;

	# Need these below.
	my $virtlan = $virtexp->Table("virt_lan_lans")->Find($lanname);
	my $lanidx  = $virtlan->idx();

	# Process members.
	foreach my $member (@members) {
	    my $ip      = $member->ip();
	    my $midx    = $member->vindex();

	    #
	    # If the virtual topology specifies an ip in the subnet then
	    # try to use that one. This is not likely to happen, but
	    # look for it anyway. 
	    #
	    if (defined($ip) &&
		inet_ntoa(inet_aton($netmask) & inet_aton($ip)) eq $subnet) {

		my $ip_result =
		    DBQueryWarn("select lanidx,exptidx from global_ipalloc ".
				"where ip='$ip' and fabric_idx='$fabidx'");

		if (!$ip_result) {
		    DBQueryWarn("unlock tables");
		    return -1;
		}
		
		if (! $ip_result->numrows) {
		    # Safe to insert it;
		    goto insertip;
		}

		my ($lidx,$eidx) = $ip_result->fetchrow_array();

		# Checks if this IP is used someplace else in the
		# experiment. Do what the user wants since he owns it
		# already. 
		goto reuseip
		    if ($lidx == $lanidx && $eidx == $idx);

		# Some other experiment already has it.
		print STDERR "*** IP $ip for $member already in use. ";
		print STDERR "Allocating a new one for you.\n";
	    }
	    #
	    # Try to use existing IP, as for swapmod. Note that the
	    # virtual topo has been reloaded and previous assignment
	    # lost. So we have to go the global_ipalloc table to figure
	    # this out. 
	    #
	    if (exists($old_ips{"$lanidx:$midx"})) {
		$ip = $old_ips{"$lanidx:$midx"};
		if (!exists($new_ips{$ip})) {
		    goto reuseip;
		}
	    }
	    
	    #
	    # Try to find an unused ip.
	    #
	    my $ip_result =
		DBQueryWarn("select max(ipint) from global_ipalloc ".
			    "where fabric_idx='$fabidx'");
	    if (!$ip_result) {
		DBQueryWarn("unlock tables");
		return -1;
	    }

	    my ($curmax) = $ip_result->fetchrow_array();
	    if (!defined($curmax)) {
		$ip = inet_ntoa(inet_aton($subnet) | pack("N", 1));
	    }
	    elsif ($curmax < $max - 1) {
		$ip = inet_ntoa(inet_aton($subnet) | pack("N", $curmax + 1));
	    }
	    else {
		#
		# It is a pain to use mysql to find a free slot
		# in a big range of numbers. This is about the worst
		# way I could think of to do it. 
		#
		$ip_result =
		    DBQueryWarn("select u1.ipint,u2.ipint ".
				"  from global_ipalloc as u1 ".
				"left outer join global_ipalloc as u2 on ".
				"     u1.ipint-1=u2.ipint and ".
				"     u2.fabric_idx='$fabidx' ".
				"where u2.ipint is NULL and ".
				"      u1.ipint<$max and u1.ipint>1 and ".
				"      u1.fabric_idx='$fabidx'");

		if (!$ip_result) {
		    DBQueryWarn("unlock tables");
		    return -1;
		}
		if (!$ip_result->numrows) {
		    print STDERR "No free ip addresses for $member!";
		    DBQueryWarn("unlock tables");
		    return -1
		}
		my ($tmp) = $ip_result->fetchrow_array();
		$ip = inet_ntoa(inet_aton($subnet) | pack("N", $tmp - 1));
	    }
	  insertip:
	    # Need to do the row insertion and then move on.
	    my $ipint = unpack("N", (~inet_aton($netmask)) & inet_aton($ip));
	    if (!DBQueryWarn("insert into global_ipalloc set ".
			     "  fabric_idx='$fabidx', ipint=$ipint, ".
			     "  member='$midx', ".
			     "  exptidx=$idx, lanidx='$lanidx', ip='$ip'")) {
		DBQueryWarn("unlock tables");
		return -1;
	    }
	  reuseip:
	    $member->ip($ip);
	    $new_ips{$ip} = $ip;
	}
	DBQueryWarn("unlock tables");
    }
    #
    # Need to delete stale ones.
    #
    foreach my $ip (values(%old_ips)) {
	next
	    if (exists($new_ips{$ip}));

	DBQueryWarn("delete from global_ipalloc ".
		    "where ip='$ip' and exptidx='$idx'");
    }
    $virtexp->Store();
    return 0;
}

#
# This has to be done at swapout, but not during a swapmod since
# that would mess up the existing assignments.
#
sub ClearGlobalIPAllocation($)
{
    my ($self) = @_;
    my $idx = $self->idx();

    DBQueryWarn("delete from global_ipalloc where exptidx=$idx")
	or return -1;

    return 0;
}

#
# Find the blockstore details from the virt table. We should
# make this a first class object, but too lazy right now.
#
sub LookupBlockstore($$)
{
    my ($self, $bsname) = @_;
    my $blockstore = undef;
    
    # Now get this after we are sure we need it.
    my $virtexp = $self->GetVirtExperiment();
    
    foreach my $bs ($virtexp->Table("virt_blockstores")->Rows()) {
	if ($bs->vname() eq $bsname) {
	    $blockstore = $bs;
	    last;
	}
    }
    if (defined($blockstore)) {
	$blockstore->{'attributes'} = {};
	foreach my $row
	    ($virtexp->Table("virt_blockstore_attributes")->Rows()) {
	    if ($row->vname() eq $bsname) {
		$blockstore->{'attributes'}->{$row->attrkey()} =
		    $row->attrvalue();
	    }
	}
    }
    return $blockstore;
}

#
# Lookup blockstores for a node in the topology.
#
sub LookupBlockstoresForNode($$)
{
    my ($self, $vname) = @_;
    my @blockstores = ();
    
    # Now get this after we are sure we need it.
    my $virtexp = $self->GetVirtExperiment();
    
    foreach my $bs ($virtexp->Table("virt_blockstores")->Rows()) {
	if ($bs->fixed() eq $vname) {
	    my $blockstore = $self->LookupBlockstore($bs->vname());
	    if (!defined($blockstore)) {
		print STDERR "Could not get blockstore for $vname\n";
		return undef;
	    }
	    push(@blockstores, $blockstore);
	}
    }
    return @blockstores;
}

sub LookupAddressPools($$)
{
    my ($self, $pool_id_arg) = @_;
    my $result = [];
    my $virtexp = $self->GetVirtExperiment();

    my $eid = DBQuoteSpecial($self->eid());
    my $pid = DBQuoteSpecial($self->pid());
    my $pool_id = DBQuoteSpecial($pool_id_arg);
    my $dbresult =
	DBQueryWarn("select IP, mask ".
		    "from virt_node_public_addr ".
		    "where eid=$eid and ".
		    "pid=$pid and ".
		    "pool_id=$pool_id");
    while (my ($ip, $mask) = $dbresult->fetchrow_array()) {
	push(@{ $result },
	     { "ip" => $ip, "netmask" => $mask });
    }
    return $result;
}

#
# Add a profile parameter.
#
sub AddProfileParameter($$$)
{
    my ($self, $name, $value) = @_;

    # Must be a real reference. 
    return -1
	if (! ref($self));

    my $pid = $self->pid();
    my $eid = $self->eid();
    my $exptidx = $self->idx();

    if (defined($name)) {
	$name = DBQuoteSpecial($name);
    } else {
	return -1;
    }

    if (defined($value)) {
	$value = DBQuoteSpecial($value);
    } else {
	$value = "''";
    }

    DBQueryWarn( "REPLACE INTO virt_profile_parameters SET pid='$pid', " .
		 "eid='$eid', exptidx='$exptidx', name=$name, " .
		 "value=$value" )
	or return -1;
    
    return 0;
}

#
# Check for deprecated images.
#
sub CheckForDeprecatedImages($$$)
{
    my ($self, $user, $sendmail) = @_;
    my $pid = $self->pid();
    my $eid = $self->eid();
    my %needwarning = ();
    require OSImage;
    
    my $deprecated_result =
	DBQueryFatal("select vname,osname from virt_nodes ".
		     "where pid='$pid' and eid='$eid' and ".
		     "      osname is not null and osname!=''");
    while (my ($vname,$osname) = $deprecated_result->fetchrow_array()) {
	my $image = OSImage->Lookup($osname);
	if (!defined($image)) {
	    $image = OSImage->LookupByName($osname);
	    if (!defined($image)) {
		# Lets not worry, we will catch is later.
		next;
	    }
	}
	# Skip anything that looks like an OSID instead of an image.
	# XXX Need to deal with image aliases.
	next
	    if (! $image->isImage());
	
	my $deprecated = 0;
	my $iserror    = 0;
	if ($image->IsDeprecated(\$deprecated, undef, \$iserror)) {
	    tberror("Could not get deprecation info for $image\n");
	    return -1;
	}
	next
	    if (!$deprecated);

	if ($iserror && !$user->IsAdmin()) {
	    tberror($image->DeprecatedMessage() . "\n");
	    return 1;
	}
	$needwarning{$image->imageid()} = $image;
    }
    foreach my $image (values(%needwarning)) {
	print STDERR "*** WARNING: " . $image->DeprecatedMessage() . "\n";
	if ($sendmail) {
	    $image->SendDeprecatedMail($user, $self);
	}
    }
    return 0;
}

#
# Create rsa/ssh keys for experiment.
#
sub GenerateKeys($;$)
{
    my ($self,$rsa_privkey) = @_;
    my $rsa_pubkey;
    my $ssh_pubkey;
    my $errmsg;

    #
    # Generate unencrypted RSA key. 
    #
    if (!defined($rsa_privkey)) {
	$rsa_privkey = "";
	
	if (!open(RSA, "$OPENSSL genrsa 4096 2>/dev/null | ")) {
	    print STDERR "*** Could not start genrsa for RSA key\n";
	    return -1;
	}
	while (<RSA>) {
	    $rsa_privkey .= $_;
	}
	if (!close(RSA)) {
	    print STDERR "*** Could not generate RSA key\n";
	    return -1;
	}
    }
    #
    # Extract public key from it.
    #
    $rsa_pubkey =
	emutil::PipeCommand("$OPENSSL rsa -pubout 2>/dev/null",
			    $rsa_privkey, \$errmsg);
    if (!defined($rsa_pubkey) || $rsa_pubkey eq "") {
	print STDERR "*** Could not extract public RSA key\n";
	if (defined($errmsg)) {
	    print STDERR $errmsg;
	}
	return -1;
    }
    #
    # Extract SSH public key from it. Does not accept the privkey on stdin. SAD!
    #
    my $fp = File::Temp->new();
    if (!$fp) {
	print STDERR "*** Could not create temp file for RSA key\n";
	return -1;
    }
    print $fp $rsa_privkey;
    if (!open(GEN, "$SSHKEYGEN -y -f $fp |")) {
	print STDERR "*** Could not start ssh-keygen for RSA key\n";
	return -1;
    }
    while (<GEN>) {
	$ssh_pubkey .= $_;
    }
    if (!close(GEN)) {
	print STDERR "*** Could not extract SSH pub key from RSA key\n";
	return -1;
    }
    chomp($ssh_pubkey);
    my $pid = $self->pid();
    my $eid = $self->eid();
    my $idx = $self->idx();
    DBQueryWarn("replace into experiment_keys set ".
		"  pid='$pid', eid='$eid', exptidx='$idx', ".
		"  rsa_privkey=" . DBQuoteSpecial($rsa_privkey) . ", ".
		"  rsa_pubkey="  . DBQuoteSpecial($rsa_pubkey) . ", ".
		"  ssh_pubkey="  . DBQuoteSpecial($ssh_pubkey))
	or return -1;
    return 0;
}

#
# Return the per-experiment private key.
#
sub GetPrivkey($)
{
    my ($self) = @_;
    my $key = "";

    # Must be a real reference. 
    return -1
	if (! ref($self));

    my $idx = $self->idx();
    my $result = DBQueryWarn("select rsa_privkey from experiment_keys ".
			     "where exptidx='$idx'");
    if ($result && $result->numrows) {
	($key) = $result->fetchrow_array();
    }

    return $key;
}

#
# For all nodes in the experiment, determine which should receive
# per-experiment root private/public keys based on what the user wants
# and modified by Emulab policy (as encoded in Node::InitKeyDist).
#
# Here we enforce one bit of experiment-specific policy:
#
# If the user has set *any* key distribution manually within an experiment,
# we default all other unspecified nodes/keys to 0. The assumption here is
# that if the user specifies anything at all, they probably have a specific
# setup in mind and we don't want the resulting behavior to be different
# depending on the system default.
#
sub InitKeyDist($)
{
    my ($self) = @_;
    my $idx = $self->idx();

    #
    # Determine a default for all unspecified node key distributions:
    # - if the system default is "disabled", no key distribution is done
    # - if the user has specified any explicit values, the default is off
    # - otherwise use the on/off system default.
    #
    my $sysdef = -1;
    if (TBGetSiteVar("general/root_keypair", \$sysdef) && $sysdef != -1) {
	my $result =
	    DBQueryWarn("select v.rootkey_private,v.rootkey_public ".
			" from virt_nodes as v, reserved as r ".
			" where v.exptidx=r.exptidx and v.vname=r.vname ".
			"  and v.exptidx=$idx");

	if ($result && $result->numrows > 0) {
	    while (my ($priv,$pub) = $result->fetchrow_array()) {
		if ($priv != -1 || $pub != -1) {
		    $sysdef = 0;
		    last;
		}
	    }
	}
    }

    my @nodelist = $self->NodeList(0, 1);
    foreach my $node (@nodelist) {
	$node->InitKeyDist($self, $sysdef);
    }

    return 0;
}

#
# Return the portal URL for an experiment (if there is one).
#
sub PortalURL($)
{
    my ($self) = @_;
    require GeniSlice;

    if ($self->geniflags()) {
	my $slice = GeniSlice->LookupByExperiment($self);
	if (defined($slice)) {
	    return $slice->GetPortalURL();
	}
    }
    return undef;
}

# _Always_ make sure that this 1 is at the end of the file...
1;
