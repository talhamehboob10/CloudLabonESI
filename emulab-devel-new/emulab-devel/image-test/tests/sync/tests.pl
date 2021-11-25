#
# Copyright (c) 2005-2006 University of Utah and the Flux Group.
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

sub compare_file($@) {
  my $n = shift; 
  my $f = new IO::File "/proj/$pid/exp/$eid/tmp/node${n}res" or
      die "*** Unable to open result file for node$n.\n";
  while (<$f>) {
    chop;
    my $expected = shift;
    die "*** Results file for node$n did not match expected output\n"
	unless $_ eq $expected;
  }
  die "*** Results file for node$n did not match expected output\n"
      if <$f>;
  return 1;
}

print "Sleeping 45 seconds...\n";
sleep 45;

test 'sync1', [], sub {
  compare_file 0, 0,1,2;
  compare_file 1, 0,1,2;
  compare_file 2, 0,1,2;
};

print "Sleeping 30 seconds...\n";
sleep 30;

test 'sync2', [], sub {
  compare_file 3, 3,4;
  compare_file 4, 3,4;
};


