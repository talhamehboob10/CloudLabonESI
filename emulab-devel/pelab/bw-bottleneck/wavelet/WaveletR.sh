#!/bin/sh
#
# Copyright (c) 2006, 2007 University of Utah and the Flux Group.
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



InputFile="\"$1\""
OutputFile="\"$2\""

/usr/bin/R --no-save  > /dev/null 2>&1 << EOF

library(rwt)

delays <- read.table($InputFile, header=0)

xval <- delays[,1]
yval <- delays[,2]

h <- daubcqf(6)\$h.1

xResult.dwt <- denoise.dwt(xval, h)
yResult.dwt <- denoise.dwt(yval, h)

correctedX <- xResult.dwt\$xd
correctedY <- yResult.dwt\$xd

xvec <- as.vector(correctedX)
yvec <- as.vector(correctedY)

corrObj <- ccf(xvec, yvec, lag.max=0, type="correlation", plot=FALSE)
dataFrame <- data.frame(corrObj[[4]], corrObj[[1]])
write.table(dataFrame,file=$OutputFile,quote=FALSE,row.names=FALSE, col.names=FALSE)

q(runLast=FALSE)

EOF


