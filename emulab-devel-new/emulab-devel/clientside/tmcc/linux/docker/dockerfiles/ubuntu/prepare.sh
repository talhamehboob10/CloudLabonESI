#!/bin/sh

set -x

export DEBIAN_FRONTEND=noninteractive

#export UBUNTU_MIRROR=http://ubuntu.cs.utah.edu/ubuntu

if [ -n "$UBUNTU_MIRROR" -a ! -f /tmp/sources.list.backup ]; then
    cp -p /etc/apt/sources.list /tmp/sources.list.backup
    sed -i -r -e "s|http://.*.ubuntu.com/ubuntu|$UBUNTU_MIRROR|" \
	/etc/apt/sources.list
fi

[ ! -f /tmp/apt-updated ] && apt-get update && touch /tmp/apt-updated

exit 0
