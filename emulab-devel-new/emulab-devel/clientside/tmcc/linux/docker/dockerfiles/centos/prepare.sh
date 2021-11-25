#!/bin/sh

set -x

export CENTOS_MIRROR=http://mirror.chpc.utah.edu/pub/centos/

if [ -n "$CENTOS_MIRROR" -a ! -d /tmp/yum.repos.d ]; then
    cp -pR /etc/yum.repos.d /tmp/
    repofiles=`ls -1 /etc/yum.repos.d | xargs`
    for f in $repofiles ; do
	sed -i -e 's/^\(mirrorlist.*\)$/#\1/' /etc/yum.repos.d/$f
	sed -i -e "s|^\(.*baseurl.*\)\(\$rel.*\)$|baseurl=$CENTOS_MIRROR\/\2|" /etc/yum.repos.d/$f
    done
fi

[ ! -f /tmp/yum-updated ] && yum updateinfo && touch /tmp/yum-updated

exit 0
