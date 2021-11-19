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
package TestBed::Wrap::linktest;
use SemiModern::Perl;
use TBConfig;
use Data::Dumper;
use Tools;
use Tools::TBSSH;

=pod

  sleep 10;
  test_cmd 'linktest1', [], "run_linktest.pl -v -L 1 -l 1 -e $pid/$eid";
  sleep 2;
  test_cmd 'linktest2', [], "run_linktest.pl -v -L 2 -l 2 -e $pid/$eid";
  sleep 2;
  test_cmd 'linktest3', [], "run_linktest.pl -v -L 3 -l 3 -e $pid/$eid";
  sleep 2;
  test_cmd 'linktest4', [], "run_linktest.pl -v -L 4 -l 4 -e $pid/$eid";

=cut

=head1 NAME

TestBed::Wrap::linktest

=over 4

=item C<linktest($pid, $eid)>

executes linktest on $pid and $eid by sshing to ops

=back

=cut

sub linktest {
  my ($pid, $eid) = @_;
  my $results = 0;
  my $ssh = Tools::TBSSH::instance($TBConfig::OPS_SERVER);
  sleep 8;
  for my $i (1..4) {
    sleep 2;
    my $cmd = 'PATH=/usr/testbed/bin:$PATH '. "run_linktest.pl -v -L $i -l $i -e $pid/$eid";
    #say $cmd;
    $results && $ssh->cmdsuccess($cmd);
  }
  !$results;
}

1;
