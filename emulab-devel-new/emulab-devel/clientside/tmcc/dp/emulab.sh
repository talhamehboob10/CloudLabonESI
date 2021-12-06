#!/bin/sh
#
# Copyright (c) 2000-2003, 2007 University of Utah and the Flux Group.
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
PATH=/sbin:/bin:/usr/sbin:/usr/bin
[ -f /etc/default/rcS ] && . /etc/default/rcS
. /lib/lsb/init-functions

. /etc/emulab/paths.sh

case "$1" in
    start)
	if [ -x $BINDIR/emulabctl ]; then
	    log_daemon_msg "Starting Emulab services" ""
	    $BINDIR/emulabctl start
	    log_end_msg $?
	fi
        ;;
    reload|force-reload)
        echo "Error: argument '$1' not supported" >&2
        exit 3
        ;;
    stop)
	if [ -x $BINDIR/emulabctl ]; then
	    log_daemon_msg "Stopping Emulab services" ""
	    $BINDIR/emulabctl stop
	    log_end_msg $?
	fi
        ;;
    restart)
	$0 stop && sleep 10 && $0 start
	;;
    *)
        echo "Usage: $0 start|stop|restart" >&2
        exit 3
        ;;
esac

exit 0
