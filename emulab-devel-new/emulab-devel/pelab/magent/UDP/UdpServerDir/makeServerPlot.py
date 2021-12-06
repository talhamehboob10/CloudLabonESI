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

import sys
import re

inFile = open(sys.argv[1], 'r')

outFile = open(sys.argv[2], 'w')

regExp = re.compile('^(\w*?)\=(\d*)\,(\w*?)\=(\d*)')

count = 0
bandWidth = 0
initTime = 0
timeDiff = 0;
lastTime = 0;
currentTime = 0;
line = ""

for line in inFile:
	match = regExp.match(line)

	if count == 0:
		initTime = int(match.group(2))
		timeDiff = 0
		count = count + 1
		lastTime = initTime
	else:
		currentTime = int(match.group(2))
		timeDiff = currentTime - initTime
		bandWidth = int(match.group(4))*1000000 / ( ( currentTime - lastTime ))
		lastTime = currentTime

	outFile.write(str(timeDiff) + "  " + str(bandWidth) + "\n" )

