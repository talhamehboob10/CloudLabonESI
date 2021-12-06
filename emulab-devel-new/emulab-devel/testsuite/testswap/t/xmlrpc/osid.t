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

use TestBed::XMLRPC::Client::OSID;
use Test::More tests => 7;
use Data::Dumper;
use Tools;

sub okcontains {
  my ($hash, @keys) = @_;
  ok(exists $hash->{$_}, "OSID list has $_") for (@keys);
}

my $osid = TestBed::XMLRPC::Client::OSID->new();
ok($osid, 'osid new works');
isa_ok($osid, 'TestBed::XMLRPC::Client::OSID');

my $resp = $osid->getlist;
ok($resp, 'getlist response');
okcontains($resp, 'RHL-STD', 'RHL90-STD', 'FBSD63-STD');

$resp = $osid->info('RHL-STD');
ok($osid, 'info response');
