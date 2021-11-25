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
# A little perl module for using Jon's arduino relay on a Powder node.
#
# We use this package on Powder control nucs.
#
package power_powduino;

use strict;
use Exporter;
use vars qw(@ISA @EXPORT);
@ISA = ("Exporter");
@EXPORT = qw( powduinoctrl powduinostatus powduinotemp powduinovoltage
              powduinocurrent );

use Socket;
use IO::Socket;
use IO::Handle;
use POSIX qw(strftime);

# We need to know if we are running on a boss node or client.
my $LOCALMODE = (-e "/usr/testbed/etc/emulab.key" ? 0 : 1);

# Number of times to try sending command in the face of "Input error"
my $ntries = 3;

# Set for more output.
my $debug = 0;

# Prompt string
my $PROMPT = 'power> ';

my %CMDS =
  ("cycle"  => "power cycle",
   "on"     => "power on",
   "off"    => "power off");

sub powduinostatus {
    my ($controller, $statusp) = @_;

    my($TIP, $i, $insync);

    #
    # Form the connection to the controller via a "tip" line to the
    # capture process. Once we have that, we can just talk to the
    # controller directly.
    #
    if (!($TIP = tipconnect($controller))) {
	print STDERR "*** Could not form TIP connection to $controller\n";
	return 1;
    }

    #
    # Send the command.  Try again a few times if there is a retryable error.
    #
    my $status;
    for my $try (1..$ntries) {
	$status = syncandsend($controller, $TIP, "status", $statusp);
	last
	    if $status >= 0;
    }
    $TIP->close();
    return $status ? 1 : 0;
}

sub powduinotemp {
    my ($controller, $statusp) = @_;

    my($TIP, $i, $insync);

    #
    # Form the connection to the controller via a "tip" line to the
    # capture process. Once we have that, we can just talk to the
    # controller directly.
    #
    if (!($TIP = tipconnect($controller))) {
	print STDERR "*** Could not form TIP connection to $controller\n";
	return 1;
    }

    #
    # Send the command.  Try again a few times if there is a retryable error.
    #
    my $status;
    for my $try (1..$ntries) {
	$status = syncandsend($controller, $TIP, "temp", $statusp);
	last
	    if $status >= 0;
    }
    $TIP->close();
    return $status ? 1 : 0;
}

sub powduinovoltage {
    my ($controller, $statusp) = @_;

    my($TIP, $i, $insync);

    #
    # Form the connection to the controller via a "tip" line to the
    # capture process. Once we have that, we can just talk to the
    # controller directly.
    #
    if (!($TIP = tipconnect($controller))) {
	print STDERR "*** Could not form TIP connection to $controller\n";
	return 1;
    }

    #
    # Send the command.  Try again a few times if there is a retryable error.
    #
    my $status;
    for my $try (1..$ntries) {
	$status = syncandsend($controller, $TIP, "voltage", $statusp);
	last
	    if $status >= 0;
    }
    $TIP->close();
    return $status ? 1 : 0;
}

sub powduinocurrent {
    my ($controller, $statusp) = @_;

    my($TIP, $i, $insync);

    #
    # Form the connection to the controller via a "tip" line to the
    # capture process. Once we have that, we can just talk to the
    # controller directly.
    #
    if (!($TIP = tipconnect($controller))) {
	print STDERR "*** Could not form TIP connection to $controller\n";
	return 1;
    }

    #
    # Send the command.  Try again a few times if there is a retryable error.
    #
    my $status;
    for my $try (1..$ntries) {
	$status = syncandsend($controller, $TIP, "current", $statusp);
	last
	    if $status >= 0;
    }
    # Oh ick, the way syncandsend is implmenented, the current looks
    # like the temp.
    if (exists($statusp->{"tempC"})) {
	$statusp->{"current"} = $statusp->{"tempC"};
	delete($statusp->{"tempC"});
    }
    $TIP->close();
    return $status ? 1 : 0;
}

# Main routine.
# usage: powduinoctrl(cmd, controller, outlet)
# cmd = { "cycle" | "on" | "off" }
# controller = <node_id>
# outlet = int, 0 <= outlet < N
#
# Returns 0 on success. Non-zero on failure.
# 
sub powduinoctrl {
    my($cmd, $controller, @outlets) = @_;
    my $TIP;

    #
    # Check parameters
    #
    if (!defined($CMDS{$cmd})) {
	print STDERR "*** Undefined command: '$cmd'\n";
	return 1;
    }
    if (grep {$_ < 0 || $_ > 3} @outlets) {
	print STDERR "*** Invalid outlet '@outlets': Must be 0-3\n";
	return 1;
    }

    if ($debug) {
	print STDERR "outlets: ", join(" ",map("($_)",@outlets)), "\n";
    }

    #
    # Run the rest in a child process, protected by an alarm to ensure that
    # we are not hung up forever if the controller is in some funky state.
    #
    my $syspid = fork();

    if ($syspid) {
	local $SIG{ALRM} = sub { kill("TERM", $syspid); };
	#
	# Give it 30 seconds for initial connect plus time per outlet.
	# Probably too long.
	#
	alarm 30 + (10 * scalar(@outlets));
	waitpid($syspid, 0);
	alarm 0;
	my $exitstatus = $?;

	if ($exitstatus == 15) {
	    print STDERR "*** power: $controller is wedged.\n";
	}
	return($exitstatus);
    }
    if (!$LOCALMODE) {
	libdb::TBdbfork();
    }

    #
    # Form the connection to the controller via a "tip" line to the
    # capture process. Once we have that, we can just talk to the
    # controller directly.
    #
    if (! ($TIP = tipconnect($controller))) {
	print STDERR "*** Could not form TIP connection to $controller\n";
	exit(1);
    }

    foreach my $outlet (@outlets) {
	my $command = "$CMDS{$cmd} $outlet";
	my $status;
	for my $try (1..$ntries) {
	    $status = syncandsend($controller, $TIP, $command);
	    last
		if $status >= 0;
	}
	if ($status) {
	    $TIP->close();
	    exit(1);
	}
    }
    $TIP->close();
    exit(0);
}

#
# Sync up with the power controller, and set it a command. $controller is the
# controller name, for error message purposes, $TIP is the connection to
# the controller opened with tipconnect, and $command is the whole command
# (ie. 'reboot 20,40') to send.
#
# Returns 0 if successful, -1 if the caller should try again,
# 1 on an unexpected error.
#
sub syncandsend($$$;$) {
    my ($controller,$TIP,$cmd,$statusp) = @_;

    #
    # Send a newline to get the command prompt, and then wait
    # for it to print out the command prompt. This loop is set for a small
    # number since if it cannot get the prompt quickly, then something has
    # gone wrong.
    #
    my $insync = 0;

    for (my $i = 0; $i < 20; $i++) {
	my $line;

	if ($TIP->syswrite("\r") == 0) {
	    print STDERR
		"*** Power control sync write failed ($controller)\n";
	    return 1;
	}

	while (1) {
	    $line = rpc_readline($TIP);
	    if (!defined($line)) {
		print STDERR
		    "*** Power control sync read failed ($controller)\n";
		return 1;
	    }
	    if ($debug) {
		print STDERR "Read: $line";
	    }
	    if ($line =~ /$PROMPT/) {
		if ($debug) {
		    print STDERR "Matched prompt '$PROMPT'!\n";
		}
		$insync = 1;
		last;
	    }
	}
	last
	    if ($insync);
    }
    if (! $insync) {
	print STDERR "*** Could not sync with power controller! ".
	    "($controller)\n";
	return 1;
    }

    if ($debug) {
	print STDERR "Sending '$cmd' to $controller\n";
    }

    # Okay, got a prompt. Send it the string:
    if ($TIP->syswrite("$cmd\r") == 0) {
    	print STDERR "*** Power control write failed ($controller)\n";
    	return 1;
    }

    #
    # Read and parse all the output until the next prompt to ensure that
    # there was no read error.  We also collect status here if desired.
    #
    my %status = ();
    my $gotcmd = 0;
    my $gotstatus = 0;
    print STDERR "Reading output following command\n"
	if ($debug);
    while (my $line = rpc_readline($TIP)) {
	if (!defined($line)) {
	    return -1;
	}
	print STDERR "Read: $line"
	    if ($debug);
	# skip echoed prompt+command
	if ($line =~ /$cmd/) {
	    $gotcmd = 1;
	    print STDERR "GotCmd\n" if ($debug);
	    next;
	}
	# didn't recognize our command for some reason, return failure
	if ($line =~ /Invalid/) {
	    print STDERR "Bad result\n" if ($debug);
	    return -1;
	}
	#
	# Got the following prompt, all done.
	#
	if (($gotcmd || $gotstatus) && $line =~ /$PROMPT/) {
	    last;
	}
	if ($statusp) {
	    if ($line =~ /^Pin\s+(\d+)\s+(on|off)/) {
		$status{"pin$1"} = $2;
		$gotstatus = 1;
		print STDERR "status 'pin$1' = ", $status{"pin$1"}, "\n"
		    if ($debug);
	    } elsif ($line =~ /^Pin\s+(\d+):\s+(\d+)/) {
		$status{"pin$1"} = $2;
		$gotstatus = 1;
		print STDERR "status 'pin$1' = ", $status{"pin$1"}, "\n"
		    if ($debug);
	    } elsif ($line =~ /^(\-?\d+(\.\d+)?)/) {
		$status{"tempC"} = $1;
		$gotstatus = 1;
		print STDERR "status 'temp' = ", $status{"tempC"}, "\n"
		    if ($debug);
	    }
	}
    }

    if ($statusp) {
	%$statusp = %status;
    }
    return 0;
}

#
# Connect up to the capture process. This should probably be in a library
# someplace.
#
sub tipconnect($) {
    my($controller) = $_[0];
    my($server, $portnum, $keylen, $keydata, $capreturn, $disabled);
    my($inetaddr, $paddr, $proto);
    my(%powerid_row);
    local *TIP;

    if (!$LOCALMODE) {
	my $query_result =
	    libdb::DBQueryWarn("select * from tiplines ".
			       "where node_id='$controller'");

	if ($query_result->numrows < 1) {
	    print STDERR "*** No such tipline: $controller\n";
	    return 0;
	}
	%powerid_row = $query_result->fetchhash();

	$server  = $powerid_row{'server'};
	$portnum = $powerid_row{'portnum'};
	$keylen  = $powerid_row{'keylen'};
	$keydata = $powerid_row{'keydata'};
	$disabled= $powerid_row{'disabled'};

	if ($disabled) {
	    print STDERR "*** $controller tipline is disabled\n";
	    return 0;
	}
    }
    else {
	#
	# The stuff we need is in /var/log/tiplogs/$controller.acl
	#
	my $acl = "/var/log/tiplogs/${controller}.acl";
	if (! -e $acl) {
	    print STDERR "*** $acl does not exist\n";
	    return 0;
	}
	if (open(ACL, $acl)) {
	    while (<ACL>) {
		if ($_ =~ /^([^:]+):\s+(.*)$/) {
		    if ($1 eq "host") {
			$server = $2;
		    }
		    elsif ($1 eq "port") {
			$portnum = $2;
		    }
		    elsif ($1 eq "keylen") {
			$keylen = $2;
		    }
		    elsif ($1 eq "key") {
			$keydata = $2;
		    }
		}
	    }
	    close(ACL);
	    if (!($server && $portnum && $keylen && $keydata)) {
		print STDERR "*** $acl is missing stuff\n";
		return 0;
	    }
	}
	else {
	    print STDERR "*** $acl could not be opened: $!\n";
	    return 0;
	}
    }

    if ($debug) {
	print STDERR "tipconnect: $server $portnum $keylen $keydata\n";
    }

    #
    # We have to send over the key. This is a little hokey, since we have
    # to make it look like the C struct.
    #
    my $secretkey = pack("iZ256", $keylen, $keydata);
    my $capret    = pack("i", 0);

    #
    # This stuff from the PERLIPC manpage.
    # 
    if (! ($inetaddr = inet_aton($server))) {
	print STDERR "*** Cannot map $server to IP address\n";
	return 0;
    }
    $paddr    = sockaddr_in($portnum, $inetaddr);
    $proto    = getprotobyname('tcp');

    for (my $i = 0; $i < 20; $i++) {
	my $socket = IO::Socket->new("Timeout" => 5);

	if (!$socket->socket(PF_INET, SOCK_STREAM, $proto)) {
	    print STDERR "*** Cannot create socket.\n";
	    return 0;
	}
	if (!$socket->connect($paddr)) {
	    print STDERR
		"*** Cannot connect to $controller on $server($portnum)\n";
	    return 0;
	}

	#
	# While its a fatal error if the connect fails, the write and the
	# read that follows might fail because the tip is currently is
	# active. The handshake writes back a value and then immediately
	# closes the socket, which could manifest itself as a closed
	# connection on this end, even before we get a change to do these.
	# operations. In that case, just go around the loop again. We hope
	# to succeed at some point. 
	# 
	if (! $socket->syswrite($secretkey)) {
	    print STDERR
		"*** Cannot write to $controller on $server($portnum)\n";
	    goto again;
	}
	if (! $socket->sysread($capret, length($capret))) {
	    print STDERR
		"*** Cannot read from $controller on $server($portnum)\n";
	    goto again;
	}

	my $foo = unpack("i", $capret);
	if ($debug) {
	    print STDERR "Capture returned $foo\n";
	}
	if ($foo == 0) {
	    return($socket);
	}
	
      again:
	$socket->close();

	if ($i && (($i % 5) == 0)) {
	    printf STDERR
		"*** WARNING: $controller on $server($portnum) is busy\n".
		"    Waiting a bit before trying again. Pass $i.\n";
	}
	sleep(5);
    }
    
    print STDERR
	"*** $controller on $server($portnum) was busy for too long\n";
    return 0;
}

sub rpc_readline($)
{
    my ($TIP) = @_;
    my $line;

    my $cc = 0;
    while (1) {
	my $rval = $TIP->sysread($line, 1, $cc);
	if (!defined($rval) || $rval == 0) {
	    return undef;
	}
	print STDERR "got: =$line=\n" if ($debug > 1);
	$cc++;
	last if ($line =~ /\n/ || $line =~ /$PROMPT/ || $cc > 1023);
    }
    return $line;
}

1;
