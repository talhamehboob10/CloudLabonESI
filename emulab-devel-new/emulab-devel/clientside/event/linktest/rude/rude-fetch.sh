#!/bin/sh
#
# Copyright (c) 2004-2012 University of Utah and the Flux Group.
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

version=0.70
srcurl="http://sourceforge.net/projects/rude/files/rude/rude-$version"
tarball="rude-$version.tar.gz"

if [ -x /usr/bin/fetch ]; then
    fetch=/usr/bin/fetch
elif [ -x /usr/bin/wget ]; then
    fetch=/usr/bin/wget
else
    echo "ERROR: rude-fetch.sh: need either 'fetch' or 'wget' installed"
    exit 1
fi

if [ -n "$1" ]; then srcdir=$1; else srcdir=$PWD ; fi
if [ -n "$2" ]; then tarball=$2; fi
if [ -n "$3" ]; then host=$3; else host=www.emulab.net ; fi
dir=`pwd`

if [ ! -d $dir/rude-$version/src ]; then
    if [ ! -f "$tarball" ]; then
      cd $dir
      echo "Downloading rude source from $host to $dir ..."
      $fetch http://$host/$tarball
      if [ $? -ne 0 ]; then
           echo "Failed..."
           echo "Downloading rude source from $srcurl to $dir ..."
           $fetch $srcurl/$tarball || {
	       echo "ERROR: rude-fetch: $fetch failed"
	       exit 1
	   }
      fi
    fi
    echo "Unpacking/patching rude-$version source ..."
    tar xzof $tarball || {
        echo "ERROR: rude-fetch.sh: tar failed"
	exit 1
    }
    if [ -d rude -a ! -d rude-$version ]; then
        mv rude rude-$version
    fi

    # XXX hack to deal with relative paths...argh!
    case $srcdir in
    /*)
	;;
    *)
        srcdir="../$srcdir"
	;;
    esac
    cd rude-$version && patch -p0 < $srcdir/rude-patch || {
        echo "ERROR: rude-fetch.sh: patch failed"
	exit 1
    }
    rm -f */*.orig
fi
exit 0
