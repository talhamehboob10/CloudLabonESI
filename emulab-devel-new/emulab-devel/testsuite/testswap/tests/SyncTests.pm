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
package SyncTests;
use SemiModern::Perl;
use TestBed::TestSuite;
use Test::More;

my $Sync= << 'END';
set ns [new Simulator]
source tb_compat.tcl

set node0 [$ns node]
set node1 [$ns node]
set node2 [$ns node]

tb-set-node-os $node0 @OS@
tb-set-node-os $node1 @OS@
tb-set-node-os $node2 @OS@

tb-set-sync-server $node0

$ns run
END

my $OS ="RHL90-STD";

sub sync_test {
  my $e = shift;
  my $eid = $e->eid;
  my $ct = 500;
  ok( $e->node('node0')->ssh->cmdsuccess("/usr/testbed/bin/emulab-sync -a -i $ct"),  "$eid setup $ct node barrier" );
  ok( $e->node('node1')->ssh->cmdsuccess("\'for x in `seq 1 $ct`; do :(){ /usr/testbed/bin/emulab-sync > /dev/null 2> /dev/null < /dev/null &};: ; done\'"), "$eid prun sh" );
}

rege(e('sync'), concretize($Sync, OS => $OS), \&sync_test, 2, 'ImageTest-sync test');

1;
