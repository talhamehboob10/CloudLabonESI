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
# test_lin_blend.py - Quick prototype of piecewise triangular linear blending.
#
# The object is to apply error corrections from the center and corners of a
# camera grid to the whole grid.
#
# To use this program, first make a file_dumper input file specifying the
# calibration data at the center and corner points in meters.  The required
# order is lower-left, lower-right, center, upper-left, upper-right.  Gather
# these points using file_dumper, and analyze them through dump_analyzer.
#
# Gather a finer grid of points to be corrected using file_dumper.  (If the
# corners and origin above are part of the fine grid, you can extract a subset
# of this file_dumper data and analyze it to make the above file.)
#
# Usage: There are two filename args:
#
# ptAnal - The dump_analyzer output file for the center and corner points.
#          The order must be as above.  The section headers give the target
#          world coordinates in meters.  The mean_[ab][xy] give Mezzanine
#          fiducial blob coordinates in pixels, and the mean_[xy]_offset tells
#          the world coordinate error in meters (difference from the target)
#          to be canceled out at the center pixel between the fiducial blobs.
#
# gridData - The file_dumper output file containing data to be corrected.
#          Each data frame contains blob [ab] coordinates and world
#          coordinates.  The blob coordinates are passed through the error
#          correction blend, producing a world coordinate offset which is
#          added to the and new world coordinates in the data frame line,
#          which is then output.  Everything else streams straight through.

import sys
import getopt
import string
import re

import geom
import blend_tris
import read_analysis

opts,args = getopt.getopt(sys.argv[1:], 'td')
printTris = False
debug = False
for o,a in opts:
    if o == "-t":
        printTris = True
        pass
    if o == "-d":
        debug = True
        pass
    pass
if len(args) != 2:
    print "Read the comments for usage."
    pass

# Read in the calibration points.
nPts = 5
loc,target,offset = read_analysis.data(args[0], nPts)

# XXX Horrid Hack Warning - We need right-handed coordinates,
# but the image Y coordinate goes down from 0 at the top.
# Negate it internally.
for l in loc:
    l[1] = l[1] * -1.0

if debug:
    print "loc "+str(loc)
    print "target "+str(target)
    print "offset "+str(offset)

# Make the triangles.
#
# The required point order is lower-left, lower-right, center, upper-left,
# upper-right.  Triangles are generated clockwise from the bottom one.
# Vertices are listed clockwise from the center in each triangle, so edges
# will have the inside on the right.
#
#  p3 ------ p4
#   | \ t2 / |
#   |  \  /  |
#   |t1 p2 t3|
#   |  /  \  |
#   | / t0 \ |
#  p0 ------ p1
#
def mkTri(i0, i1, i2):
    return blend_tris.BlendTri((loc[i0], loc[i1], loc[i2]),
                               (target[i0], target[i1], target[i2]),
                               (offset[i0], offset[i1], offset[i2]))
triangles = [ mkTri(2,1,0), mkTri(2,0,3), mkTri(2,3,4), mkTri(2,4,1) ]

# Optionally output only gnuplot lines for the triangles.
if printTris:                       
    for tri in triangles:
        for v in tri.target:
            print '%f, %f'%tuple(v)
        print "%f, %f\n"%tuple(tri.target[0])
        pass
    sys.exit(0)
    pass

#================================================================

# Regexes for parsing file_dumper output.
fpnum = "\s*(\-*\d+\.\d+)\s*"
reDumperSection = re.compile("section:\s*\("+fpnum+","+fpnum+"\)")
reFrameData_line = re.compile("(\[[0-9]+\] a\("+fpnum+","+fpnum+"\)\s*"
                              "b\("+fpnum+","+fpnum+"\)\s*-- wc)"
                              "\("+fpnum+","+fpnum+","+fpnum+"\)\s*")
gridData = file(args[1])
gridLine = gridData.readline()
##print "gridLine: "+gridLine
while gridLine != "":
    # Chop the newline.
    gridLine = gridLine.strip('\n')
    ##print "gridLine = "+gridLine

    m1 = reFrameData_line.match(gridLine)
    if m1 == None:
        # Everything else streams straight through.
        print gridLine
    else:
        # Frame data.
        lineHead = m1.group(1)
        data = [float(f) for f in m1.groups()[1:]]

        # XXX Horrid Hack Warning - We need right-handed coordinates,
        # but the image Y coordinate goes down from 0 at the top.
        # Negate it internally.
        pixLoc = geom.ptBlend((data[0], -data[1]), (data[2], -data[3]))
        wcLoc = (data[4], data[5])
        wAng = data[6]

        # Find the quadrant by looking at the center edges of the triangles.
        # We can actually blend linearly past the outer edges...
        for iTri in range(nPts-1):

            # Get the barycentric coords of the image point.
            bcs = triangles[iTri].baryCoords(pixLoc)
            if bcs[1] >= 0.0 and bcs[2]  >= 0.0:

                # This is the triangle containing this image point.
                newLoc = geom.ptOffset(wcLoc, triangles[iTri].errorBlend(bcs))
                ##print "pixLoc %s, iTri %d, bcs %s"%(pixLoc, iTri, bcs)
                ##print "triangles[%d] %s"%(iTri, triangles[iTri])
                print "%s(%f,%f,%f)"%(lineHead, newLoc[0], newLoc[1], wAng)

                break
            pass
        pass

    gridLine = gridData.readline()
    pass
