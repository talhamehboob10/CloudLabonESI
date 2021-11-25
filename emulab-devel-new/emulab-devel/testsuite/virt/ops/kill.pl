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
if (scalar(@ARGV) != 3)
{
    print STDERR "Usage: kill.pl <proj> <exp> <pairCount>\n";
    exit(1);
}

$proj = $ARGV[0];
$exp = $ARGV[1];
$pairCount = $ARGV[2];

sub killProgram
{
    my $agentName = shift(@_);
    my $string = "/usr/testbed/bin/tevc ";
    my $string = $string."-e $proj/$exp now $agentName stop";
    system($string);
}

sub killAll
{
    my $i = 1;
    killProgram("vhost-0_program");
    for ($i = 1; $i <= $pairCount; ++$i)
    {
	killProgram("client-$i-agent");
	killProgram("server-$i-agent");
    }
}

killAll();
