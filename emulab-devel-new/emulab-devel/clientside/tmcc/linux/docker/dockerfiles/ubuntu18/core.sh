#!/bin/sh

set -x

export DEBIAN_FRONTEND=noninteractive

apt-get install -y --no-install-suggests --no-install-recommends \
    ca-certificates sudo python wget patch nano file \
    perl perl-modules libwww-perl psmisc tcsh zsh ksh rsync

#
# Create these traditional NFS mountpoints now.  Scripts get unhappy
# about them if they're not there.
#
mkdir -p /users /proj /groups /share

exit 0
