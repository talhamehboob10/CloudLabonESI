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

if (scalar(@ARGV) != 6)
{
    print STDERR "Usage: parallel-run.pl <run-path> <result-path> <proj>\n"
	."    <exp> <pairCount> <unlimited | limited>\n";
    exit(1);
}

my $runPath = shift(@ARGV);
my $resultPrefix = shift(@ARGV);
my $proj = shift(@ARGV);
my $exp = shift(@ARGV);
my $pairCount = shift(@ARGV);
my $unlimited = shift(@ARGV);

system("mkdir -p $resultPrefix/log");

my @bwList = (500, 1000, 2000, 5000, 10000, 20000, 50000, 100000, 200000);
#my @bwList = (500, 1000);
my $bwString = join(" ", @bwList);
if ($unlimited eq "unlimited")
{
    $bwString = "unlimited";
}

#my $i = 0;
#for ($i = 0; $i < scalar(@pairList); ++$i)
#{
#    my $pairCount = $pairList[$i];
    my $command = "perl bw-run.pl $runPath $resultPrefix $proj $exp "
	. "$pairCount $bwString | tee $resultPrefix/log/$pairCount.log";
    system($command);
#}
