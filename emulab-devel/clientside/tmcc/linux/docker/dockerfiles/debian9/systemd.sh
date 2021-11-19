#!/bin/sh

set -x

# Don't start any optional services except for the few we need.
#RUN find /etc/systemd/system \
#         /lib/systemd/system \
#         -path '*.wants/*' \
#         -not -name '*journald*' \
#         -not -name '*systemd-tmpfiles*' \
#         -not -name '*systemd-user-sessions*' \
#         -exec rm \{} \;

systemctl set-default multi-user.target

exit 0
