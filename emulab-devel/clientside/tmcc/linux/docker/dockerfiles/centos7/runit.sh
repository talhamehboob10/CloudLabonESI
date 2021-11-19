#!/bin/sh

#
# Mostly we need to install the runit package we're given, since runit
# isn't packaged for Fedora/CentOS.  It will be in /tmp/.
#
# Then we need /etc/runit/{1,2,3}, sshd/syslog/testbed/dockercmd
#

set -x

rpm -iv /tmp/runit-*.rpm
