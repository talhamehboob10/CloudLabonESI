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

# Usage: command.pl <command> <args>

# Begin executing command
$commandPid = fork();
if ($commandPid == 0)
{
  # Command Child
  exec(@ARGV);
}
else
{
  # Parent
  $readPid = fork();
  if ($readPid == 0)
  {
    # Read Child
    $readResult = undef;
    $readBuffer = 0;
    while (! defined($readResult) || $readResult != 0)
    {
      $readResult = sysread(STDIN, $readBuffer, 1);
    }
  }
  else
  {
    # Parent
    $deadPid = wait();
    if ($deadPid != $commandPid)
    {
	kill('KILL', $commandPid);
    }
    if ($deadPid != $readPid)
    {
	kill('KILL', $readPid);
    }
  }
}

