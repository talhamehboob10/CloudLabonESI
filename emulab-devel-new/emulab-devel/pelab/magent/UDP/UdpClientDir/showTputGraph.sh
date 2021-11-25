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


# UdpClient saves the throughput calculated after receiving each packet.

# This data is dumped in Throughput.log - it is converted to a data file for GNUplot
# using a python script makeGnuPlot.py

# The GNUplot file plot.gp displays the graph from data values in stats.log

# NOTE: If you want to run the client multiple times, save the stats.log with 
# another name, because it will be overwritten every time this shell script is run.

python makeGnuPlot.py stats.log
gnuplot -persist plot.gp
