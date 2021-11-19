#!/bin/sh

#
# Check our node attributes for CLIENTSIDE_UPDATE == 1.  If set, check
# for CLIENT_UPDATE_EACHBOOT != 1 and only continue if we've not yet
# done an update.  Finally, if we're going to update, check for
# CLIENTSIDE_UPDATE_REPO and CLIENTSIDE_UPDATE_REF .
#

set -x

prog=`basename $0`
pwd=`pwd`

repo=https://gitlab.flux.utah.edu/emulab/emulab-devel.git
ref=

ttmp=`mktemp`
/usr/local/etc/emulab/tmcc -b nodeattributes > $ttmp
. $ttmp
rm -f $ttmp

if [ -z "$CLIENTSIDE_UPDATE" -o "$CLIENTSIDE_UPDATE" != "1" ]; then
    echo "$prog: not updating clientside"
    exit 0;
fi
if [ -z "$CLIENTSIDE_UPDATE_EACHBOOT" -o "$CLIENTSIDE_UPDATE_EACHBOOT" != "1" ]; then
    if [ -e /var/emulab/boot/update-clientside-done ]; then
	echo "$prog: not updating clientside; already done"
	exit 0
    fi
fi
if [ -n "$CLIENTSIDE_UPDATE_REPO" ]; then
    repo="$CLIENTSIDE_UPDATE_REPO"
fi
if [ -n "$CLIENTSIDE_UPDATE_REF" ]; then
    ref="$CLIENTSIDE_UPDATE_REF"
fi

current=`cat /etc/emulab/version`
if [ -z "$current" ]; then
    echo "WARNING: $prog cannot determine current Emulab installation commit hash; aborting!"
    exit 1
fi
if [ -n "$ref" ]; then
    latest=`git ls-remote $repo | awk "/${ref}\\$/ { print \\$1 }"`
else
    latest=`git ls-remote $repo | awk "/[\t ]HEAD/ { print \\$1 }"`
fi
if [ -z "$latest" ]; then
    echo "WARNING: $prog cannot retrieve latest Emulab commit hash; aborting!"
    exit 1
fi

if [ "$latest" = "$current" ]; then
    echo "$prog: nothing to do, latest version already installed"
    exit 0
fi

echo "$prog: attempting clientside update from $repo $ref ($current -> $latest)..."

tmpdir=`mktemp -d`
mkdir -p $tmpdir/src $tmpdir/obj
git clone $repo $tmpdir/src
if [ ! $? -eq 0 ]; then
    echo "ERROR: $prog: git clone $repo failed, aborting!"
    exit 1
fi
cd $tmpdir/src
if [ -n "$ref" ]; then
    git checkout $ref
    if [ ! $? -eq 0 ]; then
	echo "ERROR: $prog: git checkout $ref failed, aborting!"
	exit 1
    fi
fi
cd ../obj
../src/clientside/configure --with-TBDEFS=../src/defs-utahclient
if [ ! $? -eq 0 ]; then
    echo "ERROR: $prog: configure failed; aborting!"
    exit 1
fi
make
if [ ! $? -eq 0 ]; then
    echo "ERROR: $prog: make failed; aborting!"
    exit 1
fi
make NOPASSWD=1 NOHOSTS=1 client-install
if [ ! $? -eq 0 ]; then
    echo "ERROR: $prog: make client-install failed; aborting!"
    exit 1
fi
if [ -e /etc/emulab/genvmtype ]; then
    vmtype=`cat /etc/emulab/genvmtype`
    if [ -n "$vmtype" ]; then
	make -C tmcc/linux ${vmtype}-install
	if [ ! $? -eq 0 ]; then
	    echo "ERROR: $prog: ${vmtype}-install failed; aborting!"
	    exit 1
	fi
    fi
fi
cd $pwd
rm -rf $tmpdir

echo $latest > /var/emulab/boot/update-clientside-done

echo "$prog: finished updating clientside to commit hash $latest"

exit 0
