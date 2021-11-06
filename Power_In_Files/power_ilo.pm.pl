#!/usr/bin/perl -wT

#
# Copyright (c) 2008-2021 University of Utah and the Flux Group.
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
# Handle iLO[23] remote power control.
# Also handle DRAC since its so similar.
#
# Even though not that similar, also handle IPMI so that we
# can have per-node passwords not allowed by power_ipmi.
# "ipmi15" uses the IPMI 1.5 "lan" interface, "ipmi20" uses
# the IPMI 2.0 "lanplus" interface.
#
# Node must have an interface such that role='mngmnt' and
# interface_type='ilo[23]'.
#
# Supports either pubkey or passwd auth, depending on what's in db.
#

package power_ilo;

use strict;
use warnings;

use Exporter;
our @ISA = ("Exporter");
our @EXPORT = qw( iloctrl ilostatus );

use lib "@prefix@/lib";
use libdb;
use emutil;
use English;
use IO::Pty;
use POSIX qw(setsid);
use POSIX ":sys_wait_h";

my $debug = 0;
# Always parallelize for now cause we are vulnerable to timeouts with 
# unreachable nodes or weird iLO crap.
# NOTE: ipmi doesn't appear to be handled if $parallelize isn't set.
my $parallelize = 1;

# Turn off line buffering on output
$| = 1;

my %portinfo = ();

sub ilostatus($$@) {
    my ($type,$statusp,@nodes) = @_;

    return iloaction($type, "status", $statusp, @nodes);
}

#
# usage: iloctrl(type, cmd, nodes)
# type = { "ilo" | "ilo2" | "ilo3" | "drac" | "ipmi15" | "ipmi20" }
# cmd = { "forcecycle" | "cycle" | "on" | "off" | "status" }
# nodes = list of one or more physical node names
#
# Returns 0 on success. Non-zero on failure.
# 
sub iloctrl($$@) {
    my ($type,$cmd,@nodes) = @_;

    # XXX it would be useful to propagate the individual node status here too
    my %status = ();
    return iloaction($type, $cmd, \%status, @nodes);
}

#
# Internal command to do the work.
#
# usage: iloaction(type, cmd, status, nodes)
# type = { "ilo" | "ilo2" | "ilo3" | "drac" | "ipmi15" | "ipmi20" }
# cmd = { "forcecycle" | "cycle" | "on" | "off" | "status" }
# status = hash ref keyed by node with value of per-node return status
# nodes = list of one or more physical node names
#
# Returns 0 on success. Non-zero on failure.
# 
sub iloaction($$$@) {
    my ($type,$cmd,$statusp,@nodes) = @_;
    my $exitval = 0;
    my $force = 0;

    if ($debug) {
	print "iloctrl called with $type,$cmd,(" . join(',',@nodes) . ")\n";
    }

    if ($cmd eq "forcecycle") {
	$force = 1;
	$cmd = "cycle";
    } elsif ($cmd !~ /^(cycle|on|off|status)$/) {
	warn "invalid power command '$cmd'; \n" . 
	    "  valid commands are 'cycle, 'off', 'on', and 'status'.\n";
	foreach my $n (@nodes) {
	    $statusp->{$n} = -1;
	}
	return scalar(@nodes);
    }

    my %ilo_nodeinfo = ();

    # grab ilo IP and auth info
    foreach my $n (@nodes) {
	my $res = DBQueryFatal("select IP from interfaces" . 
			       " where node_id='$n' and ".
			       " role='" . TBDB_IFACEROLE_MANAGEMENT() . "'" . 
			       "   and interface_type='$type'");
	if (!defined($res) || !$res || $res->num_rows() == 0) {
	    warn "No $type interface for $n; cannot find $type IP!\n";
	    $statusp->{$n} = -1;
	    ++$exitval;
	    next;
	}
	my ($IP) = $res->fetchrow();

	# FIXED: Handle multiple rows here like power_ipmi.pm does.
	# This is so we can grab a kgkey separately from the user password.
	$res = DBQueryFatal("select key_role,key_uid,mykey,key_privlvl" . 
			    " from outlets_remoteauth" . 
			    " where node_id='$n' and key_type='$type'");
	if (!defined($res) || !$res || $res->num_rows() == 0) {
	    warn "No $type remote auth info for $n!\n";
	    $statusp->{$n} = -1;
	    ++$exitval;
	    next;
	}
	my ($krole,$kuid,$kkey,$kgkey,$kprivlvl);
	while (my $row = $res->fetchrow_hashref()) {
	    $krole = $row->{'key_role'};
	    if ($krole eq "ipmi-passwd" || $krole eq "ssh-key") {
		$kuid = $row->{'key_uid'};
		$kkey = $row->{'mykey'};
	        if ($row->{'key_privlvl'}) {
	            $kprivlvl = $row->{'key_privlvl'};
	        }
	    }
	    elsif ($krole eq "ipmi-kgkey") {
		#
		# XXX looks like we always need a user ID.
		# Not just for the check in ipmiexec, but for ipmitool too.
		# ipmitool seems to want both uid/password in addition to key,
		# otherwise it prompts for a password.
		#
		$kuid = $row->{'key_uid'};

		($kgkey = $row->{'mykey'}) =~ s/^0x//;
	        # NOTE: key_privlvl is currently ignored in case this is the
	        # only authentication mechanism being used.
	    }
	}

	if ($kgkey && $kkey) {
	    $krole = 'ipmi-kgkey-passwd';
	}
	elsif ($kgkey) {
	    $krole = 'ipmi-kgkey';
	    # restore previous behavior
	    $kkey = $kgkey;
	    $kgkey = undef;
	    $kprivlvl = undef;
	}
	else {
	    # all of the keys were empty which is weird and the last key_role
	    # returned from the db wins
	}

	#
	# Timeout for IPMI is the interval between retries (-N in ipmitool).
	# This is a hack for slow IPMI engines that allows us to slow down
	# retries so we don't overwhelm them.
	#
	my $timeout;
	if ($type =~ /^ipmi/) {
	    $res = DBQueryFatal("select nta.attrvalue,na.attrvalue".
				"  from nodes as n".
				"  left join node_attributes as na".
				"    on n.node_id=na.node_id".
				"      and na.attrkey='power_ipmidelay'".
				"  left join node_type_attributes as nta".
				"    on n.type=nta.type".
				"      and nta.attrkey='power_ipmidelay'".
				" where n.node_id='$n'");
	    if ($res && $res->num_rows() > 0) {
		my ($nta,$na) = $res->fetchrow_array();
		if (defined($na)) {
		    $timeout = $na;
		} elsif (defined($nta)) {
		    $timeout = $nta;
		}
	    }
	}
	#
	# Otherwise (iLo), timeout represents an overall command timeout.
	#
	else {
	    $timeout = 30;
	}

	$ilo_nodeinfo{$n} = [ $n,$IP,$krole,$kuid,$kkey,$kgkey,$kprivlvl,
			      $timeout ];
    }

    if ($parallelize) {
	my $coderef = sub {
	    my ($n,$IP,$krole,$kuid,$kkey,$kgkey,$kprivlvl,$timo) = @{ $_[0] };
	    
	    my $tret;
	    eval {
		if ($type =~ /^ipmi/) {
		    $tret = ipmiexec($n,$type,$cmd,$IP,$krole,$kuid,$kkey,$kgkey,$kprivlvl,$timo,$force);
		} else {
		    $tret = iloexec($n,$type,$cmd,$IP,$krole,$kuid,$kkey,$timo);
		}
	    };
	    if ($@) {
		print "$@";
		return -1;
	    }
	    return $tret;
	};
	my @results = ();
	my @ilos    = values(%ilo_nodeinfo);
	
	if (ParRun(undef, \@results, $coderef, @ilos)) {
	    print STDERR "*** power_ilo: Internal error in ParRun()!\n";
	    return -1;
	}
	#
	# Check the exit codes. 
	# Is this awkward or what?
	#
	for (my $i = 0; $i < @ilos; $i++) {
	    my $n = $ilos[$i]->[0];
	    my $rv = ($results[$i] >> 8);
	    $statusp->{$n} = $rv;
	    if ($cmd eq "status") {
		$exitval++
		    if ($rv < 0);
	    } else {
		++$exitval
		    if ($rv != 0);
	    }
	}
    }
    else {
	for my $key (keys(%ilo_nodeinfo)) {
	    my ($n,$IP,$krole,$kuid,$kkey,$kgkey,$kprivlvl,$timo) = @{$ilo_nodeinfo{$key}};

	    my $rv;
	    if ($type =~ /^ipmi/) {
		$rv = ipmiexec($n,$type,$cmd,$IP,$krole,$kuid,$kkey,$kgkey,$kprivlvl,$timo,$force);
	    } else {
		$rv = iloexec($n,$type,$cmd,$IP,$krole,$kuid,$kkey,$timo);
	    }
	    $statusp->{$n} = $rv;
	    ++$exitval
		if ($rv < 0);
	}
    }
    return $exitval;
}

#
# Arguments: $node_id,$type,$cmd,$IP,$key_role,$key_uid,$key[,$timeout]
# on/off/cycle returns: 0 for success, < 0 otherwise
# status returns: 0 for off, 1 for on, -1 for error
#
sub iloexec($$$$$$$;$) {
    my ($node_id,$type,$cmd,$IP,$key_role,$key_uid,$key,$timeout) = @_;

    if ($debug) {
	print "iloexec called with (" . join(',',@_) . ")\n";
    }

    if (!defined($type) || !defined($cmd) || !defined($IP) 
	|| !defined($key_role) || !defined($key_uid) || !defined($key)) {
	warn "Incomplete argument list, skipping node" . 
	    (defined($node_id)?" $node_id":"");

	return -1;
    }

    my $power_cmd;
    if ($cmd eq 'cycle') {
	$power_cmd = ($type eq "drac" ?
		      'racadm serveraction powercycle' : 'power reset');
    }
    elsif ($cmd eq 'reset') {
	$power_cmd = ($type eq "drac" ?
		      'racadm serveraction hardreset' : 'power warm');
    }
    elsif ($cmd eq 'on') {
	$power_cmd = ($type eq "drac" ?
		      'racadm serveraction powerup' : 'power on');
    }
    elsif ($cmd eq 'off') {
	$power_cmd = ($type eq "drac" ?
		      'racadm serveraction powerdown' : 'power off');
    }
    elsif ($cmd eq 'status') {
	$power_cmd = ($type eq "drac" ?
		      'racadm serveraction powerstatus' : 'power');
    }
    else {
	warn "Bad iLO power command $cmd";
	return -11;
    }

    if ($type ne 'ilo' && $type ne 'ilo2' && $type ne 'ilo3' &&
	$type ne "drac") {
	warn "Unsupported iLO/DRAC type $type!";
	return -7;
    }

    my @expect_seq;
    my $ssh_cmd = "ssh -o StrictHostKeyChecking=no -l '$key_uid'";

    if ($key_role eq 'ssh-key') {
	if ($key ne '') {
	    $ssh_cmd .= " -i '$key'";
	}
	if ($type eq "drac") {
	    @expect_seq = (['\$ ',  $power_cmd],
			   ['\$ ',  'exit']);
	}
	else {
	    @expect_seq = (['hpiLO-> ',$power_cmd],['hpiLO-> ','exit']);
	}
    }
    elsif ($key_role eq 'ssh-passwd') {
	$ssh_cmd .= " -o PubkeyAuthentication=no";
	$ssh_cmd .= " -o PasswordAuthentication=yes";
	if ($key eq '') {
	    warn "iLO key_role ssh-passwd specified, but no passwd!";
	    return -13;
	}
	if ($type eq "drac") {
	    @expect_seq = (['password: ', $key],
			   ['\$ ',        $power_cmd],
			   ['\$ ',        'exit']);
	}
	else {
	    @expect_seq = (['password: ',$key],['hpiLO-> ',$power_cmd],
			   ['hpiLO-> ','exit']);
	}
    }
    else {
	warn "Unsupported key_role $key_role!";
	return -14;
    }

    $ssh_cmd .= " $IP";

    my $pid;
    my $sentall = 0;
    # Setup some signal handlers so we can avoid leaving ssh zombies.
    $SIG{'CHLD'} = sub { die "iloexec($node_id) child ssh died unexpectedly!"; };
    $SIG{'PIPE'} = sub { die "iloexec($node_id) ssh died unexpectedly!"; };
    if (defined($timeout)) {
	$SIG{'ALRM'} = sub {
	    $SIG{'PIPE'} = 'IGNORE';
	    $SIG{'CHLD'} = 'IGNORE';
	    kill('INT',$pid);
	    select(undef,undef,undef,0.1);
	    kill('TERM',$pid);
	    select(undef,undef,undef,0.1);
	    kill('KILL',$pid);
	    die "iloexec($node_id) timed out in ssh!";
	};

	alarm($timeout);
    }

    my $pty = IO::Pty->new() || die "can't make pty: $!";
    defined ($pid = fork()) || die "fork: $!";
    if (!$pid) {
	# Flip to UID 0 to ensure we can read whatever private key we need
	$UID = $EUID = 0;
	
	if ($debug) {
	    print "Flipped to root: $UID,$EUID\n";
	}

	# Connect our kid to the tty so the parent can chat through the pty
        POSIX::setsid();

	$pty->make_slave_controlling_terminal();

	my $tty = $pty->slave();
	my $tty_fd = $tty->fileno();
	close($pty);

	open(STDIN,"<&$tty_fd");
	open(STDOUT,">&$tty_fd");
	open(STDERR,">&STDOUT");
	close($tty);

	# Don't want ssh to prompt us via ssh-askpass!
	delete $ENV{DISPLAY};

	if ($debug) {
	    print "ssh_cmd($node_id): $ssh_cmd\n";
	}
	
	exec("$ssh_cmd") || die "exec: $!";
    }

    #
    # Talk to ssh over the pty: wait for expected output and send responses
    #
    my @lines = ();
    foreach my $es (@expect_seq) {
	my ($rval,$sval) = @$es;

	my $found = 0;
	my $line = '';
	while (1) {
	    my $char;
	    if (read($pty,$char,1) != 1) {
		warn "Error in read in iLO pseudo expect loop!\n";
		print "Had read the following lines:\n";
		foreach my $ln (@lines) {
		    print "  $ln\n";
		}
		last;
	    }
	    if ($char eq "\r" || $char eq "\n") {
		push @lines,$line;
		if ($debug) {
		    print "read '$line' while looking for '$rval'\n";
		}
		$line = '';
	    }
	    else {
		$line .= $char;
	    }

	    if ($line =~ /$rval$/) {
		print $pty $sval;
		print $pty ($type eq "ilo3" ? "\r" : "\r\n");
		if ($debug) {
		    print "sent '$sval'\n";
		}
		$found = 1;
		last;
	    }
	}

	if (!$found) {
	    # some sort of error; try to kill off ssh
	    kill(15,$pid);
	    return -16;
	}
    }
    # this is a race, but there's nothing better, because we want the remote 
    # side to see an appropriate exit so it frees its resources, so there is
    # a very miniscule chance that the connection could break and ssh could 
    # exit before we get here... but it seems unlikely.
    $SIG{'CHLD'} = 'IGNORE';

    # make sure the local ssh dies:
    my $i = 5;
    my $dead = 0;
    while (--$i) {
	my $ret = waitpid($pid,WNOHANG);
	if ($ret == -1 || $ret == $pid) {
	    $dead = 1;
	    last;
	}
	sleep(1);
    }
    kill('KILL',$pid) if (!$dead);

    if ($cmd eq "status") {
	foreach my $line (@lines) {
	    if ($line =~ /server power is currently:\s+(\S+)/) {
		return ($1 eq "Off") ? 0 : 1;
	    }
	}
	print "iLO unexpected power status:\n";
	foreach my $line (@lines) {
	    print "'$line'\n";
	}
	return -1;
    }

    # if we get here, things probably went ok...
    return 0;
}

#
# Arguments: $node_id,$type,$cmd,$IP,$key_role,$key_uid,$key[,$kgkey,$privlvl,$timeout]
# on/off/cycle returns: 0 for success, <0 on error
# status returns: 0 for off, 1 for on, <0 for error
#
sub ipmiexec($$$$$$$;$$$$) {
    my ($node_id,$type,$cmd,$IP,$key_role,$key_uid,$key,$kgkey,$privlvl,$timeout,$force) = @_;

    if ($debug) {
	print "ipmiexec called with (" . join(',',@_) . ")\n";
    }

    if (!defined($type) || !defined($cmd) || !defined($IP) 
	|| !defined($key_role) || !defined($key_uid) || !defined($key)) {
	warn "Incomplete argument list, skipping node" . 
	    (defined($node_id)?" $node_id":"");

	return -1;
    }

    if ($cmd =~ /^(cycle|reset|on|off|status)$/) {
	$cmd = $1;
    }
    else {
	warn "Bad IPMI power command $cmd";
	return -11;
    }

    my ($iface,$pwdmax,$usekey);
    if ($type eq 'ipmi15') {
	$iface = "lan";
	$pwdmax = 15;
    } elsif ($type eq 'ipmi20') {
	$iface = "lanplus";
	$pwdmax = 20;
    } else {
	warn "Unsupported IPMI type $type!";
	return -7;
    }

    if ($key_role eq 'ipmi-passwd') {
	$usekey = 0;
    } elsif ($key_role eq 'ipmi-kgkey-passwd') {
        $usekey = 1;
    } elsif ($key_role eq 'ipmi-kgkey') {
	if ($type eq 'ipmi15') {
	    warn "Cannot use key_role 'kgkey' for IPMI 1.5!";
	    return -21;
	}
	$usekey = 1;
	$kgkey = $key;
    } else {
	warn "Unsupported IPMI key_role $key_role!";
	return -14;
    }

again:
    my $privlvl_args = ($privlvl) ? " -L $privlvl" : '';
    my $txdelay_args = ($timeout) ? " -N $timeout" : '';
    # XXX backward compat: if no timeout use legacy 8 tries, ow use default
    my $retry_args = ($timeout) ? '' : "-R 8";
    my $ipmicmd = "ipmitool -I $iface -H $IP $txdelay_args $retry_args -U $key_uid $privlvl_args -E -K power $cmd";
    print "*** Executing '$ipmicmd', output:\n"
	if ($debug > 1);

    # Set the password and key environment variables
    $ENV{'IPMI_PASSWORD'} = substr($key, 0, $pwdmax);
    $ENV{'IPMI_KGKEY'} = $kgkey
	if ($usekey);

    my $output = `$ipmicmd 2>&1`;
    my $stat = ($? >> 8);

    # And clear them again
    delete $ENV{'IPMI_PASSWORD'};
    delete $ENV{'IPMI_KGKEY'};

    #
    # XXX check for failured due to power cycle of a node that is turned off
    # and turn it on if desired.
    #
    if ($stat && $cmd eq "cycle" &&
	$output =~ /Command not supported in present state/) {
	if ($force) {
	    print "*** Cycle failed, trying power on instead.\n"
		if ($debug > 1);
	    $cmd = "on";
	    $force = 0;
	    goto again;
	}
	# XXX we should maybe do a POWEROFF state transition here?
	$output = "Node is powered off, use 'power on' instead.\n";
    }

    if ($stat || $debug > 1) {
	print "*** '$ipmicmd' failed (stat=$stat):\n"
	    if ($stat);
	print $output;
    }

    if (!$stat && $cmd eq "status") {
	if ($output =~ /power is (off|on)/i) {
	    return ($1 eq "off") ? 0 : 1;
	}
	print "IPMI unexpected power status:\n";
	print $output;
	return -1;
    }

    return ($stat ? -1 : 0);
}

1;

# vim: set ft=perl et sw=4 ts=8:
# Not sure what the (no)et sw=? ts=? rules should be in this file - they're kind of mixed.
# Seems like a leading tab in some places and then 4 expanded spaces.  Maybe et sw=4 ts=8.
