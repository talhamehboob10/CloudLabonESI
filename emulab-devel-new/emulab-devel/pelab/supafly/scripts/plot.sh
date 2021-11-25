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

## GNUPlot commands
gnuplot << EOF

set title ''
set terminal postscript eps 20

set output "$1.eps"

set xlabel 'Timestamps as diffs (seconds)' font "Times,20"
set ylabel 'Duration (seconds)' font "Times,20"

#set format x "  %g"
#set grid xtics ytics

set size 1.5,1.0
set key top right

#set xrange [$2:$3]
#set yrange [$4:$5]

#set xrange [0:]
#set yrange [0:]

set xrange [0:30]
set yrange [0:1.2]

plot "$1.dat" title "$1 Lag" with linespoints pt 3
EOF
