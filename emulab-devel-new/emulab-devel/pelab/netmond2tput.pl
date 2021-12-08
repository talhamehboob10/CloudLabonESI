#
# Copyright (c) 2006 University of Utah and the Flux Group.
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

$usage = "Usage: netmond2tput.pl <elab-file> <planet-file> <planet-logfile>

Takes two files in the format generated by netmond, and an magent log
file and creates an xplot throughput graph with both of them
comparable. The vertical green bars are the throughput numbers
generated by the magent. The elab-file is red. The planet-file is
blue. Limitation: This only gives the *aggregate* throughput for the
nodes involved. The aggregate of all streams. This is because there is
no way to correlate individual streams on one elab with those on
PlanetLab with streams of the other without more information.";

$stubPort = 3249;
$usePeriod = 0;
$averageCount = 100;
$averagePeriod = 1.0;

sub offeredLoad
{
    ($fileName, $passName) = @_;

    $startTime = 0.0;
    $lastTime = 0.0;
    $skips = 0;
    $lastX = 0.0;
    $lastY = 0.0;
    $deltaTotal = 0.0;
    $byteTotal = 0;
    $writeCount = 0;
    if ($passName eq "planet")
    {
	$skips = 1;
	$color = "blue";
    }
    else
    {
	$skips = 0;
	$color = "red";
    }

    open(FILE, "<$fileName") or die("\nFailed to open $passName file for reading: $fileName\n\n$usage");

    while ($line = <FILE>)
    {
	chomp($line);
	if ($line =~ /Connected/ and $startTime == 0.0)
	{
	    if ($skips <= 0)
	    {
		$line =~ /([0-9]+\.[0-9]+)$/;
		$startTime = $1;
		$lastTime = $startTime;
	    }
	    else
	    {
		$skips--;
	    }
	}
	if ($line =~ /^[0-9]+\.[0-9]+ >/ and $startTime != 0.0 and ($passName eq "elab" or $line =~ /3249/))
	{
	    ++$writeCount;
	    # This is a simple write.
	    $line =~ /^([0-9]+\.[0-9]+)/;
	    $currentTime = $1;
	    $currentDelta = ($currentTime - $lastTime);
	    $lastTime = $currentTime;
	    $line =~ /\(([0-9]+)\)$/;
	    $currentBytes = $1;
	    while (($deltaTotal+$currentDelta >= $averagePeriod
		    and $usePeriod == 1)
		or ($writeCount >= $averageCount and $usePeriod == 0))
	    {
		if ($usePeriod == 0)
		{
		    $deltaTotal = $deltaTotal + $currentDelta;
		    $byteTotal = $byteTotal + $currentBytes;
		}
		else
		{
#		    print "deltaTotal: $deltaTotal, currentDelta: $currentDelta, averagePeriod: $averagePeriod\n";
		    $remainder = ($deltaTotal+$currentDelta) - $averagePeriod;
		    $proportion = ($averagePeriod - $deltaTotal)/$currentDelta;
		    $deltaTotal = $averagePeriod;
		    $byteTotal = $byteTotal + ($currentBytes * $proportion);
		    $currentDelta = $remainder;
		    $currentBytes = $currentBytes * (1.0 - $proportion);
#		    print "remainder: $remainder, proportion: $proportion, deltaTotal: $deltaTotal, byteTotal: $byteTotal\n";
		}
		$throughput = ($byteTotal*8.0) / ($deltaTotal*1000.0);
		$time = $lastX + $deltaTotal;#$currentTime - $startTime;
		# Draw dot
		print "$color\n";
		print "dot ";
		printf("%0.2f",$time);
		print " $throughput\n";
		if ($lastX != 0.0)
		{
		    print "line ";
		    printf("%0.2f", $time);
		    print " $throughput ";
		    printf("%0.2f", $lastX);
		    print " $lastY\n";
		}
		$lastX = $time;
		$lastY = $throughput;

		if ($usePeriod == 0)
		{
		    $currentDelta = 0.0;
		    $currentBytes = 0;
		}
		$deltaTotal = 0.0;
		$byteTotal = 0;
		$writeCount = 0;
	    }
	    $deltaTotal = $deltaTotal + $currentDelta;
	    $byteTotal = $byteTotal + $currentBytes;
	}
    }
}

sub throughputSend
{
    ($logFileName) = @_;
    open(LOG_FILE, "<$logFileName") or die("\nFailed to open log file for reading: $fileName\n\n$usage");
    $lastBandwidth = 0;
    $logStartTime = 0.0;

    while ($logLine = <LOG_FILE>)
    {
	chomp($logLine);
	$currentBandwidth = 0;
	$logTime = 0.0;
	if ($logStartTime == 0.0 && $logLine =~ /^COMMAND_INPUT *([0-9]+\.[0-9]+)/)
	{
	    $logStartTime = $1;
	}
	if ($logLine =~ /^COMMAND_OUTPUT *([0-9]+\.[0-9]+).*TENTATIVE_THROUGHPUT...([0-9]+)$/)
	{
	    if ($2 > $lastBandwidth)
	    {
		$currentBandwidth = $2;
		$logTime = $1
	    }
	}
	if ($logLine =~ /^COMMAND_OUTPUT *([0-9]+\.[0-9]+).*AUTHORITATIVE_BANDWIDTH...([0-9]+)$/)
	{
	    $currentBandwidth = $2;
	    $logTime = $1;
	}
	if ($currentBandwidth != 0)
	{
	    $lastBandwidth = $currentBandwidth;
	    print "green\n";
	    $adjustedTime = $logTime - $logStartTime;
	    print "line $adjustedTime 0 $adjustedTime $currentBandwidth\n";
	}
    }
}

$argCount = scalar(@ARGV);

if ($argCount != 3)
{
    die("\nWrong number of arguments\n\n$usage");
}
$elabName = $ARGV[0];
$planetName = $ARGV[1];
$logName = $ARGV[2];

print "timeval signed\n";
print "title\n";
print "Throughput (offered load)\n";
print "xlabel\n";
print "Time (s)\n";
print "ylabel\n";
print "Throughput (Kbps)\n";

offeredLoad($elabName, "elab");
offeredLoad($planetName, "planet");
throughputSend($logName);

print "go\n";