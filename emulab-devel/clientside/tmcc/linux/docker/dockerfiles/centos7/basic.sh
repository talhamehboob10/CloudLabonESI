#!/bin/sh

set -x

yum install -y \
    openssh-server rsyslog logrotate iproute net-tools

## Permissions on these should be the same as the host, so preserve them.
#cp -p /tmp/src/ssh-host-keys/ssh_host* /etc/ssh/

## Install default SSH key for root and app.
mkdir -p /root/.ssh
chmod 700 /root/.ssh
chown root:root /root/.ssh

exit 0
