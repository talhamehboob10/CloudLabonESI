#! /usr/bin/perl -w
#
# Copyright (c) 2014, Carnegie Mellon University.
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions
# are met:
# 1. Redistributions of source code must retain the above copyright
#    notice, this list of conditions and the following disclaimer.
# 2. Redistributions in binary form must reproduce the above copyright
#    notice, this list of conditions and the following disclaimer in the
#    documentation and/or other materials provided with the distribution.
# 3. Neither the name of the University nor the names of its contributors
#    may be used to endorse or promote products derived from this software
#    without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
# ``AS IS'' AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
# LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
# A PARTICULAR PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL THE COPYRIGHT
# HOLDERS OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT,
# INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
# BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS
# OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED
# AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
# LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY
# WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
# POSSIBILITY OF SUCH DAMAGE.
#

#
# power_ibmbc.pm  IBM BladeCenter emulab power manager
# 16-Dec-2014  chuck@ece.cmu.edu
#

#
# this should be pretty simple.  put root's emulab ssh key in the
# USERID's account's authorized_keys, then we can simply ssh over
# to the manager to perform power operations
#

package power_ibmbc;

use strict;
use IPC::Open2;
use POSIX;

#
# configuration
#
my($TB, $USERID, $SSHKEY, $TIMEOUT);

$TB = "/users/achauhan/Cloudlab/CloudLabonESI/emulab-devel-new/emulab-devel/sample_build/tbsetup";
$USERID = 'USERID';             # userid on remote, this the default
$SSHKEY = "$TB/etc/ibmbc";      # will use root key if not present
$TIMEOUT = 10;                  # 10 second timeout on ssh

$ENV{'PATH'} = '/bin:/usr/bin:/usr/local/bin';     # untaint path

#
# helper fns
#

#
# twaitpid(seconds,pidspec): timed wait system call.
#
# seconds: undef - disable timeout, could wait forever
#          < 0   - invalid param, converted to zero
#          0     - poll for process, don't block
#          > 0   - max wait time
#
# pidspec: -1    - wait for any child process
#          0     - wait for any child in process group
#          > 0   - wait for a specific pid
#          < -1  - wait for any process in absolute value process group
#     
# return values:
#         -1     - no processes that match pidspec that we could wait for
#         0      - timed out before matching process could exit
#         pid    - process id of process that we waited for
#
# note that you can only wait for your own child processes (i.e.
# you can't wait for other people's processes to exit, that gives -1).
#
sub twaitpid {
    my($secs, $pid) = @_;  
    my($rv, $wval);

    $secs = 0 if ($secs < 0);        # usage error, convert to poll
                
    return(waitpid($pid, 0)) if (!defined($secs));
    return(waitpid($pid, WNOHANG)) if ($secs == 0); 
            
    # must do this in an eval to trap the timeout signal
    $rv = eval {
        local $SIG{'ALRM'} = sub { die "timeout" };
        alarm($secs);
        $wval = waitpid($pid, 0);
        alarm(0);
        $wval;      
    };     
    $rv = 0 if (!defined($rv));    # happens if timeout fires

    return($rv);
}    

#
# timed_cmd(timeout, cmd...): run a cmd w/time limit. 
# return value (where exit-value is >= 0):
#  command ran: [exit-value, outline1, outline2, ... ]
#  run failed:  [-1, error-message]
#
sub timed_cmd {
    my($secs) = shift;
    my(@cmd) = @_;
    my(@rv, $endat, $childpid, $rd, $wr);
    my($rin, $rout, $to, $nfound, $outbuf, $cnt, $waitrv);

    # init status and compute timeout (if enabled)
    $rv[0] = undef;
    $endat = (defined($secs)) ? (time + $secs) : undef;
    
    # fork child process to run the command
    $childpid = open2($rd, $wr, @cmd);
    if ($childpid <= 0) {
        return([-1, "open2 failed"]);
    }

    # parent loops for output
    $outbuf = '';
    while (1) {
        $rin = '';
        vec($rin, fileno($rd), 1) = 1;
        if (defined($endat)) {
            $to = $endat - time;
            $to = 0 if ($to < 0);
        } else {
            undef($to);
        }
        $nfound = select($rout=$rin, undef, undef, $to);
        if ($nfound < 1) {  # select error, or timeout error
            kill 9, $childpid;
            @rv = (-1, (($nfound < 0) ? "select error $!" : "timeout"));
            last;
        }
        $cnt = sysread($rd, $outbuf, 1024, length($outbuf));

        # refactor output into lines and push on @rv
        while (($_ = index($outbuf, "\n")) != -1) {
            push(@rv, substr($outbuf, 0, $_));
            $outbuf = substr($outbuf, $_ + 1);
        }

        if ($cnt < 1) {     # eof
            push(@rv, $outbuf) if (length($outbuf));  # residual
            last;
        }

    }
    
    #
    # dispose of the fds, and collect the wait status.
    # we use twaitpid to handle the rare case where child closes stdout
    # but doesn't actually exit (it shouldn't do that).
    #
    close($rd);
    close($wr);
    $waitrv = twaitpid(1, $childpid);
    if ($waitrv != $childpid) {
        kill 'KILL', $childpid;   # it is sure to be dead now
        twaitpid(10, $childpid);
    }
    $rv[0] = $? >> 8 unless (defined($rv[0]));  # if no error -1 in it
    return(\@rv);
}


#
# new(obj,dev,debug): create object.  the object is a blessed hash
# where we store the device name and debug level.
#
sub new($$;$) {
    my($class, $dev, $dbg, $obj);

    $class = shift;
    $class = ref($class) if (ref($class));      # save class for blessing

    ($dev, $dbg) = @_;
    $dbg = 0 unless (defined($dbg));

    print "power_ibmbc: new(dev=$dev, dbg=$dbg)\n" if ($dbg);

    $obj = { 'DEBUG' => $dbg, 'DEVICENAME' => $dev };
    
    bless($obj, $class);
    return($obj);
}

#
# power(obj,op,ports): power operation.  return error count.
#
sub power {
    my($self, $op, @ports) = @_;
    my($mm_host, @sk, $port, $rv, $blade, $errcnt);

    $mm_host = $USERID . '@' . $$self{'DEVICENAME'};
    @sk = ("-i", $SSHKEY) if (-r $SSHKEY);

    #
    # maps to this:
    # ssh USERID@narwhal4-mm power -on -T 'blade[2]'
    # ssh USERID@narwhal4-mm power -off -T 'blade[2]'
    # ssh USERID@narwhal4-mm power -cycle -T 'blade[2]'
    #
    foreach $port (@ports) {
        $blade = sprintf 'system:blade[%d]', $port;
        $rv = timed_cmd($TIMEOUT, "/usr/bin/ssh", @sk, $mm_host, 
                                  "power", "-$op", "-T", $blade);

        $errcnt++ if (ref($rv) ne 'ARRAY' || $$rv[0] != 0);

        print "power_ibmbc: result: ", join("\n", @$rv), "\n"
               if ($$self{'DEBUG'} && ref($rv) eq 'ARRAY');
    }

    return($errcnt);
}
    

#
# status(obj,\%sthref): power status into sthref.  return error count.
#
sub status {
    my($self, $href) = @_;
    my($mm_host, @sk, $rv, $ln, %present, @outs, $bl, $blade, $state, $got);

    $mm_host = $USERID . '@' . $$self{'DEVICENAME'};
    @sk = ("-i", $SSHKEY) if (-r $SSHKEY);

    $rv = timed_cmd($TIMEOUT, "/usr/bin/ssh", @sk, $mm_host, 
                              "list", "-l", "all");
    return(1) unless ($$rv[0] == 0);
    shift(@$rv);    # discard status

    foreach $ln (@$rv) {
        next unless ($ln =~ /^\s*blade\[(\d+)\]/);
        $present{$1} = 1;
    }
    @outs = sort { $a <=> $b } keys %present;

    print "power_ibmbc: PRESENT: ", 
      join(' ', @outs), "\n" if ($$self{'DEBUG'});

    #
    # XXX: is there a command that can give us all the blade's
    # status in one ssh command?
    #
    foreach $bl (@outs) {
        $blade = sprintf 'system:blade[%d]', $bl;
        $rv = timed_cmd($TIMEOUT, "/usr/bin/ssh", @sk, $mm_host, 
                        "power", "-T", $blade, "-state");
        $state = 'Unknown';
        if ($$rv[0] == 0) {
            $got = $$rv[$#$rv];
            $got = $1 if ($got =~ /^(\w+)/);
            $state = $got if ($got eq 'On' || $got eq 'Off');
        }
        $$href{"outlet$bl"} = $state;
        print "power_ibmbc: blade/outlet $bl = $state\n" if ($$self{'DEBUG'});
    }

    return(0);
}

1;
