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


# The argument below should be the interface on which this emulab node
# is connected to the other node ( running the client ) - not the 
# control connection interface.

# This can be looked up by running ifconfig and the interface with 10.*.*.* address
# is the correct one.

# NOTE: A single invocation of file script/program only works for one UdpClient session.
# The server program has to be restarted for every session.

# The server runs in an infinite while loop - it can be terminated after the session
# is determined to be done at the client - kill using Ctrl-C.

sudo ./UdpServer vnet 3492
