#!/bin/sh
#
# Copyright (c) 2000-2003 University of Utah and the Flux Group.
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
# This file goes in /usr/local/etc/rc.d on the CDROM.
#
# Get the disk and pass that to the registration program. It does
# all the actual work.
# 

. /etc/rc.conf.local

if [ "$netbed_IP" = "DHCP" ]; then
	# See /etc/dhclient-exit-hooks
	netbed_IP=`cat /var/run/myip`    
fi

case "$1" in
start)
	if [ -f /usr/site/sbin/register.pl ]; then
		/usr/site/sbin/register.pl $netbed_disk $netbed_IP
		exit $?
	fi
	;;
stop)
	;;
*)
	echo "Usage: `basename $0` {start|stop}" >&2
	exit 1
	;;
esac
