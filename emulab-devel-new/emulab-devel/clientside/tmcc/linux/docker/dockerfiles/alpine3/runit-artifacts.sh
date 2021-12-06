#!/bin/sh

#
# Builds the artifacts required for runit on Alpine. It's already
# a package so not worrying about it currently
#

set -x

if [ -n "$DESTDIR" ]; then
    export DESTDIR="$DESTDIR/runit"
    mkdir -p $DESTDIR
fi

DIRNAME=`pwd`

$DIRNAME/alpine/prepare.sh

apk update

apk add alpine-sdk wget
cd /tmp
if [ -z "$RUNITSRC" ]; then
    apk add git ca-certificates
    git clone https://gitlab.flux.utah.edu/emulab/runit runit
    # will need to be removed once alpine branch merged with master
    # cd runit/
    # git checkout alpine
    # cd ..
else
    mkdir -p runit
    cp -pR $RUNITSRC/* runit
fi

cd runit/alpine/

mkdir -p /var/cache/distfiles
adduser -D packager
addgroup packager abuild
chgrp abuild /var/cache/distfiles
chgrp -R abuild ..
chmod -R g+w ..
chmod g+w /var/cache/distfiles
echo "packager    ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers

sudo -u packager sh $DIRNAME/alpine3/runit-packager.sh

cd /tmp/runit/x86_64
mkdir -p $DESTDIR/tmp
chown root:root $DESTDIR/tmp
chmod 1777 $DESTDIR/tmp
cp -p *.apk $DESTDIR/tmp

# cd ../..
# cp -p *.deb $DESTDIR/tmp
# rm -rf runit *.deb *.dsc

#
# Also rebuild shadow to support user/group names with capitalized letters.
#
cd /tmp/
wget https://www.emulab.net/downloads/alpine-shadow-src.tar.gz
tar -xzvf alpine-shadow-src.tar.gz
chown -R packager shadow
cd shadow
sudo -u packager abuild checksum
sudo -u packager -H abuild -r
cp -p /home/packager/packages/tmp/x86_64/shadow-4*.apk \
    /home/packager/packages/tmp/x86_64/shadow-uidmap-4*.apk \
    $DESTDIR/tmp

$DIRNAME/alpine/cleanup.sh

exit 0
