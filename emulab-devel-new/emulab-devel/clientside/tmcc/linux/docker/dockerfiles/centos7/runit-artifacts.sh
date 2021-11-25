#!/bin/sh

#
# Builds the artifacts required for runit on CentOS/Fedora (namely,
# runit itself, since runit is not packaged for those distros).
#

if [ -n "$DESTDIR" ]; then
    export DESTDIR="$DESTDIR/runit"
    mkdir -p $DESTDIR
fi

[ ! -f /tmp/yum-updated ] && yum makecache && touch /tmp/yum-updated

yum -y install rpmdevtools glibc-static which gcc make
cd /tmp
if [ -z "$RUNITSRC" ]; then
    yum -y install git
    git clone https://gitlab.flux.utah.edu/emulab/runit.git runit
else
    mkdir -p runit
    cp -pR $RUNITSRC/* runit
fi
cd runit
./redhat/build.sh
mkdir -p $DESTDIR/tmp
chown root:root $DESTDIR/tmp
chmod 1777 $DESTDIR/tmp
cp -p ~/rpmbuild/RPMS/*/*.rpm $DESTDIR/tmp
cd /tmp
rm -rf runit ~/rpmbuild

exit 0
