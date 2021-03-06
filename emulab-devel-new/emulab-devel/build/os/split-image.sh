#!/bin/sh

#
# Copyright (c) 2000-2002 University of Utah and the Flux Group.
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


#
# Split up an image and imagezip it. Beware, some sector offsets and sizes
# are hardcoded in here.
#

#
# Configure variables
#
TB="/users/mshobana/emulab-devel/build"

#
# My zipper.
# 
zipper="$TB/bin/imagezip"

#
# The input image
# 
image=wd0

#
# Boot block: start 0, size 63
# 
$zipper -d -r -c 62 $image ${image}-mbr.ndz

#
# FreeBSD:
#
$zipper -d -s 1 $image ${image}-fbsd.ndz

#
# Linux:
#
$zipper -d -s 2 $image ${image}-rhat.ndz

#
# All of it.
#
$zipper -d $image ${image}-all.ndz
