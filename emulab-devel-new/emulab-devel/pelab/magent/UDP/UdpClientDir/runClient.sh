#!/bin/sh

#
# Copyright (c) 2006 University of Utah and the Flux Group.
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


# Command line arguments:
# First argument - Interface on which we are connected to the server node ( not the control conn ).
# Second - Address/hostname of the node running the server program.
# Third - Number of UDP packets to send to the server.
# Fourth - Size of the data part of the UDP packets.
# Fifth - The rate at which the packets should be sent ( bits per sec )
# This rate will also include the UDP, IP & ethernet headers along with the packet size.
# Sixth - MHz of CPU clock frequency

# The client runs in an infinite while loop - so when no more data is being printed on
# screen, it is safe to kill it( Ctrl-C) and look at the results.

# NOTE: The UdpServer needs to be restarted before running the client for a second time.

sudo ./UdpClient eth0 node1 10000 1470 500000 601
