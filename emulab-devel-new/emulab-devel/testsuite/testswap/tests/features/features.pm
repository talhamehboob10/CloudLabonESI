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
use Test::More;
use BasicNSs;

my $test = sub {
  my $e = shift;
  ok( $e->ping_test, 'ping test');
  ok( $e->splat("JUNK", "junk.txt"), '$e->splat("JUNK", "junk.txt")');
  ok( $e->loghole_sync_allnodes, '$e->loghole_sync_allnodes');
#  ok( $e->parallel_tevc( sub {my $n = $_[0]; return "now $n"; }, [$e->hostnames]), '$e->parallel_tevc');
  ok($e->cartesian_ping, 'cartesian_ping');
  ok($e->cartesian_connectivity, 'cartesian_connectivity');
};

rege(e('features'), $BasicNSs::TwoNodeLan, $test, 5, 'tbts features');

