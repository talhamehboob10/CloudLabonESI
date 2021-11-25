#!/usr/bin/perl
#
# Copyright (c) 2009 University of Utah and the Flux Group.
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

use POSIX;
#use POSIX ":sys_wait_h";

my $timeout = shift(@ARGV);

sub runProgram
{
    my $command = shift(@_);
    my $group = getpgrp();
    my $parentPid = POSIX::getpid();
    my $pid = fork();
    my $result = 0;
    if ($pid == 0)
    {
	setpgid(0, $parentPid);
	# Child
	exec($command);
    }
    else
    {
	setpgid($pid, $parentPid);
	# Parent
	waitpid($pid, 0);
	$result = ($? >> 8);
    }
    return $result;
}

sub runSync
{
    my $tries = 5;
    
    my $command = "/usr/testbed/bin/emulab-sync ".join(" ", @_);

    my $status = runProgram($command);
    while ($status != 0 && $status != 240 && $tries >= 0)
    {
	sleep(1);
	print STDERR "FAILED: $command\n";
	print STDERR "Retrying ($tries tries left) Status was $status\n";
	--$tries;
	$status = runProgram($command);
    }
    print STDERR "Final Sync Status: $status\n";
    return $status;
}

sub runTimeout
{
    my $timeout = shift(@_);
    my $result = 0;
    my $pid = fork();
    if ($pid == 0)
    {
	# Child
        POSIX::setpgid(0, 0);
	my $status = runSync(@_);
	exit($status);
    }
    else
    {
	# Parent
        POSIX::setpgid($pid, $pid);
	my $resultPid = 0;
	while ($timeout > 0 && $resultPid != -1 && $resultPid != $pid)
	{
	    sleep(1);
	    --$timeout;
	    $resultPid = waitpid($pid, &WNOHANG);
	}
	if ($timeout <= 0)
	{
	    print STDERR "Timed out while waiting for barrier "
		. join(" ", @_) . "\n";
	    kill(-9, $pid);
	    $result = 1;
	}
    }
    return $result;
}

exit(runTimeout($timeout, @ARGV));

