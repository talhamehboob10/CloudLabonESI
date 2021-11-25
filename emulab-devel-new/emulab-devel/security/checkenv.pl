#!/usr/bin/perl

#
# Copyright (c) 2012 University of Utah and the Flux Group.
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
# Check the callers environment including IDs.
# A simple test script for the runsuid suid wrapper.
#

use English;

my %OENV = %ENV;

# un-taint path ala emulab scripts
$ENV{'PATH'} = '/bin:/usr/bin:/sbin:/usr/sbin:/usr/local/bin';
delete @ENV{'IFS', 'CDPATH', 'ENV', 'BASH_ENV'};

my $subUID = `/usr/bin/id -ru`; chomp($subUID);
my $subEUID = `/usr/bin/id -u`; chomp($subEUID);
my $subGID = `/usr/bin/id -rg`; chomp($subGID);
my $subEGID = `/usr/bin/id -g`; chomp($subEGID);

print "ARGs:\n";
foreach my $arg (@ARGV) {
    print "  '$arg'\n";
}
print "IDs:\n";
print "  UID = $UID\n";
print "  EUID = $EUID\n";
print "  GID = $GID\n";
print "  EGID = $EGID\n";
print "  subshell-UID = $UID\n";
print "  subshell-EUID = $EUID\n";
print "  subshell-GID = $GID\n";
print "  subshell-EGID = $EGID\n";

my @envstrs = `/usr/bin/env`;
my %subENV = ();
foreach (@envstrs) {
    if (/^([^=]+)=(.*)$/) {
	$subENV{$1} = $2;
    }
}

print "Environment:\n";
foreach my $var (sort keys %OENV) {
    print "  $var=$OENV{$var}\n";
}

print "Subshell environment:\n";
foreach my $var (sort keys %subENV) {
    print "  $var=$ENV{$var}\n";
}

exit(0);
