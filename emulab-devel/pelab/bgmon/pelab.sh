#!/bin/sh
#
# Copyright (c) 2007 University of Utah and the Flux Group.
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
# Utah Network Testbed Flexlab (aka PELAB) startup
#

# XXX config me
PE_PID=tbres
PE_EID=pelabbgmon

BINDIR="/usr/testbed/sbin"
ETCDIR="/usr/testbed/etc"
LOGDIR="/usr/testbed/log/pelab"

opsrecv_args="-e $PE_PID/$PE_EID -d1"
manager_args=""
automanagerclient_args="-l600 0.10"

case "$1" in
    start)
	if [ -x $BINDIR/opsrecv.pl -a -r $ETCDIR/pelabdb.pwd ]; then
	    if [ ! -d $LOGDIR ]; then
		mkdir -m 755 $LOGDIR
	    fi
	    if [ -x $BINDIR/daemon_wrapper ]; then
		$BINDIR/daemon_wrapper -n opsrecv -l $LOGDIR/opsrecv.log -- \
			$BINDIR/opsrecv.pl $opsrecv_args
		$BINDIR/daemon_wrapper -n manager -l $LOGDIR/manager.log -- \
			$BINDIR/manager.pl $manager_args
		$BINDIR/daemon_wrapper -n automanagerclient -l $LOGDIR/automanagerclient.log -- \
	                $BINDIR/automanagerclient.pl $automanagerclient_args
	    else
	        $BINDIR/opsrecv.pl $opsrecv_args >$LOGDIR/opsrecv.log 2>&1 &
	        $BINDIR/manager.pl $manager_args >$LOGDIR/manager.log 2>&1 &
	        $BINDIR/automanagerclient.pl $automanagerclient_args >$LOGDIR/automanagerclient.log 2>&1 &
	    fi
	fi
		;;
    stop)
	if [ -r /var/run/opsrecv_wrapper.pid ]; then
	    kill `cat /var/run/opsrecv_wrapper.pid`
	    kill `cat /var/run/manager_wrapper.pid`
	    kill `cat /var/run/automanagerclient_wrapper.pid`
	else
	    pkill -f "perl.*$BINDIR/daemon_wrapper.*(automanagerclient|manager|opsrecv)\.pl"
        fi
	;;
    *)
	echo ""
	echo "Usage: `basename $0` { start | stop }"
	echo ""
	exit 64
	;;
esac
