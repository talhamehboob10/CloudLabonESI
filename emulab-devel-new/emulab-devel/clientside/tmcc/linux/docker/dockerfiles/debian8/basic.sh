#!/bin/sh

set -x

export DEBIAN_FRONTEND=noninteractive

apt-get install -y --no-install-suggests --no-install-recommends \
    openssh-server rsyslog logrotate iproute2 iputils-ping net-tools sudo

## Permissions on these should be the same as the host, so preserve them.
#cp -p /tmp/src/ssh-host-keys/ssh_host* /etc/ssh/

## Install default SSH key for root and app.
mkdir -p /root/.ssh
chmod 700 /root/.ssh
chown root:root /root/.ssh

echo console >> /etc/securetty

exit 0
