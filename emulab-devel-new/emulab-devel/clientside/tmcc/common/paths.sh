#!/bin/sh
#
# Copyright (c) 2000-2004, 2016 University of Utah and the Flux Group.
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
# This path stuff will go away when the world is consistent. Until then
# we need to be able to upgrade individual scripts to the various setups.
# Of course, the old setups need /etc/emulab/paths.{sh,pm} installed
# if any new scripts are installed too. I know, what a mess.
#
LOGDIR=/var/tmp
LOCKDIR=/var/tmp

if [ -d /usr/local/etc/emulab ]; then
	BINDIR=/usr/local/etc/emulab
	if [ -e /etc/emulab/client.pem ]; then
	    ETCDIR=/etc/emulab
	else
	    ETCDIR=/usr/local/etc/emulab
	fi
	STATICRUNDIR=/usr/local/etc/emulab/run
	VARDIR=/var/emulab
	BOOTDIR=/var/emulab/boot
	LOGDIR=/var/emulab/logs
	LOCKDIR=/var/emulab/lock
	DBDIR=/var/emulab/db
elif [ -d /etc/testbed ]; then
	ETCDIR=/etc/testbed
	BINDIR=/etc/testbed
	VARDIR=/etc/testbed
	BOOTDIR=/etc/testbed
	LOGDIR=/tmp
	LOCKDIR=/tmp
	DBDIR=/etc/testbed
	STATICRUNDIR=/etc/testbed/run
elif [ -d /etc/rc.d/testbed ]; then
	ETCDIR=/etc/rc.d/testbed
	BINDIR=/etc/rc.d/testbed
	VARDIR=/etc/rc.d/testbed
	BOOTDIR=/etc/rc.d/testbed
	DBDIR=/etc/rc.d/testbed
	STATICRUNDIR=/etc/rc.d/testbed/run
else
        echo "$0: Cannot find proper emulab paths!"
	exit 1
fi

DYNRUNDIR=/var/run/emulab

export ETCDIR
export BINDIR
export VARDIR
export BOOTDIR
export LOGDIR
export DBDIR
export LOCKDIR
export STATICRUNDIR
export DYNRUNDIR
PATH=$BINDIR:/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:\
/usr/site/bin:/usr/site/sbin
