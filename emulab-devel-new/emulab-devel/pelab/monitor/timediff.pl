#! /usr/bin/perl -w
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

use Getopt::Std;

our ($opt_d, $opt_n);
getopts('dn:');
if ($#ARGV != 0) {
 print "usage: timediff.pl [-d] [-n <sample number>] <remote-host>\n";
 exit;
}
$host = $ARGV[0];
$ntptrace = "/proj/tbres/bin/ntptrace";
$cmd = "$ntptrace -nv $host";
$sampnum = 20;
if ($opt_n) {
  if ($opt_n !~ /^\d+$/) {
    print "Error: -n option must be a positive integer!\n";
    exit -1;
  } 
  if ($opt_n < 20) {
    print "Error: -n option must be larger than 20 to enable the min-outlier-filter to work!\n";
    exit -1;
  }
  $sampnum = $opt_n;
}
for ($i=0; $i<$sampnum; $i++) {
  open(PH, $cmd . "|") || die "failed to start command $cmd: $!";
  $lineno = 1;
  while (<PH>) {
    #print if ($opt_d);
    if ($lineno == 3) {
      $delay = $1 if (/\sdelay\s(-?\d+\.?\d*),/);
      $offset = $1 if (/\soffset\s(-?\d+\.?\d*)$/);
      last if (!$opt_d);
    }
    $lineno++;
  }
  close(PH) || die "$cmd failed";
  if (!defined($delay) || !defined($offset)) {
    print "Error: delay or offset is not found in the ntptrace output!\n";
    exit -1;
  }
  if ($opt_d) {
    printf("delay: %f, offset: %f \n", $delay, $offset);
    #printf("======================================================================\n");
  }
  push @delays, $delay; 
  push @offsets, $offset; 
}
@sorted_delays = sort({$a <=> $b} @delays);
print "sorted_delays: ", @sorted_delays, "\n" if ($opt_d);

#choose the offsets corresponding to the shortest 11 delays
for ($i=0; $i<$sampnum; $i++) {
  $delay = shift(@delays);
  $offset = shift(@offsets);
  if ($delay <= $sorted_delays[10]) {
    push @chosen_offsets, $offset;
  }
  last if ($#chosen_offsets == 10);
}
@sorted_chosen_offsets = sort({$a <=> $b} @chosen_offsets);
print "sorted_chosen_offsets: ", @sorted_chosen_offsets, "\n" if ($opt_d); 
printf("The median offset of the shortest 11 delays is %f second\n", $sorted_chosen_offsets[5]);


