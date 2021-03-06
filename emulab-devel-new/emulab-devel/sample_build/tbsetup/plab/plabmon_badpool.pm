# -*- perl -*-
#
# Copyright (c) 2000-2005, 2007 University of Utah and the Flux Group.
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
# plabmonitor node pool module for bad (malfunctional) nodes.
#

package plabmon_badpool;

#use strict;
use English;

use POSIX qw(WIFSIGNALED WEXITSTATUS);

$| = 1; # Turn off line buffering on output

use lib "/users/mshobana/CloudLabonESI/emulab-devel-new/emulab-devel/sample_build/lib";
use libdb;
use libtestbed;
use libplabmon;

my $BADINST = 99;
my $VNODESETUPTIMEOUT = 600; # XXX: need to get from sitevar, or
                             #      pass in via new().
my $ISUPWAITTIME = 600;      # XXX: likewise...
my $TEARDOWNTIMEOUT = 300;   # XXX: ...

my $SETUPMODE    = "SETUPMODE";
my $TEARDOWNMODE = "TEARDOWNMODE";

my $BIGINT = 9999999999;

my $CLIENT_BIN = "/usr/local/etc/emulab";
my $SSH = "/users/mshobana/CloudLabonESI/emulab-devel-new/emulab-devel/sample_build/bin/sshtb -n";
my $PLABNODE = "/users/mshobana/CloudLabonESI/emulab-devel-new/emulab-devel/sample_build/sbin/plabnode";
my $PLABDIST = "/users/mshobana/CloudLabonESI/emulab-devel-new/emulab-devel/sample_build/sbin/plabdist";
my $PLABHTTPD = "/users/mshobana/CloudLabonESI/emulab-devel-new/emulab-devel/sample_build/sbin/plabhttpd";
# XXX - testing
#my $PLABNODE = "/home/kwebb/bin/randsleep.pl";

my $PLABMOND_PID    = PLABMOND_PID();
my $PLABMOND_EID    = PLABMOND_EID();
my $PLABHOLDING_PID = PLABHOLDING_PID();
my $PLABHOLDING_EID = PLABHOLDING_EID();

my $plcname = '';
my $plcvtype = '';

sub new($$$$$) {

    # The next two lines are some voodoo taken from perltoot(1)
    my $proto = shift;
    my $class = ref($proto) || $proto;

    my ($plcid, $poolname, $poolpid, $pooleid, $chpid2pool) = @_;
    $plcname = $plcid;

    #
    # Create the actual object
    #
    my $self = {};

    $self->{'NAME'} = $poolname;
    $self->{'PID'}  = $poolpid;
    $self->{'EID'}  = $pooleid;
    $self->{'CHPID2POOL'} = $chpid2pool;
    $self->{'PNODES'}  = {};
    $self->{'PENDING'} = {};

    # grab the vtype for this plc:
    my $qr = DBQueryFatal("select node_type from plab_plc_info" .
                          " where plc_name='$plcname'");
    if ($qr->num_rows() < 1) {
        die "could not find vtype for plc $plcname!";
    }
    elsif ($qr->num_rows() > 1) {
        die "too many possible vtypes for plc $plcname!";
    }
    my @qrow = $qr->fetchrow_array();
    $plcvtype = $qrow[0];

    bless($self,$class);
    return $self;
}

#
# Things to do to check a node in the bad pool:
# 1) Ping the node (maybe with ssh) (?) - not done right now
# 2) Try to instantiate the sliver via plabnode
# 3) Try to run vnodesetup on the instantiated node.
# 4) Wait for ISUP (or failure/timeout).
#
sub checknextnode($) {
    my $self = shift;

    my $now = time();
    my $pnode = $self->getnextchecknode();

    # Nothinig to check!
    if (!$pnode) {
        return 1;
    }

    # Grab the vnode for this pnode (service sliver vnode)
    my $vnode = $self->getsvcvnode($pnode->{'name'});

    if (!defined($vnode)) {
        print "Could not find vnode associated with $pnode!\n";
        return 1;
    }

    print "Pool: $self->{'NAME'}: Testing node $pnode->{'name'} at ".
        TimeStamp() . "\n";

    my $chpid = fork();

    if ($chpid) {
        # Update node attributes
        $pnode->{'lastcheckstart'} = $now;
        $pnode->{'vnode'} = $vnode;
        $pnode->{'mode'} = $SETUPMODE;
        $pnode->{'pid'} = $chpid;
        $pnode->{'timeout'} = $now + $VNODESETUPTIMEOUT;
        $self->{'PENDING'}->{$pnode->{'name'}} = $pnode;
        $self->{'CHPID2POOL'}->{$chpid} = $self;

        return 0;
    }

    # Worker process.
    else {
        TBdbfork();	# So we get the event system fork too ...
        # Make sure vnode is in the proper state before trying to
        # bring it up.
        TBSetNodeEventState($vnode, TBDB_NODESTATE_SHUTDOWN());

        # XXX: should probably look to see if we have an RCAP for this
        #      vnode and try to clean it up first if so.

        if (TBForkCmd("$PLABNODE -f alloc $PLABMOND_PID ".
                      "$PLABMOND_EID $vnode",1)) {
            print "*** Vserver instantiation failed: $vnode\n";
            # XXX: Should check DB state instead.
            exit($BADINST);
        }

	# Do this before rootball/httpd to avoid wasted bandwidth/time.
	# However, wastes resources on boss by not exec'ing this; we have a
	# whole extra process hanging around just so we can do the rootball 
	# and httpd stuff after.  XXX!

	my $vres = TBForkCmd("$SSH -host $vnode $CLIENT_BIN/vnodesetup" . 
			     " -p $vnode");
	if ($vres) {
	    print "*** Vnodesetup failed: $vnode\n";
	    exit($vres);
	}

	exit($vres);

        #exec "$SSH -host $vnode $CLIENT_BIN/vnodesetup -p $vnode" or
        #    die "Yike! Can't exec command!\n";
    }

    # NOTREACHED
}

sub getnextchecknode($) {
    my $self = shift;

    my $retnode = "";
    my $nextcheck = $BIGINT;

    foreach my $pnode (values %{$self->{'PNODES'}}) {
        my $nchecktime = $pnode->{'nextchecktime'};
        if (!exists($self->{'PENDING'}->{$pnode->{'name'}}) and
            $nchecktime < $nextcheck) {
            $nextcheck = $nchecktime;
            $retnode = $pnode;
        }
    }

    return $retnode;
}
    

#
# XXX: comment.
#
sub getnextchecktime($) {
    my $self = shift;
    
    my $nextnode = $self->getnextchecknode();

    if ($nextnode) {
        return $nextnode->{'nextchecktime'}
    }

    return $BIGINT; # XXX
}

sub getnexttimeout($) {
    my $self = shift;

    my $timeout = $BIGINT; # XXX

    foreach my $pnode (values %{$self->{'PNODES'}}) {
        my $ntmo = $pnode->{'timeout'};
        if ($ntmo && exists($self->{'PENDING'}->{$pnode->{'name'}})) {
            $timeout = MIN($ntmo, $timeout);
        }
    }

    return $timeout;
}

sub getnextservicetime($) {
    my $self = shift;

    return MIN($self->getnexttimeout(), $self->getnextchecktime());
}


#
# XXX: Comment me
#
sub processchild($$$) {
    my $self   = shift;
    my $chpid  = shift;
    my $exstat = shift;

    my $pnode;
    my $now = time();
    my $bad = 0;

    foreach my $findpnode (values %{$self->{'PENDING'}}) {
        if (defined($findpnode->{'pid'}) and $findpnode->{'pid'} == $chpid) {
            $pnode = $findpnode;
            last;
        }
    }

    if (!defined($pnode)) {
        print "Pool: $self->{'NAME'}: $chpid not found in pending list!\n";
        return 0;
    }

    # Setup log entry prefix
    my $logmsg = "$self->{'NAME'}, $pnode->{'name'}, ";

    # Clear pid entry - child has gone away.
    delete $pnode->{'pid'};

    # Check the nodes to find out which are up, and which failed
    # in the vnode_setup we just ran.
    print "Pool: $self->{'NAME'}: Checking status of ".
          "$pnode->{'name'} (pid: $chpid) @ ". `date`;

    # XXX: ignore teardown mode for now (except to clear from pending list).
    if ($pnode->{'mode'} eq $TEARDOWNMODE) {
        delete $self->{'PENDING'}->{$pnode->{'name'}};
        if (!$exstat) {
            print "Teardown of $pnode->{'vnode'} complete\n";
            Log(STATUSLOG($plcname),
		$logmsg . "teardown, success, teardown succeeded.");
        } else {
            print "Teardown of $pnode->{'vnode'} failed: $exstat\n";
            Log(STATUSLOG($plcname),
		$logmsg . "teardown, fail, teardown failed.");
        }

        return 1;
    }

    SWRN1: for ($exstat) {
        WIFSIGNALED($_) && do {
            if ($now > $pnode->{'timeout'}) {
                print "Timeout waiting for $pnode->{'vnode'} to instantiate.\n";
                $logmsg .= "setup, fail, timeout waiting for node.";
            }
            else {
                print "Setup of $pnode->{'vnode'} killed for unknown reason.\n";
                $logmsg .= "setup, fail, killed - unknown reason.";
            }
            $bad = 1;
            last SWRN1;
        };

        WEXITSTATUS($_) == $BADINST && do {
            print "Instantiation of $pnode->{'vnode'} failed.\n";
            $bad = 1;
            $logmsg .= "setup, fail, vserver instantiation failed.";
            last SWRN1;
        };

        WEXITSTATUS($_) > 0 && do {
            print "Vnodesetup failed on $pnode->{'vnode'}.\n";
            $logmsg .= "setup, fail, vnodesetup failed (excode: $exstat).";
            $bad = 1;
            last SWRN1;
        };

        # default
        print "Node setup succeeded on $pnode->{'vnode'}.\n".
              "   Waiting for node to hit ISUP.\n";
        $bad = 0;
    }

    # Log success/failure in any case.
    # XXX: do this!
                
    if ($bad) {
        # If setup failed, schedule a vnode teardown.
        $self->teardownnode($pnode);
        $self->calcnextcheck($pnode);
        $pnode->{'consecfails'}++;
        Log(STATUSLOG($plcname), $logmsg);
    } else {
        # Instantiation was successful.
        # Setup a timeout to wait for ISUP.
        $pnode->{'timeout'} = $now + $ISUPWAITTIME;
    }

    return 0;
}

#
# XXX: Comment me
#
sub checkexpiration($) {
    my $self = shift;
    my $now = time();
    my $numfinished = 0;

    foreach my $pnode (values %{ $self->{'PENDING'} }) {

        # ISUP or TBFAILED?  Check for these before timeout.
        my $state = TBDB_NODESTATE_UNKNOWN();
        if (TBGetNodeEventState($pnode->{'vnode'}, \$state)) {
            if ($pnode->{'mode'} eq $SETUPMODE) {
                if ($state eq TBDB_NODESTATE_ISUP()) {
                    # Yes!  Node is up.
                    print "Setup of $pnode->{'vnode'} on $pnode->{'name'} ".
                        " succeeded\n";
                    Log(STATUSLOG($plcname),
			"$self->{'NAME'}, $pnode->{'name'}, ".
                        "setup, success, node came up successfully.");
                    $self->nodesetupcomplete($pnode);
                    $numfinished++;
                    next;
                }
                elsif ($state eq TBDB_NODESTATE_TBFAILED()) {
                    $self->teardownnode($pnode);
                    $self->calcnextcheck($pnode);
                    $pnode->{'consecfails'}++;
                    next;
                }
            }
        } else {
            print "Error getting event state for $pnode->{'vnode'}\n";
        }

        # Have we timed out waiting for this node?
        if ($pnode->{'timeout'} <= $now) {
            $pnode->{'timeout'} = 0;
            print "Pool: $self->{'NAME'}: $pnode->{'vnode'} timeout.\n";
            # Node has an associated PID
            if (defined($pnode->{'pid'})) {
                kill("TERM", $pnode->{'pid'});
                # Cleanup/processing handled in processchild()
            }
            # ... else we were waiting for an ISUP
            else {
                $self->teardownnode($pnode);
                $self->calcnextcheck($pnode);
                $pnode->{'consecfails'}++;
            }
        }
    }

    return $numfinished;
}


sub teardownnode($$;$) {
    my ($self, $pnode, $reason) = @_;

    my $now = time();

    my $chpid = fork();

    if ($chpid) {
        # Update node attributes, return pid of worker proc.
        $pnode->{'pid'} = $chpid;
        $pnode->{'mode'} = $TEARDOWNMODE;
        $pnode->{'timeout'} = $now + $TEARDOWNTIMEOUT;
        $self->{'PENDING'}->{$pnode->{'name'}} = $pnode;
        $self->{'CHPID2POOL'}->{$chpid} = $self;

        return;
    }

    # Worker process.
    else {
        TBdbfork();	# So we get the event system fork too ...
        my $vnode = $pnode->{'vnode'};

        # Free the vserver, if possible.
        TBForkCmd("$SSH -host $vnode $CLIENT_BIN/vnodesetup -p -k $vnode",1);

        # Make sure vnode is in the proper state (regardless of the success
        # or failure of the previous command.
        TBSetNodeEventState($vnode, TBDB_NODESTATE_SHUTDOWN());

        # Try to ssh in and kill the vserver.
        exec "$PLABNODE -f free $PLABMOND_PID $PLABMOND_EID $vnode" or
            die "Doh!  Can't exec command!\n";
    }

    # NOTREACHED
}


# XXX: may be bogus, but it'll do for now.
my $MININTERVAL = 300;
my $MAXINTERVAL = 12 * 3600;
sub calcnextcheck($$;$) {
    my ($self, $pnode, $reason) = @_;

    my $now = time();

    my $numfails  = $pnode->{'consecfails'} ? $pnode->{'consecfails'} : 1;
    my $nextint = int($numfails * $numfails * $MININTERVAL);
    $pnode->{'nextchecktime'} = 
        $now + MIN($MAXINTERVAL, $nextint) + int(rand(120));
}

#
# Check vnode status, moving nodes back into production if they booted up,
# and leaving them in hwdown if they didn't.
#
sub nodesetupcomplete($$) {
    my $self  = shift;
    my $pnode = shift;

    $pnode->{'timeout'} = 0;
    $pnode->{'consecfails'} = 0;
    $pnode->{'consecsuccess'} = 1;
    delete $self->{'PENDING'}->{$pnode->{'name'}};

    my $exptidx;
    if (!TBExptIDX($PLABHOLDING_PID, $PLABHOLDING_EID, \$exptidx)) {
	print "*** WARNING: No such experiment $PLABHOLDING_EID!\n";
	return;
    }

    #
    # It came up! Move the pnode out of hwdown and back into
    # normal holding experiment.
    #
    DBQueryWarn("update reserved set exptidx=$exptidx, ".
                "  pid='$PLABHOLDING_PID',eid='$PLABHOLDING_EID' ".
                "   where node_id=\"$pnode->{'name'}\"");
    print "$pnode->{'name'} brought back from the afterworld at ".
        TimeStamp() . "\n";
    
    TBSetNodeLogEntry($pnode->{'name'}, "root", TB_DEFAULT_NODELOGTYPE(),
                      "'Moved to $PLABHOLDING_EID; ".
                      "$plcvtype node $pnode->{'vnode'} setup okay by monitor.'");

    # XXX: move to goodpool.

    return;
}


#
# Get vnode entries (and their corresponding pnodes) 
# for the service slice vservers.
# 
sub getsvcvnode($$) {
    my $self  = shift;
    my $pnode = shift;

    my $qres =
        DBQueryWarn("select r.node_id from reserved as r ".
                    "left join nodes as n on n.node_id=r.node_id ".
                    "where r.pid='$PLABMOND_PID' and ".
                    "      r.eid='$PLABMOND_EID' and ".
                    "      n.phys_nodeid='$pnode'");
    
    if (!$qres || !$qres->num_rows()) {
        print "Failed to get vnode from DB in getsvcvnode()! \n";
        return undef;
    }

    my @row = $qres->fetchrow_array();

    return $row[0];
}


# Make perl happy...
1;
