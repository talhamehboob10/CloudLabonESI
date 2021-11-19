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
# Figure out which OS, distro. etc.
# Output: TAG=<string> OS=<string> DIST=<string> REL=<string>
#  where OS is 'FreeBSD', 'Linux', 'Cygwin', etc.
#        DIST for Linux only, is 'Redhat', 'Fedora', 'Ubuntu', etc.
#        REL is the release like '6.2', '9.0', '5.1', etc.
#        TAG is a unique combo of the above like 'freebsd6', 'fedora4', etc.
#

if [ $# -ne 1 ]; then
    arg="-a"
else
    arg=$1
fi

os=`uname -s`
tag=
dist=

case $os in
FreeBSD)
    dist="FreeBSD"
    rel=`uname -v | sed -e 's/FreeBSD \([0-9]\.[0-9][0-9]*\).*/\1/'`
    ;;
Linux)
    if [ -r /etc/lsb-release ]; then
        dist=`grep DISTRIB_ID /etc/lsb-release | awk -F = '{ print $2; }'`
        rel=`grep DISTRIB_RELEASE /etc/lsb-release | awk -F = '{ print $2; }'`
    fi
    if [ -z "$dist" -a -r /etc/redhat-release ]; then
        trel=`grep 'Red Hat' /etc/redhat-release | sed -e 's/Red Hat Linux release \([0-9]\(\.[0-9]\)\?\).*/\1/'`
	if [ -n "$trel" ]; then
            dist="Redhat"
	    rel=$trel
	fi
	trel=`grep 'Fedora' /etc/redhat-release | sed -e 's/Fedora .*release \([0-9.]\+\).*/\1/'`
	if [ -n "$trel" ]; then
	    dist="Fedora"
	    rel=$trel
	fi
	trel=`grep 'CentOS' /etc/redhat-release | sed -e 's/CentOS .*release \([0-9.]\+\).*/\1/'`
	if [ -n "$trel" ]; then
	    dist="CentOS"
	    rel=$trel
	fi
    fi
    # XXX hack check for stargate
    if [ -z "$dist" -a `uname -m` = "armv5tel" ]; then
        dist="Stargate"
        rel=1.0  # XXX probably wrong
    fi
    ;;
CYGWIN_NT-5.1)	# aka Windows XP
    tag=$os	# XXX compat for tmcd makefile
    os="Cygwin"
    dist="NT"
    rel="5.1"
    ;;
*)
    dist="Unknown"
    rel="0.0"
    ;;
esac

if [ -z "$tag" ]; then
    p1=`echo $dist | tr '[A-Z]' '[a-z]'`
    p2=`echo $rel | sed -e 's/^\([0-9]*\).*/\1/'`
    tag="${p1}${p2}"
fi

case $arg in
-a)
    echo "TAG=$tag OS=$os DIST=$dist REL=$rel"
    ;;
-t)
    echo "$tag"
    ;;
-o)
    echo "$os"
    ;;
-d)
    echo "$dist"
    ;;
-r)
    echo "$rel"
    ;;
esac
exit 0
