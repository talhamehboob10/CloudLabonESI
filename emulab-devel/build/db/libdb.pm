#!/usr/bin/perl -w
#
# Copyright (c) 2000-2020 University of Utah and the Flux Group.
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
# This library mostly contains old stuff that should phased out in
# favor of the per-object libraries in this directory.
#
# XXX: The notion of "uid" is a tad confused. A unix uid is a number,
#      while in the DB a user uid is a string (equiv to unix login).
#      Needs to be cleaned up.
#

package libdb;
use strict;
use Exporter;
use SelfLoader;
use vars qw(@ISA @EXPORT);
@ISA = qw(Exporter SelfLoader);

@EXPORT =
    qw ( MapNumericUID
	 TBSetCancelFlag TBGetCancelFlag
	 TBSetNodeEventState TBGetNodeEventState
	 TBNodeEventStateUpdated
	 TBSetNodeAllocState TBGetNodeAllocState
	 TBSetNodeOpMode TBGetNodeOpMode TBSetNodeNextOpMode
	 TBBootWhat TBNodeStateTimeout
	 TBAdmin TBNodeAccessCheck 
	 TBExptAccessCheck NodeidToExp 
	 ExpState
	 ExpNodes ExpNodeVnames ExpNodesOldReserved
	 DBDateTime DefaultImageID 
	 TBSetNodeLogEntry
	 TBOSID TBOSMaxConcurrent TBOSCountInstances
	 TBResolveNextOSID TBOsidToPid TBOSIDRebootWaittime
	 TBOSLoadMaxOkay TBImageLoadMaxOkay TBImageID 
	 TBdbfork VnameToNodeid 
	 TBIsNodeRemote 
	 TBIsNodeVirtual TBControlNetIP TBPhysNodeID
	 TBNodeUpdateAccountsByPid TBNodeUpdateAccountsByType
	 TBNodeUpdateAccountsByUID
	 TBExptWorkDir TBExptUserDir
	 TBIPtoNodeID TBNodeBootReset TBNodeStateWait
	 TBExptSetSwapUID TBExptSetThumbNail
	 TBPlabNodeUsername MarkPhysNodeDown
	 TBExptIsElabInElab TBExptIsPlabInElab
	 TBExptPlabInElabPLC TBExptPlabInElabNodes
	 TBBatchUnLockExp TBExptIsBatchExp
	 TBExptFirewall TBNodeFirewall TBExptFirewallAndIface
	 TBSetExptFirewallVlan TBClearExptFirewallVlan
	 TBNodeConsoleTail TBExptGetSwapoutAction TBExptGetSwapState
	 TBNodeSubNodes
	 TBNodeAdminOSID TBNodeRecoveryOSID TBNodeNFSAdmin TBNodeDiskloadOSID
	 TBNodeType TBNodeTypeProcInfo TBNodeTypeBiosWaittime
	 TBExptPortRange
	 TBWideareaNodeID TBTipServers
	 TBSiteVarExists TBGetSiteVar TBSetSiteVar
	 TBActivityReport GatherAssignStats
         AddPerExperimentSwitchStack UpdatePerExperimentSwitchStack
         DeletePerExperimentSwitchStack GetPerExperimentSwitchStack
         GetPerExperimentSwitchStackName
	 TBAvailablePCs
         max min 
	 hash_recurse array_recurse hash_recurse2 array_recurse2
	 TBExptMinMaxNodes TBExptSecurityLevel TBExptIDX
	 TBExptSetPanicBit TBExptGetPanicBit TBExptClearPanicBit
	 TBSetNodeHistory
	 TBRobotLabExpt
	 TBExptContainsNodeCT
	 TBPxelinuxConfig
	 );

use emdb;
use emutil;
use libEmulab;
use EmulabConstants;
use libtblog_simple;
use English;
use File::Basename;

# This line has to come before the requires.
@EXPORT = (@emutil::EXPORT, @emdb::EXPORT, @EmulabConstants::EXPORT, @EXPORT);

use vars qw($TB $TBOPS $BOSSNODE $TESTMODE $TBOPSPID $EXPTLOGNAME $PROJROOT);

# Configure variables
$TB	     = "/test";
$TBOPS       = "testbed-ops\@ops.cloudlab.umass.edu";
$BOSSNODE    = "boss.cloudlab.umass.edu";
$TESTMODE    = 0;
$TBOPSPID    = "emulab-ops";
$EXPTLOGNAME = "activity.log";
$PROJROOT    = "/proj";

sub TBdbfork()
{
    require event;
    
    event::EventFork();
}
sub hash_recurse2($%);
sub array_recurse2($%);

1;


# Local lookup for a Node, to avoid dragging in the module.
sub LocalNodeLookup($)
{
    require Node;

    return Node->Lookup($_[0]);
}
# Local lookup for an Experiment, to avoid dragging in the module.
sub LocalExpLookup(@)
{
    require Experiment;

    return Experiment->Lookup(@_);
}
# Local lookup for a Group, to avoid dragging in the module.
sub LocalGroupLookup(@)
{
    require Group;

    return Group->Lookup(@_);
}
# Local lookup for a NodeType, to avoid dragging in the module.
sub LocalNodeTypeLookup(@)
{
    require NodeType;

    return NodeType->Lookup(@_);
}
# Local lookup for a User, to avoid dragging in the module.
sub LocalUserLookup(@)
{
    require User;

    return User->Lookup(@_);
}
sub LocalUserLookupByUnixId(@)
{
    require User;

    return User->LookupByUnixId(@_);
}

# Local lookup for the control net interface
sub LocalInterfaceLookupControl($)
{
    require Interface;

    return Interface->LookupControl($_[0]);
}

#
# Auth stuff.
#
#
# Test admin status. Ignore argument; we only care if the current user
# has admin privs turned on.
#
# usage: TBAdmin();
#        returns 1 if an admin type.
#        returns 0 if a mere user.
#
sub TBAdmin(;$)
{
    require User;
    
    my $this_user = User->ThisUser();
    return 0
	if (! defined($this_user));

    return $this_user->IsAdmin();
}

#
# Experiment permission checks.
#
# Usage: TBExptAccessCheck($uid, $pid, $eid, $access_type)
#	 returns 0 if not allowed.
#        returns 1 if allowed.
#
sub TBExptAccessCheck($$$$)
{
    my ($uid, $pid, $eid, $access_type) = @_;

    #
    # Must map to an existing user to be trusted, obviously.
    #
    my $target_user = LocalUserLookupByUnixId($uid);
    return 0
	if (! defined($target_user));

    # Ditto the group
    my $experiment = LocalExpLookup($pid, $eid);
    return 0
	if (! defined($experiment));

    return $experiment->AccessCheck($target_user, $access_type);
}

#
# Determine if uid can access a node or list of nodes.
#
# Usage: TBNodeAccessCheck($uid, $access_type, $node_id, ...)
#	 returns 0 if not allowed.
#        returns 1 if allowed.
#
sub TBNodeAccessCheck($$@)
{
    my ($uid, $access_type) = (shift, shift);
    my @nodelist = @_;

    #
    # Must map to an existing user to be trusted, obviously.
    #
    my $target_user = LocalUserLookupByUnixId($uid);
    return 0
	if (! defined($target_user));
    return 1
	if ($target_user->IsAdmin());

    foreach my $nodeid (@nodelist) {
	my $node = LocalNodeLookup($nodeid);
	return 0
	    if (!defined($node));

	return 0
	    if (!$node->AccessCheck($target_user, $access_type));
    }
    return 1;
}

#
# Return Experiment state.
#
# usage: ExpState(char *pid, char *eid)
#        returns state if a valid pid/eid.
#        returns 0 if an invalid pid/eid or if an error.
#
sub ExpState($$)
{
    my ($pid, $eid) = @_;

    my $experiment = LocalExpLookup($pid, $eid);
    return 0
	if (!defined($experiment));
    return $experiment->state();
}

#
# Helper function for batch system.
#
sub TBBatchUnLockExp($$;$)
{
    my($pid, $eid, $newstate) = @_;
    my $BSTATE_UNLOCKED       = BATCHSTATE_UNLOCKED;
    
    my $query_result =
	DBQueryWarn("update experiments set expt_locked=NULL, ".
		    "       batchstate='$BSTATE_UNLOCKED' ".
		    (defined($newstate) ? ",state='$newstate' " : "") .
		    "where eid='$eid' and pid='$pid'");
    
    if (! $query_result ||
	$query_result->numrows == 0) {
	return 0;
    }
    
    if (defined($newstate)) {
	require event;
	
	event::EventSendWarn(objtype   => TBDB_TBEVENT_EXPTSTATE,
			     objname   => "$pid/$eid",
			     eventtype => $newstate,
			     expt      => "$pid/$eid",
			     host      => $BOSSNODE);
    }
    return 1;
}

#
# Set cancel flag,
#
# usage: SetCancelFlag(char *pid, char *eid, char *flag)
#        returns 1 if okay.
#        returns 0 if an invalid pid/eid or if an error.
#
sub TBSetCancelFlag($$$)
{
    my($pid, $eid, $flag) = @_;

    my $query_result =
	DBQueryWarn("update experiments set canceled='$flag' ".
		    "where eid='$eid' and pid='$pid'");

    if (! $query_result ||
	$query_result->numrows == 0) {
	return 0;
    }
    return 1;
}

#
# Get cancel flag,
#
# usage: TBGetCancelFlag(char *pid, char *eid, char **flag)
#        returns 1 if okay.
#        returns 0 if an invalid pid/eid or if an error.
#
sub TBGetCancelFlag($$$)
{
    my($pid, $eid, $flag) = @_;

    my $query_result =
	DBQueryWarn("select canceled from experiments ".
		    "where eid='$eid' and pid='$pid'");

    if (! $query_result ||
	$query_result->numrows == 0) {
	return 0;
    }
    ($$flag) = $query_result->fetchrow_array();
    return 1;
}

#
# Return a list of all the nodes in an experiment.
#
# usage: ExpNodes(char *pid, char *eid, [bool islocal])
#        returns the list if a valid pid/eid.
#	 If the optional flag is set, returns only local nodes.
#        Returns 0 if an invalid pid/eid or if an error.
#
sub ExpNodes($$;$$)
{
    my($pid, $eid, $localonly, $physonly) = @_;
    my(@row);
    my(@nodes);
    my $clause = "";

    if (defined($localonly) && $localonly) {
	$clause .= " and nt.isremotenode=0";
    }
    if (defined($physonly) && $physonly) {
	$clause .= " and nt.isvirtnode=0";
    }

    my $query_result =
	DBQueryWarn("select r.node_id from reserved as r ".
		    "left join nodes as n on n.node_id=r.node_id ".
		    "left join node_types as nt on nt.type=n.type ".
		    "where r.pid='$pid' and r.eid='$eid' $clause");

    if (! $query_result or
	$query_result->numrows == 0) {
	return ();
    }
    while (@row = $query_result->fetchrow_array()) {
	my $node = $row[0];

	#
	# Taint check. I do not understand this sillyness, but if I
	# taint check these node names, I avoid warnings throughout.
	#
	if ($node =~ /^([-\w]+)$/) {
	    $node = $1;

	    push(@nodes, $node);
	}
	else {
	    print "*** $0: WARNING: Bad node name: $node.\n";
	}
    }
    return @nodes;
}

#
# Return a hash of all the nodes in an experiment.  The hash maps pnames
# to vnames.
#
# usage: ExpNodeVnames(char *pid, char *eid, [bool islocal], [bool isphys])
#        returns the hash if a valid pid/eid.
#	 If the optional islocal is set, returns only local nodes.
#	 If the optional isphys is set, returns only physical nodes.
#        Returns 0 if an invalid pid/eid or if an error.
#
sub ExpNodeVnames($$;$$)
{
    my($pid, $eid, $localonly, $physonly) = @_;
    my(@row);
    my(%nodes);
    my $clause = "";

    if (defined($localonly)) {
	$clause = "and nt.isremotenode=0";
    }
    if (defined($physonly)) {
	$clause = "and nt.isvirtnode=0";
    }
    my $query_result =
	DBQueryWarn("select r.node_id,r.vname from reserved as r ".
		    "left join nodes as n on n.node_id=r.node_id ".
		    "left join node_types as nt on nt.type=n.type ".
		    "where r.pid='$pid' and r.eid='$eid' $clause");

    if (!$query_result || $query_result->numrows == 0) {
	return ();
    }
    while (@row = $query_result->fetchrow_array()) {
	my $node = $row[0];
	my $vname = $row[1];

	#
	# Taint check. I do not understand this sillyness, but if I
	# taint check these node names, I avoid warnings throughout.
	#
	if ($node =~ /^([-\w]+)$/) {
	    $node = $1;
	    if ($vname =~ /^([-\w]+)$/) {
		$vname = $1;
	    } else {
		$vname = $node;
	    }
	    $nodes{$node} = $vname;
	} else {
	    print "*** $0: WARNING: Bad node name: $node.\n";
	}
    }
    return %nodes;
}

#
# Find out what osid a node will boot next time it comes up,
# Usually (but not always) the currently running OS as well.
#
sub TBBootWhat($;$$)
{
    my ($nodeid, $debug, $wantfield) = @_;
    $debug = 0
	if (!defined($debug));
    $wantfield = 0
	if (!defined($wantfield));

    #
    # WARNING!!!
    #
    # DO NOT change this function without making corresponding changes to
    # pxe/bootinfo_mysql.c.
    #
    # ALWAYS find exactly the same resulting OSID given the same inputs.
    #
    my $query_result =
	DBQueryWarn("select def_boot_osid, vdef.op_mode, ".
		    "       temp_boot_osid, vtemp.op_mode, ".
		    "       next_boot_osid, vnext.op_mode ".
		    "from nodes as n ".
		    "left join os_info as odef  on odef.osid=def_boot_osid ".
		    "left join os_info_versions as vdef on ".
		    "     vdef.osid=odef.osid and vdef.vers=odef.version ".
		    "left join os_info as otemp on otemp.osid=temp_boot_osid ".
		    "left join os_info_versions as vtemp on ".
		    "     vtemp.osid=otemp.osid and vtemp.vers=otemp.version ".
		    "left join os_info as onext on onext.osid=next_boot_osid ".
		    "left join os_info_versions as vnext on ".
		    "     vnext.osid=onext.osid and vnext.vers=onext.version ".
		    "where node_id='$nodeid'");

    if (!$query_result || !$query_result->numrows) {
	print("*** Warning: No bootwhat info for $nodeid\n");
	return undef;
    }
    my ($def_boot_osid, $def_boot_opmode,
	$temp_boot_osid, $temp_boot_opmode,
	$next_boot_osid, $next_boot_opmode) = $query_result->fetchrow_array();

    my $boot_osid = 0;
    my $boot_opmode = 0;
    my $field = "";

    #
    # The priority would seem pretty clear.
    #
    if (defined($next_boot_osid) && $next_boot_osid ne 0) {
	$boot_osid = $next_boot_osid;
	$boot_opmode = $next_boot_opmode;
	$field = "next_boot_osid";
    }
    elsif (defined($temp_boot_osid) && $temp_boot_osid ne 0) {
	$boot_osid = $temp_boot_osid;
	$boot_opmode = $temp_boot_opmode;
	$field = "temp_boot_osid";
    }
    elsif (defined($def_boot_osid) && $def_boot_osid ne 0) {
	$boot_osid = $def_boot_osid;
	$boot_opmode = $def_boot_opmode;
	$field = "def_boot_osid";
    }
    #
    # If all info is clear, the node will boot into PXEWAIT.
    # This is not an error.
    #
    else {
	print("*** Warning: node '$nodeid': All boot info was null!\n");
    }

    # XXX hack for TBpxelinuxConfig below...
    if ($wantfield) {
	return $field;
    }

    return ($boot_osid, $boot_opmode);
}

#
# Note that this is a simplified version of what goes on in bootinfo.
# We are targetting just the Moonshot nodes where the choices are:
#
#   1. boot from THE disk
#   2. boot the frisbee MFS
#   3. boot a "general" MFS
#
# Its not yet clear how PXEWAIT will be handled. The nodes might be
# powered off in that state, or maybe we go into one of the MFSes to
# await further instructions.
#
sub TBPxelinuxConfig($;$)
{
    my ($node,$actionp) = @_;
    my $nodeid = $node->node_id();
    my $action;
    my $verbose = 1;
    my $field;

    if ($node->IsReserved() && ($field = TBBootWhat($nodeid, 0, 1))) {
	$action = "pxefail";

	my $query_result =
	    DBQueryWarn("SELECT v.path,v.mfs,p.`partition` FROM nodes AS n ".
			"  LEFT JOIN `partitions` AS p ON ".
			"    n.node_id=p.node_id AND ".
			"    n.${field}=p.osid ".
			"  LEFT JOIN os_info AS i ON ".
			"    n.${field}=i.osid ".
			"  LEFT JOIN os_info_versions AS v ON ".
			"    i.osid=v.osid AND i.version=v.vers ".
			"  WHERE n.node_id='$nodeid'");

	if (!$query_result || !$query_result->numrows) {
	    print("*** Warning: invalid bootinfo for $nodeid, ".
		  "booting to MFS\n");
	} else {
	    my ($path, $mfs, $part) = $query_result->fetchrow_array();

	    if (defined($path) && defined($mfs)) {
		# XXX how we identify the frisbee MFS
		if ($path =~ /frisbee/) {
		    $action = "mfsboot";
		} elsif ($path =~ /recovery/) {
		    $action = "recovery";
		} else {
		    $action = "nfsboot";
		}
	    } elsif (defined($part)) {
		$action = "diskboot";
	    } elsif (!$actionp && $field eq "def_boot_osid") {
		#
		# We are probably calling from OSSelect after changing
		# def_boot_osid but before loading the disk with that image.
		# Just leave it alone.
		#
		return;
	    } else {
		print("*** Warning: invalid $field info for $nodeid, ".
		      "booting to MFS\n");
	    }
	}
    } else {
	$action = "pxewait";
    }

    #
    # XXX if $actionp is set, we just want to return the action to take
    #
    if ($actionp) {
	$$actionp = $action;
	return;
    }

    my $cnet = LocalInterfaceLookupControl($node);
    if ($cnet && $cnet->mac() &&
	$cnet->mac() =~ /^(..)(..)(..)(..)(..)(..)$/) {
	my $nfile = "/tftpboot/pxelinux.cfg/01-$1-$2-$3-$4-$5-$6";

	# already exists, see if it is set correctly
	if (-e "$nfile" && open(FD, "<$nfile")) {
	    while (my $line = <FD>) {
		if ($line =~ /^ONTIMEOUT\s+(\S+)/) {
		    if ($1 eq $action) {
			close(FD);
			return;
		    }
		    last;
		}
	    }
	    close(FD);
	}

	# argh...gotta use a setuid script to install a new pxelinux config!
	if (!system("$TB/sbin/pxelinux_makeconf -d -a $action $nodeid")) {
	    print("$nodeid: set pxelinux boot to '$action'\n");
	    return;
	}

	print("*** Warning: $nodeid: could not update pxelinux config");
    } else {
	print("*** Warning: $nodeid: could not find MAC for cnet iface");
    }
    print (", who knows what it will boot!\n");
    return;
}

#
# Map nodeid to its pid/eid/vname. vname is optional.
#
# usage: NodeidToExp(char *nodeid, \$pid, \$eid, \$vname)
#        returns 1 if the node is reserved.
#        returns 0 if the node is not reserved.
#
sub NodeidToExp ($$$;$) {
    my($nodeid, $pid, $eid, $vname) = @_;

    my $query_result =
	DBQueryWarn("select pid,eid,vname from reserved ".
		    "where node_id='$nodeid'");

    if (! $query_result ||
	! $query_result->num_rows) {
	return 0;
    }

    my @row = $query_result->fetchrow_array();
    $$pid = $row[0];
    $$eid = $row[1];
    if (defined($vname)) {
	if (defined($row[2])) {
	    $$vname = $row[2];
	}
	else {
	    $$vname = undef;
	}
    }
    return 1;
}

#
# Map a pid/eid/vname to its real nodename
#
# usage: VnameToNodeid(char *pid, char * eid, char *vname, \$nodeid)
#        returns 1 if the specified pid/eid/vname exists
#        returns 0 if it does not
#
sub VnameToNodeid ($$$$) {
    my($pid, $eid, $vname, $nodeid) = @_;

    my $query_result =
	DBQueryWarn("select node_id from reserved ".
		    "where pid='$pid' and eid='$eid' and vname='$vname'");

    if (! $query_result ||
	! $query_result->num_rows) {
	return 0;
    }

    my @row = $query_result->fetchrow_array();
    $$nodeid = $row[0];
    return 1;
}


#
# Get the default ImageID for a particular node.
#
# usage: DefaultImageID(char *nodeid, \*imageid)
#        returns 1 if the node is valid and has a default imageid.
#                  Imageid is returned in reference param
#        returns 0 if there are problems.
#
sub DefaultImageID ($$) {
    my ($nodeid, $imageid) = @_;

    my $node = LocalNodeLookup($nodeid);

    if (! $node) {
	$$imageid = undef;
	return 0;
    }

    if ($node->NodeTypeAttribute("default_imageid", $imageid) ||
	$$imageid eq "") {
	$$imageid = undef;
	return 0;
    }
    return 1;
}

#
# Convert user pid/name to internal osid.
#
# usage: TBOSID(char *pid, char *isname)
#        returns osid if its valid.
#        returns 0 if not valid.
#
sub TBOSID($$) {
    my ($pid, $osname) = @_;
    require OSImage;

    my $osimage = OSImage->Lookup($pid, $osname);
    return 0
	if (!defined($osimage));
    return $osimage->osid();
}

#
# Return pid of an osid (internal name).
#
# usage: TBOsidToPid(char *osid, \$pid)
#        returns 1 if osid is valid; store pid into return arg.
#        returns 0 if osid is not valid.
#
sub TBOsidToPid ($$) {
    my($osid, $ppid) = @_;
    require OSImage;

    my $osimage = OSImage->Lookup($osid);
    return 0
	if (!defined($osimage));
    $$ppid = $osimage->pid();
    return 1;
}

#
# Returns the maximum number of concurrent instantiations of an image.
#
# usage: TBOSMaxConcurrent(char *osid)
#        returns >= 1 if there is a maximum number of concurrent instantiations
#        returns undef if there is no limi
#        returns 0 if not valid.
#
sub TBOSMaxConcurrent ($)
{
    my ($osid) = @_;
    require OSImage;

    my $osimage = OSImage->Lookup($osid);
    return 0
	if (!defined($osimage));
    return $osimage->max_concurrent();
}

#
# Returns the number of nodes that are supposedly booting an OS. A list of
# nodes that should be excluded from this count can be given.
#
# usage: TBOSCountInstances(char *osid; char *nodeid ...)
#        returns the number of nodes booting the OSID
#
sub TBOSCountInstances ($;@)
{
    my($osid,@exclude) = @_;

    my $nodelist = join(" or ",map("p.node_id='$_'",@exclude));
    if (!@exclude) {
	$nodelist = "0";
    }

    my $query_result = DBQueryFatal("select distinct p.node_id from `partitions` " .
	"as p left join reserved as r on p.node_id = r.node_id " .
	"where osid='$osid' and !($nodelist) and r.pid != '$TBOPSPID'");
    my $current_count = $query_result->num_rows();

    return $current_count;
}

#
# Resolve a 'generic' OSID (ie. FBSD-STD) to a real OSID
#
# Note: It's okay to call this function with a 'real' OSID, but it would be
# waseful to do so.
#
# usage: TBResolveNextOSID(char *osid, char *pid, char *eid)
# returns: The 'real' OSID that the OSID resolves to, or undef if there is a
#          problem (ie. unknown OSID)
#
sub TBResolveNextOSID($;$$)
{
    my ($osid,$pid,$eid) = @_;
    my $experiment;

    require OSImage;

    if (defined($pid) && defined($eid)) {
	$experiment = LocalExpLookup($pid, $eid);
	if (! defined($experiment)) {
	    warn "TBResolveNextOSID: No such experiment $pid/$eid\n";
	    return undef;
	}
    }
    my $osimage = OSImage->Lookup($osid);
    if (! defined($osimage)) {
	warn "TBResolveNextOSID: No such osid $osid\n";
	return undef;
    }
    my $nextosimage = $osimage->ResolveNextOSID($experiment);
    return undef
	if (!defined($nextosimage));
    return $nextosimage->osid();
}

#
# Check whether or not it's permissible, given max_concurrent restrictions, to
# load an OSID onto a number of nodes - the nodes themselves can be passed, so
# that they do no count twice (once in the count of current loads, and once in
# the count of potential loads.)
#
# usage: TBOSLoadMaxOkay(char *osid, int node_count; char *nodeid ... )
#        returns 1 if loading the given OS on the given number of nodes would
#            not go over the max_concurrent limit for the OS
#        returns 0 otherwise
#
sub TBOSLoadMaxOkay($$;@)
{
    my($osid,$node_count,@nodes) = @_;

    if (TBAdmin()) {
	return 1;
    }

    my $max_instances = TBOSMaxConcurrent($osid);
    if (!$max_instances) {
	return 1;
    }

    my $current_instances = TBOSCountInstances($osid,@nodes);

    if (($current_instances + $node_count) > $max_instances) {
	return 0;
    } else {
	return 1;
    }
}

#
#
# Check whether or not it's permissible, given max_concurrent restrictions, to
# load an image onto a number of nodes - simply checks all OSIDs on the image.
#
# usage: TBImageLoadMaxOkay(char *imageid, int node_count; char *nodeid ... )
#        returns 1 if loading the given image on the given number of nodes
#        	would not go over the max_concurrent limit for any OS im the
#        	image
#        returns 0 otherwise
#
sub TBImageLoadMaxOkay($$;@)
{
    my($imageid,$node_count,@nodes) = @_;


    my $query_result =
	DBQueryFatal("select v.part1_osid, v.part2_osid, " .
		     "  v.part3_osid, v.part4_osid from images as i ".
		     "left join image_versions as v on ".
		     "     v.imageid=i.imageid and v.version=i.version ".
		     "where i.imageid='$imageid'");

    if ($query_result->num_rows() != 1) {
	#
	# XXX - Just pretend everything is OK, something else will presumably
	# have to check the imageid anyway
	#
	return 1;
    }

    foreach my $OS ($query_result->fetchrow()) {
	if ($OS && (!TBOSLoadMaxOkay($OS,$node_count,@nodes))) {
	    return 0;
	}
    }

    return 1;
}

#
# Insert a Log entry for a node.
#
# usage: TBSetNodeLogEntry(char *node, char *uid, char *type, char *message)
#        Returns 1 if okay.
#        Returns 0 if failed.
#
sub TBSetNodeLogEntry($$$$)
{
    my ($node_id, $dbuid, $type, $message) = @_;

    my $node = LocalNodeLookup($node_id);
    return 0
	if (! defined($node));

    return ($node->InsertNodeLogEntry(LocalUserLookup($dbuid),
				      $type, $message) == 0 ? 1 : 0);
}

#
# Set event state for a node.
#
# usage: TBSetNodeEventState(char *node, char *state; int fatal)
#        Returns 1 if okay.
#        Returns 0 if failed.
#
sub TBSetNodeEventState($$;$)
{
    my ($node, $state, $fatal) = @_;

    if (!ref($node)) {
	$node = LocalNodeLookup($node);
    }
    my $rc = $node->SetEventState($state, $fatal);
    return (($rc == 0) ? 1 : 0);
}

#
# Get event state for a node.
#
# usage: TBGetNodeEventState(char *node, char \*state)
#        Returns 1 if okay (and sets state).
#        Returns 0 if failed.
#
sub TBGetNodeEventState($$)
{
    my ($node, $state) = @_;

    my $query_result =
	DBQueryFatal("select eventstate from nodes where node_id='$node'");

    if ($query_result->numrows == 0) {
	return 0;
    }
    my @row = $query_result->fetchrow_array();
    if (defined($row[0])) {
	$$state = $row[0];
    }
    else {
	$$state = TBDB_NODESTATE_UNKNOWN;
    }
    return 1;
}

#
# Check if the event state for a node was updated recently.
#
# usage: TBNodeEventStateUpdated(char *node, int tolerance)
#        Returns 1 if the state was updated.
#        Returns 0 if failed.
#
sub TBNodeEventStateUpdated($$)
{
    my ($node, $tol) = @_;

    my $query_result =
	DBQueryFatal("select UNIX_TIMESTAMP(now()) - state_timestamp < $tol ".
		     "from nodes where node_id='$node'");

    if ($query_result->numrows == 0) {
	return 0;
    }
    my ($under) = $query_result->fetchrow_array();

    return $under;
}

#
# Check if a node has timed out in its current state. If it has, it gets
# stated involved to handle the situation.
#
# usage: TBNodeStateTimeout(char *node)
#        Returns 1 if it has timed out and stated was notified
#        Returns 0 if it is okay (still within time limits)
#
sub TBNodeStateTimeout($)
{
    my ($node) = @_;

    my $notimeout = TBDB_NO_STATE_TIMEOUT;

    my $query_result =
	DBQueryFatal("select now() - state_timestamp > timeout as over, ".
		     "timeout='$notimeout' as none ".
		     "from nodes as n left join state_timeouts as st ".
		     "on n.eventstate=st.state and n.op_mode=st.op_mode ".
		     "where node_id='$node'");

    if ($query_result->numrows == 0) {
	warn("*** TBNodeStateTimeout: Couldn't check node '$node'\n");
	return 0;
    }
    my ($over,$none) = $query_result->fetchrow_array();
    if ($over && !$none) {
	# We're overtime... send an event and return 1
	require event;

	event::EventSendFatal(objtype   => TBDB_TBEVENT_CONTROL,
			      objname   => $node,
			      eventtype => TBDB_TBCONTROL_TIMEOUT,
			      host      => $BOSSNODE);
	return 1;
    } else {
	# We're good... return 0
	return 0;
    }
}

#
# Set operational mode for a node.
#
# usage: TBSetNodeOpMode(char *node, char *mode)
#        Returns 1 if okay.
#        Returns 0 if failed.
#
# DEPRECATED - stated handles these transitions now. See TBSetNodeNextOpMode
# below.
#
sub TBSetNodeOpMode($$)
{
    my ($node, $mode) = @_;

    #
    # If using the event system, we send out an event for the state daemon to
    # pick up. Otherwise, we just set the mode in the database ourselves
    #
    require event;

    return event::EventSendFatal(objtype   => TBDB_TBEVENT_NODEOPMODE,
				 objname   => $node,
				 eventtype => $mode,
				 host      => $BOSSNODE);
}

#
# Set the next operational mode for a node.
#
# usage: TBSetNodeNextOpMode(char *node, char *mode)
#        Returns 1 if okay.
#        Returns 0 if failed.
#
sub TBSetNodeNextOpMode($$)
{
    my ($node, $mode) = @_;

    #
    # Just set it in the DB. The next time the node changes state, stated will
    # make the transition happen.
    #
    return DBQueryFatal("update nodes set next_op_mode='$mode' " .
	"where node_id='$node'");
}

#
# Get operational mode for a node.
#
# usage: TBGetNodeOpMode(char *node, char \*mode)
#        Returns 1 if okay (and sets state).
#        Returns 0 if failed.
#
sub TBGetNodeOpMode($$)
{
    my ($node, $mode) = @_;

    my $query_result =
	DBQueryFatal("select op_mode from nodes where node_id='$node'");

    if ($query_result->numrows == 0) {
	return 0;
    }
    my @row = $query_result->fetchrow_array();
    if (defined($row[0])) {
	$$mode = $row[0];
    }
    else {
	$$mode = TBDB_NODEOPMODE_UNKNOWN;
    }
    return 1;
}


#
# Set alloc state for a node.
#
# usage: TBSetNodeAllocState(char *node, char *state)
#        Returns 1 if okay.
#        Returns 0 if failed.
#
sub TBSetNodeAllocState($$)
{
    my ($node, $state) = @_;
    my $now = time();
    return DBQueryFatal("update nodes set allocstate='$state', " .
			"allocstate_timestamp=$now where node_id='$node'");
}

#
# Get alloc state for a node.
#
# usage: TBGetNodeAllocState(char *node, char \*state)
#        Returns 1 if okay (and sets state).
#        Returns 0 if failed.
#
sub TBGetNodeAllocState($$)
{
    my ($node, $state) = @_;

    my $query_result =
	DBQueryFatal("select allocstate from nodes where node_id='$node'");

    if ($query_result->numrows == 0) {
	return 0;
    }
    my @row = $query_result->fetchrow_array();
    if (defined($row[0])) {
	$$state = $row[0];
    }
    else {
	$$state = TBDB_ALLOCSTATE_UNKNOWN;
    }
    return 1;
}

#
# Is a node remote?
#
# usage TBIsNodeRemote(char *node)
#        Returns 1 if yes.
#        Returns 0 if no.
#
sub TBIsNodeRemote($)
{
    my ($nodeid) = @_;

    my $query_result =
	DBQueryFatal("select isremotenode from nodes as n ".
		     "left join node_types as t on t.type=n.type ".
		     "where n.node_id='$nodeid'");

    if (! $query_result->num_rows) {
	return 0;
    }

    my @row = $query_result->fetchrow_array();
    return($row[0]);
}

#
# Is a node virtual (or "multiplexed"). Optionally return jailflag and a
# Plab flag.
#
# usage TBIsNodeVirtual(char *node, int *jailed, int *plabbed)
#        Returns 1 if yes.
#        Returns 0 if no.
#
sub TBIsNodeVirtual($;$$)
{
    my ($nodeid, $jailed, $plabbed) = @_;

    my $query_result =
	DBQueryFatal("select isvirtnode,n.jailflag,t.isplabdslice ".
		     "from nodes as n ".
		     "left join node_types as t on t.type=n.type ".
		     "where n.node_id='$nodeid'");

    if (! $query_result->num_rows) {
	return 0;
    }

    my @row = $query_result->fetchrow_array();
    if (defined($jailed)) {
	$$jailed = $row[1];
    }
    if (defined($plabbed)) {
	$$plabbed = $row[2];
    }
    return($row[0]);
}

#
# Get the username used to log in to a particular vnode allocated on Plab
#
# usage TBPlabNodeUsername(char *node, char \*username)
#        Returns 1 if successful
#        Returns 0 if node is not allocated with Plab
#
sub TBPlabNodeUsername($$)
{
    my ($nodeid, $username) = @_;

    my $query_result =
	DBQueryFatal("select slicename from plab_slice_nodes ".
		     "where node_id='$nodeid'");

    if (! $query_result->num_rows) {
	return 0;
    }

    my @row = $query_result->fetchrow_array();
    if (defined($row[0])) {
	$$username = $row[0];
	return 1;
    }
    return 0;
}

#
# Mark a Phys node as down. Cannot use next reserve since the pnode is not
# going to go through the free path.
#
# usage: MarkPhysNodeDown(char *nodeid)
#
sub MarkPhysNodeDown($)
{
    my($pnode) = $_[0];
    my($pid, $eid);

    $pid = NODEDEAD_PID;
    $eid = NODEDEAD_EID;
    
    my $exptidx;
    if (!TBExptIDX($pid, $eid, \$exptidx)) {
	print "*** WARNING: No such experiment $pid/$eid!\n";
	return -1;
    }

    DBQueryFatal("update reserved set " .
		 "  exptidx=$exptidx, pid='$pid',eid='$eid',rsrv_time=now() ".
		 "where node_id='$pnode'");

    TBSetNodeHistory($pnode, TB_NODEHISTORY_OP_MOVE, $UID, $pid, $eid);
}

#
# Return the IDX for a current experiment. 
#
# usage: TBExptIDX(char $pid, char *gid, int \$idx)
#        returns 1 if okay.
#	 returns 0 if error.
#
sub TBExptIDX($$$)
{
    my($pid, $eid, $idxp) = @_;

    my $query_result =
	DBQueryWarn("select idx from experiments ".
		    "where pid='$pid' and eid='$eid'");

    if (!$query_result || !$query_result->numrows) {
	return 0;
    }
    my ($idx) = $query_result->fetchrow_array;
    $$idxp = $idx;
    return 1;
}

#
# Return the log directory name for an experiment. This is where
# we keep copies of the files for later inspection.
#
sub TBExptWorkDir($$)
{
    my($pid, $eid) = @_;

    return TBDB_EXPT_WORKDIR() . "/${pid}/${eid}";
}

#
# Return the user's experiment directory name. This is a path in the /proj
# tree. We keep these separate to avoid NFS issues, and users generally
# messing with things they should not (by accident or otherwise).
#
sub TBExptUserDir($$)
{
    my($pid, $eid) = @_;

    my $query_result =
	DBQueryFatal("select path from experiments ".
		     "where pid='$pid' and eid='$eid'");

    my ($path) = $query_result->fetchrow_array;

    return $path;
}

#
# Return the min/max node counts for an experiment.
#
# usage: TBExptMinMaxNodes(char $pid, char *gid, int \$min, int \$max)
#        returns 1 if okay.
#	 returns 0 if error.
#
sub TBExptMinMaxNodes($$$$)
{
    my($pid, $eid, $minp, $maxp) = @_;

    my $query_result =
	DBQueryWarn("select minimum_nodes,maximum_nodes from experiments ".
		    "where eid='$eid' and pid='$pid'");

    if (!$query_result || !$query_result->numrows) {
	return 0;
    }
    my ($min, $max) = $query_result->fetchrow_array();

    $$minp = $min
	if (defined($minp));
    $$maxp = $max
	if (defined($maxp));
    return 1;
}

#
# Return the security level for an experiment.
#
# usage: TBExptSecurityLevel(char $pid, char *gid, int \$level)
#        returns 1 if okay.
#	 returns 0 if error.
#
sub TBExptSecurityLevel($$$)
{
    my($pid, $eid, $levelp) = @_;

    my $query_result =
	DBQueryWarn("select security_level from experiments ".
		    "where eid='$eid' and pid='$pid'");

    if (!$query_result || !$query_result->numrows) {
	return 0;
    }
    my ($level) = $query_result->fetchrow_array();

    $$levelp = $level
	if (defined($levelp));
    return 1;
}

#
# Check if a site-specific variable exists.
#
# usage: TBSiteVarExists($name)
#        returns 1 if variable exists;
#        returns 0 otherwise.
#
sub TBSiteVarExists($)
{
    return libEmulab::SiteVarExists($_[0]);
}

#
# Get site-specific variable.
# Get the value of the variable, or the default value if
# the value is undefined (NULL).
#
# usage: TBGetSiteVar($name, char \*rptr )
#        Without rptr: returns value if variable is defined; dies otherwise.
#        With rptr:    returns value in $rptr if variable is defined; returns
#                      zero otherwise, or any failure.
#
sub TBGetSiteVar($;$)
{
    my ($name, $rptr) = @_;

    return libEmulab::GetSiteVar($name, $rptr);
}

#
# Set a sitevar. Assumed to be a real sitevar.
#
# usage: TBSetSiteVar($name, $value)
#
sub TBSetSiteVar($$)
{
    my ($name, $value) = @_;

    return libEmulab::SetSiteVar($name, $value);
}

#
# Get pid,eid of current experiment using the robot lab. This is just
# plain silly for now.
#
sub TBRobotLabExpt($$)
{
    my ($ppid, $peid) = @_;
    
    my $query_result =
	DBQueryWarn("select r.pid,r.eid from reserved as r ".
		    "left join nodes as n on n.node_id=r.node_id ".
		    "left join node_types as nt on nt.type=n.type ".
		    "where nt.class='robot' and r.pid!='$TBOPSPID'");

    return 0
	if (!$query_result || !$query_result->numrows);

    my ($pid, $eid) = $query_result->fetchrow_array();
    $$ppid = $pid;
    $$peid = $eid;
    return 1;
}

#
# is a certain type/class node present?
# args: pid, eid, valid type/class
# 
sub TBExptContainsNodeCT($$$) 
{
    my ($pid,$eid,$ntc) = @_;

    # find out if this is a valid class or type...
    my $dbq = DBQueryWarn("select v.pid,v.eid,v.type from virt_nodes as v " .
			  "left join node_types as nt on v.type=nt.type " .
			  "where v.pid='$pid' and v.eid='$eid' and " .
			  "(nt.class='$ntc' or nt.type='$ntc')");

    return 0 
	if (!$dbq || !$dbq->numrows());

    return 1;
}

#
# Return the list of subnodes for the given node.
#
sub TBNodeSubNodes($)
{
    my ($node) = @_;
    my (@row);
    my (@nodes);

    my $result = DBQueryFatal("SELECT n.node_id FROM nodes AS n " .
			      "LEFT JOIN node_types " .
			      "    AS nt ON n.type = nt.type " .
			      "WHERE n.phys_nodeid='$node' and ".
			      "      nt.issubnode!=0");
    
    if (! $result or $result->numrows == 0) {
	return ();
    }
    while (@row = $result->fetchrow_array()) {
	my $node = $row[0];

	#
	# Taint check. I do not understand this sillyness, but if I
	# taint check these node names, I avoid warnings throughout.
	#
	if ($node =~ /^([-\w]+)$/) {
	    $node = $1;

	    push(@nodes, $node);
	}
	else {
	    print "*** $0: WARNING: Bad node name: $node.\n";
	}
    }
    return @nodes;
}

#
# Return a node's type and class, in a two-element array
# If the caller asked for a scalar, give them only the type
# Returns undef if the node doesn't exist
#
sub TBNodeType($)
{
    my ($node) = @_;
    my $result = DBQueryFatal("SELECT n.type, class FROM nodes AS n " .
			      "LEFT JOIN node_types " .
			      "    AS nt ON n.type = nt.type " .
			      "WHERE n.node_id='$node'");
    if ($result->num_rows() != 1) {
	return undef;
    }
    
    my ($type, $class) = $result->fetchrow();
    if (!$class) {
	return undef;
    }

    if (wantarray) {
	return ($type, $class);
    } else {
	return $type;
    }
}

sub TBNodeAdminOSID($)
{
    my ($nodeid) = @_;

    my $node = LocalNodeLookup($nodeid);
    if ($node) {
	return $node->adminmfs_osid();
    }
    return 0;
}

sub TBNodeRecoveryOSID($)
{
    my ($nodeid) = @_;

    my $node = LocalNodeLookup($nodeid);
    if ($node) {
	return $node->recoverymfs_osid();
    }
    return 0;
}

#
# Returns 1 if node uses NFS-based admin MFS, 0 ow.
#
sub TBNodeNFSAdmin($)
{
    my ($nodeid) = @_;

    my $node = LocalNodeLookup($nodeid);
    if ($node) {
	require OSImage;

	return OSImage->Lookup($node->adminmfs_osid())->IsNfsMfs();
    }
    return 0;
}

sub TBNodeDiskloadOSID($)
{
    my ($nodeid) = @_;

    my $node = LocalNodeLookup($nodeid);
    if ($node) {
	return $node->diskloadmfs_osid();
    }
    return 0;
}

#
# Return a node's type CPU type and speed, in a two-element array
# Returns undef if the type can't be found
#
sub TBNodeTypeProcInfo($)
{
    my ($type) = @_;

    my $typeinfo = LocalNodeTypeLookup($type);

    return undef
	if (!defined($typeinfo));

    my ($processor, $frequency);

    return undef
	if ($typeinfo->processor(\$processor) ||
	    $typeinfo->frequency(\$frequency));

    return ($processor, $frequency);
}

#
# Return a node's type bios waittime.
#        returns >= 1 if there is a waittime
#        returns undef if there is no waittime
#        returns 0 if not valid.
#
sub TBNodeTypeBiosWaittime($)
{
    my ($type) = @_;

    my $typeinfo = LocalNodeTypeLookup($type);

    return 0
	if (!defined($typeinfo));

    my $bios_waittime;

    return 0
	if ($typeinfo->bios_waittime(\$bios_waittime));

    return $bios_waittime;
}

#
# Restores backed up virtual state of pid/eid from directory in /tmp.
#
sub TBExptSetSwapUID($$$)
{
    my ($pid, $eid, $uid) = @_;

    return DBQueryWarn("update experiments set expt_swap_uid='$uid' ".
		       "where pid='$pid' and eid='$eid'");
}

#
# Set the thumbnail for an experiment. Comes in as a binary string, which
# must be quoted before DB insertion. Returns 1 if the thumbnail was
# succesfully updated, 0 if it was not.
#
sub TBExptSetThumbNail($$$)
{
    my ($pid, $eid, $bindata) = @_;

    $bindata = DBQuoteSpecial($bindata);

    # Need the resource ID first.
    my $query_result =
	DBQueryFatal("select rsrcidx from experiments as e ".
		     "left join experiment_stats as s on e.idx=s.exptidx ".
		     "where e.pid='$pid' and e.eid='$eid'");
    if ($query_result->num_rows() != 1) {
	return 0;
    }
    my ($rsrcidx) = $query_result->fetchrow_array();

    # Now do the insert.
    DBQueryFatal("update experiment_resources set thumbnail=$bindata ".
		 "where idx=$rsrcidx");
    #
    # Since the above is a QueryFatal, if it failed, we won't even get here
    #
    return 1;
}

#
# Get the port range for an experiment.
#
# usage TBExptPortRange(char *pid, char *eid, int \*low, int \*high)
#	Return 1 if success.
#	Return 0 if error.
#
sub TBExptPortRange($$$$)
{
    my ($pid, $eid, $high, $low) = @_;

    my $query_result =
	DBQueryFatal("select low,high from ipport_ranges ".
		     "where pid='$pid' and eid='$eid'");

    if ($query_result->numrows == 0) {
	return 0;
    }
    my @row = $query_result->fetchrow_array();
    $$low  = $row[0];
    $$high = $row[1];
    return 1;
}

#
# Get elabinelab info for an experiment. An experiment with a zero elabinelab
# flag, but a non-null elabinelab_eid means its an experiment that is linked
# to an elabinelab experiment cause of its security level.
#
# usage TBExptIsElabInElab(char *pid, char *eid,
#                          int \*elabinelab, char \*elabinelab_eid)
#	Return 1 if success.
#	Return 0 if error.
#
sub TBExptIsElabInElab($$$;$)
{
    my ($pid, $eid, $elabinelab, $elabinelab_eid) = @_;

    my $query_result =
	DBQueryFatal("select elab_in_elab,elabinelab_eid from experiments ".
		     "where pid='$pid' and eid='$eid'");

    if ($query_result->numrows == 0) {
	return 0;
    }
    my @row = $query_result->fetchrow_array();
    $$elabinelab     = $row[0];
    $$elabinelab_eid = (defined($row[1]) ? $row[1] : undef)
	if (defined($elabinelab_eid));
    return 1;
}

#
# Get plabinelab info for an experiment. Returns 1 in plabinelab
# if any node in the experiment is either a plab 'plc' or 'node'.
#
# usage TBExptIsPlabInElab(char *pid, char *eid, int \*plabinelab)
#	Return 1 if success.
#	Return 0 if error.
#
sub TBExptIsPlabInElab($$$)
{
    my ($pid, $eid, $plabinelab) = @_;

    my $query_result =
	DBQueryFatal("select plab_role from virt_nodes ".
		     "where pid='$pid' and eid='$eid' ".
		     "and plab_role!='none'");

    if ($query_result->numrows == 0) {
	$$plabinelab = 0;
    } else {
	$$plabinelab = 1;
    }
    return 1;
}

#
# Return the PLC node for a swapped in plabinelab experiment.
# Returns 0 if no PLC.  Returns 1 and the name of the node otherwise.
#
sub TBExptPlabInElabPLC($$$)
{
    my ($pid, $eid, $plcnode) = @_;

    my $query_result =
	DBQueryFatal("select node_id from reserved ".
		     "where pid='$pid' and eid='$eid' and plab_role='plc'");
    if ($query_result->numrows > 0) {
	my @row = $query_result->fetchrow_array();
	if (defined($row[0])) {
	    $$plcnode = $row[0];
	    return 1;
	}
    }
    return 0;
}

#
# Return a list of inner plab nodes for a swapped in plabinelab experiment.
# Returns 0 on failure.  Returns 1 and a list of nodes otherwise.
#
sub TBExptPlabInElabNodes($$$)
{
    my ($pid, $eid, $nodes) = @_;

    my $query_result =
	DBQueryFatal("select node_id from reserved ".
		     "where pid='$pid' and eid='$eid' and plab_role='node'");

    while (my @row = $query_result->fetchrow_array()) {
	push(@{$nodes}, $row[0]);
    }

    return 0;
}

#
# Similar function for batchmode.
#
sub TBExptIsBatchExp($$$)
{
    my ($pid, $eid, $batchmode) = @_;

    my $query_result =
	DBQueryFatal("select batchmode from experiments ".
		     "where pid='$pid' and eid='$eid'");

    if ($query_result->numrows == 0) {
	return 0;
    }
    my @row = $query_result->fetchrow_array();
    $$batchmode     = $row[0];
    return 1;
}

#
# Get the control network IP for a node (underlying physical node!).
#
# usage TBControlNetIP(char *nodeid, char \*ip)
#	Return 1 if success.
#	Return 0 if error.
#
sub TBControlNetIP($$)
{
    my ($nodeid, $pip) = @_;

    my $query_result =
	DBQueryFatal("select IP from nodes as n2 ".
		     "left join nodes as n1 on n1.node_id=n2.phys_nodeid ".
		     "left join interfaces as i on ".
		     "     i.node_id=n1.node_id and ".
		     "     i.role='" . TBDB_IFACEROLE_CONTROL() . "' " .
		     "where n2.node_id='$nodeid'");

    if ($query_result->numrows == 0) {
	return 0;
    }
    my @row = $query_result->fetchrow_array();
    if (defined($row[0])) {
	$$pip = $row[0];
	return 1;
    }
    return 0;
}

#
# Map network IP for a node to its nodeid
#
# usage TBIPtoNodeID(char *ip, char \*nodeid)
#	Return 1 if success.
#	Return 0 if error.
#
sub TBIPtoNodeID($$)
{
    my ($ip, $pnodeid) = @_;

    my $query_result =
	DBQueryFatal("select i.node_id from interfaces as i ".
		     "where i.IP='$ip' and ".
		     "      role='" . TBDB_IFACEROLE_CONTROL() . "'");

    if ($query_result->numrows == 0) {
	return 0;
    }
    my @row = $query_result->fetchrow_array();
    if (defined($row[0])) {
	$$pnodeid = $row[0];
	return 1;
    }
    return 0;
}

#
# Get the underlying physical node. Might be the same as the node if its
# not a virtual node.
#
# usage TBPhysNodeID(char *nodeid, char \*phys_nodeid)
#	Return 1 if success.
#	Return 0 if error.
#
sub TBPhysNodeID($$)
{
    my ($nodeid, $pphys) = @_;

    my $query_result =
	DBQueryFatal("select phys_nodeid from nodes ".
		     "where node_id='$nodeid'");

    if ($query_result->numrows == 0) {
	return 0;
    }
    my @row = $query_result->fetchrow_array();
    if (defined($row[0])) {
	$$pphys = $row[0];
	return 1;
    }
    return 0;
}

#
# From the physical node name, get the name that the should be used in the
# widearea_* tables
#
# usage TBWideareaNodeID(char *nodeid, char \*widearea_nodeid)
#	Return 1 if success.
#	Return 0 if error. (Currently, not possible)
#
sub TBWideareaNodeID($$)
{
    my ($nodeid, $pwide) = @_;

    if (TBIsNodeRemote($nodeid)) {
	$$pwide = $nodeid;
    } else {
	$$pwide = TBDB_WIDEAREA_LOCALNODE;
    }

    return 1;
}

#
# Mark a node as needing account updates. This variant does it based
# on node type, and all of the nodes of that type are marked. This is
# used for marking widearea nodes.
#
# usage TBNodeUpdateAccountsByType(char type)
#    Returns 1 all the time.
#
sub TBNodeUpdateAccountsByType($)
{
    my ($nodetype) = @_;

    #
    # No point in incrementing the flag past 2 since all that does is
    # cause needless updates.
    #
    DBQueryFatal("update nodes set update_accounts=update_accounts+1 ".
		 "where type='$nodetype' and update_accounts<2");

    return 1;
}

#
# Mark a node as needing account updates. This variant does it based
# on pid; all of the nodes in that pid are marked. Not very efficient!
#
# usage TBNodeUpdateAccountsByPid(char pid)
#    Returns 1 all the time.
#
sub TBNodeUpdateAccountsByPid($)
{
    my ($pid) = @_;

    my $query_result =
	DBQueryWarn("select r.node_id from reserved as r ".
		    "left join nodes as n on r.node_id=n.node_id ".
		    "where r.pid='$pid' and n.update_accounts=0");

    if (! $query_result ||
	! $query_result->numrows) {
	return 1;
    }

    while (my @row = $query_result->fetchrow_array()) {
	my $nodeid = $row[0];

	#
	# No point in incrementing the flag past 2 since all that does is
	# cause needless updates.
	#
	DBQueryFatal("update nodes set update_accounts=update_accounts+1 ".
		     "where node_id='$nodeid' and update_accounts<2");
    }
    return 1;
}

#
# Schedule account updates on all the nodes that this person has
# an account on.
#
# There are two sets of nodes. The first is all of the local nodes in
# all of projects the user is a member of. The second is all of the
# widearea nodes that the project has access to. Rather than operate
# on a per node basis.  grab the project names (for the reserved
# table) and the remote types to match against the node types. Of
# course, the pcremote_ok slot is a set, so need to parse that.
#
# usage TBNodeUpdateAccountsByPid(char pid)
#    Returns 1 all the time.
#
sub TBNodeUpdateAccountsByUID($)
{
    my ($uid) = @_;

    DBQueryFatal("update users set usr_modified=now() ".
		 "where uid='$uid' and status='active'");

    my $query_result =
	DBQueryFatal("select p.pid,pcremote_ok from users as u ".
		     "left join group_membership as g on ".
		     "  u.uid_idx=g.uid_idx and g.pid_idx=g.gid_idx ".
		     "left join projects as p on p.pid_idx=g.pid_idx ".
		     "where u.uid='$uid' and u.status='active' and ".
		     "      p.pid is not null");

    while (my %row = $query_result->fetchhash()) {
	my $pid      = $row{'pid'};
	my $pcremote = $row{'pcremote_ok'};

	if (defined($pcremote)) {
	    my @typelist = split(',', $pcremote);

	    foreach my $nodetype (@typelist) {
		TBNodeUpdateAccountsByType($nodetype);
	    }
	}
	TBNodeUpdateAccountsByPid($pid);
    }
    #
    # Also update on widearea nodes if entries in widearea_accounts
    #
    $query_result =
	DBQueryFatal("select node_id from widearea_accounts ".
		     "where uid='$uid' and trust!='none'");

    while (my %row = $query_result->fetchhash()) {
	my $node_id = $row{'node_id'};

	DBQueryFatal("update nodes set update_accounts=update_accounts+1 ".
		     "where node_id='$node_id' and update_accounts<2");
    }

    #
    # Finally update nodes who are accessible by the user via the 'dp_projects'
    # node attribute.
    #
    # XXX big ugly query alert!
    #
    $query_result = 
	DBQueryFatal("select n.node_id from projects as p, ".
		     "  groups as g, group_membership as gm, ".
		     "  nodes as n, node_attributes as na ".
		     "where p.pid=g.pid and p.approved!=0 ".
		     "  and g.gid=gm.gid and p.pid=gm.pid ".
		     "  and n.node_id=na.node_id ".
		     "  and FIND_IN_SET(g.gid_idx, na.attrvalue) > 0 ".
		     "  and na.attrkey='dp_projects' ".
		     "  and gm.uid='$uid'");

    while (my %row = $query_result->fetchhash()) {
	my $node_id = $row{'node_id'};

	DBQueryFatal("update nodes set update_accounts=update_accounts+1 ".
		     "where node_id='$node_id' and update_accounts<2");
    }

    return 1;
}

#
# Clear various bits of info from a node, just as if it was booting for
# the first time in an experiment.
#
sub TBNodeBootReset($)
{
    my ($nodeid) = @_;

    DBQueryFatal("update nodes set ready=0, ".
		 "startstatus='" . NODESTARTSTATUS_NOSTATUS() . "', ".
		 "bootstatus='"  . NODEBOOTSTATUS_UNKNOWN()   . "' ".
		 "where node_id='$nodeid'");

    return 0;
}

sub TBNodeConsoleTail ($$) {
    my ($pc, $fh) = @_;

    my $query_result =
	DBQueryFatal("select server from tiplines where node_id='$pc'");
    
    if (!$query_result->numrows) {
	return;
    }
    my ($tipserver) = $query_result->fetchrow_array();

    print $fh "Tail of $pc console:\n";
    my $oldeuid = $EUID;
    $EUID = $UID;
    open(CONTAIL, "$TB/sbin/spewconlog -l 10 $pc |");
    while (<CONTAIL>) {
	s/[^ -~\t\n]/./g;
	print $fh "$pc: $_";
    }
    close(CONTAIL);
    print $fh "\n";
    $EUID = $oldeuid;
}

#
# Wait for a node to hit a certain state. Provide a start time and a max
# wait time. A "state" can actually be "<op-mode>/<state>" in which case
# it will match against both node.op_mode and node.eventstate.
#
# NB: This function is not as general purpose as it might seem; there are
#     not many "terminal" states that you can wait for (like isup).
#     Still, it avoids duplication in 4 scripts.
#     Also, watch for events not filtering through stated in time.
#
sub TBNodeStateWait ($$$$@) {
    my ($pc, $waitstart, $maxwait, $actual, @waitstates) = @_;

    #
    # Start a counter going, relative to the time we rebooted the first
    # node.
    #
    my $waittime  = 0;
    my $minutes   = 0;
    my $needopmode = grep(/\//, @waitstates);

    #
    # Wait for the node to finish booting, as recorded in database
    #
    while (1) {
	my ($state, $opmode);
	if (($needopmode && !TBGetNodeOpMode($pc, \$opmode)) ||
	    !TBGetNodeEventState($pc, \$state)) {
	    print "*** Error getting event op-mode/state for $pc.\n";
	    return 1;
	}

	foreach my $wstate (@waitstates) {
	    if ($needopmode && $wstate =~ /^(.*)\/(.*)$/) {
		if (($1 eq TBDB_NODEOPMODE_ANY || $1 eq $opmode) &&
		    $2 eq $state) {
		    # note that we return opmode/state
		    $$actual = "$opmode/$state"
			if (defined($actual));
		    return 0;
		}
	    } elsif ($state eq $wstate) {
		$$actual = $state
		    if (defined($actual));
		return 0;
	    }
	}

	$waittime = time - $waitstart;
	if ($waittime > $maxwait) {
	    $minutes = int($waittime / 60);
	    print "*** Giving up on $pc ($state) - ",
	          "it's been $minutes minute(s).\n";
	    TBNodeConsoleTail($pc, *STDOUT);
	    return 1;
	}
	if (int($waittime / 60) > $minutes) {
	    $minutes = int($waittime / 60);
	    print "Still waiting for $pc ($state) - ",
	          "it's been $minutes minute(s).\n";
	}
	sleep(1);
    }
}

#
# Control net VLAN firewall stuff.
#
# reserved:cnet_vlan is set for a allocated node if the node is behind a
#       firewall.  In this case, cnet_vlan indicates the VLAN number that
#	this nodes' control net interface is a part of.
#
# firewalls:fwname is the virtual name of the node which is a firewall
#	for a particular experiment.
#
# firewalls:vlan is the VLAN number of the firewalled control net.
#
# It is possible for a node to be both a firewall and behind another
# firewall.  In that case, the firewalls table vlan column for
# pid/eid/thisnode-virt-name is the VLAN number for the firewalled control
# net that thisnode is implementing.  Thisnode's reserved table cnet_vlan
# column will contain the VLAN number of the firewalled control net that
# thisnode is a part of.
#

#
# Determine if there is a firewall for a particular experiment.
# Optionally returns the pname of the firewall node and the VLAN info.
#
# XXX only returns true for experiments with VLAN-based firewalls.
# XXX this will need to change if we support multiple firewalls per experiment.
#
sub TBExptFirewall ($$;$$$$) {
    my ($pid, $eid, $fwnodep, $fwvlanidp, $fwvlanp, $fwtypep) = @_;
    my $query_result;

    #
    # Short form: is there a firewall? Use the virt_firewalls table so can
    # be called for a swapped or active experiment.
    #
    if (!defined($fwnodep)) {
	$query_result =
	    DBQueryWarn("SELECT eid FROM virt_firewalls ".
			"WHERE pid='$pid' and eid='$eid' ".
			"AND type LIKE '%-vlan'");
	if (!$query_result || $query_result->num_rows == 0) {
	    return 0;
	}
	return 1;
    }

    #
    # Long form: want at least the name of the firewall node returned.
    # The experiment should be swapped in or else the returned node_id
    # will be NULL.
    #
    $query_result =
	DBQueryWarn("select r.node_id,f.vlan,f.vlanid,v.type from ".
		    "   virt_firewalls as v ".
		    "left join firewalls as f on f.pid=v.pid and f.eid=v.eid ".
		    "left join reserved as r on r.pid=v.pid and ".
		    "     r.eid=v.eid and r.vname=v.fwname ".
		    "where v.pid='$pid' and v.eid='$eid'");
    if (!$query_result || $query_result->num_rows == 0) {
	return 0;
    }

    my @row = $query_result->fetchrow_array();
    if (!defined($row[0])) {
	print STDERR "*** WARNING: attempted fetch of Firewall info for ".
	    "swapped experiment $pid/$eid\n";
	$$fwnodep = ""
	    if (defined($fwnodep));
    } else {
	$$fwnodep = $row[0]
	    if (defined($fwnodep));
    }
    $$fwvlanp = $row[1]
	if (defined($fwvlanp));
    $$fwvlanidp = $row[2]
	if (defined($fwvlanidp));
    $$fwtypep = $row[3]
	if (defined($fwtypep));
    return 1;
}

#
# Get the firewall node name and iface for an experiment;
# e.g., for use in an snmpit call.
# Return 1 if successful, 0 on error.
#
sub TBExptFirewallAndIface($$$$) {
    my ($pid, $eid, $fwnodep, $fwifacep) = @_;
    my $fwnode;
    require Interface;

    if (!TBExptFirewall($pid, $eid, \$fwnode)) {
	return 0;
    }

    my $interface = Interface->LookupControl($fwnode);
    if (!defined($interface)) {
	print STDERR "*** Could not lookup control interface for $fwnode\n";
	return 0;
    }
    $$fwnodep = $fwnode;
    ($$fwifacep) = $interface->iface();

    return 1;
}

#
# Set the firewall VLAN number for an experiment.
#
# XXX this will need to change if we support multiple firewalls per experiment.
#
sub TBSetExptFirewallVlan($$$$) {
    my ($pid, $eid, $fwvlanid, $fwvlan) = @_;
    my $fwnode;

    if (!TBExptFirewall($pid, $eid, \$fwnode)) {
	return 0;
    }

    my $exptidx;
    if (!TBExptIDX($pid, $eid, \$exptidx)) {
	print "*** WARNING: No such experiment $pid/$eid!\n";
	return 0;
    }

    #
    # Need the virtual name since we use that to ensure uniqness in the
    # firewalls table.
    #
    my $query_result =
	DBQueryWarn("select fwname from virt_firewalls ".
		    "WHERE pid='$pid' AND eid='$eid'");

    return 0
	if (!$query_result || $query_result->num_rows == 0);

    my ($fwname) = $query_result->fetchrow_array();

    #
    # Change the firewalls table entry to reflect the VLAN
    #
    DBQueryWarn("replace into firewalls (exptidx,pid,eid,fwname,vlan,vlanid) ".
		"values ('$exptidx', '$pid', '$eid', ".
		"        '$fwname', $fwvlan, $fwvlanid)")
	or return 0;

    #
    # Change the reserved table entries for all firewalled nodes to reflect it.
    #
    DBQueryWarn("UPDATE reserved set cnet_vlan=$fwvlan ".
		"WHERE pid='$pid' AND eid='$eid' AND node_id!='$fwnode'")
	or return 0;

    return 1;
}

#
# Clear the firewall VLAN number for an experiment.
#
# XXX this will need to change if we support multiple firewalls per experiment.
#
sub TBClearExptFirewallVlan($$)
{
    my ($pid, $eid) = @_;

    #
    # Clear entry from the firewalls table.
    #
    DBQueryWarn("delete from firewalls ".
		"where pid='$pid' and eid='$eid'");

    #
    # XXX when clearing, do not bother with reserved since the row may
    # already be gone.
    #
}

#
# Determines if a node is part of a firewalled experiment.
# If so, optionally returns the name and VLAN number for the firewall.
#
sub TBNodeFirewall ($$$) {
    my ($nodeid, $fwnodep, $fwvlanp) = @_;

    #
    # If they are only interested in a yes/no answer, just look in the
    # nodes table to set if the cnet_vlan is non-null.
    #
    if (!defined($fwnodep) && !defined($fwvlanp)) {
	my $query_result =
	    DBQueryWarn("select cnet_vlan from reserved ".
			"where node_id='$nodeid'");

	if (!$query_result || $query_result->num_rows == 0) {
	    return 0;
	}
	my ($res) = $query_result->fetchrow_array();
	if (!defined($res) || $res eq "") {
	    return 0;
	}
	return 1;
    }

    #
    # Otherwise extract the firewall name and vlan number for the node
    # This is probably not the best query in the world.  The first join
    # matches up nodes with their firewall info, the second "resolves"
    # each firewall's virtname to a physname.
    #
    my $query_result =
	DBQueryWarn("SELECT r2.node_id,f.vlan FROM firewalls AS f ".
		    "LEFT JOIN reserved AS r ".
		    "  ON r.pid=f.pid AND r.eid=f.eid AND r.cnet_vlan=f.vlan ".
		    "LEFT JOIN reserved AS r2 ".
		    "  ON r2.pid=f.pid AND r2.eid=f.eid AND r2.vname=f.fwname ".
		    "WHERE r.node_id='$nodeid'");
    if (!$query_result || $query_result->num_rows == 0) {
	return 0;
    }

    my @row = $query_result->fetchrow_array();
    $$fwnodep = $row[0]
	if (defined($fwnodep));
    $$fwvlanp = $row[1]
	if (defined($fwvlanp));
    return 1;
}

#
# Set the paniced bit for an experiment.
#
sub TBExptSetPanicBit($$;$) {
    my ($pid, $eid, $value) = @_;

    $value = 1
	if (!defined($value));

    return DBQueryWarn("update experiments set ".
		       "    paniced=$value,panic_date=now() ".
		       "where pid='$pid' and eid='$eid'");
}

#
# Clear the panic bit.
# 
sub TBExptClearPanicBit($$) {
    my ($pid, $eid) = @_;

    return DBQueryWarn("update experiments set ".
		       "    paniced=0,panic_date=NULL ".
		       "where pid='$pid' and eid='$eid'");
}

#
# Get the value of the paniced bit. 
# 
sub TBExptGetPanicBit($$$) {
    my ($pid, $eid, $panicp) = @_;

    my $query_result =
	DBQueryWarn("select paniced,panic_date from experiments ".
		    "where pid='$pid' and eid='$eid'");
    if (!$query_result || $query_result->num_rows == 0) {
	return 0;
    }
    my @row = $query_result->fetchrow_array();
    $$panicp = $row[0];

    return 1;
}

#
# Get the value of the swapout state.
# Right now this is just the savedisk field.
# Returns 1 if there is swap state, 0 otherwise.
# 
sub TBExptGetSwapState($$$) {
    my ($pid, $eid, $statep) = @_;

    my $query_result =
	DBQueryWarn("select savedisk from experiments ".
		    "where pid='$pid' and eid='$eid'");
    if (!$query_result || $query_result->num_rows == 0) {
	return 0;
    }
    my @row = $query_result->fetchrow_array();
    $$statep = $row[0];

    return 1;
}

#
# See if there is an admin MFS swapout action associated with the experiment.
# For now we just look at a globally defined action via sitevar.
#
# Returns 1 if there is a swapout action (with $ref hash filled in),
# 0 otherwise.
#
sub TBExptGetSwapoutAction($$$) {
    my ($pid, $eid, $ref) = @_;
    my ($action, $faction, $timeout);

    if (TBGetSiteVar("swap/swapout_command", \$action)) {
	my $failisfatal = 1;

	#
	# Swapout-time state saving.
	# Only perform if the experiment has desired state saving.
	#
	if ($action =~ /create-swapimage/) {
	    my $doit = 0;
	    my $query_result =
		DBQueryWarn("select savedisk from experiments ".
			    "where pid='$pid' and eid='$eid'");
	    if ($query_result && $query_result->num_rows != 0) {
		($doit) = $query_result->fetchrow_array();
	    }
	    if (!$doit) {
		%$ref = ();
		return 0;
	    }
	}

	if (TBGetSiteVar("swap/swapout_command_failaction", \$faction)) {
	    $failisfatal = ($faction eq "fail");
	}
	TBGetSiteVar("swap/swapout_command_timeout", \$timeout);

	%$ref = ('command' => $action,
		 'isfatal' => $failisfatal,
		 'timeout' => $timeout);
	return 1;
    }

    # Someday maybe check for per-experiment setting
    %$ref = ();
    return 0;
}

#
# Return a (current) string suitable for DB insertion in datetime slot.
# Of course, you can use this for anything you like!
#
# usage: char *DBDateTime(int seconds-to-add);
#
sub DBDateTime(;$)
{
    my($seconds) = @_;
    require POSIX;

    if (! defined($seconds)) {
	$seconds = 0;
    }

    return POSIX::strftime("20%y-%m-%d %H:%M:%S", localtime(time() + $seconds));
}

#
# Helper. Test if numeric. Convert to dbuid if numeric.
#
sub MapNumericUID($)
{
    my ($uid) = @_;
    my $name;

    if ($uid =~ /^[0-9]+$/) {
	my $user = LocalUserLookupByUnixId($uid);
	if (!defined($user)) {
	    die("*** $uid not a valid Emulab user!\n");
	}
	$name = $user->uid();
    }
    else {
	$name = $uid;
    }
    return $name;
}

#
# Grab the tipserver list and return.
#
sub TBTipServers()
{
    my @tipservers = ();

    my $query_result =
	DBQueryFatal("select server from tipservers");

    while (my ($server) = $query_result->fetchrow_array) {
	push(@tipservers, $server);
    }
    return @tipservers;
}

#
# Report some activity for a node
#
# usage: TBActivityReport(char *node)
#        Returns 1 if okay.
#        Returns 0 if failed.
#
sub TBActivityReport($)
{
    my ($node) = @_;

    # Set last_ext_act to now(), but don't update the last_report
    return DBQueryFatal("update node_activity set last_ext_act= now() " .
			"where node_id='$node'");
}

#
# Return the number of *available* nodes. These are nodes that are not
# reserved and in the proper state. See corresponding code in ptopgen
# and in the web server which reports the free node counts to users.
#
# usage: TBAvailablePCs(char *pid)
#        Returns count.
#
sub TBAvailablePCs(;$)
{
    my ($pid) = @_;
    my $clause = (defined($pid) ? "or p.pid='$pid'" : "");

    my $query_result =
	DBQueryFatal("select count(a.node_id) from nodes as a ".
		     "left join reserved as b on a.node_id=b.node_id ".
		     "left join node_types as nt on a.type=nt.type ".
		     "left join nodetypeXpid_permissions as p ".
		     "  on a.type=p.type ".
		     "where b.node_id is null and a.role='testnode' and ".
		     "      nt.class='pc' and ".
                     "      (a.eventstate='" . TBDB_NODESTATE_ISUP . "' or ".
                     "       a.eventstate='" . TBDB_NODESTATE_PXEWAIT . "') and".
		     "      (p.pid is null $clause)");

    my ($count) = $query_result->fetchrow_array();
    return $count;
}

#
# Gather Assign stats. Its expected that the hash that comes in
# will reflect the slot names in the DB.
#
# usage: GatherAssignStats(char *pid, char *eid,
#			   char *mode, int code, int flags)
#        Mode is one of preload, start, in, out, modify, end.
#
sub GatherAssignStats($$%)
{
    my ($pid, $eid, %stats) = @_;
    my @updates = ();

    my $query_result =
	DBQueryWarn("select e.gid,e.idx,s.rsrcidx from experiments as e ".
		    "left join experiment_stats as s on e.idx=s.exptidx ".
		    "where e.pid='$pid' and e.eid='$eid'");
    if (!$query_result || !$query_result->numrows) {
	return;
    }
    my ($gid,$exptidx,$rsrcidx) = $query_result->fetchrow_array;

    # experiment records not inserted in testmode, but I use testmode
    # at home when doing development too.
    if (!defined($rsrcidx)) {
	return
	    if ($TESTMODE);
	die("*** $0:\n".
	    "    No stat record for record for $pid/$eid\n");
    }

    foreach my $key (keys(%stats)) {
	my $val = $stats{$key};
	next
	    if (!defined($val));

	push (@updates, "$key=$val");
    }
    DBQueryFatal("update experiment_resources ".
		 "set " . join(",", @updates) . " ".
		 "where idx=$rsrcidx");
}

sub GetPerExperimentSwitchStackName($) {
    my ($expt) = @_;
    return "ExpStack" . $expt->idx();
}

#
# Get per-experiment switch stack id, the leader, and the switches.
#
sub GetPerExperimentSwitchStack($) {
    my ($expt) = @_;
    my $leader;
    my @switches;

    my $stack_id = GetPerExperimentSwitchStackName($expt);

    my $qres = DBQueryFatal("select leader from switch_stack_types" . 
			    " where stack_id='$stack_id'");
    if (!defined($qres) || $qres->numrows() == 0) {
	if (wantarray) {
	    return ();
	}
	else {
	    return undef;
	}
    }
    ($leader) = $qres->fetchrow_array();

    $qres = DBQueryFatal("select node_id from switch_stacks" . 
			 " where stack_id='$stack_id'");
    while (my ($node_id) = $qres->fetchrow_array()) {
	push @switches, $node_id
	    if ($node_id ne $leader);
    }

    return ($stack_id,$leader,@switches);
}

#
# Add a per-experiment switch stack type, and add switches to that stack.
#
sub AddPerExperimentSwitchStack($$$$$@) {
    my ($expt,$leader,$snmp_community,$min_vlan,$max_vlan,@switches) = @_;
    my $scomm = $snmp_community;

    my $stack_id = GetPerExperimentSwitchStackName($expt);

    return 1 
	if (!@switches);

    if (!defined($leader)) {
	$leader = $switches[0];
    }
    if (!defined($snmp_community)) {
	$scomm = int(rand(100000000));
    }
    if (!defined($min_vlan)) {
	$min_vlan = 256;
    }
    if (!defined($max_vlan)) {
	$max_vlan = 999;
    }

    my $query = "replace into switch_stack_types" .
	" (stack_id,stack_type,supports_private,single_domain," . 
	"  snmp_community,min_vlan,max_vlan,leader)" . 
	" values ( '$stack_id','generic',0,0," . 
	"          '$scomm',$min_vlan,$max_vlan,'$leader')";
    DBQueryFatal($query);

    foreach my $switch (@switches) {
	# for each switch, if the caller didn't supply snmp_community, then
	# check node_type_attributes to see if there is a fixed community we
	# must use -- i.e., if we can't reconfig this switch with a generated
	# one.
	if (!defined($snmp_community)) {
	    my $qres = DBQueryFatal("select nta.attrvalue" . 
				    " from nodes as n " . 
				    " left join node_type_attributes as nta" . 
				    "  on n.type=nta.type " . 
				    " where n.node_id='$switch'" . 
				    "  and nta.attrkey='snmp_community'");
	    if ($qres && $qres->numrows()) {
		($scomm,) = $qres->fetchrow_array();
	    }
	}

	DBQueryFatal("replace into switch_stacks ".
		     "  (node_id,stack_id,is_primary,snmp_community)" . 
		     " values ('$switch','$stack_id','1','$scomm')");
    }

    return 0;
}

#
# Update a per-experiment switch stack type (i.e., during an expt modify).
#
sub UpdatePerExperimentSwitchStack($@) {
    my ($expt,@switches) = @_;

    my $stack_id = GetPerExperimentSwitchStackName($expt);

    if (!@switches) {
	DBQueryFatal("delete from switch_stacks where stack_id='$stack_id'");
	return 0;
    }

    my $qres = DBQueryFatal("select leader,snmp_community from switch_stack_types" . 
			    "  where stack_id='$stack_id'");
    if (!$qres || !$qres->numrows) {
	tbwarn("No such switch stack id '$stack_id'!");
	return 1;
    }
    my ($leader,$scomm) = $qres->fetchrow_array;
    my $need_new_leader = 1;
    foreach my $switch (@switches) {
	if ($switch eq '$leader') {
	    $need_new_leader = 0;
	    last;
	}
    }

    if ($need_new_leader) {
	DBQueryFatal("delete from switch_stacks" . 
		     "  where stack_id='$stack_id' and node_id='$leader'");
	$leader = $switches[0];
    }

    # delete them all, and add them all back -- easier than querying and 
    # diff'ing
    DBQueryFatal("delete from switch_stacks where stack_id='$stack_id'");

    foreach my $switch (@switches) {
	my $is_primary = 0;
	if (1 || $switch eq $leader) {
	    $is_primary = 1;
	}

	# for each switch, if the caller didn't supply snmp_community, then
	# check node_type_attributes to see if there is a fixed community we
	# must use -- i.e., if we can't reconfig this switch with a generated
	# one.
	if (!defined($scomm) || $scomm eq '') {
	    my $qres = DBQueryFatal("select nta.attrvalue" . 
				    " from nodes as n " . 
				    " left join node_type_attributes as nta" . 
				    "  on n.type=nta.type " . 
				    " where n.node_id='$switch'" . 
				    "  and nta.attrkey='snmp_community'");
	    if ($qres && $qres->numrows()) {
		($scomm,) = $qres->fetchrow_array();
	    }
	}

	DBQueryFatal("replace into switch_stacks (node_id,stack_id,is_primary)" . 
		     " values ('$switch','$stack_id',$is_primary)");
    }

    return 0;
}

#
# Delete a per-experiment switch stack type.
#
sub DeletePerExperimentSwitchStack($) {
    my ($expt) = @_;

    my $stack_id = GetPerExperimentSwitchStackName($expt);

    DBQueryFatal("delete from switch_stacks where stack_id='$stack_id'");
    DBQueryFatal("delete from switch_stack_types where stack_id='$stack_id'");

    return 0;
}

sub max ( $$ ) {
    return ($_[0] > $_[1] ? $_[0] : $_[1]);
}

sub min ( $$ ) {
    return ($_[0] < $_[1] ? $_[0] : $_[1]);
}

sub hash_recurse(%) {
    my (%hash) = @_;
    return hash_recurse2("",%hash);
}

sub array_recurse(%) {
    my (%array) = @_;
    return array_recurse2("",%array);
}

sub hash_recurse2($%) {
    my ($indent, %hash) = @_;
    my $level = "  ";
    my $str = "HASH:\n";
    my $tab = $indent.$level;
    foreach my $k (sort keys %hash) {
	$str .= $tab."$k => ";
	my $v = $hash{$k};
	my $type = ref($v);
	if (!$type) {
	    # scalar
	    $str .= "$v\n";
	} elsif ($type eq "HASH") {
	    $str .= hash_recurse2($tab,%$v);
	} elsif ($type eq "ARRAY") {
	    $str .= array_recurse2($tab,@$v);
	} elsif ($type eq "SCALAR") {
	    $str .= "(REF) ".$$v."\n";
	} else {
	    $str .= "(TYPE $type) $v\n";
	}
    }
    return $str;
}

sub array_recurse2($%) {
    my ($indent, @array) = @_;
    my $level = "  ";
    my $str = "ARRAY:\n";
    my $tab = $indent.$level;
    foreach my $v (@array) {
	my $type = ref($v);
	if (!$type) {
	    # Not a ref, therefore, a scalar
	    $str .= $tab."$v\n";
	} elsif ($type eq "HASH") {
	    $str .= hash_recurse2($tab,%$v);
	} elsif ($type eq "ARRAY") {
	    $str .= array_recurse2($tab,@$v);
	} elsif ($type eq "SCALAR") {
	    $str .= "(REF) ".$$v."\n";
	} else {
	    $str .= "(TYPE $type) $v\n";
	}
    }
    return $str;
}

sub TBSetNodeHistory($$$$$)
{
    my ($nodeid, $op, $uid, $pid, $eid) = @_;
    my $exptidx;

    #
    # XXX Eventually this should change, but the use of $UID is funky.
    #
    my $dbid;
    my $node = LocalNodeLookup($nodeid);
    my $experiment = LocalExpLookup($pid, $eid);
    my $this_user;

    if (!defined($node)) {
	print "*** WARNING: No such node $nodeid!\n";
	return 0;
    }
    if (!defined($experiment)) {
	print "*** WARNING: No such experiment $pid/$eid!\n";
	return 0;
    }

    if ($uid =~ /^[0-9]+$/) {
	if ($uid == 0) {
	    # Node->SetNodeHistory() is okay with this.
	    $this_user = undef;
	}
	else {
	    $this_user = LocalUserLookupByUnixId($uid);
	    if (! defined($this_user)) {
		print "*** WARNING: $UID does not exist in the DB!";
		return 0;
	    }
	}
    }
    else {
	$this_user = LocalUserLookup($uid);
	if (! defined($this_user)) {
	    print "*** WARNING: $UID does not exist in the DB!";
	    return 0;
	}
    }
    return $node->SetNodeHistory($op, $this_user, $experiment);
}

# _Always_ make sure that this 1 is at the end of the file...
1;
