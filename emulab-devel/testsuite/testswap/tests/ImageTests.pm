package ImageTests;
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

my $ThreeNodeLan = <<'END';
set ns [new Simulator]
source tb_compat.tcl

set node0 [$ns node]
tb-set-node-os $node0 @OS@

set node1 [$ns node]
tb-set-node-os $node1 @OS@

set node2 [$ns node]
tb-set-node-os $node2 @OS@

set lan0 [$ns make-lan "$node0 $node1 $node2 " 100Mb 0ms]

$ns rtproto Static
$ns run
END

my $TwoNodeLink = <<'END';
set ns [new Simulator]
source tb_compat.tcl

set node0 [$ns node]
tb-set-node-os $node0 @OS@

set node1 [$ns node]
tb-set-node-os $node1 @OS@

set link0 [$ns duplex-link $node0 $node1 100Mb 0ms DropTail]

$ns rtproto Static
$ns run
END

my $LinkDelay = <<'END';
set ns [new Simulator]
source tb_compat.tcl

set node0 [$ns node]
tb-set-node-os $node0 @OS@
set node1 [$ns node]
tb-set-node-os $node1 @OS@
set node2 [$ns node]
tb-set-node-os $node2 @OS@

set link0 [$ns duplex-link $node0 $node1 55Mb 10ms DropTail]
set link1 [$ns duplex-link $node0 $node1 100Mb 0ms DropTail]
tb-set-link-loss $link1 0.01

tb-use-endnodeshaping   1

$ns rtproto Static
$ns run
END

my $LinkTestNSE = <<'END';
set ns [new Simulator]
source tb_compat.tcl

set client1 [$ns node]
tb-set-node-os $client1 @OS@

set router1 [$ns node]
tb-set-node-os $router1 @OS@

set server1 [$ns node]
tb-set-node-os $server1 @OS@

set link0 [$ns duplex-link $client1 $router1 1Mbps 25ms DropTail]
set queue0 [[$ns link $client1 $router1] queue]
$queue0 set limit_ 20

set link1 [$ns duplex-link $router1 $server1 1Mbps 25ms DropTail]
set queue1 [[$ns link $router1 $server1] queue]
$queue1 set limit_ 20

set tcp_src [new Agent/TCP/FullTcp]
$ns attach-agent $client1 $tcp_src

set tcp_sink [new Agent/TCP/FullTcp]
$tcp_sink listen
$ns attach-agent $server1 $tcp_sink

$ns connect $tcp_src $tcp_sink

set ftp [new Application/FTP]
$ftp attach-agent $tcp_src

$ns run
END

my $LinkTestHilat = <<'END';
set ns [new Simulator]
source tb_compat.tcl

set node0 [$ns node]
tb-set-node-os $node0 @OS@
set node00 [$ns node]
tb-set-node-os $node00 @OS@
set node000 [$ns node]
tb-set-node-os $node000 @OS@
set node001 [$ns node]
tb-set-node-os $node001 @OS@
set node0010 [$ns node]
tb-set-node-os $node0010 @OS@
set node00100 [$ns node]
tb-set-node-os $node00100 @OS@
set node0000 [$ns node]
tb-set-node-os $node0000 @OS@
set node00000 [$ns node]
tb-set-node-os $node00000 @OS@



set lan0 [$ns make-lan "$node0 $node00 $node000 $node0000 " 1Mb 0ms]
set lan1 [$ns make-lan "$node0000 $node00000 " 100Mb 0ms]
set lan00 [$ns make-lan "$node001 $node0010 $node00100 $node00000 " 1Mb 0ms]

tb-set-node-lan-params $node0 $lan0 100ms 1Mb 0.01
tb-set-node-lan-params $node00 $lan0 100ms 1Mb 0.01
tb-set-node-lan-params $node000 $lan0 100ms 1Mb 0.01
tb-set-node-lan-params $node0000 $lan0 100ms 1Mb 0.01
tb-set-node-lan-params $node0000 $lan1 50ms 100Mb 0.01
tb-set-node-lan-params $node00000 $lan1 50ms 100Mb 0.01
tb-set-node-lan-params $node001 $lan00 100ms 1Mb 0.01
tb-set-node-lan-params $node0010 $lan00 100ms 1Mb 0.01
tb-set-node-lan-params $node00100 $lan00 100ms 1Mb 0.01
tb-set-node-lan-params $node00000 $lan00 100ms 1Mb 0.01


$ns rtproto Static
$ns run
END

my $LinkTestLoBW = <<'END';
set ns [new Simulator]
source tb_compat.tcl

set nodeA [$ns node]
set nodeB [$ns node]

tb-set-node-os $nodeA @OS@
tb-set-node-os $nodeB @OS@

set linkAB [$ns duplex-link $nodeA $nodeB 64kb 50ms DropTail]
tb-set-link-loss $linkAB 0.1

$ns rtproto Static
$ns run
END

my $Router = << 'END';
set ns [new Simulator]
source tb_compat.tcl

set node0 [$ns node]
set node1 [$ns node]
set node2 [$ns node]
set node3 [$ns node]
set node4 [$ns node]

tb-set-node-os $node0 @OS@
tb-set-node-os $node1 @OS@
tb-set-node-os $node2 @OS@
tb-set-node-os $node3 @OS@
tb-set-node-os $node4 @OS@

set link0 [$ns duplex-link $node0 $node2 100Mb 0ms DropTail]
set link1 [$ns duplex-link $node1 $node2 100Mb 0ms DropTail]
set link2 [$ns duplex-link $node2 $node3 100Mb 0ms DropTail]
set link3 [$ns duplex-link $node3 $node4 100Mb 0ms DropTail]

$ns rtproto @RTPROTO@
$ns run
END

my $RouterManual = << 'END';
set ns [new Simulator]
source tb_compat.tcl

set node1 [$ns node]
set node2 [$ns node]
set node3 [$ns node]
set nodeA [$ns node]

tb-set-node-os $node1 @OS@
tb-set-node-os $node2 @OS@
tb-set-node-os $node3 @OS@
tb-set-node-os $nodeA @OS@

set lan [$ns make-lan "$node1 $node2 $node3" 100Mb 0ms]
set link [$ns duplex-link $node3 $nodeA 100Mb 0ms DropTail]

tb-set-ip $node1 192.168.1.1
tb-set-ip $node2 192.168.1.2
tb-set-ip-lan $node3 $lan 192.168.1.3
tb-set-netmask $lan 255.255.255.248

tb-set-ip-link $node3 $link 192.168.1.9
tb-set-ip-link $nodeA $link 192.168.1.10
tb-set-netmask $link 255.255.255.252

$node1 add-route $nodeA $node3
$node2 add-route $nodeA $node3

$nodeA add-route $lan $node3

$ns rtproto Manual
$ns run
END

my $Sync= << 'END';
set ns [new Simulator]
source tb_compat.tcl

set node0 [$ns node]
set node1 [$ns node]
set node2 [$ns node]
set node3 [$ns node]
set node4 [$ns node]

tb-set-node-os $node0 @OS@
tb-set-node-os $node1 @OS@
tb-set-node-os $node2 @OS@
tb-set-node-os $node3 @OS@
tb-set-node-os $node4 @OS@

tb-set-sync-server $node0

$ns run
END


sub router_test {
  my $e = shift;
  $e->traceroute_ok('node0', 'node4', qw(node2-link0 node3-link2 node4-link3));
  $e->traceroute_ok('node4', 'node0', qw(node3-link3 node2-link2 node0-link0));

  $e->traceroute_ok('node0', 'node1', qw(node2-link0 node1-link1));
  $e->traceroute_ok('node1', 'node0', qw(node2-link1 node0-link0));

  $e->traceroute_ok('node1', 'node4', qw(node2-link1 node3-link2 node4-link3));
  $e->traceroute_ok('node4', 'node1', qw(node3-link3 node2-link2 node1-link1));
}

sub router_manual_test {
  my $e = shift;
  $e->traceroute_ok('node1', 'nodeA', qw(node3-lan nodeA-link));
  $e->traceroute_ok('nodeA', 'node1', qw(node3-link node1-lan));

  $e->traceroute_ok('node2', 'nodeA', qw(node3-lan nodeA-link));
  $e->traceroute_ok('nodeA', 'node2', qw(node3-link node2-lan));

  $e->traceroute_ok('node3', 'nodeA', qw(nodeA-link));
  $e->traceroute_ok('nodeA', 'node3', qw(node3-link));

  $e->traceroute_ok('node1', 'node3', qw(node3-lan));
  $e->traceroute_ok('node3', 'node1', qw(node1-lan));
}
my $OS ="RHL90-STD";

my $image_basic_tests = [
['threenodelan', $ThreeNodeLan, 'Simple three node experment connected via a lan'], #lan
['twonodelink', $TwoNodeLink, 'Two node experiment with a single link between them'], #pair
['linkdelay', $LinkDelay, 'Per-Link Traffic Shaping' ],
['linktestnse', $LinkTestNSE, 'Test linktest on a topo with NSE hanging around sucking CPU.'],
['linktesthilat', $LinkTestHilat,'Test linktest on a topo with long delays.'],
['linktestlobw', $LinkTestLoBW, 'Test linktest on a topo with low bandwidth.'],
];
my $router_test = sub { my $e = shift; router_test($e); basic_test($e); };
my $router_manual_test = sub { my $e = shift; basic_test($e); router_manual_test($e); };

my $image_router_tests = [
['router', $Router, '5 node routing experiement', $router_test],
['routermanual', $RouterManual, 'Tests manual routing and tb-set-ip/netmask.', $router_manual_test],
];

sub basic_test {
my $e = shift;
  my $eid = $e->eid;
  ok($e->single_node_tests, "$eid single_node_tests");
  ok($e->linktest, "$eid linktest");
}

sub osmatch {
  shift =~ /^(.*tb-set-node-os.*)$/m;
  return $1;
}

for (@$image_basic_tests) {
  my ($eid, $orig_ns, $desc) = @$_;
  my $ns = concretize($orig_ns, OS => $OS);
  #say "$eid -- " . osmatch($ns);
  rege(e($eid), $ns, \&basic_test, 2, $desc);
}

=pod
for (@$image_router_tests) {
  my ($eid, $orig_ns, $desc, $testsub) = @$_;
  my $ns = concretize($orig_ns, OS => $OS, RTPROTO => 'Static');
  rege(e($eid), $ns, $testsub, 8, $desc);
}
=cut

rege(e('routerstatic'), concretize($Router, OS => $OS, RTPROTO => 'Static'), $router_test, 8, '5 node routing experiement - static');
#rege(e('routersession'), concretize($Router, OS => $OS, RTPROTO => 'Session'), $router_test, 8, '5 node routing experiement - session');
rege(e('routermanual'), concretize($RouterManual, OS => $OS), $router_manual_test, 10, 'Tests manual routing and tb-set-ip/netmask.');

sub sync_test {
  my %cmds = (
  '0' => <<'END',
#!/bin/sh
perl -e 'sleep(rand()*30)'
echo 0 > node0up
/usr/testbed/bin/emulab-sync -i 3
cat node0up node1up node2up > node0res
END
  '1' => <<'END',
#!/bin/sh
perl -e 'sleep(rand()*30)'
echo 1 > node1up
/usr/testbed/bin/emulab-sync
cat node0up node1up node2up > node1res
END
  '2' => <<'END',
#!/bin/sh
# This wil deadlock unless the asynchronous (-a) option is working
/usr/testbed/bin/emulab-sync -a -i 2 -n barrier2
perl -e 'sleep(rand()*30)'
echo 2 > node2up
/usr/testbed/bin/emulab-sync
cat node0up node1up node2up > node2res
END
  '3' => <<'END',
#!/bin/sh
# This wil deadlock unless the asynchronous (-a) option is working
/usr/testbed/bin/emulab-sync
sleep 22
echo 3 > node3up
/usr/testbed/bin/emulab-sync -n barrier2
cat node3up node4up > node3res
END
  '4' => <<'END',
#!/bin/sh
echo 4 > node4up
/usr/testbed/bin/emulab-sync -n barrier2
cat node3up node4up > node4res
END
);
  my $e = shift;
  my $eid = $e->eid;
  my @ids = (0..4);
  ok( prun( map { my $n = $_; sub { $e->node('node'.$n)->splatex($cmds{$n}, 'startcmd'.$n.'.sh'); } } @ids ), "$eid prun splat" );
  ok( prun( map { my $n = $_; sub { $e->node('node'.$n)->ssh->cmdoutput('./startcmd'.$n.'.sh'); } } @ids ), "$eid prun sh" );
  my @results = prunout( map { my $n = $_; sub { $e->node('node'.$n)->slurp('node'.$n.'res'); } } @ids );
  ok( $results[$_] =~ /^0\n1\n2\n$/,  "noderes$_") for (0..2);
  ok( $results[$_] =~ /^3\n4\n$/, "noderes$_") for (3..4);
}

rege(e('itsync'), concretize($Sync, OS => $OS), \&sync_test, 7, 'ImageTest-sync test');

1;
