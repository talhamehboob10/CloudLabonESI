#!/bin/sh
#
# Copyright (c) 2004-2018 University of Utah and the Flux Group.
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

if [ -n "$3" ]; then
    version="$3"
fi
if [ -z "$version" ]; then
    version=2.0.2
fi
# The old versions use this funny old URL, and I can't make any sense of
# why it still works.  But of course it doesn't work for new versions.
if [ "$version" = "2.0.2" ]; then
    srcurl="http://sourceforge.net/projects/iperf/files/iperf/iperf 2.02 source"
else
    srcurl="https://sourceforge.net/projects/iperf2/files/iperf-${version}.tar.gz"
fi
tarball="iperf-$version.tar.gz"

if [ -x /usr/bin/fetch ]; then
    fetch=/usr/bin/fetch
elif [ -x /usr/bin/wget ]; then
    fetch=/usr/bin/wget
else
    echo "ERROR: iperf-fetch.sh: need either 'fetch' or 'wget' installed"
    exit 1
fi

if [ -n "$1" ]; then srcdir=$1; else srcdir=$PWD ; fi
if [ -n "$2" ]; then tarball=$2; fi
if [ -n "$4" ]; then host=$4; else host=www.emulab.net ; fi
dir=`pwd`

if [ ! -d $dir/iperf-$version/src ]; then
    if [ ! -f "$tarball" ]; then
      cd $dir
      echo "Downloading iperf source from $host to $dir ..."
      $fetch http://$host/$tarball
      if [ $? -ne 0 ]; then
           echo "Failed..."
           echo "Downloading iperf source from \"$srcurl\" to $dir ..."
           $fetch "$srcurl/$tarball" || {
	       echo "ERROR: iperf-fetch: $fetch failed"
	       exit 1
	   }
      fi
    fi
    echo "Unpacking/patching iperf-$version source ..."
    tar xzof $tarball || {
        echo "ERROR: iperf-fetch.sh: tar failed"
	exit 1
    }
    # XXX hack to deal with relative paths...argh!
    case $srcdir in
    /*)
	;;
    *)
        srcdir="../$srcdir"
	;;
    esac
    cd iperf-$version && patch -p1 < $srcdir/iperf-${version}.patch || {
        echo "ERROR: iperf-fetch.sh: patch failed"
	exit 1
    }
    rm -f */*.orig
fi
exit 0
