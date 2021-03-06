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
# plabmonitor node pool module for checking up on "good" plab
# nodes.
#

package plabmon_goodpool;

#use strict;
use English;

use POSIX qw(WIFSIGNALED WEXITSTATUS);

$| = 1; # Turn off line buffering on output

use lib "/users/mshobana/CloudLabonESI/emulab-devel-new/emulab-devel/sample_build/lib";
use libdb;
use libtestbed;
use libplabmon;
use Node;

my $BADINST = 99;

my $VNODESETUPTIMEOUT = 600; # XXX: need to get from sitevar, or
                             #      pass in via new().
my $ISUPWAITTIME      = 600;      # XXX: likewise...
my $TEARDOWNTIMEOUT   = 300;   # XXX: ...

my $SETUPMODE        = "SETUPMODE";
my $TEARDOWNGOODMODE = "TEARDOWNGOODMODE";
my $TEARDOWNBADMODE  = "TEARDOWNBADMODE";

my $SETUPFAIL    = "SETUPFAIL";
my $SETUPSUCCESS = "SETUPSUCCESS";

my $BIGINT = 9999999999;

my $CLIENT_BIN = "/usr/local/etc/emulab";
my $SSH = "/users/mshobana/CloudLabonESI/emulab-devel-new/emulab-devel/sample_build/bin/sshtb -n";
my $PLABNODE = "/users/mshobana/CloudLabonESI/emulab-devel-new/emulab-devel/sample_build/sbin/plabnode";
my $VNODE_SETUP = "/users/mshobana/CloudLabonESI/emulab-devel-new/emulab-devel/sample_build/sbin/vnode_setup";
my $NFREE = "/users/mshobana/CloudLabonESI/emulab-devel-new/emulab-devel/sample_build/bin/nfree";
# XXX - testing
#my $PLABNODE = "/home/kwebb/bin/randsleep.pl";

my $PLABDOWN_PID    = PLABDOWN_PID();
my $PLABDOWN_EID    = PLABDOWN_EID();
my $PLABTESTING_PID = PLABTESTING_PID();
my $PLABTESTING_EID = PLABTESTING_EID();

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

    # Clean up anything left behind by a terminated monitor
    # XXX: this is kind of hacky, but it works.
    #
    my @vnodes = ();
    my $qres = DBQueryFatal("select r.node_id" . 
			    " from reserved as r" . 
			    " left join plab_slice_nodes as psn" . 
			    "   on r.node_id=psn.node_id" . 
			    " left join plab_plc_info as ppi" . 
			    "   on psn.plc_idx=ppi.plc_idx" . 
			    " left join nodes as n" . 
			    "   on r.node_id=n.node_id" . 
			    " where r.pid='$PLABTESTING_PID'" . 
			    "   and r.eid='$PLABTESTING_EID'" . 
			    "   and ppi.plc_name='$plcname'" . 
			    "   and n.type=ppi.node_type");
    if ($qres->num_rows()) {
	while (my @row = $qres->fetchrow_array()) {
	    my $vnodename = $row[0];
	    push @vnodes, $vnodename;
	}
    }
    if (@vnodes) {
	my $nodelist = join(" ",@vnodes);
        system("$VNODE_SETUP -f -k -n 100" . 
	       " $PLABTESTING_PID $PLABTESTING_EID $nodelist");
        Node::DeleteVnodes(@vnodes);
    }

    bless($self,$class);
    return $self;
}

#
# Things to do to check a node in the good pool:
# 1) Ping the node (maybe with ssh) (?) - not done right now
# 2) Try to instantiate a sliver via plabnode
# 3) Try to run vnodesetup on the instantiated node.
# 4) Wait for ISUP (or failure/timeout).
#
sub checknextnode($) {
    my $self = shift;

    my $now = time();
    my $pnode = $self->getnextchecknode();

    # Nothing to check!
    if (!$pnode) {
        return 1;
    }

    # Grab a new sliver to test with
    my @vnodes = ();
    my %options = ( 'pid'    => $PLABTESTING_PID,
                    'eid'    => $PLABTESTING_EID,
                    'count'  => 1,
                    'vtype'  => "$plcvtype",
                    'nodeid' => $pnode->{'name'});
    if (Node::CreateVnodes(\@vnodes, \%options)) {
        print "Failed to allocate vnode for $pnode->{'name'}!\n";
        return 1;
    }

    my $vnode = $vnodes[0];

    if (!defined($vnode)) {
        print "Could not create vnode associated with $pnode!\n";
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

        if (TBForkCmd("$PLABNODE -f alloc $PLABTESTING_PID ".
                      "$PLABTESTING_EID $vnode",1)) {
            print "*** Vserver instantiation failed: $vnode\n";
            # XXX: Should check DB state instead.
            exit($BADINST);
        }

        exec "$SSH -host $vnode $CLIENT_BIN/vnodesetup -p $vnode" or
            die "Yike! Can't exec command!\n";
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

    # Handle vnode teardown
    if ($pnode->{'mode'} eq $TEARDOWNGOODMODE or
        $pnode->{'mode'} eq $TEARDOWNBADMODE) {

        if (!$exstat) {
            print "Teardown of $pnode->{'vnode'} complete\n";
            Log(STATUSLOG, $logmsg . "teardown, success, teardown succeeded.");
        } else {
            print "Teardown of $pnode->{'vnode'} failed: $exstat\n";
            Log(STATUSLOG, $logmsg . "teardown, fail, teardown failed.");
        }

        delete $self->{'PENDING'}->{$pnode->{'name'}};
        # Delete the vnode created to test this node - we're done with it.
        my @vnodes = ($pnode->{'vnode'},);
        Node::DeleteVnodes(@vnodes);
        $pnode->{'vnode'} = "";

        if ($pnode->{'mode'} eq $TEARDOWNGOODMODE) {
            $self->nodesetupcomplete($pnode);
        }
        elsif ($pnode->{'mode'} eq $TEARDOWNBADMODE) {
            $self->movetodownpool($pnode);
        }

        return 1;
    }

    # Test exit status for setup mode(s)
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
            $logmsg .= "setup, fail, vserver instantiation failed.";
            $bad = 1;
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

    if ($bad) {
        # If setup failed, schedule a vnode teardown.
        $self->teardownnode($pnode, $SETUPFAIL);
        Log(STATUSLOG, $logmsg);
    } else {
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
                    Log(STATUSLOG, "$self->{'NAME'}, $pnode->{'name'}, ".
                        "setup, success, node came up successfully.");
                    $self->teardownnode($pnode, $SETUPSUCCESS);
                    next;
                }
                elsif ($state eq TBDB_NODESTATE_TBFAILED()) {
                    $self->teardownnode($pnode, $SETUPFAIL);
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
                $self->teardownnode($pnode, $SETUPFAIL);
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
        $pnode->{'timeout'} = $now + $TEARDOWNTIMEOUT;
        $self->{'PENDING'}->{$pnode->{'name'}} = $pnode;
        $self->{'CHPID2POOL'}->{$chpid} = $self;

        if ($reason eq $SETUPFAIL) {
            $pnode->{'mode'} = $TEARDOWNBADMODE;
        }
        elsif ($reason eq $SETUPSUCCESS) {
            $pnode->{'mode'} = $TEARDOWNGOODMODE;
        }

        return;
    }

    # Worker process.
    else {
        TBdbfork();	# So we get the event system fork too ...
        my $vnode = $pnode->{'vnode'};

        # Try to ssh in and kill processes running in the vserver.
        TBForkCmd("$SSH -host $vnode $CLIENT_BIN/vnodesetup -p -k $vnode",1);

        # Make sure vnode is in the proper state (regardless of the success
        # or failure of the previous command.
        TBSetNodeEventState($vnode, TBDB_NODESTATE_SHUTDOWN());

        # Free the vserver, if possible.
        exec "$PLABNODE -f free $PLABTESTING_PID $PLABTESTING_EID $vnode" or
            die "Doh!  Can't exec command!\n";
    }

    # NOTREACHED
}


# XXX: may be bogus, but it'll do for now.
my $MININTERVAL = 600;
my $MAXINTERVAL = 3600;
sub calcnextcheck($$;$) {
    my ($self, $pnode, $reason) = @_;

    my $now = time();

    my $numsuccess = $pnode->{'consecsuccess'} ? $pnode->{'consecsuccess'} : 1;
    my $nextint    = int(2 * $numsuccess * $MININTERVAL);
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
    $pnode->{'consecsuccess'}++;

    #
    # It came up!  Calculate the next check time and move on...
    #
    $self->calcnextcheck($pnode);

    return;
}

sub movetodownpool($$) {
    my $self  = shift;
    my $pnode = shift;

    $pnode->{'consecsuccess'} = 0;
    $pnode->{'consecfails'} = 1;

    my $exptidx;
    if (!TBExptIDX($PLABDOWN_PID, $PLABDOWN_EID, \$exptidx)) {
	print "*** WARNING: No such experiment $PLABDOWN_EID!\n";
	return;
    }

    #
    # It failed to come up. Move the pnode to hwdown...
    #
    DBQueryWarn("update reserved set exptidx=$exptidx, ".
                "  pid='$PLABDOWN_PID',eid='$PLABDOWN_EID' ".
                "   where node_id=\"$pnode->{'name'}\"");
    print "$pnode->{'name'} failed testing; sent to hwdown at ".
        TimeStamp() . "\n";
    
    TBSetNodeLogEntry($pnode->{'name'}, "root", TB_DEFAULT_NODELOGTYPE(),
                      "'Moved to $PLABDOWN_EID; ".
                      "$plcvtype node $pnode->{'vnode'} setup failed by monitor.'");
}

# Make perl happy...
1;
