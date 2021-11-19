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
use SemiModern::Perl;
use TestBed::TestSuite;
use BasicNSs;
use Test::More;
use Data::Dumper;

my $linkupdowntest = sub {
  my ($e) = @_; 
  my $eid = $e->eid;
  ok($e->linktest, "$eid linktest"); 

  ok($e->link("link1")->down, "$eid link down");
  sleep(2);

  my $n1ssh = $e->node("node1")->ssh;
  ok($n1ssh->cmdfailure("ping -c 5 10.1.2.3"), "$eid expected ping failure");

  ok($e->link("link1")->up, "$eid link up");
  sleep(2);
  ok($n1ssh->cmdsuccess("ping -c 5 10.1.2.3"), "$eid expected ping success");
};

rege(e('linkupdown'), $BasicNSs::TwoNodeLanWithLink, $linkupdowntest, 5, 'link up and down with ping on link');

my $twonodelan5Mbtest = sub {
  my ($e) = @_; 
  my $eid = $e->eid;
  ok($e->linktest, "$eid linktest"); 
};

rege(e('2nodelan5Mb'), $BasicNSs::TwoNodeLan5Mb, $twonodelan5Mbtest, 1, '2nodelan5Mb linktest');
rege(e('1singlenode'), $BasicNSs::SingleNode, sub { ok(shift->ping_test, "1singlenode ping test"); }, 1, 'single node pingswapkill');
rege(e('2nodelan'), $BasicNSs::TwoNodeLan, sub { ok(shift->ping_test, "2nodelan ping test"); }, 1, 'two node lan pingswapkill');

1;
