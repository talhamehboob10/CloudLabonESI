#!/bin/sh

#
# We expect several environment vars to be set:
#   EMULABSRC -- points to the source tree, may be read-only
#   PUBSUBSRC -- points to the pubsub source tree, may be read-only
#   DESTDIR -- points to an empty read-write volume from the host
#     (if unset, this will just install the clientside into the container root)
#

set -x

DIRNAME=`pwd`

# echo "@testing http://nl.alpinelinux.org/alpine/edge/testing" >> /etc/apk/repositories

apk update

apk add git ca-certificates perl \
    gcc make libc-dev byacc libtool openssl-dev 'g++' \
    sudo python python-dev libpcap-dev boost-dev wget patch flex \
    zlib-dev libtirpc-dev

if [ -z "$EMULABTMPSRC" ]; then
    echo "WARNING: missing EMULABSRC environment variable pointer to src; cloning!"
    export EMULABSRC=/tmp/emulab-devel
    cd /tmp
    git clone https://gitlab.flux.utah.edu/emulab/emulab-devel.git $EMULABSRC
    [ ! $? -eq 0 ] && exit 1
fi
if [ -z "$PUBSUBSRC" ]; then
    echo "WARNING: missing PUBSUBSRC environment variable pointer to src; cloning!"
    export PUBSUBSRC=/tmp/pubsub
    cd /tmp
    git clone https://gitlab.flux.utah.edu/emulab/pubsub.git $PUBSUBSRC
    [ ! $? -eq 0 ] && exit 1
fi

#export CFLAGS="-static"

mkdir -p /tmp/pubsub.obj
cd /tmp/pubsub.obj
cp -pRv $PUBSUBSRC/* /tmp/pubsub.obj
./configure --disable-ssl && make && make install
[ ! $? -eq 0 ] && exit 1
cd /tmp
rm -rf /tmp/pubsub.obj

#
# If we installed to a DESTDIR, well, we're going to need pubsub dropped
# into real root here too, for the clientside build.  So copy it in if
# so.
#
if [ -n "$DESTDIR" ]; then
    cp -pRv $DESTDIR/* /
fi

echo /usr/local/lib > /etc/ld.so.conf.d/pubsub.conf
ldconfig

mkdir -p /tmp/emulab.obj
cd /tmp/emulab.obj
export NONTP=1
$EMULABSRC/clientside/configure --with-TBDEFS=$EMULABSRC/defs-utahclient \
    && make client && make client-install \
    && make -C tmcc/linux docker-guest-install
[ ! $? -eq 0 ] && exit 1
cd /tmp
rm -rf /tmp/emulab.obj

#
# Create these traditional NFS mountpoints now.  Scripts get unhappy
# about them if they're not there.
#
mkdir -p $DESTDIR/users $DESTDIR/proj $DESTDIR/groups $DESTDIR/share

exit 0
