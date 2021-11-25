#!/bin/sh

set -x

if [ -f /tmp/sources.list.backup ]; then
    mv /tmp/sources.list.backup /etc/apt/sources.list
fi

apt-get clean
rm -rf /var/lib/apt/lists/*
rm -f /tmp/apt-updated
rm -rf /tmp/* /var/tmp*

exit 0
