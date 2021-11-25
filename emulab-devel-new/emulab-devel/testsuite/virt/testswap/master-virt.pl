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

if (scalar(@ARGV) < 7)
{
    print STDERR "Usage: master-virt.pl <proj> <exp> <\"type\" | \"name\">\n"
	        ."    <typeName | nodeName> <runPath> <resultPath>\n"
		."    <pairCount [...]>\n";
}

$proj = shift(@ARGV);
$exp = shift(@ARGV);
$select = shift(@ARGV);
$name = "";
$type = "";
if ($select eq "type")
{
    $type = shift(@ARGV);
}
else
{
    $name = shift(@ARGV);
}
$runPath = shift(@ARGV);
$resultPath = shift(@ARGV);
@pairList = @ARGV;
$pairString = join(" ", @pairList);

%replacement = ("PROJ" => $proj,
		"EXP" => $exp,
		"SELECT" => $select,
		"NAME" => $name,
		"TYPE" => $type,
		"RUN_PATH" => $runPath,
		"RESULT_PATH" => $resultPath,
		"PAIRS" => $pairString);

open SCRIPT_IN, "<run-virt.t";
open SCRIPT_OUT, ">final-run-virt.t";
while ($line = <SCRIPT_IN>)
{
    while (my ($key, $value) = each %replacement)
    {
	$line =~ s/\@$key\@/$value/g;
    }
    print SCRIPT_OUT $line;
}

close SCRIPT_IN;
close SCRIPT_OUT;

print("Running tests $pairString with experiment $proj/$exp\n");
system("./tbts final-run-virt.t");

