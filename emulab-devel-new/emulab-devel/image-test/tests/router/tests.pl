#
# Copyright (c) 2005-2006 University of Utah and the Flux Group.
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

# need the delay here to give time for the routes to converge when the
# routing protocol is session
if ($parms{rtproto} eq 'Session') {
  print "Sleeping 90 seconds to give time for the routes to converge...";
  sleep 90;
  print "DONE\n";
}

test_traceroute 'node0', 'node4', qw(node2-link0 node3-link2 node4-link3);
test_traceroute 'node4', 'node0', qw(node3-link3 node2-link2 node0-link0);

test_traceroute 'node0', 'node1', qw(node2-link0 node1-link1);
test_traceroute 'node1', 'node0', qw(node2-link1 node0-link0);

test_traceroute 'node1', 'node4', qw(node2-link1 node3-link2 node4-link3);
test_traceroute 'node4', 'node1', qw(node3-link3 node2-link2 node1-link1);


