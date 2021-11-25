#!/bin/sh

#
# Builds the artifacts required for runit on Debian.  Our version is
# customized.
#

set -x

export DEBIAN_FRONTEND=noninteractive

if [ -n "$DESTDIR" ]; then
    export DESTDIR="$DESTDIR/runit"
    mkdir -p $DESTDIR
fi

DIRNAME=`pwd`

$DIRNAME/debian/prepare.sh

apt-get install -y --no-install-suggests --no-install-recommends \
    build-essential dpkg-dev wget
cd /tmp
if [ -z "$RUNITSRC" ]; then
    apt-get install -y --no-install-suggests --no-install-recommends \
	git ca-certificates
    git clone https://gitlab.flux.utah.edu/emulab/runit runit
else
    mkdir -p runit
    cp -pR $RUNITSRC/* runit
fi
cd runit/

if [ ! -f runit-2.1.2.tar.gz ]; then
    wget http://www.emulab.net/downloads/docker/runit-2.1.2.tar.gz
    if [ ! $? -eq 0 ]; then
	wget http://smarden.org/runit/runit-2.1.2.tar.gz
    fi
fi
if [ -d runit-2.1.2 ]; then
    rm -rf runit-2.1.2
fi
tar -xzf runit-2.1.2.tar.gz --strip-components=1
dpkg-buildpackage -uc -us
cd ..
mkdir -p $DESTDIR/tmp
chown root:root $DESTDIR/tmp
chmod 1777 $DESTDIR/tmp
cp -p *.deb $DESTDIR/tmp
rm -rf runit *.deb *.dsc

$DIRNAME/debian/cleanup.sh

exit 0
