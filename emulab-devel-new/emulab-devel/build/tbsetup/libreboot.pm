#!/usr/bin/perl -wT
#
# Copyright (c) 2000-2021 University of Utah and the Flux Group.
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
# node reboot library. Basically the backend to the node_reboot script, but
# also used where we need finer control of rebooting nodes (and failure).
#
# XXX Only suitable for scripts that are already setuid and have not
# dropped privs by the time they call into nodereboot(). I think this
# makes the library somewhat useless.
#
package libreboot;

use strict;
use Exporter;
use vars qw(@ISA @EXPORT);

@ISA    = "Exporter";
@EXPORT = qw ( nodereboot nodereboot_wait );

# Must come after package declaration!
use lib '/users/mshobana/emulab-devel/build/lib';
use libdb;
use libtblog_simple;
use English;

#
# Configure variables
#
my $TB		= "/users/mshobana/emulab-devel/build";
my $CLIENT_BIN  = "/usr/local/etc/emulab";
my $BOSSNODE    = "boss.cloudlab.umass.edu";
my $PGENISUPPORT= 1;

#
# The number of nodes we reboot at a time and the time to wait between batches.
# The batch size determines the degree of parallelism.
#
my $BATCHCOUNT  = 12;
my $BATCHSLEEP	= 5;

#
# Various timeouts that really should come from the DB.
#
# These determine the max time per-node that we take to attempt to effect
# a reboot short of power cycling (i.e., the time spent in RebootNode):
#
# node is in PXEWAIT, returns after sending a PXEWAKEUP ("immediately").
# node does not ping, returns after 2 seconds.
# node is pingable and ssh is running, returns after between
#   2 and ($REBOOTTIMO + $PINGWAIT) seconds.
# ssh reboot fails but ipod works, returns after between
#   ($REBOOTTIMO + $PINGWAIT) and ($REBOOTTIMO + 2 * $PINGWAIT) seconds.
# unresponsive to ipod, returns after ($REBOOTTIMO + 2 * $PINGWAIT) seconds.
#
# With current settings, this is between "immediately" and 80 seconds
# per node. In the common cases where nodes are in PXEWAIT, alive and
# well (ssh running), or completely dead it takes around 10 seconds max.
# Ironically, the slowest case if for the "alive and well" scenario where
# we have to wait for the node to stop pinging, which means after it has
# shutdown all services and reached the point where it shuts down network
# interfaces.
#

#
# SSH timeouts.
# Connection timeout value should be less than the reboot/reconfig values,
# since the latter two are for the entire operation. Set to zero to not
# have a connect timeout (the historic case).
#
my $CONNECTTIMO		= 10;
my $REBOOTTIMO		= 20;
my $REBOOTVNODETIMO	= 30;
my $RECONFIGTIMO	= 30;

#
# Default reboot waittime.
# If the user doesn't specify, we use this historic value.
#
my $MAXWAITTIME	= (6 * 60);

#
# Wait times for a node to stop pinging.
# Both regular case and when the prepare script has to be run.
#
my $PINGWAIT	= 30;
my $PREPAREWAIT	= 200;

#
# Testbed Support libraries
#
use libdb;
use libtestbed;
use User;
use event;
use POSIX qw(strftime);
use IO::Handle;
use Fcntl;

# External Programs
my $ssh		= "$TB/bin/sshtb -n";
if ($CONNECTTIMO) {
    $ssh .= " -o ConnectTimeout=$CONNECTTIMO";
}
my $power	= "$TB/bin/power";
my $vnodesetup	= "$TB/sbin/vnode_setup";
my $bisend      = "$TB/sbin/bootinfosend";
my $logfile	= "$TB/log/reboot.log";
my $ping	= "/sbin/ping";
my $reboot      = "$TB/bin/node_reboot";

# Locals
my $debug       = 0;
my $silent      = 0;
my %children    = ();

#
# The actual library function. 
#
sub nodereboot($$)
{
    my ($args, $result) = @_;
    my @nodes       = @{ $args->{'nodelist'}};
    my %nodeobjects = ();	# Not in the mood to rewrite this function.

    # Reset our few globals.
    $debug    = 0;
    $silent   = 0;
    %children = ();
    
    $debug = $args->{'debug'}
        if (exists($args->{'debug'}));
    $silent = $args->{'silent'}
        if (exists($args->{'silent'}));

    if ($EUID != 0) {
	#
	# Use the exec version, but only if we do not already have
	# a pipeno in the environment, which would indicate a loop
	# caused by installing improperly.
	#
	if (exists($ENV{'REBOOTPIPENO'})) {
	    tberror "Must be root when using library!";
	    return -1;
	}
	print STDERR "reboot: no privs; invoking real nodereboot script!\n"
	    if ($debug);
	return nodereboot_exec($args, $result);
    }

    if (!defined($args->{'nodelist'})) {
	tberror "Must supply a node list!";
	return -1;
    }
    my $powercycle  = 0;
    my $rebootmode  = 0;
    my $waitmode    = 0;
    my $waittime    = $MAXWAITTIME;
    my $realmode    = 1;
    my $killmode    = 0;
    my $freemode    = 0;
    my $prepare     = 0;
    my $reconfig    = 0;
    my $asyncmode   = 0;
    my $pipemode    = 0;
    my $force       = 0;

    $powercycle  = $args->{'powercycle'} if (exists($args->{'powercycle'}));
    $rebootmode  = $args->{'rebootmode'} if (exists($args->{'rebootmode'}));
    $waitmode    = $args->{'waitmode'}   if (exists($args->{'waitmode'}));
    $waittime    = $args->{'waittime'}   if (exists($args->{'waittime'}));
    $realmode    = $args->{'realmode'}   if (exists($args->{'realmode'}));
    $killmode    = $args->{'killmode'}   if (exists($args->{'killmode'}));
    $freemode    = $args->{'freemode'}   if (exists($args->{'freemode'}));
    $prepare     = $args->{'prepare'}    if (exists($args->{'prepare'}));
    $reconfig    = $args->{'reconfig'}   if (exists($args->{'reconfig'}));
    $asyncmode   = $args->{'asyncmode'}  if (exists($args->{'asyncmode'}));
    $force       = $args->{'force'}      if (exists($args->{'force'}));

    #
    # If pipeno is specified in the environment, we write the results to
    # that pipe.
    # 
    if (exists($ENV{'REBOOTPIPENO'})) {
	$pipemode = $ENV{'REBOOTPIPENO'};

	if ($pipemode =~ /^(\d+)$/) {
	    $pipemode = $1;
	}
	else {
	    tberror "Bad pipeno in environment: $pipemode!";
	    return -1;
	}
    }

    #
    # Verify permission to reboot these nodes.
    #
    if ($UID && !TBAdmin($UID) &&
	! TBNodeAccessCheck($UID, TB_NODEACCESS_REBOOT, @nodes)) {
	tberror "You do not have permission to reboot some of the nodes!";
	return -1;
    }

    # Locals.
    my %pids	 = ();
    my $failed   = 0;

    # XXX - Wisconsin hack to avoid rebooting routers - this needs to be
    # replaced with the node_capabilities stuff or similar.
    my @temp = ();
    foreach my $node (@nodes) {
	my $nodeobject = Node->Lookup($node);
	my $rebootable = $nodeobject->rebootable();

	$nodeobjects{$node} = $nodeobject;
	push(@temp,$node) if ($rebootable || $force);
    }
    @nodes = @temp;
    # END XXX

    #
    # VIRTNODE HACK: Virtual nodes are special. We can reboot jailed
    # vnodes, but not old style (non-jail). Also, if we are going to
    # reboot the physical node that a vnode is on, do not bother with
    # rebooting the vnode since it will certainly get rebooted anyway!
    #
    my %realnodes = ();
    my %virtnodes = ();

    #
    # Geni node reboot/wait is optimized inside libGeni, so keep them
    # separate. Both real and virtual; libGeni treats them the same
    # since the Protogeni interface makes no distinction.
    #
    my %geninodes = ();

    foreach my $node (@nodes) {
	my $nodeobj = $nodeobjects{$node};
	if (!defined($nodeobj)) {
	    tbdie("Could not map $node to its object");
	}
	my $jailed     = $nodeobj->jailflag();
	my $plab       = $nodeobj->isplabdslice();
	my $pnode      = $nodeobj->phys_nodeid();
	my $geninode   = $nodeobj->isfednode();
	my $rebootable = $nodeobj->rebootable();
	
	# All nodes start out as being successful; altered later as needed.
	$result->{$node} = 0;

	if ($geninode) {
	    $geninodes{$node} = $nodeobj;
	}
	elsif ($nodeobj->isvirtnode()) {
	    if (!$jailed && !$plab && !$rebootable) {
		print "reboot ($node): Skipping old style virtual node\n";
		next;
	    }
	    if (!defined($pnode)) {
	        tberror "$node: No physical node!";
		return -1;
	    }
	    $virtnodes{$node} = $pnode;
	}
	else {
	    $realnodes{$node} = $node;
	}
    }
    for my $node ( keys(%virtnodes) ) {
	my $pnode = $virtnodes{$node};

	if (defined($realnodes{$pnode})) {
	    print "reboot: Dropping $node since its host $pnode will reboot\n"
		if (!$silent);
	    delete($virtnodes{$node});
	}
    }
    if (! (keys(%realnodes) || keys(%virtnodes) || keys(%geninodes))) {
	print "reboot: No nodes to reboot.\n";
	return 0;
    }
    my @sortednodes = sort(keys(%realnodes));

    #
    # This stuff is incomplete and non-functional.
    # 
    if (!$realmode) {
	EventSendFatal(host      => $BOSSNODE ,
		       objtype   => TBDB_TBEVENT_COMMAND ,
		       eventtype => TBDB_COMMAND_REBOOT ,
		       objname   => join(",", @sortednodes));
	# In here we can do some output to tell the user what's going on.
	if ($waitmode) {
	    # Wait for [SHUTDOWN,ISUP]
	}
	else {
	    # Wait for [SHUTDOWN]
	}
	return 0;
    }

    #
    # This is somewhat hackish. To promote parallelism, we want to fork off
    # the reboot from the parent so it can do other things.  The problem is
    # how to return status via the results vector. Well, lets do it with
    # some simple IPC. Since the results vector is simply a hash of node
    # name to an integer value, its easy to pass that back.
    #
    # We return the pid to the caller, which it can wait on either directly
    # or by calling back into this library if it wants to actually get the
    # results from the child!
    #
    if ($asyncmode) {
	#
	# Create a pipe to read back results from the child we will create.
	#
	if (! pipe(PARENT_READER, CHILD_WRITER)) {
	    tberror "creating pipe: $!";
	    return -1;
	}
	CHILD_WRITER->autoflush(1);

	if (my $childpid = fork()) {
	    close(CHILD_WRITER);
	    $children{$childpid} = [ *PARENT_READER, $result ];
	    return $childpid;
	}
	#
	# Child keeps going. 
	#
	close(PARENT_READER);
	TBdbfork();

	print STDERR "reboot: Running in asyncmode.\n"
	    if ($debug);
    }
    elsif ($pipemode) {
	#
	# We were invoked with an FD already opened to write the results to.
	# See nodereboot_exec() below. The operation from here is basically
	# the same as in asyncmode, but we do not need to create the pipe,
	# but rather just write the results to the pipe we got. 
	#
	if (! open(CHILD_WRITER, ">>&=${pipemode}")) {
	    tberror "reopening pipe: $!";
	    return -1;
	}
	CHILD_WRITER->autoflush(1);

	print STDERR "reboot: Running in pipemode ($pipemode).\n"
	    if ($debug);
    }

    #
    # Fire off the geninode reboots. 
    #
    if (keys(%geninodes)) {
	require libGeni;
	
	my $this_user = User->ThisUser();
	if (!defined($this_user)) {
	    tbdie("Could not determine current user for libGeni\n");
	}
	if (libGeni::RestartNodes($this_user, $debug, values(%geninodes))) {
	    tbdie("Could not restart protogeni nodes\n");
	}
	#
	# We always do a wait for geni nodes since for nodes in "basic"
	# cooked mode, nothing will be reporting a state change from the
	# node. We have to go poll it to make sure that the node is alive,
	# and so we can report ISUP for it. This is a bit of a violation of
	# the default reboot model, which is fire and forget when waitmode
	# is not set, but no way around it.
	#
	if (libGeni::WaitForNodes($this_user, $debug,
				  undef, values(%geninodes))) {
	    tbdie("Error in waiting for protogeni nodes\n");
	}
    }

    #
    # We do not want lots of nodes all rebooting at the same time, it puts
    # a strain on UDP-based PXE/DHCP/TFTP protocols.  So we group them in
    # batches and wait a short time between batches.
    #
    # Currently batches are organized by increasing node order.  In the
    # future we may want to batch based on power controllers; e.g. either
    # reboot all nodes on a power controller at once or AVOID rebooting
    # all nodes on a power controller at once (if controller cannot handle
    # max surge of all attached nodes).
    #
    while (@sortednodes) {
	my @batch     = ();
	my $i         = 0;

	while ($i < $BATCHCOUNT && @sortednodes > 0) {
	    my $node = shift(@sortednodes);
	    push(@batch, $node);
	    $i++;
	}

	info("BATCH: ". ($powercycle ? "power cycling " : "rebooting ").
	     join(" ", @batch));
	if ($powercycle) {
	    #
	    # In powercyle mode, call the power program for the whole
	    # batch, and continue on. We do not wait for them to go down or
	    # reboot.
	    #
	    if (PowerCycle(@batch)) {
		tberror "Powercycle failed for one or more of " .
		    join(" ",@batch);
		foreach my $node (@batch) {
		    $result->{$node} = -1;
		    $failed++;
		}
	    }
	}
	else {
	    #
	    # Fire off a reboot process so that we can overlap them all.
	    # We need the pid so we can wait for them all before preceeding.
	    #
	    foreach my $node ( @batch ) {
		$pids{$node} = RebootNode($nodeobjects{$node}, $reconfig,
					  $killmode, $rebootmode, $prepare);
	    }
	}

	#
	# If there are more nodes to go, then lets pause a bit so that we
	# do not get a flood of machines coming up all at the same exact
	# moment.
	#
	if (@sortednodes) {
	    info("BATCH: pausing for ${BATCHSLEEP}s");
	    sleep($BATCHSLEEP);
	}
    }

    #
    # Wait for all the reboot children to exit before continuing.
    #
    my @needPowercycle = ();
    my @needPowerOn = ();
    if (scalar(keys(%pids))) {
	foreach my $node (sort(keys(%realnodes))) {
	    my $mypid     = $pids{$node};
	    my $status;

	    #
	    # Child may have avoided the fork, and returned status directly.
	    # Flip it and apply the same test.
	    #
	    if ($mypid <= 0) {
		$status = -$mypid;
	    }
	    else {
		waitpid($mypid, 0);
		$status = $? >> 8;
	    }

	    if ($status == 2) {
		# Child signaled to us that this node needs a power cycle
		push(@needPowercycle, $node);
	    }
            elsif ($status == 3) {
                # Child signaled to us that this node needs to be powered on
                push(@needPowerOn, $node);
            }
	    elsif ($mypid != 0 && $?) {
		$failed++;
		$result->{$node} = -1;
		tberror "Failed ($?)!";
	    }
	    else {
		print STDOUT "reboot ($node): Successful!\n"
		    if (!$silent);
	    }
	}
    }

    #
    # Power cycle nodes that couldn't be brought down any other way
    #
    if (@needPowercycle) {
	if (PowerCycle(@needPowercycle)) {
	    tberror "Powercycle failed for one or more of " .
		join(" ",@needPowercycle);
	    foreach my $node (@needPowercycle) {
		$result->{$node} = -1;
		$failed++;
	    }
	}
    }

    #
    # Power on nodes that were turned off
    #
    if (@needPowerOn) {
	if (PowerOn(@needPowerOn)) {
	    tberror "Power on failed for " . join(" ",@needPowerOn);
	    foreach my $node (@needPowerOn) {
		$result->{$node} = -1;
		$failed++;
	    }
	}
    }
    
    #
    # Now do vnodes. Do these serially for now (simple).
    #
    for my $node ( sort(keys(%virtnodes)) ) {
	my $pnode = $virtnodes{$node};

	if (RebootVNode($nodeobjects{$node}, $pnode, $reconfig)) {
	    $failed++;
	    $result->{$node} = -1;
	    tberror "$node: Reboot failed (on $pnode)";
	}
	else {
	    print STDOUT "reboot ($node): rebooting (on $pnode).\n"
		if (!$silent);
	}
    }

    #
    # Wait for nodes to reboot. We wait only once, no reboots.
    #
    if ($waitmode) {
	my $waitstart = time;

	print STDOUT "reboot: Waiting (${waittime}s) for nodes to come up.\n"
	    if (!$silent);

	# Wait for events to filter through stated! If we do not wait, then we
	# could see nodes still in ISUP.
	sleep(2);

	#
	# States that signify that the reboot stage is done.
	# For normal reboots this means either that the node came
	# or correctly (ISUP) or not (TBFAILED). However, for a reloading
	# node there is no ISUP, it either got into the reloading process
	# (RELOAD/RELOADING) or it didn't (no explicit report).
	#
	my @waitstates = (TBDB_NODESTATE_TBFAILED,
			  TBDB_NODESTATE_ISUP,
			  TBDB_NODEOPMODE_RELOAD."/".TBDB_NODESTATE_RELOADING);

	foreach my $node (sort(@nodes)) {
	    my $actual_state;
	    
	    #
	    # Skip if something failed earlier.
	    #
	    next
		if ($result->{node});
	    
	    if (!TBNodeStateWait($node, $waitstart, $waittime,
				 \$actual_state, @waitstates)) {
		if ($actual_state ne TBDB_NODESTATE_TBFAILED) {
		    if ($actual_state eq TBDB_NODESTATE_ISUP) {
			print STDOUT "reboot ($node): alive and well.\n";
		    } else {
			print STDOUT "reboot ($node): alive and reloading.\n";
		    }
		    Node::SetBootStatus($node, NODEBOOTSTATUS_OKAY);
		    next;
		}
		tberror "$node reported a TBFAILED event.";
	    }
	    Node::SetBootStatus($node, NODEBOOTSTATUS_FAILED);
	    $result->{$node} = -1;
	    $failed++;
	}
    }
 done:    
    print "reboot: Done. There were $failed failures.\n"
	if (!$silent);

    if ($asyncmode || $pipemode) {
	#
	# We are a child. Send back the results to the parent side
	# and *exit* with status instead of returning it.
	# 
	foreach my $node (keys(%{ $result })) {
	    my $status = $result->{$node};

	    print CHILD_WRITER "$node,$status\n";
	}
	close(CHILD_WRITER);
	exit($failed);
    }
    return $failed;
}

#
# Reboot a node in a child process. Return the pid to the parent so
# that it can wait on all the children later.
#
sub RebootNode {
    my ($nodeobject, $reconfig, $killmode, $rebootmode, $prepare) = @_;
    my ($status, $syspid, $mypid, $nodestate);
    my $pc = $nodeobject->node_id();

    if ($reconfig) {
	print "reboot ($pc): Attempting to reconfigure ...\n"
	    if (!$silent);
    }
    else {
	print "reboot ($pc): Attempting to reboot ...\n"
	    if (!$silent);
    }

    # Report some activity into last_ext_act
    TBActivityReport($pc);

    #
    # Is the node in PXEWAIT? If so we want to wake it up so that it can
    # query bootinfo and do what it is supposed to do, without a real reboot.
    # We send the initial wakeup from here, but let stated deal with it
    # failing (timeout) and resending it. That means we could be called
    # with the node in PXEWAKEUP, so send it another wakeup. The point is that
    # stated is controlling the timeouts. Eventually stated gives up and uses
    # the -k option to force a power cycle.
    #
    if ($nodeobject->GetEventState(\$nodestate)) {
	info("*** $pc: no event state, power cycling");
	
	# Signal to the called that the node needs to be power cycled
	return -2;
    }
    if ($nodestate eq TBDB_NODESTATE_PXEWAIT() ||
	$nodestate eq TBDB_NODESTATE_PXELIMBO() ||
	$nodestate eq TBDB_NODESTATE_PXEWAKEUP()) {
	#
	# In killmode, we do not want to bother with sending a wakeup event.
	# Just do the power cycle. This is used to unstick a machine that
	# is in waitmode, but not responding to the wakeups.
	#
	if ($killmode) {
	    info("$pc: in $nodestate, but power cycling in killmode");
	    
	    # Signal to the caller that the node needs to be power cycled
	    return -2;
	}

	my $whol = 0;
	if ($nodeobject->NodeAttribute("wakeonlan_afterpower", \$whol) == 0) {
	    if ($whol) {
		$nodeobject->SimpleWOL();
	    }
	}
	
	#
	# The aux program sends the event to stated ...
	#
	my $reqarg = ($rebootmode ? "-r" : "-q");
	#my $optarg = ($debug ? "-dd" : "");
	my $optarg = "";
	
	info("$pc: in $nodestate, sending PXEWAKEUP");
	system("$bisend $optarg $reqarg $pc");
	if ($?) {
	    info("$pc: PXEWAKEUP failed, power cycling");
	    tbnotice "$pc: PXEWAKEUP failed; will power cycle.\n";
	    
	    # Signal to the caller that the node needs to be power cycled
	    return -2;
	}
	return 0;
    }

    #
    # Do the rest in a child process. After the fork, we do the ping test
    # before we reconnect to the DB. This cuts down on the flurry of connects
    # by a bunch of children (ping will take a moment to run).
    #
    $mypid = fork();
    if ($mypid) {
	return $mypid;
    }

    #
    # See if the machine is pingable. If its not pingable, then we just
    # power cycle the machine rather than wait for ssh to time out.
    #
    if (! DoesPing($pc, 0, 1)) {
        if ($nodestate eq TBDB_NODESTATE_POWEROFF) {
            info("$pc: powered off, will power on");
            tbnotice "$pc powered off; will power on.";
            exit(3);
        }
	info("$pc: appears dead, power cycle");
	tbnotice "$pc appears dead; will power cycle.";
	
	# Signal to the parent that the node needs to be power cycled
	exit(2);
    }
    TBdbfork();

    #
    # Machine is pingable at least. Try to reboot it gracefully,
    # or power cycle anyway if that does not work.
    #
    info("$pc: trying ssh ".($reconfig ? "reconfig" : "reboot"));

    #
    # Must change our real UID to root so that ssh will work. We save the old
    # UID so that we can restore it after we finish the ssh
    #
    my $oldUID = $UID;
    $UID = 0;

    #
    # If doing a reconfig, first try that in a child.
    #
    if ($reconfig) {
	TBSetNodeEventState($pc, "RECONFIG");
	$syspid = fork();

	if ($syspid) {
	    local $SIG{ALRM} = sub { kill("TERM", $syspid); };
	    alarm $RECONFIGTIMO;
	    waitpid($syspid, 0);
	    alarm 0;

	    #
	    # The ssh can return non-zero exit status, but still have worked.
	    # FreeBSD for example.
	    #
	    my $stat = $?;
	    info("$pc: reconfig returned ".($stat >> 8));

	    #
	    # Any failure, revert to plain reboot below.
	    #
	    if ($stat == 0) {
		$UID = $oldUID;
		exit(0);
	    }
	}
	else {
	    exec("$ssh -host $pc ".
		 "/usr/local/etc/emulab/rc/rc.bootsetup -b reconfig");
	    exit(0);
	}
    }

    #
    # If any of the node's subnodes are being reloaded, wait for the operation
    # to finish before doing the reboot.
    #
    my @subnodes = TBNodeSubNodes($pc);
    foreach my $subnode (@subnodes) {
	my $opmode;
	
	if (TBGetNodeOpMode($subnode, \$opmode) &&
	    defined($opmode) &&
	    (($opmode eq TBDB_NODEOPMODE_RELOADING) ||
	     ($opmode eq TBDB_NODEOPMODE_RELOAD) ||
	     ($opmode eq TBDB_NODEOPMODE_RELOADMOTE))) {
	    my $startwait = time;
	    my $actual_state;

	    print "reboot ($pc): waiting for subnode '$subnode' to finish ".
		"reloading...\n";
	    sleep(5);
	    if (TBNodeStateWait($subnode,
				$startwait,
				(60*10),
				\$actual_state,
				(TBDB_NODESTATE_TBFAILED,
				 TBDB_NODESTATE_ISUP))) {
		print "reboot ($pc): subnode has not finished reloading, ".
		    "rebooting anyways...\n";
	    }
	}
    }

    my $didipod = 0;

    #
    # Run an ssh command in a child process, protected by an alarm to
    # ensure that the ssh is not hung up forever if the machine is in
    # some funky state.
    #
    $syspid = fork();

    if ($syspid) {
	my $timedout = 0;
	local $SIG{ALRM} = sub { kill("TERM", $syspid); $timedout = 1; };
	alarm $REBOOTTIMO;
	waitpid($syspid, 0);
	alarm 0;
	my $stat = $? >> 8;

	#
	# We used to special case $?==256 here as meaning "ssh is not running"
	# but relying on any return code here is dubious.  Too much depends on
	# the timing of the reboot operation on the client.  So we just check
	# for a self-induced timeout here and immediately send a PoD in that
	# case.  Otherwise, we assume the reboot happened and we will catch
	# our error below if the node does not stop pinging within a couple
	# of seconds.
	#
	if ($timedout) {
	    info("$pc: ssh reboot hung, sending ipod");

	    if ($nodeobject->SendApod(1) == 0) {
		$didipod = 1;
	    }
	}
	#
	# The ssh can return non-zero exit status, but still have worked.
	# FreeBSD for example.
	#
	else {
	    info("$pc: ssh reboot returned $stat");
	}
    }
    else {
	my $cmd = "/sbin/reboot";
	$cmd = "'/usr/local/etc/emulab/reboot_prepare ".
	    "emulab-reboot-prepare || $cmd'"
	    if ($prepare);
	
	exec("$ssh -host $pc $cmd");
	exit(0);
    }

    #
    # Restore the old UID so that scripts run from this point on get the
    # user's real UID
    #
    $UID = $oldUID;

    #
    # Okay, before we try IPoD or power cycle lets really make sure we need to.
    # We wait a while for the node to stop responding to pings, and if it never
    # goes silent, whack it with a bigger stick.
    #
    # We need to give shared hosts a chance to stop their containers.
    # The standard pingwait is too small. 
    #
    my $wtime = ($prepare ||
		 $nodeobject->sharing_mode() ? $PREPAREWAIT : $PINGWAIT);
    info("$pc: waiting ${wtime}s for reboot");
    if (WaitTillDead($pc, $wtime) == 0) {
	info("$pc: rebooted");
	my $state = TBDB_NODESTATE_SHUTDOWN;
	TBSetNodeEventState($pc,$state);
	exit(0);
    }

    #
    # Switches do not do ipod, so jump to powercycle.
    #
    if ($nodeobject->isswitch()) {
	info("$pc: is a switch, skipping ipod, power cycling");
	exit(2);
    }

    #
    # Haven't yet tried an ipod, try that and wait again.
    # This further slows down reboot but is probably worth it
    # since this should be a rare case (reboot says it worked but
    # node doesn't reboot) and is vital if the nodes have no
    # power cycle capability to fall back on.
    #
    if (! $didipod) {
	info("$pc: ssh reboot failed, sending ipod");
	$UID = 0;
	my $rv = $nodeobject->SendApod(1);
	$UID = $oldUID;
	if ($rv == 0) {
	    info("$pc: waiting ${PINGWAIT}s for ipod");
	    if (WaitTillDead($pc, $PINGWAIT) == 0) {
		info("$pc: rebooted");
		my $state = TBDB_NODESTATE_SHUTDOWN;
		TBSetNodeEventState($pc,$state);
		exit(0);
	    }
	}
    }

    info("$pc: ipod failed, power cycling");
    exit(2);
}

#
# Reboot a vnode in a child process, and wait for it.
#
sub RebootVNode($$$) {
    my ($nodeobj, $pnode, $reconfig) = @_;
    my $syspid;

    my $vnode      = $nodeobj->node_id();
    my $jailed     = $nodeobj->jailflag();
    my $plab       = $nodeobj->isplabdslice();
    my $geninode   = $nodeobj->isfednode();
    my $oldUID     = $UID;

    if ($reconfig) {
	print "reboot ($vnode): Attempting to reconfigure.\n"
	    if (!$silent);
    }
    else {
	print STDOUT "reboot ($vnode): Rebooting (on $pnode).\n"
	    if (!$silent);
    }

    #
    # For reconfig, we might need to fall back to reboot, so need
    # another child.
    #
    if ($jailed && $reconfig) {
	TBSetNodeEventState($vnode, "RECONFIG");
	my $reconpid = fork();

	if ($reconpid) {
	    local $SIG{ALRM} = sub { kill("TERM", $reconpid); };
	    alarm $RECONFIGTIMO;
	    waitpid($reconpid, 0);
	    alarm 0;

	    #
	    # The ssh can return non-zero exit status, but still have worked.
	    # FreeBSD for example.
	    #
	    my $stat = $?;
	    info("$vnode: reconfig returned ".($stat >> 8));

	    #
	    # Any failure, revert to plain reboot below.
	    #
	    if ($stat == 0) {
		exit(0);
	    }
	}
	else {
	    # Must change our real UID to root so that ssh will work.
	    $UID = 0;

	    exec("$ssh -host $vnode ".
		 "/usr/local/etc/emulab/rc/rc.bootsetup -b reconfig");
	    exit(0);
	}
    }

    #
    # Run an ssh command in a child process, protected by an alarm to
    # ensure that the ssh is not hung up forever if the machine is in
    # some funky state.
    #
    $syspid = fork();

    if ($syspid) {
	local $SIG{ALRM} = sub { kill("TERM", $syspid); };
	alarm $REBOOTVNODETIMO;
	waitpid($syspid, 0);
	alarm 0;
	my $exitstatus = $?;

	#
	# The ssh can return non-zero exit status, but still have worked.
	# FreeBSD for example.
	#
	print STDERR "*** reboot ($vnode): returned $exitstatus.\n" if $debug;

	#
	# Look for setup failure, reported back through ssh.
	#
	if ($exitstatus) {
	    if ($exitstatus == 256) {
		print STDERR "*** reboot ($vnode): $pnode is not running sshd.\n"
		    if $debug;
	    }
	    elsif ($exitstatus == 15) {
		print STDERR "*** reboot ($vnode): $pnode is wedged.\n"
		    if $debug;
	    }
	}
	return($exitstatus);
    }

    my $addargs = "-t ";	# Turn on timestamps.
    if ($plab) {
	$addargs .= "-p ";
    }
    elsif ($jailed) {
	# Use virtual control net routes. 
	$addargs .= "-jV ";
    }
    else {
	$addargs .= "-i ";
    }	

    #
    # Must change our real UID to root so that ssh will work.
    #
    $UID = 0;

    exec("$ssh -host $pnode $CLIENT_BIN/vnodesetup -r $addargs $vnode");
    exit(0);
}

#
# Power cycle a PC using the testbed power program.
#
sub PowerCycle {
    my @pcs = @_;

    my $pcstring = join(" ",@pcs);

    system("$power cycle $pcstring");
    return $? >> 8;
}

#
# Power on a PC using the testbed power program.
#
sub PowerOn {
    my @pcs = @_;
    
    my $pcstring = join(" ",@pcs);

    system("$power on $pcstring");
    return $? >> 8;
}

#
# Wait until a machine stops returning ping packets.
#
sub WaitTillDead {
    my ($pc, $waittime) = @_;

    print STDERR "reboot ($pc): Waiting to die off.\n" if $debug > 1;

    #
    # Sigh, a long ping results in the script waiting until all the
    # packets are sent from all the pings, before it will exit. So,
    # loop doing a bunch of shorter pings.
    #
    # Note that each call to DoesPing takes about two seconds.
    #
    my $iters = int(($waittime + 1) / 2);
    for (my $i = 0; $i < $iters; $i++) {
	if (! DoesPing($pc, $i, 0)) {
	    print STDERR "reboot ($pc): Died off.\n" if $debug > 1;
	    return 0;
	}
    }
    print STDERR "reboot ($pc): still alive after $waittime seconds.\n"
	if $debug > 1;
    return 1;
}

#
# Returns 1 if host is responding to pings, 0 otherwise.
# Pings for roughly two seconds.
# If $immediate is set, return after the first successful ping.
# This routine is NOT allowed to do any DB queries!
#
sub DoesPing {
    my ($pc, $index, $immediate) = @_;
    my $status;
    my $saveuid;

    #
    # We fork/exec rather than system() for two reasons.
    # One, is so that we don't have to flip the UID back and forth in
    # the parent, and two, so that we can throw away stdout/stderr without
    # an extra level of "sh -c" to setup redirection (">/dev/null 2>&1").
    #
    # XXX I am not sure either of these is particularly compelling,
    # but when we can have literally hundreds of pending nodereboots
    # outstanding at any time, it might matter.
    #
    my $child = fork();
    if ($child == 0) {
	my $args = "-q -i 0.25 -c 9 -t 2";
	$args .= " -o" if ($immediate);

	# get rid of output that -q doesn't
	open(STDOUT, ">/dev/null");
	open(STDERR, ">&STDOUT");

	$UID = 0;
	exec("$ping $args $pc");
	exit(1);
    }
    waitpid($child, 0);
    $status = $? >> 8;

    #
    # Ping returns 0 if any packets are returned. Returns 2 if pingable
    # but no packets are returned. Other non-zero error codes indicate
    # other problems.  Any non-zero return indicates "not pingable" to us.
    #
    print STDERR "reboot ($pc): $ping $index returned $status\n" if $debug > 1;
    if ($status) {
	return 0;
    }
    return 1;
}

sub info($) {
    my $message = shift;

    # Time stamp log messages like:
    # Sep 20 09:36:00 $message
    my $tstamp = strftime("%b %e %H:%M:%S", localtime);

    open(LOG,">> $logfile");
    print LOG "$tstamp $message\n";
    close(LOG);

    print STDERR "$message\n" if ($debug);
}

#
# This gets called in the parent, to wait for an async reboot that was
# launched earlier (asyncmode). The child will print the results back
# on the the pipe that was opened between the parent and child. They
# are stuffed into the original results array.
#
sub nodereboot_wait($)
{
    my ($childpid) = @_;

    if (!exists($children{$childpid})) {
	tberror "No such child pid $childpid!";
	return -1;
    }
    my ($PARENT_READER, $result) = @{ $children{$childpid}};

    #
    # Read back the results.
    # 
    while (<$PARENT_READER>) {
	chomp($_);

	if ($_ =~ /^([-\w]+),([-\d])+$/) {
	    $result->{$1} = $2;
	    print STDERR "reboot ($1): child returned $2 status.\n";
	}
	else {
	    tberror "Improper response from child: $_";
	}
    }
    
    #
    # And get the actual exit status.
    # 
    waitpid($childpid, 0);
    return $? >> 8;
}

#
# Okay, this is horrible! We cannot include this library into non-setuid
# scripts cause a lot of this stuff needs to be run as root. So provide an
# interface that is equiv to the library interface above, but which execs
# an instance of node_reboot and waits for the results.
#
sub nodereboot_exec($$)
{
    my ($args, $result) = @_;
    my $asyncmode = 0;

    #
    # Create a suitable command line from arg hash.
    #
    my $cmdline = "";

    $cmdline .= "-d"
	if (exists($args->{'debug'}) && $args->{'debug'});
    $cmdline .= " -f"
	if (exists($args->{'powercycle'}) && $args->{'powercycle'});
    $cmdline .= " -b"
	if (exists($args->{'rebootmode'}) && $args->{'rebootmode'});
    $cmdline .= " -w"
	if (exists($args->{'waitmode'}) && $args->{'waitmode'});
    $cmdline .= " -r"
	if (exists($args->{'realmode'}) && $args->{'realmode'});
    $cmdline .= " -k"
	if (exists($args->{'killmode'}) && $args->{'killmode'});
    $cmdline .= " -a"
	if (exists($args->{'freemode'}) && $args->{'freemode'});
    $cmdline .= " -c"
	if (exists($args->{'reconfig'}) && $args->{'reconfig'});
    $cmdline .= " -W$args->{waittime}"
	if (exists($args->{'waittime'}) && $args->{'waittime'});
    $cmdline .= " -F"
	if (exists($args->{'force'}));
    $cmdline .= " @{ $args->{'nodelist'}}";
    
    $asyncmode = $args->{'asyncmode'} if (exists($args->{'asyncmode'}));
	    
    #
    # Create a pipe to read back results from the child we will create.
    #
    if (! pipe(PARENT_READER, CHILD_WRITER)) {
	tberror "creating pipe: $!";
	return -1;
    }
    CHILD_WRITER->autoflush(1);

    #
    # ACK! Perl defaults to close-on-exec? Why is that?
    # 
    fcntl(CHILD_WRITER, F_SETFD, 0);

    if (my $childpid = fork()) {
	close(CHILD_WRITER);

	#
	# Save the info we need for calling nodereboot_wait() above.
	# 
	$children{$childpid} = [ *PARENT_READER, $result ];

	#
	# If asyncmode we return right away. The caller will need to
	# use the nodereboot_wait() routine above.
	#
	if ($asyncmode) {
	    return $childpid;
	}

	#
	# Block waiting.
	#
	return nodereboot_wait($childpid);
    }
    close(PARENT_READER);

    #
    # Pass the fd number to the child.
    # 
    $ENV{'REBOOTPIPENO'} = fileno(CHILD_WRITER);
   
    #
    # Child execs the instance of node_reboot, with an extra open fd.
    #
    exec("$reboot $cmdline");
    die("Could not exec $reboot!");
    
}

# _Always_ make sure that this 1 is at the end of the file...
1;
