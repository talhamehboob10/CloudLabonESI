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
use TestBed::XMLRPC::Client::Node;
use Data::Dumper;
use Test::More tests => 8;

my $node = TestBed::XMLRPC::Client::Node->new();
ok($node, 'Node new works');
isa_ok($node, 'TestBed::XMLRPC::Client::Node');

ok($node->available, 'nodes available');
ok($node->available('type' => 'pc3000'), 'pc3000 nodes available');
ok($node->getlist('type' => 'pc3000'), 'getlist returns hash');
ok((keys %{$node->typeinfo}) > 20, 'node typeinfo has at least 20 types');
ok($node->get_free('type' => 'pc3000'), 'get_free type => pc3000');
ok($node->get_free_names('type' => 'pc3000'), 'get_free_names type => pc3000');
