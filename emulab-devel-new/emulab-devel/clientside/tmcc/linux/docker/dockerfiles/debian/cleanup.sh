#!/bin/sh

set -x

apt-get clean
rm -rf /var/lib/apt/lists/*
rm -f /tmp/apt-updated
rm -rf /tmp/* /var/tmp*

exit 0
