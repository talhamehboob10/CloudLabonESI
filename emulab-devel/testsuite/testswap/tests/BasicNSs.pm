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
package BasicNSs;

our $TwoNodeLan = << 'END';
source tb_compat.tcl

set ns [new Simulator]

set node1 [$ns node]
set node2 [$ns node]

set lan1 [$ns make-lan "$node1 $node2" 100Mb 0ms]
$ns run
END

our $TwoNodeLan5Mb = << 'END';
source tb_compat.tcl

set ns [new Simulator]

set node1 [$ns node]
set node2 [$ns node]

set lan1 [$ns make-lan "$node1 $node2" 5Mb 20ms]
$ns run
END

our $SingleNode = << 'END';
source tb_compat.tcl

set ns [new Simulator]

set node1 [$ns node]

$ns run
END

our $TwoNodeLanWithLink = << 'END';
source tb_compat.tcl

set ns [new Simulator]

set node1 [$ns node]
set node2 [$ns node]

set lan1 [$ns make-lan "$node1 $node2" 5Mb 20ms]
set link1 [$ns duplex-link $node1 $node2 100Mb 50ms DropTail]
$ns run
END

our $TooManyLans = << 'END';
source tb_compat.tcl

set ns [new Simulator]

set node1 [$ns node]
set node2 [$ns node]

set lan1 [$ns make-lan "$node1 $node2" 100Mb 0ms]
set lan2 [$ns make-lan "$node1 $node2" 100Mb 0ms]
set lan3 [$ns make-lan "$node1 $node2" 100Mb 0ms]
set lan4 [$ns make-lan "$node1 $node2" 100Mb 0ms]
set lan5 [$ns make-lan "$node1 $node2" 100Mb 0ms]
$ns run
END

1;
