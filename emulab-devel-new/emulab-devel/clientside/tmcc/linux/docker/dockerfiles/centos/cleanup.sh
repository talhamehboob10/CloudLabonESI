#!/bin/sh

set -x

if [ -d /tmp/yum.repos.d ]; then
    cp -p /tmp/yum.repos.d/* /etc/yum.repos.d
fi

yum clean all
rm -f /tmp/yum-updated
rm -rf /tmp/* /var/tmp*

exit 0
