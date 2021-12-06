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
use TestBed::ForkFramework;
use TestBed::ParallelRunner::Executor;
use RPC::XML;
use Data::Dumper;
use Test::Exception;
use Test::More tests => 4;

my $date_id_sub = sub { my $d = `date`; chomp($d); $_[0] . " $d "  . $$; };

my $results = TestBed::ForkFramework::ForEach::max_work(2, $date_id_sub, ['K1', 'K2', 'K3', 'K4'] );
ok($results->has_errors == 0 && @{ $results->successes } == 4, 'ForkFramework::ForEach::max_work');
#say Dumper($results);

$results = TestBed::ForkFramework::WeightedScheduler::work(4, $date_id_sub, [['K1', 1], ['K2', 1], ['K3', 2], ['K4', 3] ] );
ok($results->has_errors == 0 && @{ $results->successes } == 4, 'ForkFramework::WeightedScheduler::work');
#say Dumper($results);

$results = TestBed::ForkFramework::WeightedScheduler::work(1, 
  sub { die TestBed::ParallelRunner::Executor::SwapinError->new( 
    original => RPC::XML::struct->new( { value => { cause => 'temp' } })); },
  [[ TestBed::ParallelRunner::Executor->buildt(test_count => 1, retry => 1), 1]]
);

ok($results->has_errors == 1 && @{ $results->errors } == 1, 'ForkFramework::WeightedScheduler::work, retry');
#say Dumper($results);

my $launchtime = time;
$results = TestBed::ForkFramework::WeightedScheduler::work(4, 
  sub { 
    die TestBed::ParallelRunner::Executor::SwapinError->new( 
    original => RPC::XML::struct->new( { value => { cause => 'temp' } })) if (time - $launchtime < 6); 1;},
  [[ TestBed::ParallelRunner::Executor->buildt(test_count => 1, backoff => "2:10:0"), 1]]
);

ok($results->has_errors == 0 && @{ $results->successes } == 1, 'ForkFramework::WeightedScheduler::work, backoff');
#say Dumper($results);
