#!/bin/sh
#
# Copyright (c) 2007 University of Utah and the Flux Group.
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

InputFile1="\"$1\""
InputFile2="\"$2\""
OutputFile="\"$3\""

/proj/tbres/R/bin/R --slave  << EOF

xv <- read.table($InputFile1, header=0)
yv <- read.table($InputFile2, header=0)

xval <- xv[,2]
yval <- yv[,2]

corrObj <- ccf(xval, yval, lag.max=1000, type="correlation", plot=FALSE)
dataFrame <- data.frame(corrObj[[4]], corrObj[[1]])
write.table(dataFrame,file=$OutputFile,quote=FALSE,row.names=FALSE, col.names=FALSE)

q(runLast=FALSE)

EOF


