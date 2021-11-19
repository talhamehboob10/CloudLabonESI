#!/bin/sh

#
# Install and configure runit, including our ssh/syslog unit files.  We
# have a custom version of runit that was built in runit-artifacts.sh,
# so install that one.
#

set -x

export DEBIAN_FRONTEND=noninteractive
#export LANGUAGE=en_US:en
#export LC_ALL=en_US.UTF-8
#export LANG=en_US.UTF-8
#export LC_CTYPE=en_US.UTF-8

dpkg -i /tmp/runit_*.deb
apt-get install -y --no-install-suggests --no-install-recommends -f

#language-pack-en

## See https://github.com/dotcloud/docker/issues/1024
#dpkg-divert --local --rename --add /sbin/initctl
#ln -sf /bin/true /sbin/initctl

## https://bugs.launchpad.net/launchpad/+bug/974584
#dpkg-divert --local --rename --add /usr/bin/ischroot
#ln -sf /bin/true /usr/bin/ischroot

#locale-gen $LANG
#update-locale LANG=$LANG

# Configure runit services.
#mkdir -p /etc/service/sshd
#touch /etc/service/sshd/down
#mkdir -p /etc/service/rsyslog
#touch /etc/service/rsyslog/down
#mkdir -p /etc/service/testbed
#touch /etc/service/testbed/down
#mkdir -p /etc/service/tbprepare
#touch /etc/service/testbed/up

exit 0
