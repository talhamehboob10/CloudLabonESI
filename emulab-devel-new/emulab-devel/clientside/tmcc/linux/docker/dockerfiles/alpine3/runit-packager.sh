#!/bin/sh

#
# Actually does the package building since root can't build the packages
#

set -x

# sudo chown packager:packager ~/.abuild/
abuild-keygen -a -i -n
cd /tmp/runit/alpine
abuild -r -P /tmp
