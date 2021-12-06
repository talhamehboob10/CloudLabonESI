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
package VNodeTest;
use SemiModern::Perl;
use TestBed::TestSuite;
use Test::More;

my $nsfile = <<'END';
set ns [new Simulator]
source tb_compat.tcl

set node0 [$ns node]
tb-set-node-os $node0 @OS@
tb-set-hardware $node @HARDWARE@

set node1 [$ns node]
tb-set-node-os $node1 @OS@
tb-set-hardware $node @HARDWARE@

set node2 [$ns node]
tb-set-node-os $node2 @OS@
tb-set-hardware $node @HARDWARE@

#@LINKTYPE@
set lan0 [$ns make-lan "$node0 $node1 $node2 " 100Mb 0ms]

$ns rtproto Static
$ns run
END

sub VNodeTest {
  my ($params) = @_;
  my $options = defaults($params, 'OS' => 'RedHat9', 'HARDWARE' => 'pc3000', 'LINKTYPE' => 'REALLYFAST');


  my $ns = concretize($nsfile, %$options);
  say $ns;
  ok(1);
}

sub VNodeTest2 {
  my ($config) = @_;

  my @cases = CartProd($config);

  for (@cases) {
    my $ns = concretize($nsfile, %$_);
    say $ns;
    ok(1);
  }
}

VNodeTest unless caller;
1;
