#!/bin/sh

set -x

yum install -y \
    ca-certificates sudo python wget patch nano file \
    perl perl-libwww-perl psmisc tcsh zsh ksh util-linux

#
# Create these traditional NFS mountpoints now.  Scripts get unhappy
# about them if they're not there.
#
mkdir -p /users /proj /groups /share

#
# Force an ldconfig to ensure pubsub clients can find the 
#
ldconfig

exit 0
