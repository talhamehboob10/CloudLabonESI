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
package TooManyLans;
use SemiModern::Perl;
use TestBed::TestSuite;
use BasicNSs;
use Test::More;
use TestBed::ParallelRunner;

my $test_body = sub {
  my $e = shift;
  my $eid = $e->eid;
  ok($e->ping_test, "$eid Ping Test");
};

sub handleResult {
  my ($executor, $scheduler, $result) = @_;
  if ($result->error) {
    my $newns = $BasicNSs::TooManyLans;
    $newns =~ s/^set lan5.*$//m;
    say "In TooManyLans::handleResult";
    $executor->e->modify_ns_wait($newns);
    say "Done with TooManyLans->modify_ns_wait";
  }
}

rege(e('toomanylans'), $BasicNSs::TooManyLans, $test_body, 1, "too many lans", retry => 1, pre_result_handler => \&handleResult);
1;
