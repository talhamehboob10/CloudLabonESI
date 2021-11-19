#!/bin/sh

#
# Install and configure runit, including our ssh/syslog unit files.  We
# have a custom version of runit that was built in runit-artifacts.sh,
# so install that one.
#

set -x

#export LANGUAGE=en_US:en
#export LC_ALL=en_US.UTF-8
#export LANG=en_US.UTF-8
#export LC_CTYPE=en_US.UTF-8

echo "runit should be run here..."

apk update

apk add --allow-untrusted /tmp/runit*.apk
apk add --allow-untrusted /tmp/shadow*.apk

## dpkg -i /tmp/runit_*.deb
## apt-get install -y --no-install-suggests --no-install-recommends -f

#language-pack-en

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
