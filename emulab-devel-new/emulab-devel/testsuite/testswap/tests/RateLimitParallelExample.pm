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
package RateLimitParallelExample;
use TestBed::TestSuite;
use BasicNSs;
use Test::More;

my $test_body = sub {
  my $e = shift;
  my $eid = $e->eid;
  sleep(5);
  ok($e->ping_test, "$eid Ping Test");
  sleep(5);
};

rege(e("ksks$_"), $BasicNSs::SingleNode, $test_body, 1, "k$_ desc" ) for (1..5);

1;
