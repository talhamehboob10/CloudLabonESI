#!/usr/local/bin/python
# 
#   Copyright (c) 2005 University of Utah and the Flux Group.
#   
#   {{{EMULAB-LICENSE
#   
#   This file is part of the Emulab network testbed software.
#   
#   This file is free software: you can redistribute it and/or modify it
#   under the terms of the GNU Affero General Public License as published by
#   the Free Software Foundation, either version 3 of the License, or (at
#   your option) any later version.
#   
#   This file is distributed in the hope that it will be useful, but WITHOUT
#   ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
#   FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Affero General Public
#   License for more details.
#   
#   You should have received a copy of the GNU Affero General Public License
#   along with this file.  If not, see <http://www.gnu.org/licenses/>.
#   
#   }}}
# 
# read_analysis.py - Read in data from dump_analyzer.

import re
import geom

# Regexes for parsing dump_analyzer output.
fpnum = "\s*(\-*\d+\.\d+)\s*"
reAnalysisSection = re.compile("section\s*\("+fpnum+","+fpnum+"\)\s*results:")
reAnalysisData = re.compile("\s*mean_([abw])([xy]+)(\w*)\s*="+fpnum)

def data(dataFile, nPts):
    ptAnal = file(dataFile)
    ptLine = ptAnal.readline()
    ##print "ptLine: "+ptLine

    iPt = -1
    loc = [None for i in range(nPts)]    # Fiducial center coordinates in pixels.
    target = [None for i in range(nPts)] # Target world coordinates in meters.
    offset = [None for i in range(nPts)] # World coordinate error in meters.

    while ptLine != "" and ptLine[:5] != "total":
        # Chop the newline.
        ptLine = ptLine.strip('\n')
        ##print "ptLine = "+ptLine

        m1 = reAnalysisSection.match(ptLine)
        m2 = reAnalysisData.match(ptLine)
        if m1 != None:

            # Section headers.
            iPt = iPt + 1
            if iPt > nPts-1:
                print "\nExtra points?\n"
                break
            target[iPt] = (float(m1.group(1)), float(m1.group(2)))
            blobCtrs = [[None, None], [None, None]]
            offset[iPt] = [None, None]

        elif m2 != None:
            ##print "m2.groups() "+str(m2.groups())

            # Coordinates.
            if m2.group(1) != "w" and m2.group(3) == '':

                # Stash mean_[ab][xy] blob center coordinates.
                blobCtrs[m2.group(1) == 'b'][m2.group(2) == 'y'] = float(m2.group(4))
                ##print "blobCtrs "+str(blobCtrs)

            elif m2.group(3) == '_offset':

                if m2.group(2) == 'x':
                    # mean_wx_offset - We have [ab][xy] coords, record the center.
                    ##print "iPt "+str(iPt)+", blobCtrs "+str(blobCtrs)
                    loc[iPt] = geom.ptBlend(*blobCtrs)
                    pass

                # Stash mean_w[xy]_offset error coords.
                offset[iPt][m2.group(2) == 'y'] = float(m2.group(4))

                pass
            pass

        ptLine = ptAnal.readline()
        pass
    return (loc, target, offset)
