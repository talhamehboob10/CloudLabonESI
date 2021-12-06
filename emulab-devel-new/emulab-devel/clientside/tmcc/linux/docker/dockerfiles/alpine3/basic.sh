#!/bin/sh

set -x

# add testing branch to repo for tcsh package
echo "@community http://nl.alpinelinux.org/alpine/edge/community" >> /etc/apk/repositories

apk update

# missing iputils-ping package from ubuntu process
apk add openssh-server rsyslog logrotate iproute2 iputils net-tools sudo bash \
    util-linux openssh-client tcsh@community

# the apk tcsh doesnt include a csh symlink so we'll add one
ln -s /bin/tcsh /bin/csh

## Permissions on these should be the same as the host, so preserve them.
#cp -p /tmp/src/ssh-host-keys/ssh_host* /etc/ssh/

## Install default SSH key for root and app.
mkdir -p /root/.ssh
chmod 700 /root/.ssh
chown root:root /root/.ssh

echo console >> /etc/securetty

exit 0
