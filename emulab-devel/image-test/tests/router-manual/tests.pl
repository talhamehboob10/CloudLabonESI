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

test_traceroute 'node1', 'nodeA', qw(node3-lan nodeA-link);
test_traceroute 'nodeA', 'node1', qw(node3-link node1-lan);

test_traceroute 'node2', 'nodeA', qw(node3-lan nodeA-link);
test_traceroute 'nodeA', 'node2', qw(node3-link node2-lan);

test_traceroute 'node3', 'nodeA', qw(nodeA-link);
test_traceroute 'nodeA', 'node3', qw(node3-link);

test_traceroute 'node1', 'node3', qw(node3-lan);
test_traceroute 'node3', 'node1', qw(node1-lan);
