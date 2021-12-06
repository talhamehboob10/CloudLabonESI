#! /usr/bin/perl -w

#
# Copyright (c) 2011-2013 University of Utah and the Flux Group.
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
# module for controlling power and reset via Linux NetworX's ICEBox
#
# supports new(ip), power(on|off|cyc[le]), status
#

package power_icebox;

use POSIX;
use IO::Pty;

use strict;
$ENV{'PATH'} = '/bin:/usr/bin:/usr/local/bin'; # Required when using system() or backticks `` in combination with the perl -T taint checks

# timeout for telnet operations, library default is 10 seconds
my $TIMEOUT = 10;

sub spawn_subprocess {
    my(@cmd) = @_;
    my($pid, $pty, $tty, $tty_fd);

    $pty = new IO::Pty();
    if (not defined $pty) {
	print STDERR "pty failed: $!\n";
	return undef;
    }

    $pid = fork();
    if (not defined $pid) {
        print STDERR "fork() failed: $!\n";
	return undef;
    } elsif ($pid == 0) {
        # detach from controlling terminal
        POSIX::setsid or die "setsid failed: $!";

        $tty = $pty->slave;
        $pty->make_slave_controlling_terminal();
        $tty_fd = $tty->fileno;
	close $pty;
  
	open STDIN, "<&$tty_fd" or die $!;
	open STDOUT, ">&$tty_fd" or die $!;
	open STDERR, ">&STDOUT" or die $!;
	close $tty;

        exec @cmd or die "exec($cmd[0]) failed: $!\n";
    }

    return $pty;
}

sub _icebox_exec ($$) {
    my ($self, $host, $cmd) = @_;
    my $user = "admin";
    my $password = "icebox";
    my $prompt = '/# /';

    # OK, start ssh child process
    my $pty = spawn_subprocess("ssh",
                  "-o", "RSAAuthentication=no",
                  "-o", "PubkeyAuthentication=no",
                  "-o", "PasswordAuthentication=yes",
                  "-l", $user, $host);
    if (not defined $pty) {
	print STDERR "$host: could not start ssh\n";
	return undef;
    }

    my $ssh = new Net::Telnet (-fhopen => $pty,
                               -prompt => $prompt,
                               -telnetmode => 0,
                               -cmd_remove_mode => 1,
                               -output_record_separator => "\r",
			       -timeout => $TIMEOUT,
			       -errmode => "return");
    if (not defined $ssh) {
	print STDERR "$host: could not create telnet object\n";
	return undef;
    }

    # Log in to the icebox
    if (!$ssh->waitfor(-match => '/password: ?$/i',
		       -errmode => "return")) {
        print STDERR "$host: failed to connect: ", $ssh->lastline;
	return undef;
    }
    $ssh->print($password);
    if (!$ssh->waitfor(-match => $ssh->prompt,
		       -errmode => "return")) {
        print STDERR "$host: login failed: ", $ssh->lastline;
	return undef;
    }

    # Send the command to the icebox and get any output
    my @output = $ssh->cmd($cmd);
    return \@output;
}

sub new($$;$) {

    require Net::Telnet; # Saves us from parsing the ssh output by hand

    # The next two lines are some voodoo taken from perltoot(1)
    my $proto = shift;
    my $class = ref($proto) || $proto;

    my $devicename = shift;
    my $debug = shift;

    if (!defined($debug)) {
        $debug = 0;
    }

    if ($debug) {
        print "power_icebox module initializing... debug level $debug\n";
    }

    my $self = {};

    $self->{DEBUG} = $debug;

    $self->{DEVICENAME} = $devicename;

    bless($self,$class);
    return $self;
}

sub _icebox_power {
    my ($self, $op, @ports) = @_;

    my $errors = 0;
    my $output;

    if    ($op eq "on")  { $op = "power on";    }
    elsif ($op eq "off") { $op = "power off";   }
    
    $output = $self->_icebox_exec($self->{DEVICENAME}, $op . ' ' . join(',', @ports));

    if (not defined $output) {
	    print STDERR $self->{DEVICENAME}, ": could not execute power command \"$op\" for ports @ports\n";
	    $errors++;
    } elsif ($$output[-1] !~ /^\s*OK$/) {
	    print STDERR $self->{DEVICENAME}, ": power command \"$op\" failed with error @$output\n";
	    $errors++;
    }

    return $errors;
}

sub power {
	my ($self, $op, @ports) = @_;
	my $rc;
	
	if ($op =~ /cyc/) {
		$rc = $self->_icebox_power("off", @ports);
		if (!$rc) {
			sleep(3); # XXX Is three seconds enough?
			$rc = $self->_icebox_power("on", @ports);
		}
	} else {
		$rc = $self->_icebox_power($op, @ports);
	}

	return $rc;
}

sub status {
    my $self = shift;
    my $statusp = shift; # pointer to an associative (hashed) array (i.o.w. passed by reference)
    my %status;          # local associative array which we'll pass back through $statusp

    my $errors = 0;
    my $output;

    # Get power status (i.e. whether system is on/off)
    $output = $self->_icebox_exec($self->{DEVICENAME}, "power status all");
    if (not defined $output) {
        $errors++;
        print STDERR $self->{DEVICENAME}, ": could not get power status from device\n";
    }
    else {
        for my $line (@$output) {
            next unless $line =~ /^port\s+(\d+):\s+(.*)$/;
	    $status{"outlet$1"} = ucfirst $2;
	    print("Power status for outlet $1 is: $2\n") if $self->{DEBUG};
	}
    }

    if ($statusp) { %$statusp = %status; } # update passed-by-reference array
    return $errors;
}

1;
