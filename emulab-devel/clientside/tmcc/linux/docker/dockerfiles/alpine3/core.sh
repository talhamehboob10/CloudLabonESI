#!/bin/sh

set -x

apk update

# missing perl-modules package from ubuntu version
apk add ca-certificates sudo python wget patch nano file \
    perl perl-libwww psmisc zsh mksh shadow \
    'g++' gcc openssl-dev boost rsync

#
# Create these traditional NFS mountpoints now.  Scripts get unhappy
# about them if they're not there.
#
mkdir -p /users /proj /groups /share

exit 0
