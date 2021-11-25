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

use TestBed::XMLRPC::Client::Emulab;
use Test::More tests => 3;
use Time::Local;
use Data::Dumper;
use Tools;
use RPC::XML qw(time2iso8601);


my $emuclient = TestBed::XMLRPC::Client::Emulab->new();
ok($emuclient, 'Emulab new works');
isa_ok($emuclient, 'TestBed::XMLRPC::Client::Emulab');

my $time = timegm(0,0,0,1,0,2008);
my $utctime =  time2iso8601($time); # chop off the Z
my $resp = $emuclient->news('starting' => chop($utctime)); #? chop off the trailing Z
ok($resp, 'Valid Emulab::new response');
