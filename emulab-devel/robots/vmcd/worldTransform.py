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
import math

# Transform a point from camera-local into global world coords.
# (Same logic as local2global_posit_trans in vmc-client.c)
def worldTransform(options, cx, cy, ca):
    ct = math.cos(options['world_theta'])
    st = math.sin(options['world_theta'])
    # Notice this is a left-handed rotation, followed by an offset.
    wx = ct * cx + st * -cy + options['world_x']
    wy = ct * -cy + st * -cx + options['world_y']
    # Rotate 90 more degrees because the fiducials are now mounted crosswise.
    wa = mtp_theta(ca + options['world_theta'] + math.pi/2);
    return wx, wy, wa

# Put orientation into the +-PI radians range.
# (Same logic as mtp_theta in mtp.c)
def mtp_theta(theta):
    if theta < -math.pi:
	retval = theta + (2.0 * math.pi)
    elif theta > math.pi:
	retval = theta - (2.0 * math.pi)
    else:
	retval = theta
        pass
    return retval

