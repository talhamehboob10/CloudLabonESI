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

use IO::Socket;
use POSIX ":sys_wait_h";

use Carp;
use Data::Dumper;

local $^W = 1;

sub parse ($) {
  local ($_) = @_;
  @d = /(\d+)\.\d+ \(icmp:\d+,\d+ tcp:(\d+),\d+ udp:(\d+),\d+ other:\d+,\d+\)/ or confess "?$_";
  return @d;
}

sub fix_times ($\@) {
  my ($base,$l) = @_;
  foreach (@$l) {
    $_->[0] -= $base;
  }
}

sub find_intervals ($@) {
  my @intervals;
  my $w = shift;
  my @interval;
  foreach (@_) {
    if (!@interval && $_->[$w] != 0) {
      @interval = ($_->[0], undef, undef);
    }
    if (@interval) {
      if ($_->[$w] != 0) {
	$interval[1]  = $_->[0];
	$interval[2] += $_->[$w];
      } else {
	push @intervals, [@interval];
	undef @interval;
      }
    }
  }
  return @intervals;
}

sub find_interval (\$\%$$$$$)
{
  my ($res, $intv, $desc, $which, $when, $duration, $traffic) = @_;
  my $v;
  foreach (@{$intv->{$which}}) {
    $v = $_;
    last if (abs($v->[0] - $when) <= 1);
  }
  unless (defined $v) {
    print "*** Could not find traffic corresponding to \"$desc\"\n";
    $$res = 0;
    return;
  }
  my $real_duration = $v->[1] - $v->[0];
  if (abs($real_duration - $duration) > 1) {
    print "*** Traffic from \"$desc\" lasted for $real_duration seconds when\n";
    print "    it was only suppose to last for $duration seconds\n";
    $$res = 0;
  }
  my $real_traffic = $v->[2];
  my $tol = 0.20;
  if (abs($real_traffic - $traffic) > $traffic*$tol) {
    print "*** Traffic from \"$desc\" generated $real_traffic bytes of data\n";
    print "    but was expecting approximately $traffic bytes with a tolerance of ";
    printf "%.0f%%\n", $tol * 100;
    $$res = 0;
  }
}

test 'event', [], sub {

  # connect to emulab pcapper daemon on port 4443
  my $n0s = IO::Socket::INET->new(Proto => 'tcp',
				  PeerAddr => "node0.$eid.$pid",
				  PeerPort => 4443)
      or die "socket-node0: $!\n";
  my $n1s = IO::Socket::INET->new(Proto => 'tcp',
				  PeerAddr => "node1.$eid.$pid",
				  PeerPort => 4443)
      or die "socket-node1: $!\n";

  <$n0s>;
  <$n0s>;

  <$n1s>;
  <$n1s>;

  my $cpid = fork();
  
  if ($cpid == 0) {
    my $cmd = "tevc -w -e $pid/$eid now tl start";
    print "exec $cmd\n";
    exec $cmd;
    die "exec tevc: $!\n";
  }

  my @n0_traffic = ();
  my @n1_traffic = ();

  print $n0s "1000\n";
  print $n1s "1000\n";

  while (waitpid($cpid,WNOHANG) <= 0) {
    push @n0_traffic, [parse(<$n0s>)];
    push @n1_traffic, [parse(<$n1s>)];
  }
  push @n0_traffic, [parse(<$n0s>)];
  push @n1_traffic, [parse(<$n1s>)];

  close $n0s;
  close $n1s;
  
  if ($? >> 8 != 0) {
    die "tevc existed with non-zero status: $?\n";
  }

  my $base = $n0_traffic[0][0];

  fix_times $base, @n0_traffic;  
  fix_times $base, @n1_traffic;

  $intervals{node0_tcp} = [find_intervals 1, @n0_traffic];
  $intervals{node0_udp} = [find_intervals 2, @n0_traffic];
  $intervals{node1_tcp} = [find_intervals 1, @n1_traffic];
  $intervals{node1_udp} = [find_intervals 2, @n1_traffic];

  open F, ">traffic.txt";
  foreach (sort keys %intervals) {
    local @_ = @{$intervals{$_}};
    print F "$_\n";
    foreach (@_) {
      print F "  $_->[0]-$_->[1]: $_->[2]\n";
    }
  }
  close F;

  my $res = 1;

  find_interval($res, %intervals, 
		'$tl at 10.0 "$cbr_udp start"', 
		'node0_udp', 10, 2, 20000);
  find_interval($res, %intervals, 
		'$tl at 15.0 "$cbr_tcp start"',
		'node1_tcp', 15, 2, 100000);
  find_interval($res, %intervals, 
		'$tl at 20.0 "$cbr_udp start"', 
		'node0_udp', 20, 2, 20000);
  find_interval($res, %intervals, 
		'$tl at 22.0 "$cbr_tcp start"',
		'node1_tcp', 20, 2, 100000);
  return $res;
};




