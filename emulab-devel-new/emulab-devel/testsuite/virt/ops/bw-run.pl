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

if (scalar(@ARGV) < 6)
{
    print STDERR "Usage: bw-run.pl <run-path> <result-path> <proj> <exp> <pair-count> <bandwidth [...]>\n";
    print STDERR "The special string 'unlimited' removes bandwidth constraints\n";
    exit(1);
}

$runPrefix = shift(@ARGV);
$resultPrefix = shift(@ARGV);
$proj = shift(@ARGV);
$exp = shift(@ARGV);
$numPairs = shift(@ARGV);
@bwList = @ARGV;

system("mkdir -p $resultPrefix/output");

sub runtest
{
    my $bw = shift(@_);
    my $delay = shift(@_);
    if ($bw ne "unlimited")
    {
	my $command = "perl $runPrefix/network.pl $proj $exp " . $numPairs . " "
	    . $bw . " " . $delay;
	print $command."\n";
	system($command);
    }
    $command = "perl $runPrefix/run.pl $proj $exp $resultPrefix/output/$numPairs-$bw-$delay $runPrefix $numPairs";
    print $command."\n";
    system($command);
}

my @delayList = (0);

my $j = 0;
my $k = 0;
for ($j = 0; $j < scalar(@bwList); ++$j)
{
    for ($k = 0; $k < scalar(@delayList); ++$k)
    {
	print "\n\n\n======BANDWIDTH: " . $bwList[$j] . ", DELAY: "
	    . $delayList[$k]."\n";
	runtest($bwList[$j], $delayList[$k]);
    }
}
