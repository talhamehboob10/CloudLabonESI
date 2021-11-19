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
use Test::More tests => 7;
use Test::Exception;
use Data::Dumper;
use BasicNSs;

my $e = e('ensureactive');

ok(!$e->startexp_ns_wait($BasicNSs::TwoNodeLan), 'first start');
throws_ok {$e->startexp_ns_wait($BasicNSs::TwoNodeLan)} 'RPC::XML::struct', 'failed second start';
ok(!$e->ensure_active_ns($BasicNSs::TwoNodeLan), 'ensure active_start');
ok(!$e->end_wait, 'kill_wait succeded');

ok(!$e->ensure_active_ns($BasicNSs::TwoNodeLan), 'ensure active_start');
throws_ok {$e->startexp_ns_wait($BasicNSs::TwoNodeLan)} 'RPC::XML::struct', 'failed second start';
ok(!$e->end_wait, 'kill_wait succeded');
