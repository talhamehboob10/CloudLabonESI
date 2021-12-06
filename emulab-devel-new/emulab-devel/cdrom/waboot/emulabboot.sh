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
# This script goes in /usr/local/etc/rc.d on the disk image.
#
# Set the magic bit that said we booted from the disk okay. Otherwise
# if the CDROM boots and this has not been done, the CDROM assumes the
# disk is scrogged.
# 
. /etc/rc.conf.local

#
# netbed_disk is set in rc.conf.local by the CDROM boot image.
#
case "$1" in
start)
	if [ -x /usr/site/sbin/tbbootconfig ]; then
		/usr/site/sbin/tbbootconfig -c 1 $netbed_disk

		case $? in
		0)
		    exit 0
		    ;;
		*)
		    echo 'Error in testbed boot header program'
		    echo 'Reboot failed. HELP!'
		    exit 1
		    ;;
		esac
	fi
	;;
stop)
	;;
*)
	echo "Usage: `basename $0` {start|stop}" >&2
	exit 1
	;;
esac
