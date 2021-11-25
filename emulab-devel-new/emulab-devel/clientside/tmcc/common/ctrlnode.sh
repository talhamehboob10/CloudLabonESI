#!/bin/sh
#
# Copyright (c) 2000-2014 University of Utah and the Flux Group.
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
. /etc/emulab/paths.sh

#
# Boottime initialization of the control node (aka ops, users, etc).
#
case "$1" in
start|faststart|quietstart|onestart|forcestart)
	$BINDIR/rc/rc.ctrlnode -b boot
	;;
stop|faststop|quietstop|onestop|forcestop)
	$BINDIR/rc/rc.ctrlnode shutdown 
	;;
*)
	echo "Usage: `basename $0` {start|stop}" >&2
	;;
esac

exit 0
