#!/usr/bin/sh
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

LINKNAME=planetc
HOSTNAME=`cat /var/emulab/boot/nickname | sed 's/\..*//'`
LINK="$HOSTNAME-$LINKNAME"
LINKIP=`grep "$LINK" /etc/hosts | cut -f1`
IFACENAME=`ifconfig -a | perl -e 'while(<>) { if (/^(eth\d+)/) { $if = $1; } if (/10.1/) { print "$if\n"; exit 0; }} exit 1;'`

echo $IFACENAME
